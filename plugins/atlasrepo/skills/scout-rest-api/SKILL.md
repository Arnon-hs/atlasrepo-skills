---
name: scout-rest-api
description: Search AtlasRepo Scout for vetted open-source repositories and implementation stories matching a task. Works without an API key (free endpoints); a paid key unlocks full catalog search.
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

## Categories

Exact values accepted by `category=` (matching is case-insensitive but exact — `AI/ML` works, `ai-ml` returns nothing):

`Crypto`, `Payments`, `Trading`, `Orchestration`, `MCP`, `Knowledge/RAG`, `Automation`, `AI/ML`, `Frontend`, `Backend`, `DevTools`, `Data`, `Database`, `Observability`, `Mobile`, `DevOps/Infra`, `Security`, `Design`, `Education`, `Marketing`, `Product`, `Misc`

`/api/catalog/top` also accepts a GitHub topic or a language (e.g. `category=rust`) in the same parameter.

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

- `q`: keyword substring match (ILIKE) over title, owner, name, description, valueProposition, integrationNotes, productionReadiness, riskNotes, categories, topics, useCases. Use one distinctive word or short phrase (`"notion"`, `"trading bot"`), not a full sentence.
- `category`: exact category from the list above
- `source`: discovery source — `github`, `hackernews`, `reddit`, `producthunt`, `devto`, `lobsters`, `habr`, `youtube`, `mastodon`
- `language`: primary language, case-insensitive (`python`, `typescript`)
- `minScore` (0–100), `minStars`
- `dateFrom`, `dateTo`: filter by `refreshedAt`
- `sort`: `score` (default), `stars`, `refreshed_at`, `discovered_at`, `updated_at`
- `limit` (max 100), `cursor`: pass `nextCursor` from the previous response

Returns `402` without a valid paid key.

## Query strategy

1. Map the task to 1–2 categories from the list above.
2. No key → call `/api/catalog/top` per category, then `/api/recommendations` for implementation evidence.
3. With a key → `/api/catalog/search` with a narrow `q` + `category`. Empty result? Broaden stepwise: shorten `q` to a single word → drop `category` → drop `minScore`/`minStars`. Sentences in `q` will not match; keep it to keywords.
4. Fetch `/api/repos/<owner>/<name>` for finalists to get linked stories.

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
