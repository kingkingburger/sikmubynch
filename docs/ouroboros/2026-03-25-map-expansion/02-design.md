# Phase 2: 설계 — 대규모 맵 확장

## ADR (Architecture Decision Records)

### ADR-1: 맵 크기 256x256

**결정:** MAP_SIZE = 256
**대안:** 128(너무 작음), 512(FlowField 비용 폭발)
**근거:** 256은 현재 대비 16배 면적, They Are Billions급 스케일. FlowField BFS 65,536셀은 청크 기반으로 관리 가능.

### ADR-2: 2단계 계층적 길찾기

**결정:** Global 청크 그래프(8x8) + Local BFS(32x32 청크 내)
**대안 1:** 전체 256x256 BFS — O(65536), 매 프레임 불가
**대안 2:** A* 개별 적 — 1000적 × A* = CPU 폭발
**근거:** 2단계 분리로 글로벌 경로는 건물 변경 시에만 재계산(8x8=64셀 BFS), 로컬은 적이 청크 진입 시 32x32 BFS(1024셀). 전체 재계산 대비 64배 절약.

### ADR-3: SpatialGrid 확장

**결정:** CELL_SIZE=8.0, GRID_W=32 (256/8=32)
**대안:** CELL_SIZE=4 → GRID_W=64(너무 많은 셀), CELL_SIZE=16 → GRID_W=16(셀 너무 큼)
**근거:** 셀당 평균 적 밀도 유지. 탐색 범위 10.0 기준 ceil(10/8)=2 → 5x5=25셀 검색, 현재와 유사.

### ADR-4: 안개(Fog of War) 구현

**결정:** Visibility 텍스처(256x256 Image) + 지면 셰이더 곱연산
**대안:** 3D 볼륨 포그(GL Compat 미지원), 타일별 메쉬(느림)
**근거:** Image.set_pixel로 시야 업데이트 → ImageTexture → 셰이더 uniform. GPU에서 처리하므로 CPU 비용 거의 없음. GL Compatibility에서 동작.

### ADR-5: 미니맵

**결정:** SubViewport(128x128) + top-down 직교 카메라
**대안:** 수동 2D 렌더링(복잡), TextureRect에 직접 그리기(느림)
**근거:** SubViewport는 Godot 4 빌트인. 저해상도 탑다운 뷰를 자동 렌더링. 클릭으로 카메라 이동도 쉽게 구현.

---

## 시스템 설계

### 1. 맵 시스템 (game.gd)

```
변경 사항:
- MAP_SIZE: 64 → 256
- 지면 PlaneMesh: 256x256
- 지면 셰이더: UV 스케일 256
- HQ 위치: (128.5, 0, 128.5)
- 카메라 초기 중심: (128, 128)
- 카메라 줌 범위: 18 ~ 120
- 카메라 팬 범위: [0, 256]
- 경계 벽: 256 크기로 확장
```

### 2. FlowField 재설계 (flow_field.gd)

```
구조:
- CHUNK_SIZE = 32 (256/32 = 8x8 청크)
- _global_graph: Dictionary[Vector2i, Array[Vector2i]]  # 청크 간 연결 그래프
- _chunk_fields: Dictionary[Vector2i, Dictionary]        # 청크별 방향 필드
- _obstacles: Dictionary[Vector2i, bool]                 # 셀 단위 장애물

흐름:
1. recalculate_global(hq_chunk) — 8x8 BFS로 청크 간 경로 계산
2. recalculate_chunk(chunk_pos) — 해당 청크 32x32 내부 BFS
3. get_direction(world_pos) — 글로벌 방향 + 로컬 방향 합성

재계산 트리거:
- 건물 배치/파괴 시 → 해당 청크 + 인접 청크만 재계산
- HQ 변경 시 → 글로벌 재계산
```

### 3. SpatialGrid 확장 (spatial_grid.gd)

```
변경 사항:
- CELL_SIZE: 4.0 → 8.0
- GRID_W: 16 → 32
- _pos_to_cell 로직 동일 (pos / CELL_SIZE, clamp 0..31)
```

### 4. Fog of War 시스템 (신규: fog_of_war.gd autoload)

