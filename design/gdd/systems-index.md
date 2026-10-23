# Systems Index: Sky Island Farm

> **Status**: Draft
> **Created**: 2026-10-23
> **Last Updated**: 2026-10-23
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

The game needs few systems but every one sits on the same spine: a seed-built island loaded per player, a single player record that persists, and a server that decides every action a client requests. The MVP loop (Pillar 1: 서두르지 않아도 되는 섬) is farming → selling to the island NPC → spending on seeds and furniture, with collection dex and housekeeping as the reasons to keep coming back. Social systems (party, visiting, island union) come after the solo 15-minute loop is fun.

- **Data Persistence** — one DataStore record per player with a session lock; every other system writes into it. Bottleneck: a bug here loses progress for all systems.
- **Island Generation** — seed → one of 10 concepts → Minecraft-style block island built from Parts. Only the seed is stored (Pillar 2: 세상에 하나뿐인 내 섬).
- **Island Zones & Expansion** — 16×16-block chunks (start 4×4) with zones (shop street, farm, fishing, home plot, mine, forest); guide 루미 opens plots and sells land; seed-based loot tables for fish, ore, crops, creatures.
- **Fishing**, **Mining**, **Creatures** — cast/bite/reel at the lake, ore blocks that refill, biome creatures to pet; all feed the dex and 루미's shop.
- **Inventory & Economy** — coins and item counts; the only path that changes them.
- **Farming** — 3×3 farm on the yard, till/plant/water/harvest, real-time growth that never wilts.
- **NPC Dialogue & Shops** — data-graph dialogue, shops and selling; the hub for each content type.
- **Collection Dex** (inferred: required by the user) — first-discovery records for crops, furniture, biomes; later fish.
- **Housekeeping** — furniture placement with storage, chores (weeds, leaves, pebbles), cozy score.
- **Action Animation** (inferred) — procedural character motions for each farm/house action, crop and NPC idle motion.
- **Interaction Feedback (VFX/SFX)** (inferred) — highlight, particles, sounds, floating text, toasts; the 1-second feedback promised by the concept's Flow State Design.
- **HUD** — cozy/coins/dex pills, zone hotbar with 3D icons, toasts, combo, settings (reduce motion).
- **Party & Visiting** — same-server visits and parties of up to 6; party members water each other's crops. Cross-server invites wait for publish.
- **Island Union** — after the MVP.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Data Persistence | Persistence | MVP | Implemented | — | — |
| 2 | Island Generation | Core | MVP | Implemented | design/gdd/island-generation.md | — |
| 3 | Inventory & Economy (inferred) | Economy | MVP | Implemented | — | Data Persistence |
| 4 | Farming | Gameplay | MVP | Implemented | design/gdd/farming.md | Island Generation, Inventory & Economy, Data Persistence |
| 5 | NPC Dialogue & Shops | Narrative | MVP | Implemented | design/gdd/npc-dialogue.md | Inventory & Economy, Data Persistence, Island Generation |
| 6 | Collection Dex | Progression | MVP | Implemented | design/gdd/collection-dex.md | Farming, Housekeeping, Island Generation, Data Persistence |
| 7 | Housekeeping | Gameplay | MVP | Implemented | design/gdd/housekeeping.md | Island Generation, Inventory & Economy, NPC Dialogue & Shops, Data Persistence |
| 8 | Action Animation (inferred) | Gameplay | Vertical Slice | Implemented | design/gdd/action-animation.md | Farming, Housekeeping, NPC Dialogue & Shops |
| 9 | Interaction Feedback (inferred) | UI | Vertical Slice | Implemented | design/gdd/interaction-feedback.md | Farming, Housekeeping, Collection Dex, NPC Dialogue & Shops |
| 10 | HUD | UI | MVP | Implemented | design/ux/hud.md | Inventory & Economy, Farming, Island Zones & Expansion |
| 11 | Island Zones & Expansion (was Island Progression) | Progression | MVP | Implemented | design/gdd/island-zones.md | Island Generation, Inventory & Economy, NPC Dialogue & Shops, Data Persistence |
| 12 | Party & Visiting | Gameplay | Alpha | Implemented (same server) | design/gdd/party-visiting.md | Island Generation, Data Persistence, Farming, Fishing, Collection Dex |
| 13 | Fishing | Gameplay | MVP | Implemented | design/gdd/fishing.md | Island Zones & Expansion, Inventory & Economy, Collection Dex |
| 14 | Island Union | Gameplay | Full Vision | Not Started | — | Party & Visiting, Island Generation, Data Persistence |
| 15 | Mining | Gameplay | MVP | Implemented | design/gdd/mining.md | Island Zones & Expansion, Inventory & Economy, Collection Dex |
| 16 | Creatures | Gameplay | Vertical Slice | Implemented | design/gdd/creatures.md | Island Generation, Island Zones & Expansion, Collection Dex |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Solo 15-minute loop: farm, sell, buy, place, clean, fill the dex | First playable | Design FIRST |
| **Vertical Slice** | The same loop with motion, particles and sound so it feels good | Demo | Design SECOND |
| **Alpha** | Friends, visiting | Alpha | Design THIRD |
| **Full Vision** | Island union | Beta / Release | As needed |

