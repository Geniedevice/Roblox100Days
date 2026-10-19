# Roblox100Days

Existing remote: https://github.com/Geniedevice/Roblox100Days.git

## Open the existing game

Open CopyOf100days in Roblox Studio, then use File > Save to File / Save to File As to save it in this repository as CopyOf100days.rbxlx (XML preferred for Git) or CopyOf100days.rbxl. The original game has not yet been located or imported. Keep a separate original backup before editing.

## MCP

Studio: Assistant > ... > Manage MCP Servers > Enable Studio as MCP server.
Claude Code: run `claude` from this repository and approve the project MCP if prompted. `.mcp.json` contains the official Windows Studio launcher.
Codex: Roblox_Studio was registered in the user MCP configuration. Restart the client to load newly registered tools. Open this repository as the working project before editing it.
Only one AI should edit the Studio session at a time. Changes through Studio MCP must be saved to the local place file to appear in Git.

## Connection status at setup

The installed Studio MCP proxy responded to initialize, but tools/list returned an empty list after waiting. An active game and the Studio MCP toggle still need verification. Do not treat registration as a verified game connection.

## Development sequence

1. Back up the original place file.
2. Verify MCP: list open studios, select CopyOf100days, read the tree and console.
3. Inventory scripts and existing systems; record findings before edits.
4. Complete a playable days 1-3 loop using the existing game systems.
5. Playtest spawn, gathering, night enemies, death/restart and day progression.
6. Expand content, then check multiplayer, mobile input, saving and performance.

Official guide: https://create.roblox.com/docs/studio/mcp
