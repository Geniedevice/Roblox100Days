# NPC Dialogue & Shops

> Category: Narrative · Priority: MVP · Status: Implemented for 정원사 모모 (`NpcService.lua`, `Dialogues.lua`, `Shared/Lines.lua`, client `DialogueClient`); 목수 버니 added with Housekeeping

## Overview

섬마다 NPC가 마당에 서 있고, 다가가 "대화하기"를 누르면 대화창이 열린다. 대화는 데이터 그래프(라우터 → `dialogue-systems` 스킬 방식)이고 서버가 한 노드씩 진행한다. NPC마다 상점이 있어 씨앗·가구를 사고 작물을 판다.

## Detailed Rules

1. 노드 = 대사 ID + (선택지 | 다음 | 끝). `Set`은 그 NPC의 대화 변수에 쓰고, `Action`은 노드에 들어올 때나 선택지를 고를 때 실행한다.
2. 클라이언트는 문장·선택지 글만 받고 고른 번호만 보낸다. 0 = 닫기.
3. 선택지 `If`는 대화 변수(저장 변수 + CropCount, Sold)를 받는 함수다. 조건이 거짓인 선택지는 보이지 않는다.
4. 다시 올 수 있는 노드에는 `Set`/`Action`을 두지 않는다(두 번 적용 방지). 첫 만남 선물은 마지막 소개 노드에서 `Met = true`와 같이 준다.
5. 대화·상점은 NPC에서 16스터드보다 멀어지면 닫힌다(서버·클라이언트 둘 다 확인).
6. 상점 구매: 같은 상점을 가진 NPC가 16스터드 안에 있어야 하고, 코인이 충분해야 한다. 1회 클릭 = 1개.
7. 판매: "작물 팔기"는 가진 작물을 전부 판다. 선택지는 작물이 1개 이상일 때만 보인다.
8. 서버 시작 시 그래프를 검사해 없는 노드·대사·행동, 끝나지 않는 노드를 Output에 경고한다.
9. 대사 문자열은 `Lines.ko`에 ID로 둔다. 없는 ID는 `<MISSING:ID>`로 보인다. 조사는 `Lines.Josa`로 붙인다.

## Formulas

- 판매액 = Σ(작물 개수 × SellPrice) — 값은 Farming 표.

## Edge Cases

- 대화 중 섬 주인이 나가 NPC가 사라짐 → 다음 선택 때 범위 밖으로 보고 닫는다.
- 클라이언트가 보여 준 적 없는 번호를 보냄 → 닫는다.
- 작물 0개에 판매 요청(선택지가 안 보여야 하지만) → 0코인, 대사 "0코인이야"가 나오지 않도록 선택지 자체를 숨긴다.
- 코인이 모자람 → "코인이 모자라요", 아무것도 바뀌지 않는다.
- 소개 도중 나감 → `Met`이 아직 거짓이라 다음에 소개부터 다시, 선물은 한 번만.

## Dependencies

- Inventory & Economy (코인·아이템), Data Persistence (`profile.Npc[Id]`), Island Generation (NPC 자리 = 마당 칸)
- Farming: 씨앗 상점이 `Crops`를 읽는다 / Housekeeping: 목수 상점이 `Furniture`를 읽는다
- Action Animation: 대화 시작 때 NPC가 플레이어를 보고 손을 흔든다 / Interaction Feedback: Sell, Gift 신호
- Party & Visiting: 친구 섬 루미는 밭 열기·섬 넓히기를 보이지 않고(`v.Home`), "이 섬의 명물"은 그 섬 것을 말한다

## Acceptance Criteria

- [ ] 처음 대화하면 소개 3줄 뒤 순무 씨앗 5개를 받고, 두 번째 대화부터 인사로 시작한다.
- [ ] 작물이 없으면 "작물 팔기"가 보이지 않는다. 순무 2개를 팔면 24코인이 늘고 "24코인이야!"가 나온다.
- [ ] 상점에서 당근 씨앗을 사면 15코인이 줄고 씨앗 바에 ×1이 뜬다. 코인 14에서는 실패 안내가 뜬다.
- [ ] 17스터드 이상 멀어지면 대화창과 상점 창이 닫힌다.
- [ ] Dialogues에 없는 노드를 넣으면 서버 시작 때 Output에 경고가 한 줄 나온다.
