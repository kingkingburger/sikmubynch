# SIKMUBYNCH (식무변처)

## 프로젝트 개요

대규모 웨이브 디펜스 + 오토배틀 + 로그라이크. They Are Billions 스타일 실시간 건설+전투 + 롤토체스 시너지 시스템.

## 기술 스택

- Godot 4 + GDScript
- 3D 이소메트릭 (디아블로/스타크래프트 스타일), GL Compatibility 렌더러
- 비주얼: 다크 판타지 + 밀리터리, 로우폴리 스타일리쉬 모델
- 로컬라이제이션: 한글(기본) + 영문 토글 (Locale autoload)
- PC 전용 (키보드 + 마우스)

## 핵심 가치

1. **타격감** — 화면 흔들림, 히트스톱, 파티클. 대량 적 처치 시 쾌감
2. **대규모 전투** — 첫 웨이브부터 압도적 물량. 500+ 동시 적
3. **"한 판 더"** — 시너지 조합 + 랜덤 맵/보상으로 매 런이 다름

## 개발 방식

- Ouroboros 프로세스로 요구사항/설계/검증 문서화 (`docs/ouroboros/`)
- 프로토타입 우선: 구현 → 플레이 → 피드백 → 반복
- 기술 결정은 자율적으로, 게임 경험 관련만 사용자 확인

## 프로젝트 구조

```
project/                                # Godot 4 프로젝트
  project.godot                         # 엔진 설정
  autoloads/                            # 싱글톤 매니저 (Locale, GameManager, FlowField, SynergyManager, EventManager, GameFeel, ObjectPool)
  scenes/                               # 씬 파일 (.tscn)
    main/                               #   메인 게임 씬
    buildings/                          #   건물 씬 (HQ, Barricade, Tower, Barracks)
    enemies/                            #   적 유닛 씬 (6종)
    units/                              #   아군 유닛 씬 (4종)
    projectiles/                        #   발사체 씬
    effects/                            #   이펙트 씬 (미네랄 오브)
  scripts/data/                         # 데이터 정의 (Resource 클래스)
  assets/                               # 스프라이트, 사운드
docs/ouroboros/{date}-{slug}/           # Ouroboros 프로세스 문서
  01-requirements.md                    # Phase 1: 요구사항
  02-design.md                          # Phase 2: 설계
  03-verification.md                    # Phase 3: 검증
mockup.html                             # UI/레이아웃 목업 (디아블로 스타일 이소메트릭)
```

## 현재 상태

M7 폴리시까지 전체 구현 완료. 7-마일스톤 로드맵 (M1-M7) 완결.
- M1 코어 루프: 3D 이소메트릭, 건설, 적 스폰, 게임오버
- M2 전투 기반: 타워 + 발사체 + 레벨업 + 멀티웨이브
- M3 유닛 시스템: 배럭 + 4종 유닛 (솔저/아처/탱커/폭탄병) + 오토배틀 AI
- M4 웨이브 + 적 다양성: 적 6종 + Flow Field 길찾기 + 파도형 난이도 + 미네랄 오브
- M5 메타 시스템: 5종 특성 시너지 + 보상 카드 3택 + 이벤트 10종 + 채굴기/버프 타워
- M6 게임 필: 타격감(쉐이크/히트스톱/크리티컬) + WASD 카메라 + 줌 + 속도 조절 + 드래그 배치
- M7 폴리시: 시작 화면 + ESC 메뉴 + 디버그 오버레이(F3) + 비주얼 오버홀(그림자/지형 셰이더/모델) + 로컬라이제이션(한/영)

## 주요 시스템

- **Locale**: 다국어 (한글/영문), 타이틀 화면에서 전환
- **GameManager**: 게임 상태 (미네랄, 웨이브, 킬 카운트)
- **FlowField**: BFS 기반 적 집단 길찾기
- **SynergyManager**: 5종 특성 시너지 계산 + 보너스
- **EventManager**: 전투/선택 이벤트 시스템
- **GameFeel**: 화면 흔들림, 히트스톱, 게임 속도 관리
- **ObjectPool**: 발사체/이펙트 재사용 풀
