import AppKit

enum MeetingService: String, CaseIterable {
    case meet, zoom, teams, webex, slack, whereby, around, chime, goto, jitsi, discord, facetime, skype, other

    var name: String {
        switch self {
        case .meet: "Google Meet"
        case .zoom: "Zoom"
        case .teams: "Teams"
        case .webex: "Webex"
        case .slack: "Slack huddle"
        case .whereby: "Whereby"
        case .around: "Around"
        case .chime: "Chime"
        case .goto: "GoTo Meeting"
        case .jitsi: "Jitsi"
        case .discord: "Discord"
        case .facetime: "FaceTime"
        case .skype: "Skype"
        case .other: "meeting"
        }
    }

    /// Start of a join URL for this service. The detector appends the rest of the URL.
    fileprivate var urlPrefix: String? {
        switch self {
        case .meet: #"https?://meet\.google\.com/"#
        case .zoom: #"https?://(?:[a-z0-9-]+\.)*zoom(?:gov)?\.(?:us|com)/(?:j|my|w|s|wc/join)/"#
        case .teams: #"https?://teams\.(?:microsoft|live)\.com/(?:l/meetup-join|meet|dl/launcher)/"#
        case .webex: #"https?://(?:[a-z0-9-]+\.)*webex\.com/(?:meet/|join/|[a-z0-9-]+/j\.php)"#
        case .slack: #"https?://app\.slack\.com/huddle/"#
        case .whereby: #"https?://(?:[a-z0-9-]+\.)?whereby\.com/"#
        case .around: #"https?://(?:meet\.)?around\.co/"#
        case .chime: #"https?://(?:app\.)?chime\.aws/"#
        case .goto: #"https?://(?:global\.gotomeeting\.com/join|meet\.goto\.com|app\.goto\.com/meeting|gotomeet\.me)/"#
        case .jitsi: #"https?://meet\.jit\.si/"#
        case .discord: #"https?://(?:(?:www\.)?discord(?:app)?\.com/channels|discord\.gg)/"#
        case .facetime: #"https?://facetime\.apple\.com/join"#
        case .skype: #"https?://join\.skype\.com/"#
        case .other: nil
        }
    }
}

struct MeetingLink: Equatable {
    let service: MeetingService
    let url: URL

    /// The URL to open. Meet links get the right Google account, Zoom and Teams
    /// links go straight to their desktop apps when installed.
    @MainActor
    func launchURL(accountEmail: String?) -> URL {
        switch service {
        case .meet: meetURL(accountEmail: accountEmail)
        case .zoom: zoomAppURL() ?? url
        case .teams: teamsAppURL() ?? url
        default: url
        }
    }

    private func meetURL(accountEmail: String?) -> URL {
        guard let accountEmail, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = components.queryItems ?? []
        guard !items.contains(where: { $0.name == "authuser" }) else { return url }
        items.append(URLQueryItem(name: "authuser", value: accountEmail))
        components.queryItems = items
        return components.url ?? url
    }

    @MainActor
    private func zoomAppURL() -> URL? {
        guard Self.hasApp(for: "zoommtg://"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else { return nil }
        let parts = components.path.split(separator: "/")
        guard parts.count >= 2, parts[0] == "j" || parts[0] == "w" else { return nil }
        var app = URLComponents()
        app.scheme = "zoommtg"
        app.host = host
        app.path = "/join"
        var items = [URLQueryItem(name: "action", value: "join"), URLQueryItem(name: "confno", value: String(parts[1]))]
        if let password = components.queryItems?.first(where: { $0.name == "pwd" })?.value {
            items.append(URLQueryItem(name: "pwd", value: password))
        }
        app.queryItems = items
        return app.url
    }

    @MainActor
    private func teamsAppURL() -> URL? {
        guard url.host == "teams.microsoft.com",
              url.path.hasPrefix("/l/meetup-join/"),
              Self.hasApp(for: "msteams:"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var string = "msteams:" + components.percentEncodedPath
        if let query = components.percentEncodedQuery {
            string += "?" + query
        }
        return URL(string: string)
    }

    @MainActor
    private static func hasApp(for scheme: String) -> Bool {
        guard let probe = URL(string: scheme) else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: probe) != nil
    }
}

enum MeetingLinkDetector {
    private static let urlTail = #"[^\s<>"'()\[\]{}]+"#

    private static let rules: [(service: MeetingService, regex: NSRegularExpression)] =
        MeetingService.allCases.compactMap { service -> (service: MeetingService, regex: NSRegularExpression)? in
            guard let prefix = service.urlPrefix,
                  let regex = try? NSRegularExpression(pattern: prefix + MeetingLinkDetector.urlTail, options: [.caseInsensitive])
            else { return nil }
            return (service: service, regex: regex)
        }

    private static let safeLinks = try? NSRegularExpression(
        pattern: #"https?://[a-z0-9.-]*safelinks\.protection\.outlook\.com/\?[^\s<>"']+"#,
        options: [.caseInsensitive]
    )

    /// Looks for a join link in the event URL, then location, then notes, the same
    /// order Notion Calendar uses. Falls back to a plain URL in the location field.
    static func detect(url: URL?, location: String?, notes: String?) -> MeetingLink? {
        for case let text? in [url?.absoluteString, location, notes] where !text.isEmpty {
            if let link = firstLink(in: unwrapSafeLinks(text)) {
                return link
            }
        }
        return plainURL(in: location)
    }

    private static func firstLink(in text: String) -> MeetingLink? {
        let searchRange = NSRange(text.startIndex..., in: text)
        var best: (range: NSRange, service: MeetingService)?
        for rule in rules {
            guard let match = rule.regex.firstMatch(in: text, range: searchRange) else { continue }
            if match.range.location < (best?.range.location ?? Int.max) {
                best = (range: match.range, service: rule.service)
            }
        }
        guard let best,
              let range = Range(best.range, in: text),
              let url = URL(string: trimmed(String(text[range]))) else { return nil }
        return MeetingLink(service: best.service, url: url)
    }

    private static func trimmed(_ raw: String) -> String {
        var value = raw.replacingOccurrences(of: "&amp;", with: "&")
        while let last = value.last, ".,;:!?*".contains(last) {
            value.removeLast()
        }
        return value
    }

    private static func plainURL(in location: String?) -> MeetingLink? {
        guard let value = location?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.contains(" "),
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              url.host != nil else { return nil }
        return MeetingLink(service: .other, url: url)
    }

    /// Outlook wraps links in safelinks.protection.outlook.com redirects. Swap in the real URL.
    private static func unwrapSafeLinks(_ text: String) -> String {
        guard let regex = safeLinks, text.contains("safelinks") else { return text }
        var result = text as NSString
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            let wrapped = result.substring(with: match.range).replacingOccurrences(of: "&amp;", with: "&")
            guard let target = URLComponents(string: wrapped)?.queryItems?.first(where: { $0.name == "url" })?.value else { continue }
            result = result.replacingCharacters(in: match.range, with: target) as NSString
        }
        return result as String
    }
}
