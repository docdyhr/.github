# Maintenance Plan — docdyhr org

**Owner:** Thomas Juul Dyhr | **Started:** 2026-05-05 | **19 active public repos**

## Architecture

Reusable workflows live in `.github/workflows/` in this repo and are referenced by consumers as:

```yaml
uses: docdyhr/.github/.github/workflows/<name>.yml@v1
```

Consumer repos carry only a thin caller (≤ 60 lines). To deploy an improvement to all consumers, push to this repo and re-tag `v1`.

## Reusable workflows

| Workflow | Purpose | Tag |
|---|---|---|
| `claude-dependabot-merge.yml` | Headless Claude Dependabot auto-merge. Callers on 2026-10-26: pigame and mac-diagnostics (see below); for the current list, run the inventory under Re-tagging | v1 |
| `claude-status-check.yml` | Repo health check (PRs, CI, issues, alerts, branches). Callers on 2026-10-26: pigame and mac-diagnostics (see below); for the current list, run the inventory under Re-tagging | v1 |

Caller templates for new consumers: `workflow-templates/`

### Retired: per-repo Claude callers (2026-10-21)

httpcheck, malwarespotter and simplenote-mcp-server carried thin callers for both Claude workflows above, and versiontracker had a dispatch-only caller of the merger saved as `dependabot-auto-merge.yml`. The callers and their templates were removed because nothing ran them:

- **No schedule.** The callers said "Schedule is owned by the cross-repo orchestrator", but the orchestrator never dispatches them. It does the status and Dependabot work itself in one session. The callers only ran on a push to their own file or by hand, so httpcheck's Claude Dependabot Auto-Merge had last run 130 days earlier.
- **The work is covered elsewhere.** The orchestrator checks all T1+T2 repos every week. Patch bumps merge natively: `dependabot-auto-merge.yml` in httpcheck, malwarespotter and versiontracker, `auto-merge.yml` in simplenote-mcp-server. The merge caller defaulted to `dry-run`, so a dispatched run merged nothing unless someone chose `live`.
- **Dispatching them would widen the token.** `GH_ORG_TOKEN` is read-only by design. Starting workflows in other repos needs Actions: write on every one of them.

versiontracker's `dependabot-auto-merge.yml` is now the native workflow httpcheck and malwarespotter use, plus a `ruff` exclusion. pigame (T4, outside the standard and the orchestrator's repo list) still has both callers, left alone under the T4 rule; its next `/status` will flag their driver claim again.

mac-diagnostics (private, in neither the tier table nor the orchestrator's repo list) also keeps both callers (decided 2026-10-26). The 10-21 count went by file name and missed it. None of the three reasons above applies to it: each caller has its own weekly `schedule:` (status Monday 07:00 UTC, merger Sunday 06:00 UTC), both run green, and the orchestrator does not cover the repo. The status run does real work (its Claude job ran for 41 s on 2026-10-26). The merger stops at "Nothing to do" when there is no Dependabot PR, so it costs no Claude run.

The reusable workflows stay at `v1` for one-off use. To bring a caller back, write it from the reusable workflow's header, and give it a real trigger: a `schedule:` of its own, or a dispatch from the orchestrator.

## Orchestrator (this repo only)

`claude-maintenance-orchestrator.yml` — Cross-repo scheduled maintenance. Runs directly from this repo (not a reusable workflow). Requires `GH_ORG_TOKEN` secret set in this repo's settings.

| Schedule (UTC) | Task |
|---|---|
| Sunday 06:00 | `dependabot` — triage Dependabot PRs across all T1+T2 repos |
| Monday 07:00 | `status` — health check all T1+T2 repos, create issue if CRITICAL |

## Re-tagging v1 (deploy improvements)

```bash
git tag -f -a v1 -m "v1 — <summary of change>"
git push -f origin v1
```

All consumers pick up the change automatically on next run — no PR required.

To see who the consumers are, run the inventory (owner's local tooling) instead of keeping a list here. A hand-written list was wrong twice: on 2026-10-21 ("all 3 consumers") and again on 2026-10-23, when mac-diagnostics was missing:

```bash
bash ~/.claude/skills/_shared/workflow-consumers.sh docdyhr <reusable-file>.yml   # CONSUMER <repo> <caller-path> → …@<ref>, then READ <n> repos, <m> files
```

It finds callers by their `uses:` target, so a caller saved under another file name still counts. Exit 0 means at least one consumer, 1 means none (everything was read), and 2 means some repo or file could not be read, so the list may be short. Never read exit 2 as "no consumers".

**Exception: a change that needs a new `GITHUB_TOKEN` scope.** A called workflow can't raise the caller's permissions. Re-tagging `v1` before every caller grants the new scope makes those callers' runs fail to start. Land the scope in each caller's `permissions:` block first (extra caller scopes are harmless under the old `v1`). Then check each caller's default branch:

```bash
bash ~/.claude/skills/_shared/workflow-consumers.sh docdyhr <reusable-file>.yml > /tmp/callers.txt; echo "inventory exit $?"   # must be 0
awk '$1 == "CONSUMER" {print $2, $3}' /tmp/callers.txt | while read -r r f; do
  printf '%s %s: ' "$r" "$f"; gh api "repos/$r/contents/$f" --jq .content </dev/null | base64 -d | grep -c '<new-scope>: read'
done
```

Re-tag only when the inventory exited 0 and every count is 1. The scopes `claude-status-check.yml` needs are listed in `.github/workflows/README.md`.

## The docdyhr standard (Tier 1–2 repos)

- `main` as default branch
- `.github/CODEOWNERS` with `* @docdyhr`
- `.github/dependabot.yml` (ecosystem-appropriate, grouped, weekly)
- `.github/workflows/` with **only callers** — no inline blobs
- `CLAUDE.md` at repo root
- Branch protection on `main`: required checks, linear history
- License: MIT | Tagged releases

## Repo tiers

| Tier | Repos | Approach |
|---|---|---|
| T1 flagship | mcp-wordpress, simplenote-mcp-server | Full standard + release-please |
| T2 active | batless, drop2md, versiontracker, malwarespotter, httpcheck, macwhisper-mcp-server | Full standard, manual semver |
| T3 helper | homebrew-tap, homebrew-versiontracker | Trimmed: homebrew-bump caller + ruby tests only |
| T4 legacy | pigame, mac_changer, ansible-keyring, DALL-E-Image-Generator-Script, AppleScriptUtils | Leave alone unless reopened |

## Scheduled maintenance

Implemented in `claude-maintenance-orchestrator.yml` (Phase 5). See Orchestrator section above.

## Phases

| Phase | Status | Goal |
|---|---|---|
| 0 — Hygiene | ✅ Done | Archived repos, deleted detritus, migrated master→main |
| 1 — Community files | ✅ Done | This repo; community health files cascade via GitHub defaults |
| 2 — Reusable workflows | ✅ Done | claude-dependabot-merge + claude-status-check; all 3 consumers migrated. Their callers were retired on 2026-10-21 in favour of the orchestrator |
| 3 — Claude Code skills | 🔄 Active | repo-audit, workflow-migrate |
| 4 — Hooks | Planned | auto-format, tests-before-stop |
| 5 — Scheduled maintenance | ✅ Done | Cross-repo orchestrator in this repo (`claude-maintenance-orchestrator.yml`) |
