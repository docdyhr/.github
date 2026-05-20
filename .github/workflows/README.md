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
| `claude-dependabot-merge.yml` | Headless Claude evaluation + merge of Dependabot PRs | `v1` |
| `claude-status-check.yml` | Weekly repo health check — PRs, CI, issues, Dependabot, stale branches | `v1` |
| `python-ci.yml` | Five-stage Python pipeline: lint → package → test matrix → gate → release; supports `pip` and `uv` | `v1` |
| `security-scan.yml` | Python security: Bandit SAST + pip-audit dependency audit + hardcoded-secrets grep | `v1` |
| `security.yml` | Trivy filesystem scan (vulns + secrets); SARIF → Code Scanning | `v1` |
| `codeql.yml` | GitHub CodeQL static analysis; SARIF → Code Scanning | `v1` |
| `claude-maintenance-orchestrator.yml` | Cross-repo scheduled orchestrator — runs health checks and Dependabot triage across all T1+T2 repos from this repo on a schedule | — |

`claude-maintenance-orchestrator.yml` is not a reusable workflow — it runs directly from this repo via `schedule` and `workflow_dispatch`. It requires the `GH_ORG_TOKEN` secret (fine-grained PAT with `contents:read` + `pull-requests:read` for all target repos).

More to come: `node-ci.yml`, `rust-ci.yml`, `release-*.yml`, `homebrew-bump.yml`, `stale.yml`.
