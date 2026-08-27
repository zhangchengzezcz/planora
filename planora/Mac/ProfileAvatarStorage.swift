#if os(macOS)
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

@MainActor
enum ProfileAvatarStorage {
    static let revisionKey = "planora.mac.profileAvatarRevision"
    private static var cachedImage: NSImage?
    private static var hasLoadedImage = false

    private static var fileURL: URL? {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return applicationSupport
            .appending(path: "Planora", directoryHint: .isDirectory)
            .appending(path: "ProfileAvatar.png", directoryHint: .notDirectory)
    }

    static var hasCustomAvatar: Bool {
        guard let fileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func image() -> NSImage? {
        if hasLoadedImage { return cachedImage }
        hasLoadedImage = true
        guard let fileURL else { return nil }
        cachedImage = NSImage(contentsOf: fileURL)
        return cachedImage
    }

    static func save(from sourceURL: URL) throws {
        let canAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if canAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 512
                ] as CFDictionary
              ),
              let fileURL else {
            throw CocoaError(.fileReadCorruptFile)
        }

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, thumbnail, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
        cachedImage = NSImage(cgImage: thumbnail, size: .zero)
        hasLoadedImage = true
        bumpRevision()
    }

    static func remove() throws {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
        cachedImage = nil
        hasLoadedImage = true
        bumpRevision()
    }

    private static func bumpRevision() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: revisionKey) + 1, forKey: revisionKey)
    }
}
#endif
