# Party & Visiting (파티·섬 방문)

> Category: Gameplay · Priority: Alpha · Status: Implemented (2026-10-23, 같은 서버 범위) — `PartyService.lua`, `IslandService.lua`(어디 있는지·방문 이동), `FarmService`·`FishService`·`NpcService`(권한), client `SocialClient`, `Hud`(설정 2줄)

## Overview

같은 서버의 다른 플레이어 섬에 놀러 가고, 파티를 맺어 서로의 밭에 물을 줄 수 있다. 친구 섬에서는 그 섬 바이옴의 물고기·생물·섬 도감 칸을 채울 수 있어서, 도감이 방문의 이유가 된다(collection-dex.md). 다른 서버 친구 초대는 publish 뒤 단계로 미룬다.

## Player Fantasy

"내 섬 구경 올래?" 친구 섬은 시드가 달라 생김새·물고기·생물이 다르다. 놀러 가서 낚시하고, 동물을 쓰다듬고, 파티원이면 친구 밭에 물을 주고 돌아온다.

## Detailed Rules

1. **친구 창**: HUD 오른쪽 기둥 "친구" 버튼. 서버의 다른 플레이어마다 한 줄 — 얼굴 사진, 이름, 섬 컨셉 이름 · 청크 수, 파티 표시(왕관 = 파티장), 버튼 "놀러 가기"·"초대". 아래쪽에 내 파티(인원/6, "파티 나가기"), 남의 섬에 있으면 "우리 섬으로".
2. **방문**: `Interact("Visit", 주인 Player)`. 주인의 설정이 "파티원만"이면 같은 파티일 때만 된다. 서버가 그 섬 스폰으로 옮기고 `Visiting` 속성(주인 UserId)을 단다. 처음 간 섬의 컨셉은 방문자 도감 "섬"에 기록된다(+10코인).
3. **집으로**: `Interact("Home")` 또는 방문 알약의 "집으로". 죽거나 다시 태어나면 늘 내 섬이다. 남의 섬에서 떨어지면 그 섬 스폰으로 돌아온다. 주인이 나가 섬이 지워지면 그 섬에 있던 사람은 모두 집으로 간다.
4. **파티**: 최대 6명, 파티장 1명. `Interact("Invite", 상대)` → 상대에게 초대 카드(수락·거절, 30초). 수락하면 초대한 사람의 파티에 들어간다(초대한 사람이 파티가 없으면 새 파티, 그 사람이 파티장). 파티 상태는 서버 메모리에만 있고 `PartyId`·`PartyLeader` 속성으로 모두에게 보인다.
   - 이미 파티에 있는 사람은 초대할 수 없다(먼저 나가야 한다). 한 사람에게 걸린 초대는 하나뿐이다.
   - `Interact("LeaveParty")`로 나간다. 파티장이 나가면 가장 먼저 들어온 사람이 이어받는다. 한 명만 남으면 파티가 사라진다.
4-1. **인사하기**(2026-10-24): 다른 플레이어를 누르거나 8스터드 안에서 E → 손 흔들기·하트·"안녕!" 말풍선, 상대에게 토스트(파티가 아니어도 된다). 5초 안에 서로 인사하면 하이파이브. 처리는 `PartyPlayService`(party-play.md).
4-2. **파티 놀거리**(2026-10-24): 파티 의뢰·파티 대회·이벤트 함께 받기 — party-play.md. 친구 창 맨 위 "파티 놀이" 줄, 왼쪽 위 파티 카드.
5. **권한**(서버가 판정, 주인 = 그 섬 주인). 같은 섬 연합 멤버는 파티원과 같다(`PartyService.Same`이 `UnionId`도 본다, island-union.md):

   | 행동 | 방문객 | 파티원 | 주인 |
   |------|------|------|------|
   | 구경·낚시·생물 쓰다듬기·NPC 상점·팔기 | O | O | O |
   | 물주기 | X | O | O |
   | 수확 | X | 주인이 "파티원 수확"을 켰을 때 | O |
   | 갈기·심기·캐기·집안일·가구 | X | X | O |
   | 밭 열기·섬 넓히기(루미) | X | X | O |

   - 파티원이 물을 주거나 거두면 작물은 주인 것이다(주인 보관함으로). 주인에게 "○○님이 물을 줬어요" 토스트가 간다.
   - 남의 섬 물에서 낚으면 물고기는 낚은 사람 것이고, 표는 그 섬(시드) 것이다.
   - 남의 섬 루미는 밭 열기·섬 넓히기를 보이지 않고, "이 섬의 명물"은 그 섬 것을 말한다.
