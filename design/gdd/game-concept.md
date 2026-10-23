# Game Concept: Sky Island Farm (스카이섬 힐링 농장)

*Created: 2026-10-23*
*Status: Draft*

---

## Elevator Pitch

> 구름 위 나만의 하늘섬에서 작물을 키우고 집을 꾸미며, 친구 섬을 옆에 붙여 작은 하늘 마을을 만드는 느긋한 멀티플레이 농장 게임.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 농장·생활 시뮬레이션, 코지(cozy) 게임 |
| **Platform** | Roblox (PC·모바일 동시, 터치 우선) |
| **Target Audience** | 9~16세 Roblox 캐주얼 유저, 2~6명 친구 그룹 (가정) |
| **Player Count** | 서버당 최대 6명, 섬은 1인 1개, 파티·섬 편입으로 함께 |
| **Session Length** | 15~20분 (수확·재심기 5분 + 낚시·꾸미기·방문) |
| **Monetization** | 미정 (게임패스·개발자 상품 후보, 게임 진행에는 무관) |
| **Estimated Scope** | Medium (3~9개월) |
| **Comparable Titles** | 동물의 숲, 스타듀 밸리, Palia, Roblox의 Islands·Grow a Garden |

---

## Core Fantasy

나만의 작은 하늘섬이 있다. 세상에 하나뿐인 모양이고, 내가 돌보는 만큼 포근해진다. 아무것도 나를 서두르게 하지 않고, 친구가 놀러 오면 섬이 마을이 된다.

---

## Unique Hook

동물의 숲처럼 섬을 가꾸는데, **섬 모양이 시드로 만들어지고 친구 섬을 내 섬 옆에 실제로 붙일 수 있다**(섬 편입).

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Submission** (편안함) | 1 | 실패·사망·시듦 없음, 실제 시간 성장, 잔잔한 소리 |
| **Expression** (나다움) | 2 | 시드 섬 모양 + 가구 배치·테마, 섬 이름 |
| **Fellowship** (함께) | 3 | 방문·서로 물주기·섬 편입, NPC 사이 잡담 |
| **Discovery** (발견) | 4 | 바이옴 8종, 도감, 희귀 작물·물고기 |
| **Sensation** (감각) | 5 | 파스텔 색, 수확 튀어 오름·반짝임, 작은 효과음 |
| **Fantasy** | 6 | 하늘섬 주인, NPC 이웃 |
| **Challenge** | N/A | 의도적으로 낮게 (낚시 미니게임만 약간) |
| **Narrative** | N/A | 줄거리 없음, NPC 대사와 관계로 대신 |

### Key Dynamics

- 자기 전에 오래 걸리는 작물을 심고, 다음 접속 때 한꺼번에 거둔다.
- 친구 섬에 들러 물을 주고 가는 것이 인사처럼 된다.
- 도감 빈칸을 채우려고 바이옴이 다른 친구 섬을 찾아간다.
- 같은 세트 가구를 모아 테마를 맞춘다.

### Core Mechanics

1. 시드 하늘섬 생성 (마인크래프트식 절차 생성, 바이옴 8종)
2. 실제 시간 농사 (갈기 → 심기 → 물주기 → 수확, 시듦 없음)
3. 섬 NPC와 대화·상점·의뢰 (데이터 그래프 대화)
4. 하우스키핑 (가구 배치·청소·아늑함 점수)
5. 도감 (작물·가구·바이옴, 이후 물고기)

---

## Player Motivation Profile

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | 무엇을 심고 어떻게 꾸밀지 전부 플레이어 선택, 할당량 없음 | Core |
| **Competence** | 섬 레벨·해금, 도감 완성, 아늑함 등급 | Supporting |
| **Relatedness** | 방문·물주기·섬 편입, NPC 호감도 | Core |

### Flow State Design

도전이 아니라 "작은 일의 연속"으로 몰입을 만든다. 행동 하나에 1초 안의 피드백(소리·튀어 오름·숫자)이 붙고, 다음 할 일이 늘 눈에 보인다(반짝이는 다 자란 작물, 잡초).

---

## Core Loop

### Moment-to-Moment (30 seconds)
농지를 누른다 → 상태에 맞는 동작(갈기·심기·물주기·수확)과 피드백 → 다음 농지.

### Short-Term (5-15 minutes)
다 자란 작물 수확 → 모모에게 판매 → 씨앗·가구 구매 → 다시 심기 → 기다리는 동안 꾸미기·청소·방문.

### Session-Level (30-120 minutes)
의뢰 처리, 테마 완성, 친구 섬 방문으로 도감 채우기.

