# SIKMUBYNCH - Steam 출시 요구사항 (초안)

> Ouroboros Phase 1 Draft | 2026-03-24 | 사용자 확인 필요

## 목표 (Goal)

SIKMUBYNCH(식무변처)를 Steam 스토어에 출시하여 유료 판매 가능한 상태로 만든다. Steamworks 개발자 등록부터 스토어 페이지 구축, Steam API 통합, 법적 요건 충족, 빌드 배포까지 전체 파이프라인을 수립한다.

---

## 필수 작업 목록

### A. Steamworks 개발자 등록 및 앱 설정

| 단계 | 내용 | 비용/기간 |
|------|------|----------|
| 1 | Steamworks 파트너 프로그램 가입 (partner.steamgames.com) | 무료 |
| 2 | Steam Direct 앱 등록비 결제 | **$100 USD / 앱** |
| 3 | 세금 인터뷰 완료 (W-8BEN 양식 — 한국 거주자) | 5~10분 |
| 4 | 은행 정보 및 신원 확인 | 서류 준비 필요 |
| 5 | 앱 ID 발급 대기 | 등록비 결제 후 즉시~수일 |
| 6 | 30일 대기 기간 (결제→출시 가능 최소 간격) | **30일** |

**$100 등록비 회수 조건**: 해당 앱의 Steam 스토어 + 인앱 구매 합산 매출이 $1,000 이상 달성 시 환급됨.

**한국 개발자 세금 관련**:
- 한국-미국 조세조약 적용 가능 → W-8BEN 양식에 한국 납세자번호(TIN) 기재 시 원천징수율 감면 (기본 30% → 조약 적용 시 감면)
- 미국 내 매출분만 원천징수 대상 (IRS Form 1042-S로 연간 보고)
- 한국 내 소득세/부가세 별도 신고 필요

**수익 배분**:
- Steam 기본: **70% 개발자 / 30% Valve**
- $10M 초과분: 75/25, $50M 초과분: 80/20
- 정산 주기: 월별 (매출 발생 후 30일 이내)

### B. GodotSteam 통합 (기술)

| 항목 | 내용 |
|------|------|
| GodotSteam 플러그인 | Godot 4.x용 GodotSteam 플러그인 설치 (godotsteam.com) |
| Steamworks SDK | 최신 Steamworks SDK 다운로드 및 연동 |
| steam_appid.txt | 개발 시 프로젝트 루트에 배치 (앱 ID 기재), **출시 빌드에서는 제외** |
| Steam 초기화 | `Steam.steamInit()` 호출 + `_process()`에서 `Steam.run_callbacks()` 실행 |
| Export Template | GodotSteam 활성화된 커스텀 Export Template 사용 필수 (일반 템플릿 사용 시 크래시) |
| 빌드 명령 | `--export-release` + `--headless` 플래그로 CLI 빌드 가능 |
| 업로드 | SteamCMD 또는 Steamworks 파트너 사이트에서 직접 ZIP 업로드 |

### C. Steam 기능 통합

| 기능 | 필수 여부 | 구현 난이도 | 설명 |
|------|----------|-----------|------|
| **업적 (Achievements)** | 권장 | 중 | Steamworks 대시보드에서 업적 정의 → GodotSteam API로 해제. SDK 1.61+부터 자동 동기화 |
| **클라우드 세이브** | 권장 | 하 | Steam Auto-Cloud 사용 시 코드 수정 없이 파일 그룹 지정만으로 동기화 가능 |
| **Steam 오버레이** | 필수 | 자동 | Steamworks SDK 연동 시 자동 활성화 |
| **리치 프레즌스** | 선택 | 하 | 친구 목록에 현재 게임 상태 표시 |
| **리더보드** | 선택 | 중 | 웨이브 기록, 킬 수 등 경쟁 요소 |
| **트레이딩 카드** | 선택 | 별도 | Valve 심사 필요, 출시 후 일정 매출 달성 시 신청 가능 |
| **Steam Input** | 선택 | 중 | 컨트롤러 지원 (현재 키보드+마우스 전용이므로 후순위) |

**업적 후보 (예시)**:
- 첫 웨이브 클리어
- 500킬 달성
- 모든 시너지 조합 활성화
- 웨이브 10/20/30 도달
- 무손실 웨이브 클리어
- 모든 건물 타입 배치
- 특정 이벤트 완료

### D. 빌드 및 QA

| 항목 | 내용 |
|------|------|
| 지원 OS | Windows (필수), Linux (권장), macOS (선택) |
| 최소/권장 사양 | 테스트 후 확정 (GL Compatibility 렌더러 → 저사양 호환 예상) |
| 해상도 지원 | 기본 1280x720, 풀스크린/창모드 전환, 16:9/16:10/21:9 테스트 |
| 빌드 크기 | 최적화 후 측정 (로우폴리 + 텍스처 없음 → 소형 예상) |
| 스팀 덱 호환 | 테스트 권장 (Deck Verified 뱃지 획득 시 노출 증가) |
| 크래시 핸들링 | 에러 로깅 + Steam 크래시 리포트 연동 |
| 안티치트 | 싱글플레이 전용이므로 불필요 |

