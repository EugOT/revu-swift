import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

struct CardMediaStripView: View {
    let urls: [URL]

    private var imageURLs: [URL] {
        urls.filter { url in
            guard url.isFileURL || url.scheme != nil else { return false }
            return Self.imageExtensions.contains(url.pathExtension.lowercased())
        }
    }

    private var audioURLs: [URL] {
        urls.filter { url in
            guard url.isFileURL || url.scheme != nil else { return false }
            return Self.audioExtensions.contains(url.pathExtension.lowercased())
        }
    }

    private var otherURLs: [URL] {
        let handled = Set(imageURLs + audioURLs)
        return urls.filter { !handled.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !imageURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(imageURLs, id: \.absoluteString) { url in
                            ImageAttachmentTile(url: url)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if !audioURLs.isEmpty || !otherURLs.isEmpty {
                FlowRow(spacing: 10, lineSpacing: 10) {
                    ForEach(audioURLs, id: \.absoluteString) { url in
                        AudioAttachmentChip(url: url)
                    }
                    ForEach(otherURLs, id: \.absoluteString) { url in
                        GenericAttachmentChip(url: url)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "heic", "tiff", "bmp", "webp"
    ]

    private static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aiff", "caf", "flac", "ogg", "oga"
    ]
}

private struct ImageAttachmentTile: View {
    let url: URL

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: NSImage?

    var body: some View {
        Button {
            #if canImport(AppKit)
            NSWorkspace.shared.open(url)
            #endif
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DesignSystem.Colors.hoverBackground)
                    .frame(width: 160, height: 108)

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 108)
                        .clipped()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DesignSystem.Colors.separator.opacity(colorScheme == .dark ? 0.9 : 0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .task { await loadImageIfNeeded() }
        .accessibilityLabel("Open image attachment")
    }

    @MainActor
    private func loadImageIfNeeded() async {
        guard image == nil else { return }
        guard url.isFileURL else { return }
        image = NSImage(contentsOf: url)
    }
}

private struct AudioAttachmentChip: View {
    let url: URL

    @State private var isPlaying = false
    @State private var sound: NSSound?

    var body: some View {
        Button {
            toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(DesignSystem.Typography.captionMedium)
                    .lineLimit(1)
            }
            .foregroundStyle(DesignSystem.Colors.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.hoverBackground)
            )
            .overlay(
                Capsule()
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onDisappear { stop() }
        .accessibilityLabel(isPlaying ? "Pause audio" : "Play audio")
    }

    private var label: String {
        url.lastPathComponent.isEmpty ? "Audio" : url.lastPathComponent
    }

    private func toggle() {
        if isPlaying {
            stop()
        } else {
            play()
        }
    }

    private func play() {
        guard url.isFileURL else {
            #if canImport(AppKit)
            NSWorkspace.shared.open(url)
            #endif
            return
        }
        sound = NSSound(contentsOf: url, byReference: true)
        sound?.play()
        isPlaying = sound?.isPlaying ?? false
    }

    private func stop() {
        sound?.stop()
        isPlaying = false
    }
}

private struct GenericAttachmentChip: View {
    let url: URL

    var body: some View {
        Button {
            #if canImport(AppKit)
            NSWorkspace.shared.open(url)
            #endif
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperclip")
                    .font(.system(size: 12, weight: .semibold))
                Text(url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent)
                    .font(DesignSystem.Typography.captionMedium)
                    .lineLimit(1)
            }
            .foregroundStyle(DesignSystem.Colors.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.hoverBackground)
            )
            .overlay(
                Capsule()
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open attachment")
    }
}

/// Minimal wrapping layout for attachment chips (no WebKit).
private struct FlowRow<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 10, lineSpacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }

    var body: some View {
        InlineWrapLayout(alignment: .leading, spacing: spacing, lineSpacing: lineSpacing) {
            content
        }
    }
}

#if DEBUG
#Preview("CardMediaStripView") {
    let tmp = FileManager.default.temporaryDirectory
    let urls: [URL] = [
        tmp.appendingPathComponent("preview-image.png"),
        tmp.appendingPathComponent("preview-audio.mp3"),
        URL(string: "https://example.com/notes.pdf")!
    ]
    return CardMediaStripView(urls: urls)
        .padding()
        .frame(width: 520)
        .background(DesignSystem.Colors.window)
}
#endif
