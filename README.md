<div align="right">

<a href="https://railway.com?referralCode=QhjuBc">

  <img width="160" src="https://raw.githubusercontent.com/docdyhr/.github/main/assets/railway-corner-v2@2x.png" alt="Deploy on Railway — $20 free credits">

</a>

</div>

# docdyhr/.github

Organisation-wide community health files and workflow templates for all repositories under [docdyhr](https://github.com/docdyhr).

## How the cascade works

GitHub automatically applies files from this repository as defaults for any repo in the organisation that does **not** have its own copy. One edit here propagates to all repos without touching them individually.

| File | Purpose |
|---|---|
| `CODE_OF_CONDUCT.md` | Community standards |
| `CONTRIBUTING.md` | Contribution guidelines |
| `SECURITY.md` | Vulnerability disclosure policy |
| `SUPPORT.md` | Where to get help |
| `FUNDING.yml` | Sponsor links |
| `PULL_REQUEST_TEMPLATE.md` | Default PR checklist |
| `ISSUE_TEMPLATE/` | Bug, feature, and routing templates |

Individual repositories can override any of these by placing their own version in `.github/` or at the repo root.

## Workflow templates

The `workflow-templates/` directory is a placeholder for **Phase 2**: reusable `workflow_call` workflows that replace the duplicated 27 KB CI blobs currently spread across httpcheck, malwarespotter, and pigame.

## Roadmap

| Phase | Status | Goal |
|---|---|---|
| 1 — Community files | **Done** | This repo; cascade via GitHub defaults. |
| 2 — Reusable workflows | Planned | Extract CI blobs; consumers use 10-line callers. |
| 3 — Claude Code skills | Planned | Personal skills for `repo-audit`, `workflow-migrate`, etc. |

## References

- [Creating a default community health file](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file)
- [Reusing workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
- [mcp-wordpress](https://github.com/docdyhr/mcp-wordpress) — gold-standard reference repo
