# Upnext

A native macOS menu bar calendar modeled on Notion Calendar's menu bar widget. SwiftUI + AppKit, no dependencies.

## What it does

| Notion Calendar menu bar | Upnext |
|---|---|
| Next event title and countdown in the menu bar | Yes. `▍Weekly sync · in 5m`, then `20m left` once it starts. A date icon shows only when nothing is coming up |
| "Preview upcoming event" lead time, title/time toggles | Yes, in Settings > Menu bar |
| Dropdown with upcoming events grouped by day | Yes. The rest of today under Upcoming, then Tomorrow and weekdays, with the free time between meetings. Times include the duration, e.g. `9:30 PM - 9:55 PM (25 min)` |
| Big "Join Google Meet" button for the current/next meeting | Yes, with each guest's email address and reply (accepted, declined, maybe or no reply) under it. Meet, Zoom, Teams, Webex, Slack huddles, Whereby, Around, Chime, GoTo, Jitsi, Discord, FaceTime, Skype |
| Quick actions: join a meeting | Yes. The top card's Join button, Join on hovering any row, ⌥V, or Return in the dropdown |
| Event details: guests and their RSVP, rooms, notes | Yes, click a row |
| Include events: days, all-day, without participants, without conferencing/location | Yes, in Settings > Menu bar |
| Hide individual calendars from the menu bar | Yes, in Settings > Calendars (also stops their alerts) |
| Upcoming meeting popup with Join button, over full screen apps | Yes, top right. Plays a macOS sound or any audio file macOS can decode (not Ogg or WebM; Upnext checks when you choose one). Settings > Notifications |
| Global shortcuts: toggle menu bar calendar, join next meeting | ⌥K and ⌥V (Cron's defaults). Return joins and Esc closes inside the dropdown |
| Open at login | Yes |
| Change your RSVP from the menu bar | No. macOS's calendar framework is read-only for responses. Use "Open in Calendar" |

Small extras: Meet links open with your Google account (`authuser`), Zoom and Teams links open straight in their apps when installed, Outlook SafeLinks are unwrapped, duplicate copies of the same meeting across calendars are merged, and declined or canceled events are hidden.

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
