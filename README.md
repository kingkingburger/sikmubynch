# SIKMUBYNCH (식무변처)

엄청난 물량이 몰려오고, 플레이어가 전투 중 건설과 배치로 방어선을 유지하는 2D 쿼터뷰 대규모 디펜스.

SIKMUBYNCH는 플레이어가 한 런 동안 본진을 지키며 자원을 모으고, 타워와 방어물을 배치하고, 점점 커지는 웨이브에 화력을 집중하는 생존 게임이다. 적은 쉬지 않고 몰려오며, 플레이어는 방어선을 임시로 막고, 화력을 집중하고, 무너진 곳을 다시 세우며 더 큰 웨이브를 버틴다.

## 핵심 경험

- **대규모 웨이브 압박**: 초반부터 적 무리가 보이고, 중후반에는 수천 단위의 호드가 방어선을 밀어붙인다.
- **전투 중 건설 판단**: 안전한 준비 페이즈가 아니라, 무너지는 방어선을 보며 즉석에서 방어물과 타워를 보강한다.
- **화력 집중**: 자원은 항상 부족하다. 어디를 막고 어디에 포격을 놓을지가 곧 전략이다.
- **대량 전투 피드백**: 개별 타격이 아니라 수백 마리가 동시에 터지고, 연쇄 처치와 방어선 붕괴가 화면과 소리로 즉시 보인다.
- **반복 런**: 실패 후 바로 다른 배치를 시도하게 만든다.

## 현재 상태

현재 구현은 상용 출시용 완성본이 아니라 핵심 전투 감각을 검증하는 프로토타입이다. M1~M7 범위의 여러 시스템이 들어갔지만, 기준은 기능 보유 여부가 아니라 “대규모 압박이 보이는가”, “배치 판단이 전투 결과를 바꾸는가”, “한 판 더 하고 싶은가”로 재정렬한다.

구현 이력:

- M1: 3D 이소메트릭 맵, 본진, 바리케이드, 적 스폰, 게임오버
- M2: 타워, 발사체, 레벨업, 철거, 멀티웨이브
- M3: 배럭, 4종 아군 유닛, 자동전투 AI
- M4: 6종 적, Flow Field 길찾기, 파도형 난이도, 미네랄 오브
- M5: 5종 특성 시너지, 보상 카드 3택, 이벤트, 채굴기, 버프 타워
- M6: 화면 흔들림, 히트스톱, 카메라, 속도 조절, 드래그 배치
- M7 이후: 256 맵 확장, StarCraft식 UI, 로우폴리 GLB 모델, 파티클, 로컬라이제이션

방향 전환:

- **2026-09-16**: 3D를 버리고 2D 쿼터뷰로 전환하며, 적·발사체를 Node에서 떼어내 시뮬레이션 배열로 옮기기로 결정했다. 엔진은 Godot을 유지한다.
- **2026-09-21**: 증강·보상 카드·시너지·이벤트·유닛·메타를 보류하고, 첫 프로토타입을 맵 1/본진 1/방어물 1~2/타워 3/적 3/자원 1/무한 웨이브로 축소했다. 물량은 100 → 500 → 1,000 → 5,000 → 10,000 순서로 올리며, 500마리에서 재미를 증명한 뒤 콘텐츠를 다시 얹는다.

- **2026-09-21 코드 전환**: 3D 씬·GLB 모델·보류 시스템 코드를 제거하고, `project/sim`(Node 없는 시뮬레이션)과 `project/render`(MultiMesh 2D 렌더러)로 재구성했다. 축소 범위(본진, 바리케이드·강화벽, 타워 3종, 적 3종+분열체, 미네랄, 무한 웨이브)가 2D 쿼터뷰에서 돌아간다. headless 소크에서 800~1,000마리 동시 생존 시 시뮬레이션 틱 평균 0.25 ms, 창 모드 895마리 렌더 약 1 ms를 확인했다. Flow Field 재계산(건물 배치·파괴 시) 30~40 ms 히치는 단계 D에서 다룬다.

전환 순서와 구조는 [기술 설계](docs/technical-design.md)를 따른다.

## 문서

- [제품 설명](docs/product-brief.md): 게임을 외부에 설명할 때 쓰는 짧고 명확한 소개 문서
- [게임 디자인](docs/game-design.md): 첫 프로토타입 범위, 핵심 루프, 웨이브 압박, 건물·적, 보류 시스템
- [기술 설계](docs/technical-design.md): 2D 전환 결정, 시뮬레이션/렌더러 분리 구조, 물량 단계, 성능 설계
- [제작 로드맵](docs/production-roadmap.md): 기반 전환 → 재미 증명 → 물량 확장 → 콘텐츠 재도입 순서
- [검증 계획](docs/quality-plan.md): 플레이 감각, 시스템, 성능, 출시 준비 검증 기준
- [미완성 작업 목록](docs/unfinished-work.md): 코드·실행 대조 결과, 남은 기능, 오류, 검증 항목과 우선순위
- [2D 아트 가이드](docs/2d-art-guide.md): 쿼터뷰 스프라이트 제작 및 교체 기준
- [사운드 가이드](docs/sound-guide.md): BGM/SFX 제작 및 적용 기준

