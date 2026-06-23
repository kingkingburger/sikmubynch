# SIKMUBYNCH 유지보수형 리팩터링 설계

작성일: 2026-06-23

## 배경

현재 `project/scenes/main/game.gd`는 메인 씬 초기화, 카메라, 조명, 지면 셰이더, UI 생성, 입력 처리, 건물 배치, 웨이브 스폰, 보상 카드, 이벤트 선택, ESC 메뉴, 디버그 오버레이를 한 파일에서 처리한다. 이미 `building_catalog.gd`, `threat_radar.gd`, `wave_director.gd` 추출이 시작되었지만, `game.gd`는 여전히 1,300줄 이상이며 다음 기능 추가 때 다시 비대해질 가능성이 높다.

리팩터링 목표는 "기능을 바꾸지 않고 파일 경계를 정리해서 다음 기능을 더 안전하게 붙일 수 있게 만드는 것"이다. 새 게임플레이, 밸런스 조정, 렌더링 재작성은 이 문서의 1차 목표가 아니다.

## 현재 관찰

- `game.gd`: 씬 오케스트레이션과 실제 시스템 로직이 섞여 있다.
- `building_catalog.gd`: 건물 데이터 생성 책임이 분리되었지만, 이후 `.tres` 리소스화 여부는 별도 결정이 필요하다.
- `threat_radar.gd`: 미니맵 UI가 분리되어 좋은 선례가 생겼다.
- `wave_director.gd`: 웨이브 수치와 스폰 위치 계산이 분리되었지만, 스폰 큐와 실제 인스턴스 생성은 아직 `game.gd`에 남아 있다.
- `enemy.gd`, `unit.gd`: 메쉬 생성, 애니메이션, AI, 전투, 사망 효과가 각각 한 파일에 묶여 있어 두 번째 리팩터링 축이다.
- 검증 기준선: Godot 4.6.1 headless 로드는 성공했다. 종료 시 resource leak 경고는 있으나 현재 기준선에서는 script/parse error가 아니다.

## 설계 원칙

1. 동작 보존을 우선한다. 리팩터링 단계에서는 웨이브 수치, 비용, 공격력, UI 동작을 바꾸지 않는다.
2. `game.gd`는 씬 루트와 신호 연결을 조율하는 coordinator로 낮춘다.
3. 한 번에 새 프레임워크를 만들지 않는다. 이미 존재하는 Godot Node, RefCounted, Autoload, signal 패턴을 유지한다.
4. 각 추출은 즉시 검증 가능한 작은 단위로 끝낸다.
5. 새 파일은 "역할 이름"으로 만든다. `manager` 남발을 피하고, 책임이 보이는 이름을 쓴다.

## 목표 구조

### 1. Main Scene Coordinator

`project/scenes/main/game.gd`

남길 책임:

- 씬 루트 생명주기
- 핵심 PackedScene 로드
- controller/helper 생성
- Autoload signal 연결
- 각 controller의 `tick`, `handle_input`, `refresh` 호출

제거할 책임:

- UI 노드 상세 생성
- 건물 배치 검증과 인스턴스화
- 웨이브 수치 계산과 스폰 위치 계산
- threat radar 렌더링
- 보상 카드 UI 세부 구성
- 카메라 입력 세부 계산

### 2. UI Controller

후보 파일:

- `project/scripts/game_ui_controller.gd`
- `project/scripts/reward_choice_panel.gd`
- `project/scripts/debug_overlay.gd`

책임:

- HUD, 보상 카드, 선택 이벤트, ESC 메뉴, 디버그 오버레이 생성
- `GameManager`, `SynergyManager`, `EventManager` 상태를 화면 텍스트로 반영
- 사용자의 UI 선택을 signal로 방출

주의:

- UI가 게임 상태를 직접 변경하는 범위는 최소화한다.
- 보상 적용, 선택 결과 처리 같은 도메인 동작은 기존 흐름을 유지하거나 별도 runtime으로 옮긴다.

### 3. Building Placement

후보 파일:

- `project/scripts/building_placer.gd`
- `project/scripts/building_registry.gd`

책임:

- grid bounds 검증
- 기존 건물 존재 여부 확인
- 비용 차감
- PackedScene 인스턴스화
- `building_grid`, `FlowField`, `SynergyManager`, 건물 수 카운터 갱신
- drag build와 단일 클릭 build 경로 통합

성공 기준:

- `_handle_left_click`과 `_try_drag_build`의 중복 건설 코드가 사라진다.
- 배치 실패 이유가 한 함수의 return/result로 추적 가능하다.

### 4. Wave Runtime

현재 `wave_director.gd`는 순수 계산에 가깝게 유지한다.

후보 파일:

- `project/scripts/wave_runtime.gd`
- `project/scripts/enemy_spawner.gd`

책임:

- `_spawn_queue` 소유
- frame당 스폰 수 제한
- enemy scene 인스턴스화
- `died`, `drop_mineral` signal 연결
- wave active/completed 판정 보조

