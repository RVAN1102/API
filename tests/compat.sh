#!/usr/bin/env bash
# tests/compat.sh
#
# Cross-platform compatibility shim.
# Source this at the top of any test script that uses python3.
#
# Usage:
#   SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/../compat.sh"

# ── python3 shim ─────────────────────────────────────────────────────────────
# On Windows Git Bash, python3/python may be non-functional Windows Store stubs.
# We find a real Python 3 and create a shell function that hardcodes its path.

_compat_try_py() {
  local c="$1" major
  major="$("$c" -c 'import sys; print(sys.version_info.major)' 2>/dev/null)" || return 1
  [ "$major" = "3" ] || return 1
  _COMPAT_PY_BIN="$c"
}

_compat_install_shim() {
  # Bake the resolved path into the function body at define-time, not call-time.
  # This way the function survives even after we unset temp variables.
  local py="$1"
  eval "python3() { \"${py}\" \"\$@\"; }"
  export -f python3 2>/dev/null || true
  # Add Python dir to PATH so child bash processes also find it
  local pydir
  pydir="$(dirname "$py")"
  case ":${PATH}:" in
    *":${pydir}:"*) ;;
    *) export PATH="${pydir}:${PATH}" ;;
  esac
}

_COMPAT_PY_BIN=""

# Only shim if python3 doesn't already work
if ! _compat_try_py python3; then

  # 1) Common command names
  for _c in py python; do
    _compat_try_py "$_c" && break
  done

  # 2) Search filesystem using POSIX paths derived from $HOME
  if [ -z "$_COMPAT_PY_BIN" ]; then
    _PLA="${HOME}/AppData/Local"
    for _dir in \
      "${_PLA}/Programs/Python/Python313" \
      "${_PLA}/Programs/Python/Python312" \
      "${_PLA}/Programs/Python/Python311" \
      "${_PLA}/Programs/Python/Python310" \
      "${_PLA}/Programs/Python/Python39" \
      "${HOME}/miniconda3" \
      "${HOME}/anaconda3" \
      "${HOME}/miniforge3" \
      "/c/Python313" "/c/Python312" "/c/Python311" "/c/Python310"
    do
      [ -d "$_dir" ] || continue
      for _pyexe in "${_dir}/python.exe" "${_dir}/python3.exe" "${_dir}/python"; do
        [ -f "$_pyexe" ] || continue
        _compat_try_py "$_pyexe" && break 2
      done
    done
    unset _PLA _dir _pyexe
  fi

  # 3) Caller-provided override
  if [ -z "$_COMPAT_PY_BIN" ] && [ -n "${PYTHON_BIN:-}" ]; then
    _compat_try_py "${PYTHON_BIN}" || true
  fi

  # Install the shim if we found a working Python
  if [ -n "$_COMPAT_PY_BIN" ]; then
    _compat_install_shim "$_COMPAT_PY_BIN"
  else
    echo "[compat] WARNING: No working Python 3 found." >&2
    echo "[compat] Hint: PYTHON_BIN=/path/to/python.exe bash tests/final/main-regression.sh" >&2
  fi
fi

unset _COMPAT_PY_BIN _c
unset -f _compat_try_py _compat_install_shim 2>/dev/null || true
