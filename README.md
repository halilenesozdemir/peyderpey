# peyderpey

A small pomodoro timer. *Peyderpey* is Turkish for "step by step": every focus session is one step (*pey*), and four steps make a stair.

**Live:** [peyderpey.app](https://peyderpey.app)

## Features

- 25 min focus, 5 min short break, 15 min long break after every fourth step
- Stair view that fills in as you complete steps
- Daily count of finished steps, kept in `localStorage`
- Remaining time in the tab title, a short chime when a session ends
- `Space` starts and pauses

## Stack

Plain HTML, CSS and JavaScript in `site/`, no build step and no dependencies. Hosted on Cloudflare Pages.

## Run locally

```sh
npx serve site
```

Or open `site/index.html` directly.

## Deploy

`main` is protected. Every change goes through a pull request; the workflow in `.github/workflows/cloudflare.yml` posts a preview URL on the PR and deploys to production after the merge.
