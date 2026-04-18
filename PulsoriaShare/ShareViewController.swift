//
//  ShareViewController.swift
//  PulsoriaShare
//
//  Created by Станислава Гункер on 12.04.2026.
//

import OSLog
import UIKit
import UniformTypeIdentifiers

private let shareLog = Logger(subsystem: "Wave.Pulsoria.Share", category: "share")

class ShareViewController: UIViewController {

    private let appGroupID = "group.Wave.Pulsoria"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        handleSharedFiles()
    }

    private func handleSharedFiles() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        let audioIdentifiers = [
            UTType.audio.identifier,
            UTType.mp3.identifier,
            UTType.mpeg4Audio.identifier,
            UTType.wav.identifier,
            UTType.aiff.identifier,
            "org.xiph.flac",
            "com.apple.m4a-audio",
            "public.audio",
        ]

        var pendingCount = 0
        var foundAny = false

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                let matchedType = audioIdentifiers.first { provider.hasItemConformingToTypeIdentifier($0) }
                    ?? (provider.hasItemConformingToTypeIdentifier("public.data") ? "public.data" : nil)

                guard let typeID = matchedType else { continue }
                foundAny = true
                pendingCount += 1

                provider.loadItem(forTypeIdentifier: typeID, options: nil) { [weak self] data, error in
                    guard let self else { return }

                    var fileURL: URL?

                    if let url = data as? URL {
                        fileURL = url
                    } else if let rawData = data as? Data {
                        let tempFile = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString + ".mp3")
                        try? rawData.write(to: tempFile)
                        fileURL = tempFile
                    }

                    guard let sourceURL = fileURL else {
                        pendingCount -= 1
                        if pendingCount == 0 { self.close() }
                        return
                    }

                    self.saveToSharedContainer(from: sourceURL)

                    pendingCount -= 1
                    if pendingCount == 0 {
                        self.openMainApp()
                    }
                }
            }
        }

        if !foundAny {
            close()
        }
    }

    private func saveToSharedContainer(from sourceURL: URL) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return }

        let sharedDir = containerURL.appendingPathComponent("SharedAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)

        let fileName = sourceURL.lastPathComponent
        let destination = sharedDir.appendingPathComponent(fileName)

        try? FileManager.default.removeItem(at: destination)

        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } catch {
            shareLog.error("Failed to copy file: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func openMainApp() {
        let url = URL(string: "pulsoria://import")!

        // Use responder chain to open URL from extension
        var responder: UIResponder? = self
        while let r = responder {
            if let application = r as? UIApplication {
                application.open(url)
                break
            }
            responder = r.next
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.close()
        }
    }

    private func close() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
