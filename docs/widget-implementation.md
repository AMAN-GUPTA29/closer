# Home-screen widgets

**Status:** planned for Phase 5. Phase 1 ships only `WidgetPreviewCard`, an in-app preview
component — **not** a native widget.

## Plan

- **Android:** Kotlin `AppWidgetProvider`, configuration activity to choose a group per widget
  instance, per-instance preferences keyed by `appWidgetId`, cached photo, deep link to the group,
  empty/error states, refresh on new photos for that group only.
- **iOS:** WidgetKit extension in SwiftUI, App Group shared container, AppIntent configuration per
  widget instance, timeline/snapshot/placeholder, deep links, `WidgetCenter` reloads.
- **Bridge:** `home_widget` package (to be evaluated against current Flutter at Phase 5).
- Revoked membership clears cached content for that group.
- Refresh cadence is controlled by the OS; no promises of exact intervals.
