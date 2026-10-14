# Design system

## Reference

- Original: `Closer App UI Concept Board.png` (repository root — preserved, never modified).
- Copy: [`docs/design/closer-ui-concept-board.png`](design/closer-ui-concept-board.png) (byte-identical).
- The board shows 14 screens: onboarding, sign up/login, home/groups, create group, invite
  members, join group, group home, journal timeline, milestones, add a memory, special moment,
  notifications, profile/settings and home-screen widgets for multiple groups.
- It is a **reference**, not a screenshot to embed. All UI is built from real components.

## Observations from the board

- Warm ivory / blush backgrounds, white rounded cards, coral→rose pill buttons.
- Deep plum headings, soft mauve secondary text, generous whitespace.
- Photography-first: rounded photo cards, sunset/coastal imagery, heart accent on couple items.
- Large display numerals for milestones ("100 days together", "182 days together").
- Bottom navigation: Home, Journal, Add, Notifications, Profile.

## Tokens (`lib/core/theme/`)

### Colour (`closer_colors.dart`)
| Role | Light | Dark |
|---|---|---|
| background | `#FFF8F5` ivory | `#1A1119` |
| surface | `#FFFFFF` | `#261A25` |
| surfaceMuted | `#FBEFEA` | `#33232F` |
| textPrimary | `#2B1A2E` plum | `#F7ECEE` |
| textSecondary | `#5B4A5C` | `#C9B8C4` |
| textTertiary | `#8E7D8C` | `#9C8B98` |
| accent / accentStrong | `#F36B7F` coral / `#E84F6D` rose | `#F67F91` / `#F36B7F` |
| accentSoft | `#FDE8EC` blush | `#4A2733` |
| line | `#EFE3E3` | `#433340` |
| tints | couple coral · family `#8C6BC8` · friends `#5B8DEF` · premium gold `#F5B54A` |
| gradients | `accentGradient` (coral→rose, buttons) · `heroScrim` (photo text legibility) |

Use `context.closerColors.<role>`, never raw hex in widgets.

### Typography (`closer_typography.dart`)
- **Plus Jakarta Sans** (variable) for UI; **Fraunces** (variable) for display numerals/moments.
- Scale: display 56/40/32 · headline 28/24/20 · title 18/16/14 · body 16/14/13 · label 16/13/12.
- Minimum body text 13–14 pt; weights set via both `fontWeight` and the `wght` axis.

### Spacing, radii, elevation, motion (`closer_tokens.dart`)
- Spacing 4-pt scale: 4, 8, 12, 16, 20, 24, 32, 48; page gutter 20.
- Radii: 10, 14, 20, 28, pill.
- Elevation: `low`, `medium` soft plum shadows; `accentGlow` under primary buttons.
- Motion: 150/250/400 ms, `easeOutCubic`; `CloserMotion.of(context, d)` returns zero when the OS
  "reduce motion" setting is on.

### Icons (`closer_icons.dart`)
Lucide outline glyphs plus Material rounded fills for solid accents (heart, pin, star, check).
Emoji are never used as icons.

## Components (`lib/core/widgets/`)

| Component | Notes |
|---|---|
| `CloserButton` | primary (gradient), secondary, ghost, danger; loading state; disabled when `onPressed` null |
| `CloserIconButton` | round, mandatory semantic label + tooltip, ≥48 dp target, optional badge, filled variant |
| `CloserTextField` | leading icon, password show/hide |
| `GroupCard` | cover, name, type · member count, activity, premium crown, couple heart |
| `MemoryCard` | 4:3 photo, caption, location, uploader, date, pinned badge, Hero tag |
| `MilestoneCard` | display numeral or title, date, description, cover; heart / celebration / neutral themes; reduced-motion aware intro |
| `MemberAvatar`, `AvatarStack` | photo or deterministic initials tint; "+N" overflow |
| `PhotoViewer` | full screen, swipe, pinch-zoom, caption overlay, tap to hide chrome |
| `InviteCodeCard` | spaced code, copy to clipboard + snackbar |
| `UpgradeCard` | "Keep every memory from this group"; disabled with reason when billing unavailable |
| `WidgetPreviewCard` | small / wide preview of a native widget |
| `LoadingState`, `EmptyState`, `ErrorState` (+ `.offline`), `OfflineBanner`, `NoticeCard` | state views |
| `ConfirmationDialog` / `showConfirmationDialog` | resolves `true` only on explicit confirm; destructive variant |
| `CloserPhoto`, `SunsetArt` | photo with fade-in and painted placeholder; vector sunset scene used for the hero and missing photos |
| `CloserLogo` | heart mark + wordmark |

A debug-only **Component gallery** (Profile → Component gallery) shows every component with sample data.

## Accessibility

Semantic labels on cards and icon buttons, live regions for errors, 48 dp touch targets,
text that wraps instead of overflowing (tests run with real font metrics), reduced-motion support.
