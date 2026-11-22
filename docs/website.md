# Website (privacy, terms, support, account deletion, invite links)

The privacy policy, terms of use and help page are shown **inside the app** (Profile → Help,
the sign-up footer) from `assets/legal/*.md`. The stores also need public web addresses, so the
same files are published as a small static site on **Cloudflare Pages** (free, no domain needed;
it gets a `*.pages.dev` address). Vercel's free plan is for non-commercial use only.

| Page | Source | Store field |
|---|---|---|
| `/privacy` | `assets/legal/privacy.md` | Play: Privacy policy · App Store: Privacy Policy URL |
| `/terms` | `assets/legal/terms.md` | App Store: EULA / description link |
| `/support` | `assets/legal/support.md` | App Store: Support URL |
| `/invite` | `site/invite.mjs` | Invite links: `/invite#t=<token>` opens the app |
| `/delete-account` | `site/content/delete-account.md` | Play: Data safety → account deletion URL |

## Build

`node site/build.mjs` writes `site/dist/` (no dependencies). `SUPPORT_EMAIL` fills in the
`{{contact}}` line; keep it the same as the app's `SUPPORT_EMAIL` dart-define.
`legalContactText()` in `lib/features/legal/legal_content.dart` and `site/build.mjs` must produce
the same sentence.

## Cloudflare Pages setup (owner, once)

1. dash.cloudflare.com → Workers & Pages → Create → Pages → connect the `closer` GitHub repo.
2. Production branch `main`; build command `node site/build.mjs`; output directory `site/dist`.
3. Environment variables: `SUPPORT_EMAIL` (and `PLAY_STORE_URL` / `APP_STORE_URL` once they exist).
4. Deploy. The project name decides the address, e.g. `keeploom.pages.dev`.
5. Set `INVITE_LINK_BASE=https://<that address>` in `.env`, the GitHub variables and Codemagic,
   then rebuild the app. Until then invites use the `com.keeploom.app://` link, which chat apps
   don't make tappable.

## Invite links

`https://<site>/invite#t=<token>` shows a page with **Open in Keeploom**, which opens
`com.keeploom.app://invite?t=<token>`. The token is after `#`, so it isn't sent to the host, and
the page loads nothing from third parties. It is one extra tap: opening the app straight from the
link needs Android App Links / iOS Universal Links, which need the release signing certificate
(A12) and the Apple team id (A8).

## Editing

Change the Markdown, keep `Last updated` current, and run `flutter test
test/features/legal_content_test.dart`. Only `#`/`##` headings, paragraphs, `- ` bullets and
`**bold**` are supported. The texts are plain-language drafts written from how the app actually
works; they have not been reviewed by a lawyer (ISSUES D5).
