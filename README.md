# Upnext

A native macOS menu bar calendar modeled on Notion Calendar's menu bar widget. SwiftUI + AppKit, no dependencies.

## What it does

| Notion Calendar menu bar | Upnext |
|---|---|
| Next event title and countdown in the menu bar | Yes. `▍Weekly sync · in 5m`, then `20m left` once it starts. A date icon shows only when nothing is coming up |
| "Preview upcoming event" lead time, title/time toggles | Yes, in Settings > Menu bar |
| Dropdown with upcoming events grouped by day | Yes, as a timeline: meetings with no free time between them share one colored bar, labelled Back to back or Overlaps 15 min where each joins the last; free time shows as a small row, and declined meetings (struck through) then all-day events sit at the bottom of each day with a dimmed bar. When the next meeting follows straight on from the top one, the top meeting's bar runs down into the list and its Join button moves in beside it. Today's meetings follow the top card with no extra header; a later first day is labelled Upcoming, and days with nothing on are skipped. Times include the duration, e.g. `9:30 PM - 9:55 PM (25 min)` |
| Big "Join Google Meet" button for the current/next meeting | Yes, in a band across the top of the dropdown. Click it to show or hide each guest's email address and reply (accepted, declined, maybe or no reply). Meet, Zoom, Teams, Webex, Slack huddles, Whereby, Around, Chime, GoTo, Jitsi, Discord, FaceTime, Skype |
| Quick actions: join a meeting | Yes. The top card's Join button, Join on hovering any row, ⌥V, or Return in the dropdown |
| Meeting ended early | Click the checkmark on the top card, or press ⌘D in the dropdown, and Upnext moves on to the next meeting. Undo with Restore in the ⋯ menu until the meeting's scheduled end |
| Event details: guests and their RSVP, rooms, notes | Yes, click a row |
| Include events: days, all-day, without participants, without conferencing/location | Yes, plus declined events, in Settings > Menu bar |
| Hide events by title | Yes, in Settings > Menu bar > Hide events titled. "Out of office" is listed by default. The whole title must match, ignoring case |
| Late-night meetings count toward the day they belong to | Yes. A day runs from 4 AM to 4 AM by default, so a 12:30 AM call stays under today. Change it in Settings > Menu bar > New day starts at |
| Hide individual calendars from the menu bar | Yes, in Settings > Calendars (also stops their alerts) |
| Upcoming meeting popup with Join button, over full screen apps | Yes, top right. Plays a macOS sound or any audio file macOS can decode (not Ogg or WebM; Upnext checks when you choose one). Settings > Notifications |
| Global shortcuts: toggle menu bar calendar, join next meeting | ⌥K and ⌥V (Cron's defaults). Return joins, ⌘D marks the current meeting done and Esc closes inside the dropdown |
| Open at login | Yes |
| Change your RSVP from the menu bar | No. macOS's calendar framework is read-only for responses. Use "Open in Calendar" |

Small extras: Meet links open with your Google account (`authuser`), Zoom and Teams links open straight in their apps when installed, Outlook SafeLinks are unwrapped, duplicate copies of the same meeting across calendars are merged, and canceled events are hidden.

## Where the events come from

Upnext reads every calendar account on the Mac through EventKit. For Google Calendar, add the account in **System Settings > Internet Accounts > Google** with Calendars turned on. iCloud, Exchange/Outlook and CalDAV accounts work the same way. No OAuth setup or Google Cloud project is needed.

## Requirements

- macOS 14 Sonoma or later
- The Command Line Tools (`xcode-select --install`) or Xcode 16+

## Build and install

```bash
git clone https://github.com/sagar-vib/upnext.git && cd upnext && ./build.sh --install
```

That builds a release binary, wraps it in `Upnext.app`, signs it ad hoc, copies it to `/Applications` and launches it. Run `./build.sh` without `--install` to build and launch from `./build` instead.

On first launch macOS asks for calendar access. If you dismiss it, click the menu bar icon and choose **Allow Calendar Access**, or enable Upnext in System Settings > Privacy & Security > Calendars.

### Keeping calendar permission across rebuilds

Ad hoc signatures change on every build, so macOS may ask for calendar access again after a rebuild. Sign with your own certificate to avoid that:

```bash
CODESIGN_IDENTITY="Apple Development: you@example.com" ./build.sh --install
```

`security find-identity -v -p codesigning` lists the identities on your Mac.

## Continuous build

Every push builds the app on GitHub Actions on macOS 15 with Xcode 16, with the newest Xcode on macOS 26, and on macOS 26 with only the newest Command Line Tools Apple offers for it, then launches it for 10 seconds to catch crashes on startup. A separate check fails the build if any SwiftUI macro such as `@State` appears in the sources, because on the macOS 27 SDK those need a plugin that only Xcode ships. See `.github/workflows/build.yml`.

## Editing in Xcode

`open Package.swift` opens the project in Xcode for editing. Run it with `./build.sh` rather than Xcode's Run button, because calendar access needs the app bundle and its Info.plist.

## Project layout

```
Package.swift
build.sh                         builds and signs Upnext.app
Resources/Info.plist             menu bar only app (LSUIElement), calendar usage text
Sources/Upnext/
  main.swift                     entry point
  App/AppDelegate.swift          wires everything together, shortcuts, panel placement
  Model/
    CalendarStore.swift          EventKit queries, filters, "current or next" logic, day grouping
    CalendarEvent.swift          event model, guests, rooms, notes cleanup
    MeetingLink.swift            join link detection and app hand-off
    Preferences.swift            all settings, persisted to UserDefaults
    Clock.swift                  1 second tick for countdowns
    WorkDay.swift                days that start at 4 AM (or another hour) instead of midnight
  StatusBar/StatusItemController.swift   menu bar title, countdown and date icon
  Support/
    HostingPanel.swift           borderless floating panel that sizes to SwiftUI content
    HotKeys.swift                Carbon global shortcuts (no Accessibility permission needed)
    AlertSound.swift             meeting alert sound: a macOS sound or an audio file
    EventActions.swift           join, open in Calendar / Google Calendar
    Formatting.swift             times, durations and labels
  Views/
    PanelView.swift              the dropdown: header, top card, event list
    EventRow.swift               rows and expanded details
    MeetingAlert.swift           upcoming meeting popup
    SettingsView.swift           settings window
    Components.swift             shared buttons and surfaces
```

## Customizing

- **Shortcuts**: change `HotKey.togglePanel` and `HotKey.joinMeeting` in `Support/HotKeys.swift`.
- **Name or bundle ID**: `Resources/Info.plist` and `APP_NAME` in `build.sh`.
- **Panel width**: `.frame(width: 340)` in `Views/PanelView.swift`.
- **Meeting services**: add a case and URL prefix to `MeetingService` in `Model/MeetingLink.swift`.

## Troubleshooting

- **The icon doesn't appear**: on a MacBook with a notch, too many menu bar items can push it behind the notch. Hold ⌘ and drag it closer to the clock, or turn off "Event title" in Settings > Menu bar to make it narrower.
- **A Google meeting has no Join button**: check that the event shows the Meet link in Apple Calendar too. If Apple Calendar doesn't have it, Upnext can't see it either.
- **⌥K or ⌥V no longer types ˚ or √**: system-wide shortcuts take those keys everywhere, same as Notion Calendar. Turn them off in Settings > General, or change them in `Support/HotKeys.swift`.
- **Open at login doesn't stick**: install to `/Applications` first (`./build.sh --install`), then approve Upnext in System Settings > General > Login Items if macOS asks.
