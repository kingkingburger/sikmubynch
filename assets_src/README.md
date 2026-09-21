# assets_src — AI 생성 원본 이미지를 넣는 곳

여기에 넣은 원본을 `tools/import_sprites.py`가 게임 규격으로 정리해 `project/assets/sprites/`에 쓴다.
게임은 스프라이트 파일이 있으면 그것을, 없으면 코드로 그린 폴백 도형을 쓴다.

**1차 생성(4장) 검토 결과**: HQ(흰 우주선)·속사 타워(짙은 회색 군용)·러셔(사진 같은 거미)의 스타일이 서로 달랐고, 나머지 10개가 폴백 도형이라 화면이 두 게임을 겹친 것처럼 보였다. 그래서 **기준 이미지를 정하고, 그 이미지를 첨부해 같은 세션에서 14장을 전부 다시 만든다.** 폴백이 하나라도 섞이면 통일되지 않는다.

**바로 붙여 넣을 완성 프롬프트는 `PROMPTS.md`에 있다.** 아래는 그 프롬프트가 어떻게 만들어졌는지의 규칙이다.

## 기준 이미지 (`ref/`)

| 파일 | 역할 | 이 이미지에서 가져올 것 |
| --- | --- | --- |
| `ref/gun_tower_ref.png` | **건물 전체의 기준** | 짙은 건메탈 장갑, 노랑-검정 경고선, 사각 어두운 금속 받침판, 위 왼쪽 조명, 페인티드 렌더 |
| `ref/rusher_ref.png` | **적 전체의 기준** | 붉은 키틴 외계 생명체, 주황 발광 눈, 같은 렌더. 단, 새 러셔는 더 밝고 몸통이 굵어야 한다(아래 참고) |
| `ground.png` | 지면 (유지) | 어두운 암석. 다시 만들 필요 없다 |

## 생성 방법 — 이 네 가지가 통일성을 만든다

1. **같은 도구, 같은 대화(세션)에서 14장을 연속으로 만든다.** 도구나 세션을 바꾸면 화풍이 바뀐다.
2. **매 프롬프트에 기준 이미지를 첨부한다.** 건물은 `gun_tower_ref.png`, 적은 `rusher_ref.png`. 프롬프트의 첫 문장은 항상 아래 "기준 문장"이다.
3. **팔레트를 프롬프트에 색 코드로 박는다.** 아래 팔레트 그대로.
4. **한 장 나올 때마다 바로 넣고 게임에서 본다.** `assets_src/<이름>.png` 저장 → `cd tools && uv run import_sprites.py <이름>` → Godot `--headless --import` → 실행. 어긋나면 그 자리에서 다시 만든다.

정사각 1024px 이상, PNG. 배경은 단색 마젠타 `#FF00FF`(기준 이미지와 동일). 한 장에 개체 1개, 중앙, 캔버스의 70~85%. 그림자·지면·글자 없음.

### 기준 문장 (모든 프롬프트의 첫 줄, 기준 이미지 첨부 필수)

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.
```

### 팔레트 (프롬프트에 그대로 넣는다)

- **건물 공통**: gunmetal gray armor plates `#3B3F45`, darker recesses `#25282C`, yellow-black hazard stripes `#E0B428` / `#1A1A1A`, on a square dark steel base plate `#2A2D31` with a thin yellow edge trim — the same base plate as the reference. 발광은 **기능색 하나만**: HQ 파랑 `#3C8CFF`, 포격 주황 `#FF7A1E`, 감속 청록 `#4FD8FF`, 화염 붉은 주황 `#FF4A16`, 전격 보라 `#9A7CFF`, 저격 녹색 `#5CE08A`. 바리케이드·강화벽은 발광 없음.
- **적 공통**: the same alien species family as the reference — crimson red chitin `#C8262A` with dark charcoal `#2B2224` joints, glowing orange-yellow eyes and joint vents `#FFA028`, bright and saturated so it reads on dark ground. 탱크는 보라 `#5A3D7A`, 스플리터·미니는 황록 `#A8D830` 변종.

## 건물 — 9장 (기준: `ref/gun_tower_ref.png`)

프롬프트 = 기준 문장 + 아래 설명 + 건물 팔레트 문장. 모든 건물이 **같은 사각 받침판** 위에 선다.

