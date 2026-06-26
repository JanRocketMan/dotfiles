# Building PyTorch 2.10.0 (+cu128) from source

A reproducible guide for building PyTorch **v2.10.0** from source against **CUDA 12.8**,
producing a version stamped `2.10.0+cu128`. Targeted at a Linux GPU box with **no root
access** (e.g. an HPC/Bright cluster node). Tested layout: **A100 80GB (sm_80)**,
driver 550, 122 cores. Note it's a **shared node** — available RAM fluctuates with other
tenants, which matters for `MAX_JOBS` (see troubleshooting).

> **Key idea:** "+cu128" is a CUDA *variant* label, not part of the git tag. You get it
> by building the `v2.10.0` source against a CUDA 12.8 toolkit. There is **no official
> `+cu124` wheel** for 2.10.0 (published variants are cu126/cu128/cu130), but the source
> builds fine against any CUDA >= 12.0.

> ⚠️ **Note for AI agents — bubblewrap (bwrap) sandbox.** Claude Code may run inside a
> bwrap sandbox where the **filesystem view is not the real machine**:
> - `$HOME` (`/home/<user>`) is presented as an **empty tmpfs**. The real `/home` is
>   persistent **wekafs**; only the project dir (`~/pytorch`) is bind-mounted in.
> - Out-of-project paths — `~/cuda-12.8` (the CUDA toolkit), `~/.local/gcc-11`, the venv's
>   `nvidia/*` libs, and even `.env` — are **masked / hidden**. `ls`/`find`/`grep`/`Read`
>   on them return empty, "No such file", or `EACCES`.
> - **Do not conclude something is missing, deleted, or "wiped" based on an in-sandbox
>   check.** It is almost always a masking artifact. Re-verify on the real machine (the
>   user can run commands via the `!` prefix), or note the uncertainty instead of alarming.
> - Build artifacts, `.venv`, and `build.log` live under `~/pytorch` (bind-mounted), so
>   those *are* visible and reliable. The toolkit's `libcudart` is at
>   `cuda-12.8/targets/x86_64-linux/lib` (`lib64/` symlinks to it).
> - `build.log` is binary (ANSI/`\r` from progress bars) — use `grep -a` on it.

> ✅ **Status: built & verified working.** `torch 2.10.0+cu128`, CUDA 12.8, cuDNN 9.2.3,
> NCCL 2.30.7, `torch.cuda.get_arch_list() == ['sm_80']`, `cuda.is_available() == True` on
> an A100 80GB. Remember to `source .env` before importing (it sets the runtime
> `LD_LIBRARY_PATH`). This is an editable, sm_80-only, env-dependent build — **not** a
> drop-in for the official multi-arch, self-contained `+cu128` wheel (see final note).

---

## 0. Prerequisites

- `uv` installed (`~/.local/bin/uv`). Install: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- `git` (needed for submodules; `jj` does **not** manage submodules).
- A working NVIDIA **driver** >= 525 (you do *not* need root or a matching driver for
  12.8 — CUDA minor-version compatibility lets a cu128 build run on a >=525 driver).
  Check: `nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader`
- Internet access (to fetch the repo, CUDA runfile, and pip wheels).
- ~30 GB free space for source + submodules + toolkit + build artifacts.

No system CUDA toolkit is required — we install CUDA 12.8 into your home dir (Step 4).

---

## 1. Clone the repository

```bash
# SSH (preferred — works without stored HTTPS credentials)
git clone git@github.com:pytorch/pytorch.git
cd pytorch
```

Optional (colocated Jujutsu, per personal VCS workflow):

```bash
jj git init --colocate    # turns the existing .git checkout into a jj+git colocated repo
```

---

## 2. Check out the v2.10.0 tag

**With jj (colocated):**

```bash
jj new v2.10.0            # new working-copy change on top of the v2.10.0 tag
jj st                     # should be clean / empty on top of the tag commit
```

**Plain git equivalent:**

```bash
git checkout v2.10.0
```

> jj prints `ignoring git submodule at ...` lines — expected. jj does not touch
> submodules; that's Step 3.

---

## 3. Sync submodules to the tag

jj/git checkout does **not** update submodules. Do it explicitly (unavoidable bare git):

```bash
git submodule update --init --recursive
```

