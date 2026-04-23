/**
 * Pulsoria Cloud Functions
 * ────────────────────────
 *
 * Jobs:
 *   1. notifyOnFriendRequest     — push + sanitize when a
 *      `friendRequests/{id}` doc is created.
 *   2. notifyOnFriendship        — push to the request sender on accept.
 *   3. cleanupStalePresence      — nightly sweep of 30+ day stale users.
 *   4. verifyAndRecordPurchase   — callable: verifies a TON transaction
 *      on-chain, writes an idempotent `purchases/{txHash}` doc and
 *      appends the buyer to `beats/{beatID}.purchasedBy`. Only path
 *      that mutates beat ownership — client-side direct writes are
 *      rejected by Firestore rules.
 *   5. onBeatDeleted             — fan-out cleanup of Storage files
 *      when a beat doc is deleted.
 *   6. tonconnectManifest        — serves the static TonConnect
 *      manifest JSON under our own origin, removing the GitHub Raw
 *      single-point-of-failure.
 *
 * Deploy:
 *   cd functions
 *   npm install
 *   firebase deploy --only functions
 */

const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
const storage = admin.storage();

// Firestore batch has a hard limit of 500 writes. Leave headroom in
// case we want to include deletes + updates in the same batch later.
const BATCH_SIZE = 450;

// Strip control characters and bidi overrides, clip to 40 chars.
// Used for anything a client typed that ends up in a push banner.
function sanitizeDisplayName(name, fallback = "A friend") {
  if (typeof name !== "string") return fallback;
  const cleaned = name
    .replace(/[\u0000-\u001F\u007F-\u009F\u200E\u200F\u202A-\u202E]/g, "")
    .trim();
  return cleaned.slice(0, 40) || fallback;
}

// ─── 1. Friend-request push + sanitization ──────────────────────────────

exports.notifyOnFriendRequest = onDocumentCreated(
  "friendRequests/{requestId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const raw = snap.data() || {};
    const { to, from } = raw;
    if (!to || !from) return;

    const profile = await userProfile(from);
    const fromName = sanitizeDisplayName(profile.displayName);
    const fromAvatarURL = typeof profile.avatarURL === "string"
      ? profile.avatarURL
      : null;
    const fromCode = typeof profile.friendCode === "string"
      ? profile.friendCode
      : "";

    await snap.ref.update({
      fromName,
      fromAvatarURL: fromAvatarURL || admin.firestore.FieldValue.delete(),
      fromCode,
    });

    const token = await fcmToken(to);
    if (!token) {
      logger.info(`No FCM token for uid=${to}, skipping friend-request push`);
      return;
    }

    await safeSend({
      token,
      notification: {
        title: `${fromName} wants to add you`,
        body: "Tap to accept or decline.",
      },
      data: {
        type: "friendRequest",
        requestId: snap.id,
      },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
  }
);

// ─── 2. Friendship-accepted push ────────────────────────────────────────

exports.notifyOnFriendship = onDocumentCreated(
  "friendships/{pairId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    const members = data.members || [];
    if (members.length !== 2) return;

    const acceptedBy = typeof data.acceptedBy === "string"
      ? data.acceptedBy
      : null;
    const sender = members.find((m) => m !== acceptedBy);
    if (!sender) return;

    const [token, rawAcceptedByName] = await Promise.all([
      fcmToken(sender),
      displayName(acceptedBy),
    ]);
    if (!token) return;

    const accepterName = sanitizeDisplayName(rawAcceptedByName);

    await safeSend({
      token,
      notification: {
        title: "New friend 🎧",
        body: `${accepterName} accepted your request.`,
      },
      data: {
        type: "friendshipAccepted",
        otherUID: acceptedBy,
      },
      apns: { payload: { aps: { sound: "default" } } },
    });
  }
);

// ─── 3. Stale presence cleanup ──────────────────────────────────────────

exports.cleanupStalePresence = onSchedule(
  { schedule: "0 3 * * *", timeZone: "UTC" },
  async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 30 * 24 * 60 * 60 * 1000
    );

    const stale = await db
      .collection("users")
      .where("lastSeen", "<", cutoff)
      .get();

    logger.info(`Sweeping ${stale.size} stale user presences`);
    if (stale.empty) return;

    for (let i = 0; i < stale.docs.length; i += BATCH_SIZE) {
      const chunk = stale.docs.slice(i, i + BATCH_SIZE);
      const batch = db.batch();
      chunk.forEach((doc) => {
        batch.update(doc.ref, {
          nowPlaying: admin.firestore.FieldValue.delete(),
          currentRoomCode: admin.firestore.FieldValue.delete(),
        });
      });
      await batch.commit();
    }
  }
);

