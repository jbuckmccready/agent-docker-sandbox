---
name: web-browse
description: "Search the web and fetch/read pages via a real headless browser (CDP). Use this instead of curl when sites are JS-heavy or bot-protected."
---

# Web Browse

Search the web, then open/fetch pages in a **real browser session** (headless Chromium via CDP) and extract readable text.
Use this instead of `curl` when sites are JS-heavy or bot-protected.

## Setup

Run once before first use:

```bash
cd {baseDir}
npm install
```

## Configuration (optional)

Environment variables:

| Variable                 | Description                                     |
| ------------------------ | ----------------------------------------------- |
| `WEB_BROWSE_USER_AGENT`  | Override User-Agent string                      |
| `WEB_BROWSE_DAEMON_PORT` | Daemon port (default: 9377)                     |
| `WEB_BROWSE_CDP_PORT`    | CDP port (default: 9225)                        |
| `WEB_BROWSE_DEBUG_DUMP`  | Set to `1` to save screenshots/HTML on failures |

## Usage

```bash
# Search (results are cached for ~10 minutes)
{baseDir}/web-browse.js "your query"
{baseDir}/web-browse.js "your query" -n 10

# Fetch specific cached results by index
{baseDir}/web-browse.js --fetch 1,3,5

# Fetch a specific URL
{baseDir}/web-browse.js --url <url>          # truncated (~2000 chars)
{baseDir}/web-browse.js --url <url> --full   # full content
```

## Default behavior: persistent daemon (auto)

Direct calls automatically start/use a local daemon that keeps a **persistent headless browser+CDP session**.
This avoids browser startup overhead and helps with bot-protection pages that auto-clear (e.g. Anubis PoW).

### Daemon controls (optional, for debugging)

```bash
{baseDir}/web-browse.js --daemon status
{baseDir}/web-browse.js --daemon start
{baseDir}/web-browse.js --daemon stop
{baseDir}/web-browse.js --daemon restart
```

### Bypass daemon (one-shot)

```bash
{baseDir}/web-browse.js --no-daemon --url https://example.com
{baseDir}/web-browse.js --no-daemon "your query"
```

## Workflow

1. **Search** → see snippets → decide what to read
2. **Fetch by index** → `--fetch 1,3` opens those results and extracts content

```bash
{baseDir}/web-browse.js "rust async runtime"  # shows results
{baseDir}/web-browse.js --fetch 1,3           # fetches result #1 and #3
```

## Notes

- Content is truncated by default to save tokens; use `--full` for complete output.
- The daemon keeps a warm browser session for faster subsequent requests.
- CDP profile is stored in `~/.config/web-browse-cdp-profile/` (configurable via `--cdp-profile`).
