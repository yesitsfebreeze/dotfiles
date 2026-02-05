VERSION := "1.0.0"

__brew:
  #!/usr/bin/env bash
  set -euo pipefail
  if ! command -v brew >/dev/null 2>&1; then
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    brew update
    brew upgrade
  fi

__update p cask:
  #!/usr/bin/env bash
  set -euo pipefail
  if ! brew list {{p}} >/dev/null 2>&1; then
    if [ "{{cask}}" = "true" ]; then
      brew install --cask {{p}}
    else
      brew install {{p}}
    fi
  else
    brew upgrade {{p}}
  fi

__adjust:
  @defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
  @defaults write -g NSWindowResizeTime -float 0.001
  @defaults write -g NSScrollAnimationEnabled -bool false
  @defaults write -g NSDocumentRevisionsWindowTransformAnimation -bool false
  @defaults write -g NSInitialToolTipDelay -int 0
  @defaults write -g NSWindowResizeTime -float 0
  @defaults write com.apple.finder DisableAllAnimations -bool true
  @killall Finder
  @defaults write com.apple.dock autohide-time-modifier -float 0
  @defaults write com.apple.dock autohide-delay -float 0
  @defaults write com.apple.dock expose-animation-duration -float 0
  @killall Dock

install:
  @just __brew
  @just __update wezterm true
  @just __update hammerspoon true
  @just __update nvim false
  @just __update ripgrep false
  @just link
  @just __adjust

link:
  @mkdir -p ~/.config/wezterm
  @ln -sf $(pwd)/cfg/wezterm.lua ~/.config/wezterm/wezterm.lua

  @mkdir -p ~/.hammerspoon
  @ln -sf $(pwd)/cfg/hammerspoon.lua ~/.hammerspoon/init.lua

  @mkdir -p ~/.config/nvim
  @ln -sf $(pwd)/cfg/nvim.lua ~/.config/nvim/init.lua

update:
  #!/usr/bin/env bash
  set -euo pipefail
  remote_version=$(curl -fsSL https://raw.githubusercontent.com/yesitsfebreeze/dotfiles/main/justfile?$(date +%s) | head -n 1 | sed 's/VERSION := "\(.*\)"/\1/')
  if [ "$remote_version" != "{{VERSION}}" ]; then
    git pull
    just install
  fi

push:
  @git add --all && git commit -m "change" && git push --force