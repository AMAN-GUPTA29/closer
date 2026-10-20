# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

One Keeploom brand look on both Android and iOS, built with Flutter, launching on both at the same time.
Each platform keeps its own conventions where users expect them: system photo picker and share sheet,
back navigation, safe areas and notifications. The home-screen widgets are fully native on each
platform (Android in Kotlin, iOS in WidgetKit).

## Users

Three equal audiences from launch, each in their own private group:

- **Couples**: two people keeping their shared story (a couple group holds at most two people).
- **Friends**: a small crew sharing trips, nights out and inside moments.
- **Families**: parents, grandparents and siblings sharing everyday photos across distance.

Each person opens Keeploom to share a small moment with *their* people, or to look back on what the
group has kept.

## Product Purpose

Keeploom is a private photo-sharing app and shared journal. It lets a small group share photos, turn
them into a shared journal with milestones, and keep their people visible on the home screen.
Success means a group keeps coming back to add and revisit moments together, and the group's story
outlives any single chat thread.

Principle: *Basic lets you share the moment. Keeploom Memories lets you keep the story.*

## Positioning

What WhatsApp groups and Google Photos shared albums can't truthfully claim:

- **Private and invite-only.** Only the people in a group ever see it. There are no public feeds,
  no strangers and no ads. Group membership is enforced by the server, not the app.
- **A kept story, not a chat.** A journal of photos and milestones, plus a couple's days-together
  counter, turns photos into a story instead of a scroll.
- **On your home screen.** Native widgets show a chosen group's newest photo where you look every
  day.
- **Small and calm.** A few photos that matter, not thousands. A Basic group keeps its latest 10.

## Operating Context

- **Groups:** a person can be in many groups but only one couple group. Groups are joined by
  invite: a link or an 8-character code that can expire, be cancelled or have a use limit.
- **Sharing:** one share can include several photos and go to several groups at once, with an
  optional caption and date. A shared photo can also start a "special moment".
- **Looking back:**
  - the journal (per group and across all groups);
  - milestones ("special moments"), including upcoming ones;
  - notifications, plus a reminder the day before a milestone.
- **Widgets:** each widget is set to one group, independently of the others.

## Capabilities and Constraints

- Group types: Couple (max 2 people), Friends, Family. Roles: owner and member. Ownership can be
  handed over.
- Basic retention: 10 active photos per Basic group. Sharing an 11th photo removes the oldest, and
  the server enforces this. Keeploom Memories is a one-time purchase per group that unlocks full
  history and pinning for every member, including future members.
- Push notifications never include photos or private captions.
- Accounts: email and password with a confirmed email, and a unique username. Account deletion
  needs a typed confirmation.
- Every visible control either works or is clearly marked as unavailable.
- **Open decisions:**
  - Basic pricing model (D1).
  - Final regional prices (D2).
  - Trademark and bundle-ID check for the Keeploom name (D10).
  - Google and phone sign-in are paused.
  - Usernames are built but not live on the hosted backend yet.

## Brand Commitments

- Name **Keeploom**, formerly Closer. Tagline: *Keep what brings you closer.*
- The logo is two interlocking rounded shapes in coral and plum, with an ivory "seed" where they
  overlap.
- References:
  - `docs/design/Keeploom Brand Identity Board.png`
  - `docs/design/Keeploom App Design Showcase.png` (light and dark)
  - `docs/design-system.md`
- The redesign UI was approved and **locked by the owner on 2026-10-20**. The reference set is
  `docs/screenshots/keeploom-all-screens/`. Visual changes need the owner's approval.
- Internal identifiers stay `closer` on purpose: package/bundle ID `com.closerapp.closer`, the URL
  scheme, the App Group and the Dart package.

## Evidence on Hand

- The owner's original sample photos: `docs/design/` and `assets/onboarding/*.jpg`. Onboarding and
  previews use these.
- No real users, testimonials, reviews, press, usage numbers or final prices exist yet. Don't invent
  any.

## Product Principles

1. **Your people only.** Privacy is enforced by the server, and nothing is visible beyond the group.
2. **Moments over volume.** Make sharing and revisiting a few meaningful photos easy, not storing
   everything.
3. **A story, not a stream.** Photos, milestones and counters add up to something worth looking
   back on.
4. **Equal care for couples, friends and families.** Each group type gets its own tone: hearts for
   couples, celebration for friends and family.
5. **Honest controls.** Nothing pretends to work. Unavailable features say so.

## Accessibility & Inclusion

Light and dark appearance (with a system option). Screen-reader labels and minimum tap targets are
covered by the accessibility tests in `test/app/accessibility_test.dart`.
