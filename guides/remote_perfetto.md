# Remote Perfetto Setup Guide

Self-hosted Perfetto UI + server-side trace processing for remote servers (e.g. SLURM clusters).
Traces never leave the server - only small SQL query results travel over SSH.

## Architecture

```
Local machine (browser)              Remote server
-----------------------              -------------
Browser <--SSH:8101--> Perfetto UI   (static HTML/JS/CSS)
        <--SSH:9001--> trace_processor_shell (loads trace, answers SQL queries)
```

- Port 8101: static UI served by Python HTTP server
- Port 9001: trace_processor_shell --httpd (parses trace server-side, serves query results)
- The browser sends small SQL queries (~bytes), gets back small result sets (~KB)
- A full profiling session transfers ~1-5MB total, regardless of trace size

## Prerequisites

- Python 3.10+ (see Python version note below)
- Git
- SSH access with port forwarding

### Python version note

The build system uses Python type hints (`list[Flag]`) that require Python 3.9+.
If the system python3 is older (e.g. 3.8 on Ubuntu 20.04), you have two options:

**Option A (recommended)**: Create a venv with a newer Python and activate it before
every build command in this guide:

```bash
# Create once (adjust python3.11 to whatever >= 3.10 is available):
python3.11 -m venv .venv

# Activate before every build step:
source .venv/bin/activate
```

**Option B**: Add a compatibility import to `gn/write_buildflag_header.py`.
Find the imports block at the top and add `from __future__ import annotations`
as the very first import (before `import argparse`):

```python
from __future__ import annotations

import argparse
import os
...
```

This guide assumes Option A. Every build command below should be run with the
venv activated.

## Step 1: Clone and install build dependencies

```bash
git clone https://github.com/google/perfetto.git
cd perfetto

# UI dependencies (node, pnpm, emsdk - all downloaded into the repo)
tools/install-build-deps --ui

# C++ toolchain (clang, etc. - also into the repo)
tools/install-build-deps
```

Everything is installed inside the repo directory. Nothing global.

To keep pnpm's content store inside the repo too (prevents writes to ~/.local/share/pnpm):

```bash
export PNPM_HOME="$(pwd)/buildtools/pnpm-home"
export npm_config_store_dir="$(pwd)/buildtools/pnpm-store"
```

## Step 2: Initialize Emscripten cache

The UI build uses Emscripten (WASM compiler). Its cache must be initialized before
the first parallel build, otherwise a race condition on cache.lock causes failures.

```bash
mkdir -p buildtools/linux64/emsdk/emscripten/cache
EM_CONFIG=$(pwd)/gn/standalone/.emscripten \
  buildtools/linux64/emsdk/emscripten/embuilder build MINIMAL
```

## Step 3: Build the UI

```bash
# Set pnpm env vars (if not already exported in Step 1):
export PNPM_HOME="$(pwd)/buildtools/pnpm-home"
export npm_config_store_dir="$(pwd)/buildtools/pnpm-store"

ui/build
```

Output lands in `out/ui/ui/dist/` (also symlinked as `ui/out/dist/`).

## Step 4: Build trace_processor_shell

```bash
tools/gn gen out/linux_clang_release --args='is_clang=true is_debug=false'
tools/ninja -C out/linux_clang_release trace_processor_shell
```

Binary: `out/linux_clang_release/trace_processor_shell`

## Step 5: Patch CORS origins

The trace_processor_shell only allows CORS requests from a hardcoded list of origins.
If your UI is served on a port not in that list, the browser will be blocked.

Edit `src/trace_processor/rpc/httpd.cc`, find `kDefaultAllowedCORSOrigins[]` and add
your UI's origin:

```cpp
const char* kDefaultAllowedCORSOrigins[] = {
    "https://ui.perfetto.dev",
    "http://localhost:10000",
    "http://127.0.0.1:10000",
    "http://localhost:8101",    // <-- add your UI port
    "http://127.0.0.1:8101",   // <-- add your UI port
};
```

Then rebuild:

```bash
tools/ninja -C out/linux_clang_release trace_processor_shell
```

## Step 6: Auto-connect to loaded traces

