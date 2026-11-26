# Upnext

A native macOS menu bar calendar modeled on Notion Calendar's menu bar widget. SwiftUI + AppKit, no dependencies.

## What it does

| Notion Calendar menu bar | Upnext |
|---|---|
| Next event title and countdown in the menu bar | Yes. `▍Weekly sync · in 5m`, then `20m left` once it starts. A date icon shows only when nothing is coming up |
| "Preview upcoming event" lead time, title/time toggles | Yes, in Settings > Menu bar |
| Dropdown with upcoming events grouped by day | Yes, as a timeline: meetings with no free time between them share one colored bar, labelled Back to back or Overlaps 15 min where each joins the last; free time shows as a small row colored by how much room it leaves (red under 15 min, amber 15 to 30, green 30 or more) with a dotted line joining the bars, and declined meetings (struck through) then all-day events sit at the bottom of each day with a dimmed bar. When the next meeting follows straight on from the top one, the top meeting's bar runs down into the list and its Join button moves in beside it. Today's meetings follow the top card with no extra header; a later first day is labelled Upcoming, and days with nothing on are skipped. Times include the duration, e.g. `9:30 PM - 9:55 PM (25 min)` |
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
| Desktop widget | Yes: small (the current or next meeting), medium (plus the next 3) and large (the whole dropdown list, colored gaps and all). Right-click the desktop, choose Edit Widgets and search for Upnext. Clicking it opens the dropdown; Join opens the meeting |
| Light or dark look | Yes, in Settings > General > Appearance: Light, Dark or System. Applies to the dropdown, meeting alerts and Settings; the menu bar item always matches the menu bar |
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

### Signing

The desktop widget needs an Apple Development certificate: macOS 26 and later drop widgets that aren't signed by a team. A certificate also keeps the calendar permission between rebuilds, which ad hoc signatures don't, because they change on every build. A free Apple ID is enough:

1. Install Xcode from the App Store and open it once.
2. In Xcode > Settings > Accounts, add your Apple ID. It gets a free Personal Team.
3. Select the team, click Manage Certificates, then + > Apple Development.

`build.sh` then signs with that certificate on its own. To pick a different identity, set `CODESIGN_IDENTITY` to its name or SHA-1 from `security find-identity -v -p codesigning`. Without a certificate it signs ad hoc and warns that the widget won't appear.

## Continuous build

Every push builds the app on GitHub Actions on macOS 15 with Xcode 16, with the newest Xcode on macOS 26, and on macOS 26 with only the newest Command Line Tools Apple offers for it. It checks the widget's signature and sandbox, has macOS register the widget, launches the app for 10 seconds to catch crashes on startup, and checks that it wrote the widget's snapshot. A separate check fails the build if any SwiftUI macro such as `@State` appears in the sources, because on the macOS 27 SDK those need a plugin that only Xcode ships. See `.github/workflows/build.yml`.

## Editing in Xcode

`open Package.swift` opens the project in Xcode for editing. Run it with `./build.sh` rather than Xcode's Run button, because calendar access needs the app bundle and its Info.plist.

## Project layout

```
Package.swift
build.sh                         builds and signs Upnext.app
Resources/Info.plist             menu bar only app (LSUIElement), calendar usage text, upnext:// URL
Resources/UpnextWidget-*         the widget extension's Info.plist and sandbox entitlements
Sources/UpnextShared/            used by the app and the widget
  WidgetSnapshot.swift           what the widget shows at each moment, and where the file lives
  Timeline.swift                 timeline bars, gap rows and join labels
Sources/UpnextWidget/            the desktop widget (PlugIns/UpnextWidget.appex)
  UpnextWidget.swift             widget, timeline provider, gallery sample
  AgendaWidgetView.swift         small, medium and large layouts
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
    WidgetSnapshotBuilder.swift  works out the widget's contents for each moment ahead
    WidgetPublisher.swift        writes the widget's snapshot and asks WidgetKit to redraw
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
- **Upnext isn't in the widget gallery**: check that `build.sh` printed `Signing with: Apple Development: ...` (see Signing), then open Upnext once from `/Applications`. `pluginkit -m -v -p com.apple.widgetkit-extension | grep upnext` shows whether macOS registered it and from where; only the `/Applications` copy should be listed. `/usr/bin/log show --last 5m --info --debug --predicate 'process == "chronod"' --style compact | grep -i upnext` shows whether the widget answered: `getAllDescriptors result` means it did, `purging` means macOS rejected its signature.
- **The widget shows old meetings or "Open Upnext"**: the widget draws what Upnext writes to `~/Library/Application Support/Upnext/Widget.json`, so Upnext has to be running. Desktop widgets turn monochrome while another app is in front, so the gap colors only show when you're looking at the desktop.
- **Open at login doesn't stick**: install to `/Applications` first (`./build.sh --install`), then approve Upnext in System Settings > General > Login Items if macOS asks.
