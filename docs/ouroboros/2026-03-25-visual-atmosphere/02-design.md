# Phase 2: 설계 — 어두운 분위기 + 조명

## ADR-1: 환경 조명 최소화
- DirectionalLight energy 1.2 → 0.15 (거의 없음)
- Ambient energy 0.5 → 0.08
- 배경색 더 어둡게: (0.01, 0.01, 0.015)

## ADR-2: WorldEnvironment Glow
- glow_enabled = true
- glow_intensity = 0.6, bloom = 0.3
- emission이 있는 오브젝트만 번짐 효과

## ADR-3: 건물 OmniLight3D
- 건물 생성 시 OmniLight3D 추가 (base_building.gd)
- HQ: 에너지 2.0, 반경 14, 파란색
- Tower: 에너지 1.2, 반경 8, 노란색
- Barracks: 에너지 0.8, 반경 6, 주황색
- Miner: 에너지 1.0, 반경 7, 청록색
- Buff: 에너지 1.5, 반경 10, 금색

## ADR-4: 적/유닛 emission 강화
- 적: emission_energy 1.8→3.0
- 유닛: emission_energy 1.2→2.0
- Exploder/Destroyer: emission_energy 5.0+

## ADR-5: 지면 셰이더 어둡게
- ground_dark: (0.02, 0.025, 0.02)
- ground_mid: (0.04, 0.045, 0.035)
- 격자선: (0.06, 0.07, 0.05)
- 비네트 강화: 0.3→0.15 (더 어두운 가장자리)
