#!/usr/bin/env bash
# DevOps Portfolio - top-level launcher. Forwards a command to a project's own run.sh.
#
#   ./run.sh                      list projects
#   ./run.sh <project> <command>  e.g.  ./run.sh 02 start   |   ./run.sh observability chaos errors
#   ./run.sh doctor               check tools for every project
set -euo pipefail
cd "$(dirname "$0")"

projects=(0*/)
projects=("${projects[@]%/}")

list() {
  echo "DevOps Portfolio - projects:"
  echo
  for p in "${projects[@]}"; do printf '  %-32s ./run.sh %s help\n' "$p" "${p%%-*}"; done
  echo
  echo "Usage: ./run.sh <number|name> <command> [args]     e.g. ./run.sh 02 start"
  echo "       ./run.sh doctor                              check tools for every project"
}

resolve() {
  local key="$1" p
  for p in "${projects[@]}"; do
    [[ "$p" == "$key" || "${p%%-*}" == "$key" || "${p%%-*}" == "0$key" || "$p" == *"$key"* ]] && { echo "$p"; return; }
  done
  return 1
}

case "${1:-}" in
  ""|help|-h|--help) list ;;
  doctor)
    for p in "${projects[@]}"; do echo; echo "=== $p"; "./$p/run.sh" doctor || true; done ;;
  *)
    proj=$(resolve "$1") || { list; echo; echo "ERROR: unknown project: $1" >&2; exit 1; }
    shift
    exec "./$proj/run.sh" "${@:-help}" ;;
esac
