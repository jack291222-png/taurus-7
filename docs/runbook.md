# Taurus — build, fork-sync & merge-request runbook

_Updated 2026-10-21. Keep this in sync: the long-term copy is `docs/runbook.md` on
`diyarit/taurus` main; this root copy is the always-visible untracked one for the
next agent session. No secrets live here — tokens are fetched from the keychain
at runtime, never printed or committed._

## What this is for

Every non-obvious thing learned the hard way while fixing, syncing, building and
opening merge requests for the spoti.pw tweak. Repo rules (layers, traps, release
flow) live in `AGENTS.md` and `docs/tweaks.md` — read those first; this file is
the operational layer on top.

## Where everything lives

| Thing | Value |
|---|---|
| Local repo | `~/Desktop/taurus` (branch `fix/side-drawer-row` = the code inside the current IPA) |
| Upstream (`origin`) | gitlab.com/taurustweak/taurus, project id **87486056**, default branch `main`, default of new work |
| Fork (`fork`) | gitlab.com/diyarit/taurus, project id **87832372**, a real GitLab fork of the upstream; `main` carries the user's own lineage + synced fixes |
| Upstream members | `apfelsaftaddict` (owner 50), `samj-exe` (maintainer 40); `diyarit` is **not** a member |
| Build tools | `THEOS=/Users/diyarabbas/Desktop/Spotify-Taurus-Safari/Spotify-Taurus/out/theos` (plain `~/theos` does not exist) |
| Decrypted input IPA | `/Users/diyarabbas/Desktop/Spotify-Taurus-Safari/com.spotify.client_9.1.90_und3fined.ipa` (Spotify 9.1.90 is the supported base) |
| Output | `out/Taurus-<version>.ipa` (~137 MB, already "fakesigned"; the device install + signing step is the owner's own flow) |
| Evidence untracked files | `device.log` (real .ips crash report), `crash.log` (mod's own `[spotifyglass]` lines) — **never commit or push these**, they contain device data |
| Reference notes | `.agents/skills/spotipw-code-notes/` (why hooks exist, recorded view trees under `trees/`) |

## Issues fixed so far (do not re-introduce)

### 1. Lyrics SIGABRT on a JSON `null` duration — MR !5
- **Symptom:** Spotify aborts ~10–30 s after every launch; repro = play "SUBSTANCE
  (Remixes)" by kili so every lyrics source misses. `.ips` shows
  `NSInvalidArgumentException, -[NSNull doubleValue]: unrecognized selector`,
  frames inside `spotifyglass.dylib` on the lyrics fetch path.
- **Cause:** every lyrics source read duration/track_length straight out of JSON
  (`[record[@"duration"] doubleValue]`, `integerValue`); JSON `null` becomes
  `NSNull`, which is not `nil` and does not answer those selectors.
- **Fix:** one guarded reader `SGLyricsNumber(id)` in `Shared/LyricsSources`
  (declared in `LyricsSources.h`), used at every unguarded read: LrcLib ×3,
  BiniLyrics, Unison, NetEase ×2, Musixmatch. NSNull/nil read as 0 — same
  semantics as a missing field. One commit: `fix: lyrics sources die on a JSON
  null duration` (`41a8773`).
- **Where:** branch `fix/lyrics-nsnull` (one commit on upstream `main` tip
  `e2e7556`) pushed to the fork → **MR !5** (open, CLA ticked, `Closes #2`).
  Also synced onto fork `main` as `3f01a3a` on the fork's own lineage.
- **Trap:** the all-sources-failed walk is deliberately not cached as "no lyrics"
  (`LyricsSources.m`), so an unhandled throw happens *again on the next request*
  → launch dies in a loop for as long as such a track is queued. Always fix the
  crash, not the retry.

### 2. Duplicate "taurus settings" entry in the side drawer — MR !6
- **Symptom:** the mod's settings row appeared twice: top of the account drawer
  (side panel) *and* at the end of Spotify's Settings list. User wanted the
  drawer one gone, the Settings one kept.
- **Cause:** deliberate upstream code, not a bug of ours: `SGModSettingsRow` in
  `App/ModSettings.x` has a `drawer` variant; the hook on
  `_TtC23SideDrawer_ListPageImpl18ListViewController` adds it to
  `SideDrawerListCollectionView`, and upstream commit `0a3216a` ("restore Mod
  Settings row when drawer relayouts") made it sticky. Upstream *intends* the
  drawer row — removing it is a call by the project owner, so a maintainer may
  push back on the MR.
- **Fix:** removed the whole drawer path (property, layout branches, dismissal
  path in `open`, drawer placement in `placeRow`, `ensureDrawerRow`, the
  `SideDrawerListCollectionView` probe in the `UICollectionView` hook and in the
  drawer hook). Kept the drawer hook alive **only** because it recolours the
  drawer's plan badge to "Taurine" (`updatePlanBadge`). Docs updated
  (2 lines in `docs/tweaks.md`).
- **Where:** the installed IPA's branch `fix/side-drawer-row` is stacked
  (lyrics + drawer). For the MR the drawer commit was **cherry-picked** onto
  upstream `main` as `fix/drawer-settings-entry` (`62b1e0f`, 2 files, +13/−43)
  → **MR !6**. One concern, one commit, zero overlap with !5 — they can merge in
  any order.

### Branch/commit inventory right now

| Branch (local) | Base | Content | Remote |
|---|---|---|---|
| `fix/lyrics-nsnull` | upstream `main` | lyrics fix only | fork; MR !5 |
| `fix/side-drawer-row` | `fix/lyrics-nsnull` | lyrics + drawer | fork (deliberately **not** an MR source) |
| `fix/drawer-settings-entry` | upstream `main` | drawer fix cherry-picked | fork; MR !6 |
| `main` | upstream `main` (e2e7556) | clean | — |
| fork `main` | the user's own lineage | migration/docs commits + lyrics fix `3f01a3a` | only on the remote |

## GitLab accounts & tokens (both belong to `diyarit`)

```
TOKEN=$(security find-internet-password -s gitlab.com -w 2>/dev/null)    # glpat-…, scopes api+write_repository, expires 2026-11-20
TK=$(security find-generic-password -s "glab:gitlab.com:token" -w 2>/dev/null)  # glab's keyring token (different PAT; gave 401 once late in the day)
```

- Never print/echo a token; bind and use in the curl line only.
- `glab` CLI is installed and logged in, but its API path hit the same fences as
  curl except for the unlock below — plain curl with the keychain PAT is the
  reliable path.
- Local commit identity (repo-local): `Diyar Abbas <diyarit@gitlab.com>`.

## THE unlock: cross-fork MR as a non-member (upstream fence)

`POST /projects/87486056/merge_requests` returns **403** for `diyarit` with any
parameter shape (with/without `source_project_id`, `target_project_id`), as does
any `git push` to `origin`, and `can_create_merge_request_in: true` in the
project GET lies about it. Issues still work. The working recipe — **create the
merge request by POSTing to the SOURCE (fork) project with `target_project_id`
pointing at the upstream**:

```
# 1) build the JSON body — write it to a file path WITHOUT spaces (curl --data @file)
python3 - > /private/var/folders/4j/6qhmcwk11w1fnch2lggk72jw0000gn/T/opencode/mr.json <<'EOF'
import json
print(json.dumps({
  "title": "fix: <one-liner in house style>",
  # The CLA line must be FIRST in the description — CLA.md's rule:
  "description": "I have read the CLA and I agree to it.\n\n<Symptom / Root cause / The fix / Repro>\n\nCloses #<n>",
  "source_branch": "fix/<name-on-fork>",
  "target_branch": "main",
  "target_project_id": 87486056,          # the upstream — hence "mr lives there"
  "remove_source_branch": True,
}))
EOF
# 2) POST to the FORK id (87832372), NOT to 87486056:
curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  --data @/private/var/folders/4j/6qhmcwk11w1fnch2lggk72jw0000gn/T/opencode/mr.json \
  "https://gitlab.com/api/v4/projects/87832372/merge_requests"
# 3) confirm facts + diff:
curl -sS -H "Authorization: Bearer $TOKEN" "https://gitlab.com/api/v4/projects/87486056/merge_requests/<iid>"
curl -sS -H "Authorization: Bearer $TOKEN" "https://gitlab.com/api/v4/projects/87486056/merge_requests/<iid>/changes" | grep '"old_path"'
```

- The MR then shows on upstream (`/taurustweak/taurus/-/merge_requests/<iid>`)
  and in the fork's own MR list marked "to taurustweak/taurus" — the owner often
  looks at the fork's tab.
- Editing later (`PUT …/merge_requests/<iid>` with a JSON file) works even on
  the *target's* endpoint — that was used to promote the probe "!5" into the
  real MR.
- Common failure modes to skip: `{"message":"403 Forbidden"}` from the target
  endpoint; `The provided content-type '' is not supported` when body was passed
  without `-H "Content-Type: application/json"`; glab's
  `--input`/`-f` forms mixing query-encoding into the description. curl + file.
- **Fallback if creation ever fails again:** file a well-written upstream
  *issue* (that endpoint still works) with the full write-up, the fork-branch
  pointer and the promise to tick the CLA in the MR once it exists — that is how
  issue #2 was delivered before the unlock was found.

## Upstream house rules (`CLAA.md` = `CLA.md`, README § Contributing)

- Every MR description starts with: `I have read the CLA and I agree to it.`
- Commit messages start `feat:` or `fix:` only (`chore:`/`docs:`/`refactor:`
  stay out of the release bump). `version.txt`/CHANGELOG are release-please's —
  never hand-edit.
- One concern per commit/branch/PR. Stack only on build-IPA branches.
- `scripts/check-layers.sh` runs before every build and fails on layer
  violations (`Core <- Settings <- Shared <- Native | Redesigned <- App`).

## Fork sync playbook (as asked by the owner)

- New user-facing fix → its own branch off upstream `main` tip:
  `git fetch origin main && git switch -c fix/<name> origin/main`, commit, then
  `git push fork fix/<name>`, then create the MR with the unlock.
- "Sync to my fork" = the same commit onto fork `main`'s lineage, fast-forward
  only: `git fetch fork main && git switch -c tmp-sync fork/main && git
  cherry-pick <commit> && git push fork tmp-sync:main && git switch -` (never
  push local `main` over fork `main`, never reconcile the two lineages).
- IPA branches may stack several fixes (that is exact what
  `fix/side-drawer-row` is) but never get pushed as an MR source — the MR would
  inherit the whole stack.
- If a maintainer needs the clean diff, cherry-pick onto `origin/main` instead
  (how `fix/drawer-settings-entry` was born from `fix/side-drawer-row`).

## Building a test IPA

```
cd /Users/diyarabbas/Desktop/taurus
THEOS=/Users/diyarabbas/Desktop/Spotify-Taurus-Safari/Spotify-Taurus/out/theos \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  env -u MAKELEVEL gmake release        # → out/Taurus-<version>.ipa, no FLEX
```

- Without `THEOS=` the Makefile exits at
  `~/theos/makefiles/common.mk: No such file`. `env -u MAKELEVEL` avoids a
  gmake recursion warning under recursive make calls.
- Newer IPA overwrites the same path — move the previous one aside first
  (`*.prev.ipa`, `*-CrashFix.ipa` pattern already in `out/`).
- **Prove the change is inside the shipped dylib before handing it over:**

```
rm -rf out/verify && mkdir out/verify && cd out/verify
unzip -qo ../Taurus-<version>.ipa "Payload/Spotify.app/Frameworks/spotifyglass.dylib"
DY="Payload/Spotify.app/Frameworks/spotifyglass.dylib"
nm -gU "$DY" | grep -c _SGLyricsNumber                    # 1 = lyrics-null fix inside
strings "$DY" | grep -c SideDrawerListCollectionView      # 0 = drawer row wiring gone
strings "$DY" | grep -c Settings_PlatformImpl             # >=1 = settings-list row hook kept
strings "$DY" | grep -c SideDrawer_ListPageImpl           # >=1 = drawer hook kept (badge)
```

## Device-side verification style

Install the IPA (owner's signing flow), **relaunch Spotify** (switches are read
at launch; most mod settings need a restart). Use narrow repros:
- crash loop: kili — "SUBSTANCE (Remixes)", watch whether ~10–30 s after launch
  still dies;
- UI entries: drawer + Settings page bottoms (the two screenshots in the root
  of the workspace, `01efda09…jpeg` / `24949452…jpeg`).

House rule: every task ends the reply with what the owner must check next (one
line or short list).

## GitLab state to be aware of next time

- MRs !5 (lyrics, `fix/lyrics-nsnull`) and !6 (drawer row,
  `fix/drawer-settings-entry`) are open, descriptions carry the CLA tick.
- Issue #2 upstream = the lyrics bug write-up (`Closes #2` in !5 — merging !5
  closes it).
- Upstream issue #1 titled "probe" is closed but NOT deletable without owner
  rights (DELETE → 403/404) — harmless residue; a maintainer can remove it.
- MRs #3/#4 by `diyarit` are already merged (proving this fork's MRs are
  welcome); MR #1 from another fork is open and spammy — ignore.

## Open thread / TODO

- "The lyrics button is disabled" after installing the CrashFix build — never
  investigated. First questions: which button (Spotify's mic icon vs. the mod's
  Lyrics row), which look (Redesigned?), which track/page, and `make log`
  around the tap. Nothing in the NSNull fix obviously touches that button; do
  not assume it was ours.
