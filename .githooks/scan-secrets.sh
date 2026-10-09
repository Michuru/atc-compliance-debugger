#!/bin/sh
# .githooks/scan-secrets.sh - secret-shape scanner used by .githooks/pre-push.
#
# Patterns live in .githooks/secret-patterns.txt, one extended regex per line.
#
# Usage:
#   scan-secrets.sh files <path>...     - scan specific files
#   scan-secrets.sh objects <sha>...    - scan specific git blobs
#
# A finding is reported as the file label, line numbers and the pattern's ordinal among the active
# patterns, never the matched text, so the output does not copy a secret into a terminal or a log.
#
# Exit codes (fails closed):
#   0 = clean
#   1 = at least one finding
#   2 = the scanner could not do its job (pattern file missing, empty or with CRLF line endings,
#       a pattern grep rejects, a path or object that cannot be read, bad usage). Never treated as clean.
#
# A matched value that is exactly one of Claude Code's own redaction placeholders
# (__TRACKED_VAR__, __CMDSUB_OUTPUT__) is never a finding.

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || {
  echo "[scan-secrets] cannot resolve the scanner's own directory - scanner cannot run" >&2
  exit 2
}
PATTERNS_FILE="$SELF_DIR/secret-patterns.txt"
SAFE_PLACEHOLDERS_RE='__TRACKED_VAR__|__CMDSUB_OUTPUT__'

if [ ! -f "$PATTERNS_FILE" ]; then
  echo "[scan-secrets] pattern file missing ($PATTERNS_FILE) - scanner cannot run" >&2
  exit 2
fi
if ! command -v grep >/dev/null 2>&1; then
  echo "[scan-secrets] grep not found - scanner cannot run" >&2
  exit 2
fi
if [ -n "$(tr -d -c '\r' < "$PATTERNS_FILE")" ]; then
  echo "[scan-secrets] pattern file contains a CR byte (CRLF line endings) - every pattern would silently never match; scanner cannot run" >&2
  exit 2
fi
if ! grep -qvE '^[[:space:]]*(#|$)' "$PATTERNS_FILE"; then
  echo "[scan-secrets] pattern file has no active pattern - scanner cannot run" >&2
  exit 2
fi

FOUND=0
INFRA=0

scan_file() {
  # $1 = label to report, $2 = actual file path to scan
  _label="$1"
  _target="$2"
  if [ ! -f "$_target" ]; then
    echo "[scan-secrets] $_label is not a readable file - it was not scanned" >&2
    INFRA=1
    return 0
  fi
  _pn=0
  # "|| [ -n ...]" keeps a last pattern line that has no trailing newline; plain
  # "read" drops it and the scanner would silently lose that pattern.
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    case "$pattern" in
      ''|'#'*) continue ;;
    esac
    _pn=$((_pn + 1))
    _raw=$(grep -naoE "$pattern" "$_target" 2>/dev/null)
    _rc=$?
    if [ "$_rc" -gt 1 ]; then
      echo "[scan-secrets] pattern $_pn was rejected by grep (exit $_rc) - scanner cannot run" >&2
      INFRA=1
      continue
    fi
    [ "$_rc" -eq 1 ] && continue
    _matches=$(printf '%s\n' "$_raw" | grep -vE "$SAFE_PLACEHOLDERS_RE")
    if [ -n "$_matches" ]; then
      echo "[scan-secrets] FINDING in $_label:"
      printf '%s\n' "$_matches" | cut -d: -f1 | sed "s/^/    line /; s/\$/ (pattern $_pn)/"
      FOUND=1
    fi
  done < "$PATTERNS_FILE"
}

MODE="$1"
if [ $# -gt 0 ]; then shift; fi

case "$MODE" in
  files)
    if [ $# -eq 0 ]; then
      echo "[scan-secrets] 'files' was given nothing to scan" >&2
      exit 2
    fi
    for f in "$@"; do
      scan_file "$f" "$f"
    done
    ;;
  objects)
    if [ $# -eq 0 ]; then
      echo "[scan-secrets] 'objects' was given nothing to scan" >&2
      exit 2
    fi
    for sha in "$@"; do
      type=$(git cat-file -t "$sha" 2>/dev/null)
      if [ -z "$type" ]; then
        echo "[scan-secrets] object $sha cannot be resolved - it was not scanned" >&2
        INFRA=1
        continue
      fi
      [ "$type" = "blob" ] || continue
      tmp=$(mktemp 2>/dev/null) || {
        echo "[scan-secrets] mktemp failed - blob $sha was not scanned" >&2
        INFRA=1
        continue
      }
      if ! git cat-file -p "$sha" > "$tmp" 2>/dev/null; then
        echo "[scan-secrets] could not read blob $sha - it was not scanned" >&2
        INFRA=1
        rm -f "$tmp"
        continue
      fi
      scan_file "blob $sha" "$tmp"
      rm -f "$tmp"
    done
    ;;
  *)
    echo "[scan-secrets] usage: scan-secrets.sh <files|objects> <arg>..." >&2
    exit 2
    ;;
esac

if [ "$FOUND" = "1" ]; then
  exit 1
fi
if [ "$INFRA" = "1" ]; then
  exit 2
fi
exit 0
