# assets_src — AI 생성 원본 이미지를 넣는 곳

여기에 넣은 원본을 `tools/import_sprites.py`가 게임 규격으로 정리해 `project/assets/sprites/`에 쓴다.
게임은 스프라이트 파일이 있으면 그것을, 없으면 코드로 그린 폴백 도형을 쓴다. 한 장씩 넣어도 된다.

## 작업 순서

1. 아래 프롬프트로 이미지를 만든다. 정사각 1024px 이상, PNG 권장.
2. 이 폴더에 **표의 파일명 그대로** 저장한다 (`rusher.png`, `hq.png`, …; jpg/webp도 된다).
3. 임포트: `cd tools` 후 `uv run import_sprites.py` (전체) 또는 `uv run import_sprites.py rusher hq` (지정).
4. Godot 임포트: `D:/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe --path project --headless --import`
5. 실행해서 본다: 에디터 F5, 또는 `./build.sh`로 exe. 스크린샷 검수는 `tools/tests/capture_screenshot.gd`.

한 번에 전부 만들지 않는다. **rusher → gun_tower → hq → ground** 순으로 4장을 먼저 넣고 화면에서 크기·톤이 맞는지 본 뒤 나머지를 만든다.

## 모든 이미지 공통 규칙

- **배경**: 단색 마젠타(`#FF00FF`) 또는 투명. 임포터가 모서리 색을 배경으로 보고 뺀다. 개체에 마젠타가 있으면 흰색·검정 배경으로 바꾼다.
- **한 장에 개체 1개**, 화면 중앙, 잘리지 않게, 캔버스의 70~85%를 채운다.
- **시점**: 3/4 탑다운(isometric). 앞면이 화면 아래쪽. 카메라는 위에서 35~40° 내려다본다. 정면·측면 시점은 쓰지 않는다.
- **바닥 그림자·지면·받침 없음**. 그림자는 임포터가 넣는다.
- **글자·워터마크·배경 발광 없음**. 빛은 위 왼쪽에서 오는 부드러운 방향광 하나.
- **화풍**: 페인티드·세미리얼 다크 SF. 픽셀아트·카툰·귀여운 실루엣은 쓰지 않는다. 모든 이미지에 같은 스타일 문장을 붙여 톤을 맞춘다.

프롬프트 끝에 붙이는 **공통 스타일 문장**:

```
isometric 3/4 top-down view, dark sci-fi game sprite, painted semi-realistic style, crisp hard-surface detail, single object centered, full body visible, not cropped, flat solid magenta background #FF00FF, no ground, no floor, no cast shadow, no text, no watermark, one soft directional light from the upper left
```

## 적 — 외계 생명체

무리 속에서 **실루엣과 색**으로 구분돼야 한다. 러셔는 붉고 작고 날카롭게, 탱크는 보라·검정에 육중하게, 스플리터는 황록색으로 부풀게.

| 파일명 | 게임 내 크기 | 실루엣 요점 | 프롬프트 (뒤에 공통 스타일 문장) |
| --- | --- | --- | --- |
| `rusher.png` | 34px | 작고 빠름, 낮게 달려드는 자세 | small fast alien crawler, insectoid, six thin blade-like legs, hunched low body, sharp mandibles, crimson red chitin with dark charcoal markings, glowing orange eyes, aggressive lunging pose |
| `tank.png` | 58px | 크고 둔중, 넓은 어깨 | massive armored alien brute, thick plated carapace, heavy limbs, dark purple and violet chitin with black bone spikes, wide low stance, dim magenta glow between armor plates |
| `splitter.png` | 42px | 부풀어 오른 포자낭 | bloated alien spore carrier, round translucent yellow-green sac full of glowing larvae, thin spindly legs, pulsing veins, dripping slime |
| `mini.png` | 22px | 스플리터에서 튀어나온 유충 | tiny alien larva, pale green soft body, short legs, small mandibles, glowing green core |

