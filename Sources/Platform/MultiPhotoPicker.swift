import PhotosUI
import SwiftUI
import UIKit

/// Multi-image PHPicker. Callers copy/compress results; no library permission.
struct MultiPhotoPicker: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onPicked: ([UIImage]) -> Void

    init(selectionLimit: Int = 9, onPicked: @escaping ([UIImage]) -> Void) {
        self.selectionLimit = max(1, min(9, selectionLimit))
        self.onPicked = onPicked
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit
        configuration.selection = .ordered
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPicked: ([UIImage]) -> Void
        private var delivered = false

        init(onPicked: @escaping ([UIImage]) -> Void) {
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !delivered else { return }
            delivered = true
            guard !results.isEmpty else {
                picker.dismiss(animated: true)
                return
            }
            var images = [UIImage?](repeating: nil, count: results.count)
            let group = DispatchGroup()
            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    images[index] = object as? UIImage
                    group.leave()
                }
            }
            group.notify(queue: .main) { [weak self] in
                self?.onPicked(images.compactMap { $0 })
                picker.dismiss(animated: true)
            }
        }
    }
}
