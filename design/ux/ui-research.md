# UI Research & Design Direction (UI 조사와 디자인 방향)

> **Status**: In Design
> **Author**: ux-designer (autonomous run, 2026-10-23)
> **Last Updated**: 2026-10-23
> **Game**: Sky Island Farm (스카이섬 힐링 농장)
> **Feeds**: `design/ux/hud.md`, `design/ux/interaction-patterns.md`
> **Related GDDs**: `design/gdd/interaction-feedback.md`, `design/gdd/action-animation.md`, `design/gdd/collection-dex.md`, `design/gdd/housekeeping.md`, `design/gdd/farming.md`, `design/gdd/npc-dialogue.md`

사용자 불만(2026-10-23): "UI가 보기 안 좋다. 아이템에 아이콘·로고 이미지가 없다. 여러 게임 UI를 조사해 디자인을 발전시키고, 모든 행동에 확실한 피드백을 과장해서 넣어라." 참고 자료로 '7 HIT COMBO' 손맛 요소(번쩍임, 히트 스톱, 넉백, 카메라 흔들림, 지연 체력바, 타격 이펙트, 사운드)를 받았다.

**조사 방법 메모**: 이번 세션에서는 WebFetch 도구를 쓸 수 없었다. 아래 링크는 모두 WebSearch가 돌려준 페이지이고, 근거로 쓴 것은 검색 결과에 나온 발췌 내용이다(전체 페이지를 열어 읽지 않았다). 발췌로 확인하지 못한 내용, 즉 내 기존 지식에서 나온 내용은 **(일반 지식)**으로 표시했다. 플레이테스트 데이터는 아직 없다.

---

## 0. 지금 UI 점검 (src/StarterPlayer/StarterPlayerScripts, 2026-10-23)