Verify everything is at the pinned commits — output should have **no** `+`, `-`, or `U`
prefix on any line:

```bash
git submodule status --recursive
```

---

## 4. Install the CUDA 12.8 toolkit (user-space, no root)

The driver requires root; the **toolkit does not**. Install toolkit-only into `$HOME`:

```bash
# ~5.4 GB download
curl -L -o /tmp/cuda_12.8.1.run \
  https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/cuda_12.8.1_570.124.06_linux.run

# toolkit only — NO driver, NO root
sh /tmp/cuda_12.8.1.run --silent --toolkit \
  --toolkitpath=$HOME/cuda-12.8 --no-opengl-libs --override

# verify
$HOME/cuda-12.8/bin/nvcc --version | tail -2     # expect: release 12.8
```

> **Persistent storage:** if `$HOME` is *genuinely* tmpfs (RAM-backed, lost on reboot),
> point `--toolkitpath` (and `CUDA_HOME` in Step 6) at a persistent disk. On the tested
> node `/home` is persistent wekafs, so `~/cuda-12.8` survives — a tmpfs `$HOME` seen from
> inside the bwrap sandbox is an artifact, not the real disk (see the agent note at top).

---

## 5. Create the Python environment

PyTorch 2.10 supports CPython 3.10–3.13. This guide uses **3.12.7**.

```bash
uv venv --python 3.12.7        # creates ./.venv
```

---

## 6. Create the `.env` file

Create `./.env` in the repo root with the contents below. It is portable
(`$HOME` / `$(pwd)` based). `source` it before building.

> If your venv Python isn't 3.12, update the `python3.12` segment in `_SITE`.

```bash
# PyTorch 2.10.0 source build env  (CUDA 12.8 toolkit, sm_80 / A100)
# Usage:  source .env   then follow Step 7.

# --- venv ---
export VIRTUAL_ENV="$(pwd)/.venv"
export PATH="$VIRTUAL_ENV/bin:$PATH"
_SITE="$VIRTUAL_ENV/lib/python3.12/site-packages"

# --- CUDA 12.8 toolkit (user-space install from Step 4) ---
export CUDA_HOME="$HOME/cuda-12.8"
export CUDA_NVCC_EXECUTABLE="$CUDA_HOME/bin/nvcc"
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

# --- cuDNN 9 (pip wheel in venv) ---
export CUDNN_ROOT="$_SITE/nvidia/cudnn"
export CUDNN_INCLUDE_DIR="$CUDNN_ROOT/include"
export CUDNN_INCLUDE_PATH="$CUDNN_ROOT/include"
export CUDNN_LIBRARY="$CUDNN_ROOT/lib/libcudnn.so"
export CUDNN_LIBRARY_PATH="$CUDNN_ROOT/lib"
export CUDNN_LIB_DIR="$CUDNN_ROOT/lib"

# --- NCCL (pip wheel in venv) ---
export USE_SYSTEM_NCCL=1
export NCCL_ROOT="$_SITE/nvidia/nccl"
export NCCL_INCLUDE_DIR="$NCCL_ROOT/include"
export NCCL_LIB_DIR="$NCCL_ROOT/lib"

# --- runtime library resolution ---
export LD_LIBRARY_PATH="$CUDNN_ROOT/lib:$NCCL_ROOT/lib:$LD_LIBRARY_PATH"

# --- host compiler ---
# uv's standalone CPython records `clang` as its compiler in sysconfig, but clang
# is usually not installed on HPC nodes. Force gcc so setuptools' C-extension step
# doesn't try to call a missing clang.
export CC=gcc
export CXX=g++

# --- build configuration ---
export USE_CUDA=1
export USE_CUDNN=1
export USE_NCCL=1
export TORCH_CUDA_ARCH_LIST="8.0"     # A100 = 8.0; set to your GPU's compute_cap
export MAX_JOBS=16                     # safe one-shot default (≈ available_GB/8). RAM-bound,
                                       # NOT core-bound: flash-attn/cutlass cicc jobs spike
                                       # to several GB each. See "Tuning MAX_JOBS" in the
                                       # troubleshooting section for a faster two-phase run.
export BUILD_TEST=0                    # skip C++ test binaries; drop for a full build
export CMAKE_PREFIX_PATH="$VIRTUAL_ENV"

# --- version stamping: produce exactly 2.10.0+cu128 ---
export PYTORCH_BUILD_VERSION=2.10.0+cu128
export PYTORCH_BUILD_NUMBER=1
```

