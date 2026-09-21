# 복붙용 완성 프롬프트 (ChatGPT 이미지 생성 대화창용)

## A. 한 번에 붙이는 프롬프트 (권장)

1. ChatGPT 새 대화창을 연다.
2. `ref/gun_tower_ref.png` 와 `ref/rusher_ref.png` 두 장을 첨부한다 (순서대로: 타워 먼저, 벌레 다음).
3. 아래 블록을 통째로 붙여 넣고 보낸다 → 1번(HQ)이 나온다.
4. 이미지를 **저장** (파일명은 목록의 이름) → `assets_src/` 에 넣는다.
5. `next` 라고 보낸다 → 다음 장. 12번까지 반복.
6. 마음에 안 드는 장이 있으면 `redo #4, closer to the reference turret, same rendering and palette` 처럼 번호로 다시 시킨다.

배경이 마젠타가 아니어도 **단색이거나 투명**이면 된다. 그라데이션·바닥·그림자가 들어가면 그 번호를 다시 시킨다.

```
I need a matched set of 12 game sprites for an isometric tower-defense game. I attached two style references: the first image (the gun turret) is the reference for ALL buildings, the second image (the red creature) is the reference for ALL enemies.

Rules for every image:
- Match the reference exactly: painted semi-realistic rendering, the same level of detail and edge crispness, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left.
- Flat solid magenta background #FF00FF. One object centered, full body visible, not cropped. No ground, no floor, no cast shadow, no text, no watermark.
- Square 1024x1024.
- Building palette: gunmetal gray armor plates #3B3F45, darker recesses #25282C, yellow-black hazard stripes #E0B428 and #1A1A1A. Every building stands on the same square dark steel base plate #2A2D31 with a thin yellow edge trim as the reference turret. Only one glowing color per building, listed below.
- Enemy palette: the same alien species family as the reference creature: chitin body, dark charcoal joints #2B2224, glowing orange-yellow eyes and joint vents #FFA028. Bright and saturated so it reads on dark ground.

Generate them ONE AT A TIME in this order. Start with #1 now. Each time I reply "next", generate the next one. Label each result with its number and filename. If I say "redo #N", regenerate that one only.

1. hq.png — Large fortified command bunker in the same design language as the reference turret: wide low-rise armored body with a raised central tower, thick gunmetal armor plates, hazard stripes along the edges, an antenna mast, and a large blue glowing energy core visible in the center. Stands on a large square base plate about three times the footprint of the reference turret. Glow: blue #3C8CFF only.
2. barricade.png — Low portable barricade: three gunmetal armor panels bolted together with sandbags at the base, hazard stripes on the panel edges, knee height, no weapons. On the same square base plate. No glow.
3. wall.png — Heavy wall block: solid dark gunmetal reinforced block with rivets, bolted panels and hazard-stripe corners, chest height, no weapons. On the same square base plate. No glow.
4. cannon_tower.png — Heavy artillery cannon turret built like the reference turret: one huge short barrel on a bulky armored mount, hydraulic recoil pistons, orange glowing vents. On the same square base plate. Glow: orange #FF7A1E only.
5. frost_tower.png — Cryo turret built like the reference turret: cylindrical coolant tank with cyan glowing liquid windows, a frost emitter dish on top, frost crystals on the metal. On the same square base plate. Glow: cyan #4FD8FF only.
6. flame_tower.png — Flamethrower turret built like the reference turret: twin fuel tanks on the back, a wide nozzle with a small red-orange pilot flame, scorched metal around the nozzle. On the same square base plate. Glow: red-orange #FF4A16 only.
7. tesla_tower.png — Tesla coil turret built like the reference turret: a tall coil with a violet glowing orb on top, small electric arcs around the orb, ceramic insulators on the body. On the same square base plate. Glow: violet #9A7CFF only.
8. sniper_tower.png — Tall railgun sniper turret built like the reference turret: slim tall body with one long thin barrel angled upward, a green laser-sight glow at the scope. On the same square base plate. Glow: green #5CE08A only.
9. rusher.png — The same creature as the reference creature, redesigned to read clearly at a tiny size: thicker compact body, shorter sturdier legs, large glowing orange eyes, low aggressive lunging pose. Brighter and more saturated crimson red chitin #C8262A than the reference.
10. tank.png — Heavy variant of the same alien species: massive armored brute with a thick plated carapace, heavy limbs, black bone spikes, wide low stance, about three times the mass of the reference creature. Dark violet-purple chitin #5A3D7A, same glowing orange eyes and joint vents.
11. splitter.png — Spore-carrier variant of the same alien species: a bloated round translucent yellow-green sac #A8D830 full of glowing larvae, carried on thin legs, pulsing veins on the sac, the same chitin rendering on legs and head, same orange eyes.
12. mini.png — Larva of the same alien species: tiny compact soft body, short legs, small mandibles, a glowing green core visible through pale green skin #A8D830, small orange-yellow eyes. Simple silhouette that fills the frame.
```

