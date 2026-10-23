# Roblox — Version Reference

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live service, no pinned version) |
| **Installed at pin time** | Studio build `version-7aaa6838d36c4448` (2026-10-23) |
| **Language** | Luau (New Type Solver GA since 2025-11) |
| **Project Pinned** | 2026-10-23 |

Roblox updates Studio and the engine weekly, so there is no version to pin. Check an API against
https://create.roblox.com/docs before using anything you are not sure of, and use the installed
skills: `roblox-luau` (services, remotes, client/server), `roblox-datastores` (persistence).

## Facts verified in this project (measured in Studio, 2026-10-23)

- **Islands are Parts, not Terrain** (since the 2026-10-23 voxel rewrite): `IslandBuilder` makes one Part per
  visible surface block and greedy-merges hidden blocks; 16 chunks = 6,100–10,000 Parts, generation 51–82 ms.
  The Terrain facts below are kept for reference; `IslandService.LIFT` is gone.
- **Terrain surface sits half a voxel outside a full voxel.** With `WriteVoxels` at resolution 4, a column
  whose top full voxel covers `[0, 4)` renders and collides at y = 6, not 4. Two full voxels → 10; a
  following voxel at occupancy 0.5 → 8. Horizontal walls extend about 1.3–2 studs as well.
  Anything placed on generated terrain is lifted by `CELL / 2` (`IslandService.LIFT`).
- Terrain written with `WriteVoxels` is not hit by `workspace:Raycast` in the same frame; a second later every
  ray hits. Anything that raycasts onto a freshly built island waits a beat (`ChoreService.Load` uses 1 s).
- Default avatars (2026-10) use `AnimationConstraint` joints, not `Motor6D`: `UpperTorso.Waist`,
  `RightUpperArm.RightShoulder` and `LeftUpperArm.LeftShoulder` have no `C0`. Pose them by tweening the joint's
  `Attachment0.CFrame` (torso side); `ActionAnimator` handles both kinds.
- `math.noise` returns about −0.5..0.5 and is exactly 0 on integer lattice points; offset inputs by a
  seeded non-integer value.
- Built-in sounds that load from `rbxasset://sounds/`: `impact_water.mp3`, `Kerplunk.wav`, `snap.mp3`,
  `splat.wav`, `victory.wav`, `electronicpingshort.wav`, `button.wav`, `clickfast.wav`, `switch.wav`,
  `short spring sound.wav`, `action_get_up.mp3`, `action_jump_land.mp3`, `hit.wav`, `collide.wav`.
  `swoosh.wav` and `pageturn.wav` do not load.
- `execute_luau` `require` makes a separate module instance from the running game's, so tests that need
  game state go through remotes from the Client datamodel.
- DataStore needs a published place (PlaceId ≠ 0) and "Enable Studio Access to API Services"; until then
  `DataService` runs in memory and warns once.

## Studio MCP limits

- MCP cannot save or publish; the user presses Ctrl+S. A Studio crash loses unsaved MCP edits
  (the 2026-10-23 GPU "Device removed" crash did; recovery came from
  `%LOCALAPPDATA%\Roblox\RobloxStudio\AutoSaves`).
- A modal dialog in Studio blocks every MCP call until it is closed.
- After the **server** moves a character (`PivotTo`), nearby `ProximityPrompt`s stay hidden on the client, so
  the E key and `InputHoldBegin` do nothing until the client moves the character (a client-side `PivotTo` works).
- Client-datamodel calls (`execute_luau`, `get_console_output`) can hang until timeout while an NPC dialogue is
  open; Server calls keep working. Drive dialogues with `user_keyboard_input` (E) and check results on the Server
  or with `screen_capture` (it rendered the 3D view correctly on 2026-10-23 evening).
- `user_mouse_input` x/y are not screenshot pixels; click GUI by `instance_path` (name the button).
- Two-player tests cannot be started through MCP (`start_stop_play` is solo only). Party rules are covered by
  `tests/party_logic.luau`; the real two-client check needs Test → Clients and Servers by hand.
- Push `src/` into the place with `tools/studio_sync_server.py` + `ServerStorage.StudioSync` (see README,
  "Syncing src/ into Studio") instead of pasting scripts through `multi_edit`.