By default the UI shows a confirmation dialog every time it detects a trace_processor
with a preloaded trace. To skip it and auto-connect:

Edit `ui/src/frontend/rpc_http_dialog.ts`, find the `// Check if pre-loaded:` block
in `checkHttpRpcConnection()` and replace the entire if-block:

```typescript
  // Check if pre-loaded:
  if (tpStatus.loadedTraceName) {
    // If a trace is already loaded in the trace processor (e.g., the user
    // launched trace_processor_shell -D trace_file.pftrace), prompt the user to
    // initialize the UI with the already-loaded trace.
    const result = await showDialogToUsePreloadedTrace(tpStatus);
    switch (result) {
      case PreloadedDialogResult.Dismissed:
      case PreloadedDialogResult.UseRpcWithPreloadedTrace:
        AppImpl.instance.openTraceFromHttpRpc();
        return;
      case PreloadedDialogResult.UseRpc:
        // Resetting state is the default.
        return;
      case PreloadedDialogResult.UseWasm:
        forceWasm();
        return;
      default:
        const x: never = result;
        throw new Error(`Unsupported result ${x}`);
    }
  }
```

With:

```typescript
  // Check if pre-loaded:
  if (tpStatus.loadedTraceName) {
    AppImpl.instance.openTraceFromHttpRpc();
    return;
  }
```

Then remove the now-unused code to avoid TypeScript compile errors. Delete these
three items from the same file (they appear after the `checkHttpRpcConnection`
function):

1. The `getPromptMessage` function (starts with `function getPromptMessage(tpStatus`)
2. The `PreloadedDialogResult` enum
3. The `showDialogToUsePreloadedTrace` function

Then rebuild the UI:

```bash
export PNPM_HOME="$(pwd)/buildtools/pnpm-home"
export npm_config_store_dir="$(pwd)/buildtools/pnpm-store"
ui/build
```

## Step 7: Enable multiple simultaneous traces

By default, only one trace_processor instance (port 9001) works without extra
configuration. To view multiple traces side-by-side in separate browser tabs,
two changes are needed:

### 7a: Patch the Content Security Policy

Edit `ui/src/frontend/index.ts`, find the `setupContentSecurityPolicy()` function.
Locate the `rpcPolicy` array declaration:

```typescript
  let rpcPolicy = [
    'http://127.0.0.1:9001', // For trace_processor_shell --httpd.
    'ws://127.0.0.1:9001', // Ditto, for the websocket RPC.
    'ws://127.0.0.1:9167', // For Web Device Proxy.
  ];
  if (CSP_WS_PERMISSIVE_PORT.get()) {
    const route = Router.parseUrl(window.location.href);
    if (/^\d+$/.exec(route.args.rpc_port ?? '')) {
      rpcPolicy = [
        `http://127.0.0.1:${route.args.rpc_port}`,
        `ws://127.0.0.1:${route.args.rpc_port}`,
      ];
    }
  }
```

Replace with:

```typescript
  const rpcPolicy = [
    'http://127.0.0.1:9001', // For trace_processor_shell --httpd.
    'ws://127.0.0.1:9001', // Ditto, for the websocket RPC.
    'ws://127.0.0.1:9167', // For Web Device Proxy.
  ];
  // Allow ports 9002-9010 so multiple trace_processor instances can run
  // in parallel, each on a different port.
  for (let port = 9002; port <= 9010; port++) {
    rpcPolicy.push(`http://127.0.0.1:${port}`);
    rpcPolicy.push(`ws://127.0.0.1:${port}`);
  }
  if (CSP_WS_PERMISSIVE_PORT.get()) {
    const route = Router.parseUrl(window.location.href);
    if (/^\d+$/.exec(route.args.rpc_port ?? '')) {
      rpcPolicy.push(`http://127.0.0.1:${route.args.rpc_port}`);
      rpcPolicy.push(`ws://127.0.0.1:${route.args.rpc_port}`);
    }
  }
