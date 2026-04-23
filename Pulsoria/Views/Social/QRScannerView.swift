import AVFoundation
import SwiftUI

/// Wraps `AVCaptureSession` as a SwiftUI view that emits the first
/// detected QR payload via `onCode`. Designed to be presented as a sheet
/// from `AddFriendSheet`.
///
/// The caller is responsible for *using* the returned string (e.g.
/// filling the friend-code field) and for dismissing the sheet.
///
/// Info.plist must include `NSCameraUsageDescription` or the system will
/// silently deny camera access on first launch.
struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onError: onError)
    }

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    final class Coordinator: NSObject, QRScannerViewControllerDelegate {
        let onCode: (String) -> Void
        let onError: (String) -> Void
        private var didFire = false

        init(onCode: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onCode = onCode
            self.onError = onError
        }

        func scanner(_ controller: QRScannerViewController, didFind code: String) {
            // Rate-limit: a single QR in view spams the callback. Fire once.
            guard !didFire else { return }
            didFire = true
            onCode(code)
        }

        func scanner(_ controller: QRScannerViewController, failedWith message: String) {
            onError(message)
        }
    }
}

// MARK: - UIKit controller

protocol QRScannerViewControllerDelegate: AnyObject {
    func scanner(_ controller: QRScannerViewController, didFind code: String)
    func scanner(_ controller: QRScannerViewController, failedWith message: String)
}

final class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerViewControllerDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            fail("No camera available.")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                fail("Camera input rejected.")
                return
            }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                fail("Metadata output rejected.")
                return
            }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            previewLayer = layer
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        delegate?.scanner(self, failedWith: message)
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              first.type == .qr,
              let value = first.stringValue else { return }
        delegate?.scanner(self, didFind: value)
    }
}
