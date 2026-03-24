# SIKMUBYNCH - 3D 모델링 파이프라인 설계

> Ouroboros Phase 2 | 2026-03-24 | 모호성: 18%

## ADR (Architecture Decision Records)

### ADR-M1: AI 도구 선택 — Hunyuan3D-2 로컬

- **결정**: Hunyuan3D-2 오픈소스를 로컬 실행하여 모델 생성
- **대안**: Meshy Pro ($20/월) / Tripo 무료 (상업 불가) / Rodin ($0.4/개)
- **선택 근거**:
  - 완전 무료, 횟수 무제한, 상업적 사용 가능 (오픈소스)
  - Windows 원클릭 인스톨러 존재 (WinPortable)
  - 내장 Low-Polygon Stylization Module로 로우폴리 변환 지원
  - RTX 30시리즈 8GB VRAM으로 Shape+Texture 모두 실행 가능
  - GLB 직접 출력 지원
  - 현존 오픈소스 중 최고 품질

### ADR-M2: Material 전략 — material_override 유지

- **결정**: GLB에서 메시(형태)만 사용하고, 색상/이미션/플래시는 기존 코드 유지
- **대안**: GLB 내장 material 사용
- **선택 근거**:
  - 코드 변경 최소화 (`_build_mesh()` 내 메시 생성 부분만 교체)
  - 기존 피격 플래시, HP 색상 변화, 이미션 시스템 100% 보존
  - 플랫 색상 스타일이므로 GLB에 복잡한 재질 불필요
  - 레벨업 스케일 변경 코드도 그대로 동작

### ADR-M3: 후처리 — Hunyuan3D 내장 리듀서 (Blender 없이)

- **결정**: Hunyuan3D-2 내장 Low-Polygon Stylization Module + face_reducer로 직접 ~1,000 tri GLB 출력
- **대안**: Blender Decimate 후처리 / Godot 임포트 시 메시 단순화
- **선택 근거**:
  - 사용자가 Blender를 모르고 설치하지 않음
  - Hunyuan3D-2에 내장 로우폴리 모듈이 있어 별도 후처리 불필요
  - 폴리곤이 높을 경우 face_reducer 파라미터로 재생성
  - 최후 수단: Godot 임포트 설정에서 메시 단순화 옵션 사용
  - Blender 자동화 스크립트는 추후 필요 시 도입 가능

### ADR-M4: 일괄 교체 전략

- **결정**: 모든 20개 에셋을 한 번에 제작하고 일괄 교체
- **대안**: 건물→적→유닛 순서로 단계적 교체
- **선택 근거**:
  - 비주얼 통일성이 상용 기준의 핵심 (일부만 교체하면 어색)
  - Phase 1에서 사용자가 "한 번에 전체" 선택
  - 폴백: 개별 GLB 교체 실패 시 해당 엔티티만 프리미티브 유지 (코드에서 load 실패 시 폴백)

---

## 파이프라인 설계

### 전체 워크플로우

```
[1] Hunyuan3D-2 로컬 설치
    └─ WinPortable 원클릭 인스톨러
    └─ VRAM 8GB+, RAM 24GB+

[2] 프롬프트로 모델 생성 (20개)
    └─ 텍스트 프롬프트: "dark fantasy {엔티티} low poly flat shading military style"
    └─ 마음에 들 때까지 반복 생성
    └─ Shape only 모드 (텍스처 불필요)

[3] 폴리곤 조절 (Blender 없이)
    └─ Hunyuan3D 내장 face_reducer로 ~1,000 tri 타겟
    └─ Low-Polygon Stylization Module 활용
    └─ 부족 시 재생성 (프롬프트 수정, 최대 5회)
    └─ 최후 수단: Godot 임포트 메시 단순화 옵션

[4] Godot 프로젝트에 배치
    └─ project/assets/models/{category}/{name}.glb
    └─ _build_mesh() 코드 수정: load("res://assets/models/...")
    └─ material_override 기존 코드 유지

[5] 검증
    └─ 전체 엔티티 렌더링 확인
    └─ 기능 회귀 테스트 (전투, 배치, 시너지)
    └─ 성능 벤치마크 (500적 60fps)
```