---

## 스토어 페이지

### 필수 그래픽 에셋

| 에셋 | 크기 | 용도 |
|------|------|------|
| **Header Capsule** | 920 x 430 px | 스토어 페이지 상단, 추천 섹션, 데일리 딜 |
| **Small Capsule** | 462 x 174 px | 검색 결과, 카테고리 목록 |
| **Main Capsule** | 920 x 430 px | 메인 스토어 노출 |
| **Library Capsule** | 600 x 900 px | Steam 라이브러리 세로형 |
| **Library Hero** | 3840 x 1240 px | 라이브러리 배경 이미지 |
| **Library Logo** | 1280 x 1280 px | 라이브러리 로고 |
| **Page Background** | 1438 x 810 px | 스토어 페이지 배경 (선택) |

**캡슐 이미지 규칙**: 게임 아트워크 + 게임 이름(로고)만 포함. 수상 내역, 리뷰 점수, 마케팅 문구 삽입 금지.

### 스크린샷

- **최소 5장** (권장 10장+)
- **1920 x 1080** 이상 와이드스크린
- **실제 게임 플레이** 화면만 (컨셉아트, 시네마틱, 마케팅 문구 금지)
- 최소 4장은 "전연령 적합" 마킹 필요
- 권장 내용: 대규모 전투, 건설 화면, 시너지 UI, 보상 선택, 보스 웨이브

### 트레일러

- **최소 1개** 필수 (출시 프로세스 요건)
- 최대 해상도: **1920 x 1080**, 30/60fps
- 비트레이트: 5,000+ Kbps
- 포맷: .mp4, .mov, .wmv
- 스토어 썸네일 영역에 최대 **2개** 트레일러 노출 (나머지는 스크린샷 뒤로)
- 권장: 게임플레이 트레일러 (60~90초) + 시네마틱/분위기 트레일러

### 스토어 설명문

- **짧은 설명**: 1~2문장 요약 (검색 결과에 노출)
- **긴 설명**: 게임 특징, 시스템, 핵심 세일즈 포인트
- **외부 링크 금지** (URL, QR코드, 이미지 내 링크 포함)
- **다국어**: 한국어 + 영어 설명 별도 작성

### 태그

최대 **5개** 태그 설정 가능. 추천:
- Tower Defense
- Wave Defense (또는 Survival)
- Roguelike / Roguelite
- Strategy
- Real-Time Strategy (RTS)

### Coming Soon 페이지 타임라인

| 시점 | 행동 |
|------|------|
| 출시 6~9개월 전 | Coming Soon 페이지 공개 → 위시리스트 수집 시작 |
| 출시 최소 2주 전 | Coming Soon 상태 필수 유지 (Steam 정책) |
| 출시 2~4개월 전 | Steam Next Fest 참가 (데모 빌드 준비) |
| 4~6주 간격 | 개발 업데이트 포스트 (위시리스트 알림 트리거) |

**위시리스트 목표**: 최소 7,000~10,000 (인디 게임 런칭 시 의미 있는 첫주 매출 기준)

---

## 법적/행정

### 필수 사항

| 항목 | 내용 |
|------|------|
| **Steamworks 개발자 계약** | 파트너 등록 시 디지털 서명 |
| **세금 인터뷰** | W-8BEN 양식 (비미국 거주자) + 한국 TIN |
| **콘텐츠 설문** | Steamworks 콘텐츠 서베이 작성 → 연령 등급 자동 산출 |
| **독일 연령 등급** | 2024.11.15부터 필수. Valve 자체 등급 또는 USK 등급 필요 |
| **IARC 등급** | 무료, 글로벌 통합 등급 시스템. 가능하면 취득 권장 |

### 권장 사항

| 항목 | 내용 |
|------|------|
| **EULA** | Steam 기본 EULA 사용 가능. 커스텀 EULA는 선택사항 |
| **개인정보보호정책** | 플레이어 데이터 수집 시 필수 (분석, 클라우드 세이브 등). GDPR(유럽)/CCPA(캘리포니아) 준수 |
| **사업자 등록** | 개인 명의 출시 가능 (법인 불필요). 단, 매출 규모에 따라 사업자 등록 권장 |
| **저작권 표기** | (c) 2026 [개발자명]. All rights reserved. |

### 한국 특이사항