주의:

- `WaveDirector`는 수치/확률 계산만 담당한다.
- `WaveRuntime`은 실제 scene tree와 signal을 다룬다.

### 5. Actor Internals

2차 리팩터링 대상:

- `project/scenes/enemies/enemy.gd`
- `project/scenes/units/unit.gd`
- `project/scenes/buildings/base_building.gd`

후보 분리:

- `enemy_visual_builder.gd`: enemy mesh/detail/hp bar 생성
- `enemy_status_effects.gd`: burn/slow/poison/stun 상태와 tick
- `unit_visual_builder.gd`: unit mesh/weapon/hp bar 생성
- `unit_combat_brain.gd`: patrol/chase/attack 상태 전이
- `building_visual_builder.gd`: building mesh/light/hp bar 생성

이 단계는 `game.gd` 안정화 이후 진행한다. 처음부터 같이 건드리면 회귀 원인을 추적하기 어렵다.

## 단계별 실행 순서

### Phase 0: 현재 추출 안정화

- 기존 dirty 변경의 의도를 유지한다.
- `building_catalog.gd`, `threat_radar.gd`, `wave_director.gd`가 Godot에서 정상 로드되는지 확인한다.
- UID 파일과 preload 경로를 유지한다.
- 검증: Godot headless load, main scene 실행 smoke.

### Phase 1: UI Controller 추출

- `game.gd`의 `_setup_ui`, card UI, synergy bar, event UI, choice UI, speed label, ESC menu, debug overlay를 UI controller로 이동한다.
- `game.gd`는 UI controller에 필요한 callback만 연결한다.
- 검증: HUD 갱신, reward card 선택, ESC resume/title/restart, F3 overlay.

### Phase 2: Building Placement 추출

- 단일 클릭 배치와 drag barricade 배치를 같은 placement 함수로 통합한다.
- 비용 차감, grid 갱신, FlowField dirty 처리, synergy add/remove 흐름을 한 경계로 모은다.
- 검증: 1~5번 건물 배치, 자원 부족 실패, 레벨업, 철거, FlowField 재계산.

### Phase 3: Wave Runtime 추출

- `_spawn_queue`, `_spawn_wave`, `_process_spawn_queue`, wave completion 보조를 `wave_runtime.gd`로 이동한다.
- `WaveDirector`는 enemy count/templates/spawn position만 담당한다.
- 검증: 1~3웨이브 진행, early wave 근거리 스폰, wave clear 보상, challenge multiplier 반영.

### Phase 4: Actor 파일 축소

- `enemy.gd`와 `unit.gd`에서 visual builder부터 분리한다.
- 이후 status effect와 state machine을 분리한다.
- 검증: 적 이동/공격/분열/폭발, 유닛 patrol/chase/attack/bomber explosion.

### Phase 5: 데이터 리소스화 검토

- `BuildingCatalog`와 `WaveDirector`의 하드코딩 수치를 `.tres` 또는 config resource로 옮길지 결정한다.
- 이 단계는 밸런싱을 자주 하게 될 때만 진행한다.

## 파일 크기 목표

- `game.gd`: 1차 목표 700줄 이하, 최종 목표 450줄 이하
- `enemy.gd`: 최종 목표 400줄 이하
- `unit.gd`: 최종 목표 400줄 이하
- 새 helper/controller: 파일당 250줄 이하를 우선 목표로 한다.

줄 수는 절대 기준이 아니라 냄새 감지 기준이다. 역할이 명확하면 조금 넘어도 된다.

## 검증 계획

기본 검증:

```powershell
& 'D:\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\reference2\sikmubynch\project' --quit
```

수동 smoke:

1. 타이틀에서 게임 시작
2. 1~5번 건물 선택과 배치
3. 바리케이드 drag build
4. 건물 레벨업과 철거
5. 1~3웨이브 진행과 wave clear 보상
6. reward card 선택과 skip
7. ESC menu resume/title/restart
8. F3 debug overlay
9. threat radar 적/건물 점 표시

회귀 관찰:

- script/parse error 없음
- 새 null reference 없음
- 배치 비용과 환불량 유지
- wave enemy count와 spawn rhythm 유지
- 기존 resource leak 경고 외 새 치명 오류 없음

## 구현 보류 사항

- enemy/unit 전체 state machine 재작성
- MultiMesh 전환
- `.tres` 데이터 전환
- fog of war
- 미니맵 SubViewport 재작성
- 밸런싱 수치 변경

위 항목은 미래 과제이며, 이번 리팩터링에 섞으면 원인 추적이 어려워진다.

## 권장 1차 구현

가장 먼저 Phase 0과 Phase 1을 수행한다. 이미 시작된 helper 추출을 검증 가능한 상태로 고정한 뒤, `game.gd`에서 가장 큰 덩어리인 UI 생성을 controller로 옮기는 순서가 안전하다. 이 순서는 게임플레이 수치를 건드리지 않고도 파일 경계를 크게 개선한다.