| # | 문제 | 어디서 | 왜 문제인가 |
|---|------|--------|-------------|
| 1 | 아이템을 **단색 동그라미**로 보여 준다 | `FarmClient` 씨앗 칸 30px 원, `DexClient` 카드 40px 원, `DecorClient` 26px 원(`Parts[1].Color`) | 의자·탁자·벤치가 모두 같은 갈색 원이 된다. 사용자가 짚은 "아이콘이 없다"가 바로 이것이다. |
| 2 | 씨앗 바는 **왼쪽 아래**, 도감·꾸미기는 **오른쪽 아래**에 있다 | `bar.Position (0,12,1,-12)`, 버튼 `(1,-12,1,-12)`, `(1,-104,1,-12)` | Roblox 문서에 따르면 휴대폰에서는 기본 조작(조이스틱·점프)이 이 두 모서리를 차지한다([Roblox cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design)). 우선해야 할 기기에서 겹친다. |
| 3 | 대비가 부족하다 | 흰 글자 + LEAF(120,180,95) = **2.47:1**(끝내기 버튼, 선택한 탭). MUTED(140,120,100) + CREAM = **3.99:1**. 도감 설명은 11px, 꾸미기 안내는 13px | WCAG AA 기준(4.5:1)에 못 미치고, 글자도 휴대폰에서 읽기에 너무 작다. |
| 4 | 글꼴이 **Gotham / GothamBold**다 | 모든 클라이언트 UI | 예전 Font datatype 문서에 Gotham·Arial을 곧 없앤다는 안내가 있다([developer.roblox.com Font](https://developer.roblox.com/api-reference/datatype/Font)). |
| 5 | 테두리와 그림자가 없다 | 크림색 사각형만 쓴다 | 밝은 하늘 배경에서 패널과 배경이 섞인다. Roblox 인기 게임에서 흔한 두꺼운 테두리·그림자 문법과도 거리가 멀다. |
| 6 | 피드백 타이밍이 맞지 않는다 | `FeedbackFx`는 신호가 오는 즉시(t=0) 입자를 뿜는데, `ActionAnimator`의 괭이는 0.32초에 땅을 찍는다 | 효과가 먼저 터지고 동작이 뒤따라온다. 히트 스톱도, 카메라 반응도, HUD 반응(코인 글자가 그냥 바뀜)도 없다. 토스트는 움직임 없이 나타났다가 사라진다. |
| 7 | 코인을 "코인 0"으로 쓴다 | `coinText` | 낱말이 자리를 차지하고 숫자가 묻힌다. 코인 아이콘과 숫자로 충분하다. |

---

## 1. 게임별 조사

### 1.1 Animal Crossing: New Horizons (동물의 숲)

**잘하는 것**
- NookPhone은 **메뉴 허브 하나**다. 앱을 진행에 따라 하나씩 연다([iMore](https://imore.com/animal-crossing-new-horizons-what-nookphone-and-what-it)). 버튼 하나 뒤에 큰 둥근 앱 아이콘 격자가 있는 구조다(일반 지식).
- 주머니는 20칸에서 시작하고 재료는 저절로 쌓인다. 별도 도구 메뉴가 없는 대신 퀵 메뉴(빠른 선택)가 그 역할을 한다([jvgs 2019 reveal impressions](https://www.jvgs.net/blog/2019/06/11/)).
- DIY 작업대 목록은 아는 레시피를 보여 주고, 재료가 있으면 그림 위에 'craftable' 표시를 붙인다([Twinfinite](https://twinfinite.net/guides/animal-crossing-new-horizons-craft-items-furniture/), [Nookipedia DIY workbench](https://nookipedia.com/wiki/DIY_workbench)).
- UI 글꼴(Seurat 계열로 알려짐)부터 말풍선까지 모두 둥글다([Fonts In Use](https://fontsinuse.com/uses/51354/animal-crossing-new-horizons)). 글자 끝이 둥글고 자간이 넓다([Mechanics of Magic](https://mechanicsofmagic.com/2023/04/21/short-exercise-visual-design-of-games-32/)).
- 작은 소리 하나하나가 감정을 설계한다. 걷는 소리가 바닥과 신발에 따라 달라지고([WhatCulture](https://whatculture.com/gaming/animal-crossing-10-wonderful-tiny-details-youve-probably-missed)), 아이템을 들어 보여 주는 효과음이 성취감을 준다([UAL case study](https://yjjoya5250.myblog.arts.ac.uk/?p=437)). "UI는 플레이어가 직접 보고 듣는 모든 것"이라는 관점도 있다([uxdesign.cc](https://uxdesign.cc/animal-crossing-delight-by-design-e2c0a1a4d462)).
- 아이템을 얻으면 머리 위로 들어 보이는 동작과 짧은 팡파르가 함께 나온다(일반 지식).

**가져올 것**: 버튼 하나에 허브를 둔다(도감 버튼 = 도감 허브). 모든 모서리를 둥글게 하고 자간을 넓힌다. "얻었다"는 순간은 짧은 정지와 들어 보이기 연출로 만든다(→ 수확 히트 스톱 90ms, 새 도감 120ms 스탬프). 참고로 동물의 숲은 가구를 주머니에서 나뭇잎 아이콘으로 보여 주는데(일반 지식), 우리는 **실제 3D 모델**을 보여 줘서 이 점을 앞선다.

### 1.2 Stardew Valley (스타듀 밸리)

**잘하는 것**
- 인벤토리는 12칸짜리 줄로 되어 있고, 고를 수 있는 한 줄이 핫바가 된다. 숫자 키나 휠로 칸을 고른다([Stardew Wiki Inventory](https://stardewvalleywiki.com/Inventory)).
- 화면 왼쪽 아래에 "21 Wood"처럼 아이콘과 개수가 붙은 작은 알림이 뜬다([Stardew forums](https://forums.stardewvalley.net/threads/messages-at-bottom-left-of-screen-on-ipad.12174/latest)). 연속으로 주우면 숫자가 합쳐진다(일반 지식). 빨리 사라져서 놓치기 쉽다는 불만도 있다.
- 꾸러미에 필요한 아이템은 인벤토리에서 아이콘이 은은하게 맥동한다([Destructoid](https://www.destructoid.com/stardew-valley-tip-community-center-bundle-items/)).
- 줍기 알림이 잘못된 아이템이나 개수를 보여 주는 버그가 보고됐다([Stardew forums](https://forums.stardewvalley.net/threads/pop-up-issue-on-picking-up-furniture-after-picking-up-equipment.31404/latest)). 알림을 인벤토리 변화에서 직접 만들어야 한다는 교훈이다.

**가져올 것**: PC에서는 숫자 키 1~9로 씨앗을 고른다. 같은 종류의 획득은 하나의 떠오르는 글자로 합친다("+1 순무"가 "+3 순무"로). 새 도감 항목처럼 중요한 칸은 맥동시킨다. 알림 숫자는 서버가 바꾼 속성(`Item_*`, `Coins`)의 차이로 계산하고, 신호 문구만 믿지 않는다.

### 1.3 Palia

**잘하는 것**
- 도구는 툴 휠에 두고, 인벤토리 탭에서 끌어 놓아 휠 자리를 바꾼다. 백팩은 자루 아이콘으로 표시한다([Palia Wiki Player Menu](https://palia.wiki.gg/wiki/Player_Menu)).
- 리뷰들은 메뉴와 지도가 "큰 글자, 단순한 이동"으로 잘 만들어졌다고 평가한다. 반면 제작·인벤토리·꾸미기 메뉴는 붐벼서 스틱으로 스크롤하기 지루하다고 지적한다([Gaming Nexus](https://www.gamingnexus.com/Article/16224/Palia/), [Nintendo Life](https://www.nintendolife.com/reviews/switch-eshop/palia), [The Outer Haven](https://www.theouterhaven.net/palia-review-xsx-a-cozy-mmo-with-room-to-grow/), [Playnews](https://www.playnews.gg/pl/aktualizacje/palia-na-switch-2-co-naprawde-zmienia-dedykowana-edycja)). 빠른 이동 UI를 고쳐 보자는 팬 UX 사례도 있다([Uxcel](https://app.uxcel.com/showcase/palia-fast-travel-ui-redesign-concept-342)).

**가져올 것**: 글자를 크게 하고 탭은 3개 이하로 둔다. 꾸미기 트레이는 **한 줄 가로 스크롤 + 큰 칸**으로 만들어 깊게 들어가는 메뉴를 피한다. 아이콘은 물건 자체를 보여 준다(자루 = 씨앗 주머니 3D 모델).

### 1.4 Minecraft (마인크래프트)

**잘하는 것**
- 아래 가운데 9칸 핫바를 두고, 고른 칸은 두꺼운 틀로 표시한다. 개수는 칸 오른쪽 아래에 그림자 진 흰 숫자로 쓴다(일반 지식).
- 줍기 애니메이션은 **칸의 개수가 늘어날 때** 그 칸을 튕겨 올린다. 그래서 단축키로 칸을 바꿔도 튀는 버그(MC-91883)가 있다([Mojang MC-91883](https://bugs-legacy.mojang.com/browse/MC-91883)). 모드들은 여기서 더 나아가 주운 아이템이 칸까지 날아가거나 칸이 톡 튀어나오게 하고, 새로 발견한 희귀 아이템에 은은한 광택을 준다([Motion Craft](https://www.curseforge.com/minecraft/mc-mods/motion-craft), [Tiny Pickup Animation](https://modrinth.com/mod/tiny-pickup-animation)). 애니메이션 시간을 0으로 만들어 끄는 설정도 있다([NeverEnoughAnimation](https://moddex.gg/mod/neverenoughanimation)).
- 베드록 모바일에서 아이템 설명이 핫바를 가리는 문제가 보고됐다([Mojang MCPE-36719](https://bugs-legacy.mojang.com/browse/MCPE-36719)). 핫바 툴팁은 이름만 보여 달라는 요청도 있다([Minecraft Feedback](https://feedback.minecraft.net/hc/en-us/community/posts/47872310615821/comments/47930369213709)).

**가져올 것**: 개수는 칸 오른쪽 아래에 쓴다. 칸은 **개수가 늘어날 때만** 튀게 하고, 고르기만 할 때는 튀지 않는다. 날아오는 아이템을 칸이 받아 준다(→ Item Fly-to-HUD). 칸 이름은 칸 위에 잠깐 띄우되 핫바를 가리지 않는다. 모든 연출은 시간을 0으로 만들 수 있게 한다(→ 움직임 줄이기).

### 1.5 Grow a Garden (Roblox)

**잘하는 것**
- 화면 위쪽 "Seeds" 버튼을 누르면 씨앗 상점(NPC Sam)으로 바로 이동한다. 상점을 열면 재입고까지 남은 시간이 보인다([Deltia's Gaming](https://deltiasgaming.com/?p=207402), [Sportskeeda](https://www.sportskeeda.com/roblox-news/all-merchants-in-grow-a-garden)).
- 다 자라면 E로 수확한다. 판매는 "전부 팔기"와 골라 팔기 중에서 고른다([Noping guide](https://noping.com/blog/grow-a-garden-gameplay-guide), [Deltia's beginners](https://deltiasgaming.com/?p=201040)).
- 상점 GUI 만드는 법이 DevForum 튜토리얼 시리즈로 공개돼 있다([DevForum](https://devforum.roblox.com/t/how-to-make-roblox-grow-a-garden-game-tutorial-series/3769116)).

**가져올 것**: 큰 글자 바로가기 버튼과 "전부 팔기"를 큰 보상 순간(잭팟)으로 만든다(→ Sell 패턴). **가져오지 않을 것**: 재고 카운트다운과 품절 압박. 서두르게 만드는 장치는 Pillar 1(서두르지 않아도 되는 섬)에 어긋난다.

### 1.6 Adopt Me! (Roblox)

**잘하는 것**: 백팩 업데이트로 같은 아이템을 하나로 쌓고, 즐겨찾기 분류를 추가하고, 툴팁을 개선했다([DualShockers](https://www.dualshockers.com/adopt-me-backpack-update-whats-new-patch-notes/)). Roblox 기본 백팩 UI는 낡은 패턴이라 개발자들이 직접 만든다([DevForum](https://devforum.roblox.com/t/roblox-needs-to-add-customization-to-the-backpack-gui/3932231)).

**가져올 것**: 꾸미기 트레이와 씨앗 칸은 같은 아이템을 **×n으로 쌓아** 한 칸에 둔다. Roblox 기본 백팩은 쓰지 않고(이미 쓰지 않는다) 직접 만든 칸을 쓴다. 즐겨찾기는 가구가 20종을 넘으면 추가한다.

### 1.7 Bee Swarm Simulator (Roblox)

**잘하는 것**
- 지금 걸린 버프 아이콘이 화면 위에 줄지어 있고, 마우스를 올리면 효과와 남은 시간이 나온다. 시스템 페이지에서 **꽃가루 숫자 표시(Pollen Text)와 숫자 줄임(Abbreviate)을 켜고 끌 수 있다**([Bee Swarm Wiki System Page](https://bee-swarm-simulator.fandom.com/wiki/System_Page)).
- 가방이 차면 "Pollen container full" 메시지로 벌집에 가라고 알려 준다. 가방 용량은 200에서 수십만까지 커진다([Bee Swarm Wiki Bags](https://bee-swarm-simulator.fandom.com/wiki/Bags), [TechWiser](https://techwiser.com/bee-swarm-simulator-stats-mechanics-guide/)).

**가져올 것**: 떠오르는 숫자는 **설정에서 끌 수 있게** 한다(손맛을 과장하는 만큼 탈출구가 필요하다). 큰 수는 줄여 쓴다(12,400 → 12.4K, 10,000 이상부터). 차오르는 막대(가방)는 아늑함 막대에 쓴다.

### 1.8 Pet Simulator 99와 Roblox 시뮬레이터 장르

**잘하는 것**: 깨지는 물건에서 코인·다이아가 튀어나오고 모은다(일반 지식, 경제 구조는 [itemlevel](https://itemlevel.net/pet-simulator-99-diamond-farm-guide/) 참고). 시뮬레이터 장르에는 "코인·보석이 UI로 직접 날아 들어가는" 연출이 표준 상품으로 팔릴 만큼 흔하다([BuiltByBit Currency Popup](https://builtbybit.com/resources/currency-popup-ui-system.108494/)). 희귀 결과에는 파티클과 색종이를 터뜨린다([BuiltByBit Pet Sim X kit](https://builtbybit.com/resources/pet-simulator-x-fully-scripted.108241/)).

**가져올 것**: 코인과 작물이 HUD 카운터로 날아가는 연출을 쓰되 **개수에 상한**을 둔다(판매 한 번에 코인 아이콘 최대 14개). 색종이는 새 도감과 콤보 마일스톤에만 터뜨린다. 매번 터지면 무뎌진다.

### 1.9 Roblox UI 문법 (인기 게임 공통)

- 인기 게임 스타일의 기본은 UIStroke와 UIGradient다. 한 오브젝트에 UIStroke를 하나만 쓸 수 있어서, 이중 테두리는 뒤에 프레임을 하나 더 겹쳐 흉내 낸다([DevForum How to recreate such UI style](https://devforum.roblox.com/t/how-to-recreate-such-ui-style/1943553)).
- 둥근 모서리, 넉넉한 여백, 또렷한 UIStroke 테두리, 테두리가 맥동하는 hover가 흔한 구성이다([Roblox Button UI Effects](https://maxuno.itch.io/roblox-button-ui-effects), [BuiltByBit Modern Cartoon Simulator UI](https://builtbybit.com/resources/modern-cartoon-simulator-ui.109159/)).
- 휴대폰에서는 기본 조작이 왼쪽 아래와 오른쪽 아래를 차지한다. 자주 누르는 버튼은 점프 버튼 근처에 두고, 위치는 `TouchGui > TouchControlFrame > JumpButton`의 AbsolutePosition·AbsoluteSize를 기준으로 계산한다([Roblox cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design), [Roblox position and size](https://create.roblox.com/docs/ui/position-and-size)). 작은 화면의 점프 버튼은 약 70×70, 위치는 약 {1,-95},{1,-90}이라는 보고가 있지만 확인된 공식 값은 아니다([DevForum jump button](https://devforum.roblox.com/t/figuring-out-where-the-jump-button-placement/3915124)).
- 터치 대상은 최소 44×44(iOS 44pt, Android 48dp)로 잡는다([rolearn.dev](https://rolearn.dev/insights/mobile-first-design-roblox-engagement), [UXPin](https://www.uxpin.com/studio/?p=58041)).
- ViewportFrame 조명은 `Ambient`(기본 회색 200)와 `LightColor`(기본 140)로 정한다. 그림자와 후처리는 그리지 않는다. `ImageColor3`로 렌더 결과에 색을 입힌다([Roblox ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame.md), [Viewport frames guide](https://create.roblox.com/docs/ui/viewport-frames.md)). Ambient와 LightColor를 한 색으로 맞추면 음영 없는 단색 실루엣이 된다([DevForum custom outlines](https://devforum.roblox.com/t/custom-object-outlines/3855436)).
- `Enum.Font.FredokaOne`은 Font enum에 있다([Font enum](https://create.roblox.com/docs/ko-kr/reference/engine/enums/Font)). Builder Sans는 `rbxasset://fonts/families/BuilderSans.json`이다([Font datatype](https://create.roblox.com/docs/reference/engine/datatypes/Font.md)).

---

## 2. 손맛(game feel) 자료

| 자료 | 핵심 | 우리에게 주는 숫자·규칙 |
|------|------|------------------------|
| "Juice it or lose it" (Jonasson & Purho, 2012) — [Game Developer](https://gamedeveloper.com/design/video-is-your-game-juicy-enough-), [RPG Playground](https://rpgplayground.com/research-making-a-juicy-game/), [GameDiscover](https://newsletter.gamediscover.co/p/has-your-game-got-juice-and-more) | 흔들리고, 튀고, 통통 튀고, 귀여운 소리를 내는 것. 적은 입력에 큰 출력. 트윈·이징, 찌그러짐과 늘어남(squash & stretch), 색, 소리, 아껴 쓰는 파티클, 화면 흔들림 | 모든 등장은 Back Out(넘쳤다 돌아오기). 크기 펀치는 1 → 1.2 → 1. 입자는 "아껴서". 반대 의견("Don't juice it")도 있으니 몰입을 해치지 않을 상한을 둔다 |
| "The Art of Screenshake" (Vlambeer, Nijman) — [Kenney](https://kenney.nl/learn/must-see-videos-for-indie-developers), [Infovore](https://infovore.org/?p=5275) | 권총 한 발: 소리 → 탄피 → 빠른 탄 → 카메라 뒤로 6px + 흔들림 +4 → 총이 2만큼 밀렸다 돌아옴 | **여러 작은 신호를 겹친다**: 행동 하나에 번쩍임 + 정지 + 펀치 + 흔들림 + 입자 + 소리 2겹. 흔들림 하나는 작아도 된다 |
| "Juicing Your Cameras With Math" (Eiserloh, GDC 2016) — [Bevy example](https://bevy.org/examples/camera/2d-screen-shake/), [Strayspark](https://www.strayspark.studio/docs/godot-camera-system/noise-and-shake), [Game Developer](https://gamedeveloper.com/programming/video-sprucing-up-cameras-with-math) | 트라우마 값 0~1, 흔들림 = 트라우마², 노이즈로 부드럽게, 렌더에만 적용 | 흔들림 `A(t) = A0 × (1 − t/D)² × noise(f·t)`. 회전 위주로 흔들고 화면에만 적용(게임 로직에는 영향 없음) |
| 히트 스톱 — [Wayline](https://www.wayline.io/learn/game-feel/1), [Bugnet](https://bugnet.io/blog/how-to-fix-hitstop-or-freeze-frame-feeling-off), [Critpoints](https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/), [Coddy](https://coddy.tech/learn/godot/game_feel/hit_freeze) | 50~100ms, 무거울수록 길게. 세계 전체가 아니라 **때린 쪽과 맞은 쪽만** 멈춘다. 너무 길면 멈춘 것처럼 보인다 | 30~120ms. **캐릭터 동작과 대상만** 멈추고 서버·다른 플레이어·UI는 멈추지 않는다(멀티플레이). 무게 순서: 새 도감 120 > 수확 90 > 판매 80 > 갈기·청소 70 > 놓기 60 > 심기·거두기 40 > 버튼 30 > 물주기 0 |
| 지연 체력바 — [Fab trailing health bar](https://www.fab.com/listings/0ab7ee41-cdf5-4010-840f-0fd2e15c4742) | 두 번째 막대가 본 막대를 늦게 따라와 방금 바뀐 양을 보여 준다. 값이 바뀔 때만 움직인다 | **늘 때**는 밝은 고스트가 먼저 가고 본 채움이 뒤따른다. **줄 때**는 본 채움이 바로 줄고 분홍 고스트가 늦게 줄어든다. 코인 숫자는 날아오는 코인이 **닿은 뒤** 굴러간다 |
| 굴러가는 숫자 — [Unity Animated Score Counter](https://assetstore-fallback.unity.com/packages/tools/gui/animated-score-counter-fx-responsive-score-animation-and-effects-64052) | 코인·보석을 모을 때 숫자 애니메이션 + 소리 + 움직임 + 파티클 | 코인 카운터는 Quad Out으로 300~1200ms 동안 굴린다 |
| 접근성 — [Xbox XAG 117](https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/117), [Bugnet accessibility](https://bugnet.io/blog/accessibility-testing-for-indie-games), [gaming patterns ref](https://cdn.jsdelivr.net/npm/@hegemonart/get-design-done@1.60.4/reference/domains/gaming-patterns.md) | 카메라 흔들림·흔들거림·모션 블러는 피하거나 끌 수 있어야 한다(0~100% 슬라이더 예). 깜빡임은 초당 3회 이하, 채도 높은 빨강은 조심한다. OS의 움직임 줄이기 설정을 따른다 | "움직임 줄이기"를 켜면 흔들림과 번쩍임이 **0**이 된다. 화면 번쩍임은 초당 1회 이하, 불투명도 35% 이하이고 빨강은 쓰지 않는다 |
| UI 소리 — [Material sound](https://m2.material.io/design/sound/about-sound.html) | 소리는 행동이 끝났다는 확인이다 | 모든 버튼과 행동에 소리를 붙이되, 소리 하나만으로 정보를 전하지는 않는다 |

---

## 3. '7 HIT COMBO'를 코지 게임으로 옮기기

전투가 없으므로 "때림"을 **"손이 닿는 순간(접촉 프레임)"**으로 바꿔 읽는다. 행동마다 수치는 `interaction-patterns.md`에 있다.

| # | 원래 요소 | 우리 게임에서의 뜻 | 강도 범위 | 안전 상한 |
|---|-----------|-------------------|-----------|-----------|
| 1 | 번쩍임 | 대상 Highlight를 흰색·따뜻한 색으로 채웠다가 사라지게 한다. HUD 요소는 흰 덮개를 잠깐 씌운다. 화면 번쩍임은 새 도감·큰 판매에만 쓴다 | 80~250ms | 화면 번쩍임 불투명도 35% 이하, 초당 1회 이하, 빨강 금지. 움직임 줄이기 → 0 |
| 2 | 히트 스톱 | **접촉 정지**: 접촉 프레임에서 캐릭터 자세와 대상의 펀치를 멈춘다. UI는 카운터가 구르기 직전에 멈춘다 | 0~120ms | 세계 시간·입력·다른 플레이어는 멈추지 않는다 |
| 3 | 넉백 | **찌그러짐·튕겨 오름**: 농지가 눌리고, 작물이 튀어 오르고, 가구가 떨어져 착지하고, NPC가 깡충 뛰고, 버튼이 눌린다 | 월드 ±40%, HUD ±15% | Back Out 넘침 1회 |
| 4 | 카메라 흔들림 | **내 행동에만** 아주 작게 회전으로 흔든다. 큰 순간에는 화면을 살짝 당기는 FOV 킥을 더한다 | 0.15~0.6°, 12~22Hz, 100~300ms | 합계 0.8° 이하. 패널·대화가 열려 있으면 0. 움직임 줄이기 → 0 |
| 5 | 지연 체력바 | **지연 카운터·고스트 막대**: 코인은 날아온 코인이 닿은 뒤 굴러가고, 아늑함·도감 막대는 고스트가 먼저 움직인다. 씨앗 개수는 "−1" 칩을 남긴다 | 지연 80~600ms, 따라잡기 200~1200ms | — |
| 6 | 타격 이펙트 | 입자 + 퍼지는 링(납작한 원기둥 파트) + 반짝임 + 아이템이 HUD로 날아가기 + UI 색종이(마일스톤) | 입자 8~40개 | 한 번에 40개 이하, 살아 있는 입자 400개 이하(휴대폰) |
| 7 | 사운드 | 내장 사운드 14종(VERSION.md)을 2~3겹으로 겹치고 PlaybackSpeed로 음높이를 바꾼다. ±4% 무작위. 콤보는 음계로 올라간다 | 겹 2~3 | 같은 소리 40ms 이내 재생 금지 |

---

## 4. Design Direction (디자인 방향)

### 4.1 Palette (정확한 RGB)

| 이름 | RGB | 쓰임 |
|------|-----|------|
| Cream | 255, 248, 235 | 패널·알약 채움(기존 `Ui.CREAM`) |
| Parchment | 250, 240, 222 | 칸·카드 채움 |
| Parchment Deep | 236, 222, 196 | 눌린 칸, 칸 안쪽 바닥, 빈 막대 |
| Cocoa | 110, 78, 52 | **모든 테두리(UIStroke)**, 떠오르는 글자 테두리 |
| Ink | 80, 60, 45 | 본문 글자(Cream 위 9.8:1) |
| Muted | 115, 95, 78 | 보조 글자(Cream 위 5.7:1, 기존 140,120,100의 3.99:1을 고침) |
| Shadow | 60, 40, 25 | 아래 그림자 프레임(투명도 0.7) |
| Leaf | 120, 180, 95 | 선택 테두리, 아늑함 채움, 강조(글자 바탕으로는 쓰지 않음) |
| Leaf Deep | 76, 153, 60 | 주 버튼 채움. 흰 글자 3.5:1(굵은 18px 이상 + 글자 테두리) |
| Leaf Ink | 35, 85, 30 | 주 버튼 흰 글자의 테두리 |
| Sun Gold | 255, 200, 60 | 코인, 수확 반짝임, 콤보 5+ |
| Gold Deep | 200, 140, 30 | 코인 테두리, 금색 글자 테두리 |
| Banner Gold | 255, 230, 150 | 새 도감 배너 채움(테두리 200,150,60) |
| Berry | 255, 140, 170 | 도감, 축하, 콤보 10+ |
| Sky | 120, 190, 255 | 물, 물주기 |
| Mint | 150, 215, 180 | 아늑함 C 배지 |
| Coral | 235, 110, 95 | 거절·부족(테두리와 번쩍임에만, 글자는 Ink) |
| Ghost Gain | 255, 235, 150 | 늘 때 고스트 막대 |
| Ghost Loss | 255, 170, 170 | 줄 때 고스트 막대 |
| Flash White / Warm | 255,255,255 / 255,245,210 | 번쩍임 |

### 4.2 Shapes · Corner radius

- 알약형(코인·아늑함·도감·토스트·콤보): `UICorner = UDim.new(0.5, 0)` (완전히 둥글게)
- 칸·카드: 14px, 버튼: 16px, 패널: 22px, 배지(등급·개수): 지름의 절반
- 터치 대상은 최소 44×44, 주 버튼은 56 이상

### 4.3 Outline + Shadow

- **테두리**: 모든 알약·칸·패널·버튼에 `UIStroke` Cocoa, 두께 3px(휴대폰 2.5px), `ApplyStrokeMode.Border`
- **글자 테두리**: 떠오르는 글자, 콤보, 흰 글자 버튼에 `UIStroke(Contextual)` 2.5px(Cocoa 또는 Leaf Ink)
- **그림자**: 같은 크기·같은 모서리의 형제 프레임을 (0, +4px) 밀어 뒤에 둔다. Shadow 색, 투명도 0.7. 누르면 오프셋이 1px로 줄어 "눌려 들어간" 느낌을 준다. Roblox에는 박스 그림자가 없고 UIStroke는 하나만 쓸 수 있으므로 형제 프레임으로 만든다
- 그라데이션: 주 버튼과 배너에만 `UIGradient`, 위쪽 +8% 밝게(Rotation 90)

### 4.4 Typography

| 용도 | 글꼴 | 휴대폰 / PC px |
|------|------|----------------|
| 숫자·라틴 문자(코인, ×5, 7/21, 콤보 숫자, 등급 글자) | `Enum.Font.FredokaOne` | — |
| 한글 라벨·본문 | `Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)` (한글 글리프는 자동 대체 글꼴로 그려진다) | — |
| 코인 숫자 | FredokaOne | 22 / 26 |
| 아늑함·도감 알약 숫자 | FredokaOne | 18 / 20 |
| 칸 이름 · 버튼 라벨 | Builder Sans Bold | 14 / 15 |
| 칸 개수 ×n | FredokaOne | 16 / 18 |
| 토스트 | Builder Sans Bold | 17 / 18 |
| 배너 제목 / 부제 | Builder Sans ExtraBold / Bold | 24 / 28, 17 / 18 |
| 대화 본문 | Builder Sans Bold | 18 / 19 |
| 떠오르는 글자(BillboardGui) | FredokaOne + 한글 대체 | 26 / 28 |
| 콤보 숫자 | FredokaOne | 30→56 / 34→70 |
| **최소** | — | **14px**(기존 11·12·13px 글자는 모두 14로 올린다) |

Gotham은 쓰지 않는다(위 4번 문제). `TextScaled`는 쓰지 않고 크기를 고정한다. 크기를 키우는 설정은 `UIScale`로 만든다.

### 4.5 Icon framing (업로드 없는 3D 아이콘)

- 모든 아이콘은 **ViewportFrame + 게임 자체 모델**로 만든다. 공용 빌더 하나(`IconModels.Build(kind, id)`, 클라이언트)가 모델을 만든다.
  - 작물: 3단계 모델. 지금은 서버에서 만드니, `Furniture.Build`처럼 Shared 빌더로 옮겨야 한다(구현 의존성)
  - 가구: `Furniture.Build(id)`를 그대로 쓴다
  - 씨앗 주머니: Ball 파트(1.2, 1.4, 1.2) 삼베색(205,170,120) Fabric + 원기둥 목 + 작물 `Fruit` 색 띠
  - 코인: 금색(255,200,60) 원기둥 + 한 단계 진한(230,160,40) 테두리 원기둥, 20° 기울임
  - 섬 컨셉: **복셀 블록 덩어리**. 맨 위 3×3 블록(컨셉 `Tint.Grass`, 없으면 `Color`), 아래 2×2(흙), 맨 아래 1×1(돌)로 쌓아 떠 있는 섬처럼 원뿔을 만든다
  - 도감(책): 표지 박스 Berry + 종이 박스 Cream / 아늑함(집): 몸통 박스 Cream + WedgePart 지붕 2개(170,95,70) / 설정(톱니): 원기둥 + 작은 블록 6개
- 카메라: `FieldOfView = 28`(원근 왜곡이 적다). 오른쪽으로 35°, 위에서 −22°로 내려다보는 3/4 시점. 거리 `d = r / sin(FOV/2) × 1.08`, `r`은 `Model:GetBoundingBox()` 크기의 절반 대각선
- 조명: `Ambient = (205,200,195)`, `LightColor = (255,244,225)`, `LightDirection = (-0.6,-1,-0.4)`. 칸 안쪽 여백 6px, 배경은 투명(칸 채움이 비친다)
- **실루엣(못 찾은 도감)**: 복제한 모델의 모든 BasePart를 `Color = 검정`, `Material = SmoothPlastic`로 바꾸고(Neon 등불이 빛나지 않게), `Ambient = LightColor = 검정`, `ImageTransparency = 0.15`로 둔다. 오른쪽 아래에 "?" 배지(FredokaOne 20, Cream + Cocoa 테두리)를 붙인다
- 움직임: 고른 씨앗 칸 아이콘만 초당 30°로 돈다. 나머지는 멈춰 있어 다시 그리는 비용을 아낀다. 새로 얻은 순간에는 한 바퀴(360°, 0.6초) 돈다
- 예산: 한 화면에 ViewportFrame 30개 이하. 도감은 지금 탭의 카드만 만든다

### 4.6 Motion rules

| 규칙 | 길이 | Easing |
|------|------|--------|
| 등장(팝) | 160~220ms, 0.8 또는 1.3배에서 시작 | Back Out |
| 퇴장 | 등장의 0.7배(120~160ms) | Quad In |
| 누르기 / 놓기 | 60ms 0.9배 / 90ms 1.06 → 70ms 1 | Quad Out / Back Out → Sine Out |
| 값 바뀜 펀치 | 1 → 1.2 → 1, 합계 180ms | Back Out |
| HUD로 날아가기 | 400~650ms, 베지어 곡선 | Quad In(빨려 들어감) |
| 숫자 굴리기 | 300~1200ms | Quad Out |
| 대기 루프 | 주기 2초 이상, 크기 ±4% / 회전 ±4° 이하 | Sine InOut |

- 크기 변화는 `UIScale.Scale`로 트윈한다. 레이아웃 안에 있는 요소의 `Size`는 트윈하지 않는다(줄이 흔들린다).
- 가만히 있는 HUD는 움직이지 않는다. 예외는 고른 칸 아이콘 회전, S등급 반짝임, 새 도감 칸 맥동 세 가지뿐이다.
- 모든 숫자 값은 `JUICE`(전체 배율, 기본 1.0, 0~1.5) 하나로 함께 줄이고 키운다. 움직임 줄이기를 켜면 흔들림·번쩍임은 0, 날아가기·펀치는 페이드로 바뀐다.

---

## Decisions (autonomous run — 질문 없이 정한 것)

1. 아이콘은 업로드 없이 ViewportFrame 3D 렌더 하나로 통일한다(사용자 제약). 2D 대체물(글자·이모지)은 쓰지 않는다. 이모지는 기기마다 다르게 보이기 때문이다.
2. 글꼴은 숫자 FredokaOne, 한글 Builder Sans로 정했다. Gotham은 없앤다는 안내 때문에 버린다.
3. 기존 Cream·Ink·Leaf는 유지하고 대비가 부족한 Muted를 고쳤다. 흰 글자 바탕은 Leaf에서 Leaf Deep으로 바꿨다.
4. 휴대폰 기본 조작 모서리와 겹치는 문제는 버그로 보고 `hud.md`에서 위치를 옮겼다.
5. 히트 스톱은 세계가 아니라 캐릭터와 대상만 멈춘다(멀티플레이 서버 게임이라 시간을 멈출 수 없다).
6. 콤보는 순수 연출이고 보상은 없다(Pillar 1). 남은 시간 막대도 보이지 않는다.
7. 게임별 조사의 상세 내용 중 출처 발췌로 확인되지 않은 부분은 (일반 지식)으로 표시했다. 다음 세션에서 WebFetch로 원문을 확인하면 좋다.
