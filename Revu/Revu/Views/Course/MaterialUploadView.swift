import SwiftUI
import UniformTypeIdentifiers

struct MaterialUploadView: View {
    @Binding var uploadedURLs: [URL]
    let onFilesAdded: ([URL]) -> Void

    @State private var isHoveringDropZone = false
    @State private var fileImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            Text("Course Materials")
                .font(DesignSystem.Typography.heading)
                .foregroundStyle(DesignSystem.Colors.primaryText)

            Text("Upload PDFs, slides, or text files to extract topics and generate study materials.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)

            // Drop zone
            dropZone

            // File list
            if !uploadedURLs.isEmpty {
                fileList
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(isHoveringDropZone ? DesignSystem.Colors.studyAccentBright : DesignSystem.Colors.secondaryText)

            Text("Drag and drop files here")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.primaryText)

            Text("or")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)

            Button(action: {
                fileImporterPresented = true
            }) {
                Text("Choose Files")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                            .fill(DesignSystem.Colors.window)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                            .strokeBorder(DesignSystem.Colors.studyAccentBright, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.canvasBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(
                    isHoveringDropZone ? DesignSystem.Colors.studyAccentBright : DesignSystem.Colors.secondaryText.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isHoveringDropZone) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: "public.file-url") { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async {
                        if !uploadedURLs.contains(url) {
                            uploadedURLs.append(url)
                            onFilesAdded([url])
                        }
                    }
                }
            }
            return true
        }
        .fileImporter(
            isPresented: $fileImporterPresented,
            allowedContentTypes: [.pdf, .plainText, .text],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                let newURLs = urls.filter { !uploadedURLs.contains($0) }
                uploadedURLs.append(contentsOf: newURLs)
                if !newURLs.isEmpty {
                    onFilesAdded(newURLs)
                }
            case .failure:
                break
            }
        }
        .animation(DesignSystem.Animation.layout, value: isHoveringDropZone)
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Uploaded Files")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .padding(.top, DesignSystem.Spacing.sm)

            ForEach(uploadedURLs, id: \.self) { url in
                fileRow(for: url)
            }
        }
    }

    private func fileRow(for url: URL) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // File type icon
            Image(systemName: fileIcon(for: url))
                .font(.system(size: 16))
                .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                .frame(width: 20)

            // Filename
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(url.lastPathComponent)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                Text(fileMetadata(for: url))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }

            Spacer()

            // Remove button
            Button(action: {
                removeFile(url)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            .buttonStyle(.plain)
            .help("Remove file")
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                .fill(DesignSystem.Colors.window)
        )
    }

    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.richtext"
        case "txt", "md", "markdown":
            return "doc.text"
        default:
            return "doc"
        }
    }

    private func fileMetadata(for url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            return "Unknown size"
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    private func removeFile(_ url: URL) {
        uploadedURLs.removeAll { $0 == url }
    }
}
