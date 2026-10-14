# Product requirements

Closer is a private photo-sharing and shared-journal app for couples, friends and families.
**Principle:** Basic lets you share the moment. Closer Memories lets you keep the story.

## Core concepts

| Concept | Summary |
|---|---|
| Group | Private space of type **Couple** (max 2 active members), **Friends** or **Family**. Name, type, creator, members, optional cover, settings. |
| Membership | Unique per user+group, explicit roles (owner / member), enforced on the backend. Couple capacity enforced atomically. |
| Invitation | Belongs to a group, not a person. Secure random token (stored hashed) + human-friendly code, expiry, revocation, optional redemption limit, redemption records, deep links. |
| Photo | Uploaded by any member into a group; private storage; thumbnail + full size; caption; capture date vs upload time. |
| Journal | Chronological (newest first) feed of photos and milestones per group, cursor-paginated. |
| Milestone | Database record: title, type, event date, description, optional cover photo, theme, pinned. Hearts for couples; celebratory/neutral for friends and family. |
| Relationship counter | Couple groups only, optional start date, editable. |
| Basic retention | A Basic group keeps at most **10 active photos**; the 11th upload removes the oldest eligible photo, server-side and concurrency-safe. |
| Closer Memories | One-time purchase per group (pricing hypothesis: Basic $2, Memories +$10; configurable). Unlocks full history for every member of that group, including future members. |
| Widgets | Native Android (Kotlin) and iOS (WidgetKit) widgets; each instance configured independently to one group. |
| Notifications | Server-dispatched push for new photos, new members, milestones; never includes photos or private captions. |

## Screens

1 Onboarding · 2 Authentication · 3 Home/Groups · 4 Create group · 5 Invite members · 6 Join group ·
7 Group home · 8 Journal · 9 Milestones · 10 Add a memory · 11 Create a special moment ·
12 Notifications · 13 Profile/Settings · 14 Widget setup — plus photo viewer, members, group
settings, invitation management, upgrade/purchase states, destructive-action confirmations.

Every visible control either works or is clearly marked unavailable.

## Delivery

Six gated phases (see [TRACKER.md](../TRACKER.md)). The owner approves each phase before the next starts.

## Implemented in Phase 3

- Share a photo from the gallery or camera into a group: preview, caption, optional date (EXIF
  pre-filled), step progress, Retry without duplicates, clear errors.
- Private storage with signed URLs and on-device caching; thumbnails for grids, full size in the
  viewer; group covers from the newest photo.
- Basic groups keep 10 photos, enforced on the server; warning before sharing into a full group.
- Closer Memories entitlement on the server (per group, inherited by new members, 30-day refund
  grace); upgrade screen (purchases disabled until Phase 5); pin photos (Premium).
- Journal photo grid with pagination; full-screen viewer with delete and pin.

## Implemented in Phase 2

- Database: profiles, groups, memberships, invitations with RLS and trusted functions.
- Create Couple / Friends / Family groups (optional couple start date); Home group list.
- Group-specific invitations: 8-character code + link, expiry (1/7/30 days or none), use limits,
  revocation, share sheet, copy link, invitation list with status.
- Join by code, pasted invite message or deep link, with a preview and clear invalid / expired /
  revoked / used-up / full / rate-limited states.
- Group home (couple counter, members, tabs), members (remove, make owner), group settings
  (rename, start date, counter toggle, leave, delete).

## Implemented so far (Phase 1)

- Onboarding (3 pages), sign up, sign in, email verification, password reset request and
  new-password screens, wired to Supabase Auth when configured.
- Google/Apple buttons wired to Supabase OAuth, disabled until enabled by configuration.
- Navigation shell (Home, Journal, Add, Notifications, Profile) with honest empty states.
- Profile with sign-out confirmation; legal summaries.
