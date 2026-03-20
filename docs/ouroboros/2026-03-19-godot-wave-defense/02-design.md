# SIKMUBYNCH (식무변처) - 설계

> Ouroboros Phase 2 | 2026-03-19 | 모호성: 16%

## ADR (Architecture Decision Records)

### ADR-1: 엔진 — Godot 4

- **결정**: Godot 4 + GDScript
- **대안**: Unity (C#), Unreal (C++), 웹 (Three.js)
- **선택 근거**:
  - 2D 네이티브 지원 (Unity/Unreal은 3D 우선)
  - GDScript ≈ Python → 사용자 기존 역량 활용
  - 무료 + 오픈소스, 빌드 크기 작음
  - MultiMeshInstance2D로 대량 유닛 렌더링 가능
- **리스크**: 게임 개발 첫 경험이라 학습 곡선 존재 → Godot 문서/튜토리얼 잘 되어 있음

### ADR-2: 적 유닛 처리 — Object Pool + MultiMesh

- **결정**: 적 유닛은 Object Pool + MultiMeshInstance2D
- **대안**: 순수 Node 기반, ECS (godot-rust)
- **선택 근거**:
  - 500+ 적 유닛 요구사항 → Node 기반은 200개 이상에서 성능 저하
  - MultiMeshInstance2D는 단일 드로우콜로 수천 개 스프라이트 렌더링
  - Object Pool로 GC 부담 제거
  - godot-rust ECS는 학습 비용 과다
- **리스크**: MultiMesh는 개별 클릭/충돌 감지 직접 구현 필요 → 적은 개별 선택 불필요하므로 문제 없음

### ADR-3: 아군 유닛/건물 — Node 기반

- **결정**: 아군 유닛(20-50개), 건물(5-20개)은 표준 Node2D 씬
- **대안**: 적과 같이 MultiMesh
- **선택 근거**:
  - 소수이므로 성능 문제 없음
  - 시너지 오라, 건물 상호작용 등 개별 비주얼 필요
  - Godot 에디터에서 직접 디버깅 가능
  - 건물 클릭/선택 UI 자연스러움

### ADR-4: 적 길찾기 — Flow Field

- **결정**: Flow Field 방식
- **대안**: A* 개별 경로, Navigation2D, 직선 이동
- **선택 근거**:
  - 500+ 에이전트에 개별 A*는 성능 불가
  - Navigation2D도 500 에이전트 비현실적
  - Flow Field는 맵 전체 한 번 계산 → 모든 적이 공유
  - 건물 배치 변경 시 Flow Field만 갱신
  - 본진 방향으로의 자연스러운 대규모 이동
- **리스크**: Flow Field 구현 복잡도 → 단순 그리드 기반으로 충분, 참고 자료 풍부

### ADR-5: 데이터 구조 — Godot Resource (.tres)

- **결정**: 특성, 시너지, 웨이브, 유닛/건물 스탯을 Godot Resource로 정의
- **대안**: JSON, GDScript dict, SQLite
- **선택 근거**:
  - Godot 에디터에서 직접 편집/미리보기 가능
  - 타입 안전성 (export 변수)
  - 씬에서 드래그앤드롭으로 연결
  - 코드와 데이터 분리
- **리스크**: 없음 (Godot 표준 패턴)

### ADR-6: 시너지 시스템 — 중앙 관리자 + 옵저버 패턴

- **결정**: SynergyManager 오토로드가 전체 시너지 상태 추적
- **대안**: 각 유닛/건물이 자체 시너지 계산
- **선택 근거**:
  - 유닛/건물 추가/제거 시 전체 시너지 재계산 필요
  - 중앙 관리가 일관성 보장
  - Signal로 시너지 변경 이벤트 브로드캐스트
  - UI 바와 필드 이펙트 모두 같은 이벤트 구독
- **리스크**: 매 배치/제거 시 전체 재계산 → 유닛/건물 합계 50개 이하이므로 O(n) 무시 가능

### ADR-7: 게임 필 — 전용 시스템

- **결정**: GameFeel 오토로드로 화면 흔들림, 히트스톱, 파티클 중앙 관리
- **대안**: 각 엔티티가 자체 이펙트 처리
- **선택 근거**:
  - 타격감이 핵심 가치 → 전용 시스템으로 품질 보장
  - 화면 흔들림은 카메라 레벨, 히트스톱은 게임 시간 레벨 → 중앙 관리 필수
  - 강도 매개변수화로 상황별 조절 (일반 적 vs 대형 적)
- **리스크**: 없음

---

## 시스템 아키텍처

### 전체 구조

```
Godot Autoloads (싱글톤)
├── GameManager        — 게임 상태 (런, 웨이브, 자원)
├── WaveManager        — 웨이브 스폰, 난이도 스케일링
├── SynergyManager     — 특성 추적, 시너지 발동/해제
├── EnemyPool          — 적 Object Pool + MultiMesh 렌더링
├── GameFeel           — 화면 흔들림, 히트스톱, 플래시
├── RewardManager      — 웨이브 클리어 보상 생성
└── FlowField          — 적 길찾기 그리드

Game Scene Tree
├── Camera2D           — 플레이어 카메라 (WASD 이동, 휠 줌)
├── TileMap            — 맵 지형 (절차적 생성)
├── Buildings          — Node2D 컨테이너
│   ├── HQ             — 본진 (중앙 고정)
│   └── [배치된 건물들]
├── Units              — Node2D 컨테이너
│   └── [생산된 유닛들]
├── EnemyRenderer      — MultiMeshInstance2D (적 렌더링)
├── Projectiles        — Node2D 컨테이너 (발사체 풀)
├── Particles          — GPUParticles2D 풀
└── UI
    ├── HUD            — 자원, 웨이브, 시너지 바
    ├── BuildMenu      — 건설 메뉴
    ├── RewardPicker   — 보상 3택 UI
    └── GameOver       — 게임오버 화면
```

### 통신 방식

```
Signal 기반 느슨한 결합:

건물 배치/제거 → SynergyManager.recalculate()
                 → signal synergy_changed(active_synergies)
                   → HUD.update_synergy_bar()
                   → Units/Buildings.apply_synergy_effects()

적 사망 → GameManager.add_mineral(amount)
         → GameFeel.play_death_effect(position, size)
         → EnemyPool.return(enemy)
         → WaveManager.check_wave_clear()

웨이브 클리어 → RewardManager.generate_rewards(3)
              → UI.show_reward_picker()
              → (선택 후) GameManager.apply_reward()
```

---

## 콘텐츠 설계 (초기 세트)

### 특성 (Traits) — 5종

| 특성 | 색상 | 효과 테마 |
|------|------|----------|
| 화염 (Fire) | 빨강 | 지속 데미지, 범위 공격 |
| 냉기 (Ice) | 파랑 | 이동속도 감소, 동결 |
| 독 (Poison) | 초록 | 지속 데미지, 방어력 감소 |
| 전기 (Electric) | 노랑 | 연쇄 공격, 스턴 |
| 강화 (Fortify) | 회색 | 체력 증가, 방어력 증가 |

### 건물 — 6종

| 건물 | 비용 | 특성 | 역할 |
|------|------|------|------|
| 본진 (HQ) | - | - | 방어 대상. 파괴 시 런 종료 |
| 바리케이드 | 30 | 가변 | 적 이동 차단. 특성에 따라 접촉 데미지 |
| 타워 | 80 | 가변 | 원거리 자동 공격. 핵심 방어 건물 |
| 배럭 | 100 | 가변 | 유닛 자동 생산. 특성이 생산 유닛에 전달 |
| 채굴기 | 60 | - | 미네랄 자동 생산. 경제 건물 |
| 버프 타워 | 120 | 가변 | 주변 건물/유닛 강화. 시너지 트리거 역할 |

> "가변" = 보상으로 획득 시 랜덤 특성 부여

### 아군 유닛 — 4종

| 유닛 | 생산 건물 | 특성 | 역할 |
|------|----------|------|------|
| 솔저 | 배럭 | 배럭 특성 계승 | 근접 전투. 기본 유닛 |
| 아처 | 배럭 | 배럭 특성 계승 | 원거리 공격. 낮은 체력 |
| 탱커 | 배럭 | 강화 고정 | 높은 체력. 적 어그로 |
| 폭탄병 | 배럭 | 화염 고정 | 범위 공격. 자폭형 |

### 적 유닛 — 4종

| 적 | 체력 | 속도 | 특징 | 보상 |
|----|------|------|------|------|
| 러셔 | 낮음 | 빠름 | 대량 출현. 방어선 압박 | 5 |
| 탱크 | 높음 | 느림 | 높은 체력. 바리케이드 파괴 | 15 |
| 스플리터 | 중간 | 중간 | 사망 시 2마리로 분열 | 10 |
| 폭발형 | 중간 | 빠름 | 건물 근접 시 자폭. 범위 데미지 | 20 |

### 시너지 — 6종

| 시너지 | 조건 | 효과 |
|--------|------|------|
| 화염폭풍 | 화염 유닛 2+ AND 화염 건물 1+ | 화염 공격 범위 +50%, 지속 데미지 +30% |
| 빙결장 | 냉기 건물 2+ AND 냉기 유닛 1+ | 모든 적 기본 이동속도 -15% |
| 맹독지대 | 독 건물 2+ AND 독 유닛 1+ | 독 데미지 적 방어력 무시 |
| 번개사슬 | 전기 유닛 2+ AND 전기 건물 1+ | 전기 공격 최대 3마리 연쇄 |
| 철벽 | 강화 건물 3+ | 모든 건물 체력 +40% |
| 원소폭발 | 서로 다른 특성 4종 이상 보유 | 모든 공격력 +25% |

---

## 파일/씬 구조

```
project/
├── project.godot
│
├── autoloads/                    # 오토로드 (싱글톤)
│   ├── game_manager.gd           # 게임 상태, 런 관리
│   ├── wave_manager.gd           # 웨이브 스폰/스케일링
│   ├── synergy_manager.gd        # 특성/시너지 추적
│   ├── enemy_pool.gd             # 적 Object Pool + MultiMesh
│   ├── game_feel.gd              # 화면흔들림, 히트스톱, 플래시
│   ├── reward_manager.gd         # 보상 생성/관리
│   └── flow_field.gd             # 적 길찾기 그리드
│
├── scenes/
│   ├── main/
│   │   ├── game.tscn             # 메인 게임 씬
│   │   └── game.gd
│   │
│   ├── buildings/
│   │   ├── base_building.tscn    # 건물 베이스 씬
│   │   ├── base_building.gd      # 건물 공통 로직
│   │   ├── hq.tscn               # 본진
│   │   ├── barricade.tscn        # 바리케이드
│   │   ├── tower.tscn            # 타워
│   │   ├── barrack.tscn          # 배럭
│   │   ├── miner.tscn            # 채굴기
│   │   └── buff_tower.tscn       # 버프 타워
│   │
│   ├── units/
│   │   ├── base_unit.tscn        # 유닛 베이스 씬
│   │   ├── base_unit.gd          # 유닛 공통 로직 (자동 전투 AI)
│   │   ├── soldier.tscn
│   │   ├── archer.tscn
│   │   ├── tanker.tscn
│   │   └── bomber.tscn
│   │
│   ├── ui/
│   │   ├── hud.tscn              # 상단 HUD (자원, 웨이브, 시너지바)
│   │   ├── hud.gd
│   │   ├── build_menu.tscn       # 건설 메뉴
│   │   ├── build_menu.gd
│   │   ├── reward_picker.tscn    # 보상 3택 UI
│   │   ├── reward_picker.gd
│   │   ├── synergy_bar.tscn      # 시너지 상태 바
│   │   └── game_over.tscn        # 게임오버 화면
│   │
│   └── effects/
│       ├── hit_effect.tscn       # 히트 이펙트 (파티클)
│       ├── death_effect.tscn     # 사망 이펙트
│       └── synergy_aura.tscn     # 시너지 오라 이펙트
│
├── resources/                    # 데이터 정의 (.tres)
│   ├── traits/
│   │   ├── trait_fire.tres
│   │   ├── trait_ice.tres
│   │   ├── trait_poison.tres
│   │   ├── trait_electric.tres
│   │   └── trait_fortify.tres
│   │
│   ├── synergies/
│   │   ├── synergy_firestorm.tres
│   │   ├── synergy_frostfield.tres
│   │   ├── synergy_toxiczone.tres
│   │   ├── synergy_chainlightning.tres
│   │   ├── synergy_ironwall.tres
│   │   └── synergy_elemental_burst.tres
│   │
│   ├── buildings/
│   │   ├── building_hq.tres
│   │   ├── building_barricade.tres
│   │   ├── building_tower.tres
│   │   ├── building_barrack.tres
│   │   ├── building_miner.tres
│   │   └── building_buff_tower.tres
│   │
│   ├── units/
│   │   ├── unit_soldier.tres
│   │   ├── unit_archer.tres
│   │   ├── unit_tanker.tres
│   │   └── unit_bomber.tres
│   │
│   ├── enemies/
│   │   ├── enemy_rusher.tres
│   │   ├── enemy_tank.tres
│   │   ├── enemy_splitter.tres
│   │   └── enemy_exploder.tres
│   │
│   └── waves/
│       └── wave_config.tres      # 웨이브 스케일링 설정
│
├── scripts/
│   ├── data/                     # Resource 클래스 정의
│   │   ├── trait_data.gd         # class_name TraitData extends Resource
│   │   ├── synergy_data.gd       # class_name SynergyData extends Resource
│   │   ├── building_data.gd      # class_name BuildingData extends Resource
│   │   ├── unit_data.gd          # class_name UnitData extends Resource
│   │   ├── enemy_data.gd         # class_name EnemyData extends Resource
│   │   └── reward_data.gd        # class_name RewardData extends Resource
│   │
│   ├── systems/
│   │   ├── map_generator.gd      # 절차적 맵 생성
│   │   ├── combat_system.gd      # 전투 판정 (사거리, 데미지)
│   │   └── building_placer.gd    # 건물 배치 로직 (그리드 스냅, 유효성)
│   │
│   └── utils/
│       └── object_pool.gd        # 범용 Object Pool
│
└── assets/
    ├── sprites/
    │   ├── buildings/
    │   ├── units/
    │   ├── enemies/
    │   └── effects/
    ├── audio/
    │   ├── sfx/
    │   └── music/
    └── fonts/
```

---

## 핵심 시스템 상세

### 1. EnemyPool (적 유닛 풀)

```
┌─ EnemyPool (Autoload) ─────────────────────────┐
│                                                  │
│  enemies: Array[EnemyInstance]  # 데이터 배열     │
│  multimesh: MultiMeshInstance2D # 렌더링          │
│  active_count: int                               │
│                                                  │
│  spawn(type, pos) → EnemyInstance                │
│  update(delta)    → 이동 + 전투 + 사망 처리       │
│  return(idx)      → 풀에 반환                     │
│                                                  │
│  내부 구조:                                       │
│  ┌─ EnemyInstance (순수 데이터, Node 아님) ──┐    │
│  │ pos: Vector2                             │    │
│  │ hp: float                                │    │
│  │ speed: float                             │    │
│  │ type: EnemyData                          │    │
│  │ active: bool                             │    │
│  └──────────────────────────────────────────┘    │
└──────────────────────────────────────────────────┘
```

- 최대 1024개 사전 할당 (확장 가능)
- `_process(delta)`: 활성 적 전체 이동 → Flow Field 방향 따라
- MultiMesh 인스턴스 Transform 업데이트 (위치 + 스프라이트 프레임)

### 2. Flow Field (길찾기)

```
┌─ FlowField (Autoload) ──────────────────────────┐
│                                                   │
│  grid: Array[Array[Vector2]]  # 각 셀의 방향벡터  │
│  cell_size: int = 16          # 픽셀 단위         │
│                                                   │
│  recalculate(target_pos)                          │
│    1. BFS from target (본진)                      │
│    2. 각 셀에 다음 셀 방향 벡터 저장               │
│    3. 건물은 장애물로 처리                          │
│                                                   │
│  get_direction(world_pos) → Vector2               │
│    적 위치 → 그리드 셀 → 방향 벡터 반환            │
│                                                   │
│  트리거: 건물 배치/파괴 시 recalculate()           │
└───────────────────────────────────────────────────┘
```

### 3. SynergyManager (시너지)

```
┌─ SynergyManager (Autoload) ──────────────────────┐
│                                                    │
│  trait_counts: Dict[StringName, int]               │
│  active_synergies: Array[SynergyData]              │
│                                                    │
│  signal synergy_activated(synergy: SynergyData)    │
│  signal synergy_deactivated(synergy: SynergyData)  │
│  signal synergies_changed(all_active: Array)        │
│                                                    │
│  on_entity_added(traits: Array[TraitData])         │
│    → trait_counts 갱신 → _check_all_synergies()    │
│                                                    │
│  on_entity_removed(traits: Array[TraitData])       │
│    → trait_counts 갱신 → _check_all_synergies()    │
│                                                    │
│  _check_all_synergies()                            │
│    모든 SynergyData.condition 확인                  │
│    변경 있으면 signal emit                          │
└────────────────────────────────────────────────────┘
```

### 4. GameFeel (타격감)

```
┌─ GameFeel (Autoload) ────────────────────────────┐
│                                                   │
│  screen_shake(intensity, duration)                 │
│    → Camera2D offset 랜덤 진동                    │
│    → intensity: 0.1(약) ~ 1.0(강)                 │
│                                                   │
│  hitstop(duration_ms)                              │
│    → Engine.time_scale = 0.05                     │
│    → duration 후 복원 (보통 50-100ms)              │
│                                                   │
│  flash(node, color, duration)                      │
│    → 대상 스프라이트 white flash                   │
│                                                   │
│  spawn_particles(pos, type, count)                 │
│    → 사전 풀링된 GPUParticles2D 활성화             │
│                                                   │
│  # 프리셋                                          │
│  enemy_hit(pos)                                    │
│    → flash + spawn_particles(작음)                 │
│  enemy_death(pos)                                  │
│    → screen_shake(0.2) + spawn_particles(중간)     │
│  big_enemy_death(pos)                              │
│    → screen_shake(0.5) + hitstop(80ms)             │
│    → spawn_particles(대량)                         │
│  building_destroyed(pos)                           │
│    → screen_shake(0.8) + hitstop(120ms)            │
│    → spawn_particles(폭발)                         │
└───────────────────────────────────────────────────┘
```

### 5. WaveManager (웨이브)

```
웨이브 스케일링 (대규모 전투 — 첫 웨이브부터 압도적):
  Wave N의 적 구성:
    러셔:   30 + N × 15    (첫 웨이브부터 대량)
    탱크:   max(0, (N-1) × 3)  (2웨이브부터)
    스플리터: max(0, (N-2) × 2) (3웨이브부터)
    폭발형:  max(0, (N-4) × 2)  (5웨이브부터)

  체력 배수: 1.0 + (N-1) × 0.10
  속도 배수: 1.0 + (N-1) × 0.02

  Wave 1:  러셔 45마리 (사방에서 밀려옴, 압도적 첫인상)
  Wave 3:  러셔 75 + 탱크 6 + 스플리터 2 = 총 83+
  Wave 5:  러셔 105 + 탱크 12 + 스플리터 6 + 폭발형 2 = 총 125+
  Wave 10: 러셔 180 + 탱크 27 + 스플리터 16 + 폭발형 12 = 총 235+
  Wave 20: 러셔 330 + 탱크 57 + 스플리터 36 + 폭발형 32 = 총 455+
  Wave 30: 러셔 480 + 탱크 87 + 스플리터 56 + 폭발형 52 = 총 675+

  스폰 방향: 맵 사방 가장자리에서 랜덤 위치, 물결처럼 밀려오는 연출
  동시 스폰 제한: 초당 최대 50마리 (대규모 밀려오는 연출)
  화면에 동시 존재 최대: 1024마리 (MultiMesh 버퍼 크기)
```

### 6. 보상 시스템

```
웨이브 클리어 시:
  1. RewardManager.generate_rewards(3) 호출
  2. 보상 풀에서 3개 랜덤 선택 (중복 불가)
  3. 보상 종류:
     - 새 건물 해금 (특성 랜덤 부여)
     - 새 유닛 해금 (특성 랜덤 부여)
     - 글로벌 버프 (공격력/속도/체력 % 증가)
     - 시너지 부스트 (특정 시너지 효과 강화)
  4. 희귀도: 일반(60%) / 희귀(30%) / 전설(10%)
  5. 게임 일시정지 → 3택 UI 표시
  6. 선택 후 즉시 적용 → 다음 웨이브 시작
```

---

## 맵 생성 (절차적)

```
1. 고정 요소:
   - 중앙에 본진 (HQ)
   - 본진 주변 3×3 빈 공간 (초기 건설 영역)

2. 랜덤 요소:
   - 미네랄 노드 4-8개 (채굴기 배치용)
   - 자연 장애물 (바위, 물) — 적/건물 배치 불가
   - 지형 변화 (좁은 통로, 넓은 평원)

3. 균형 보장:
   - 4방향 모두 적이 진입 가능한 경로 존재
   - 미네랄 노드가 한쪽에 쏠리지 않도록 분산

4. 맵 크기: 64×64 타일 (타일 크기 16px = 1024×1024px 뷰포트)
```

---

## 엣지케이스

| 상황 | 처리 |
|------|------|
| 적이 건물에 완전히 둘러싸여 경로 없음 | Flow Field에서 가장 가까운 건물 공격 |
| 모든 배럭 파괴 → 유닛 생산 불가 | 보상에서 배럭 우선 제공 (자동 조정) |
| 자원 0 + 건물 없음 | 본진 자체에 약한 자동 공격 추가 (최후 수단) |
| 500+ 적 동시 존재 시 프레임 | MultiMesh로 렌더링, 로직은 O(n) 단순 루프 |
| 시너지 조건 정확히 경계에서 유닛 사망 | 사망 처리 후 즉시 시너지 재계산 |
| 보상으로 같은 건물 중복 획득 | 허용 — 여러 개 배치 가능 |
| 스플리터 연쇄 분열 → 적 수 폭발 | 분열 세대 제한 (최대 1회) |

---

## 보안 고려사항

싱글플레이 오프라인 게임이므로 보안 위협 최소:
- 네트워크 없음 → 원격 공격 불가
- 세이브 없음 → 세이브 파일 조작 불가
- 리더보드 없음 → 점수 조작 무의미

---

## 리스크 분석

| 리스크 | 영향 | 확률 | 대응 |
|--------|------|------|------|
| Godot 4 MultiMesh 성능 부족 (500+) | 높음 | 낮음 | 프로토타입에서 1000개 테스트. 실패 시 적 수 조정 |
| Flow Field 구현 복잡 | 중간 | 중간 | 단순 BFS 기반. 참고 구현 풍부. 최악의 경우 직선 이동 |
| 시너지 밸런싱 난이도 | 중간 | 높음 | 초기엔 3-4개 시너지만 활성화. 반복 플레이테스트 |
| 1웨이브부터 힘든 밸런스 잡기 어려움 | 중간 | 중간 | 초기 자원/건물 조정으로 해결. 튜토리얼 없이 난이도로 학습 |
| 픽셀아트 에셋 제작 부담 | 중간 | 높음 | 최소한 스프라이트로 시작. 색상 차이로 구분. 나중에 교체 |
| GDScript 학습 곡선 | 낮음 | 낮음 | Python 경험 있으므로 빠른 적응 예상 |

---

## 명확도 추이

| Round | Arch | Decision | Impl | Risk | 모호성 | 타겟 |
|-------|------|----------|------|------|--------|------|
| 0 | 0.3 | 0.0 | 0.3 | 0.3 | 78% | 초기 |
| 1 | 0.5 | 0.5 | 0.3 | 0.3 | 62% | 유닛 처리/길찾기 |
| 2 | 0.6 | 0.6 | 0.3 | 0.3 | 50% | 자원 시스템 |
| 3 | 0.7 | 0.7 | 0.5 | 0.5 | 38% | 시너지 UX |
| 4 | 0.8 | 0.8 | 0.5 | 0.5 | 30% | 보상 시스템 |
| 5 | 0.9 | 0.9 | 0.9 | 0.7 | **16%** | 설계 문서 작성 → **통과** |
