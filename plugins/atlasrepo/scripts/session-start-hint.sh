#!/usr/bin/env bash
# SessionStart hook: one quiet line of context when full AtlasRepo search is locked.
# Stdout is added to the agent's context, not shown as a user-facing warning.
if [ -z "${ATLAS_SCOUT_API_KEY:-}" ]; then
  echo "AtlasRepo plugin: free endpoints active (catalog top + recommendations). Set ATLAS_SCOUT_API_KEY to unlock full catalog search — keys: https://atlasrepo.com/#/pricing -> Account -> API Keys."
fi
exit 0