```

### 7b: Skip the flag dialog for allowed ports

In the same file (`ui/src/frontend/index.ts`), find the
`maybeChangeRpcPortFromFragment()` function:

```typescript
function maybeChangeRpcPortFromFragment() {
  const route = Router.parseUrl(window.location.href);
  if (route.args.rpc_port !== undefined) {
    if (!CSP_WS_PERMISSIVE_PORT.get()) {
      showModal({
```

Replace the entire function body with:

```typescript
function maybeChangeRpcPortFromFragment() {
  const route = Router.parseUrl(window.location.href);
  if (route.args.rpc_port !== undefined) {
    const port = parseInt(route.args.rpc_port, 10);
    const portInAllowedRange = port >= 9001 && port <= 9010;
    if (!portInAllowedRange && !CSP_WS_PERMISSIVE_PORT.get()) {
      showModal({
        title: 'Using a different port requires a flag change',
        content: m(
          'div',
          m(
            'span',
            'For security reasons before connecting to a non-standard ' +
              'TraceProcessor port you need to manually enable the flag to ' +
              'relax the Content Security Policy and restart the UI.',
          ),
        ),
        buttons: [
          {
            text: 'Take me to the flags page',
            primary: true,
            action: () => Router.navigate('#!/flags/cspAllowAnyWebsocketPort'),
          },
        ],
      });
    } else {
      HttpRpcEngine.rpcPort = route.args.rpc_port;
    }
  }
}
```

Then rebuild the UI:

```bash
export PNPM_HOME="$(pwd)/buildtools/pnpm-home"
export npm_config_store_dir="$(pwd)/buildtools/pnpm-store"
ui/build
```

## Step 8: Create helper scripts

### serve-ui.sh

Serves the static Perfetto UI. Run once, keep in tmux.

```bash
cat > serve-ui.sh << 'SCRIPT'
#!/bin/bash
set -eu

PERFETTO_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$PERFETTO_DIR/out/ui/ui/dist"
UI_PORT="${PERFETTO_UI_PORT:-8101}"

if [ ! -d "$DIST_DIR" ]; then
  echo "Error: UI dist not found at $DIST_DIR"
  echo "Build it with: ui/build"
  exit 1
fi

echo "Serving Perfetto UI on http://127.0.0.1:${UI_PORT}"
echo "Press Ctrl-C to stop."
exec python3 -c "
import http.server, socketserver, functools
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory='$DIST_DIR')
with socketserver.ThreadingTCPServer(('127.0.0.1', $UI_PORT), handler) as httpd:
    httpd.serve_forever()
"
SCRIPT
```

### open-trace.sh

Loads a trace into trace_processor_shell. Run per trace. Supports an optional
port argument for viewing multiple traces simultaneously.

```bash
cat > open-trace.sh << 'SCRIPT'
#!/bin/bash
set -eu

PERFETTO_DIR="$(cd "$(dirname "$0")" && pwd)"
TP_BIN="$PERFETTO_DIR/out/linux_clang_release/trace_processor_shell"
UI_PORT="${PERFETTO_UI_PORT:-8101}"

if [ $# -eq 0 ]; then
  echo "Usage: open-trace.sh <trace-file> [port]"
  echo ""
  echo "Loads a trace in trace_processor and opens it in the Perfetto UI."
  echo "Make sure the UI server (perf_ui) and SSH tunnels are already running."
  echo ""
  echo "The default port is 9001. To view multiple traces simultaneously,"
  echo "run each on a different port (9001-9010) and open separate browser tabs:"
  echo "  open-trace.sh trace1.pftrace         # port 9001 (default)"
  echo "  open-trace.sh trace2.pftrace 9002    # port 9002"
  echo ""
  echo "Environment variables:"
  echo "  PERFETTO_UI_PORT  (default: 8101)"
  exit 1
fi

TRACE="$(realpath "$1")"
TP_PORT="${2:-${PERFETTO_TP_PORT:-9001}}"

if [ ! -f "$TRACE" ]; then
  echo "Error: file not found: $1"
  exit 1
fi

if [ ! -x "$TP_BIN" ]; then
  echo "Error: trace_processor_shell not found at $TP_BIN"
  echo "Build it with: tools/ninja -C out/linux_clang_release trace_processor_shell"
  exit 1
fi

echo "Loading: $TRACE"
echo "Trace processor on port $TP_PORT"
echo ""
if [ "$TP_PORT" = "9001" ]; then
  echo "Open in your browser:"
  echo "  http://localhost:${UI_PORT}"
else
  echo "Open in your browser:"
  echo "  http://localhost:${UI_PORT}/#!/?rpc_port=${TP_PORT}"
  echo ""
  echo "Note: forward this port too: ssh -L ${TP_PORT}:127.0.0.1:${TP_PORT} ..."
fi
echo ""
echo "Press Ctrl-C to stop and load a different trace."
exec "$TP_BIN" --httpd --http-port "$TP_PORT" "$TRACE"
SCRIPT
```

Make both executable:

```bash
chmod +x serve-ui.sh open-trace.sh
```

## Step 9: Shell aliases

Add to your shell rc file (~/.bashrc or ~/.zshrc):

```bash
alias perf_ui='/path/to/perfetto/serve-ui.sh'
alias perf='/path/to/perfetto/open-trace.sh'
```

## Usage

### On your local machine - SSH with ports forwarded:

For a single trace:

```bash
ssh -C -L 8101:127.0.0.1:8101 -L 9001:127.0.0.1:9001 user@server
```

For multiple simultaneous traces, forward additional ports:

```bash
ssh -C \
  -L 8101:127.0.0.1:8101 \
  -L 9001:127.0.0.1:9001 \
  -L 9002:127.0.0.1:9002 \
  -L 9003:127.0.0.1:9003 \
  user@server
```

### On the server - start UI (once, in tmux):

```bash
perf_ui
```

### On the server - load a trace:

```bash
perf /path/to/any/trace.json
```

Then open http://localhost:8101 in your browser.

### To view multiple traces simultaneously:

Run each on a different port:

```bash
perf /path/to/trace1.pftrace          # port 9001 (default)
perf /path/to/trace2.pftrace 9002     # port 9002
perf /path/to/trace3.pftrace 9003     # port 9003
```

Open separate browser tabs:
- http://localhost:8101 - for trace1 (port 9001, the default)
- http://localhost:8101/#!/?rpc_port=9002 - for trace2
- http://localhost:8101/#!/?rpc_port=9003 - for trace3

Each tab connects to its own trace_processor instance independently.

### To switch traces:

Ctrl-C the `perf` command and re-run with a different file (and same port).

## Isolation / cleanup

Everything lives inside the perfetto repo directory:
- Node.js: `buildtools/linux64/nodejs/`
- pnpm: `third_party/pnpm/`
- Emscripten: `buildtools/linux64/emsdk/`
- C++ toolchain: `buildtools/linux64/clang/`
- node_modules: `ui/node_modules/`
- Build output: `out/`

To fully uninstall: `rm -rf /path/to/perfetto`

The only potential leak is pnpm's content store at `~/.local/share/pnpm/store/`.
Setting `PNPM_HOME` and `npm_config_store_dir` during Step 1 prevents this.
If you forgot, check and remove `~/.local/share/pnpm/` after deleting the repo.

## Troubleshooting

- **Python "TypeError: 'type' object is not subscriptable" during build**: Your
  system Python is too old (< 3.9). See the "Python version note" section at the
  top. Either activate a venv with Python 3.10+, or add `from __future__ import
  annotations` to `gn/write_buildflag_header.py`.
- **Emscripten cache.lock error during build**: Run the embuilder command from Step 2 first.
- **CORS "origin not allowed" error**: Your UI port is not in the CORS allowlist. See Step 5.
- **Browser shows old UI after rebuild**: Clear browser cache and unregister the service worker
  (DevTools > Application > Service Workers > Unregister), then hard-reload.
- **Connection freezes on large traces**: Make sure you're using the trace_processor_shell
  approach (port 9001), NOT the `?url=` approach which streams the entire trace to the browser.
- **UI shows home page instead of trace**: Make sure port 9001 (or whichever port you're using)
  is forwarded in your SSH command.
- **"Using a different port requires a flag change" dialog**: You're using a port outside
  the 9001-9010 range (after applying the Step 7 patch). Either use a port in that range,
  or enable the `cspAllowAnyWebsocketPort` flag at `#!/flags/cspAllowAnyWebsocketPort`.
  If you haven't applied Step 7, this dialog appears for any port other than 9001.
