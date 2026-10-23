# Interaction Feedback (VFX · SFX · 알림)

> Category: UI · Priority: Vertical Slice · Status: Implemented (session 3, 2026-10-23)

## Overview

모든 행동에 1초 안의 피드백을 준다: 누를 수 있는 것에 테두리, 행동마다 입자·소리, 얻은 것은 떠오르는 숫자, 안내는 토스트, 새 도감은 배너. 피드백이 게임의 "손맛"이자 Flow State Design(게임 컨셉)의 약속이다. 소리는 Roblox 내장 사운드만 쓴다(업로드 불필요, 목록은 engine reference).

## Detailed Rules

1. 가리키기: 마우스가 누를 수 있는 대상(자기 농지, 집안일, 꾸미기 모드의 놓은 가구) 위에 있으면 하얀 테두리 Highlight 하나를 붙인다. 터치 기기는 생략.
2. 신호별 피드백(`Feedback` kind):

| kind | 입자 | 소리 | 떠오르는 글자(행동한 사람만) |
|------|------|------|------|
| Till | 흙 조각 12개, 갈색 | action_jump_land | — |
| Plant | 초록 반짝 8개 | Kerplunk | — |
| Water | 물방울 16개, 파랑, 아래로 | impact_water(짧게) | — |
| Harvest | 노랑 반짝 14개 + 작물 색 | snap | "+1 순무" |
| Sell | 노랑 동전 20개 | electronicpingshort | "+24 코인" |
| Gift | 분홍 반짝 12개 | short spring sound | "순무 씨앗 ×5" |
| Clean | 풀잎 10개 | splat | "+3 코인" |
| Place, Pickup | 먼지 10개, 회색 | short spring sound | — |
| DexNew | — | victory | 화면 위 배너 "새 도감! 작물 · 순무" 2.5초 |
| Toast | — | clickfast | 화면 위(코인 아래) 안내 2.5초 — 아래쪽은 대화창·씨앗 바와 겹친다 |

3. 다 자란 작물(3단계)은 작은 반짝임을 계속 뿜는다(초당 2개) — 할 일이 눈에 보이게.
4. 소리는 위치 소리(그 자리에서 들림), 배너·토스트·UI 버튼 소리는 2D.
5. 다른 사람 행동의 입자·소리는 60스터드 안에서만 보이고 들린다.
6. 떠오르는 글자: 위치에서 1.2초 동안 3스터드 위로 떠오르며 사라진다.
7. UI 버튼을 누르면 짧은 클릭음(button).

## Formulas

- 거리 감쇠: 위치 소리 `RollOffMaxDistance = 60`, `RollOffMinDistance = 8`
- 떠오름 `y(t) = 3 × easeOutQuad(t / 1.2)`, 투명도 `t / 1.2`

## Edge Cases

- 같은 프레임에 여러 신호 → 각각 그린다(입자 수가 많아도 Debris로 2초 뒤 정리).
- Highlight 대상이 사라짐 → 다음 프레임에 테두리를 뗀다.
- 사운드가 로드되지 않음(pageturn·swoosh는 실제로 안 됨) → 표의 사운드만 쓴다, 실패해도 조용히 넘어간다.
- 토스트가 연달아 옴 → 마지막 것만 보인다(앞의 것을 바로 바꾼다).

## Dependencies

- Farming, NPC Dialogue & Shops, Housekeeping, Collection Dex: 신호를 낸다
- Action Animation: 같은 신호, 독립 구현
- HUD: 버튼 클릭음

## Acceptance Criteria

- [ ] 마우스를 내 농지에 올리면 테두리가 생기고 벗어나면 사라진다.
- [ ] 물을 주면 물방울이 튀고 물소리가 난다. 60스터드 밖 친구의 행동은 들리지 않는다.
- [ ] 수확하면 "+1 순무"가 떠오르며 사라진다(행동한 사람 화면에만).
- [ ] 다 자란 작물이 반짝여서 멀리서도 보인다.
- [ ] 새 도감 배너가 2.5초 동안 보인다.
- [ ] "잘 자라는 중" 안내가 화면 위 토스트로 뜬다(이전엔 신호만 오고 아무것도 보이지 않았다).
