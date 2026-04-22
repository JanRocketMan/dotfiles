#!/usr/bin/env bash
# Injected via SessionStart hook when running inside nanobox.
# Silent (no output) when NBOX is unset (claude-unsafe / bare claude).

[[ "${NBOX:-}" != "1" ]] && exit 0

cat <<'EOF'
# Sandbox Environment

You are running inside a bwrap (bubblewrap) sandbox. Respect these constraints:

## Filesystem
- `$HOME` is a tmpfs — only specific directories are bind-mounted in
- Project directory is read-write
- `.venv` is read-only — do NOT run `pip install` or modify the venv
- `.env` / `.env.*` files are masked to `/dev/null` — you cannot read secrets (`.example` templates are not masked)
- System dirs (`/usr`, `/lib`, `/etc`) are read-only

## SSH & credentials
- SSH private keys are hidden — only the agent socket is forwarded
- Use SSH (not HTTPS) for git remotes — HTTPS credentials are not available
- If a credential-injection proxy is active, authenticated HTTP services work
  transparently; you do not need tokens

## GPU
- NVIDIA GPUs are available if the host has them (auto-detected)
- CUDA/NCCL/TORCH env vars are forwarded from the host

## What to avoid
- Don't try to access paths outside the project dir or mounted tool dirs
- Don't try to install system packages or modify read-only mounts
- Don't try to read `.env` files (they appear empty)
- Don't try to read `~/.ssh/id_*` or any private key files
EOF
