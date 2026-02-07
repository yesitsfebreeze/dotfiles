VERSION := "1.0.2"

OS := if os() == "windows" { "windows" } else if os() == "macos" { "mac" } else { "linux" }
OS_JUSTFILE := "os/just." + OS

install:
	@just --working-directory . -f {{OS_JUSTFILE}} install

link:
	@just --working-directory . -f {{OS_JUSTFILE}} link

watch:
	@just --working-directory . -f {{OS_JUSTFILE}} watch

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
