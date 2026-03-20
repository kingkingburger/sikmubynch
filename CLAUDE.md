# SIKMUBYNCH (식무변처)

## 프로젝트 개요

대규모 웨이브 디펜스 + 오토배틀 + 로그라이크. They Are Billions 스타일 실시간 건설+전투 + 롤토체스 시너지 시스템.

## 기술 스택

- Godot 4 + GDScript
- 2D 탑다운, 픽셀아트
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
project/                                # Godot 4 프로젝트 (예정)
  autoloads/                            # 싱글톤 매니저
  scenes/                               # 씬 파일 (.tscn)
  scripts/                              # 로직 스크립트
  resources/                            # 데이터 정의 (.tres)
  assets/                               # 스프라이트, 사운드
docs/ouroboros/{date}-{slug}/           # Ouroboros 프로세스 문서
  01-requirements.md                    # Phase 1: 요구사항
  02-design.md                          # Phase 2: 설계
  03-verification.md                    # Phase 3: 검증
mockup.html                             # UI/레이아웃 목업 (디아블로 스타일 이소메트릭)
index.html                              # (레거시) 웹 프로토타입
```

## 현재 상태

Ouroboros 3Phase 완료 (94개 결정 확정). Godot 4 프로젝트 생성 대기 중.
- 요구사항 94개 결정 확정 (Clarify 4차)
- 설계/검증 문서 완성 (Round 13-20 반영 필요)
- HTML 목업 완성 (디아블로 스타일 이소메트릭)
- 이전 웹 프로토타입(index.html)은 레거시 — 컨셉 참고용