---

## B. 한 장씩 따로 만들 때 (A가 안 될 때, 또는 한 장만 다시 만들 때)

각 프롬프트마다 **지정된 기준 이미지를 첨부**하고 아래 블록을 통째로 붙인다.

### 0. 세션 시작 (한 번만. `ref/gun_tower_ref.png` 와 `ref/rusher_ref.png` 두 장 첨부)

```
I am going to ask you for 13 game sprites one at a time. The two attached images are the fixed style references for this whole session: the turret is the reference for every building, the red creature is the reference for every enemy. For every image, keep the rendering identical to these references: painted semi-realistic style, same level of detail, same isometric 3/4 top-down camera angle, same soft directional light from the upper left, flat solid magenta background #FF00FF, one object centered, full body visible, no ground, no floor, no cast shadow, no text, no watermark. Always output a square 1024x1024 image. Reply "ready" and wait for the first request.
```

---

## 건물 8장 — 매번 `ref/gun_tower_ref.png` 첨부

### 1. `hq.png`

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: a large fortified command bunker in the same design language as the reference turret. Wide low-rise armored body with a raised central tower, thick gunmetal armor plates, hazard stripes along the edges, an antenna mast, and a large blue glowing energy core visible in the center. It stands on a large square dark steel base plate with a thin yellow edge trim, roughly three times the footprint of the reference turret.

Palette: gunmetal gray armor plates #3B3F45, darker recesses #25282C, yellow-black hazard stripes #E0B428 and #1A1A1A, base plate #2A2D31 with thin yellow edge trim. The only glowing color is blue #3C8CFF.

Output: one square 1024x1024 PNG.
```

### 2. `barricade.png`

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: a low portable barricade in the same design language as the reference turret. Three gunmetal armor panels bolted together with sandbags at the base, hazard stripes on the panel edges, knee height, no weapons, no glowing parts. It stands on the same square dark steel base plate with a thin yellow edge trim as the reference.

Palette: gunmetal gray armor plates #3B3F45, darker recesses #25282C, yellow-black hazard stripes #E0B428 and #1A1A1A, base plate #2A2D31 with thin yellow edge trim. No glow.

Output: one square 1024x1024 PNG.
```

### 3. `wall.png`

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: a heavy wall block in the same design language as the reference turret. A solid dark gunmetal reinforced block with rivets, bolted panels and hazard stripe corners, chest height, no weapons, no glowing parts. It stands on the same square dark steel base plate with a thin yellow edge trim as the reference.

Palette: gunmetal gray armor plates #3B3F45, darker recesses #25282C, yellow-black hazard stripes #E0B428 and #1A1A1A, base plate #2A2D31 with thin yellow edge trim. No glow.

Output: one square 1024x1024 PNG.
```

### 4. `cannon_tower.png`

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: a heavy artillery cannon turret built like the reference turret. One huge short barrel on a bulky armored mount, hydraulic recoil pistons, orange glowing vents on the body. It stands on the same square dark steel base plate with a thin yellow edge trim as the reference.

Palette: gunmetal gray armor plates #3B3F45, darker recesses #25282C, yellow-black hazard stripes #E0B428 and #1A1A1A, base plate #2A2D31 with thin yellow edge trim. The only glowing color is orange #FF7A1E.

Output: one square 1024x1024 PNG.
```

### 5. `frost_tower.png`

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: a cryo turret built like the reference turret. A cylindrical coolant tank with cyan glowing liquid windows, a frost emitter dish on top, frost crystals on the metal. It stands on the same square dark steel base plate with a thin yellow edge trim as the reference.

Palette: gunmetal gray armor plates #3B3F45, darker recesses #25282C, yellow-black hazard stripes #E0B428 and #1A1A1A, base plate #2A2D31 with thin yellow edge trim. The only glowing color is cyan #4FD8FF.

Output: one square 1024x1024 PNG.
```

### 6. `flame_tower.png`

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: a flamethrower turret built like the reference turret. Twin fuel tanks on the back, a wide nozzle with a small red-orange pilot flame, scorched metal around the nozzle. It stands on the same square dark steel base plate with a thin yellow edge trim as the reference.

Palette: gunmetal gray armor plates #3B3F45, darker recesses #25282C, yellow-black hazard stripes #E0B428 and #1A1A1A, base plate #2A2D31 with thin yellow edge trim. The only glowing color is red-orange #FF4A16.

Output: one square 1024x1024 PNG.
```

