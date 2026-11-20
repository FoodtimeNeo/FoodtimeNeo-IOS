import PhotosUI
import SwiftUI
import UIKit

/// System photo picker (no full-library permission). The selected image is
/// copied into app-owned data by the caller; this adapter never uploads.
struct PhotoPicker: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onPicked: (UIImage) -> Void

    init(selectionLimit: Int = 1, onPicked: @escaping (UIImage) -> Void) {
        self.selectionLimit = max(1, selectionLimit)
        self.onPicked = onPicked
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPicked: (UIImage) -> Void
        private var delivered = false

        init(onPicked: @escaping (UIImage) -> Void) {
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !delivered else { return }
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                picker.dismiss(animated: true)
                return
            }
            delivered = true
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self?.onPicked(image)
                    }
                    picker.dismiss(animated: true)
                }
            }
        }
    }
}
