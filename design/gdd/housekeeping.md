# Housekeeping

> Category: Gameplay · Priority: MVP · Status: Implemented (session 5, 2026-10-23)

## Overview

섬을 꾸미고 돌보는 시스템. 가구를 사서 보관함에 두었다가 섬 어디에나 놓고(격자 스냅·90° 회전), 섬에 저절로 생기는 잡초·낙엽·돌멩이를 치운다. 놓은 가구와 정돈 상태로 섬의 "아늑함 점수"가 정해진다. 벌칙은 없다: 치우지 않아도 손해 대신 정돈 보너스만 빠진다(Pillar 1, 2).

### Research basis (2026-10-23)

| 출처 | 가져온 것 | 이 게임에 맞춘 점 |
|------|-----------|------------------|
| 동물의 숲 HHA ([Nookipedia](https://nookipedia.com/wiki/HHA), [mic.com](https://www.mic.com/p/animal-crossing-new-horizons-how-to-improve-your-happy-home-score-22796233)) | 정돈·배치·테마·세트 완성 보너스, 필수 가구(의자·탁자 등), 못 쓰는 물건 감점 | 감점 없이 보너스만. 세트는 3개(대규모 시리즈 대신) |
| 동물의 숲 섬 평가 ([Nintendo Life](https://nintendolife.com/guides/animal-crossing-new-horizons-how-to-get-a-5-star-island-rating), [TheGamer](https://www.thegamer.com/dataminer-discovers-how-to-get-5-star-island-rating-animal-crossing-new-horizons/)) | 경관 점수, 흩어진 물건·잡초가 많으면 최고 등급 불가 | 잡초가 남아 있으면 정돈 보너스만 빠진다 |
| Palia ([wiki](https://palia.wiki.gg/wiki/Customization), [Functional Furniture](https://palia.wiki.gg/wiki/Functional_Furniture)) | 격자/자유 배치, Q/E 회전, 보관함 목록, 기능성 가구, 배치 한도 | 격자 1스터드 + 90°, 한도 300(Roblox 성능), 앉기·불 켜기 |
| 코지 디자인 ([Game Developer](https://www.gamedeveloper.com/design/designing-for-coziness), [Lost Garden](https://lostgarden.com/2018/01/24/cozy-games/)) | 선택형(opt-in), 외적 보상이 의무감을 만들지 않게, 비교 불안 피하기 | 랭킹 없음, 집안일 알림 없음, 보상은 작게 |

## Detailed Rules

### 가구와 보관함
1. 가구는 목수 버니(마당 칸 (-2.5, 3.5))의 상점에서 산다. 산 가구는 보관함(`Items[가구Id]`)에 들어간다.
2. HUD "꾸미기" 버튼으로 꾸미기 모드를 켠다. 켜면 보관함 목록이 뜨고 농지 누르기는 꺼진다.
3. 목록에서 가구를 고르면 반투명 미리보기가 포인터 아래 지면에 붙어 다닌다(1스터드 격자). R 키 또는 회전 버튼 = 90° 회전. 누르면 놓는다. 터치는 누른 곳에 바로 놓는다.
4. 가구를 고르지 않은 채 놓인 가구를 누르면 보관함으로 돌아온다.
5. 서버 검사: 자기 섬, 섬 중심에서 `Extent` 안, 위치가 지면 근처(±12스터드), 보관함에 1개 이상, 섬당 배치 300개 이하.
6. 저장: `profile.Placed = { { Id, P = {x, y, z}(섬 원점 기준, 소수 1자리), R = 0|90|180|270 } }`.

### 기능성 가구
- 의자·벤치: "앉기" 프롬프트 → 앉는다(Seat).
- 등불: "켜기/끄기" 프롬프트 → 불빛 토글(저장하지 않음, 기본 켜짐).

### 집안일(청소)
1. 종류: 잡초(풀 무더기), 낙엽 더미, 돌멩이. 마당·농지·연못을 피한 섬 윗면에 무작위로 생긴다.
2. 접속 때: 섬을 비운 시간 30분마다 1개, 최대 6개(처음 들어온 섬은 3개).
3. 접속 중: 10분마다 1개, 섬에 최대 8개.
4. 누르면 치운다: +3코인. 9스터드 안 내 섬 집안일 앞에 서면 프롬프트 "치우기 · 잡초 · +3코인"(E · 게임패드 X · 모바일 버튼, 2026-10-24). 남은 수는 `profile.Chores`에 저장(위치는 매번 새로 고른다).

### 아늑함 점수
- 가구마다 점수, 세트를 모두 놓으면 세트 보너스, 필수 3종(의자 계열·탁자·불빛)이 있으면 보너스, 집안일 0개면 정돈 보너스.
- 등급 D/C/B/A/S를 HUD 코인 옆에 보인다. 랭킹·비교는 없다.

## Formulas

- `cozy = Σ cozy(가구) + 15 × (완성 세트 수) + 10 × [의자·탁자·불빛 모두 있음] + 10 × [집안일 0개]`
  - 같은 가구를 여러 개 놓아도 점수는 개당 더하되, 같은 Id는 3개까지만 센다(같은 물건 도배로 점수 올리기 방지, HHA "보관용 도배" 문제).
  - 예) 의자(5)+탁자(6)+등불(5)+화분(4) = 20, 필수 보너스 10, 정돈 10 → 40 = C
- 등급: D < 15 ≤ C < 45 ≤ B < 75 ≤ A < 110 ≤ S
- 오프라인 집안일 수 `min(6, floor((now − LastSeen) / 1800))`, 처음 섬(LastSeen = 0)은 3

| 가구 | Id | 세트 | 가격 | 아늑함 | 기능 |
|------|----|------|------|--------|------|
| 통나무 의자 | LogChair | 통나무 | 30 | 5 | 앉기 |
| 통나무 탁자 | LogTable | 통나무 | 45 | 6 | 탁자 |
| 통나무 벤치 | LogBench | 통나무 | 40 | 6 | 앉기 |
| 꽃 화분 | FlowerPot | 정원 | 15 | 4 | — |
| 하얀 울타리 | Fence | 정원 | 10 | 2 | — |
| 허수아비 | Scarecrow | 정원 | 60 | 8 | — |
| 등불 | Lantern | — | 35 | 5 | 불빛 토글 |
| 동그란 러그 | Rug | — | 25 | 4 | — |

## Edge Cases

- 섬 밖·허공·다른 사람 섬에 놓기 → 서버가 거절, "여기에는 놓을 수 없어요".
- 농지 위에 놓기 → 허용하지 않는다(농지 칸과 겹치면 거절).
- 300개 초과 → 거절, "섬에 더 놓을 자리가 없어요(300개)".
- 놓은 가구를 데이터에서 지움(가구 Id 삭제) → 불러올 때 건너뛰고 보관함에도 넣지 않는다, Output 경고.
- 저장된 위치가 섬 밖(섬 생성 규칙이 바뀜) → 불러올 때 보관함으로 돌려보낸다.
- 꾸미기 모드에서 대화창을 열면 → 꾸미기 모드를 끈다.
- 집안일을 동시에 두 번 누름 → 첫 요청만 보상, 두 번째는 대상이 이미 없다.

## Dependencies

- Island Generation: 원점·Extent·마당·LIFT / Data Persistence: `Placed`, `Chores`, `Items`
- Inventory & Economy: 가구 구매·청소 보상 / NPC Dialogue & Shops: 목수 버니와 상점
- Farming: 농지 칸과 겹치지 않기
- Collection Dex: 가구를 처음 얻으면 기록 (Dex가 Housekeeping을 듣는다)
- Action Animation: Place/Pickup/Clean 동작 / Interaction Feedback: 미리보기·먼지·보상 숫자

## Acceptance Criteria

- [ ] 목수 버니에게 의자를 사면 30코인이 줄고 꾸미기 목록에 의자 ×1이 보인다.
- [ ] 꾸미기 모드에서 지면을 누르면 의자가 1스터드 격자에 놓이고, R을 누른 뒤 놓으면 90° 돌아가 있다.
- [ ] 놓은 의자를 누르면 보관함으로 돌아온다. 농지 위·섬 밖에는 놓이지 않는다.
- [ ] 다시 접속하면(저장 가능 환경) 같은 상대 위치·방향에 가구가 있다.
- [ ] 잡초를 누르면 사라지고 +3코인. 접속 직후 비운 시간에 따라 0~6개가 있다.
- [ ] 의자·탁자·등불을 놓고 집안일이 0개면 아늑함이 16 + 10 + 10 = 36(C)으로 보인다.
- [ ] 의자에 "앉기"를 누르면 앉는다. 등불 "끄기"를 누르면 불빛이 꺼진다.
