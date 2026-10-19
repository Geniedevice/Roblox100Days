# Roblox100Days

Existing remote: https://github.com/Geniedevice/Roblox100Days.git

## The game

`Copy of 100 Days.rbxl` is the place file: a 100-day co-op zombie survival game built from the Claude Desktop design doc (stages 1-6). It started as an empty Baseplate; the pre-edit copy is in `backups/` (gitignored).

`src/` mirrors every script in the place (file name without `.lua` / `.server.lua` / `.client.lua` = instance name). Edit both together and save the place (Ctrl+S) before committing. Not published yet (PlaceId 0), so DataStore saving is skipped in Studio.

## MCP

Studio: Assistant > ... > Manage MCP Servers > Enable Studio as MCP server.
Claude Code: run `claude` from this repository and approve the project MCP if prompted. `.mcp.json` contains the official Windows Studio launcher.
Codex: Roblox_Studio was registered in the user MCP configuration. Restart the client to load newly registered tools. Open this repository as the working project before editing it.
Only one AI should edit the Studio session at a time. Changes through Studio MCP must be saved to the local place file to appear in Git.

## Development sequence

1. Back up the original place file.
2. Verify MCP: list open studios, select CopyOf100days, read the tree and console.
3. Inventory scripts and existing systems; record findings before edits.
4. Complete a playable days 1-3 loop using the existing game systems.
5. Playtest spawn, gathering, night enemies, death/restart and day progression.
6. Expand content, then check multiplayer, mobile input, saving and performance.

Official guide: https://create.roblox.com/docs/studio/mcp
