# Farming

> Category: Gameplay · Priority: MVP · Status: Implemented (`src/ServerScriptService/Services/FarmService.lua`, data `src/ReplicatedStorage/Shared/Crops.lua`)

## Overview

섬 마당의 3×3 농지(칸당 4×4스터드)에서 작물을 키운다. 농지를 누르면 서버가 상태에 맞는 동작 하나를 고른다: 갈기 → 심기 → 물주기 → 수확. 작물은 실제 시간으로 자라고, 섬을 비운 동안에도 자라며, 시들지 않는다(Pillar 1).

## Detailed Rules

1. 농지는 스폰 앞(+Z) 마당 칸 x∈{-1,0,1}, z∈{2,3,4}에 놓인다. 번호 1~9 = 왼쪽 아래부터 행 순서.
2. 누르기 요청(`Interact("Tile", 농지, 고른 씨앗)`)은 농지 주인만, 캐릭터가 농지에서 20스터드 안일 때만 처리한다.
3. 상태별 동작:
   1. 갈지 않음 → 간다(`Till`).
   2. 갈았고 작물 없음 → 고른 씨앗 1개를 써서 심는다(`Plant`). 씨앗을 안 골랐거나 없으면 안내만 한다.
   3. 자라는 중, 물 안 줌 → 물을 준다(`Water`). 작물마다 한 번.
   4. 자라는 중, 물 줌 → 남은 시간 안내만 한다.
   5. 다 자람 → 수확물 1개를 인벤토리에 넣는다(`Harvest`). `Regrow`가 있으면 덤불은 남고 열매만 다시 자란다. 없으면 농지는 갈린 채 빈다.
4. 단계: 0 씨앗 → 1 새싹 → 2 성장 → 3 수확 가능. 단계는 저장하지 않고 시각으로 계산한다.
5. 서버는 1초마다 단계를 다시 계산해 바뀐 농지만 작물 모델을 바꾼다.

## Formulas

- 자란 정도 `p = min(1, (now − PlantedAt + boost) / Grow)`
  - `boost = 0.5 × clamp(now − WateredAt, 0, Grow / 2)` (물을 안 줬으면 0)
  - 변수: `now`, `PlantedAt`, `WateredAt` = 초(os.time); `Grow` = 작물별 초
  - 범위 0~1. 예) 순무 Grow 300, 심고 바로 물 → 225초 뒤 `p = (225 + 0.5×150)/300 = 1`
- 단계 `stage = p ≥ 1 ? 3 : floor(3p)`
- 남은 초(안내용): `need = (1 − p) × Grow`, `b = max(0, WateredAt + Grow/2 − now)`; `need ≤ 1.5b` 이면 `need / 1.5`, 아니면 `b + (need − 1.5b)`
- 다시 열림: 수확 시 `PlantedAt = now − (Grow − Regrow)` → 딸기(3600/1800)는 p = 0.5에서 다시 시작

| 작물 | Grow | Regrow | 씨앗 | 판매 | 시간당 수익(물 없음) |
|------|------|--------|------|------|------|
| 순무 | 300초 | — | 5 | 12 | 84 |
| 당근 | 900초 | — | 15 | 40 | 100 |
| 딸기 | 3600초 | 1800초 | 40 | 120 | 첫 수확 80, 이후 240 |

## Edge Cases

- 다른 사람 농지를 누름 → 아무 일도 없다(방문객 물주기는 Party & Visiting에서).
- 20스터드 밖에서 누름 → 무시.
- 씨앗 0개로 심기 → "씨앗이 없어요… 모모에게 살 수 있어요" 안내, 상태 그대로.
- 접속하지 않은 사이 다 자람 → 접속하면 바로 3단계로 보인다.
- 서버 시계가 뒤로 감(드묾) → `p`가 음수가 되지 않도록 단계 계산은 0 미만을 0단계로 취급한다(`floor` 결과가 0 이상).
- 알 수 없는 작물 Id가 저장돼 있음(데이터에서 작물을 지움) → 작물 없음으로 보고 농지만 갈린 상태로 둔다.

## Dependencies

- Island Generation: 마당 높이·원점(`IslandService.YardPoint`)
- Inventory & Economy: 씨앗 차감·수확물 추가
- Data Persistence: `profile.Tiles["1".."9"] = { Tilled, Crop, PlantedAt, WateredAt }`
- NPC Dialogue & Shops: 씨앗 판매·수확물 매입 (양방향: 상점이 `Crops`를 읽는다)
- Collection Dex: 수확 때 작물 기록 (Dex가 Farming을 듣는다)
- Party & Visiting: 파티원은 남의 밭에 물을 줄 수 있고, 주인이 "파티원 수확"을 켜면 거둘 수 있다. 작물은 주인 것(`party-visiting.md`)
- Action Animation, Interaction Feedback: `Feedback` 신호 Till/Plant/Water/Harvest를 받는다

## Acceptance Criteria

- [ ] 새 섬에서 농지 9칸이 마당 지면 위(지면 +0.25스터드)에 보인다.
- [ ] 같은 농지를 4번 누르면 갈기 → 심기 → 물주기 → 안내 순서로 바뀌고 씨앗이 1개 준다.
- [ ] 물 준 순무는 225초(±2초) 뒤 수확 가능해진다.
- [ ] 수확하면 인벤토리 순무 +1, 농지는 갈린 채 빈다. 딸기는 덤불이 남는다.
- [ ] 접속을 끊었다 다시 들어오면(저장 가능 환경) 농지 상태와 성장 시간이 이어진다.
- [ ] 다른 플레이어가 내 농지 요청을 보내도 아무것도 바뀌지 않는다.
