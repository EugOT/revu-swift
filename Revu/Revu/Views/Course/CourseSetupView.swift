import SwiftUI

struct CourseSetupView: View {
    var existingCourse: Course?
    var onCourseCreated: (Course) -> Void
    var onCancel: () -> Void

    @State private var name: String = ""
    @State private var courseCode: String = ""
    @State private var examDate: Date? = nil
    @State private var hasExamDate: Bool = false
    @State private var weeklyTimeBudgetMinutes: String = ""
    @State private var selectedColorHex: String? = nil

    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { existingCourse != nil }

    private let colorChoices = ["#6366F1", "#8B5CF6", "#EC4899", "#F43F5E", "#F97316", "#10B981"]

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(isEditing ? "Edit Course" : "New Course")
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text(isEditing ? "Update your course details" : "Set up your course to organize study materials")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            .padding(.bottom, DesignSystem.Spacing.lg)

            // Form fields
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Course name (required)
                fieldSection("Course name") {
                    DesignSystemTextField(placeholder: "e.g. Linear Algebra", text: $name)
                }

                // Course code (optional)
                fieldSection("Course code", optional: true) {
                    DesignSystemTextField(placeholder: "e.g. MATH 221", text: $courseCode)
                }

                // Exam date toggle + picker
                fieldSection("Exam date", optional: true) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Set an exam date")
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                            Spacer()
                            DesignSystemToggle(isOn: $hasExamDate.animation(DesignSystem.Animation.quick))
                        }

                        if hasExamDate {
                            DatePicker(
                                "Exam date",
                                selection: Binding(
                                    get: { examDate ?? Date() },
                                    set: { examDate = $0 }
                                ),
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.field)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                // Weekly time budget
                fieldSection("Weekly study budget", optional: true) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        DesignSystemTextField(placeholder: "120", text: $weeklyTimeBudgetMinutes)
                            .frame(width: 100)
                            .onChange(of: weeklyTimeBudgetMinutes) { _, newValue in
                                weeklyTimeBudgetMinutes = newValue.filter { $0.isNumber }
                            }

                        Text("minutes per week")
                            .font(DesignSystem.Typography.small)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                }

                // Color picker
                fieldSection("Color") {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(colorChoices, id: \.self) { hex in
                            colorCircle(hex: hex)
                        }
                    }
                }
            }

            Spacer(minLength: DesignSystem.Spacing.lg)

            // Separator
            Rectangle()
                .fill(DesignSystem.Colors.separator)
                .frame(height: 1)
                .padding(.horizontal, -DesignSystem.Spacing.lg)

            // Bottom bar
            HStack {
                Button {
                    onCancel()
                    dismiss()
                } label: {
                    Text("Cancel")
                        .secondaryButtonStyle()
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    createCourse()
                } label: {
                    Text(isEditing ? "Save Changes" : "Create Course")
                        .primaryButtonStyle()
                }
                .buttonStyle(.plain)
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1.0 : 0.5)
            }
            .padding(.top, DesignSystem.Spacing.md)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(minWidth: 440)
        .background(DesignSystem.Colors.canvasBackground)
        .onAppear {
            if let course = existingCourse {
                name = course.name
                courseCode = course.courseCode ?? ""
                examDate = course.examDate
                hasExamDate = course.examDate != nil
                weeklyTimeBudgetMinutes = course.weeklyTimeBudgetMinutes.map { String($0) } ?? ""
                selectedColorHex = course.colorHex
            }
        }
    }

    // MARK: - Subviews

    private func fieldSection<Content: View>(
        _ title: String,
        optional: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Text(title)
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                if optional {
                    Text("optional")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
            }

            content()
        }
    }

    private func colorCircle(hex: String) -> some View {
        let isSelected = selectedColorHex == hex

        return Circle()
            .fill(Color(hex: String(hex.dropFirst())))
            .frame(width: 28, height: 28)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2.5)
            )
            .overlay(
                Circle()
                    .strokeBorder(DesignSystem.Colors.separator.opacity(isSelected ? 0 : 0.5), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isSelected)
            .onTapGesture {
                selectedColorHex = (selectedColorHex == hex) ? nil : hex
            }
    }

    // MARK: - Actions

    private func createCourse() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let budget: Int? = if let val = Int(weeklyTimeBudgetMinutes), val > 0 {
            val
        } else {
            nil
        }

        var course: Course
        if let existing = existingCourse {
            course = existing
            course.name = trimmedName
            course.courseCode = courseCode.isEmpty ? nil : courseCode.trimmingCharacters(in: .whitespaces)
            course.examDate = hasExamDate ? (examDate ?? Date()) : nil
            course.weeklyTimeBudgetMinutes = budget
            course.colorHex = selectedColorHex
        } else {
            course = Course(
                name: trimmedName,
                courseCode: courseCode.isEmpty ? nil : courseCode.trimmingCharacters(in: .whitespaces),
                examDate: hasExamDate ? (examDate ?? Date()) : nil,
                weeklyTimeBudgetMinutes: budget,
                colorHex: selectedColorHex
            )
        }

        onCourseCreated(course)
        dismiss()
    }
}
