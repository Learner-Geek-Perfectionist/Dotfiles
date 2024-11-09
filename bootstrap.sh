#!/bin/bash
# bootstrap.sh

REMOTE_SCRIPT="https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/install.sh"
REMOTE_VERSION=$(curl -fsSL "${REMOTE_SCRIPT}?$(date +%s)" | grep 'Version' | cut -d' ' -f2)

curl -fsSL "${REMOTE_SCRIPT}?$(date +%s)" | /bin/bash
