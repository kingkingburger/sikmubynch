# SIKMUBYNCH - 구현 로드맵 설계

> Ouroboros Phase 2 | 2026-03-20 | 모호성: 13%

## ADR (Architecture Decision Records)

### ADR-R1: 마일스톤별 점진적 렌더링

- **결정**: M1~M3은 적을 Node2D로, M4부터 EnemyPool + MultiMesh 도입
- **대안**: M1부터 MultiMesh / M7에서 일괄 전환
- **선택 근거**:
  - M1~M3은 적 100마리 이하 → Node2D로 충분, 개발 속도 우선
  - M4에서 웨이브 시스템 도입 시 200+ 적 필요 → MultiMesh 필수
  - M7에서 일괄 전환은 대규모 리팩토링 리스크
  - EnemyPool이 Node2D↔MultiMesh 전환을 캡슐화하므로 리팩토링 최소화

### ADR-R2: 적 이동 점진적 고도화

- **결정**: M1~M3은 직선 이동 + 건물 충돌(부수기), M4에서 Flow Field 도입
- **대안**: M1부터 Flow Field / M1 직선이동만(건물 무시)
- **선택 근거**:
  - M1부터 건물 충돌이 있어야 바리케이드 배치가 의미 있음 (게임 경험)
  - 직선 이동 + 충돌은 구현 단순하면서도 게임플레이 핵심 제공
  - Flow Field는 M4에서 건물 우회 경로가 필요할 때 도입 (전략적 깊이)

### ADR-R3: 타격감 후순위 집중

- **결정**: M1~M5는 기능 우선(타격감 없음), M6에서 타격감 집중 추가
- **대안**: M2부터 기본 타격감 점진적 추가
- **선택 근거**:
  - 핵심 가치 1위가 타격감이지만, 모든 전투 시스템이 갖춰져야 타격감 튜닝이 의미 있음
  - M6에서 모든 전투 상황(유닛, 건물, 대량 적, 정예)에 맞춤 타격감 설계 가능
  - 기능 미완성 상태에서의 타격감 작업은 재작업 가능성 높음

### ADR-R4: 지연 시 범위 축소

- **결정**: 마일스톤 지연 시 기능 범위를 축소하고 미완 기능은 다음 마일스톤으로 이월
- **대안**: 시간 연장 / 품질 타협
- **선택 근거**:
  - 각 마일스톤이 플레이 가능한 빌드를 산출하는 것이 최우선
  - 범위 축소로 피드백 루프 유지
  - 이월된 기능은 다음 마일스톤 시작 전에 삽입

---

## 마일스톤별 파일/씬 매핑

### M1: 코어 루프

```
project/
├── project.godot                          # Godot 4 프로젝트 설정
├── autoloads/
│   └── game_manager.gd                    # 게임 상태 (런, 자원, 게임오버)
├── scenes/
│   ├── main/
│   │   ├── game.tscn                      # 메인 게임 씬
│   │   └── game.gd                        # 게임 초기화, 입력 처리
│   ├── buildings/
│   │   ├── base_building.tscn             # 건물 베이스 (HP, 파괴)
│   │   ├── base_building.gd
│   │   ├── hq.tscn                        # 본진 (3x3, HP 1000, 자동회복)
│   │   └── barricade.tscn                 # 바리케이드 (1x1, HP 50, 클릭 배치)
│   ├── enemies/
│   │   ├── enemy.tscn                     # 적 Node2D (M1~M3용)
│   │   └── enemy.gd                       # 직선 이동 + 건물 충돌 + 공격
│   └── ui/
│       └── game_over.tscn                 # 게임오버 (웨이브 수 + 재시작)
├── scripts/
│   ├── data/
│   │   ├── building_data.gd               # BuildingData Resource 클래스
│   │   └── enemy_data.gd                  # EnemyData Resource 클래스
│   └── systems/
│       └── building_placer.gd             # 건물 배치 (그리드 스냅, 유효성)
├── resources/
│   ├── buildings/
│   │   ├── building_hq.tres
│   │   └── building_barricade.tres
│   └── enemies/
│       └── enemy_rusher.tres              # 러셔 데이터
└── assets/
    └── sprites/
        └── placeholder/                   # 색상 사각형/원 플레이스홀더
```