6. **설정**(설정 창 2줄, 저장됨): "섬 방문" = 모두 / 파티원만(기본 모두), "파티원 수확" = 켬 / 끔(기본 끔).

## Formulas

수식 없음. 수치는 Tuning Knobs의 상수뿐이다.

## Edge Cases

- 주인이 아직 섬을 불러오는 중이면 "섬을 준비하는 중이에요" 토스트, 이동하지 않는다.
- 초대 중에 초대한 사람이 나가거나 파티가 6명이 되면, 수락해도 "파티에 들어갈 수 없어요" 토스트.
- 초대를 연달아 누르면 3초 안의 두 번째부터 무시한다.
- 주인이 "파티원만"으로 바꿔도 이미 와 있는 방문객을 내보내지는 않는다(다음 방문부터 막는다).
- 파티를 나가도 친구 섬에 있던 사람은 그대로 남는다. 물주기 권한만 사라진다.
- 방문 중에 내 섬 땅을 사면(루미는 내 섬에만 있다) 해당 없음.

## Dependencies

- 기대는 것: Island Generation·IslandService(섬 기록·스폰), Data Persistence(설정), Collection Dex(섬 기록), Farming·Fishing·NPC Dialogue(권한)
- 이것에 기대는 것: Island Union(파티가 있어야 편입 제안), Party Play(`PartyService.Members`로 파티원을 읽는다)
- 양방향: farming.md(파티원 물주기·수확), fishing.md(남의 섬 낚시), npc-dialogue.md(남의 섬 루미), collection-dex.md(방문 기록)

## Tuning Knobs

| 상수 | 값 | 범위 | 영향 |
|------|------|------|------|
| `PartyService.MAX` | 6 | 2–6 | 파티 인원(서버 최대 인원 6과 맞춘다) |
| `PartyService.INVITE_TTL` | 30초 | 10–60 | 초대 카드가 떠 있는 시간 |
| `PartyService.INVITE_COOLDOWN` | 3초 | 1–10 | 초대 연타 막기 |

## Acceptance Criteria

- [ ] 두 명이 있는 서버에서 A가 B 섬에 "놀러 가기"를 누르면 B 섬 스폰에 서고, A 도감 "섬"에 B 섬 컨셉이 기록된다.
- [ ] B가 "섬 방문 = 파티원만"이면 파티가 아닌 A의 방문은 토스트로 거절된다.
- [ ] A가 B를 초대하고 B가 수락하면 둘의 `PartyId`가 같고 A가 파티장이다. A가 나가면 B가 파티장이 되지 않고 파티가 사라진다(한 명).
- [ ] 파티원 A가 B의 물 안 준 작물을 누르면 물이 주어지고, B의 작물 상태가 바뀐다. 방문객(파티 아님)은 거절된다.
- [ ] "파티원 수확"이 꺼져 있으면 A는 B의 다 자란 작물을 거둘 수 없고, 켜면 거둔 작물이 B의 보관함에 들어간다.
- [ ] A가 B 섬 물에서 낚은 물고기는 A의 보관함과 도감에 들어간다.
- [ ] B가 나가면 B 섬에 있던 A는 자기 섬 스폰으로 돌아간다.
- [ ] B 섬의 루미에게 A가 말을 걸면 "밭 열기"·"섬 넓히기"가 없다.

## Verification (2026-10-23)

- `tests/party_logic.luau`: 14 rule checks pass (invite/accept, leader, Same, harvest permission, party-only visit,
  island dex record, home, invite cooldown, leave → dissolve, decline, union = party permission). A mutant that ignores
  "파티원 수확" fails it. Re-run 2026-10-24 after the union change: 14 pass.
- Solo Play: friends window, settings rows, home 루미 options, farming/fishing on own island unchanged, no errors.
- **Not run:** the two-player criteria above. MCP cannot start a multi-client test; run Test → Clients and Servers
  (2 players) by hand and tick the boxes.

## Not in this slice

- 다른 서버 친구 초대(`SocialService:PromptGameInvite` + `TeleportService` + `ReserveServer`): publish 뒤에만 시험할 수 있다.
- 공동 관리자 역할(섬 편입 단계), 방문객 내보내기.
