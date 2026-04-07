import Foundation

// MARK: - TimeOfDay

struct TimeOfDay: Codable, Hashable {
  var hour: Int
  var minute: Int
}

// MARK: - RepeatSchedule

enum RepeatSchedule: Hashable {
  case once
  case daily(time: TimeOfDay)
  case weekdays(time: TimeOfDay)  // Mon–Fri
  case selectedWeekdays(weekdays: [Int], time: TimeOfDay)  // arbitrary weekdays (1=Sun…7=Sat)
  case weekly(weekday: Int, time: TimeOfDay)  // 1=Sun … 7=Sat
  case monthly(day: Int, time: TimeOfDay)  // every Nth day
  case yearly(month: Int, day: Int, time: TimeOfDay)  // every Month/Day

  var shortLabel: String {
    switch self {
    case .once: return String(localized: "ONCE")
    case .daily: return String(localized: "DAILY")
    case .weekdays: return String(localized: "WKDAYS")
    case .selectedWeekdays: return String(localized: "CUSTOM")
    case .weekly(let weekday, _):
      let labels = [
        String(localized: "SUN"), String(localized: "MON"), String(localized: "TUE"),
        String(localized: "WED"), String(localized: "THU"), String(localized: "FRI"),
        String(localized: "SAT"),
      ]
      guard weekday >= 1 && weekday <= 7 else { return String(localized: "WEEKLY") }
      return labels[weekday - 1]
    case .monthly: return String(localized: "MONTHLY")
    case .yearly: return String(localized: "YEARLY")
    }
  }

  /// Human-readable detail label shown in task cards (e.g. "Daily · 9:00 AM").
  var detailedLabel: String {
    func fmt(_ t: TimeOfDay) -> String {
      let langCode = Locale.current.language.languageCode?.identifier ?? ""
      switch langCode {
      case "ja":
        return String(format: "%d:%02d", t.hour, t.minute)
      case "ko":
        let h = t.hour % 12 == 0 ? 12 : t.hour % 12
        let suffix = t.hour < 12 ? "오전" : "오후"
        return String(format: "%@ %d:%02d", suffix, h, t.minute)
      default:
        let h = t.hour % 12 == 0 ? 12 : t.hour % 12
        let suffix = t.hour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, t.minute, suffix)
      }
    }
    let dayAbbr = [
      String(localized: "Su"),
      String(localized: "Mo"),
      String(localized: "Tu"),
      String(localized: "We"),
      String(localized: "Th"),
      String(localized: "Fr"),
      String(localized: "Sa"),
    ]
    let dayFull = [
      String(localized: "Sunday"),
      String(localized: "Monday"),
      String(localized: "Tuesday"),
      String(localized: "Wednesday"),
      String(localized: "Thursday"),
      String(localized: "Friday"),
      String(localized: "Saturday"),
    ]
    let months = [
      String(localized: "Jan"), String(localized: "Feb"), String(localized: "Mar"),
      String(localized: "Apr"), String(localized: "May"), String(localized: "Jun"),
      String(localized: "Jul"), String(localized: "Aug"), String(localized: "Sep"),
      String(localized: "Oct"), String(localized: "Nov"), String(localized: "Dec"),
    ]
    switch self {
    case .once:
      return String(localized: "One-time")
    case .daily(let t):
      return "\(String(localized: "Daily")) \(fmt(t))"
    case .weekdays(let t):
      return String(localized: "Mon–Fri") + " \(fmt(t))"
    case .selectedWeekdays(let days, let t):
      let names = days.sorted().compactMap { d -> String? in
        guard d >= 1 && d <= 7 else { return nil }
        return dayAbbr[d - 1]
      }.joined(separator: ", ")
      return "\(names) \(fmt(t))"
    case .weekly(let wd, let t):
      let name = (wd >= 1 && wd <= 7) ? dayFull[wd - 1] : "?"
      let everyName = String(format: String(localized: "Every %@"), name)
      return "\(everyName) \(fmt(t))"
    case .monthly(let d, let t):
      let monthlyStr = String(format: String(localized: "Every month %lld"), Int64(d))
      return "\(monthlyStr) \(fmt(t))"
    case .yearly(let m, let d, let t):
      let mName = (m >= 1 && m <= 12) ? months[m - 1] : "?"
      let yearlyStr = String(format: String(localized: "Every year %@ %lld"), mName, Int64(d))
      return "\(yearlyStr) \(fmt(t))"
    }
  }

  var timeOfDay: TimeOfDay? {
    switch self {
    case .once: return nil
    case .daily(let t): return t
    case .weekdays(let t): return t
    case .selectedWeekdays(_, let t): return t
    case .weekly(_, let t): return t
    case .monthly(_, let t): return t
    case .yearly(_, _, let t): return t
    }
  }

  var isRepeating: Bool {
    if case .once = self { return false }
    return true
  }
}

// MARK: - RepeatSchedule + Codable

extension RepeatSchedule: Codable {
  private enum CodingKeys: String, CodingKey {
    case type, time, weekday, weekdays, day, month
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .once:
      try c.encode("once", forKey: .type)
    case .daily(let time):
      try c.encode("daily", forKey: .type)
      try c.encode(time, forKey: .time)
    case .weekdays(let time):
      try c.encode("weekdays", forKey: .type)
      try c.encode(time, forKey: .time)
    case .selectedWeekdays(let weekdays, let time):
      try c.encode("selectedWeekdays", forKey: .type)
      try c.encode(weekdays, forKey: .weekdays)
      try c.encode(time, forKey: .time)
    case .weekly(let weekday, let time):
      try c.encode("weekly", forKey: .type)
      try c.encode(weekday, forKey: .weekday)
      try c.encode(time, forKey: .time)
    case .monthly(let day, let time):
      try c.encode("monthly", forKey: .type)
      try c.encode(day, forKey: .day)
      try c.encode(time, forKey: .time)
    case .yearly(let month, let day, let time):
      try c.encode("yearly", forKey: .type)
      try c.encode(month, forKey: .month)
      try c.encode(day, forKey: .day)
      try c.encode(time, forKey: .time)
    }
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let type = try c.decode(String.self, forKey: .type)
    switch type {
    case "daily":
      self = .daily(time: try c.decode(TimeOfDay.self, forKey: .time))
    case "weekdays":
      self = .weekdays(time: try c.decode(TimeOfDay.self, forKey: .time))
    case "selectedWeekdays":
      self = .selectedWeekdays(
        weekdays: try c.decode([Int].self, forKey: .weekdays),
        time: try c.decode(TimeOfDay.self, forKey: .time)
      )
    case "weekly":
      self = .weekly(
        weekday: try c.decode(Int.self, forKey: .weekday),
        time: try c.decode(TimeOfDay.self, forKey: .time)
      )
    case "monthly":
      self = .monthly(
        day: try c.decode(Int.self, forKey: .day),
        time: try c.decode(TimeOfDay.self, forKey: .time)
      )
    case "yearly":
      self = .yearly(
        month: try c.decode(Int.self, forKey: .month),
        day: try c.decode(Int.self, forKey: .day),
        time: try c.decode(TimeOfDay.self, forKey: .time)
      )
    default:
      self = .once
    }
  }
}
