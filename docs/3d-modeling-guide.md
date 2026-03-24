# 3D 모델링 가이드 — Hunyuan3D-2 + Godot 파이프라인

## 1. Hunyuan3D-2 설치 (Windows 원클릭)

### 요구 사양
- NVIDIA GPU 8GB+ VRAM (RTX 3060 이상)
- RAM 24GB+
- 디스크 여유 ~15GB

### 설치 순서

1. **WinPortable 다운로드**
   - https://github.com/YanWenKun/Hunyuan3D-2-WinPortable
   - Releases에서 최신 zip 다운로드

2. **압축 해제**
   - `C:\AI\HY3D2` 같은 짧은 경로에 해제 (긴 경로 오류 방지)

3. **실행**
   - `run.bat` 실행
   - 첫 실행 시 모델 다운로드 (~10GB, 한 번만)
   - 브라우저에서 `http://127.0.0.1:7860` 열림

4. **설정**
   - Mode: "Shape Only" (텍스처 불필요)
   - Low-Poly: 활성화
   - Output Format: GLB

---

## 2. 모델 생성 프롬프트 (20개)

### 사용법
1. Hunyuan3D-2 웹 UI에서 텍스트 프롬프트 입력
2. "Generate" 클릭
3. 마음에 들 때까지 반복 (무제한)
4. GLB로 다운로드
5. `project/assets/models/{카테고리}/` 에 저장

### 건물 (5종)

| 파일명 | 프롬프트 |
|--------|---------|
| `buildings/hq.glb` | dark fantasy fortress headquarters, large stone castle keep, glowing blue magical runes, military fortification, low poly stylized, flat shading, game asset, isometric |
| `buildings/tower.glb` | dark fantasy attack tower with cannon turret, stone military watchtower, compact design, low poly stylized, flat shading, game asset, isometric |
| `buildings/tower_turret.glb` | small cannon turret mechanism, dark metal, military weapon, low poly stylized, flat shading, game asset |
| `buildings/barracks.glb` | dark fantasy military barracks with banner flag, troop recruitment building, wooden and stone, low poly stylized, flat shading, game asset, isometric |
| `buildings/barracks_banner.glb` | medieval banner on pole, blue flag, military standard, low poly stylized, flat shading, game asset |
| `buildings/miner.glb` | dark fantasy mining drill machine, teal crystal glow, mechanical drill, low poly stylized, flat shading, game asset, isometric |
| `buildings/miner_drill.glb` | small mechanical drill bit, teal metal, spinning tool, low poly stylized, flat shading, game asset |
| `buildings/buff_tower.glb` | dark fantasy power beacon tower, golden crystal on top, magical aura, low poly stylized, flat shading, game asset, isometric |
| `buildings/buff_crystal.glb` | floating golden crystal, magical gem, glowing energy, diamond shape, low poly stylized, flat shading, game asset |

> **참고**: 건물은 base_building.gd가 메인 메시를 로드하고, tower/barracks/miner/buff_tower가 추가 파트를 로드합니다. 메인 건물 + 파트를 별도로 만들거나, 한 모델에 합쳐도 됩니다.

### 적 (6종)

| 파일명 | 프롬프트 |
|--------|---------|
| `enemies/rusher.glb` | small fast goblin creature, aggressive charging pose, sharp claws, dark fantasy, red tint, low poly stylized, flat shading, game asset |
| `enemies/tank.glb` | heavy armored beast, thick shell armor plates, dark fantasy, bulky defensive creature, dark gray, low poly stylized, flat shading, game asset |
| `enemies/splitter.glb` | diamond shaped alien creature, crystalline body, dark fantasy, green glow, splitting organism, low poly stylized, flat shading, game asset |
| `enemies/exploder.glb` | spiky explosive creature, swollen body with spines, dark fantasy, orange glow, dangerous volatile, low poly stylized, flat shading, game asset |
| `enemies/elite_rusher.glb` | elite goblin warrior with dark red armor, battle scarred, dark fantasy, glowing red eyes, low poly stylized, flat shading, game asset |
| `enemies/destroyer.glb` | massive boss demon creature, towering imposing figure, dark fantasy, purple dark aura, heavy build, low poly stylized, flat shading, game asset |

