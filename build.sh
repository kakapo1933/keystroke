#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Building never installs or stops the running app. Installation is explicit.
exec "$ROOT_DIR/script/build_and_run.sh" "${1:---build-only}"
