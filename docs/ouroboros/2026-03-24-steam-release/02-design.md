# SIKMUBYNCH - Steam 출시 설계

> Ouroboros Phase 2 | 2026-03-24 | 모호성: 17%

## ADR (Architecture Decision Records)

### ADR-S1: 가격 모델 — 무료 + 후원

- **결정**: Steam Free to Play로 배포, 후원 DLC ($1~$5) + 외부 후원 링크 (Ko-fi 등)
- **대안**: $9.99 EA / $14.99 EA / 무료만
- **선택 근거**:
  - 진입 장벽 제거 → 최대 다운로드 확보
  - 후원 DLC로 Steam 내 수익 경로 확보
  - 외부 링크로 추가 후원 채널 운영
  - F2P 게임은 Steam 알고리즘에서 노출 유리 (다운로드 수 기반)

### ADR-S2: Steam 기능 — 전체 포함

- **결정**: GodotSteam + 오버레이 + 클라우드 세이브 + 업적 + 리더보드 + 리치 프레즌스 전부 구현
- **대안**: 최소한만 / 업적까지만
- **선택 근거**:
  - 사용자가 "전부 다" 선택
  - 리더보드와 리치 프레즌스가 커뮤니티 형성에 기여
  - GodotSteam이 모든 기능을 단일 API로 제공하므로 추가 비용 없음

### ADR-S3: 세이브 시스템 — 통계만

- **결정**: 런 중 진행 저장 없음. 누적 통계(최고 웨이브, 총 킬, 플레이 횟수 등)만 저장
- **대안**: 런 중 세이브/로드 / 통계+런 세이브 둘 다
- **선택 근거**:
  - 로그라이크 장르 특성상 런 중 저장은 비핵심
  - 통계는 업적/리더보드와 연동 가능
  - 구현 복잡도 최소화
  - Steam Auto-Cloud로 통계 파일만 동기화

### ADR-S4: 화면 설정 — 옵션 제공

- **결정**: 풀스크린/창모드 + 해상도 선택(720p/1080p/1440p) + V-Sync
- **대안**: 기본만 (풀스크린/창모드 토글)
- **선택 근거**: 상용 게임 기본 요구사항. ESC 메뉴에 설정 탭 추가

### ADR-S5: 튜토리얼 — 없음

- **결정**: 튜토리얼/온보딩 구현하지 않음
- **대안**: 간단 팁 표시 / 대화형 튜토리얼
- **선택 근거**: 사용자 결정. EA 기간 중 피드백에 따라 추후 추가 가능

---

## 시스템 아키텍처

### 신규 Autoload

```
기존: Locale → GameManager → FlowField → SynergyManager → EventManager → GameFeel → ObjectPool
추가: SteamManager → StatsManager → SettingsManager → AudioManager
```

