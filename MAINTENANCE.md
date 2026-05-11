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
| `claude-dependabot-merge.yml` | Weekly headless Claude Dependabot auto-merge | v1 |
| `claude-status-check.yml` | Weekly repo health check (PRs, CI, issues, alerts, branches) | v1 |

Caller templates for new consumers: `workflow-templates/`

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
| 2 — Reusable workflows | ✅ Done | claude-dependabot-merge + claude-status-check; all 3 consumers migrated |
| 3 — Claude Code skills | 🔄 Active | repo-audit, workflow-migrate |
| 4 — Hooks | Planned | auto-format, tests-before-stop |
| 5 — Scheduled maintenance | ✅ Done | Cross-repo orchestrator in this repo (`claude-maintenance-orchestrator.yml`) |
