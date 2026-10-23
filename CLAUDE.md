Read AGENTS.md and README.md before working. Use the Roblox_Studio MCP configured in .mcp.json. Never claim MCP edits are saved to Git until the place file has been saved locally.

## Game studio (CCGS)

This repo runs [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) (agents, skills, hooks and rules in `.claude/`), adapted for Roblox:

- Config: `project.yaml` — engine Roblox/Luau, `modes.rigor: standard`, `modes.automation: autonomous`. Change it with `/settings`.
- Engine facts measured in this project: @docs/engine-reference/roblox/VERSION.md
- Code root is `src/`, the mirror of the place's scripts. The engine specialist is `.claude/agents/roblox-specialist.md`; the Godot/Unity/Unreal agents were left out.
- Design: `design/gdd/` (game concept, systems index, one GDD per system). The shared player-facing design doc is https://claude.ai/artifact/Rp92cXi2FKTrooQypDygcC — change both together.
- Session checkpoint: `production/session-state/active.md`. Read it first after a compaction, crash or `/clear`.
- Coordination rules: @.claude/docs/coordination-rules.md

## Automation

`autonomous` mode: pick the recommended option, log the decision to `production/session-logs/decision-log.md`, and keep going. Stop only for what the user must do: saving or publishing the place, spending Robux, deleting player data.

Per feature: `/design-system <system>` → `/design-review` → `/create-stories` → implement with `roblox-specialist` → verify in Play mode → `/story-done`.