---

## 파일 구조

```
project/assets/models/
├── buildings/
│   ├── hq.glb              # 본진 (3x3)
│   ├── tower.glb            # 공격 타워
│   ├── tower_turret.glb     # 타워 포탑 (별도)
│   ├── barracks.glb         # 배럭
│   ├── miner.glb            # 채굴기
│   └── buff_tower.glb       # 버프 타워
├── enemies/
│   ├── rusher.glb           # 러셔
│   ├── tank.glb             # 탱크
│   ├── splitter.glb         # 스플리터
│   ├── exploder.glb         # 폭발형
│   ├── elite_rusher.glb     # 엘리트 러셔
│   └── destroyer.glb        # 파괴자
├── units/
│   ├── soldier.glb          # 솔저
│   ├── archer.glb           # 아처
│   ├── tanker.glb           # 탱커
│   └── bomber.glb           # 폭탄병
└── effects/
    ├── projectile.glb       # 발사체
    └── mineral_orb.glb      # 미네랄 오브
```

---

## 코드 교체 설계

### 공통 패턴: GLB 로드 + 폴백

```gdscript
# 모든 _build_mesh()에 적용할 패턴
var model_path := "res://assets/models/%s/%s.glb" % [category, model_name]
var loaded = load(model_path)
if loaded is PackedScene:
    var instance = loaded.instantiate()
    # PackedScene에서 MeshInstance3D 찾기
    for child in instance.get_children():
        if child is MeshInstance3D:
            _mesh_instance.mesh = child.mesh
            break
    instance.queue_free()
elif loaded is Mesh:
    _mesh_instance.mesh = loaded
else:
    # 폴백: 기존 프리미티브
    _create_primitive_mesh()
```

### 수정 대상 파일 (7개)

| 파일 | 함수 | 변경 내용 |
|------|------|----------|
| `base_building.gd` | `_build_mesh()` L43 | BoxMesh → load GLB (building 타입별 분기) |
| `tower.gd` | `_setup_turret()` L17 | CylinderMesh → load tower_turret.glb |
| `barracks.gd` | `_setup_banner()` L60 | BoxMesh 배너 → barracks.glb에 포함 |
| `miner.gd` | `_setup_drill()` L12 | CylinderMesh → miner.glb에 포함 |
| `buff_tower.gd` | `_setup_aura()` L13 | CylinderMesh+BoxMesh → buff_tower.glb |
| `enemy.gd` | `_build_mesh()` L34 | match문 6종 → load GLB (타입별 파일명) |
| `unit.gd` | `_build_mesh()` L38 | match문 4종 → load GLB (타입별 파일명) |

### 변경하지 않는 것

- 그림자 (QuadMesh) — 메시 독립, 코드 유지
- HP바 (BoxMesh) — 동적 크기, 코드 유지
- 콜리전 (BoxShape3D/SphereShape3D/CapsuleShape3D) — 메시 독립, 코드 유지
- material_override 로직 — 색상/이미션/피격 플래시 모두 유지
- 레벨업 스케일 — `_mesh_instance.scale` 코드 유지
- 오라 링 (buff_tower) — 이펙트성 메시, 코드 유지 고려

---

## Hunyuan3D-2 프롬프트 설계

### 공통 프롬프트 구조

```
{entity description}, dark fantasy military style, low poly stylized,
flat shading, solid color, game asset, isometric view, {size hint}
```

### 엔티티별 프롬프트

