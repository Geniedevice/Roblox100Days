# Roblox100Days

Existing remote: https://github.com/Geniedevice/Roblox100Days.git

## The game

`Copy of 100 Days.rbxl` is the place file: a multiplayer sky-island farming and healing game. Design doc: https://claude.ai/artifact/Rp92cXi2FKTrooQypDygcC

It used to be a 100-day zombie survival game; that code was removed on 2026-10-23 (it is still in git history before that date). The last zombie place file is in `backups/` (gitignored).

Each player gets a floating island generated from an integer seed saved in their data (same seed = same island). The seed picks one of 10 island concepts (meadow, cherry terraces, snowy peaks, mesa, jungle falls, pale garden, mushroom, amethyst geode, arch archipelago, lush moss). `IslandGen` builds a Minecraft-style block island (3-stud blocks) from 16×16-block chunks; the starting island is 4×4 chunks, each with a zone: shop street (spawn), farm, fishing lake, home plot, mine, forest. `IslandBuilder` turns visible blocks into Parts and greedy-merges hidden cliffs and the underside. On join the island is built in a server slot (`SLOT_SPACING` apart) and the player spawns on it; falling off returns them to spawn. On leave the island is erased. Design: `design/gdd/island-generation.md`, `island-zones.md`.

`DataService` saves one record per player (`player_<UserId>` in the `SkyIslandPlayers` DataStore) with a session lock, autosave every 2 minutes, and a final save on leave and `BindToClose`. Not published yet (PlaceId 0), so saving is skipped in Studio.

On the island: farm plots (till → plant → water → harvest, real-time growth that never wilts), fishing (cast, wait for the bite, reel), mining (hit ore blocks that refill over time), and creatures by biome that can only be petted. Three NPCs with data-graph dialogue and shops: 정원사 모모 (seeds, buys crops), 목수 버니 (furniture), 안내인 루미 (opens farm plots, sells new land chunks, buys fish and ore). Which fish, ore, crops and creatures show up depends on the seed (`Shared/Loot.lua`). Housekeeping lets players place furniture on the home plot, sit on chairs, toggle lanterns, and clean weeds/leaves/pebbles; together they give a cozy score (D–S). A collection dex records crops, fish, ore, creatures, furniture and islands. Players on the same server can visit each other's islands and form parties of up to 6 (the HUD "친구" window); party members can water a friend's crops, and harvest them when the owner allows it. Fish caught on a friend's island come from that island's table. Items show as 3D icons (ViewportFrames of the game's own models). Every action is animated (joint tweens, no animation assets) and has exaggerated feedback (`Juice`: shake, flash, hit stop, squash, rings, layered pitched sounds, combo, items flying to the HUD), with a reduce-motion setting. Design: `design/gdd/` (one GDD per system, CCGS format) and `design/ux/` (HUD, interaction patterns).

`src/` mirrors every script in the place (file name without `.lua` / `.server.lua` / `.client.lua` = instance name). Edit `src/` and sync it into Studio, then save the place (Ctrl+S) before committing.

Rule checks that run without Play live in `tests/` (paste the file into MCP `execute_luau`, Edit datamodel, after syncing; it returns `PASS n`).

### Syncing src/ into Studio

1. `py tools/studio_sync_server.py` (stdlib only, serves `src/` on 127.0.0.1:34999).
2. Once per place, install the module: in the Edit datamodel, fetch `http://127.0.0.1:34999/tool` and put it in `ServerStorage.StudioSync` (ModuleScript).
3. Each sync: `return require(game.ServerStorage.StudioSync:Clone())()` through MCP `execute_luau` (Edit). It creates or updates every script from `src/` and deletes scripts under ReplicatedStorage, ServerScriptService and StarterPlayer that are not in `src/`. HttpEnabled is switched on only during the run.

Skills used (installed in `.claude/skills`): `router` picks `roblox-luau`, `roblox-datastores`, `procedural-gen`, `dialogue-systems`.

The repo also runs Claude Code Game Studios (agents, skills, hooks under `.claude/`, config in `project.yaml`, see CLAUDE.md). Its hooks need Python 3 (`py`) and Git Bash.

## MCP

Studio: Assistant > ... > Manage MCP Servers > Enable Studio as MCP server.
Claude Code: run `claude` from this repository and approve the project MCP if prompted. `.mcp.json` contains the official Windows Studio launcher.
Only one AI should edit the Studio session at a time. Changes through Studio MCP must be saved to the local place file to appear in Git.

Official guide: https://create.roblox.com/docs/studio/mcp
