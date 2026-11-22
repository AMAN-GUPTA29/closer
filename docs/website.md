# Website (privacy, terms, support, account deletion)

The privacy policy, terms of use and help page are shown **inside the app** (Profile → Help,
the sign-up footer) from `assets/legal/*.md`. The stores also need public web addresses, so the
same files are published as a small static site on a free **Vercel** project (no domain needed;
it gets a `*.vercel.app` address).

| Page | Source | Store field |
|---|---|---|
| `/privacy` | `assets/legal/privacy.md` | Play: Privacy policy · App Store: Privacy Policy URL |
| `/terms` | `assets/legal/terms.md` | App Store: EULA / description link |
| `/support` | `assets/legal/support.md` | App Store: Support URL |
| `/delete-account` | `site/content/delete-account.md` | Play: Data safety → account deletion URL |

## Build

`node site/build.mjs` writes `site/dist/` (no dependencies). `SUPPORT_EMAIL` fills in the
`{{contact}}` line; keep it the same as the app's `SUPPORT_EMAIL` dart-define.
`legalContactText()` in `lib/features/legal/legal_content.dart` and `site/build.mjs` must produce
the same sentence.

## Vercel setup (owner, once)

1. vercel.com → Add New → Project → import the `closer` GitHub repo (Hobby plan is free).
2. Leave the root directory as the repo root: `vercel.json` sets the build command and output.
3. Project → Settings → Environment Variables: `SUPPORT_EMAIL`.
4. Deploy. The project name decides the address, e.g. `keeploom.vercel.app`.

`vercel.json` skips deployments when nothing under `site/`, `assets/legal/` or `vercel.json`
changed.

## Editing

Change the Markdown, keep `Last updated` current, and run `flutter test
test/features/legal_content_test.dart`. Only `#`/`##` headings, paragraphs, `- ` bullets and
`**bold**` are supported. The texts are plain-language drafts written from how the app actually
works; they have not been reviewed by a lawyer (ISSUES D5).