### 유닛 (4종)

| 파일명 | 프롬프트 |
|--------|---------|
| `units/soldier.glb` | human infantry soldier with sword and shield, dark fantasy military, blue armor, standing ready pose, low poly stylized, flat shading, game asset |
| `units/archer.glb` | human archer with longbow, dark fantasy military, green hooded cloak, slim build, low poly stylized, flat shading, game asset |
| `units/tanker.glb` | heavy shield warrior, dark fantasy military, golden plate armor, wide stance defensive, low poly stylized, flat shading, game asset |
| `units/bomber.glb` | suicide bomber unit carrying explosive barrel, dark fantasy, red and blue outfit, desperate look, low poly stylized, flat shading, game asset |

### 이펙트 (2종)

| 파일명 | 프롬프트 |
|--------|---------|
| `effects/projectile.glb` | magical energy orb projectile, glowing yellow fireball, small sphere with trail, low poly stylized, flat shading, game asset |
| `effects/mineral_orb.glb` | small glowing crystal orb, teal cyan energy, floating magical mineral, low poly stylized, flat shading, game asset |

---

## 3. Godot에 배치

### 파일 저장 위치

```
project/assets/models/
├── buildings/
│   ├── hq.glb
│   ├── tower.glb
│   ├── tower_turret.glb
│   ├── barracks.glb
│   ├── barracks_banner.glb
│   ├── miner.glb
│   ├── miner_drill.glb
│   ├── buff_tower.glb
│   └── buff_crystal.glb
├── enemies/
│   ├── rusher.glb
│   ├── tank.glb
│   ├── splitter.glb
│   ├── exploder.glb
│   ├── elite_rusher.glb
│   └── destroyer.glb
├── units/
│   ├── soldier.glb
│   ├── archer.glb
│   ├── tanker.glb
│   └── bomber.glb
└── effects/
    ├── projectile.glb
    └── mineral_orb.glb
```

### 자동 동작

GLB 파일을 위 경로에 넣으면:
1. Godot 에디터가 자동으로 임포트
2. 코드가 `_load_glb()`로 자동 로드
3. GLB가 없는 엔티티는 기존 프리미티브로 폴백

**코드 수정 필요 없음** — 이미 모든 파일에 GLB 로딩 + 폴백 코드가 적용되어 있습니다.

---

## 4. 크기 조정

모델이 너무 크거나 작으면:
1. Godot 에디터에서 `.glb.import` 파일의 scale 조정
2. 또는 Hunyuan3D-2에서 재생성 시 크기 힌트 추가 ("small", "tiny", "large")

### 기준 크기 (Godot 단위)

| 엔티티 | 높이 | 비고 |
|--------|------|------|
| HQ | ~1.5 | 3x3 그리드 |
| Tower | ~1.0 | 1x1 그리드 |
| Barracks | ~0.8 | 2x1 그리드 |
| Rusher | ~0.3 | 가장 작은 적 |
| Tank | ~0.55 | 육중한 적 |
| Destroyer | ~0.9 | 보스급 |
| Soldier | ~0.6 | 표준 유닛 |

---

## 5. 문제 해결

### "모델이 안 보여요"
- 파일명이 정확한지 확인 (소문자, 언더스코어)
- Godot 에디터를 열어 임포트 확인 (FileSystem 탭)

### "모델이 너무 크거나 작아요"
- `.glb.import` 파일에서 `_subresources` > `nodes` > `scale` 조정
- 또는 코드에서 `_mesh_instance.scale` 수정

### "모델 색상이 이상해요"
- 정상입니다. material_override로 코드에서 색상을 덮어씁니다.
- 모델 자체 색상은 무시되고, 게임 데이터(data.color)가 적용됩니다.

### "Hunyuan3D 실행 안 돼요"
- CUDA 드라이버 최신 버전 확인
- 폴백: Tripo3D (https://tripo3d.ai) 무료 웹 서비스 사용
