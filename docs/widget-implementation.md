# Home-screen widgets

**Status (Phase 5):** Android widget built and checked on an Android 14 emulator. The iOS
WidgetKit extension is written and compiled in CI (macOS runner, unsigned), but it has not run on
an iPhone yet. See ISSUES C9–C11.

Each widget instance shows **one** group: the newest photo, the group name and a subtitle. Couples
with a start date show "N days", other groups show the member count or "New memory · 2h ago".
Users can add any number of widgets: one per group, or several for the same group. Changing one
widget never changes another.

## Data flow

```
Flutter (WidgetSync)  ──home_widget──▶  shared storage  ◀── native widget reads
   myGroupsProvider changes                 Android: SharedPreferences "HomeWidgetPreferences"
   realtime / push / resume                 iOS:     App Group group.com.closerapp.closer
```

| Key | Value |
|---|---|
| `closer.signedIn` | `"true"` / `"false"` |
| `closer.groups` | JSON list `[{id, name, type}]`, used by the group pickers |
| `closer.group.<id>` | JSON snapshot `{id, name, type, subtitle, imagePath?, updatedAt}` |

Cover images are downsampled thumbnails written to the app's widget folder (Android app files,
iOS App Group container `widgets/<id>.jpg`). They contain no captions.

- `WidgetSync.syncAll` runs whenever the group list changes. It writes the index, one snapshot per
  group and the covers, then makes one refresh call for all widgets.
- `WidgetSync.updateGroup` refreshes only the widgets that show that group (group-targeted refresh).
- **Revoked membership:** groups that disappear from the list lose their snapshot and cover. Their
  widgets switch to "This group is no longer available".
- **Sign-out:** everything is wiped and `signedIn=false`. Widgets show "Open Closer to sign in".
- A failed cover download never blocks the rest of the data (tested).

## Android (Kotlin)

- `CloserWidgetProvider`, an `AppWidgetProvider`, has four states: signed out, not configured
  ("Tap to choose a group"), unavailable, and group. Bitmaps are downsampled before going into the
  `RemoteViews`. Tapping a configured widget opens `com.closerapp.closer://group/<id>`.
- `CloserWidgetConfigureActivity` is the group picker. The choice is saved per `appWidgetId` in
  the prefs file `closer_widget_config`. The widget is reconfigurable, and the configure activity
  also opens when the user taps an unconfigured widget (pinned widgets skip the configure step on
  some launchers).
- `updatePeriodMillis = 0`: refreshes come from the app (sync, push, resume), never from polling.
- The in-app "Add a widget" button uses `AppWidgetManager.requestPinAppWidget` where the launcher
  supports it. Otherwise the Widget Setup screen shows manual steps.
- **Checked on the emulator (2026-10-14):** add from the app → launcher pin dialog → "Tap to choose a
  group" → picker → "My Love · 182 days" → tap opens the group. Screenshots are in
  `docs/screenshots/phase5/`.

## iOS (SwiftUI WidgetKit)

- `ios/CloserWidget/CloserWidget.swift`: an `AppIntentConfiguration` (iOS 17) whose
  `SelectGroupIntent` offers the groups from `closer.groups`. It provides a timeline, a snapshot
  and a placeholder, and reads snapshots and covers from the App Group.
- `widgetURL` opens the same `com.closerapp.closer://group/<id>` link.
- The app reloads timelines with `HomeWidget.updateWidget(iOSName: 'CloserWidget')`.
- The extension target is added by `ios/scripts/add_widget_extension.rb` (xcodeproj gem,
  idempotent). CI runs it before `flutter build ios --debug --no-codesign`.
- Signing needs the App Group `group.com.closerapp.closer` on both the app and extension identifiers
  (ISSUES A13).

## Background refresh

When Firebase is configured, `closerBackgroundMessage` (data push `photo_added`) refreshes that
group's widget while the app is in the background. Unverified until FCM is set up (ISSUES C10).
The OS decides how often iOS widgets actually reload, so no exact interval is promised.
