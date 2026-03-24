# SIKMUBYNCH - 3D 모델링 파이프라인 요구사항

> Ouroboros Phase 1 | 2026-03-24 | 모호성: 19%

## 목표 (Goal)

현재 코드 생성 프리미티브(BoxMesh, SphereMesh, CylinderMesh 등)로 렌더링되는 **모든 게임 엔티티**를 AI 생성 로우폴리 3D 모델(.glb)로 **일괄 교체**하여, Steam 스토어 페이지에 올릴 수 있는 상용 수준의 비주얼을 달성한다.

## 범위 (Scope)

| 카테고리 | 수량 | 대상 |
|---------|------|------|
| 건물 | 5 | HQ, Tower, Barracks, Miner, Buff Tower |
| 적 | 6 | Rusher, Tank, Splitter, Exploder, Elite Rusher, Destroyer |
| 유닛 | 4 | Soldier, Archer, Tanker, Bomber |
| 지형 | 1 | 맵 타일/지면 |
| 이펙트 | 3~5 | 발사체, 미네랄 오브, 폭발 등 |
| **합계** | **19~21** | |

## 제약조건 (Constraints)

- **폴리곤**: 모델당 ~1,000 triangles (Crossy Road/Superhot 수준 로우폴리)
- **텍스처**: 없음. 플랫 색상(vertex color 또는 단색 material)만 사용
- **스타일**: 다크 판타지 + 밀리터리, 로우폴리 스타일리쉬
- **포맷**: GLB (Godot 4 권장 포맷)
- **애니메이션**: 1차에서 제외. 정적 모델만 교체, 코드 애니메이션 유지
- **렌더러**: GL Compatibility (모바일 아님, PC 전용)
- **제작 도구**: AI 3D 생성 도구 (구체적 도구는 Phase 2에서 결정)
- **교체 전략**: 일괄 교체 (단계적 아님)

## 비목표 (Non-Goals)

- 본 파이프라인에서 애니메이션(걷기, 공격, 사망) 처리하지 않음
- PBR 텍스처(normal, roughness map 등) 제작하지 않음
- 기존 게임 로직 변경하지 않음 (메시 교체만)
- LOD(Level of Detail) 시스템 도입하지 않음

## 수용 기준 (Acceptance Criteria)

1. **비주얼**: 모든 엔티티가 통일된 로우폴리 스타일로 렌더링됨
2. **상용 기준**: Steam 스토어 페이지 스크린샷으로 사용 가능한 품질
3. **기능 무결성**: 모델 교체 후 기존 게임 기능(전투, 배치, 시너지 등) 100% 정상 동작
4. **성능 유지**: 500적 동시 60fps 기준 유지 (모델 교체로 인한 성능 저하 없음)
5. **실루엣 구분**: 각 엔티티 타입이 실루엣만으로 식별 가능

## 핵심 엔티티 (Ontology)

### 건물 (5종)
| 이름 | 현재 프리미티브 | 게임 역할 | 크기(그리드) |
|------|---------------|----------|------------|
| HQ | BoxMesh 3x3x1.5 | 본진, 방어 대상 | 3x3 |
| Tower | CylinderMesh h=0.35 | 자동 사격 타워 | 1x1 |
| Barracks | BoxMesh 1x1x0.8 + 배너 | 유닛 생산 | 2x1 |
| Miner | CylinderMesh h=0.4 | 미네랄 채굴 | 1x1 |
| Buff Tower | CylinderMesh + BoxMesh | 범위 버프 | 1x1 |

### 적 (6종)
| 이름 | 현재 프리미티브 | 게임 역할 | 색상 |
|------|---------------|----------|------|
| Rusher | PrismMesh | 빠른 돌진 | 빨강 |
| Tank | BoxMesh 0.6x | 높은 HP | 진회색 |
| Splitter | PrismMesh 다이아몬드 | 사망 시 분열 | 초록 |
| Exploder | SphereMesh 가시 | 자폭 | 주황 |
| Elite Rusher | SphereMesh | 강화 러셔 | 진빨강 |
| Destroyer | BoxMesh 0.8x | 보스급 | 보라 |

### 유닛 (4종)
| 이름 | 현재 프리미티브 | 게임 역할 | 색상 |
|------|---------------|----------|------|
| Soldier | CapsuleMesh | 근접 돌진 | 파랑 |
| Archer | CapsuleMesh 길쭉 | 원거리 | 녹색 |
| Tanker | BoxMesh | 높은 HP 탱커 | 금색 |
| Bomber | SphereMesh | 자폭 범위 | 빨강+파랑 |

## 노출된 가정과 해결

| 가정 | 해결 |
|------|------|
| AI 도구가 ~1,000 tris 로우폴리를 잘 생성함 | Phase 2에서 도구 비교 후 검증 |
| GLB 임포트 시 기존 콜리전/히트박스 유지 가능 | 코드에서 별도 Shape3D 사용 중이므로 가능 |
| 플랫 색상이 상용 수준으로 보일 수 있음 | emission + 이미션 글로우로 보완 (현재와 동일) |
| 일괄 교체 시 회귀 버그 관리 가능 | 기존 03-verification.md 체크리스트로 검증 |

## 명확도 추이

| Round | Goal | Constraint | Success | Context | 모호성 | 타겟 |
|-------|------|-----------|---------|---------|--------|------|
| 0 | 0.7 | 0.5 | 0.3 | 0.7 | 45% | 초기 |
| 1 | 0.7 | 0.5 | 0.5 | 0.7 | 37% | Success (상용 기준) |
| 2 | 0.7 | 0.7 | 0.5 | 0.7 | 31% | Constraint (~1000 tris) |
| 3 | 0.7 | 0.7 | 0.7 | 0.7 | 25% | Success (플랫 색상) |
| 4 | 0.9 | 0.7 | 0.7 | 0.9 | **19%** | Goal (일괄 교체) → **통과** |
