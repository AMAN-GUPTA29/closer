# Keeploom design system

Keeploom (formerly Closer) is a private photo-sharing and shared-journal app.
**Tagline:** *Keep what brings you closer.*

## References

- [`design/Keeploom Brand Identity Board.png`](design/Keeploom%20Brand%20Identity%20Board.png): logo, palette, tone.
- [`design/Keeploom App Design Showcase.png`](design/Keeploom%20App%20Design%20Showcase.png): onboarding, Home,
  Journal, share flow, notifications and profile in light **and** dark.
- `Closer App UI Concept Board.png` (repo root): the original board, kept for history.

The boards are references, not assets: every screen uses real components and real user content.
The only exception is the onboarding collage, which shows the owner's original sample photos
(`docs/design/*Sunset*`, `*Romantic*`, `*Blooms*`; the multi-photo images are split into
`assets/onboarding/*.jpg`, max 1200 px).

## Brand

- **Logo:** two rounded, slightly tilted shapes interlock (coral and plum). Where they overlap, an
  ivory "seed" shows through: the moment that's kept. The geometry lives once, in
  [`tool/keeploom_logo.py`](../tool/keeploom_logo.py), and is mirrored by
  `KeeploomMarkPainter` (`lib/core/widgets/keeploom_logo.dart`).
- **In app:** `KeeploomLogo(size:, showWordmark:, showTagline:)` draws the mark as vectors.
- **Never** put the wordmark inside the launcher icon.

### Generated assets

```bash
python tool/make_icons.py            # needs Pillow
dart run flutter_launcher_icons      # Android (adaptive + monochrome) and iOS icons
dart run flutter_native_splash:create
```

| Output | Use |
|---|---|
| `assets/brand/keeploom_mark.svg` / `.png` | standalone mark (transparent) |
| `assets/icon/icon.png` | iOS and legacy Android icon (ivory tile) |
| `assets/icon/foreground.png` + background `#FFF7F1` | Android adaptive icon |
| `assets/icon/monochrome.png` | Android 13 themed icon |
| `assets/icon/splash*.png` | launch screen (ivory light / `#0E0810` dark) |
| `android/.../drawable/ic_stat_keeploom.xml` | white status-bar notification icon |

## Tokens (`lib/core/theme/`)

Widgets use **semantic roles** (`context.closerColors.<role>`), never raw hex. Internal class names
keep the `Closer*` prefix (`CloserColors`, `CloserSpacing`, …) to avoid churn; only user-facing
names changed.

### Colour (`closer_colors.dart`)

| Role | Light | Dark | Notes |
|---|---|---|---|
| background | `#FFF7F1` ivory | `#0E0810` | |
| surface | `#FFFFFF` | `#1A1620` | cards, sheets, inputs |
| surfaceMuted | `#F8EDE7` | `#241D2A` | elevated card / dock (dark) |
| textPrimary | `#2E2A2A` charcoal | `#FFF7F4` | |
| textSecondary | `#786B79` | `#C2B5C5` | ≥ 4.5:1 for small text |
| textTertiary | `#8A7D8B` | `#9D8FA0` | hints and icons only (≥ 3:1) |
| accent | `#F5767A` coral | `#FF687B` | fills, borders, focus |
| accentStrong | `#B8304F` | `#FF687B` | coral **text** (AA on ivory and blush) |
| accentSoft | `#FCE8EC` blush | `#3A2230` | selected highlights |
| line | `#F0E2E3` | `#3B303F` | |
| brandPlum / peach | `#6B3F55` / `#FDCABA` | `#B982A6` / `#FDCABA` | logo, decoration |
| accentGradient | `#EE5F70 → #E23A5E` | same | primary buttons, dock Add |

Contrast adjustments versus the brand board (only where WCAG required them): coral text uses
`#B8304F`, and the button gradient is slightly deeper than `#F5767A → #F04468`, so white labels
keep at least 3:1.

### Typography (`closer_typography.dart`)

One family, **Plus Jakarta Sans** (variable, bundled, OFL), from 12 px labels to 56 px display.
Display sizes use weight 800. Minimum body size 14. Text scales with the system setting; layouts are
tested at 200 %.

### Spacing, radii, elevation, motion (`closer_tokens.dart`)

4-pt grid (`xxs 4 … xxxl 48`, page gutter 20), radii `10 / 14 / 20 / 28 / pill`, two soft shadows
(`low`, `medium`) and motion tokens that respect "reduce motion".

## Appearance (light / dark / system)

- `appearanceProvider` (Riverpod) holds `ThemeMode`; **Profile → Appearance** offers Light, Dark and
  System (default).
- Saved with `shared_preferences` (`keeploom.appearance`). `main.dart` reads it **before the first
  frame**, so the theme never flashes.
- Changes apply instantly. Status- and navigation-bar icons follow the theme (`systemBarsFor`,
  edge to edge).
- Every component theme (app bar, inputs, buttons, chips, segmented buttons, switches, cards,
  dialogs, sheets, snack bars, date picker) is derived from the same tokens, so new screens follow
  both themes automatically.
- Native surfaces follow the system theme: the widget group picker uses `@color/kl_*` with
  `values-night` variants. The splash has light and dark variants.

## Components (`lib/core/widgets`, feature folders)

| Component | Where |
|---|---|
| `KeeploomLogo` / `KeeploomMarkPainter` | `core/widgets/keeploom_logo.dart` |
| `KeeploomBottomNav` (floating dock, raised Add, unread dot) | `features/shell/keeploom_bottom_nav.dart` |
| `ThemeSettingsTile` (Appearance) | `features/profile/presentation/theme_settings_tile.dart` |
| `CloserButton` (primary gradient / secondary) | `core/widgets/closer_button.dart` |
| `GroupCard`, `MemoryCard`, `MilestoneCard`, `UpgradeCard` | `core/widgets/` |
| `EmptyState`, `LoadingState`, `ErrorState`, `NoticeCard`, `OfflineBanner` | `core/widgets/state_views.dart` |
| `InAppNotificationBanner` | `features/notifications/presentation/in_app_banner.dart` |

### Navigation dock

- Floating rounded surface (white in light mode, `surfaceMuted` in dark), thin border, one soft
  shadow (none in dark).
- Four outline icons (Home, Journal, Alerts, Profile) with a small blush pill behind the selected
  one; active colour `accentStrong`, inactive `textSecondary` (12–13 px labels must reach 4.5:1).
- A raised 56 px gradient **Add** button opens the existing share flow. It's an action, not a tab.
- An unread dot on Alerts. The dock respects safe areas and gesture navigation.

## Accessibility rules

- Tap targets ≥ 48 dp; semantic labels on icon-only buttons.
- Text contrast is checked by tests (`test/app/accessibility_test.dart`,
  `test/app/keeploom_theme_nav_test.dart`) on main screens in **light and dark**.
- 200 % text size must not overflow on any main screen.
