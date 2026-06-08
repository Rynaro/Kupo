#!/usr/bin/env bash
# tests/helpers.bash — shared test helpers for the Kupo bats suite.
#
# Provides install fixtures and sha256 helpers for tests that exercise
# install.sh and the skills layout.

# Absolute path to the Kupo repo root (one level up from this file).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# sha256_of <path>
sha256_of() {
  local f="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    echo "0000000000000000000000000000000000000000000000000000000000000000"
  fi
}

# run_install TARGET_DIR [EXTRA_ARGS...]
# Runs install.sh non-interactively into a temp target directory.
# Sets INSTALL_TARGET, INSTALL_STATUS, INSTALL_OUTPUT.
run_install() {
  local target_dir="$1"
  shift
  INSTALL_TARGET="${target_dir}"
  run bash "${REPO_ROOT}/install.sh" \
    --non-interactive \
    --force \
    --target "${INSTALL_TARGET}" \
    --hosts none \
    "$@"
  INSTALL_STATUS="$status"
  INSTALL_OUTPUT="$output"
}

# teardown_install — clean up a temp install target.
teardown_install() {
  [[ -n "${INSTALL_TARGET:-}" && -d "${INSTALL_TARGET}" ]] && rm -rf "${INSTALL_TARGET}"
}
