# Agent Docker Sandbox

Portable Docker sandbox for running AI agents interactively. Should work on linux, macOS (tested), and Windows with WSL2.

Currently just installs pi agent, and has pi config mounted, but this can be used to run anything really.

See `Dockerfile` for base image and installed tools. `docker-compose.yml` and `docker-compose.override.ym` for the sandbox and proxy configuration.

## Usage

`./workspace` is read/write mounted into the container as `/workspace` - this is where you probably want everything the agent will work with.

`./pi_config` is read/write mounted into the container as `/home/agent/.pi` for pi agent config. Write is required for sessions, extension generated files, `auth.json` and `settings.json`.

`/home/agent` is persisted via a named Docker volume, so caches, installed tools, etc. will persist across container restarts. Note that `docker compose down -v` will delete this volume, but the bind mounts (`./workspace` and `./pi_config`) are unaffected.

Agent runs as a non-root user (`agent`) with passwordless sudo, so it can install packages, etc. All three mounted paths (`/workspace`, `/home/agent/.pi`, and `/home/agent`) persist across container restarts.

Build and start an interactive shell:

```bash
docker compose run --rm --build --name agent-sandbox sandbox
```

To run multiple unique containers, use a unique name for each:

```bash
docker compose run --rm --build --name agent-sandbox-2 sandbox
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

To disable the proxy and allow full internet access, skip the override file:

```bash
docker compose -f docker-compose.yml run --rm --build --name agent-sandbox sandbox
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
