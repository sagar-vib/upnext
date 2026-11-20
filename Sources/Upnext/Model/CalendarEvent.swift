import EventKit
import SwiftUI

enum ResponseStatus {
    case accepted, declined, tentative, pending, none

    init(_ status: EKParticipantStatus) {
        switch status {
        case .accepted, .delegated: self = .accepted
        case .declined: self = .declined
        case .tentative: self = .tentative
        case .pending: self = .pending
        default: self = .none
        }
    }
}

struct Attendee {
    let name: String
    let email: String?
    let status: ResponseStatus
}

struct CalendarInfo: Identifiable {
    let id: String
    let title: String
    let color: Color
}

struct CalendarGroup: Identifiable {
    let id: String
    let calendars: [CalendarInfo]
}

struct CalendarEvent: Identifiable {
    let id: String
    let eventIdentifier: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let isCanceled: Bool
    let location: String?
    let notesSummary: String?
    let color: Color
    let accountEmail: String?
    let guests: [Attendee]
    let rooms: [String]
    let myStatus: ResponseStatus
    let meeting: MeetingLink?

    init(_ event: EKEvent) {
        let start: Date = event.startDate ?? Date()
        let identifier: String = event.eventIdentifier ?? event.calendarItemIdentifier
        let rawTitle = (event.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let rawLocation = (event.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        self.id = "\(identifier)|\(start.timeIntervalSince1970)"
        self.eventIdentifier = identifier
        self.title = rawTitle.isEmpty ? "(No title)" : rawTitle
        self.start = start
        self.end = event.endDate ?? start
        self.isAllDay = event.isAllDay
        self.isCanceled = event.status == .canceled
        self.location = rawLocation.isEmpty ? nil : rawLocation
        self.notesSummary = NotesCleaner.summary(event.notes)
        self.color = Color(nsColor: event.calendar?.color ?? .systemBlue)
        self.meeting = MeetingLinkDetector.detect(url: event.url, location: event.location, notes: event.notes)

        let participants = event.attendees ?? []
        let me = participants.first { $0.isCurrentUser }
        var guests: [Attendee] = []
        var rooms: [String] = []
        for participant in participants where !participant.isCurrentUser {
            let email = Self.email(of: participant)
            if Self.isRoom(participant, email: email) {
                rooms.append(participant.name ?? email ?? "Room")
            } else {
                guests.append(Attendee(name: participant.name ?? email ?? "Guest", email: email, status: ResponseStatus(participant.participantStatus)))
            }
        }
        self.guests = guests
        self.rooms = rooms

        if let me {
            self.myStatus = ResponseStatus(me.participantStatus)
        } else {
            // You organised it, or the calendar doesn't report your own response.
            self.myStatus = guests.isEmpty ? .none : .accepted
        }

        let sourceTitle = event.calendar?.source?.title
        self.accountEmail = me.flatMap(Self.email(of:)) ?? (sourceTitle?.contains("@") == true ? sourceTitle : nil)
    }

    func isOngoing(at now: Date) -> Bool {
        !isAllDay && start <= now && now < end
    }

    var needsResponse: Bool { myStatus == .pending || myStatus == .tentative }
    var isMeeting: Bool { meeting != nil || !guests.isEmpty }
    var dedupeKey: String { "\(title)|\(start.timeIntervalSince1970)|\(end.timeIntervalSince1970)" }

    /// The location, unless it's only the meeting URL.
    var displayLocation: String? {
        guard let location else { return nil }
        return location.range(of: #"^https?://\S+$"#, options: .regularExpression) == nil ? location : nil
    }

    private static func email(of participant: EKParticipant) -> String? {
        let raw = participant.url.absoluteString
        guard raw.lowercased().hasPrefix("mailto:") else { return nil }
        let email = String(raw.dropFirst("mailto:".count)).removingPercentEncoding ?? ""
        return email.contains("@") ? email : nil
    }

    private static func isRoom(_ participant: EKParticipant, email: String?) -> Bool {
        participant.participantType == .room
            || participant.participantType == .resource
            || email?.hasSuffix("resource.calendar.google.com") == true
    }
}

enum NotesCleaner {
    /// Plain-text preview of event notes, without HTML or the conferencing
    /// boilerplate Google and Teams add to invites.
    static func summary(_ notes: String?) -> String? {
        guard var text = notes, !text.isEmpty else { return nil }
        text = text.replacingOccurrences(of: #"(?i)<br\s*/?>|</p>|</div>|</li>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        let entities: [(entity: String, character: String)] = [
            ("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&"),
        ]
        for pair in entities {
            text = text.replacingOccurrences(of: pair.entity, with: pair.character)
        }
        text = text.replacingOccurrences(of: #"-::~[:~]+::-[\s\S]*?(?:-::~[:~]+::-|$)"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"_{10,}[\s\S]*$"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(400))
    }
}
