# AtlasRepo MCP parity roadmap

Goal: make the MCP integration at least as useful as the bundled `scout-rest-api` skill, then make remote MCP the preferred onboarding path.

## Catalog tools shipped in main repo

All catalog tools are read-only and should set `annotations.readOnlyHint: true` so MCP clients can safely auto-approve calls.

| Tool | Purpose | Inputs | Output notes |
|------|---------|--------|--------------|
| `search_catalog` | Paid/full-text catalog search | `q`, `category?`, `language?`, `source?`, `minScore?`, `minStars?`, `sort?`, `limit?`, `cursor?` | Compact repo list with `id`, `url`, `score`, `stars`, `language`, `categories`, `valueProposition`, `riskNotes`, `productionReadiness`, `refreshedAt`, `nextCursor` |
| `top_repos` | Free top repos by category/topic/language | `category?`, `limit?` | Same compact repo list, no paid key required |
| `get_repo` | Details for one finalist | `owner`, `name` | Full repo details plus linked stories/evidence |
| `solve_task` | End-to-end advisor after Epic 3 | `task`, `category?`, `language?`, `source?`, `minScore?`, `minStars?`, `limit?` | Paid `/api/catalog/solve` hybrid results; free fallback to `top_repos` + story recommendations |
| `list_categories` | Category discovery | none | `/api/categories` names, descriptions, and active repo counts |

Existing story/tools MCP methods should remain, but catalog methods must be first-class because they are the core user intent behind `/find-oss`.

## Error degradation

Return structured, user-facing messages instead of raw HTTP failures:

- `402`: `paid_key_required` with pricing URL, API-key setup hint, and fallback suggestion (`top_repos` + recommendations).
- `429`: `rate_limited` with `retryAfter` from the response header when present.
- Empty search after broadening: `no_grounded_match`; tell the agent not to invent repositories.

## Resources

Expose low-cost resources so clients can preload context without a tool call:

- `atlasrepo://categories` — exact category list used by `category=`.
- `atlasrepo://top-feed` — current top repositories grouped by category.
- `atlasrepo://skill/latest` — latest public skill/plugin version and update URL.

## Prompts

Add a prompt named `find-oss-stack`:

```text
Find vetted open-source solutions for: {{task}}

Use AtlasRepo tools only. Search/broaden, fetch details for the top 3 finalists, then return a table with score, license if available, freshness, production readiness, risks, and one winner.
```

## Remote MCP target

Strategic target: `https://atlasrepo.com/mcp` with OAuth.

Why it matters:

1. Claude Desktop / claude.ai users connect in two clicks.
2. Users log in with AtlasRepo; no local API-key copying.
3. Every MCP-connected account becomes an identifiable product lead.
4. OAuth scopes can separate free catalog reads, paid search, and future write/actions.

Keep the local stdio MCP package for developers and CI, but make remote MCP the default paid onboarding path after Epic 3.
