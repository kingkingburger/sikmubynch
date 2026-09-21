# 복붙용 완성 프롬프트 (ChatGPT 이미지 생성 대화창용)

확정 화풍: **2D 손그림 카툰** — 굵은 어두운 외곽선, 플랫 매트 색면, 2~3톤 셀 셰이딩 (2026-09-21, `ref/hq_2d_ref.png` 승인).
페인티드·사실적 렌더는 쓰지 않는다. 현재 `assets_src/`의 12장이 이 화풍이고, **`gun_tower.png`만 아직 페인티드**라 다시 만들어야 한다.

## A. 한 번에 붙이는 프롬프트

1. ChatGPT 새 대화창을 연다.
2. `ref/hq_2d_ref.png` (화풍 기준) 와 `ref/rusher_ref.png` (적 해부 구조 기준) 두 장을 첨부한다. 순서대로: HQ 먼저, 벌레 다음.
3. 아래 블록을 통째로 붙여 넣고 보낸다 → 1번이 나온다.
4. 이미지를 저장해 목록의 파일명으로 `assets_src/` 에 넣는다.
5. `next` 라고 보낸다 → 다음 장. 끝까지 반복.
6. 마음에 안 드는 장은 `redo #4, closer to image 1's flat 2D drawn style` 처럼 번호로 다시 시킨다.

지금 필요한 것은 **#1 gun_tower.png 한 장**이다. 나머지는 화풍을 바꾸거나 다시 만들 때만 쓴다.

배경이 마젠타가 아니어도 단색이거나 투명이면 된다. 그라데이션·바닥·그림자가 들어가면 그 번호를 다시 시킨다.

```
I need a matched set of 2D hand-drawn game sprites for an isometric tower-defense game. Image 1 is the APPROVED ART STYLE reference: match its bold dark drawn contour lines, flat matte color regions, simple 2-3 tone cel shading and slightly hand-painted cartoon finish exactly. Clearly illustrated 2D, not a 3D render. No photorealism, no PBR, no reflective metal, no smooth volumetric shading, no ambient occlusion, no fine scratches, no excessive bolts. Image 2 is ANATOMY REFERENCE ONLY for the enemies: ignore its realistic rendering and use exclusively image 1's flat 2D drawn style.

Rules for every image:
- Chunky readable silhouette at small size. Same isometric 3/4 top-down camera and upper-left lighting as image 1.
- Entire object visible with comfortable margins, centered, single object. No text, no watermark, no external cast shadow, no ground.
- Square 1024x1024. Background MUST be flat opaque bright magenta #FF00FF, never black, never transparent.
- Building palette: matte gunmetal gray #3B3F45 with lighter gray face shading as in image 1, dark recesses #25282C, yellow/black hazard stripes #E0B428/#1A1A1A. Every building stands on the same square dark steel base #2A2D31 with thin yellow trim and dark drawn outlines as image 1. Yellow is flat paint, never glowing. Use only the specified accent color per building, rendered as simple graphic color, no bloom.
- Enemy palette: alien chitin species, charcoal joints #2B2224, orange-yellow eyes/vents #FFA028, saturated body colors. No mechanical parts, no base plate.

Generate them ONE AT A TIME in this order. Start with #1 now. Each time I reply "next", generate the next one. Label each result with its number and filename. If I say "redo #N", regenerate that one only.

1. gun_tower.png — Rapid-fire gun turret: twin machine-gun barrels on a rotating mount, ammo belts, yellow hazard stripes on the mount. Same square base. Accent: none beyond the hazard yellow.
2. hq.png — Match the approved HQ building design in image 1 exactly: fortified command bunker, broad low armored wings, raised central tower, antenna mast and large blue #3C8CFF core. Same square base, about three times the footprint of a turret.
3. barricade.png — Low knee-height portable barricade: exactly three armor panels bolted together with sandbags at their base, hazard stripes on edges, no weapons, no glow. Same square base.
4. wall.png — Heavy chest-height wall block: solid reinforced block, a few simple rivets and panel divisions, hazard-stripe corners, no weapons, no glow. Same square base.
5. cannon_tower.png — Heavy artillery turret: exactly ONE huge short wide barrel on a bulky armored mount, hydraulic recoil pistons, orange vent accent #FF7A1E only. Same square base.
6. frost_tower.png — Cryo turret: cylindrical coolant tank with cyan liquid windows, frost emitter dish on top, a few angular frost crystals. Cyan accent #4FD8FF only. Same square base.
7. flame_tower.png — Flamethrower turret: two fuel tanks on the back feeding exactly ONE short wide nozzle with a small red-orange pilot flame, matte scorched patch around the nozzle. Red-orange accent #FF4A16 only. Same square base.
8. tesla_tower.png — Tesla turret: tall coil, violet orb on top, a few simple zigzag electric arcs, ceramic insulators. Violet accent #9A7CFF only. Same square base.
9. sniper_tower.png — Railgun sniper turret: slim tall body, exactly ONE long thin barrel angled upward, green scope/laser-sight accent #5CE08A only. Same square base.
10. rusher.png — Crimson alien rusher #C8262A: compact thick chitin body, SHORT sturdy legs, large orange eyes, low aggressive lunge. Simplify image 2's anatomy substantially for small-sprite readability; flat painted red armor plates and dark drawn outlines.
11. tank.png — Heavy alien tank, dark violet-purple #5A3D7A: very broad squat massive brute, thick overlapping armored carapace, SHORT heavy limbs, black bone spikes, wide low stance, about three times the rusher's mass, orange eyes and vents. Broad chunky silhouette distinctly heavier than the rusher.
12. splitter.png — Alien spore carrier: huge bloated ROUND translucent yellow-green #A8D830 sac with a few simple visible glowing larva shapes and pulsing veins, small chitin head with orange eyes, thin supporting legs. Flat 2D graphic transparency effect, no realistic glass.
13. mini.png — Tiny baby alien larva: compact SOFT rounded pale green #A8D830 segmented body, very short stubby legs, small mandibles, small orange-yellow eyes, one visible bright green core. Very simple silhouette, few details, no armored adult spikes. Fill the frame.
```

