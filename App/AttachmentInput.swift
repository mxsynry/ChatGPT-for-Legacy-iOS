import SwiftUI
import UIKit
import PDFKit
import UniformTypeIdentifiers

struct ImportedDocument {
    let name: String
    let text: String
}

enum AttachmentImportError: LocalizedError {
    case tooLarge, empty, unsupported
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "The file exceeds the 5 MB attachment limit."
        case .empty: return "No selectable text was found in this document."
        case .unsupported: return "Only text, JSON and text-based PDF documents are supported."
        }
    }
}

enum AttachmentTextExtractor {
    static func importDocument(from url: URL) throws -> ImportedDocument {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let count = (attrs[.size] as? NSNumber)?.intValue ?? 0
        guard count <= 5_000_000 else { throw AttachmentImportError.tooLarge }
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
        let text: String
        if type?.conforms(to: .pdf) == true || url.pathExtension.lowercased() == "pdf" {
            guard let pdf = PDFDocument(url: url) else { throw AttachmentImportError.unsupported }
            // Text extraction only. Scanned images need OCR, which is not implemented.
            text = pdf.string ?? ""
        } else if type?.conforms(to: .plainText) == true ||
                  ["txt", "json", "md", "csv"].contains(url.pathExtension.lowercased()) {
            let data = try Data(contentsOf: url)
            text = String(data: data, encoding: .utf8) ?? ""
        } else {
            throw AttachmentImportError.unsupported
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AttachmentImportError.empty
        }
        // Limit content injected into the model request, independent of file size.
        return ImportedDocument(name: url.lastPathComponent, text: String(text.prefix(40_000)))
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let completion: (Data?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let completion: (Data?) -> Void
        init(completion: @escaping (Data?) -> Void) { self.completion = completion }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            guard let image = image else { completion(nil); return }
            // The picker already holds the original camera image in memory.
            // Move JPEG resizing/compression off the main thread.
            DispatchQueue.global(qos: .userInitiated).async {
                let data = ImagePreparation.jpeg(from: image)
                DispatchQueue.main.async { self.completion(data) }
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
    }
}