| 항목 | 내용 |
|------|------|
| 게임물등급위원회 | PC 게임 자체 등급 분류 가능 여부 확인 필요 (Steam 글로벌 배포 시) |
| 부가가치세 | 전자적 용역의 해외 공급 → 부가세 신고 여부 확인 |
| 소득세 | 해외 플랫폼 수입 종합소득세 신고 |

---

## Early Access vs Full Release 전략

### 비교

| 항목 | Early Access | Full Release |
|------|-------------|-------------|
| **장점** | 커뮤니티 피드백 반영, 개발비 조기 확보, 점진적 완성 | 완성도 높은 첫인상, 리뷰 리스크 낮음 |
| **단점** | 미완성 인상, "영원한 EA" 리스크, EA 매출 > 정식 매출 경향 | 피드백 반영 기회 제한, 런칭 실패 시 회복 어려움 |
| **적합 조건** | 컨텐츠 확장 계획 많음, 커뮤니티 주도 밸런싱 필요 | 코어 루프 완성, 충분한 콘텐츠량 |

### 현재 프로젝트 상태 평가

- M1~M7 완료 → 코어 루프 + 메타 시스템 + 폴리시 완결
- 3D 모델링 교체 별도 진행 중
- 사운드/음악 미확인
- 콘텐츠 볼륨 (맵 다양성, 웨이브 수, 유닛/적 종류) 평가 필요

**잠정 권장**: Early Access 또는 Full Release 여부는 사용자 결정 사항 → 미해결 질문 참조

---

## 가격 책정

### 장르 벤치마크 (인디 웨이브 디펜스 / 타워 디펜스 / 로그라이크)

| 게임 | 장르 | 가격 |
|------|------|------|
| They Are Billions | 웨이브 디펜스 RTS | $29.99 |
| Legion TD 2 | 멀티플레이어 타워디펜스 | $19.99 |
| Wave Defense: Trappist | 웨이브 디펜스 로그라이크 | ~$9.99 |
| Gnomes | 타워디펜스 로그라이크 | ~$14.99 |
| Vampire Survivors | 웨이브 서바이벌 로그라이크 | $4.99 |

### 2026 인디 게임 가격 전략

- **$15~$20 가격대**가 PC 인디 게임의 최적 구간 (품질 기대 초과 시 오가닉 성장)
- **$30 이상**은 브랜드 인지도/기존 팬베이스 없이는 전환율 급락
- **$10 미만**은 "가벼운 게임" 인식 리스크
- 출시 할인: 10~20% (Steam 정책상 출시 2주 내 할인 가능)
- 지역 가격 설정: Steam 자동 권장가 참고 (한국 원화 포함)

**잠정 권장 가격대**: $14.99~$19.99 (콘텐츠 볼륨 및 완성도에 따라 최종 결정)

---

## 미해결 질문

> 아래 항목들은 Ouroboros 본 프로세스(Phase 1 정식)에서 사용자와 Q&A를 통해 확정해야 합니다.

### 출시 전략

1. **Early Access vs Full Release** — 어느 전략을 선호하는가? 추가 콘텐츠 확장 계획이 있는가?
2. **목표 출시 시기** — 2026년 내 출시 목표인가? 구체적 목표 분기가 있는가?
3. **데모 빌드** — Steam Next Fest 참가를 위한 데모 빌드를 별도로 만들 의향이 있는가?

### 콘텐츠 및 완성도

4. **사운드/음악** — 현재 BGM, 효과음 상태는? 별도 제작/구매 계획이 있는가?
5. **콘텐츠 볼륨** — 현재 맵 1개, 웨이브 수, 유닛 4종, 적 6종으로 충분한가? 추가 콘텐츠 계획은?
6. **3D 모델링 진행도** — 모델링 교체 완료 예상 시기는? 스토어 스크린샷 촬영 가능 시점은?
7. **튜토리얼/온보딩** — 신규 플레이어를 위한 튜토리얼이 있는가? 필요한가?
8. **밸런싱** — 외부 플레이테스트를 진행했거나 계획이 있는가?

### 플랫폼

9. **지원 OS** — Windows 전용인가? Linux/macOS 빌드도 제공할 것인가?
10. **컨트롤러 지원** — 키보드+마우스 전용 유지인가? Steam Deck 대응은?

### 법적/행정

11. **개발자 이름** — Steam 스토어에 표시할 개발자/퍼블리셔 이름은? (개인명 vs 스튜디오명)
12. **사업자 등록** — 개인 명의로 출시할 것인가? 사업자 등록(간이/일반) 계획이 있는가?
13. **데이터 수집** — 플레이어 분석 데이터를 수집할 계획인가? (개인정보보호정책 필요 여부 결정)

### 마케팅