### Long-Term Progression
섬 레벨 1~20: 작물·NPC·섬 확장·농지 확장 해금. 도감 완성과 아늑함 S등급.

### Retention Hooks
- 섬을 비운 동안 자란 작물 (돌아올 이유)
- 그사이 생긴 잡초·낙엽 (작은 할 일, 벌칙 아님)
- 도감 빈칸과 다음 해금 미리보기

---

## Game Pillars

### Pillar 1: 서두르지 않아도 되는 섬
실패·벌칙·마감이 없다. 작물은 시들지 않고, 청소를 미뤄도 손해 대신 보너스만 놓친다.
*판단 기준*: "이 기능이 플레이어를 조급하게 만드는가?" 그렇다면 빼거나 바꾼다.

### Pillar 2: 세상에 하나뿐인 내 섬
섬 모양은 시드로, 섬의 분위기는 플레이어의 배치로 정해진다.
*판단 기준*: "두 플레이어의 섬이 이 기능 때문에 더 달라지는가?"

### Pillar 3: 함께라서 따뜻한 하늘
다른 사람의 섬을 돕는 행동(물주기·선물)은 늘 보상받고, 해치는 행동은 아예 없다.
*판단 기준*: "이 기능이 다른 플레이어를 반갑게 만드는가?"

### Anti-Pillars (What This Game Is NOT)
- 전투·사망·몬스터 없음
- 경쟁 랭킹·PvP 없음 (좋아요 수만 보여 준다)
- 시간 압박·작물 시듦·유지비 없음
- 돈으로 진행을 사는 구조 없음

---

## Inspiration and References

| Reference | What we take | What we avoid |
| ---- | ---- | ---- |
| 동물의 숲 | HHA 평가(테마·세트·정돈), 섬 평가(경관·잡초), 무이자 집 대출 | 실시간 대기 강요(너구리 상점 하루 대기) |
| 스타듀 밸리 | 작물 성장 단계, 계절 대신 바이옴 특산 | 작물 시듦, 체력 소모 |
| Palia | 격자/자유 배치, 보관함 목록, 기능성 가구 | 배치 한도 3,000 (Roblox 성능상 300) |
| 마인크래프트 | 기후 → 바이옴 표, 노이즈 지형, 동굴 깎기 | 블록 단위 편집 |

---

## Target Player Profile

친구와 같은 서버에서 수다를 떨며 손을 가볍게 움직이고 싶은 9~16세. 짧게(15분) 자주 들어오고, 모바일 비중이 높다. 꾸미기 결과를 친구에게 보여 주는 것을 좋아한다.

---

## Technical Considerations

- Roblox Luau, 서버 권한(클라이언트는 요청만). 상세: `docs/engine-reference/roblox/VERSION.md`.
- 섬은 저장하지 않고 시드로 다시 짓는다. 저장은 시드 + 변경분(농지·배치물)뿐.
- DataStore 세션 잠금·자동 저장, 배치 위치는 섬 원점 기준.
- 모바일: 탭 하나로 동작하는 스마트 상호작용, 큰 버튼.

---

## Risks and Open Questions

### Design Risks
- 행동 종류가 적어 15분 루프가 단조로울 수 있다 → 1세션 관문(혼자 15분 재미) 플레이테스트.

### Technical Risks
- Studio MCP는 저장을 못 하고, GPU 크래시로 미저장 작업을 잃을 수 있다(2026-10-23 발생).
- Terrain 연합 섬 4개 × 서버 6슬롯의 메모리.

### Market Risks
- Roblox 농장 장르는 경쟁이 많다 → 시드 섬·섬 편입으로 차별화.

### Scope Risks
- 섬 편입·파티는 서버 이동이 얽혀 커질 수 있다 → 마지막 단계로 둔다.

### Open Questions
- 기획서 미결 사항 절을 따른다(서버 인원, 오프라인 연합 섬 표시, 시드 공유, 수익화).

---

## MVP Definition

혼자 15분: 시드 섬에서 태어나 모모와 대화하고, 순무·당근·딸기를 키워 팔고, 가구 몇 개를 놓고 잡초를 치우며, 도감 첫 칸들을 채운다. 데이터는 다시 들어와도 남는다.

### Scope Tiers
1. MVP: 위 내용 (농사·대화·도감·기본 꾸미기·청소)
2. +소셜: 파티·방문·서로 물주기
3. +낚시·요리
4. +섬 편입·연합

---

## Next Steps

`/map-systems` → 시스템별 `/design-system` → 2~5세션 구현(애니메이션 · 피드백 VFX · 도감 · 하우스키핑).