---

## Dependency Map

### Foundation Layer
1. Data Persistence — every saved thing goes through one record and one lock.
2. Island Generation — every placed thing needs the island origin and yard height.

### Core Layer
1. Inventory & Economy — depends on: Data Persistence

### Feature Layer
1. Farming — depends on: Island Generation, Inventory & Economy, Data Persistence
2. NPC Dialogue & Shops — depends on: Inventory & Economy, Data Persistence, Island Generation
3. Housekeeping — depends on: Island Generation, Inventory & Economy, NPC Dialogue & Shops (carpenter shop), Data Persistence
4. Collection Dex — depends on: Farming, Housekeeping, Fishing, Mining, Creatures, Island Generation, Data Persistence
5. Island Zones & Expansion — depends on: Island Generation, Inventory & Economy, NPC Dialogue & Shops (루미), Data Persistence
6. Fishing, Mining — depend on: Island Zones & Expansion, Inventory & Economy
7. Creatures — depends on: Island Generation (biome), Island Zones & Expansion (habitat chunks)

### Presentation Layer
1. Action Animation — depends on: Farming, Housekeeping, Fishing, Mining, Creatures, NPC Dialogue & Shops (their Feedback signals)
2. Interaction Feedback — depends on: every Feature-layer system (Feedback signals)
3. HUD — depends on: Inventory & Economy, Farming, Island Zones & Expansion (zone hotbar)

### Polish Layer
1. Party & Visiting — depends on: Island Generation, Data Persistence (settings), Farming, Fishing, Collection Dex
2. Island Union — depends on: Party & Visiting

Bottlenecks: Data Persistence and Island Generation (everything depends on them). Leaf systems: Action Animation, Interaction Feedback, Island Union. No cycles: Collection Dex reads events from Farming and Housekeeping but neither reads the dex.

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Farming | MVP | Feature | game-designer, roblox-specialist | Done (doc after code) |
| 2 | NPC Dialogue & Shops | MVP | Feature | game-designer, writer | Done (doc after code) |
| 3 | Collection Dex | MVP | Feature | game-designer, systems-designer | S |
| 4 | Housekeeping | MVP | Feature | game-designer, economy-designer | M |
| 5 | Action Animation | Vertical Slice | Presentation | technical-artist, roblox-specialist | S |
| 6 | Interaction Feedback | Vertical Slice | Presentation | technical-artist, sound-designer | S |

Gates skipped in this run (review mode solo): TD-SYSTEM-BOUNDARY, PR-SCOPE, CD-SYSTEMS.

---

## High-Risk Systems

| System | Risk | Mitigation |
|--------|------|------------|
| Data Persistence | Untested against a live DataStore (place not published) | Test publish + rejoin before Alpha |
| Housekeeping | Placement UI on mobile; 300-item performance | Grid snap + tap-to-place; cap at 300 |
| Island Generation | 6,100–10,000 Parts per island replicated by the server; land expansion adds more | Greedy-merge hidden blocks; if servers fill up, send only the seed and build on the client (`ponytail:` note in `IslandBuilder`) |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems | 16 |
| GDDs written | 12 GDDs + HUD UX spec |
| Implemented | 15 |