### 7. `tesla_tower.png`

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: a tesla coil turret built like the reference turret. A tall coil with a violet glowing orb on top, small electric arcs around the orb, ceramic insulators on the body. It stands on the same square dark steel base plate with a thin yellow edge trim as the reference.

Palette: gunmetal gray armor plates #3B3F45, darker recesses #25282C, yellow-black hazard stripes #E0B428 and #1A1A1A, base plate #2A2D31 with thin yellow edge trim. The only glowing color is violet #9A7CFF.

Output: one square 1024x1024 PNG.
```

### 8. `sniper_tower.png`

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: a tall railgun sniper turret built like the reference turret. A slim tall body with one long thin barrel angled upward, a green laser sight glow at the scope. It stands on the same square dark steel base plate with a thin yellow edge trim as the reference.

Palette: gunmetal gray armor plates #3B3F45, darker recesses #25282C, yellow-black hazard stripes #E0B428 and #1A1A1A, base plate #2A2D31 with thin yellow edge trim. The only glowing color is green #5CE08A.

Output: one square 1024x1024 PNG.
```

---

## 적 4장 — 매번 `ref/rusher_ref.png` 첨부

### 9. `rusher.png` (다시 — 몸통 굵고 밝게)

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: the same alien creature as the reference, but redesigned to read clearly at a tiny size: a thicker compact body, shorter and sturdier legs, large glowing orange eyes, in a low aggressive lunging pose. Brighter and more saturated than the reference.

Palette: bright crimson red chitin #C8262A with dark charcoal joints #2B2224, glowing orange-yellow eyes and joint vents #FFA028. High contrast so it reads on dark ground.

Output: one square 1024x1024 PNG.
```

### 10. `tank.png`

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: the heavy variant of the same alien species as the reference. A massive armored brute with a thick plated carapace, heavy limbs, black bone spikes, a wide low stance, about three times the mass of the reference creature. Same chitin rendering as the reference.

Palette: dark violet-purple chitin #5A3D7A with dark charcoal joints #2B2224, the same glowing orange-yellow eyes and joint vents #FFA028 as the reference.

Output: one square 1024x1024 PNG.
```

### 11. `splitter.png`

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: the spore-carrier variant of the same alien species as the reference. A bloated round translucent yellow-green sac full of glowing larvae carried on thin legs, pulsing veins on the sac, the same chitin rendering on the legs and head as the reference.

Palette: yellow-green translucent sac #A8D830, dark charcoal joints #2B2224, the same glowing orange-yellow eyes #FFA028 as the reference.

Output: one square 1024x1024 PNG.
```

### 12. `mini.png`

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: a larva of the same alien species as the reference. A tiny compact soft body, short legs, small mandibles, a glowing green core visible through the skin. Simple silhouette, fills the frame.

Palette: pale green body #A8D830, dark charcoal joints #2B2224, glowing green core and small orange-yellow eyes #FFA028.

Output: one square 1024x1024 PNG.
```

---

## 선택: `gun_tower.png` 다시 만들 때 (기준 이미지가 마음에 안 들 때만)

```
Match the attached reference image exactly: the same painted semi-realistic rendering, the same color palette, the same isometric 3/4 top-down camera angle, the same soft directional light from the upper left, the same level of detail and edge crispness, and the same flat solid magenta background #FF00FF. Single object centered, full body visible, not cropped, no ground, no floor, no cast shadow, no text, no watermark.

Subject: a rapid-fire gun turret with twin machine gun barrels on a rotating mount, ammo belts, gold-yellow hazard stripes. It stands on a square dark steel base plate with a thin yellow edge trim.

Palette: gunmetal gray armor plates #3B3F45, darker recesses #25282C, yellow-black hazard stripes #E0B428 and #1A1A1A, base plate #2A2D31 with thin yellow edge trim. The only glowing color is gold #E0B428.

Output: one square 1024x1024 PNG.
```

---

## 결과가 어긋날 때 같은 대화창에 붙이는 수정 문장

- 화풍이 다를 때: `Closer to the attached reference: same painted rendering, same palette, same camera angle and lighting. Do not change the art style.`
- 배경이 이상할 때: `Flat solid magenta background #FF00FF only. No gradient, no floor, no shadow.`
- 받침판이 없을 때: `Put it on the same square dark steel base plate with a thin yellow edge trim as the reference turret.`
- 너무 어둡거나 탁할 때(적): `Brighter and more saturated red, glowing orange eyes must be clearly visible.`
