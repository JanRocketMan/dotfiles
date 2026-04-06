
# frozen.nvim

This is a slimmer version of [nvim-lua/kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) that gets rid of Mason installer. It currently only supports python and c languages.

I also removed all the packages I don't need (e.g. statusline), added a couple of (very subjectively) awesome, and introduced a set of (very custom) hotkeys.

The name is "Frozen" because all commit versions of all packages are fixed via `lazy-lock.json`. Since there are no additional installers this makes config reproducable.

Also 'zen' indicates that it starts in zen mode by default (no statusline, no line numbers, no file explorers etc), which is awesome since we don't need any separate packages for this.

Probably shouldn't be used by anyone.

## Installation

We provide a single installation script that installs both neovim, fd and ripgrep and configures neovim:

```bash
curl -LsSf https://raw.githubusercontent.com/JanRocketMan/frozen.nvim/refs/heads/main/autoinstall.sh | bash
```

Additionally there is a minimal version that doesn't install Lazy plugin manager or plugins (using core neovim only):

```bash
curl -LsSf https://raw.githubusercontent.com/JanRocketMan/frozen.nvim/refs/heads/main/autoinstall.sh | bash -s min
```

*Warning!* Both scripts above are going to remove all existing files you have in `~/.cache/nvim ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim`! There will also add a couple of aliases in your `~/.bashrc` file. Please check the script before running it

## Requirements

System utils: git, make, gcc, unzip

Neovim and tools:
- `nvim==0.10.0`: [linux](https://github.com/neovim/neovim/releases/download/v0.10.0/nvim-linux64.tar.gz) and [macos-arm](https://github.com/neovim/neovim/releases/download/v0.10.0/nvim-macos-arm64.tar.gz)
- `ripgrep==14.1.0`: [linux](https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz) and [macos-arm](https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-aarch64-apple-darwin.tar.gz)
- `fd==10.1.0`: [linux](https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-x86_64-unknown-linux-musl.tar.gz) and [macos-arm](https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-aarch64-apple-darwin.tar.gz)

A bunch of python libraries:
- `pyright` for autocompletion and static type checking
- `ruff` for linting and autoformat
- `debugpy` for debugging

Note that support for every language should be handled manually since we dont use Mason. For python simply installing for libs above works ok, but beware that I don't know anything about other languages. This config may be unusable for them.

## Manual installation

1. Delete previous configs (cache them if needed):
```bash
rm -rf ~/.cache/nvim ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim
```

2. Download nvim config:

```bash
git clone https://github.com/JanRocketMan/frozen.nvim.git ~/.config/nvim
```

3. Make sure you have `nvim`, `fd` and `rg` in your system path. Then run `nvim` to install all packages & exit it to apply all changes

4. To use this config for python projects make sure to install necessary tools via `pip install pyright ruff debugpy`. Use python/uv environment to avoid polluting your global python. For you can install uv with:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

