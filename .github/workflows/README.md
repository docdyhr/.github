# Reusable workflows

This directory holds **reusable workflows** for `docdyhr/*` repos.

Unlike the community health files at the repo root (`SECURITY.md`, `CONTRIBUTING.md`, etc.), reusable workflows do **not** auto-cascade. Consumer repos must explicitly reference them via `uses:`.

## How consumers reference these

```yaml
jobs:
  call:
    uses: docdyhr/.github/.github/workflows/<workflow-name>.yml@v1
    permissions:
      # ... per-job permissions go here, not in the reusable workflow
    secrets: inherit
    with:
      # ... inputs defined by the reusable workflow's `on.workflow_call.inputs`
```

## Pinning rules

- **Always pin to a tag** (`@v1`, `@v2`, ...), never a branch.
- Re-tagging is force-push to a tag — audit-logged, but trustworthy because only repo admins can do it.
- Pinning to `@main` gives anyone with write access to this repo silent code execution on every consumer's runner. Never do this.

## Versioning

- `v1`: stable, breaking changes go to `v2`.
- Minor improvements and bug fixes re-tag `v1` to the new commit (consumers pick them up automatically).
- Breaking input/secret changes get a new major tag (`v2`) and consumers migrate when ready.

## Workflows available

| Name | Purpose | Tag |
|---|---|---|
| `claude-dependabot-merge.yml` | Headless Claude evaluation + merge of Dependabot PRs. Only pigame (T4) still calls it | `v1` |
| `claude-status-check.yml` | Repo health check — PRs, CI, issues, Dependabot, stale branches. Only pigame (T4) still calls it | `v1` |
| `python-ci.yml` | Five-stage Python pipeline: lint → package → test matrix → gate → release; supports `pip` and `uv` | `v1` |
| `security-scan.yml` | Python security: Bandit SAST + pip-audit dependency audit + hardcoded-secrets grep | `v1` |
| `security.yml` | Trivy filesystem scan (vulns + secrets); SARIF → Code Scanning | `v1` |
| `codeql.yml` | GitHub CodeQL static analysis; SARIF → Code Scanning | `v1` |
| `claude-maintenance-orchestrator.yml` | Cross-repo scheduled orchestrator — runs health checks and Dependabot triage across all T1+T2 repos from this repo on a schedule | — |

`claude-maintenance-orchestrator.yml` is not a reusable workflow — it runs directly from this repo via `schedule` and `workflow_dispatch`. It requires the `GH_ORG_TOKEN` secret: a fine-grained PAT for all target repos with read-only Contents, Pull requests, Issues, Actions, Commit statuses and Dependabot alerts. Claude runs on the Claude subscription through the `CLAUDE_CODE_OAUTH_TOKEN` secret (create it with `claude setup-token`), never an API key. Pre-flight fails fast if `CLAUDE_CODE_OAUTH_TOKEN` is missing or malformed or a set `GH_ORG_TOKEN` is rejected, and a status run fails if no repo returned data.

The orchestrator does the status and Dependabot work itself, so no T1/T2 repo calls `claude-dependabot-merge.yml` or `claude-status-check.yml` any more; only pigame (T4) still does. The per-repo callers and their `workflow-templates/` files were retired on 2026-10-21; why is in `MAINTENANCE.md`.

### `claude-status-check.yml`: caller permissions and token

A called workflow can only keep or reduce the caller's `GITHUB_TOKEN` scopes, never raise them. So every caller must grant all of these, or its runs fail to start:

```yaml
    permissions:
      contents: read
      issues: write                # read for the report, write for the CRITICAL issue
      pull-requests: read
      actions: read                # CI runs
      checks: read                 # PR CI rollup
      statuses: read               # PR CI rollup
      vulnerability-alerts: read   # Dependabot alerts
```

Secret-scanning alerts can't be read with `GITHUB_TOKEN` at all. To include them, give the caller repo an optional `STATUS_CHECK_ALERTS_TOKEN` secret: a fine-grained PAT with read-only "Secret scanning alerts" and "Metadata" on that repo. The workflow uses it in a pre-fetch step only, never hands it to Claude, and puts only a summary (no secret values) into the prompt. Without it, the report says "NOT CHECKED". A 403 from any other endpoint now shows as "NOT CHECKED — token lacks permission" instead of N/A, so a permission gap can't pass for a disabled feature.

When adding a scope here, update every caller **before** re-tagging `v1` (see `MAINTENANCE.md`). The block above is the current list; there is no caller template any more.

More to come: `node-ci.yml`, `rust-ci.yml`, `release-*.yml`, `homebrew-bump.yml`, `stale.yml`.