**Why these choices**
- `PYTORCH_BUILD_VERSION` — without it the editable build derives a dev string like
  `2.10.0a0+gitXXXX` (HEAD is one jj commit above the tag, so `git describe` isn't exact).
  Setting it stamps a clean `2.10.0+cu128`.
- cuDNN/NCCL via pip — the CUDA toolkit ships neither, and the cluster's cuDNN is too old.
  The `nvidia-*-cu12` wheels are version-matched to what 2.10 expects and stay
  self-contained in the venv (same libs the official wheels bundle).
- `USE_SYSTEM_NCCL=1` — there is no `third_party/nccl` source in this tree, so point the
  build at the pip NCCL instead of letting it look for a bundled source that isn't there.

---

## 7. Install dependencies and build

```bash
source .env

# sanity: nvcc must resolve to 12.8
which nvcc && nvcc --version | tail -1

# 1. build deps + runtime deps (must be present because --no-build-isolation)
uv pip install -r requirements-build.txt -r requirements.txt

# 2. cuDNN 9 + NCCL into the venv
uv pip install nvidia-cudnn-cu12 nvidia-nccl-cu12

# 3. unversioned .so symlinks so cmake's find_library() locates them
( cd "$CUDNN_ROOT/lib" && ln -sf libcudnn.so.9 libcudnn.so )
( cd "$NCCL_ROOT/lib"  && ln -sf libnccl.so.2  libnccl.so  )

# 4. the build (editable, no isolation so it uses the deps above)
#    Tee everything to build.log so failures can be inspected / shared after the fact.
#    `pipefail` ensures a build error still produces a non-zero exit through the pipe.
set -o pipefail
uv pip install -e . -v --no-build-isolation 2>&1 | tee build.log
```

The editable build is the long step (tens of minutes on a many-core box). The full
transcript (including any error) lands in `build.log` in the repo root — point the agent
at that file if something goes wrong. To inspect quickly:

```bash
tail -n 100 build.log              # last lines (where the error usually is)
grep -an -iE 'error|failed|killed|signal 9' build.log   # jump to failures
```

---

## 8. Verify

```bash
python -c "import torch; print(torch.__version__, torch.version.cuda, torch.cuda.is_available())"
# expect: 2.10.0+cu128 12.8 True
python -c "import torch; print(torch.backends.cudnn.version(), torch.cuda.nccl.version())"
```

---

## 9. Using this build in other projects (e.g. `~/qwent`)

Two constraints apply to **any** project that consumes this build:

1. **Python must be CPython 3.12.** The compiled extensions are `cp312`; a 3.11/3.13 venv
   won't import it. Create the consuming venv with `uv venv --python 3.12`.
2. **The CUDA runtime libs must be on the path at run time** (this build is *not*
   self-contained — see the final section). Simplest: `source ~/pytorch/.env` in any shell
   that runs the project — it sets `LD_LIBRARY_PATH` to the toolkit + the venv `nvidia`
   libs. Alternative (self-contained, no `LD_LIBRARY_PATH` needed): install the runtime
   wheels into the consuming venv —
   `uv pip install nvidia-cuda-runtime-cu12 nvidia-cuda-cupti-cu12 nvidia-cudnn-cu12
   nvidia-nccl-cu12 nvidia-cublas-cu12 nvidia-cufft-cu12 nvidia-curand-cu12
   nvidia-cusolver-cu12 nvidia-cusparse-cu12 nvidia-nvtx-cu12 nvidia-nvjitlink-cu12`.

You do **not** edit the consuming project's PyTorch *code*; you just point its dependency
resolution at this build. Pick one of the approaches below.

### Default: editable path source

Reference this build's source tree directly — one source of truth, and edits to the
PyTorch source (`~/pytorch`) propagate to the project with no wheel rebuild.

Add to `~/qwent/pyproject.toml`:

```toml
[project]
dependencies = ["torch"]

[tool.uv.sources]
# Path is RELATIVE to this pyproject.toml's directory — uv does NOT expand $HOME / env
# vars in source paths. Assumes ~/qwent and ~/pytorch are siblings; adjust the depth if not
# (an absolute path also works but hardcodes your username).
torch = { path = "../pytorch", editable = true }

[tool.uv]
no-build-isolation-package = ["torch"]             # torch can't build under isolation
```

then apply it with:

```bash
cd ~/qwent
source ~/pytorch/.env        # the build backend needs CUDA_HOME, CC=gcc, etc.
uv sync                      # installs torch into qwent's venv (re-invokes torch's
                             # build backend; incremental ≈ no-op when build/ is current)
```

Caveat: every `uv sync`/`uv lock` re-runs torch's build backend. It's fast when `build/`
is up to date, but it **needs `~/pytorch/.env` sourced first** — otherwise it reconfigures
CPU-only / wrong-version (same failure mode as building without `.env`).

### Alternative: build a wheel and install it

Prefer this when you want a stable, relocatable artifact decoupled from the source tree
(sharing with others, or projects that shouldn't trigger a build on `uv sync`).

```bash
cd ~/pytorch && source .env
python setup.py bdist_wheel          # reuses build/, no recompile; ~1-2 min
# -> dist/torch-2.10.0+cu128-cp312-cp312-linux_x86_64.whl
```

Then in the other project — imperatively:

```bash
cd ~/qwent
uv venv --python 3.12                # consuming venv MUST be 3.12
uv pip install ~/pytorch/dist/torch-2.10.0+cu128-cp312-cp312-linux_x86_64.whl
```

or declaratively in `~/qwent/pyproject.toml` (then `uv sync`):

```toml
[project]
dependencies = ["torch==2.10.0+cu128"]

[tool.uv.sources]
torch = { path = "../pytorch/dist/torch-2.10.0+cu128-cp312-cp312-linux_x86_64.whl" }
```

### Verify it works in the consuming project

From the project (with `~/pytorch/.env` sourced, or the `nvidia-*-cu12` runtime wheels
installed), run a smoke test that also exercises the GPU:

```bash
cd ~/qwent
uv run python - <<'PY'
import torch
print("version:", torch.__version__)
print("from   :", torch.__file__)   # editable -> ~/pytorch/torch/... ; wheel -> the venv
print("cuda   :", torch.cuda.is_available(),
      "|", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "-")
assert torch.__version__ == "2.10.0+cu128", torch.__version__
assert torch.cuda.is_available(), "CUDA not available"
x = torch.randn(2048, 2048, device="cuda")
print("matmul :", float((x @ x).sum()))   # real GPU kernel — no exception => libs load & GPU works
PY
```

No `ImportError`/`OSError` about `libcudart`/`libcudnn`, no "CUDA not available", and a
matching version means it's wired in correctly.

> **Avoid the silent swap:** a public `2.10.0+cu128` wheel *does* exist on the PyTorch
> index, so if a project is configured with that index, plain `uv add torch` may resolve
> the **official multi-arch wheel** instead of your sm_80 build. The `[tool.uv.sources]`
> override (or installing the wheel path explicitly) is what guarantees you get *this* one.

---

## Notes & troubleshooting

- **`uv pip` vs `pip`:** the repo's `CLAUDE.md` specifies `pip install -e . -v
  --no-build-isolation`. `uv pip install -e . --no-build-isolation` drives the same
  setup.py/CMake backend; the `--no-build-isolation` flag is the part that matters
  (it makes the build reuse the deps installed in Step 7.1 and keeps rebuilds incremental).
- **Rebuilds:** after editing source, just rerun `uv pip install -e . -v
  --no-build-isolation` — CMake/ninja rebuild incrementally. For a clean slate:
  `python setup.py clean` (or remove `build/`).
- **`find_library` can't find cuDNN/NCCL:** the pip wheels ship only versioned `.so.9` /
  `.so.2`; the Step 7.3 symlinks fix this. Re-create them if you reinstall the wheels.
- **"driver too old" at runtime:** cu128 on a 550 driver relies on CUDA minor-version
  compatibility. If a specific op fails, rebuild with the `+cu126` toolkit (closer to the
  550/12.4 driver generation): install CUDA 12.6 in Step 4 and set
  `PYTORCH_BUILD_VERSION=2.10.0+cu126`.
- **Tuning `MAX_JOBS` / out-of-memory (`nvcc error: ... cicc died due to signal 9`):**
  `MAX_JOBS` is bounded by **RAM, not cores**. Most compiles use ~1–2 GB, but the
  flash-attn/cutlass `.cu` kernels spike to ~8–16 GB *each*; too many at once exhausts RAM,
  the OOM killer SIGKILLs `cicc`, and the box thrashes on swap (looks like a freeze). Size
  it against the **`available` column of `free -g`** (on a shared node this fluctuates):
  - **Safe one-shot** (won't OOM even on the heavy kernels): `MAX_JOBS ≈ available_GB / 8`.
    e.g. ~125 GB available → `16`.
  - **Faster, two-phase (recommended):** start **high** — `MAX_JOBS ≈ min(nproc, available_GB / 2)`
    — to blast through the thousands of light files quickly; when it OOMs on the flash-attn
    tail, **drop to** `available_GB / 12` (≈ `8`) and rerun. The build is **incremental** —
    completed `.o` files are cached and an OOM-killed compile just recompiles next run, so
    the heavy tail finishes at low concurrency while the bulk already went fast. Net wall
    time is lower than running everything at the safe one-shot value. Deliberately hitting
    one OOM here is fine: it's *your* memory-hog `cicc` processes that get killed, and
    nothing already built is lost (be a courteous neighbor on a shared node, though).
  - To skip the heaviest kernels entirely: `export USE_FLASH_ATTENTION=0 USE_MEM_EFF_ATTENTION=0`.
- **Must `source .env` in the *same* shell as the build.** If you forget, cmake silently
  configures a wrong build. Tells: `-- Not using CUDA`, `TORCH_BUILD_VERSION=2.10.0a0+git...`
  (instead of `2.10.0+cu128`), and `-DBUILD_TEST=True` (it links lots of `bin/test_*`).
  A no-CUDA reconfigure also rewrites `build/CMakeCache.txt` to `USE_CUDA=OFF`; just
  re-source `.env` and rerun — cmake flips it back and rebuilds CUDA targets (mostly cached).
- **`error: command 'clang' failed: No such file or directory`:** uv's standalone CPython
  records `clang`/`clang++` as its compiler in `sysconfig`, but clang isn't installed on
  the cluster (only gcc). The `CC=gcc`/`CXX=g++` exports in `.env` (Step 6) fix this —
  setuptools honors those over sysconfig. CMake picks gcc on its own, which is why the
  main libtorch build succeeds and this only surfaces at the Python-extension step.
- **Wrong GPU arch:** set `TORCH_CUDA_ARCH_LIST` to your GPU's compute capability
  (A100=8.0, H100=9.0, L40/4090=8.9, V100=7.0). Add `+PTX` (e.g. `8.0+PTX`) for forward
  compatibility with newer GPUs at a small build-time cost.

## How this differs from `uv pip install torch` (the official `+cu128` wheel)

Same source (v2.10.0) and identical Python API/behavior on an A100, but **not a drop-in
replacement** for the prebuilt wheel:

- **Arch-limited.** Built `TORCH_CUDA_ARCH_LIST=8.0` → `get_arch_list() == ['sm_80']`.
  The official wheel ships fat binaries for many arches (7.5/8.0/8.6/9.0/10.0/12.0 +PTX)
  and runs on almost any supported GPU; this build runs on A100-class only.
- **Not self-contained.** It links the system toolkit + venv `nvidia` libs and needs
  `.env`'s `LD_LIBRARY_PATH` at import time. The official wheel bundles the whole
  `nvidia-*-cu12` runtime stack as pip deps and runs with no system CUDA. To make this
  build self-contained too, `uv pip install nvidia-cuda-runtime-cu12 nvidia-cuda-cupti-cu12
  nvidia-cufft-cu12 nvidia-curand-cu12 nvidia-cusolver-cu12 nvidia-cusparse-cu12
  nvidia-nvtx-cu12 nvidia-nvjitlink-cu12` into the venv (optional).
- **Missing optional libs** the wheel bundles: cuSPARSELt, cuDSS (auto-disabled at
  configure when not found).
- **Editable install** tied to this source tree (`.pth` → `~/pytorch`), not a relocatable
  wheel in `site-packages`.
