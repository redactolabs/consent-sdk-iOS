import SwiftUI
import UIKit
import UniformTypeIdentifiers

public struct PickedFile: Sendable {
    public let url: URL
    public let fileName: String
    public let mimeType: String
    public let data: Data
}

public struct FilePickerView: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPick: (PickedFile) -> Void
    let onCancel: () -> Void

    public init(
        allowedTypes: [UTType] = [.data],
        onPick: @escaping (PickedFile) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.allowedTypes = allowedTypes
        self.onPick = onPick
        self.onCancel = onCancel
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePickerView

        init(_ parent: FilePickerView) {
            self.parent = parent
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.onCancel()
                return
            }
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                let mimeType = mimeType(for: url)
                parent.onPick(PickedFile(url: url, fileName: fileName, mimeType: mimeType, data: data))
            } catch {
                parent.onCancel()
            }
        }

        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }

        private func mimeType(for url: URL) -> String {
            if let utType = UTType(filenameExtension: url.pathExtension), let mime = utType.preferredMIMEType {
                return mime
            }
            return "application/octet-stream"
        }
    }
}