| Autoload | 역할 |
|----------|------|
| **SteamManager** | Steam 초기화, 콜백, 업적 해제, 리더보드, 리치 프레즌스 |
| **StatsManager** | 누적 통계 저장/로드 (JSON → user://stats.json) |
| **SettingsManager** | 해상도/풀스크린/V-Sync/볼륨 설정 저장 (user://settings.json) |
| **AudioManager** | BGM/SFX 재생 관리 |

### 시그널 흐름 (Steam 연동)

```
GameManager.kill_count 변경 → StatsManager.record_kill() → SteamManager.check_achievements()
GameManager.wave_number 변경 → StatsManager.record_wave() → SteamManager.update_leaderboard()
GameManager.game_over → StatsManager.record_run() → SteamManager.upload_score()
game.gd 시작 → SteamManager.set_rich_presence("웨이브 {n} 진행 중")
```

---

## 파일별 구현 계획

### 신규 파일 (4개)

#### `project/autoloads/steam_manager.gd`
```
- _ready(): Steam.steamInit(), App ID 확인
- _process(): Steam.run_callbacks()
- set_achievement(name: String): Steam.setAchievement(name), Steam.storeStats()
- upload_score(board: String, score: int): Steam 리더보드 업로드
- set_rich_presence(status: String): Steam.setRichPresence("status", status)
- is_steam_running() -> bool: Steam 클라이언트 실행 여부
```

#### `project/autoloads/stats_manager.gd`
```
- 저장 경로: user://stats.json
- 통계 항목:
  - total_kills: int
  - total_runs: int
  - best_wave: int
  - best_kill_count: int
  - total_play_time: float
  - buildings_placed: int
  - synergies_activated: Dictionary
- save(): JSON 직렬화 → 파일 쓰기
- load(): 파일 읽기 → JSON 파싱
- record_kill(): total_kills += 1, 업적 체크
- record_wave(n): best_wave = max(best_wave, n)
- record_run(): total_runs += 1, 저장
```

#### `project/autoloads/settings_manager.gd`
```
- 저장 경로: user://settings.json
- 설정 항목:
  - fullscreen: bool (기본 true)
  - resolution: Vector2i (기본 1920x1080)
  - vsync: bool (기본 true)
  - master_volume: float (기본 0.8)
  - music_volume: float (기본 0.7)
  - sfx_volume: float (기본 0.8)
  - language: String (기본 "ko")
- apply(): DisplayServer 설정 적용
- save()/load(): JSON 직렬화
```

#### `project/autoloads/audio_manager.gd`
```
- BGM: AudioStreamPlayer (단일 트랙, 크로스페이드)
- SFX: AudioStreamPlayer 풀 (동시 8개)
- play_bgm(stream: AudioStream)
- play_sfx(stream: AudioStream, volume_db: float = 0.0)
- set_master_volume(vol: float)
- set_music_volume(vol: float)
- set_sfx_volume(vol: float)
```

### 수정 파일

#### `project/project.godot`
```
- [autoload] 섹션에 SteamManager, StatsManager, SettingsManager, AudioManager 추가
- [display] 해상도/풀스크린 기본값 업데이트
```

#### `project/autoloads/game_manager.gd`
```
- signal kill_reached(count: int) 추가
- signal wave_cleared(wave: int) 추가
- add_kill(): kill_count += 1, kill_reached.emit(kill_count)
- advance_wave(): wave_number += 1, wave_cleared.emit(wave_number)
```

#### `project/scenes/main/game.gd`
```
- _ready(): SteamManager 연결, AudioManager BGM 시작
- _on_wave_cleared(): StatsManager.record_wave(), SteamManager.set_rich_presence()
- _on_game_over(): StatsManager.record_run(), SteamManager.upload_score()
- ESC 메뉴에 설정 탭 추가 (SettingsManager 연동)
```

#### `project/scenes/main/title.gd`
```
- _ready(): AudioManager.play_bgm(title_bgm)
- 설정 버튼 추가 (SettingsManager UI)
- 통계 표시 (StatsManager 데이터)
```

### 신규 리소스 파일

```
project/assets/audio/
├── bgm/
│   ├── title.ogg           # 타이틀 BGM
│   └── battle.ogg          # 전투 BGM
└── sfx/
    ├── hit.ogg             # 타격
    ├── death.ogg           # 적 사망
    ├── build.ogg           # 건물 배치
    ├── destroy.ogg         # 건물 파괴
    ├── wave_start.ogg      # 웨이브 시작
    ├── synergy.ogg         # 시너지 발동
    ├── reward.ogg          # 보상 선택
    ├── levelup.ogg         # 레벨업
    └── ui_click.ogg        # UI 클릭
```

---

## 업적 설계 (15개)

| ID | 이름 | 조건 | 난이도 |
|----|------|------|--------|
| FIRST_BLOOD | 첫 처치 | 첫 킬 | ★ |
| WAVE_5 | 5번째 파도 | 웨이브 5 도달 | ★ |
| WAVE_10 | 열 번째 파도 | 웨이브 10 도달 | ★★ |
| WAVE_20 | 스무 번째 파도 | 웨이브 20 도달 | ★★★ |
| KILL_100 | 백인참수 | 누적 100 킬 | ★ |
| KILL_1000 | 천인참수 | 누적 1,000 킬 | ★★ |
| KILL_10000 | 만인참수 | 누적 10,000 킬 | ★★★ |
| ALL_BUILDINGS | 건축왕 | 5종 건물 모두 배치 | ★ |
| SYNERGY_T2 | 시너지 각성 | Tier 2 시너지 발동 | ★★ |
| SYNERGY_T3 | 시너지 마스터 | Tier 3 시너지 발동 | ★★★ |
| ALL_SYNERGIES | 오원소 마스터 | 5종 특성 모두 활성화 | ★★★ |
| SURVIVE_30 | 30분 생존 | 단일 런 30분 생존 | ★★ |
| NO_DAMAGE_WAVE | 무상처 | 피해 없이 웨이브 클리어 | ★★★ |
| SPEED_RUN | 스피드러너 | 3배속으로 웨이브 10 도달 | ★★ |
| RUNS_10 | 중독자 | 10판 플레이 | ★ |

## 리더보드 설계

| 보드 이름 | 정렬 | 데이터 |
|----------|------|--------|
| best_wave | 내림차순 | 최고 웨이브 도달 |
| best_kills | 내림차순 | 단일 런 최고 킬 수 |
| best_time | 내림차순 | 최장 생존 시간 (초) |

---

## 리스크와 완화

| 리스크 | 심각도 | 완화 전략 |
|--------|--------|----------|
| GodotSteam 4.x 호환 문제 | 중 | 공식 Godot 4.6 빌드 확인, 커뮤니티 포럼 참조 |
| AI 생성 음악 저작권 | 중 | CC0/상업 가능 라이선스 확인, ToS 검토 |
| F2P 리뷰 폭탄 | 낮 | 무료이므로 기대치 낮음, EA 태그로 미완성 안내 |
| 업적 동기화 실패 | 낮 | storeStats() 호출 확인, 오프라인 큐잉 |
| 빌드 크기 | 낮 | 로우폴리+무텍스처+ogg 압축 → 100MB 이하 예상 |

---

## 명확도 추이

| Round | Arch | Decision | Impl | Risk | 모호성 | 타겟 |
|-------|------|----------|------|------|--------|------|
| 0 | 0.7 | 0.3 | 0.5 | 0.5 | 45% | 초기 |
| 1 | 0.7 | 0.5 | 0.5 | 0.5 | 40% | Decision (전부 포함) |
| 2 | 0.7 | 0.7 | 0.5 | 0.5 | 33% | Decision (통계만 저장) |
| 3 | 0.7 | 0.7 | 0.5 | 0.7 | 28% | Decision (해상도 옵션) |
| 4 | 0.9 | 0.7 | 0.5 | 0.7 | 25% | Decision (튜토리얼 없음) |
| 5 | 0.9 | 0.9 | 0.5 | 0.7 | 20% | Decision (무료+후원) |
| 6 | 0.9 | 0.9 | 0.7 | 0.7 | **17%** | Impl (후원 방식 확정) → **통과** |
