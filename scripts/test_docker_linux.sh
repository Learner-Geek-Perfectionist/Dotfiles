#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./test_helpers.sh
source "$SCRIPT_DIR/test_helpers.sh"

IMAGE_TAG="${IMAGE_TAG:-dotfiles-linux-test:local}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-$REPO_ROOT/docker/linux-test.Dockerfile}"

if ! command -v docker &>/dev/null; then
	fail "docker is required to run Linux integration tests"
fi

run_test "Build Linux test image" docker build -f "$DOCKERFILE_PATH" -t "$IMAGE_TAG" "$REPO_ROOT"
run_test "Run Linux Docker integration tests" docker run --rm "$IMAGE_TAG" bash /repo/scripts/test_linux_integration.sh

section "Done"
pass "Docker Linux integration checks completed"