**핵심 기술 결정**:
- TileMap으로 64x64 그리드 (정적 맵, 중앙 본진)
- 적은 Node2D + 직선 이동 (본진 방향 Vector2)
- 건물 충돌: 적의 경로에 건물이 있으면 공격 → 파괴 → 전진
- 미네랄: 적 사망 시 GameManager에 직접 추가 (오브 연출은 M6)

---

### M2: 전투 기반

```
추가/수정 파일:
├── scenes/
│   ├── buildings/
│   │   └── tower.tscn                     # 타워 (DPS 15, 사거리 6, 자동 사격)
│   ├── projectiles/
│   │   ├── projectile.tscn                # 발사체 씬
│   │   └── projectile.gd                  # 발사체 이동 + 적중 판정
│   └── ui/
│       ├── hud.tscn                       # 상단 HUD (미네랄, 웨이브 수)
│       └── build_menu.tscn               # 건설 메뉴 (숫자키 1~3)
├── scripts/
│   └── systems/
│       └── combat_system.gd               # 사거리 판정, 타겟 선택
├── resources/
│   └── buildings/
│       └── building_tower.tres
```

**수정**: `base_building.gd`에 레벨업/철거 로직 추가, `game_manager.gd`에 경제 시스템(미네랄 수입/지출) 추가

**핵심 기술 결정**:
- 타워 타겟팅: 가장 가까운 적 (Area2D 사거리 감지)
- 발사체: Node2D + 속도/방향, 적중 시 데미지 + queue_free()
- 경제: 적 처치 보상(즉시 미네랄 추가) + 건설 비용 차감

---

### M3: 유닛 시스템

```
추가/수정 파일:
├── scenes/
│   ├── buildings/
│   │   └── barrack.tscn                   # 배럭 (유닛 자동 생산, 8초 간격)
│   └── units/
│       ├── base_unit.tscn                 # 유닛 베이스 (이동, 공격, 사망)
│       ├── base_unit.gd                   # 자동전투 AI (순찰 + 공격)
│       ├── soldier.tscn
│       ├── archer.tscn
│       ├── tanker.tscn
│       └── bomber.tscn                    # 폭탄병 (자폭, 아군 피해 없음)
├── scripts/
│   └── data/
│       └── unit_data.gd                   # UnitData Resource 클래스
├── resources/
│   ├── buildings/
│   │   └── building_barrack.tres
│   └── units/
│       ├── unit_soldier.tres
│       ├── unit_archer.tres
│       ├── unit_tanker.tres
│       └── unit_bomber.tres
```

**핵심 기술 결정**:
- 유닛 AI: NavigationAgent2D 없이 단순 상태머신 (Idle→Patrol→Chase→Attack)
- 순찰: 랜덤 방향 이동 → 적 감지(Area2D) → 추격 → 공격
- 배럭 생산: Timer(8초) + 4종 중 랜덤 선택 + 인스턴스화
- 유닛 수 ~50 이하이므로 Node2D 성능 문제 없음

---

### M4: 웨이브 + 적 다양성

```
추가/수정 파일:
├── autoloads/
│   ├── wave_manager.gd                    # 웨이브 스폰, 난이도, 파도형 패턴
│   ├── enemy_pool.gd                      # Object Pool + MultiMesh 전환
│   └── flow_field.gd                      # BFS 기반 Flow Field
├── scenes/
│   └── enemies/
│       └── enemy_renderer.tscn            # MultiMeshInstance2D (적 렌더링)
├── scripts/
│   └── utils/
│       └── object_pool.gd                 # 범용 Object Pool
├── resources/
│   ├── enemies/
│   │   ├── enemy_splitter.tres
│   │   ├── enemy_exploder.tres
│   │   ├── enemy_tank.tres
│   │   ├── enemy_elite_rusher.tres
│   │   └── enemy_destroyer.tres
│   └── waves/
│       └── wave_config.tres               # 웨이브 스케일링 설정
```