## 건물 — 인류 전초기지

무채색 금속 몸체 + **기능별 발광색** 하나로 구분한다. 바닥은 마름모(2:1) 받침판 위에 서 있는 형태가 좋다. 받침판의 **아래 꼭짓점**이 게임 격자 칸의 앞 꼭짓점에 맞춰진다.

| 파일명 | 게임 내 폭 / 칸 | 발광색 | 프롬프트 (뒤에 공통 스타일 문장) |
| --- | --- | --- | --- |
| `hq.png` | 250px / 3×3 | 파랑 | sci-fi military command center, hexagonal fortified base building on a flat diamond-shaped dark metal platform, layered armor plates, antenna array, central blue glowing energy core, warning lights, three stories tall |
| `barricade.png` | 76px / 1×1 | 없음(회색) | low portable sci-fi barricade, gray steel plates with sandbags, scratched and worn, on a small flat diamond-shaped platform, knee height |
| `wall.png` | 78px / 1×1 | 없음(짙은 회색) | heavy sci-fi wall segment, dark reinforced steel block with rivets and bolted panels, on a small flat diamond-shaped platform, chest height |
| `gun_tower.png` | 84px / 1×1 | 금색 | sci-fi rapid-fire gun turret tower, twin machine gun barrels on a rotating mount, gray metal body with gold-yellow warning stripes, ammo belts, on a small flat diamond-shaped platform |
| `cannon_tower.png` | 88px / 1×1 | 주황 | sci-fi heavy artillery cannon tower, one huge short barrel, bulky gray armor with orange accents, hydraulic recoil pistons, on a small flat diamond-shaped platform |
| `frost_tower.png` | 84px / 1×1 | 청록 | sci-fi cryo tower, cylindrical coolant tank with cyan glowing liquid, frost emitter dish on top, ice crystals on the metal, on a small flat diamond-shaped platform |
| `flame_tower.png` | 84px / 1×1 | 붉은 주황 | sci-fi flamethrower tower, twin fuel tanks, wide nozzle with a small red-orange pilot flame, scorched metal, on a small flat diamond-shaped platform |
| `tesla_tower.png` | 84px / 1×1 | 보라 | sci-fi tesla coil tower, tall copper coil with a violet glowing orb on top, small electric arcs, insulators, on a small flat diamond-shaped platform |
| `sniper_tower.png` | 84px / 1×1 | 녹색 | sci-fi tall railgun sniper tower, long thin barrel angled upward, slim tower body, green laser sight glow, on a small flat diamond-shaped platform |

## 지면

| 파일명 | 크기 | 프롬프트 |
| --- | --- | --- |
| `ground.png` | 1024×1024, 이음새 없음 | seamless tileable texture, straight top-down view, alien planet ground, dark basalt rock with fine cracks, faint teal bioluminescent veins, muted dark tones, even flat lighting, no objects, no shadows, no vignette, high detail |

지면은 8칸마다 반복되고 이소 투영으로 세로가 절반으로 눌린다. **어둡고 대비가 낮아야** 적과 UI가 읽힌다. 밝거나 무늬가 큰 텍스처는 쓰지 않는다.

## 잘 안 될 때

- 배경이 덜 빠짐 → 원본 배경이 그라데이션이거나 개체 색과 비슷하다. 완전한 단색 배경으로 다시 만들거나 `import_sprites.py`의 `CHROMA_TOLERANCE`를 올린다.
- 개체가 너무 작게/크게 보임 → 임포터가 캔버스에 맞춰 리사이즈하므로 원본 여백은 상관없다. 게임 내 크기는 `SPEC`의 숫자로 조정한다.
- 건물이 칸에서 떠 보임 → 받침판 아래 꼭짓점이 이미지 맨 아래 중앙에 오도록 원본을 잘라 다시 임포트한다.
- 그림자가 이상함 → 원본에 그림자가 포함됐다. 그림자 없는 원본으로 다시 만든다.
