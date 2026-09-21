# assets_src — AI 생성 원본 이미지를 넣는 곳

여기에 넣은 원본을 `tools/import_sprites.py`가 게임 규격으로 정리해 `project/assets/sprites/`에 쓴다.
게임은 스프라이트 파일이 있으면 그것을, 없으면 코드로 그린 폴백 도형을 쓴다.

**붙여 넣을 프롬프트는 `PROMPTS.md`에 있다.** 이 문서는 규칙과 파일 배치다.

## 확정 화풍 (2026-09-21)

- **2D 손그림 카툰**: 굵은 어두운 외곽선, 플랫 매트 색면, 2~3톤 셀 셰이딩. 사실적 페인티드·PBR 금속·볼류메트릭 음영은 쓰지 않는다.
- 경위: 1차(페인티드 4장)는 서로 화풍이 달랐고 폴백과 섞였다. 2차는 페인티드 12장과 2D 12장을 만들어 비교했고, **2D 세트를 승인**했다. 작은 크기에서 실루엣이 더 잘 읽힌다.
- 현재 상태: 12장이 2D 화풍으로 임포트됨. **`gun_tower.png`만 페인티드라 재생성 필요** (`PROMPTS.md` A의 #1).
- 페인티드 12장은 `_alt/painted/`에 보관(커밋 안 함).

## 기준 이미지 (`ref/`)

| 파일 | 역할 |
| --- | --- |
| `ref/hq_2d_ref.png` | **화풍 기준.** 모든 생성 시 첫 번째로 첨부한다 |
| `ref/rusher_ref.png` | 적 **해부 구조** 참고용(두 번째 첨부). 렌더 방식은 무시하고 형태만 |
| `ground.png` | 지면 (유지). 다시 만들 필요 없다 |

## 파일 규칙

- 파일명은 아래 표 그대로. 정사각 1024px 이상, PNG/JPG/WEBP.
- 배경: 단색 마젠타 `#FF00FF` 권장. 단색이거나 투명이면 어떤 색이든 임포터가 뺀다. 그라데이션·바닥·그림자·글자가 있으면 다시 만든다.
- 한 장에 개체 1개, 중앙, 캔버스의 70~85%.

| 파일명 | 게임 내 크기 | 비고 |
| --- | --- | --- |
| `hq.png` | 폭 212px / 3×3칸 | 받침판이 발자국보다 약간 크다 |
| `barricade.png` `wall.png` | 폭 72px / 1×1칸 | |
| `gun_tower.png` `frost_tower.png` `flame_tower.png` `tesla_tower.png` `sniper_tower.png` | 폭 72px / 1×1칸 | |
| `cannon_tower.png` | 폭 76px / 1×1칸 | |
| `rusher.png` | 38px 정사각 | 줌아웃에서 20px 이하. 몸통이 굵어야 한다 |
| `tank.png` | 58px 정사각 | |
| `splitter.png` | 42px 정사각 | |
| `mini.png` | 22px 정사각 | |
| `ground.png` | 1024×1024 | 이음새 없음, 어둡고 대비 낮게 |

크기는 `tools/import_sprites.py`의 `SPEC`에서 바꾼다.

## 넣은 뒤

```
cd tools && uv run import_sprites.py            # 전체
cd tools && uv run import_sprites.py gun_tower  # 한 장
D:/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe --path project --headless --import
./build.sh
```

검수는 `tools/tests/capture_screenshot.gd`가 찍는 `build/shot-01~04.png` 4장면으로 한다.

- 건물이 한 공장에서 나온 것처럼 보이는가? (같은 외곽선·색면·받침판)
- 적 3종이 같은 종의 변종으로 보이는가? 러셔가 줌아웃에서도 붉은 점으로 읽히는가?
- 화면에 폴백 도형(단색 큐브·육각형)이나 다른 화풍의 개체가 없는가?
- 지면이 적·UI보다 눈에 띄지 않는가?

## 잘 안 될 때

- 3D처럼 나옴 → `PROMPTS.md` 맨 아래 수정 문장. 기준 이미지를 첫 번째로 첨부했는지 확인.
- 배경이 덜 빠짐 → 완전한 단색인지 확인. `import_sprites.py`의 `CHROMA_TOLERANCE`를 올린다.
- 적이 너무 어두움 → 임포터가 평균 밝기 80까지 자동으로 올린다(`ENEMY_MIN_MEAN_LUM`).
- 건물이 칸에서 떠 보임 → 받침판 아래 모서리가 이미지 맨 아래 중앙에 오도록 잘라 다시 임포트.
