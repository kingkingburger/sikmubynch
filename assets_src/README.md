# assets_src — AI 생성 원본 이미지를 넣는 곳

여기에 넣은 원본을 `tools/import_sprites.py`가 게임 규격으로 정리해 `project/assets/sprites/`에 쓴다.
게임은 스프라이트 파일이 있으면 그것을, 없으면 코드로 그린 폴백 도형을 쓴다.

**붙여 넣을 프롬프트는 `PROMPTS.md`에 있다.** 이 문서는 규칙과 파일 배치다.

## 확정 화풍 (2026-09-21)

- **2D 손그림 카툰**: 굵은 어두운 외곽선, 플랫 매트 색면, 2~3톤 셀 셰이딩. 사실적 페인티드·PBR 금속·볼류메트릭 음영은 쓰지 않는다.
- 경위: 1차(페인티드 4장)는 서로 화풍이 달랐고 폴백과 섞였다. 2차는 페인티드 12장과 2D 12장을 만들어 비교했고, **2D 세트를 승인**했다. 작은 크기에서 실루엣이 더 잘 읽힌다.
- 몬스터 방향(2026-09-21 추가): **귀엽고 아기자기한 치비형 카툰 외계 생물**. 무섭고 사실적인 거미는 쓰지 않는다. 건물은 지금 카툰 그대로.
- 몬스터 애니메이션(2026-09-21 추가): 몬스터는 **4포즈 시트**(`<이름>_sheet.png`: 걷기A, 걷기B, 물기 준비, 물기)로 만든다. 임포터가 마젠타 틈으로 포즈를 나눠 정사각 셀 스트립으로 만들고, 게임이 걷기·물기 프레임을 돌린다. 낱장 `<이름>.png`만 있으면 정지 이미지로 쓴다(물기 런지는 정지 이미지에도 적용).
- 현재 상태: 건물 8종은 완료. **다시 만들 것 = `gun_tower.png`(아직 페인티드) + 몬스터 시트 4종(`rusher_sheet` `tank_sheet` `splitter_sheet` `mini_sheet`, 귀여운 버전으로)** → `PROMPTS.md` A의 #1~#5.
- 페인티드 12장은 `_alt/painted/`에 보관(커밋 안 함).

## 기준 이미지 (`ref/`)

| 파일 | 역할 |
| --- | --- |
| `ref/hq_2d_ref.png` | **화풍 기준.** 모든 생성 시 첨부한다 (이것 한 장만) |
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
| `rusher_sheet.png` (또는 `rusher.png`) | 셀 38px 정사각 × 포즈 수 | 줌아웃에서 20px 이하. 둥글고 굵은 몸통, 큰 눈 |
| `tank_sheet.png` (또는 `tank.png`) | 셀 58px 정사각 × 포즈 수 | |
| `splitter_sheet.png` (또는 `splitter.png`) | 셀 42px 정사각 × 포즈 수 | |
| `mini_sheet.png` (또는 `mini.png`) | 셀 22px 정사각 × 포즈 수 | |
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
- 시트 포즈가 N개로 안 나뉨 → 포즈 사이에 마젠타 틈(6px 이상)이 있어야 한다. `import_sprites.py`의 `SHEET_GAP_MIN`. 임포트 로그에 `N프레임`이 찍힌다.
