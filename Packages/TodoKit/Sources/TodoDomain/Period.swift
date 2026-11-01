import Foundation

public enum TodoPeriod: String, CaseIterable, Identifiable, Sendable {
    case today, week, month
    public var id: String { rawValue }

    /// Monday–Sunday in the device's time zone; end is exclusive. Calendar arithmetic preserves DST.
    public func range(at now: Date = .now, timeZone: TimeZone = .current) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let component: Calendar.Component = switch self {
        case .today: .day
        case .week: .weekOfYear
        case .month: .month
        }
        return calendar.dateInterval(of: component, for: now)!
    }
}
