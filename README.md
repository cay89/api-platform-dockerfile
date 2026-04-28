# Dockerized dev environment

Minimal, containerized development environment for the API Platform Core repo, focused on the **Laravel port** (`src/Laravel`) bug-fix and test-writing workflow. Tuned for macOS (named volumes for `vendor/` directories to avoid bind-mount slowness).

## What's inside the image

- `php:8.5-cli-bookworm` (the latest stable PHP version used by the CI `laravel` job)
- PHP extensions: `intl`, `bcmath`, `pdo_sqlite`, `zip`, `opcache`
- `composer` (installed via the official installer script)
- `git`, `unzip`
- `soyuka/pmu` composer plugin **globally** (required for monorepo package linking)

To switch PHP versions, change `8.5` in the first line of the `Dockerfile` (e.g. `php:8.4-cli-bookworm`) and rebuild.

## Build

```bash
docker build -t apip-dev .
```

## Run — interactive shell

```bash
docker run --rm -it \
  -v "$(pwd)":/app \
  -v apip-vendor-root:/app/vendor \
  -v apip-vendor-laravel:/app/src/Laravel/vendor \
  -v apip-composer-cache:/root/.composer/cache \
  apip-dev
```

What the volumes do:

| Volume | Type | Purpose |
|---|---|---|
| `"$(pwd)":/app` | bind mount | Live mount of the repo → host-side code changes are immediately visible inside the container. |
| `apip-vendor-root` | named volume | Keeps the root `vendor/` in a named volume → orders of magnitude faster on macOS than a bind mount. |
| `apip-vendor-laravel` | named volume | Same for `src/Laravel/vendor`. |
| `apip-composer-cache` | named volume | Composer download cache reused across builds. |

## One-time setup inside the container

Run these once after the first `docker run` (mirrors the CI `laravel` job):

```bash
composer global link . --permanent          # register this repo as a PMU path source
composer api-platform/laravel update        # install Laravel package deps into src/Laravel/vendor
cd src/Laravel
composer link ../../                        # symlink api-platform/* deps to /app/src/*
composer build                              # vendor/bin/testbench workbench:build (fixtures, sqlite db)
```

**Persistence:** `--rm` removes the container, but the named volumes (`apip-vendor-*`, `apip-composer-cache`) and the bind-mounted source survive. So the installed `vendor/` directories and the workbench fixtures stay in place across container restarts — you do **not** need to re-run this setup for normal edit/test cycles. Only re-run it after wiping volumes (see below) or after a fresh clone.

## Running tests

Inside the container, in `src/Laravel`:

```bash
vendor/bin/testbench package:test Tests/NoOperationResourceTest.php
```

Or as a one-shot from the host (container starts → test runs → exits):

```bash
docker run --rm -it \
  -v "$(pwd)":/app \
  -v apip-vendor-root:/app/vendor \
  -v apip-vendor-laravel:/app/src/Laravel/vendor \
  -v apip-composer-cache:/root/.composer/cache \
  -w /app/src/Laravel \
  apip-dev \
  vendor/bin/testbench package:test Tests/NoOperationResourceTest.php
```

Thanks to the live bind mount, any test or source file you edit on the host runs with the latest version on the next invocation — no rebuild needed.

## Useful commands

Fresh workbench fixtures (drop the sqlite db), inside the container:

```bash
cd /app/src/Laravel
vendor/bin/testbench workbench:drop-sqlite-db
```

Reset vendors / composer cache on the host — wipes the named volumes, so the **one-time setup must be re-run** afterwards:

```bash
docker volume rm apip-vendor-root apip-vendor-laravel apip-composer-cache
```

Rebuild the image (e.g. after switching PHP versions):

```bash
docker build --no-cache -t apip-dev .
```

## Optional: shell alias

To avoid typing the long `docker run` command every time, add this to your `~/.zshrc` / `~/.bashrc`:

```bash
alias apip='docker run --rm -it \
  -v "$(pwd)":/app \
  -v apip-vendor-root:/app/vendor \
  -v apip-vendor-laravel:/app/src/Laravel/vendor \
  -v apip-composer-cache:/root/.composer/cache \
  apip-dev'
```

Then, from the repo root:

```bash
apip                                                                          # interactive shell at /app
apip bash -c 'cd src/Laravel && vendor/bin/testbench package:test Tests/NoOperationResourceTest.php'
```

(Use `bash -c` for one-shot test runs because the workbench's `testbench` binary lives in `src/Laravel/vendor/bin/`, not in the root vendor.)

## Notes

- **No separate web server** (nginx / Caddy / FrankenPHP) — `testbench` uses its own in-process HTTP client to test the Laravel app, so none is needed.
- **No Xdebug by default** — if you want it, append `xdebug` to the `install-php-extensions` line in the `Dockerfile` (it slows tests down, hence not enabled by default).
- **No MariaDB / MongoDB / Mercure / Elasticsearch** — the Laravel port runs on sqlite. If you also need to run the Symfony port's full integration test suite, those services must be added separately (a `compose.yaml` is more practical for that).
- The live mount needs **no extra setup** — `-v "$(pwd)":/app` picks up host file changes automatically. In PHP CLI mode, `opcache.validate_timestamps=1` is the default, and every test runs in a fresh PHP process, so stale cache is not a concern.
