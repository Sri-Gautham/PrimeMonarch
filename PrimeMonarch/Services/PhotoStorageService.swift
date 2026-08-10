import Foundation
import UIKit

// MARK: - Photo Storage Service
//
// Saves progress photos to the app's private Application Support directory
// with complete-file protection. Never touches the system Photo Library or
// any cloud-synced location — all data stays on-device.

@MainActor
final class PhotoStorageService {

    static let shared = PhotoStorageService()

    private let directory: URL

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        directory = base.appendingPathComponent("ProgressPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: - Public API

    func save(_ image: UIImage, identifier: String) throws {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw StorageError.encodingFailed
        }
        let url = directory.appendingPathComponent(identifier)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func load(identifier: String) -> UIImage? {
        let url = directory.appendingPathComponent(identifier)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func delete(identifier: String) {
        let url = directory.appendingPathComponent(identifier)
        try? FileManager.default.removeItem(at: url)
    }

    func deleteAll() {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }
        items.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    // MARK: - Error

    enum StorageError: Error { case encodingFailed }
}
