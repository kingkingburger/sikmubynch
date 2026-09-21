# 복붙용 완성 프롬프트 (ChatGPT 이미지 생성 대화창용)

확정 화풍: **2D 손그림 카툰** — 굵은 어두운 외곽선, 플랫 매트 색면, 2~3톤 셀 셰이딩 (2026-09-21, `ref/hq_2d_ref.png` 승인).
건물은 지금 그대로 둔다(귀엽고 아기자기한 카툰 스타일). **몬스터는 귀여운 카툰 외계 생물로 다시 만든다** — 무섭고 사실적인 거미가 아니라 둥글고 아기자기한 치비형. **`gun_tower.png`도 아직 페인티드라 다시 만든다.**

## A. 한 번에 붙이는 프롬프트

1. ChatGPT 새 대화창을 연다.
2. `ref/hq_2d_ref.png` 한 장을 첨부한다 (화풍 기준).
3. 아래 블록을 통째로 붙여 넣고 보낸다 → 1번이 나온다.
4. 이미지를 저장해 목록의 파일명으로 `assets_src/` 에 넣는다.
5. `next` 라고 보낸다 → 다음 장. **5번까지** 반복하면 끝. (6번 이후는 이미 완성된 건물이라 다시 만들 때만.)
6. 마음에 안 드는 장은 `redo #2, cuter and rounder, closer to the reference's flat 2D drawn style` 처럼 번호로 다시 시킨다.

배경이 마젠타가 아니어도 단색이거나 투명이면 된다. 그라데이션·바닥·그림자가 들어가면 그 번호를 다시 시킨다.

```
I need a matched set of 2D hand-drawn game sprites for a lighthearted isometric tower-defense game. The attached image is the APPROVED ART STYLE reference: match its bold dark drawn contour lines, flat matte color regions, simple 2-3 tone cel shading and slightly hand-painted cartoon finish exactly. Clearly illustrated 2D, not a 3D render. No photorealism, no PBR, no reflective metal, no smooth volumetric shading, no ambient occlusion, no fine scratches. The overall mood is cute and charming, like a cartoon RTS: chunky, rounded, friendly shapes.

Rules for every image:
- Chunky readable silhouette at small size. Same isometric 3/4 top-down camera and upper-left lighting as the reference.
- Entire object visible with comfortable margins, centered, single object. No text, no watermark, no external cast shadow, no ground.
- Square 1024x1024. Background MUST be flat opaque bright magenta #FF00FF, never black, never transparent.
- Building palette: matte gunmetal gray #3B3F45 with lighter gray face shading as in the reference, dark recesses #25282C, yellow/black hazard stripes #E0B428/#1A1A1A. Every building stands on the same square dark steel base #2A2D31 with thin yellow trim and dark drawn outlines as the reference. Yellow is flat paint, never glowing. Only the specified accent color per building, rendered as simple graphic color, no bloom.
- Enemy style: CUTE cartoon alien critters, chibi proportions: big round body, oversized round eyes, tiny stubby legs, small cheeky fangs or grin. Mischievous but adorable, never scary or realistic. Saturated flat colors, dark charcoal #2B2224 outlines and joints, bright orange-yellow #FFA028 eyes. No mechanical parts, no base plate.

Generate them ONE AT A TIME in this order. Start with #1 now. Each time I reply "next", generate the next one. Label each result with its number and filename. If I say "redo #N", regenerate that one only.

1. gun_tower.png - Rapid-fire gun turret: twin machine-gun barrels on a rotating mount, ammo belts, yellow hazard stripes on the mount. Same square base. No accent glow beyond the hazard yellow.
2. rusher.png - Cute crimson red #C8262A alien critter: round chubby body, huge round orange eyes, four tiny stubby legs, a small cheeky grin with two little fangs, leaning forward as if scurrying. Very simple chunky silhouette that still reads at 30 pixels.
3. tank.png - Cute big alien brute, dark violet-purple #5A3D7A: very wide, chubby, rounded armored body with a few soft rounded plates, tiny stubby legs, small sleepy orange eyes, a couple of small rounded bone bumps instead of spikes. Broad heavy silhouette, about three times the rusher mass, still adorable.
4. splitter.png - Cute yellow-green #A8D830 alien blob: big round translucent belly with a few tiny smiling larva faces visible inside, small head with wide orange eyes, thin little legs. Bouncy and jolly.
5. mini.png - Tiny baby alien larva, pale green #A8D830: tiny round soft body, huge orange eyes, very short stubby legs, one bright green glowing spot on its belly. Super simple, fills the frame.

Already finished - regenerate only if I ask:
6. hq.png - Fortified command bunker matching the reference exactly: broad low armored wings, raised central tower, antenna mast and large blue #3C8CFF core. Same square base, about three times the footprint of a turret.
7. barricade.png - Low knee-height portable barricade: three armor panels bolted together with sandbags at their base, hazard stripes on edges, no weapons, no glow. Same square base.
8. wall.png - Heavy chest-height wall block: solid reinforced block, a few simple rivets and panel divisions, hazard-stripe corners, no weapons, no glow. Same square base.
9. cannon_tower.png - Heavy artillery turret: exactly ONE huge short wide barrel on a bulky armored mount, hydraulic recoil pistons, orange vent accent #FF7A1E only. Same square base.
10. frost_tower.png - Cryo turret: cylindrical coolant tank with cyan liquid windows, frost emitter dish on top, a few angular frost crystals. Cyan accent #4FD8FF only. Same square base.
11. flame_tower.png - Flamethrower turret: two fuel tanks on the back feeding exactly ONE short wide nozzle with a small red-orange pilot flame, matte scorched patch around the nozzle. Red-orange accent #FF4A16 only. Same square base.
12. tesla_tower.png - Tesla turret: tall coil, violet orb on top, a few simple zigzag electric arcs, ceramic insulators. Violet accent #9A7CFF only. Same square base.
13. sniper_tower.png - Railgun sniper turret: slim tall body, exactly ONE long thin barrel angled upward, green scope/laser-sight accent #5CE08A only. Same square base.
```

## B. 한 장만 다시 만들 때

같은 대화창이면 `redo #N` 으로 충분하다. 새 대화창이면 `ref/hq_2d_ref.png` 를 첨부하고, 위 블록에서 "Rules for every image" 항목까지 붙인 뒤 마지막에 원하는 항목 한 줄만 붙인다. 예:

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
- 적이 무섭거나 사실적으로 나올 때: `Cuter: rounder body, bigger eyes, stubbier legs, friendly cartoon critter, no realistic insect anatomy.`
- 적이 어둡거나 탁할 때: `Brighter, more saturated body color; eyes must be clearly visible orange-yellow.`
