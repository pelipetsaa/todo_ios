import Foundation
import Testing
@testable import TodoDomain

struct DomainTests {
    @Test(arguments: ["", "name", "a @b.com", "a@b", "a@@b.com", String(repeating: "a", count: 250) + "@b.com"])
    func rejectsInvalidEmails(_ email: String) { #expect(Validation.email(email) != nil) }

    @Test func acceptsTrimmedEmail() { #expect(Validation.email("  person+ios@example.com\n") == nil) }
    @Test func passwordRulesMatchServer() {
        #expect(Validation.password("short", registration: true) != nil)
        #expect(Validation.password("12345678", registration: true) == nil)
        #expect(Validation.password(String(repeating: "x", count: 129), registration: true) != nil)
        #expect(Validation.password("legacy", registration: false) == nil)
        #expect(Validation.password("", registration: false) != nil)
    }
    @Test func titleAndDescriptionLimits() {
        #expect(Validation.title(" \n ") != nil)
        #expect(Validation.title(String(repeating: "a", count: 200)) == nil)
        #expect(Validation.title(String(repeating: "a", count: 201)) != nil)
        #expect(Validation.description(String(repeating: "a", count: 2000)) == nil)
        #expect(Validation.description(String(repeating: "a", count: 2001)) != nil)
        #expect(TodoDraft(title: "  hello \n").normalized.title == "hello")
    }
    @Test func unicodeLimitsUseKotlinUTF16Length() {
        #expect(Validation.title(String(repeating: "😀", count: 100)) == nil)
        #expect(Validation.title(String(repeating: "😀", count: 101)) != nil)
        #expect(Validation.password(String(repeating: "😀", count: 4), registration: true) == nil)
        #expect(Validation.description(String(repeating: "😀", count: 1001)) != nil)
    }
    @Test func mondayWeekAcrossYearBoundary() {
        let range = TodoPeriod.week.range(at: instant("2027-01-03T15:00:00Z"), timeZone: TimeZone(secondsFromGMT: 0)!)
        #expect(range.start == instant("2026-12-28T00:00:00Z"))
        #expect(range.end == instant("2027-01-04T00:00:00Z"))
    }
    @Test func monthAndLeapYear() {
        let range = TodoPeriod.month.range(at: instant("2028-02-29T20:00:00Z"), timeZone: TimeZone(secondsFromGMT: 0)!)
        #expect(range.start == instant("2028-02-01T00:00:00Z"))
        #expect(range.end == instant("2028-03-01T00:00:00Z"))
    }
    @Test(arguments: [("2026-03-29T12:00:00Z", 23.0), ("2026-10-25T12:00:00Z", 25.0)])
    func daylightSavingDays(_ value: (String, Double)) {
        let range = TodoPeriod.today.range(at: instant(value.0), timeZone: TimeZone(identifier: "Europe/Warsaw")!)
        #expect(range.duration == value.1 * 3600)
    }
    @Test func nextFullHourCrossesMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(TodoDraft.nextHour(after: instant("2026-12-31T23:59:30Z"), calendar: calendar) == instant("2027-01-01T00:00:00Z"))
        #expect(TodoDraft.nextHour(after: instant("2026-12-31T10:00:00Z"), calendar: calendar) == instant("2026-12-31T11:00:00Z"))
    }
}

private func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
