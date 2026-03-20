import Foundation
import Combine

extension Card {
    var displayPrompt: String {
        switch kind {
        case .basic:
            return front
        case .cloze:
            guard let source = clozeSource else { return front }
            return ClozeRenderer.prompt(from: source)
        case .multipleChoice:
            return front
        }
    }

    var displayAnswer: String {
        switch kind {
        case .basic:
            return back
        case .cloze:
            guard let source = clozeSource else { return back }
            return ClozeRenderer.answer(from: source)
        case .multipleChoice:
            if !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return back
            }
            guard let index = correctChoiceIndex, choices.indices.contains(index) else { return "" }
            return choices[index]
        }
    }

    var displayChoices: [String] {
        switch kind {
        case .multipleChoice:
            return choices
        case .basic, .cloze:
            return []
        }
    }
}

extension SRSState {
    /// Blends current recall probability and long-term stability into a single mastery score.
    /// Values are clamped between 0 and 1 for direct use in progress indicators.
    func masteryProgress(retentionTarget: Double = AppSettingsDefaults.retentionTarget, referenceDate: Date = Date()) -> Double {
        if fsrsReps == 0 {
            return 0
        }
        let recall = predictedRecall(on: referenceDate, retentionTarget: retentionTarget)
        let normalizedStability = min(max(stability / 25.0, 0), 1)
        let blended = (recall * 0.65) + (normalizedStability * 0.35)
        return min(max(blended, 0), 1)
    }
}

enum ClozeRenderer {
    /// Public representation of a linear cloze fragment stream (for rendering)
    enum LinearFragment: Equatable {
        case text(String)
        case deletion(index: Int, answer: String, hint: String?)
    }

    /// Returns the linear fragments in reading order for the given cloze source.
    /// Text and deletion entries are preserved as they appear in the string.
    static func linearFragments(from source: String) -> [LinearFragment] {
        let raw = parse(source: source)
        guard !raw.isEmpty else { return [.text(source)] }
        return raw.map { frag in
            switch frag {
            case .text(let s):
                return .text(s)
            case .deletion(let d):
                return .deletion(index: d.index, answer: d.answer, hint: d.hint)
            }
        }
    }

    static func prompt(from source: String) -> String {
        let fragments = parse(source: source)
        guard !fragments.isEmpty else { return source }
        return fragments.map { fragment -> String in
            switch fragment {
            case .text(let value):
                return value
            case .deletion(let deletion):
                return placeholder(for: deletion)
            }
        }.joined()
    }

    static func answer(from source: String) -> String {
        let deletions = parse(source: source).compactMap { fragment -> Deletion? in
            if case let .deletion(value) = fragment {
                return value
            }
            return nil
        }
        guard !deletions.isEmpty else { return source }

        let grouped = Dictionary(grouping: deletions, by: { $0.index })
        let sortedKeys = grouped.keys.sorted()
        let lines = sortedKeys.map { index -> String in
            let entries = grouped[index] ?? []
            let answers = uniqueAnswers(from: entries.map(\.answer))
            let answerText = answers.isEmpty ? "—" : answers.joined(separator: " / ")
            var line = "\(index). \(answerText)"
            if let hint = firstHint(from: entries) {
                line += " _(hint: \(hint))_"
            }
            return line
        }
        return lines.joined(separator: "\n")
    }

