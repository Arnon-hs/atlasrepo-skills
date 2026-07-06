#!/usr/bin/env bash
set -euo pipefail

TARGET_AUTHOR_NAME="${TARGET_AUTHOR_NAME-Arnon-hs}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: this script must be run inside a Git repository." >&2
  exit 1
fi

if ! command -v git-filter-repo >/dev/null 2>&1; then
  echo "Error: git-filter-repo is not installed." >&2
  echo "Install it first, for example: python3 -m pip install --user git-filter-repo" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Error: working tree is dirty. Commit, stash, or remove local changes before rewriting history." >&2
  exit 1
fi

if [ "${CONFIRM_REWRITE_HISTORY:-}" != "1" ]; then
  echo "Error: refusing to rewrite history without CONFIRM_REWRITE_HISTORY=1." >&2
  echo "This operation rewrites every commit and changes commit hashes." >&2
  exit 1
fi

if [ -z "${TARGET_AUTHOR_EMAIL:-}" ]; then
  echo "Error: TARGET_AUTHOR_EMAIL is required." >&2
  echo "Example: TARGET_AUTHOR_EMAIL='49660318+Arnon-hs@users.noreply.github.com' CONFIRM_REWRITE_HISTORY=1 bash scripts/rewrite-git-authors.sh" >&2
  exit 1
fi

if [ -z "${TARGET_AUTHOR_NAME}" ]; then
  echo "Error: TARGET_AUTHOR_NAME must not be empty." >&2
  exit 1
fi

echo "WARNING: Git history will be rewritten in this repository."
echo "All commit author and committer metadata will become:"
echo "  ${TARGET_AUTHOR_NAME} <${TARGET_AUTHOR_EMAIL}>"
echo "Every rewritten commit will get a new hash."
echo
echo "Make sure a mirror backup exists before continuing."
echo

git filter-repo --force --commit-callback '
import os

target_name = os.environ["TARGET_AUTHOR_NAME"].encode("utf-8")
target_email = os.environ["TARGET_AUTHOR_EMAIL"].encode("utf-8")

commit.author_name = target_name
commit.author_email = target_email
commit.committer_name = target_name
commit.committer_email = target_email
'

echo
echo "Rewrite complete. Verify the result before any force push:"
echo '  git log --format="%h | author=%an <%ae> | committer=%cn <%ce>" --all | head -50'
echo '  git shortlog -sne --all'
