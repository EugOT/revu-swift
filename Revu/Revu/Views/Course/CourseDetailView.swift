import SwiftUI
import UniformTypeIdentifiers

/// Lesson-first Course Hub.
struct CourseDetailView: View {
    let course: Course
    @ObservedObject var viewModel: CourseViewModel
    var onOpenDeck: (UUID) -> Void = { _ in }
    var onOpenExam: (UUID) -> Void = { _ in }
    var onOpenStudyGuide: (UUID) -> Void = { _ in }

    @State private var fileImporterPresented = false
    @State private var isHoveringDropZone = false
    @State private var selectedMaterialIds: Set<UUID> = []
    @State private var newLessonTitle: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                heroSection
                bulkActionBar
                nextActionsSection
                lessonsSection
                materialsSection
                weakLessonsSection
            }
            .padding(.horizontal, DesignSystem.Spacing.xxl)
            .padding(.top, DesignSystem.Spacing.xxl)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.window)
        .id(course.id)
        .task(id: course.id) {
            viewModel.selectCourse(course)
        }
        .fileImporter(
            isPresented: $fileImporterPresented,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                viewModel.addMaterial(url: url)
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        let dashboard = viewModel.dashboard
        let readiness = dashboard?.topKpis.readiness ?? 0
        let dueItems = dashboard?.topKpis.dueItems ?? 0
        let weakCount = dashboard?.topKpis.weakLessonCount ?? 0
        let lessons = dashboard?.topKpis.lessonCount ?? 0

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(course.name)
                .font(DesignSystem.Typography.hero)
                .foregroundStyle(DesignSystem.Colors.primaryText)

            HStack(spacing: DesignSystem.Spacing.sm) {
                kpiPill(title: "Readiness", value: "\(Int(readiness * 100))%")
                kpiPill(title: "Due", value: "\(dueItems)")
                kpiPill(title: "Weak Lessons", value: "\(weakCount)")
                kpiPill(title: "Lessons", value: "\(lessons)")
            }

            progressTrack(readiness: readiness)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.studyAccentBright.opacity(0.14),
                    DesignSystem.Colors.studyAccentMid.opacity(0.08),
                    DesignSystem.Colors.canvasBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func kpiPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(DesignSystem.Colors.primaryText)
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background(DesignSystem.Colors.window, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func progressTrack(readiness: Double) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            HStack {
                Text("Course Readiness")
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Spacer()
                Text("\(Int(readiness * 100))%")
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.xs, style: .continuous)
                        .fill(DesignSystem.Colors.subtleOverlay)
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.xs, style: .continuous)
                        .fill(DesignSystem.Colors.studyAccentMid)
                        .frame(width: geo.size.width * CGFloat(min(max(readiness, 0), 1)))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Bulk

    @ViewBuilder
    private var bulkActionBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            bulkButton("Generate Missing Notes", icon: "doc.text") {
                viewModel.generateMissingArtifacts(kind: .notes)
            }
            bulkButton("Generate Missing Quizzes", icon: "checklist") {
                viewModel.generateMissingArtifacts(kind: .quiz)
            }
            bulkButton("Generate Missing Flashcards", icon: "rectangle.stack") {
                viewModel.generateMissingArtifacts(kind: .flashcards)
            }
            bulkButton("Refresh Mixed Quiz", icon: "arrow.clockwise.circle") {
                viewModel.refreshMixedQuiz()
            }
        }
    }

    @ViewBuilder
    private func bulkButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(DesignSystem.Typography.captionMedium)
            }
            .foregroundStyle(DesignSystem.Colors.primaryText)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.Colors.canvasBackground, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeline

    @ViewBuilder
    private var nextActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Next Actions")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("\(viewModel.dashboard?.timelineItems.count ?? 0)")
                    .badgeStyle()
            }

            if let items = viewModel.dashboard?.timelineItems, !items.isEmpty {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(items.prefix(8)) { item in
                        timelineRow(item)
                    }
                }
            } else {
                emptyPanel("No pending actions. Upload more PDFs or generate lesson artifacts.")
            }
        }
    }

    @ViewBuilder
    private func timelineRow(_ item: CourseTimelineItem) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(urgencyColor(item.urgency))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                Text(item.subtitle)
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            Spacer()
            Button(item.cta.title) {
                performTimelineAction(item.cta)
            }
            .buttonStyle(.plain)
            .font(DesignSystem.Typography.captionMedium)
            .foregroundStyle(DesignSystem.Colors.accent)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.canvasBackground, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    // MARK: - Lessons

    @ViewBuilder
    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Lessons")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("\(viewModel.dashboard?.lessonSummaries.count ?? 0)")
                    .badgeStyle()
            }

            if let lessonSummaries = viewModel.dashboard?.lessonSummaries, !lessonSummaries.isEmpty {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(lessonSummaries) { summary in
                        lessonCard(summary)
                    }
                }
            } else {
                emptyPanel("Upload lecture PDFs to create lessons automatically.")
            }
        }
    }

    @ViewBuilder
    private func lessonCard(_ summary: LessonDashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.lesson.title)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    Text("\(summary.materialCount) file\(summary.materialCount == 1 ? "" : "s") • \(summary.wordCount) words • \(summary.dueCards) due")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
                Spacer()
                Text("\(Int(summary.readiness * 100))% ready")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }

            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(summary.artifactSummaries, id: \.kind) { artifact in
                    artifactChip(summary: summary, artifact: artifact)
                }
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.canvasBackground, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func artifactChip(summary: LessonDashboardSummary, artifact: LessonArtifactSummary) -> some View {
        let tint = statusColor(artifact.status)
        let text = artifact.kind.rawValue.capitalized

        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(text)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.primaryText)
            if artifact.status == .ready {
                Button("Open") {
                    openArtifact(summary: summary, kind: artifact.kind)
                }
                .buttonStyle(.plain)
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.accent)
            } else {
                Button("Generate") {
                    viewModel.generateLessonArtifacts(lessonId: summary.lesson.id, kinds: [artifact.kind])
                }
                .buttonStyle(.plain)
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.accent)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, 4)
        .background(DesignSystem.Colors.window, in: Capsule())
        .overlay(
            Capsule()
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    // MARK: - Materials

    @ViewBuilder
    private var materialsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Materials")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("\(viewModel.materials.count)")
                    .badgeStyle()
                Spacer()
                Button {
                    fileImporterPresented = true
                } label: {
                    Label("Upload PDFs", systemImage: "doc.badge.plus")
                        .font(DesignSystem.Typography.captionMedium)
                }
                .buttonStyle(.plain)
            }

            if !viewModel.materials.isEmpty {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    TextField("Lesson title (optional)", text: $newLessonTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(DesignSystem.Typography.caption)
                    Button("Group Selection Into Lesson") {
                        let title = newLessonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        viewModel.createLessonFromMaterials(
                            materialIds: Array(selectedMaterialIds),
                            title: title.isEmpty ? nil : title
                        )
                        selectedMaterialIds.removeAll()
                        newLessonTitle = ""
                    }
                    .buttonStyle(.plain)
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(selectedMaterialIds.count >= 2 ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText)
                    .disabled(selectedMaterialIds.count < 2)
                }
            }

            if viewModel.materials.isEmpty {
                materialDropZone
            } else {
                VStack(spacing: DesignSystem.Spacing.xxs) {
                    ForEach(viewModel.materials) { material in
                        materialRow(material)
                    }
                }
                materialDropZone
            }

            if viewModel.isMaterialUploading {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.75)
                    Text("Ingesting PDF...")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private var materialDropZone: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 18))
                .foregroundStyle(isHoveringDropZone ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText)
            Text("Drop PDF files here")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.canvasBackground, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(
                    isHoveringDropZone ? DesignSystem.Colors.accent : DesignSystem.Colors.separator,
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isHoveringDropZone) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: "public.file-url") { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          url.pathExtension.lowercased() == "pdf" else { return }
                    Task { @MainActor in
                        viewModel.addMaterial(url: url)
                    }
                }
            }
            return true
        }
    }

    @ViewBuilder
    private func materialRow(_ material: CourseMaterial) -> some View {
        let isSelected = selectedMaterialIds.contains(material.id)
        let lessonName = viewModel.lessons.first(where: { $0.id == material.lessonId })?.title ?? "Unassigned"

        HStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                if isSelected {
                    selectedMaterialIds.remove(material.id)
                } else {
                    selectedMaterialIds.insert(material.id)
                }
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(material.filename)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(1)
                Text("Lesson: \(lessonName) • \(material.processingStatus.rawValue)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }

            Spacer()

            Menu {
                Button("Unassign from lesson") {
                    viewModel.assignMaterial(materialId: material.id, toLessonId: nil)
                }
                Divider()
                ForEach(viewModel.lessons) { lesson in
                    Button(lesson.title) {
                        viewModel.assignMaterial(materialId: material.id, toLessonId: lesson.id)
                    }
                }
            } label: {
                Text("Assign")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.canvasBackground, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    // MARK: - Weak Lessons

    @ViewBuilder
    private var weakLessonsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Weak Lessons")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("\(viewModel.dashboard?.weakLessons.count ?? 0)")
                    .badgeStyle()
            }

            if let weak = viewModel.dashboard?.weakLessons, !weak.isEmpty {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(weak) { lesson in
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.lessonTitle)
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundStyle(DesignSystem.Colors.primaryText)
                                Text("Confidence \(Int(lesson.confidence * 100))% • Miss rate \(Int(lesson.missRate * 100))% • \(lesson.dueCards) due")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                                Text(lesson.recommendation)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                            }
                            Spacer()
                            Button("Act") {
                                if let summary = viewModel.dashboardLessonSummary(lessonId: lesson.lessonId) {
                                    if let deckId = summary.flashcardDeckIds.first {
                                        onOpenDeck(deckId)
                                    } else {
                                        viewModel.generateLessonArtifacts(lessonId: lesson.lessonId, kinds: [.flashcards])
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.accent)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.canvasBackground, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                        )
                    }
                }
            } else {
                emptyPanel("Weak areas appear after review outcomes accumulate.")
            }
        }
    }

    // MARK: - Actions

    private func performTimelineAction(_ cta: CourseTimelineCTA) {
        switch cta.actionType {
        case .generateLessonArtifact:
            guard let lessonId = cta.lessonId, let kind = cta.artifactKind else { return }
            viewModel.generateLessonArtifacts(lessonId: lessonId, kinds: [kind])
        case .generateMixedQuiz:
            viewModel.refreshMixedQuiz()
        case .openMixedQuiz, .openLessonQuiz:
            if let examId = cta.examId {
                onOpenExam(examId)
            } else if let lessonId = cta.lessonId,
                      let summary = viewModel.dashboardLessonSummary(lessonId: lessonId),
                      let examId = summary.quizIds.first {
                onOpenExam(examId)
            }
        case .openLessonNotes:
            if let guideId = cta.studyGuideId {
                onOpenStudyGuide(guideId)
            } else if let lessonId = cta.lessonId,
                      let summary = viewModel.dashboardLessonSummary(lessonId: lessonId),
                      let guideId = summary.notesIds.first {
                onOpenStudyGuide(guideId)
            }
        case .openLessonFlashcards, .reviewWeakLesson:
            if let deckId = cta.deckId {
                onOpenDeck(deckId)
            } else if let lessonId = cta.lessonId,
                      let summary = viewModel.dashboardLessonSummary(lessonId: lessonId),
                      let deckId = summary.flashcardDeckIds.first {
                onOpenDeck(deckId)
            } else if let lessonId = cta.lessonId {
                viewModel.generateLessonArtifacts(lessonId: lessonId, kinds: [.flashcards])
            }
        }
    }

    private func openArtifact(summary: LessonDashboardSummary, kind: LessonArtifactKind) {
        switch kind {
        case .notes:
            if let guideId = summary.notesIds.first {
                onOpenStudyGuide(guideId)
            }
        case .quiz:
            if let examId = summary.quizIds.first {
                onOpenExam(examId)
            }
        case .flashcards:
            if let deckId = summary.flashcardDeckIds.first {
                onOpenDeck(deckId)
            }
        }
    }

    // MARK: - Visual Helpers

    @ViewBuilder
    private func emptyPanel(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.canvasBackground, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
    }

    private func urgencyColor(_ urgency: Int) -> Color {
        switch urgency {
        case 3:
            return Color.red
        case 2:
            return Color.orange
        default:
            return DesignSystem.Colors.studyAccentMid
        }
    }

    private func statusColor(_ status: ArtifactStatus) -> Color {
        switch status {
        case .ready:
            return DesignSystem.Colors.studyAccentBright
        case .inProgress:
            return Color.orange
        case .failed:
            return Color.red
        case .notStarted:
            return DesignSystem.Colors.tertiaryText
        }
    }
}
