---
name: scout-rest-api
description: Search AtlasRepo Scout for vetted open-source repositories and implementation stories matching a task. Works without an API key (free endpoints); a paid key unlocks full catalog search.
version: 2.3.0
---

# AtlasRepo Scout REST API Skill

Use this skill when an agent needs grounded open-source options instead of inventing a stack from memory.

## Environment

```bash
export ATLAS_SCOUT_BASE_URL="${ATLAS_SCOUT_BASE_URL:-https://atlasrepo.com}"
export ATLAS_SCOUT_API_KEY="atlas_..."   # optional — unlocks /api/catalog/search
```

When `ATLAS_SCOUT_API_KEY` is set, send it on every request as `-H "x-api-key: $ATLAS_SCOUT_API_KEY"`.
Without a key the free endpoints below still work (30 req/min per IP). A paid key raises the limit to 300 req/min and unlocks full-text catalog search. Keys are created at `https://atlasrepo.com` → Account → API Keys (requires an active subscription).

## Quick search (preferred)

The bundled script handles auth, URL encoding, automatic query broadening, and free-tier fallback in one call:

```bash
scripts/atlas-search.sh "<keyword>" ["<category>"] [limit]
scripts/atlas-search.sh --pretty "<keyword>" ["<category>"] [limit]
scripts/atlas-search.sh --version
scripts/atlas-search.sh --check-version
# examples:
scripts/atlas-search.sh "notion" "Automation" 10
scripts/atlas-search.sh "trading bot"
```

It prints compact JSON to stdout by default and the search strategy it used to stderr. Add `--pretty` when you need full API fields for finalist comparison. It also converts invalid-key, `402`, and `429` responses into agent-readable JSON instead of raw API errors. Use the raw endpoints below only when you need parameters the script doesn't cover (source, dates, cursor pagination).

`--check-version` calls `/api/skill/latest` when that endpoint exists and returns whether this bundled skill is current. If the endpoint is not deployed yet, treat `status: "unknown"` as non-blocking.

## Categories

Exact values accepted by `category=` (matching is case-insensitive but exact — `AI/ML` works, `ai-ml` returns nothing):

`Crypto`, `Payments`, `Trading`, `Orchestration`, `MCP`, `Knowledge/RAG`, `Automation`, `AI/ML`, `Frontend`, `Backend`, `DevTools`, `Data`, `Database`, `Observability`, `Mobile`, `DevOps/Infra`, `Security`, `Design`, `Education`, `Marketing`, `Product`, `Misc`

`/api/catalog/top` also accepts a GitHub topic or a language (e.g. `category=rust`) in the same parameter.

## Writing queries: good vs bad

`q` is keyword substring matching (ILIKE), not semantic search. Sentences never match.

| ✅ Good | ❌ Bad |
|---------|--------|
| `q=notion` | `q=best tool to replace notion` |
| `q=screencast` | `q=how to record my screen on macOS` |
| `q=trading bot` + `category=Trading` | `q=I need something for algorithmic trading` |
| `q=rag` + `category=Knowledge/RAG` | `q=retrieval augmented generation framework for production` |

For task-shaped natural-language questions use `POST /api/recommendations` (semantic, free) instead of `q`.

## Free endpoints (no key required)

Top repos by category / topic / language:

```bash
curl -sS "$ATLAS_SCOUT_BASE_URL/api/catalog/top?category=Automation&limit=30"
```

Semantic story recommendations for a task described in natural language:

```bash
curl -sS -X POST "$ATLAS_SCOUT_BASE_URL/api/recommendations" \
  -H "content-type: application/json" \
  -d '{"query": "self-hosted alternative to Notion for a small team", "limit": 5}'
```

Repo details with linked stories, stories, tags, tools:

```bash
curl -sS "$ATLAS_SCOUT_BASE_URL/api/repos/<owner>/<name>"
curl -sS "$ATLAS_SCOUT_BASE_URL/api/stories?q=notion&type=workflow&limit=10"
curl -sS "$ATLAS_SCOUT_BASE_URL/api/stories/<slug>"
curl -sS "$ATLAS_SCOUT_BASE_URL/api/tags"
curl -sS "$ATLAS_SCOUT_BASE_URL/api/tools?q=langchain&minQuality=0.5"
```

## Full catalog search (paid key required)

```bash
curl -sS "$ATLAS_SCOUT_BASE_URL/api/catalog/search?q=screencast&category=Automation&minScore=60&limit=10" \
  -H "x-api-key: $ATLAS_SCOUT_API_KEY"
```

Parameters:

- `q`: keyword substring match (ILIKE) over title, owner, name, description, valueProposition, integrationNotes, productionReadiness, riskNotes, categories, topics, useCases
- `category`: exact category from the list above
- `source`: discovery source — `github`, `hackernews`, `reddit`, `producthunt`, `devto`, `lobsters`, `habr`, `youtube`, `mastodon`
- `language`: primary language, case-insensitive (`python`, `typescript`)
- `minScore` (0–100), `minStars`
- `dateFrom`, `dateTo`: filter by `refreshedAt`
- `sort`: `score` (default), `stars`, `refreshed_at`, `discovered_at`, `updated_at`
- `limit` (max 100), `cursor`: pass `nextCursor` from the previous response

Returns `402` without a valid paid key and `429` when rate-limited. Prefer the bundled script because it turns those statuses into user-facing guidance with the pricing URL or retry-after value.

## Query strategy

1. Map the task to 1–2 categories from the list above.
2. Run `scripts/atlas-search.sh "<keyword>" "<category>"` — it broadens automatically (full query → first keyword → no category) and falls back to free endpoints without a key.
3. Add `/api/recommendations` for implementation evidence when the task is described in natural language.
4. Fetch `/api/repos/<owner>/<name>` for finalists to get linked stories.
5. If `scripts/atlas-search.sh --check-version` says the skill is outdated, mention the update URL after answering the user's search task.

## Compare finalists (turns search into advice)

When more than one candidate survives, fetch details for the top 2–3 and present a comparison before recommending:

```bash
curl -sS "$ATLAS_SCOUT_BASE_URL/api/repos/<owner1>/<name1>"
curl -sS "$ATLAS_SCOUT_BASE_URL/api/repos/<owner2>/<name2>"
```

Build a short table from: `score`, `stars`, `refreshedAt` (freshness), `riskNotes`, `productionReadiness`, `integrationNotes`, linked stories count. Recommend one winner and say why the others lost. If the user's constraints (language, license, self-hosted) eliminate all finalists, say so instead of stretching a bad fit.

## Reading results

Most useful fields per catalog item: `score` (0–100 AtlasRepo quality score), `valueProposition`, `useCases`, `integrationNotes`, `productionReadiness`, `riskNotes`, `categories`, `stars`, `refreshedAt`. Prefer active repos with high score, recent `refreshedAt`, and relevant categories.

## Public docs

- Swagger UI: `/api/docs`
- OpenAPI JSON: `/api/openapi.json`

## Agent behavior

1. Return concise recommendations: repo URL, why it fits (ground it in `valueProposition`/`useCases`), risks (from `riskNotes`), and any linked story evidence.
2. Use story results as evidence. Do not add tools or claims that are not present in the API response unless you clearly label them as external suggestions.
3. If the API returns no matches after broadening, say that Scout has no grounded match; do not fabricate catalog entries.
4. If the user needs full search but no key is set, mention that a paid API key from `https://atlasrepo.com/#/pricing` unlocks `/api/catalog/search`.

---

Skill version: 2.3.0 · updates: <https://github.com/Arnon-hs/atlasrepo-skills>