## 실행

Godot 에디터에서 `project/` 폴더를 열고 F5로 실행한다.

회귀 검증은 PowerShell에서 Godot 실행 파일 경로를 지정해 실행한다.

```powershell
./tools/run-gameplay-tests.ps1 -GodotPath 'D:/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe'
```

검증은 네 스크립트로 나뉜다. 실행기는 headless 회귀와 headless 스모크를 순서대로 돌린다.

| 스크립트 | 실행 방식 | 다루는 것 |
| --- | --- | --- |
| `tools/tests/gameplay_regression.gd` | headless | 시작 상태, Flow Field, 배치·철거, 본진 도달·공격, 타워 처치·분열체, 웨이브 완료, 결정론(같은 seed 같은 해시), 봉쇄 돌파, 포격 광역·감속, 500마리 틱 예산 |
| `tools/tests/play_smoke.gd` | headless / 창 모드 | 게임 씬 로드, MultiMesh 버퍼, 씬을 통한 배치·철거, 화면→타일, 일시정지·ESC·속도, 게임오버·재시작, 500마리 렌더 |
| `tools/tests/soak_waves.gd` | headless | 스크립트 방어선으로 N웨이브(`SOAK_WAVES`)를 돌리며 웨이브별 규모·틱 시간·본진 HP 추세 기록 |
| `tools/tests/capture_screenshot.gd` | 창 모드 | 시작·방어선·줌아웃 800마리·줌인 스크린샷을 `build/shot-*.png`로 저장 |

```powershell
# 창 모드 스모크·스크린샷은 Godot을 직접 실행한다
D:/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe --path project --script ../tools/tests/play_smoke.gd
D:/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe --path project --script ../tools/tests/capture_screenshot.gd
```

과거 3D 프로토타입의 실행·플레이 결과는 [런 안정화 검증 기록](docs/verification/2026-09-08-run-stability.md)에 남아 있다.

## 조작

| 키 | 동작 |
| --- | --- |
| 1~5 | 건물 선택 (바리케이드, 속사 타워, 포격 타워, 감속 타워, 강화벽) |
| 좌클릭 (빈 타일) | 건물 배치. 바리케이드·강화벽은 드래그로 연속 배치 |
| 우클릭 (기존 건물) | 철거 (비용 50% 회수) |
| 우클릭 드래그 | 카메라 이동 |
| WASD | 카메라 이동 |
| 마우스 휠 | 줌 |
| Space | 일시정지 (건설 판단 가능, 전투·스폰 정지) |
| F | 게임 속도 전환 (1x → 2x → 3x) |
| ESC | 메뉴 (재개, 다시 시작, 타이틀) |
| F3 | 디버그 오버레이 (FPS, 적 수, 틱·렌더 시간, seed) |
| F4 | 디버그 빌드 전용: 본진 주변에 러셔 500마리 즉시 스폰 |

레벨업은 없다. 시작 시 본진 4방향에 속사 타워가 하나씩 있고 미네랄 150으로 시작한다. `SIKMUBYNCH_SEED` 환경변수로 런 seed를 고정할 수 있다.

## 프로젝트 구조

```text
project/
├── autoloads/          # Locale, GameManager(런 상태 미러), GameFeel, AudioManager
├── sim/                # Node 없는 시뮬레이션 (RefCounted + PackedArray)
│   ├── game_simulation.gd   # 고정 30Hz 틱, 하위 Sim 호출 순서, 런 상태, 결정론 해시
│   ├── enemy_sim.gd         # 적 배열, Flow Field 이동, 건물 접촉·공격 슬롯
│   ├── combat_sim.gd        # 타워 타겟팅, 발사체, 피해, 광역·감속
│   ├── wave_sim.gd          # 웨이브 규모·타입·방향, 스폰 큐
│   ├── building_sim.gd      # 건물 HP·타일 점유·공격자 상한
│   ├── flow_field.gd        # BFS 비용 필드 + 8방향 이동 벡터
│   ├── spatial_grid.gd      # 근접 탐색 셀 그리드
│   └── sim_config.gd        # 맵 크기, 틱, 상한 상수
├── render/             # 시뮬레이션 상태를 2D 쿼터뷰로 그린다
│   ├── enemy_renderer.gd    # 적 MultiMesh (타입별), 보간, 피격 플래시
│   ├── projectile_renderer.gd / effect_renderer.gd
│   ├── building_view.gd     # 건물 Node2D (이소 블록, HP 바)
│   ├── ground_renderer.gd / placement_view.gd / world_camera.gd
│   └── iso.gd / sprite_factory.gd   # 2:1 투영, 폴백 스프라이트
├── scenes/
│   ├── main/           # 타이틀, 메인 게임 씬(코디네이터)
│   └── ui/             # HUD (자원, 본진 체력, 슬롯, 웨이브 배너, 위협 레이더, 메뉴, 결과)
├── scripts/            # 건물·적 카탈로그, 위협 레이더, Resource 데이터 정의(data/)
└── assets/audio/       # BGM, SFX

docs/                   # 제품·설계·검증 문서와 제작 가이드
tools/tests/            # headless 회귀, 씬 스모크, 소크, 스크린샷 캡처
```
