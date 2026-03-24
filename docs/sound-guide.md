# 사운드 제작 가이드 — AI + 무료 도구

## 필요한 사운드 목록

| # | 파일명 | 종류 | 용도 |
|---|--------|------|------|
| 1 | `bgm/title.ogg` | BGM | 타이틀 화면 (다크 판타지 분위기) |
| 2 | `bgm/battle.ogg` | BGM | 전투 중 (긴장감 액션) |
| 3 | `sfx/hit.ogg` | SFX | 타격음 |
| 4 | `sfx/death.ogg` | SFX | 적 사망 |
| 5 | `sfx/build.ogg` | SFX | 건물 배치 |
| 6 | `sfx/destroy.ogg` | SFX | 건물 파괴 |
| 7 | `sfx/wave_start.ogg` | SFX | 웨이브 시작/클리어 |
| 8 | `sfx/synergy.ogg` | SFX | 시너지 발동 |
| 9 | `sfx/reward.ogg` | SFX | 보상 선택 |
| 10 | `sfx/levelup.ogg` | SFX | 건물 레벨업 |
| 11 | `sfx/ui_click.ogg` | SFX | UI 클릭 |

저장 위치: `project/assets/audio/`

---

## 도구별 역할

| 도구 | 용도 | 비용 | 상업 가능 |
|------|------|------|----------|
| **Udio** | BGM 2곡 | 무료 (월 100곡) | TOS 확인 필요* |
| **ElevenLabs** | 핵심 SFX 5종 | 무료 (월 제한) | O |
| **Freesound.org** | 보조 SFX 2종 | 무료 | O (CC0만) |
| **jsfxr** | UI SFX 2종 | 완전 무료 | O (MIT) |

> *Udio 무료 티어 상업 라이선스를 https://www.udio.com/terms-of-service 에서 확인해주세요. 불가하면 Freesound/Pixabay에서 CC0 BGM을 검색하세요.

---

## 1단계: BGM 생성 (Udio)

### 설정
1. https://udio.com 가입 (Google/Discord)
2. "Create" 클릭

### 타이틀 BGM 프롬프트
```
dark fantasy orchestral ambient, slow tempo, ominous choir,
deep strings, military drums undertone, haunted castle atmosphere,
game menu music, loop-friendly ending
```

### 전투 BGM 프롬프트
```
intense dark fantasy battle music, fast tempo, epic orchestral,
heavy percussion, brass fanfare, urgent strings, military march influence,
action game combat music, loop-friendly
```

### 후처리
1. 마음에 드는 곡 선택 → WAV/MP3 다운로드
2. Audacity (무료) 설치: https://www.audacityteam.org/
3. 파일 열기 → File > Export > OGG Vorbis (품질 6)
4. `title.ogg`, `battle.ogg`로 저장
5. `project/assets/audio/bgm/`에 복사

### Godot 루프 설정
- Godot 에디터에서 .ogg 파일 클릭
- Import 탭 → Loop 체크 → Reimport

---

## 2단계: 핵심 SFX (ElevenLabs)

### 설정
1. https://elevenlabs.io 가입
2. Sound Effects 메뉴 선택

### 프롬프트

| SFX | 프롬프트 |
|-----|---------|
| hit.ogg | `heavy sword impact on armor, metallic clang with bass thud, dark fantasy combat` |
| death.ogg | `monster death groan with body collapse, dark creature dying sound, short` |
| build.ogg | `stone blocks placing down, construction thud, medieval building placement` |
| destroy.ogg | `stone structure crumbling and collapsing, debris falling, short explosion` |
| wave_start.ogg | `deep war horn blast, ominous warning signal, dark fantasy battle horn` |

### 후처리
1. WAV로 다운로드
2. Audacity에서 트리밍 (앞뒤 무음 제거)
3. Effect > Normalize (-1 dB)
4. OGG로 내보내기
5. `project/assets/audio/sfx/`에 복사

---

## 3단계: 보조 SFX (Freesound CC0)

### 검색 방법
1. https://freesound.org 가입
2. 검색 시 **License 필터 → "Creative Commons 0"** 선택 (필수!)

### 검색어

| SFX | 검색어 |
|-----|--------|
| synergy.ogg | `magic spell activate` 또는 `power up magical` |
| reward.ogg | `treasure chest open` 또는 `card reveal magic` |

### 후처리
- Audacity에서 트리밍 → OGG 변환 → `project/assets/audio/sfx/`에 복사

---

## 4단계: UI SFX (jsfxr)

### 사용법
1. https://sfxr.me 접속 (웹 브라우저에서 바로 사용)

### 레벨업 SFX
1. "Powerup" 버튼 클릭
2. 마음에 들 때까지 반복 클릭
3. 파라미터 미세 조정 (선택)
4. "Export WAV" → `levelup.wav`

### UI 클릭 SFX
1. "Blip/Select" 버튼 클릭
2. 마음에 들 때까지 반복
3. "Export WAV" → `ui_click.wav`

### 후처리
- Audacity에서 OGG 변환 → `project/assets/audio/sfx/`에 복사

---

## 최종 파일 구조

```
project/assets/audio/
├── bgm/
│   ├── title.ogg        ← Udio (루프 설정)
│   └── battle.ogg       ← Udio (루프 설정)
└── sfx/
    ├── hit.ogg          ← ElevenLabs
    ├── death.ogg        ← ElevenLabs
    ├── build.ogg        ← ElevenLabs
    ├── destroy.ogg      ← ElevenLabs
    ├── wave_start.ogg   ← ElevenLabs
    ├── synergy.ogg      ← Freesound CC0
    ├── reward.ogg       ← Freesound CC0
    ├── levelup.ogg      ← jsfxr
    └── ui_click.ogg     ← jsfxr
```

**코드 수정 필요 없음** — AudioManager와 game.gd/title.gd에 이미 사운드 재생 코드가 적용되어 있습니다. 파일을 위 경로에 넣으면 자동으로 재생됩니다.

---

## 대안: Udio 상업 불가 시

BGM을 Freesound/Pixabay CC0에서 검색:

| 사이트 | 검색어 |
|--------|--------|
| freesound.org | `dark fantasy orchestral loop` (CC0 필터) |
| pixabay.com/music | `dark fantasy game` |
| opengameart.org | `dark ambient battle` (CC0 필터) |

또는 로컬 AI 도구 **YuE** (Apache 2.0, 상업 가능):
- https://github.com/multimodal-art-projection/YuE
- GPU 8GB+ 필요, Hunyuan3D-2와 같은 PC에서 실행 가능
