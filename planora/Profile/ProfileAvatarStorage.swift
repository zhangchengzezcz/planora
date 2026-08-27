import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
typealias PlanoraPlatformImage = NSImage
#else
import UIKit
typealias PlanoraPlatformImage = UIImage
#endif

@MainActor
enum ProfileAvatarStorage {
    static let revisionKey = "planora.profileAvatarRevision"
    private static var cachedImage: PlanoraPlatformImage?
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

    static func image() -> PlanoraPlatformImage? {
        if hasLoadedImage { return cachedImage }
        hasLoadedImage = true
        guard let fileURL else { return nil }
        cachedImage = PlanoraPlatformImage(contentsOfFile: fileURL.path)
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

#if os(macOS)
        cachedImage = NSImage(cgImage: thumbnail, size: .zero)
#else
        cachedImage = UIImage(cgImage: thumbnail)
#endif
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

struct ProfileAvatarView: View {
    let name: String
    let size: CGFloat
    @AppStorage(ProfileAvatarStorage.revisionKey) private var avatarRevision = 0

    private var initials: String {
        let components = name.split(whereSeparator: \.isWhitespace)
        let characters = components.prefix(2).compactMap(\.first)
        return characters.isEmpty ? "P" : String(characters).uppercased()
    }

    var body: some View {
        ZStack {
            if let image = ProfileAvatarStorage.image() {
#if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
#else
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
#endif
            } else {
                Circle()
                    .fill(Color.accentColor.gradient)
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .id(avatarRevision)
        .accessibilityHidden(true)
    }
}
