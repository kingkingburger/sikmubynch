# 복붙용 완성 프롬프트 (ChatGPT 이미지 생성 대화창용)

확정 화풍: **2D 손그림 카툰** — 굵은 어두운 외곽선, 플랫 매트 색면, 2~3톤 셀 셰이딩 (2026-09-21, `ref/hq_2d_ref.png` 승인).
건물은 지금 그대로 둔다(귀엽고 아기자기한 카툰 스타일). **몬스터는 귀여운 카툰 외계 생물로 다시 만든다** — 무섭고 사실적인 거미가 아니라 둥글고 아기자기한 치비형. **`gun_tower.png`도 아직 페인티드라 다시 만든다.**

## A. 한 번에 붙이는 프롬프트

몬스터는 낱장이 아니라 **한 장에 4포즈가 나란히 있는 시트**로 만든다 (걷기A, 걷기B, 물기 준비, 물기). 같은 이미지 안에서 그려야 포즈끼리 캐릭터가 같다. 게임이 이 시트로 걷기·물기 애니메이션을 돌린다.

1. ChatGPT 새 대화창을 연다.
2. `ref/hq_2d_ref.png` 한 장을 첨부한다 (화풍 기준).
3. 아래 블록을 통째로 붙여 넣고 보낸다 → 1번이 나온다.
4. 이미지를 저장해 목록의 파일명으로 `assets_src/` 에 넣는다. 몬스터는 `rusher_sheet.png` 처럼 **`_sheet`** 를 붙인다.
5. `next` 라고 보낸다 → 다음 장. **5번까지** 반복하면 끝. (6번 이후는 이미 완성된 건물이라 다시 만들 때만.)
6. 마음에 안 드는 장은 `redo #2, cuter and rounder, exactly 4 poses in one row with clear gaps` 처럼 번호로 다시 시킨다.

배경이 마젠타가 아니어도 단색이거나 투명이면 된다. 그라데이션·바닥·그림자·글자·번호·격자선이 들어가면 그 번호를 다시 시킨다. 시트에서 포즈끼리 붙어 있으면(틈 없음) 다시 시킨다.

```
I need 2D hand-drawn game sprites for a lighthearted isometric tower-defense game. The attached image is the APPROVED ART STYLE reference: match its bold dark drawn contour lines, flat matte color regions, simple 2-3 tone cel shading and slightly hand-painted cartoon finish exactly. Clearly illustrated 2D, not a 3D render. No photorealism, no PBR, no smooth volumetric shading. The mood is cute and charming, like a cartoon RTS: chunky, rounded, friendly shapes.

Rules for every image:
- Same isometric 3/4 top-down camera and upper-left lighting as the reference. Chunky readable silhouette at small size.
- Square 1024x1024. Background MUST be flat opaque bright magenta #FF00FF, never black, never transparent. No text, no numbers, no labels, no grid lines, no borders, no cast shadow, no ground.
- Building palette: matte gunmetal gray #3B3F45 with lighter gray face shading as in the reference, dark recesses #25282C, yellow/black hazard stripes #E0B428/#1A1A1A, on the same square dark steel base #2A2D31 with thin yellow trim as the reference.
- Enemy style: CUTE cartoon alien critters, chibi proportions: big round body, oversized round eyes, tiny stubby legs, small cheeky fangs. Mischievous but adorable, never scary or realistic. Saturated flat colors, dark charcoal #2B2224 outlines, bright orange-yellow #FFA028 eyes. No mechanical parts, no base plate.

ENEMY SPRITE SHEETS: each enemy is ONE image containing exactly 4 poses of the SAME character in ONE horizontal row, evenly spaced with clear magenta gaps between them, all 4 the same size and the same facing direction (facing the lower-left, as seen from the isometric camera). Poses left to right:
  (1) walk A: mid-stride, legs in one position, body level
  (2) walk B: mid-stride, legs swapped, body slightly bobbed
  (3) attack wind-up: rearing back, mouth wide open, fangs bared, weight on the back legs
  (4) attack bite: lunging forward, body stretched, fangs sunk in, eyes squeezed
Keep the character identical across the 4 poses: same colors, same proportions, same details. Only the pose changes.

Generate them ONE AT A TIME in this order. Start with #1 now. Each time I reply "next", generate the next one. Label each result with its number and filename. If I say "redo #N", regenerate that one only.

1. gun_tower.png (single image) - Rapid-fire gun turret: twin machine-gun barrels on a rotating mount, ammo belts, yellow hazard stripes on the mount. Same square base. No accent glow beyond the hazard yellow.
2. rusher_sheet.png (4-pose sheet) - Cute crimson red #C8262A alien critter: round chubby body, huge round orange eyes, four tiny stubby legs, a cheeky grin with two little fangs. Very simple chunky silhouette that still reads at 30 pixels.
3. tank_sheet.png (4-pose sheet) - Cute big alien brute, dark violet-purple #5A3D7A: very wide chubby rounded armored body with soft rounded plates, tiny stubby legs, small sleepy orange eyes, a few small rounded bone bumps. Broad heavy silhouette, about three times the rusher mass, still adorable.
4. splitter_sheet.png (4-pose sheet) - Cute yellow-green #A8D830 alien blob: big round translucent belly with a few tiny smiling larva faces visible inside, small head with wide orange eyes, thin little legs. Bouncy and jolly.
5. mini_sheet.png (4-pose sheet) - Tiny baby alien larva, pale green #A8D830: tiny round soft body, huge orange eyes, very short stubby legs, one bright green glowing spot on its belly. Super simple.

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
- 시트 포즈가 붙었거나 4개가 아닐 때: `Exactly 4 poses in one horizontal row, clear magenta gaps between them, all the same size and facing, no labels.`
- 포즈마다 캐릭터가 달라질 때: `Keep the character identical in all 4 poses: same colors, proportions and details. Only the pose changes.`
- 적이 어둡거나 탁할 때: `Brighter, more saturated body color; eyes must be clearly visible orange-yellow.`
