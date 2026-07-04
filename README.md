# AtlasRepo Skills

Official agent integrations for [AtlasRepo](https://atlasrepo.com) — an autonomous 24/7 open-source scout. Install once, and your coding agent (Claude Code, Codex, any SKILL.md-aware agent) queries the AtlasRepo catalog for vetted open-source repositories and implementation stories instead of inventing a stack from memory.

## What's inside

| Component | Path | Status |
|-----------|------|--------|
| `scout-rest-api` skill (v2.3, with bundled `atlas-search.sh`, compact/pretty output, version check, invalid-key/402/429 UX) | `plugins/atlasrepo/skills/scout-rest-api/` | ✅ ready |
| `/find-oss <task>` slash command | `plugins/atlasrepo/commands/find-oss.md` | ✅ ready |
| `oss-scout` background research agent | `plugins/atlasrepo/agents/oss-scout.md` | ✅ ready |
| SessionStart hint (only when no API key is set) | `plugins/atlasrepo/hooks/hooks.json` | ✅ ready |
| MCP server config | `plugins/atlasrepo/mcp.json.example` | ⏳ activates when `atlasrepo-mcp` is published to npm |

After install, try: `/find-oss self-hosted analytics for a small SaaS`

## Install — Claude Code (plugin, recommended)

```
/plugin marketplace add Arnon-hs/atlasrepo-skills
/plugin install atlasrepo
```

## Install — skill only (Claude Code / any agent)

```bash
mkdir -p ~/.claude/skills/scout-rest-api
curl -o ~/.claude/skills/scout-rest-api/SKILL.md \
  https://raw.githubusercontent.com/Arnon-hs/atlasrepo-skills/main/plugins/atlasrepo/skills/scout-rest-api/SKILL.md
```

For a single project, put the file under `<project>/.claude/skills/scout-rest-api/SKILL.md` instead. For Codex, copy it into the project and reference it from `AGENTS.md`.

## API key (optional but recommended)

Free endpoints (`/api/catalog/top`, `/api/recommendations`, `/api/stories`, `/api/repos/...`) work without a key at 30 req/min. A paid key unlocks full catalog search (`/api/catalog/search`) at 300 req/min.

1. Subscribe at <https://atlasrepo.com/#/pricing>
2. Create a key: Account → API Keys
3. Export it in the environment your agent runs in:

```bash
export ATLAS_SCOUT_API_KEY="atlas_..."
```

## MCP server

The stdio MCP server (`search_workflow_stories`, `recommend_tool_stack`, `find_self_hosted_alternatives`, `get_implementation_guide`, `get_story`, `list_tools`) currently lives in the main AtlasRepo repository and requires a local build. For parity with this skill, the next MCP release should also expose catalog tools: `search_catalog`, `top_repos`, `get_repo`, and later `solve_task`, all marked read-only where applicable. Once it ships to npm as `atlasrepo-mcp`, rename `plugins/atlasrepo/mcp.json.example` to `.mcp.json` and the plugin will register it automatically. Manual registration will then be:

```bash
claude mcp add atlasrepo -e ATLASREPO_API_KEY=atlas_... -- npx -y atlasrepo-mcp
```

## Docs

- Swagger UI: <https://atlasrepo.com/api/docs>
- OpenAPI JSON: <https://atlasrepo.com/api/openapi.json>
- MCP parity roadmap: `plugins/atlasrepo/MCP_ROADMAP.md`

## Source of truth

The canonical copy of the skill is maintained in the main AtlasRepo repository at `skills/scout-rest-api/SKILL.md` and mirrored here on release. Keep the two in sync when editing.

## License

MIT
