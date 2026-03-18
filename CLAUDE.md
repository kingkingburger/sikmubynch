# SIKMUBYNCH (식무변처)

## 프로젝트 개요

무한 웨이브 하이브리드 디펜스 게임. 건물 배치 + 유닛 생산 복합 방어.

## 기술 스택

- HTML + Three.js (CDN), 싱글 HTML 파일 프로토타입
- 빌드 도구 없음. `index.html`을 브라우저에서 직접 열어 실행
- 개발 시 `bunx live-server --open` 권장

## 개발 방식

- Ouroboros 프로세스로 요구사항/설계/검증 문서화 (`docs/ouroboros/`)
- 프로토타입 우선: 구현 → 플레이 → 피드백 → 반복
- 기술 결정은 자율적으로, 게임 경험 관련만 사용자 확인

## 프로젝트 구조

```
index.html                          # 게임 본체 (Three.js 싱글 파일)
docs/ouroboros/{date}-{slug}/       # Ouroboros 프로세스 문서
  01-requirements.md                # Phase 1: 요구사항
  02-design.md                      # Phase 2: 설계 (미완)
  03-verification.md                # Phase 3: 검증 (미완)
```

## 현재 상태

초기 프로토타입 단계. Ouroboros Phase 1 진행 중 (모호성 63%).