**핵심 기술 결정**:
- **Node2D → MultiMesh 전환**: EnemyPool이 기존 enemy.gd 로직을 데이터 배열로 이전. MultiMeshInstance2D로 렌더링
- **Flow Field**: 64x64 BFS, 건물 배치/파괴 시 재계산. 적은 Flow Field 방향벡터 따라 이동
- **웨이브**: 45초 간격, 잔잔↔폭풍 교대, 스폰 초당 50마리 제한
- **스플리터**: 사망 시 2마리 분열 (1회 한정, 풀에서 추가 할당)

---

### M5: 메타 시스템

```
추가/수정 파일:
├── autoloads/
│   ├── synergy_manager.gd                 # 특성 추적, 시너지 발동/해제
│   └── reward_manager.gd                  # 보상 생성, 희귀도
├── scenes/
│   ├── buildings/
│   │   ├── miner.tscn                     # 채굴기 (미네랄 노드 위만)
│   │   └── buff_tower.tscn               # 버프 타워 (7x7 범위)
│   └── ui/
│       ├── reward_picker.tscn             # 보상 3택 카드 UI
│       ├── reward_picker.gd
│       └── synergy_bar.tscn              # 좌측 시너지 바
├── scripts/
│   └── data/
│       ├── trait_data.gd                  # TraitData Resource
│       ├── synergy_data.gd               # SynergyData Resource
│       └── reward_data.gd                # RewardData Resource
├── resources/
│   ├── traits/
│   │   ├── trait_fire/ice/poison/electric/fortify.tres
│   ├── synergies/
│   │   ├── (5특성 x 3단계 + 크로스 2종).tres
│   ├── buildings/
│   │   ├── building_miner.tres
│   │   └── building_buff_tower.tres
│   └── rewards/
│       └── reward_pool.tres               # 보상 풀 정의
```

**핵심 기술 결정**:
- **SynergyManager**: Signal 기반 (synergy_activated/deactivated). 유닛/건물 배치/제거 시 재계산
- **보상 3택**: RewardManager가 풀에서 3개 랜덤 (중복 불가, 희귀도 가중치)
- **이벤트**: 전투 변수(자동) + 선택형(UI 팝업, 거절 불가). WaveManager에서 트리거
- **미네랄 노드**: TileMap 레이어에 표시, 채굴기 배치 유효성 검사

---

### M6: 게임 필

```
추가/수정 파일:
├── autoloads/
│   └── game_feel.gd                       # 화면 흔들림, 히트스톱, 플래시
├── scenes/
│   ├── main/
│   │   └── camera.gd                      # WASD 이동, 휠 줌 (0.5x~2x)
│   ├── effects/
│   │   ├── hit_effect.tscn               # 히트 파티클
│   │   ├── death_effect.tscn             # 사망 파티클
│   │   ├── synergy_aura.tscn             # 시너지 오라
│   │   └── mineral_orb.tscn              # 미네랄 오브 (적→본진 비행)
│   └── ui/
│       ├── minimap.tscn                   # 우하단 미니맵 (클릭 이동)
│       ├── start_screen.tscn             # 시작 화면
│       └── settings_menu.tscn            # ESC 메뉴 (재시작+나가기)
├── scripts/
│   └── systems/
│       └── map_generator.gd               # 절차적 맵 생성 + 경로 유효성 검증
├── assets/
│   └── audio/
│       └── sfx/                           # 9종 효과음
```

**핵심 기술 결정**:
- **GameFeel**: screen_shake(Camera2D offset), hitstop(Engine.time_scale), flash(셰이더), 파티클(GPUParticles2D 풀)
- **맵 생성**: BSP 또는 셀룰러 오토마타 → 미네랄/장애물/통로 배치 → BFS 경로 검증 → 실패 시 재생성
- **미니맵**: SubViewport로 전체 맵 렌더링 → TextureRect에 표시
- **사운드**: AudioStreamPlayer2D (공간감) + AudioStreamPlayer (UI)