| 엔티티 | 프롬프트 |
|--------|---------|
| HQ | "large dark fortress headquarters, dark fantasy military, low poly, flat shading, 3x3 base, glowing blue accents" |
| Tower | "dark stone attack tower with cannon, military fortification, low poly, flat shading, compact 1x1 base" |
| Barracks | "dark military barracks with banner, troop production building, low poly, flat shading, rectangular 2x1 base" |
| Miner | "mining drill machine, dark fantasy, teal glow, low poly, flat shading, small 1x1 base" |
| Buff Tower | "golden crystal power beacon, dark fantasy buff tower, low poly, flat shading, glowing aura" |
| Rusher | "small fast goblin creature, dark fantasy, aggressive pose, low poly, flat shading, red tint" |
| Tank | "heavy armored beast, dark fantasy, bulky, low poly, flat shading, dark gray" |
| Splitter | "diamond-shaped splitting creature, dark fantasy, green tint, low poly, flat shading" |
| Exploder | "spiky explosive creature, dark fantasy, orange glow, low poly, flat shading, dangerous" |
| Elite Rusher | "elite goblin warrior, dark fantasy, dark red glow, low poly, flat shading, battle-hardened" |
| Destroyer | "massive boss creature, dark fantasy, purple aura, low poly, flat shading, imposing" |
| Soldier | "human soldier with sword, dark fantasy military, blue armor, low poly, flat shading" |
| Archer | "human archer with bow, dark fantasy military, green cloak, low poly, flat shading, slim" |
| Tanker | "heavy shield warrior, dark fantasy military, golden armor, low poly, flat shading, bulky" |
| Bomber | "suicide bomber unit, dark fantasy, red and blue, low poly, flat shading, explosive pack" |

---

## 모델 후처리 체크리스트 (모델당, Blender 없이)

1. [ ] Hunyuan3D-2에서 face_reducer로 ~1,000 tri 생성
2. [ ] GLB 직접 출력
3. [ ] Godot에서 임포트 후 크기 확인 (1 unit = 1 그리드 셀)
   - 건물: HQ ~3x3, Tower ~0.5 높이, Barracks ~1x2
   - 적: Rusher ~0.5, Tank ~0.6, Destroyer ~0.9
   - 유닛: Soldier ~0.6 높이, Tanker ~0.55
4. [ ] 크기 불일치 시 코드에서 `_mesh_instance.scale` 조정
5. [ ] Origin point 불일치 시 코드에서 `_mesh_instance.position.y` 조정
6. [ ] 폴리곤 초과 시 재생성 (프롬프트 수정, 최대 5회)

---

## 리스크와 완화

| 리스크 | 심각도 | 완화 전략 |
|--------|--------|----------|
| AI 생성 품질 불균일 | 중 | 마음에 들 때까지 반복 생성 + Blender 수정 |
| Decimate로 형태 손상 | 중 | Decimate ratio 점진적 조절, 수동 정리 |
| GLB 임포트 시 스케일 불일치 | 낮 | Blender에서 미리 Godot 스케일로 정규화 |
| 성능 저하 (1K tri × 500적) | 중 | 프리미티브보다 무거울 수 있음 → 프로파일링 후 판단 |
| 스타일 통일성 부족 | 높 | 동일 프롬프트 구조 + Blender에서 색상 팔레트 통일 |
| Hunyuan3D-2 설치 실패 | 낮 | 폴백: Tripo 무료 웹 서비스 |

---

## 명확도 추이

| Round | Arch | Decision | Impl | Risk | 모호성 | 타겟 |
|-------|------|----------|------|------|--------|------|
| 0 | 0.7 | 0.3 | 0.5 | 0.5 | 48% | 초기 |
| 1 | 0.7 | 0.5 | 0.5 | 0.5 | 42% | Decision (Meshy 제안) |
| 2 | 0.7 | 0.5 | 0.5 | 0.5 | 42% | Decision (무료 우선) |
| 3 | 0.7 | 0.7 | 0.5 | 0.7 | 24% | Decision (Hunyuan3D + GPU 확인) |
| 4 | 0.9 | 0.9 | 0.5 | 0.7 | 22% | Impl (material 방식 설명) |
| 5 | 0.9 | 0.9 | 0.7 | 0.7 | **18%** | Impl (방식 A 확정) → **통과** |