// ─── 4. Verified beat purchase (TON on-chain) ───────────────────────────
//
// Client hands us `{ beatID, fromAddress }`. We:
//   1. Pull the seller's wallet from `beats/{beatID}.sellerWallet`
//      (snapshotted at upload time; seller's private user doc is not
//      readable to buyers). Fallback to legacy `users/{uploaderID}
//      .tonWallet` and `userPrivate/{uploaderID}.tonWallet` for beats
//      uploaded before the sellerWallet field existed.
//   2. Pull recent txs to that wallet from toncenter.
//   3. Match one by (source, amount, recent time window).
//   4. Record `purchases/{txHash}` transactionally — the doc id is the
//      tx hash, guaranteeing one tx funds at most one purchase.
//   5. Add the buyer to `beats/{beatID}.purchasedBy`.
//
// All via admin SDK, so Firestore rules can keep `beats.update` locked
// down to the uploader and `purchases.*` locked down entirely — only
// this function mutates them.

const TX_TOLERANCE_NANO = 10_000_000n;         // 0.01 TON slop
const TX_AGE_WINDOW_SEC = 30 * 60;             // 30 minutes
const TX_LIMIT = 25;                            // how far back we scan

exports.verifyAndRecordPurchase = onCall({ cors: true }, async (request) => {
  const { auth, data } = request;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const beatID = typeof data?.beatID === "string" ? data.beatID : "";
  const fromAddress = typeof data?.fromAddress === "string" ? data.fromAddress : "";
  if (!beatID || !fromAddress) {
    throw new HttpsError("invalid-argument", "beatID + fromAddress required.");
  }

  const beatSnap = await db.collection("beats").doc(beatID).get();
  if (!beatSnap.exists) {
    throw new HttpsError("not-found", "Beat not found.");
  }
  const beat = beatSnap.data() || {};
  const uploaderID = typeof beat.uploaderID === "string" ? beat.uploaderID : "";
  const priceTON = Number(beat.priceTON);
  if (!uploaderID || !Number.isFinite(priceTON) || priceTON <= 0) {
    throw new HttpsError("failed-precondition", "Beat isn't configured for TON sale.");
  }

  // Prevent self-purchase as an abuse / accidental loop.
  if (uploaderID === auth.uid) {
    throw new HttpsError("failed-precondition", "Can't buy your own beat.");
  }

  // Prefer the beat's own snapshotted sellerWallet (public, scoped to
  // this listing). Fallback: legacy public `users/{uploaderID}.tonWallet`
  // for pre-existing beats, then `userPrivate/{uploaderID}.tonWallet`
  // via Admin SDK. Once all legacy beats are re-listed this falls to
  // the first branch only.
  let sellerAddress = typeof beat.sellerWallet === "string" ? beat.sellerWallet : "";
  if (!sellerAddress) {
    const sellerPub = await db.collection("users").doc(uploaderID).get();
    sellerAddress = sellerPub.exists ? (sellerPub.get("tonWallet") || "") : "";
  }
  if (!sellerAddress) {
    const sellerPriv = await db.collection("userPrivate").doc(uploaderID).get();
    sellerAddress = sellerPriv.exists ? (sellerPriv.get("tonWallet") || "") : "";
  }
  if (!sellerAddress) {
    throw new HttpsError("failed-precondition", "Seller has no wallet configured.");
  }

  // Query toncenter for recent txs to the seller. Using built-in
  // fetch (Node 20+).
  const url = `https://toncenter.com/api/v2/getTransactions?address=${encodeURIComponent(sellerAddress)}&limit=${TX_LIMIT}`;
  let txs;
  try {
    const res = await fetch(url);
    const body = await res.json();
    if (!body?.ok) {
      logger.warn(`toncenter error: ${JSON.stringify(body)}`);
      throw new Error(body?.error || "toncenter failure");
    }
    txs = Array.isArray(body.result) ? body.result : [];
  } catch (e) {
    logger.error(`toncenter fetch failed: ${e.message}`);
    throw new HttpsError("unavailable", "Chain explorer unreachable.");
  }

  const expectedNano = BigInt(Math.floor(priceTON * 1_000_000_000));
  const now = Math.floor(Date.now() / 1000);

  let matched = null;
  for (const tx of txs) {
    const inMsg = tx.in_msg || {};
    if (inMsg.source !== fromAddress) continue;
    const valueNano = BigInt(inMsg.value || "0");
    const delta = valueNano > expectedNano ? valueNano - expectedNano : expectedNano - valueNano;
    if (delta > TX_TOLERANCE_NANO) continue;
    const utime = Number(tx.utime || 0);
    if (!utime || now - utime > TX_AGE_WINDOW_SEC) continue;
    matched = tx;
    break;
  }

  if (!matched) {
    throw new HttpsError("not-found", "Matching on-chain transfer not found.");
  }

  const txHash = (matched.transaction_id && matched.transaction_id.hash) || "";
  if (!txHash) {
    throw new HttpsError("internal", "Transaction had no hash.");
  }

  const purchaseRef = db.collection("purchases").doc(txHash);
  const beatRef = db.collection("beats").doc(beatID);

  try {
    await db.runTransaction(async (t) => {
      const existing = await t.get(purchaseRef);
      if (existing.exists) {
        throw new HttpsError("already-exists", "Purchase already recorded.");
      }
      t.set(purchaseRef, {
        beatID,
        buyerUID: auth.uid,
        sellerUID: uploaderID,
        amountTON: priceTON,
        txHash,
        fromAddress,
        toAddress: sellerAddress,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      t.update(beatRef, {
        purchasedBy: admin.firestore.FieldValue.arrayUnion(auth.uid),
      });
    });
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    logger.error(`purchase commit failed: ${e.message}`);
    throw new HttpsError("internal", "Couldn't record purchase.");
  }

  return { ok: true, txHash };
});

// ─── 5. On-beat-delete Storage cleanup ──────────────────────────────────
// When a beat doc is deleted, fan out to Storage and nuke the folder
// so we don't leave orphaned MP3s occupying the bucket.

exports.onBeatDeleted = onDocumentDeleted(
  "beats/{beatID}",
  async (event) => {
    const beatID = event.params.beatID;
    const bucket = storage.bucket();
    const prefix = `beats/${beatID}/`;
    try {
      const [files] = await bucket.getFiles({ prefix });
      await Promise.all(files.map((f) => f.delete().catch(() => {})));
      logger.info(`Deleted ${files.length} storage files under ${prefix}`);
    } catch (e) {
      logger.warn(`Storage cleanup for beat=${beatID} failed: ${e.message}`);
    }
  }
);

// ─── 6. TonConnect manifest (self-hosted) ───────────────────────────────
// Previously lived on raw.githubusercontent.com/.../main/... — a single
// GitHub outage / branch rename / compromise would break wallet
// connect. Serve it from our own Firebase origin instead.

const MANIFEST = {
  url: "https://pulsoria.app",
  name: "Pulsoria",
  iconUrl: "https://raw.githubusercontent.com/whalor-chain/pulsoria--ton--connect/main/pulsoria-icon.png",
  termsOfUseUrl: "https://pulsoria.app/terms",
  privacyPolicyUrl: "https://pulsoria.app/privacy",
};

exports.tonconnectManifest = onRequest({ cors: true }, async (_req, res) => {
  res.set("Content-Type", "application/json");
  res.set("Cache-Control", "public, max-age=300");
  res.send(MANIFEST);
});

// ─── Helpers ────────────────────────────────────────────────────────────

async function userProfile(uid) {
  const snap = await db.collection("users").doc(uid).get();
  return snap.exists ? snap.data() || {} : {};
}

async function fcmToken(uid) {
  // FCM tokens moved to `userPrivate/{uid}` so they're no longer
  // readable via the public `users/{uid}` doc. We fall back to the
  // legacy location so pushes keep working for installs that haven't
  // yet written the new private doc — the client scrubs the legacy
  // field on next token refresh.
  const priv = await db.collection("userPrivate").doc(uid).get();
  if (priv.exists) {
    const t = priv.get("fcmToken");
    if (t) return t;
  }
  const pub = await db.collection("users").doc(uid).get();
  return pub.exists ? pub.get("fcmToken") || null : null;
}

async function displayName(uid) {
  const snap = await db.collection("users").doc(uid).get();
  return snap.exists ? snap.get("displayName") || "A friend" : "A friend";
}

async function safeSend(message) {
  try {
    await messaging.send(message);
  } catch (err) {
    logger.warn(`FCM send failed: ${err.message}`);
  }
}
