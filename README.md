# Agent Docker Sandbox

Portable Docker sandbox for running AI agents interactively. Should work on linux, macOS (tested), and Windows with WSL2.

Currently just installs pi agent, and has pi config mounted, but this can be used to run anything really.

See `Dockerfile` for base image and installed tools. `docker-compose.yml` and `docker-compose.override.yml` for the sandbox and proxy configuration.

## Usage

`./workspace` is read/write mounted into the container as `/workspace` - this is where you probably want everything the agent will work with.

`./pi_config` is read/write mounted into the container as `/home/agent/.pi` for pi agent config. Write is required for sessions, extension generated files, `auth.json` and `settings.json`.

`/home/agent` is persisted via a named Docker volume, so caches, installed tools, etc. will persist across container restarts. Note that `docker compose down -v` will delete this volume, but the bind mounts (`./workspace` and `./pi_config`) are unaffected.

Agent runs as a non-root user (`agent`) with passwordless sudo, so it can install packages, etc. All three mounted paths (`/workspace`, `/home/agent/.pi`, and `/home/agent`) persist across container restarts.

Build and start an interactive shell:

```bash
./run.sh
```

Custom container name (default is `agent-sandbox`):

```bash
./run.sh -n my-sandbox
```

Pass extra args to `docker compose run` after `--`:

```bash
./run.sh -- --service-ports
```

Attach another terminal to the running container:

```bash
docker exec -it <container-name> bash
```

Stop and remove the container:

```bash
docker compose down
```

Delete the persisted home volume (caches, installed tools, etc.):

```bash
docker compose down -v
```

## Networking

By default, the sandbox uses a domain allowlist proxy (see `proxy/allowlist.txt`).
Only requests to listed domains are allowed — all other internet access is blocked.

To disable the proxy and allow full internet access (skips using the `docker-compose.override.yml` that configures the proxy):

```bash
./run.sh --no-proxy
```

To fully disable networking:

```yaml
# docker-compose.override.yml
services:
  sandbox:
    network_mode: none
```

### Domain allowlisting

Edit `proxy/allowlist.txt` to control which domains are accessible. After
changing the allowlist, reload the proxy:

```bash
docker compose exec proxy squid -k reconfigure
```

The proxy runs as a Squid sidecar on an internal Docker network — the sandbox has no direct route to the internet. Direct connections (including `curl` without the proxy) will fail. Only requests to domains listed in the allowlist are permitted.

### Known limitations

**Zig package manager does not work through the proxy.** Zig's built-in HTTP client does not properly handle HTTPS proxy tunneling when fetching dependencies (e.g. `git+https://` URLs in `build.zig.zon`). Fetches will fail with `EndOfStream` errors.

Workarounds:

- **Pre-fetch on the host:** run `zig fetch` or `zig build --fetch` on the host machine before starting the container.
- **Disable the proxy:**
  ```bash
  ./run.sh --no-proxy
  ```

## Notifications

`run.sh` bridges notifications from the container to native OS notifications on the host. The pi notify extension (`pi_config/agent/extensions/notify.ts`) detects when it's running inside Docker and writes JSON signal files to `~/.pi/notifications/`. A file watcher on the host picks these up and fires native notifications.

This only activates when using `run.sh` — running `docker compose run` directly will not produce notification files.

### Requirements

| Platform | Watcher tool                                     | Notification tool                                                     |
| -------- | ------------------------------------------------ | --------------------------------------------------------------------- |
| macOS    | `fswatch` (`brew install fswatch`)               | `terminal-notifier` (`brew install terminal-notifier`) or `osascript` |
| Linux    | `inotifywait` (`sudo apt install inotify-tools`) | `notify-send`                                                         |
| WSL      | `inotifywait` (`sudo apt install inotify-tools`) | PowerShell balloon tip (built-in)                                     |

If the watcher tool is missing, `run.sh` prints a warning and continues without notification bridging.

## Git Workflow

Create a fine grained personal access token for GitHub that is readonly, then authenticate gh cli inside the container: `echo "<your_token>" | gh auth login --with-token`.
The agent can then do queries using the `gh` CLI tool to fetch PRs, comments, issues, etc. from GitHub, but it won't be able to push any changes.

The global git config for the agent user is pre-configured in the Docker image (user: `Agent`, email: `agent@sandbox.local`), which allows the agent to make local commits that are clearly from the agent.

Once changes are ready to be pushed, the commits can be amended or rebased with the correct author information (and signed if necessary) before pushing to GitHub from the host machine.

## Headed Browser (Playwright)

The sandbox includes `@playwright/cli` (`playwright-cli`) with Chromium for browser automation. It works headless out of the box. For headed mode (visible browser window), the sandbox uses Xvfb + VNC so you can see and interact with the browser from your Mac.

### Setup (one-time)

Install a VNC client on macOS:

```bash
brew install --cask tigervnc-viewer
```

### Running with headed browser support

Start the sandbox with `--service-ports` to publish the VNC port:

```bash
./run.sh -n <container-name> -- --service-ports
```

Inside the container, start the virtual display and VNC server:

NOTE: you need to have `start-vnc.sh` in the `./workspace` directory so it's mounted into the container at `/workspace/start-vnc.sh`.

```bash
source /workspace/start-vnc.sh
```

Connect from macOS:

```bash
open -a TigerVNC
```

Enter `localhost:5900` in the connection dialog. You'll see a black 1280×720 desktop.

Now when the agent (or you) runs a headed browser, it appears in the VNC window:

```bash
playwright-cli open --browser=chromium --headed https://example.com
```

### Headless mode

If you don't need to see the browser, skip `--service-ports` and `start-vnc.sh`. With no VNC server running, `playwright-cli` defaults to headless on Linux. You still get full functionality — screenshots, snapshots, page interaction, etc:

```bash
playwright-cli open --browser=chromium https://example.com
playwright-cli screenshot
playwright-cli snapshot
```

### Notes

- **ARM64 (Apple Silicon):** Use `--browser=chromium`, not `--browser=chrome`. Chrome isn't available for ARM64 Linux; Chromium works fine.
- **Headed flag:** `playwright-cli` daemon mode defaults to headless even with `DISPLAY` set. Always pass `--headed` explicitly when you want a visible browser.
- **Browser binaries** are stored in `~/.cache/ms-playwright/` inside the persisted home volume. If you update `@playwright/cli`, run `playwright-cli install-browser` inside the container to download matching browser binaries.
- **VNC is password-free** and only bound to localhost (via the Docker port mapping). It's not exposed to your network.