```
구조:
- _visibility: Image (256x256, FORMAT_R8)
- _texture: ImageTexture
- SIGHT_RANGES: { "buildings": 12, "units": 8 }

메서드:
- update_visibility() — 매 0.5초마다 호출
  - Image 전체를 0(안개)으로 초기화
  - 모든 건물/유닛 주변 원형 영역을 255(보임)로 설정
  - ImageTexture 갱신
- get_visibility(x, z) -> bool — 해당 셀이 보이는지
- get_texture() -> ImageTexture — 셰이더에 전달

지면 셰이더 수정:
- uniform sampler2D fog_texture;
- float vis = texture(fog_texture, UV).r;
- ALBEDO *= mix(0.15, 1.0, vis);  // 안개 영역은 어둡게
```

### 5. 자원 지대 시스템 (game.gd 확장)

```
구조:
- ResourceZone: { position: Vector2i, radius: int, bonus: float }
- _resource_zones: Array[ResourceZone] — 8개 고정 위치

배치 (256x256 맵):
- HQ 주변 (128,128): 기본 영역
- NW (48, 48), NE (208, 48), SW (48, 208), SE (208, 208): 4 코너
- N (128, 32), E (224, 128), S (128, 224), W (32, 128): 4 변
- 총 8개 자원 지대

지면 셰이더에 자원 지대 표시 (밝은 청록색 하이라이트)

채굴기 배치:
- 자원 지대 내 채굴기 → 수입 2x 보너스
- 자원 지대 밖 채굴기 → 기본 수입
```

### 6. 스폰 시스템 확장 (game.gd)

```
변경 사항:
- _random_edge_position(): MAP_SIZE 256 기반
- 웨이브별 스폰 방향:
  - 웨이브 1-2: 1방향 (북)
  - 웨이브 3-4: 2방향 (북+동)
  - 웨이브 5+: 4방향 전체
  - 보스 웨이브: 전방향 동시 + 대형 적
- 스폰 수량: 현재 × 2 (넓은 맵에 맞게)
```

### 7. 미니맵 UI (game.gd)

```
구조:
- SubViewport (128x128) + orthogonal Camera3D (top-down)
- TextureRect (180x180, 우측 하단)
- 카메라 시야 표시 (흰 사각형)
- 건물: 파란 점, 적: 빨간 점, 자원지대: 청록 영역
- 클릭 시 메인 카메라 이동
```

### 8. 유닛/적 범위 조정

```
변경 사항:
- unit.gd: patrol clamp [1.0, 255.0]
- unit.gd: DETECTION_RANGE 10.0 → 12.0
- unit.gd: PATROL_RADIUS 5.0 → 8.0
- enemy.gd: 경계 클램프 없음 (FlowField가 안내)
- barracks.gd: 스폰 위치 클램프 [1.0, 255.0]
```

---

## 파일별 구현 계획

| 파일 | 작업 | 변경 규모 |
|------|------|-----------|
| `game.gd` | MAP_SIZE 256, HQ위치, 카메라, 지면, 스폰, 자원지대, 미니맵 UI | 대규모 |
| `flow_field.gd` | 2단계 계층적 길찾기 전면 재작성 | 전면 재작성 |
| `spatial_grid.gd` | CELL_SIZE=8, GRID_W=32 | 소규모 (상수만) |
| `fog_of_war.gd` (신규) | Visibility Image + 셰이더 연동 | 신규 생성 |
| `project.godot` | FogOfWar autoload 등록 | 1줄 |
| `unit.gd` | 순찰 범위/클램프 조정 | 소규모 |
| `enemy.gd` | 경계 관련 없음 (FlowField 의존) | 없음 |
| `barracks.gd` | 스폰 위치 클램프 조정 | 소규모 |

---

## 엣지케이스

1. **FlowField 경로 없음** — 건물로 완전 차단 시 적이 가장 가까운 건물 공격
2. **안개 밖 건물 파괴** — 플레이어에게 알림 표시 (건물 파괴 이벤트)
3. **맵 경계 빌딩** — (0,0)~(255,255) 범위 내에서만 배치
4. **카메라 줌 아웃 최대** — 전체 맵 보이지만 엔티티 매우 작음 → 미니맵 참조 유도
5. **청크 경계 이동** — 적이 청크 넘을 때 새 청크 필드 조회, 없으면 계산

## 보안 고려사항

- 싱글 플레이 PC 전용 → 별도 보안 불필요
- 세이브 데이터 변조 → 현재 세이브 시스템 없음, 스코프 외

## 명확도 추이

| Round | Architecture | Decision Rationale | Implementation | Risk | 모호성 |
|-------|-------------|-------------------|----------------|------|--------|
| 1 | 0.9 | 0.9 | 0.7 | 0.7 | 17.0% |

**Phase 2 품질 게이트 통과 (17.0% ≤ 20%)**
