import Foundation

extension UserSettings {
    var notificationTimeComponents: DateComponents {
        DateComponents(hour: notificationHour, minute: notificationMinute)
    }

    mutating func updateNotificationTime(hour: Int, minute: Int) {
        notificationHour = hour
        notificationMinute = minute
    }

    var learningStepsDurations: [TimeInterval] {
        learningStepsMinutes.map { $0 * 60.0 }
    }

    var lapseStepsDurations: [TimeInterval] {
        lapseStepsMinutes.map { $0 * 60.0 }
    }

    var retentionPercentage: Int {
        Int((retentionTarget * 100).rounded())
    }
}