| 파일명 | 게임 내 폭 / 칸 | 설명 프롬프트 |
| --- | --- | --- |
| `hq.png` (다시) | 250px / 3×3 | Large fortified command bunker in the same design language as the reference turret: wide low-rise armored body with a raised central tower, thick gunmetal armor plates, hazard stripes along the edges, antenna mast, a large blue glowing energy core visible in the center, on a large square dark steel base plate with yellow edge trim, roughly three times the footprint of the reference |
| `barricade.png` | 76px / 1×1 | Low portable barricade: three gunmetal armor panels bolted together with sandbags at the base, hazard stripes, knee height, no weapons, no glow, on the same square base plate |
| `wall.png` | 78px / 1×1 | Heavy wall block: solid dark gunmetal reinforced block with rivets, bolted panels and hazard stripe corners, chest height, no weapons, no glow, on the same square base plate |
| `gun_tower.png` (유지) | 84px / 1×1 | 기준 이미지 그대로 쓴다. 다시 만들 경우: Rapid-fire gun turret with twin machine gun barrels on a rotating mount, ammo belts, gold-yellow hazard stripes, on the same square base plate |
| `cannon_tower.png` | 88px / 1×1 | Heavy artillery cannon turret built like the reference turret: one huge short barrel, bulky armored mount, hydraulic recoil pistons, orange glowing vents only, on the same square base plate |
| `frost_tower.png` | 84px / 1×1 | Cryo turret built like the reference turret: cylindrical coolant tank with cyan glowing liquid windows, frost emitter dish on top, frost on the metal, cyan glow only, on the same square base plate |
| `flame_tower.png` | 84px / 1×1 | Flamethrower turret built like the reference turret: twin fuel tanks, wide nozzle with a small red-orange pilot flame, scorched metal, red-orange glow only, on the same square base plate |
| `tesla_tower.png` | 84px / 1×1 | Tesla coil turret built like the reference turret: tall coil with a violet glowing orb on top, small electric arcs, insulators, violet glow only, on the same square base plate |
| `sniper_tower.png` | 84px / 1×1 | Tall railgun sniper turret built like the reference turret: long thin barrel angled upward, slim tall body, green laser sight glow only, on the same square base plate |

## 적 — 4장 (기준: `ref/rusher_ref.png`)

프롬프트 = 기준 문장 + 아래 설명 + 적 팔레트 문장. 게임에서 러셔는 38px, 줌아웃하면 20px도 안 되므로 **몸통이 굵고 밝아야** 보인다. 가늘고 긴 다리는 사라진다.

| 파일명 | 게임 내 크기 | 설명 프롬프트 |
| --- | --- | --- |
| `rusher.png` (다시) | 38px | The same creature as the reference but built to read at a tiny size: thicker compact body, shorter sturdier legs, brighter saturated crimson red chitin, large glowing orange eyes, low aggressive lunging pose |
| `tank.png` | 58px | Heavy variant of the same alien species: massive armored brute with a thick plated carapace, heavy limbs, dark violet-purple chitin with black bone spikes, the same glowing orange eyes and joint vents, wide low stance, three times the mass of the reference |
| `splitter.png` | 42px | Spore-carrier variant of the same alien species: bloated round translucent yellow-green sac full of glowing larvae, thin legs, pulsing veins, the same chitin rendering and orange eyes |
| `mini.png` | 22px | Larva of the same alien species: tiny compact pale green soft body, short legs, small mandibles, glowing green core |

## 지면 — 1장 (유지)

| 파일명 | 크기 | 프롬프트 (다시 만들 때만) |
| --- | --- | --- |
| `ground.png` | 1024×1024, 이음새 없음 | seamless tileable texture, straight top-down view, alien planet ground, dark basalt rock with fine cracks, faint teal bioluminescent veins, muted dark tones, even flat lighting, no objects, no shadows, no vignette |

지면은 8칸마다 반복되고 이소 투영으로 세로가 절반으로 눌린다. 어둡고 대비가 낮아야 적과 UI가 읽힌다.

## 검수 기준 (게임 안에서 본다)

`tools/tests/capture_screenshot.gd`가 `build/shot-01~04.png` 4장면을 찍는다.

- 건물 9종이 한 공장에서 나온 것처럼 보이는가? (같은 금속, 같은 경고선, 같은 받침판)
- 적 3종이 같은 종의 변종으로 보이는가? 러셔가 줌아웃에서도 붉은 점으로 읽히는가?
- 화면에 폴백 도형(단색 큐브·육각형)이 하나도 없는가?
- 지면이 적·UI보다 눈에 띄지 않는가?

## 잘 안 될 때

- 스타일이 어긋남 → 기준 이미지를 첨부했는지, 기준 문장이 첫 줄인지 확인. 같은 세션에서 "closer to the reference, same rendering and palette"로 다시.
- 배경이 덜 빠짐 → 완전한 단색 마젠타인지 확인. `import_sprites.py`의 `CHROMA_TOLERANCE`를 올린다.
- 적이 너무 어두움 → 임포터가 평균 밝기 80까지 자동으로 올린다(`ENEMY_MIN_MEAN_LUM`). 그래도 어두우면 원본을 더 밝게.
- 건물이 칸에서 떠 보임 → 받침판 아래 모서리가 이미지 맨 아래 중앙에 오도록 잘라 다시 임포트.
- 개체 크기 조정 → `import_sprites.py`의 `SPEC` 숫자.
