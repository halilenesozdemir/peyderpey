# Project rules

peyderpey: a static mini pomodoro app ("pey" = step). Served from `site/` (no build step).

- Hosting: Cloudflare Pages, project `peyderpey`, domain `peyderpey.app` (DNS in Cloudflare).
- Deploy: never deploy by hand. Branch → PR (preview URL is commented on the PR) → merge to `main` → `.github/workflows/cloudflare.yml` deploys to production.
- `main` is protected; every change goes through a PR.
- Secrets live in GitHub Actions secrets (`CLOUDFLARE_API_TOKEN`) or a local `.env`; `.env` is never committed. The user enters secrets in their own terminal, never in chat.
- Non-secret config is in Actions variables: `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`.
- Before anything that deletes (Pages project, DNS records, repo) show what will go and wait for approval.
- If cloud resources are added later (AWS etc.): tag every resource `project=peyderpey`, region `eu-central-1`, show `terraform plan` and wait for approval before apply/destroy.
- Deployment playbooks: `.claude/skills/` (installed from `furkandogmus/sifirdan-canliya`); start with `sifirdan-canliya`.