    static func extractedAnswers(from source: String) -> [String] {
        let fragments = linearFragments(from: source)
        var seen = Set<String>()
        var ordered: [String] = []
        for fragment in fragments {
            guard case .deletion(_, let answer, _) = fragment else { continue }
            let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                ordered.append(trimmed)
            }
        }
        return ordered
    }

    // MARK: - Parsing helpers

    private struct Deletion {
        let index: Int
        let answer: String
        let hint: String?
    }

    private enum Fragment {
        case text(String)
        case deletion(Deletion)
    }

    private static let deletionRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\{\{c(\d+)::(.*?)\}\}"#,
        options: [.dotMatchesLineSeparators]
    )

    private static func parse(source: String) -> [Fragment] {
        guard let regex = deletionRegex else {
            return [.text(source)]
        }
        let nsRange = NSRange(source.startIndex..., in: source)
        let matches = regex.matches(in: source, range: nsRange)
        guard !matches.isEmpty else { return [.text(source)] }

        var fragments: [Fragment] = []
        var cursor = source.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: source) else { continue }
            if cursor < matchRange.lowerBound {
                let textSegment = String(source[cursor..<matchRange.lowerBound])
                fragments.append(.text(textSegment))
            }

            guard
                let indexRange = Range(match.range(at: 1), in: source),
                let bodyRange = Range(match.range(at: 2), in: source)
            else {
                fragments.append(.text(String(source[matchRange])))
                cursor = matchRange.upperBound
                continue
            }

            let indexValue = Int(source[indexRange]) ?? 0
            let body = String(source[bodyRange])
            let (answer, hint) = splitBody(body)
            let deletion = Deletion(index: indexValue, answer: answer, hint: hint)
            fragments.append(.deletion(deletion))
            cursor = matchRange.upperBound
        }

        if cursor < source.endIndex {
            fragments.append(.text(String(source[cursor...])))
        }

        return fragments
    }

    private static func splitBody(_ body: String) -> (answer: String, hint: String?) {
        guard let range = body.range(of: "::") else {
            return (body.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        let answer = String(body[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let hint = String(body[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (answer, hint.isEmpty ? nil : hint)
    }

    private static func placeholder(for deletion: Deletion) -> String {
        let indexText = deletion.index > 0 ? "\(deletion.index)" : "…"
        if let hint = deletion.hint, !hint.isEmpty {
            return "[\(indexText) | \(hint)]"
        }
        return "[\(indexText)]"
    }

    private static func uniqueAnswers(from answers: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for raw in answers {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                ordered.append(trimmed)
            }
        }
        return ordered
    }

    private static func firstHint(from deletions: [Deletion]) -> String? {
        for deletion in deletions {
            if let hint = deletion.hint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
                return hint
            }
        }
        return nil
    }
}

// MARK: - DTO Conversions

extension DeckDTO {
    func toDomain() -> Deck {
        Deck(
            id: id,
            parentId: parentId,
            courseId: courseId,
            originLessonId: originLessonId,
            kind: kind,
            name: name,
            note: note,
            dueDate: dueDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isArchived: isArchived
        )
    }
}

extension Deck {
    func toDTO() -> DeckDTO {
        DeckDTO(
            id: id,
            parentId: parentId,
            courseId: courseId,
            originLessonId: originLessonId,
            kind: kind,
            name: name,
            note: note,
            dueDate: dueDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isArchived: isArchived
        )
    }
}

extension SRSStateDTO {
    func toDomain() -> SRSState {
        SRSState(
            id: id,
            cardId: cardId,
            easeFactor: easeFactor,
            interval: interval,
            repetitions: repetitions,
            lapses: lapses,
            dueDate: dueDate,
            lastReviewed: lastReviewed,
            queue: SRSState.Queue(rawValue: queue.rawValue) ?? .new,
            stability: stability,
            difficulty: difficulty,
            fsrsReps: fsrsReps,
            lastElapsedSeconds: lastElapsedSeconds
        )
    }
}

extension SRSState {
    func toDTO() -> SRSStateDTO {
        SRSStateDTO(
            id: id,
            cardId: cardId,
            easeFactor: easeFactor,
            interval: interval,
            repetitions: repetitions,
            lapses: lapses,
            dueDate: dueDate,
            lastReviewed: lastReviewed,
            queue: SRSStateDTO.Queue(rawValue: queue.rawValue) ?? .new,
            stability: stability,
            difficulty: difficulty,
            fsrsReps: fsrsReps,
            lastElapsedSeconds: lastElapsedSeconds
        )
    }
}

extension CardDTO {
    func toDomain() -> Card {
        Card(
            id: id,
            deckId: deckId,
            kind: Card.Kind(rawValue: kind.rawValue) ?? .basic,
            front: front,
            back: back,
            clozeSource: clozeSource,
            choices: choices,
            correctChoiceIndex: correctChoiceIndex,
            tags: tags,
            sourceRef: sourceRef,
            media: media,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isSuspended: isSuspended,
            suspendedByArchive: suspendedByArchive,
            srs: srs.toDomain()
        )
    }
}

extension Card {
    func toDTO() -> CardDTO {
        CardDTO(
            id: id,
            deckId: deckId,
            kind: CardDTO.Kind(rawValue: kind.rawValue) ?? .basic,
            front: front,
            back: back,
            clozeSource: clozeSource,
            choices: choices,
            correctChoiceIndex: correctChoiceIndex,
            tags: tags,
            sourceRef: sourceRef,
            media: media,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isSuspended: isSuspended,
            suspendedByArchive: suspendedByArchive,
            srs: srs.toDTO()
        )
    }
}

extension ReviewLogDTO {
    func toDomain() -> ReviewLog {
        ReviewLog(
            id: id,
            cardId: cardId,
            timestamp: timestamp,
            grade: grade,
            elapsedMs: elapsedMs,
            prevInterval: prevInterval,
            nextInterval: nextInterval,
            prevEase: prevEase,
            nextEase: nextEase,
            prevStability: prevStability,
            nextStability: nextStability,
            prevDifficulty: prevDifficulty,
            nextDifficulty: nextDifficulty,
            predictedRecall: predictedRecall,
            requestedRetention: requestedRetention
        )
    }
}

extension ReviewLog {
    func toDTO() -> ReviewLogDTO {
        ReviewLogDTO(
            id: id,
            cardId: cardId,
            timestamp: timestamp,
            grade: grade,
            elapsedMs: elapsedMs,
            prevInterval: prevInterval,
            nextInterval: nextInterval,
            prevEase: prevEase,
            nextEase: nextEase,
            prevStability: prevStability,
            nextStability: nextStability,
            prevDifficulty: prevDifficulty,
            nextDifficulty: nextDifficulty,
            predictedRecall: predictedRecall,
            requestedRetention: requestedRetention
        )
    }
}

extension UserSettingsDTO {
    func toDomain() -> UserSettings {
        let appearance: AppearanceMode
        if let modeString = appearanceMode, let mode = AppearanceMode(rawValue: modeString) {
            appearance = mode
        } else {
            appearance = .system
        }
        
        let sortMode: DeckSortMode
        if let modeString = deckSortMode, let mode = DeckSortMode(rawValue: modeString) {
            sortMode = mode
        } else {
            sortMode = .manual
        }

        let sensitivity: InterventionSensitivity
        if let modeString = interventionSensitivity, let mode = InterventionSensitivity(rawValue: modeString) {
            sensitivity = mode
        } else {
            sensitivity = AppSettingsDefaults.interventionSensitivity
        }

        let celebration: CelebrationIntensity
        if let intensityString = celebrationIntensity, let mode = CelebrationIntensity(rawValue: intensityString) {
            celebration = mode
        } else {
            celebration = AppSettingsDefaults.celebrationIntensity
        }
        
        return UserSettings(
            id: id,
            dailyNewLimit: dailyNewLimit,
            dailyReviewLimit: dailyReviewLimit,
            learningStepsMinutes: learningStepsMinutes,
            lapseStepsMinutes: lapseStepsMinutes,
            easeMin: easeMin,
            burySiblings: burySiblings,
            keyboardHints: keyboardHints,
            autoAdvance: autoAdvance,
            retentionTarget: retentionTarget,
            enableResponseTimeTuning: enableResponseTimeTuning,
            proactiveInterventionsEnabled: proactiveInterventionsEnabled,
            interventionSensitivity: sensitivity,
            interventionCooldownMinutes: interventionCooldownMinutes,
            challengeModeDefaultEnabled: challengeModeDefaultEnabled ?? AppSettingsDefaults.challengeModeDefaultEnabled,
            celebrationIntensity: celebration,
            dailyGoalTarget: dailyGoalTarget ?? AppSettingsDefaults.dailyGoalTarget,
            useCloudSync: useCloudSync,
            notificationsEnabled: notificationsEnabled,
            notificationHour: notificationHour,
            notificationMinute: notificationMinute,
            dataLocationBookmark: dataLocationBookmark,
            appearanceMode: appearance,
            deckSortOrder: deckSortOrder ?? [],
            deckSortMode: sortMode,
            hasCompletedOnboarding: hasCompletedOnboarding ?? true,
            userName: (userName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? userName! : AppSettingsDefaults.userName),
            studyGoal: (studyGoal?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? studyGoal! : AppSettingsDefaults.studyGoal)
        )
    }
}

extension UserSettings {
    func toDTO() -> UserSettingsDTO {
        UserSettingsDTO(
            id: id,
            dailyNewLimit: dailyNewLimit,
            dailyReviewLimit: dailyReviewLimit,
            learningStepsMinutes: learningStepsMinutes,
            lapseStepsMinutes: lapseStepsMinutes,
            easeMin: easeMin,
            burySiblings: burySiblings,
            keyboardHints: keyboardHints,
            autoAdvance: autoAdvance,
            retentionTarget: retentionTarget,
            enableResponseTimeTuning: enableResponseTimeTuning,
            proactiveInterventionsEnabled: proactiveInterventionsEnabled,
            interventionSensitivity: interventionSensitivity.rawValue,
            interventionCooldownMinutes: interventionCooldownMinutes,
            challengeModeDefaultEnabled: challengeModeDefaultEnabled,
            celebrationIntensity: celebrationIntensity.rawValue,
            dailyGoalTarget: dailyGoalTarget,
            useCloudSync: useCloudSync,
            notificationsEnabled: notificationsEnabled,
            notificationHour: notificationHour,
            notificationMinute: notificationMinute,
            dataLocationBookmark: dataLocationBookmark,
            appearanceMode: appearanceMode.rawValue,
            deckSortOrder: deckSortOrder,
            deckSortMode: deckSortMode.rawValue,
            hasCompletedOnboarding: hasCompletedOnboarding,
            userName: userName,
            studyGoal: studyGoal
        )
    }
}