---

### M7: 폴리시

```
수정/추가:
├── 밸런싱 → resources/ 내 .tres 파일 수치 조정
├── 성능 → enemy_pool.gd MultiMesh 튜닝, 파티클 풀 최적화
├── 에셋 → assets/sprites/ 플레이스홀더 → 픽셀아트 교체
├── 레벨 시각 → 건물별 Lv1/Lv2/Lv3 스프라이트 추가
├── 디버그 → F3 오버레이 (fps, 적 수, 풀 상태, 메모리)
└── 버그 → 플레이테스트 기반 수정
```

---

## 마일스톤별 리스크

| 마일스톤 | 핵심 리스크 | 완화 전략 |
|---------|-----------|----------|
| M1 | Godot 4 학습 곡선 | 공식 튜토리얼 병행, 단순 구현 |
| M2 | 발사체 물리 판정 정확도 | Area2D 단순 판정, 복잡한 물리 피함 |
| M3 | 유닛 AI 무한 루프/정체 | 상태머신 타임아웃, 강제 리셋 |
| M4 | **MultiMesh 전환 리팩토링** | EnemyPool 캡슐화로 최소화 |
| M4 | **Flow Field 구현 복잡도** | 단순 BFS, 참고 자료 풍부 |
| M5 | 시너지 조합 폭발적 복잡도 | 5특성 x 3단계로 한정, 점진적 추가 |
| M6 | 타격감 + 성능 충돌 | 파티클 풀 제한, 이펙트 큐잉 |
| M7 | 500적 60fps 미달 | 적 수 하향 또는 LOD 적용 |

---

## 지연 시 범위 축소 가이드

```
원칙: 플레이 가능한 빌드 우선. 미완 기능은 다음 마일스톤 앞에 삽입.

예시:
  M4 지연 시:
    원래: 웨이브 + 적 6종 + Flow Field + MultiMesh
    축소: 웨이브 + 적 3종(러셔/탱크/스플리터) + MultiMesh
    이월: 나머지 적 3종 + Flow Field → M5 앞에 삽입

  M5 지연 시:
    원래: 시너지 5특성x3단계 + 보상 + 이벤트 + 채굴기 + 버프타워
    축소: 시너지 3특성x2단계 + 보상 기본
    이월: 나머지 시너지 + 이벤트 + 채굴기/버프타워 → M6 앞에 삽입
```

---

## 통신 아키텍처 (02-design.md 기반)

```
Signal 기반 느슨한 결합 (전 마일스톤 공통):

M1: 적 사망 → GameManager.add_mineral()
M2: 타워 공격 → Projectile 생성 → 적중 → 적 HP 감소
M3: 배럭 Timer → 유닛 인스턴스화 → 유닛 AI 순찰
M4: WaveManager → EnemyPool.spawn() → FlowField.get_direction()
M5: 건물/유닛 배치 → SynergyManager.recalculate() → signal → UI/필드
M6: 적 사망 → GameFeel.play_death_effect() + mineral_orb 생성
M7: 전체 시스템 프로파일링 + 밸런싱
```

---

## 명확도 추이

| Round | Arch | Decision | Impl | Risk | 모호성 | 타겟 |
|-------|------|----------|------|------|--------|------|
| 0 | 0.7 | 0.5 | 0.3 | 0.5 | 48% | 초기 |
| 1 | 0.7 | 0.7 | 0.3 | 0.5 | 41% | Decision (타격감 M6 확정) |
| 2 | 0.7 | 0.7 | 0.3 | 0.7 | 38% | Risk (지연 시 범위 축소) |
| 3 | 0.9 | 0.9 | 0.9 | 0.7 | **13%** | Impl (자율 파일 매핑 + 적 이동 확정) → **통과** |