## B. 한 장만 다시 만들 때

같은 대화창이면 `redo #N` 으로 충분하다. 새 대화창이면 `ref/hq_2d_ref.png` 를 첨부하고, 위 블록에서 "Rules for every image" 까지 붙인 뒤 마지막 줄에 원하는 항목 한 줄만 붙인다. 예:

```
(위 블록의 첫 문단 + Rules for every image 항목 전체)

Generate this one image now:
1. gun_tower.png — Rapid-fire gun turret: twin machine-gun barrels on a rotating mount, ammo belts, yellow hazard stripes on the mount. Same square base. Accent: none beyond the hazard yellow.
```

## C. 지면 (유지. 다시 만들 때만)

`ground.png`, 1024×1024 이음새 없음: `seamless tileable texture, straight top-down view, alien planet ground, dark basalt rock with fine cracks, faint teal bioluminescent veins, muted dark tones, even flat lighting, no objects, no shadows, no vignette`. 어둡고 대비가 낮아야 적과 UI가 읽힌다.

## 결과가 어긋날 때 같은 대화창에 붙이는 수정 문장

- 3D처럼 나올 때: `Too realistic. Flat 2D drawn style exactly like image 1: bold dark outlines, flat matte colors, 2-3 tone cel shading, no volumetric shading.`
- 배경이 이상할 때: `Flat opaque bright magenta background #FF00FF only. No gradient, no floor, no shadow.`
- 받침판이 없을 때: `Put it on the same square dark steel base with thin yellow trim as the buildings in image 1.`
- 적이 어둡거나 탁할 때: `Brighter, more saturated body color; eyes must be clearly visible orange-yellow.`
