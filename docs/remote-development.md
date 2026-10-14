# Remote development (laptop closed, driven from your phone)

There are two supported ways to keep building Closer while the Windows laptop is off.
Both run on cloud machines and work from a phone.

| | A. Claude app → Code tab (cloud session) | B. `@claude` on GitHub |
|---|---|---|
| Where you type | Claude mobile app, **Code** tab (or claude.ai/code) | A comment on a GitHub issue / PR (GitHub app or browser) |
| Runs on | Anthropic cloud VM (Ubuntu 24.04) | GitHub Actions runner |
| Billing | Your Claude plan usage | Your Claude plan (OAuth token) + GitHub Actions minutes |
| Conversation | Full chat, like this one | Replies as a comment that updates while it works |
| Best for | Phase work, back-and-forth | Small tasks, fixes, "@claude fix CI" |

**Recommendation:** use **A** for day-to-day phase work, keep **B** as a backup.

---

## A. Cloud sessions from the Claude mobile app

### One-time setup
1. On a phone or browser open **claude.ai/code** (or the Claude app → **Code** tab) and sign in with the
   same Claude account you use here.
2. Connect GitHub when prompted and **authorize the Claude GitHub App** for the
   `AMAN-GUPTA29/closer` repository (install page: https://github.com/apps/claude).
3. Cloud environment: the onboarding creates a **Default** environment with **Trusted** network access.
   Trusted already allows `storage.googleapis.com` (Flutter SDK download), `pub.dev` and `maven.google.com`.
4. *(Optional, faster startups)* Edit the environment and paste this into **Setup script** so the Flutter
   install is cached across sessions:
   ```bash
   #!/usr/bin/env bash
   set -e
   curl -fsSL -o /tmp/flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.4-stable.tar.xz
   tar -xf /tmp/flutter.tar.xz -C /root && rm /tmp/flutter.tar.xz
   git config --global --add safe.directory /root/flutter
   /root/flutter/bin/flutter --version
   ```
   Even without this, the repo's `SessionStart` hook (`.claude/settings.json` → `scripts/cloud-setup.sh`)
   installs Flutter automatically inside cloud sessions. It does nothing on the laptop.

### Daily use
- Open the Code tab → pick **AMAN-GUPTA29/closer** → type the instruction, e.g.
  *"Continue the current phase in TRACKER.md"* or *"Phase 1 approved — start Phase 2"*.
- The session clones the repo, works on a branch, runs `flutter analyze` / `flutter test`, pushes, and
  can open a PR. Review the diff in the session, then ask it to open/merge the PR.
- Sessions keep running when you close the app; reopen to check progress or answer questions.
- Pick up a cloud session later on the laptop with `claude --teleport`.

### Limits
- Cloud VMs are Linux: they can build/test Flutter and the Android APK (if the Android SDK is installed),
  but **cannot build iOS** — that goes through Codemagic (Phase 6).
- Cloud sessions count toward your Claude plan's usage limits.

---

## B. `@claude` in GitHub issues / PRs

Workflow file: `.github/workflows/claude.yml` (actions pinned to commit SHAs).

### One-time setup
1. Install the Claude GitHub App on the repo: https://github.com/apps/claude → *Only select repositories* →
   `closer`.
2. On the laptop, run `claude setup-token` in a terminal and copy the token it prints.
3. GitHub → repo **Settings → Secrets and variables → Actions → New repository secret**:
   name `CLAUDE_CODE_OAUTH_TOKEN`, value = the token. (Never paste it into chat or commit it.)

### Daily use
- Open an issue such as "Phase 2: invitations" and write `@claude implement the next unchecked items in
  TRACKER.md Phase 2 and open a PR`.
- Or comment `@claude fix the failing CI on this PR` on a pull request.
- Only the owner and collaborators can trigger it: the workflow checks the comment author's association, and the action also requires write access. This matters because the repo is public.

---

## Status
| Item | State |
|---|---|
| Repo pushed to GitHub | ✅ |
| SessionStart hook + `scripts/cloud-setup.sh` committed | ✅ (not yet run in a real cloud session) |
| Claude GitHub App installed | ⏳ owner action |
| `CLAUDE_CODE_OAUTH_TOKEN` secret | ⏳ owner action |
| `@claude` workflow verified end-to-end | ⏳ not tested yet |
| Cloud session verified from phone | ⏳ not tested yet |
