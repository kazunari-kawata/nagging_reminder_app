import SwiftUI

// MARK: - AppTheme

enum AppTheme: String, Codable, CaseIterable {
  case auto, light, dark

  var colorScheme: ColorScheme? {
    switch self {
    case .auto: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }

  var displayName: String {
    switch self {
    case .auto: return "Auto"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }
}

// MARK: - WeekStart

enum WeekStart: String, Codable, CaseIterable {
  case sunday, monday, saturday

  var displayName: String {
    switch self {
    case .sunday: return "Sunday"
    case .monday: return "Monday"
    case .saturday: return "Saturday"
    }
  }
}

// MARK: - AppSettings

@Observable final class AppSettings {
  var theme: AppTheme = .auto {
    didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appTheme") }
  }
  var weekStart: WeekStart = .sunday {
    didSet { UserDefaults.standard.set(weekStart.rawValue, forKey: "weekStart") }
  }
  var privacyNoticeAccepted: Bool = false {
    didSet { UserDefaults.standard.set(privacyNoticeAccepted, forKey: "privacyNoticeAccepted") }
  }

  init() {
    if let raw = UserDefaults.standard.string(forKey: "appTheme"),
      let saved = AppTheme(rawValue: raw)
    {
      theme = saved
    }
    if let raw = UserDefaults.standard.string(forKey: "weekStart"),
      let saved = WeekStart(rawValue: raw)
    {
      weekStart = saved
    }
    privacyNoticeAccepted = UserDefaults.standard.bool(forKey: "privacyNoticeAccepted")
  }
}
