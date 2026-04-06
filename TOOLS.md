# Tool Manifest

All remote URLs used during dotfiles installation. **This is the single source of truth** for
external dependencies — `install.sh` reads this file at runtime.

If a tool is compromised or needs a version bump, edit this table. No other file contains download URLs.

## Packages

<!-- install.sh parses this table: it matches on columns 2 (tool) and 4 (platform), then extracts
     the backtick-wrapped URL from column 5 and binary path from column 6. Do not change the
     column order or remove the backtick wrapping. -->

| Tool | Version | Platform | Download URL | Binary Path | Method |
|------|---------|----------|--------------|-------------|--------|
| rg | 14.1.0 | linux-x86_64 | `https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz` | `ripgrep-14.1.0-x86_64-unknown-linux-musl/rg` | tarball |
| rg | 14.1.0 | linux-aarch64 | `https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-aarch64-unknown-linux-gnu.tar.gz` | `ripgrep-14.1.0-aarch64-unknown-linux-gnu/rg` | tarball |
| rg | 14.1.0 | darwin-x86_64 | `https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-apple-darwin.tar.gz` | `ripgrep-14.1.0-x86_64-apple-darwin/rg` | tarball |
| rg | 14.1.0 | darwin-aarch64 | `https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-aarch64-apple-darwin.tar.gz` | `ripgrep-14.1.0-aarch64-apple-darwin/rg` | tarball |
| fd | 10.1.0 | linux-x86_64 | `https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-x86_64-unknown-linux-musl.tar.gz` | `fd-v10.1.0-x86_64-unknown-linux-musl/fd` | tarball |
| fd | 10.1.0 | linux-aarch64 | `https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-aarch64-unknown-linux-musl.tar.gz` | `fd-v10.1.0-aarch64-unknown-linux-musl/fd` | tarball |
| fd | 10.1.0 | darwin-x86_64 | `https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-x86_64-apple-darwin.tar.gz` | `fd-v10.1.0-x86_64-apple-darwin/fd` | tarball |
| fd | 10.1.0 | darwin-aarch64 | `https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-aarch64-apple-darwin.tar.gz` | `fd-v10.1.0-aarch64-apple-darwin/fd` | tarball |
| fzf | 0.62.0 | linux-x86_64 | `https://github.com/junegunn/fzf/releases/download/v0.62.0/fzf-0.62.0-linux_amd64.tar.gz` | `fzf` | tarball |
| fzf | 0.62.0 | linux-aarch64 | `https://github.com/junegunn/fzf/releases/download/v0.62.0/fzf-0.62.0-linux_arm64.tar.gz` | `fzf` | tarball |
| fzf | 0.62.0 | darwin-x86_64 | `https://github.com/junegunn/fzf/releases/download/v0.62.0/fzf-0.62.0-darwin_amd64.tar.gz` | `fzf` | tarball |
| fzf | 0.62.0 | darwin-aarch64 | `https://github.com/junegunn/fzf/releases/download/v0.62.0/fzf-0.62.0-darwin_arm64.tar.gz` | `fzf` | tarball |
| jq | 1.7.1 | linux-x86_64 | `https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64` | `-` | binary |
| jq | 1.7.1 | linux-aarch64 | `https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-arm64` | `-` | binary |
| jq | 1.7.1 | darwin-x86_64 | `https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-amd64` | `-` | binary |
| jq | 1.7.1 | darwin-aarch64 | `https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-arm64` | `-` | binary |
| nvim | 0.10.3 | linux-x86_64 | `https://github.com/neovim/neovim/releases/download/v0.10.3/nvim-linux64.tar.gz` | `nvim-linux64` | tarball-tree |
| nvim | 0.10.3 | linux-aarch64 | `https://github.com/neovim/neovim/releases/download/v0.10.3/nvim-linux64.tar.gz` | `nvim-linux64` | tarball-tree |
| nvim | 0.10.3 | darwin-x86_64 | `https://github.com/neovim/neovim/releases/download/v0.10.3/nvim-macos-x86_64.tar.gz` | `nvim-macos-x86_64` | tarball-tree |
| nvim | 0.10.3 | darwin-aarch64 | `https://github.com/neovim/neovim/releases/download/v0.10.3/nvim-macos-arm64.tar.gz` | `nvim-macos-arm64` | tarball-tree |
| vifm | 0.14 | linux-x86_64 | `https://github.com/vifm/vifm/releases/download/v0.14/vifm-v0.14-x86_64.AppImage` | `-` | appimage |
| vifm | 0.14 | linux-aarch64 | `-` | `-` | brew |
| vifm | 0.14 | darwin-all | `-` | `-` | brew |
| jj | 0.28.2 | linux-x86_64 | `https://github.com/jj-vcs/jj/releases/download/v0.28.2/jj-v0.28.2-x86_64-unknown-linux-musl.tar.gz` | `jj` | tarball |
| jj | 0.28.2 | linux-aarch64 | `https://github.com/jj-vcs/jj/releases/download/v0.28.2/jj-v0.28.2-aarch64-unknown-linux-musl.tar.gz` | `jj` | tarball |
| jj | 0.28.2 | darwin-x86_64 | `https://github.com/jj-vcs/jj/releases/download/v0.28.2/jj-v0.28.2-x86_64-apple-darwin.tar.gz` | `jj` | tarball |
| jj | 0.28.2 | darwin-aarch64 | `https://github.com/jj-vcs/jj/releases/download/v0.28.2/jj-v0.28.2-aarch64-apple-darwin.tar.gz` | `jj` | tarball |
| uv | latest | all | `https://astral.sh/uv/install.sh` | `-` | script |
| claude | latest | all | `npm:@anthropic-ai/claude-code` | `-` | npm |
| bwrap | 0.4.0 | linux-all | `apt:bubblewrap` | `-` | deb |
| mitmproxy | latest | all | `uv-tool:mitmproxy` | `-` | uv-tool |
| zinit | latest | all | `https://github.com/zdharma-continuum/zinit.git` | `-` | git |
