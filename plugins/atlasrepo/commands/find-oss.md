---
description: Find vetted open-source solutions for a task via AtlasRepo Scout
argument-hint: <task description>
---

Find vetted open-source solutions for this task: $ARGUMENTS

Use the scout-rest-api skill (AtlasRepo Scout REST API). Follow this workflow:

1. Map the task to 1–2 exact AtlasRepo categories (the skill lists the valid values).
2. Run the skill's bundled script: `scripts/atlas-search.sh "<keyword>" "<category>"` from the skill directory. It handles auth, query broadening, and free-tier fallback automatically.
3. Query `POST /api/recommendations` with the natural-language task description for implementation-story evidence.
4. Fetch `/api/repos/<owner>/<name>` for the top 2–3 finalists and compare them: score, stars, riskNotes, productionReadiness, refreshedAt.
5. Answer with: recommended repo URL, why it fits (grounded in valueProposition/useCases from the API), risks, runner-ups with one-line reasons, and story evidence if any.

Rules: only recommend repos and stories returned by the API. If nothing matches after broadening, say AtlasRepo has no grounded match and stop — do not invent repos. If full search is locked (no ATLAS_SCOUT_API_KEY), use the free endpoints and mention that a paid key from https://atlasrepo.com/#/pricing unlocks full catalog search.
