# Playtest — solo loop, automated (2026-10-23)

Gate 1 ("혼자서 15분 루프가 재미있다"): **NOT ASSESSED** for fun. A script can confirm that the loop
runs end to end; only a person can judge that it is fun. The user's own 15-minute session is still needed.

## How it ran

Studio Play, one player, fresh profile (DataStore off), island Archipelago (seed 195351583). Every step
was sent through the real remotes from the Client datamodel and checked on the Server.

| Step | Result |
|------|--------|
| 모모 첫 대화 (intro 3줄 → 순무 씨앗 ×5) | OK |
| 씨앗 상점 구매 / 없는 상품 | OK / "없는 상품이에요" |
| 농지 3칸 갈기 → 심기 → 물주기, 자라는 중 다시 누르기 | OK (Till/Plant/Water, toast) |
| 수확 3칸 (심은 지 약 8분 뒤) | OK, 순무 3 |
| 버니 상점 꽃 화분 구매 → 집터에 배치 | OK, 아늑함 4, 도감 가구 1/8 (+10) |
| 집안일 잡초 치우기 | OK, +3 코인 |
| 도감 조회 | OK (작물 0/3 → 수확 뒤 기록, 섬 1/10) |
| 자동 낚시 20번 | 19마리, 놓침 0, 물고기 값 137 |
| 루미: 팔기 → 섬 넓히기 → 농장 땅 | OK, 216 → 16코인, 17청크, 밭 자리 +4, 가구·NPC 유지 |
| Output 오류 | 없음 (DataStore 꺼짐 경고만) |

Fishing, mining and petting were also play-tested in the previous session after the chunk rewrite.

## Findings

1. **Balance concern — fishing outpaces early farming about 8×.** Fishing pays about 8 coins every
   6–7 s (≈ 4,400/h, `fishing.md`). Nine turnip tiles pay 9 × 7 profit every ≈ 4 min (≈ 900/h). The first
   land chunk (200 coins) took about 3 minutes of fishing. Farming is Pillar 1's core loop; if testers stop
   farming, lower fish prices or raise early crop value. Left unchanged until a human playtest.
2. **Tool issue:** some Client `execute_luau` calls never return (2 of ~20 here), even short ones. Fire the
   remote, return, and read the result in a second call.

## Not covered

- Feel, readability of the new HUD, animations and particles (screen capture renders black).
- Mobile touch layout.
- DataStore save and rejoin (place not published).