14. **마케팅 예산** — 광고/인플루언서 마케팅 예산이 있는가? (0원 마케팅 전략도 가능)
15. **커뮤니티 채널** — Discord 서버, SNS 계정 운영 계획이 있는가?
16. **그래픽 에셋 제작** — 캡슐 이미지, 로고 등을 직접 만들 수 있는가? 외주 계획은?
17. **트레일러 제작** — 게임플레이 트레일러를 직접 제작할 수 있는가? 외주 계획은?

### 가격

18. **가격대** — $14.99~$19.99 범위에 동의하는가? 다른 가격 선호가 있는가?
19. **DLC/확장팩 계획** — 출시 후 유료 DLC를 계획하는가?

---

## 참고 자료

### Steamworks 공식 문서
- [Steamworks Partner Program (Steam Direct)](https://partner.steamgames.com/steamdirect)
- [Steam Direct Fee](https://partner.steamgames.com/doc/gettingstarted/appfee)
- [Getting Started](https://partner.steamgames.com/doc/gettingstarted)
- [FAQ](https://partner.steamgames.com/doc/gettingstarted/faq)
- [Release Process](https://partner.steamgames.com/doc/store/releasing)
- [Store Graphical Assets](https://partner.steamgames.com/doc/store/assets/standard)
- [Graphical Asset Rules](https://partner.steamgames.com/doc/store/assets/rules)
- [Library Assets](https://partner.steamgames.com/doc/store/assets/libraryassets)
- [Trailers](https://partner.steamgames.com/doc/store/trailer)
- [Store Page Description](https://partner.steamgames.com/doc/store/page/description)
- [Editing A Store Page](https://partner.steamgames.com/doc/store/editing)
- [Steam Cloud](https://partner.steamgames.com/doc/features/cloud)
- [Taxes FAQ](https://partner.steamgames.com/doc/finance/taxfaq)
- [Taxes FAQ (한국어)](https://partner.steamgames.com/doc/finance/taxfaq?l=koreana)
- [Reporting and Payments FAQ](https://partner.steamgames.com/doc/finance/payments_salesreporting/faq)
- [Age Ratings - Germany](https://partner.steamgames.com/doc/gettingstarted/contentsurvey/germany)

### GodotSteam
- [GodotSteam 공식 사이트](https://godotsteam.com/)
- [GodotSteam - Initializing Steam](https://godotsteam.com/tutorials/initializing/)
- [GodotSteam - Exporting and Shipping](https://godotsteam.com/tutorials/exporting_shipping/)
- [GodotSteam GitHub](https://github.com/GodotSteam/GodotSteam)

### 마케팅 및 전략
- [How Many Wishlists Should I Have When I Launch (howtomarketagame.com)](https://howtomarketagame.com/2022/09/26/how-many-wishlists-should-i-have-when-i-launch-my-game/)
- [Steam Wishlist to Sales Ratio 2025 (game-oracle.com)](https://www.game-oracle.com/blog/wishlist-to-sales-2025)
- [Roadmap to Indie Game Marketing 2026 (game-developers.org)](https://www.game-developers.org/roadmap-to-an-effective-indie-game-marketing-strategy-in-2026)
- [Steam Next Fest Marketing Strategies (biggamesmachine.com)](https://www.biggamesmachine.com/steam-next-fest-marketing-strategies/)
- [What Devs Should Do Before Launching Steam Page (gameworldobserver.com)](https://gameworldobserver.com/2025/03/11/steam-page-launch-guide-wishlists-zukowski)

### 가격/시장 분석
- [Indie Game Monetization 2026 (dev.to)](https://dev.to/linou518/indie-game-monetization-in-2026-premium-dlc-or-subscription-which-path-is-right-for-you-955)
- [Steam Tower Defense Fest 2026 Top Sellers (gamegrin.com)](https://www.gamegrin.com/news/steam-tower-defense-fest-2026-top-sellers/)
- [Steam Revenue Calculator 2026 (generalistprogrammer.com)](https://generalistprogrammer.com/tools/steam-revenue-calculator)
- [Steam Game Releases 2025 Analytics (indielaunchlab.com)](https://indielaunchlab.com/analytics/steam-reports/2025)

### 법적
- [Game Publishing Legal Requirements for Indie Devs (wayline.io)](https://www.wayline.io/blog/game-publishing-legal-requirements-indie-dev)
- [IARC - International Age Rating Coalition](https://www.globalratings.com/)
- [Every Image You Need for Steam Store Page (game-oracle.com)](https://www.game-oracle.com/blog/steam-store-images)

### Early Access
- [Early Access Pros and Cons (GameMaker)](https://gamemaker.io/en/blog/early-access-games)
- [Early Access: Help or Hurt (xsolla.com)](https://xsolla.com/blog/early-access-will-it-help-or-hurt-your-game)
- [Why Devs Should Treat EA Launch Like Full Release (gameworldobserver.com)](https://gameworldobserver.com/2023/02/21/early-access-vs-full-launch-why-devs-should-treat-them-equally)
