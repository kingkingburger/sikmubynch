# 사운드 제작 가이드

## 현재 상태

모든 사운드는 `tools/create_sounds.py`가 numpy로 절차적으로 만든 모노 WAV(44.1kHz, 16bit)다. 외부 음원은 쓰지 않는다. 테마는 카툰 SF(2d-art-guide.md 참고)이고, 지금 파일은 개발용 1차 소리다.

재생성은 `cd tools && uv run create_sounds.py`(전체) 또는 `uv run create_sounds.py tesla sniper`(이름 지정 SFX만)로 한다. 생성한 WAV를 덮어쓰므로 직접 교체한 파일이 있으면 이름 지정으로 돌린다.

저장 위치: `project/assets/audio/`

## 파일 목록

| 파일 | 종류 | 용도 | 재생 위치 |
|------|------|------|-----------|
| `bgm/title.wav` | BGM | 타이틀 화면 (약 30초 앰비언트) | `title.gd` |
| `bgm/battle.wav` | BGM | 전투 중 (약 30초, 긴장감 있는 리듬) | `game.gd` |
| `sfx/hit.wav` | SFX | 피격. 틱 안에 여러 건이면 한 번만, 음높이 ±8% 흔든다 | `game.gd` |
| `sfx/death.wav` | SFX | 적 사망. 처치 수에 따라 음량·음높이를 바꿔 쌓는다(아래) | `AudioManager.play_kill_layer` |
| `sfx/explosion.wav` | SFX | 포격 폭발. 한 틱 처치 10마리 이상(또는 폭발로 5마리 이상)일 때 사망음과 겹친다 | `AudioManager.play_kill_layer` |
| `sfx/build.wav` | SFX | 건물 배치 | `game.gd`, `hud.gd` |
| `sfx/destroy.wav` | SFX | 건물 파괴·철거 | `game.gd` |
| `sfx/ui_click.wav` | SFX | UI 클릭 | `game.gd`, `title.gd`, `ui_kit.gd` |
| `sfx/tesla.wav` | SFX | 전격 타워 발사 | `game.gd` |
| `sfx/sniper.wav` | SFX | 저격 타워 발사 | `game.gd` |
| `sfx/flame.wav` | SFX | 화염 타워 분사 | `game.gd` |
| `sfx/wave_start.wav` | SFX | **미사용.** 웨이브 개념이 없어져 어디서도 재생하지 않는다. 재도입 대비로만 남아 있다 | — |
| `sfx/mineral.wav` | SFX | **미사용.** 크리스탈 획득음. 현재는 획득 팝업만 쓰고 소리는 내지 않는다 | — |

총 13개(BGM 2 + SFX 11). 속사·포격·감속 타워 발사에는 전용 소리가 없고, 피격(`hit`)과 처치 레이어(`death`/`explosion`)로만 들린다.

BGM은 끝나면 처음부터 다시 돈다. 생성된 `.wav`에는 루프 정보가 없고 `.import` 설정은 저장소에 남지 않으므로, `AudioManager.make_looping()`이 불러온 직후 루프를 건다(WAV는 전체 구간 Forward, OGG·MP3는 `loop = true`). 곡 끝 2초는 생성 단계에서 처음과 크로스페이드되어 이음매가 들리지 않는다.

## 대량 처치 사운드 규칙

대량 처치는 개별 재생하지 않는다. `AudioManager.play_kill_layer(kill_count, explosion_kills)`가 한 틱의 처치 수에 따라 사망음 하나를 음량·음높이를 바꿔 재생하고, 많을 때만 폭발음을 겹친다.

| 한 틱 처치 수 | 사망음 | 폭발음 |
|------|------|------|
| 1~2 | 작게(-9dB), 음높이 ±5% 랜덤 | 없음 (폭발로 5마리 이상 잡았으면 -4dB) |
| 3~9 | -4dB, 음높이 0.95 | 같은 조건 |
| 10~29 | -3dB, 음높이 0.85 | -3dB, 음높이 0.95 |
| 30 이상 | 0dB, 음높이 0.7 (낮고 묵직하게) | +2dB, 음높이 0.8 |

그 밖의 공통 보호 장치(`audio_manager.gd`): 같은 이름의 사운드는 0.04초 안에 다시 재생하지 않고, 같은 스트림은 동시에 3개까지만 재생하며, SFX 풀은 12개다. 사운드를 바꿀 때는 겹쳐 재생돼도 거슬리지 않는지(특히 `death`, `hit`)를 대량 처치 장면에서 확인한다.

## 사운드 교체하기

코드 수정 없이 같은 이름의 파일로 바꾸면 된다.

- `AudioManager`는 `.ogg` → `.wav` → `.mp3` 순으로 찾는다. 같은 이름의 `.ogg`를 넣으면 `.wav`보다 먼저 쓰인다. 같은 이름의 `.wav`로 덮어써도 된다.
- 새 사운드를 추가하려면 `game.gd` 등에서 `AudioManager.play_sfx_by_name("이름", 볼륨오프셋_db, 음높이)`를 호출하고 `sfx/이름.*`를 둔다. BGM은 `play_bgm_by_name`이다.
- 외부 음원(AI 생성·무료 라이브러리 등)으로 교체할 때는 출처와 상업 사용 조건을 기록하고, 상용 사용 권리가 불확실한 음원은 채택하지 않는다.
- 후처리 기준: 앞뒤 무음 제거, 음량 정규화(-1dB 근처), SFX는 짧게. 대량 처치에서 겹치는 `death`·`hit`·`flame`은 꼬리를 짧게 둔다.
- BGM은 전투 중 SFX가 묻히지 않도록 중저역을 비우고 음량을 낮게 둔다.

## 검수

- 100마리 이상 동시 처치 장면에서 소리가 소음이 아니라 "쿵" 하는 한 덩어리로 들리는가?
- 타워 종류(전격·저격·화염)가 소리만으로 구분되는가?
- 배치·파괴·UI 클릭이 전투 소리에 묻히지 않는가?
- BGM이 30초 뒤에도 끊기지 않고 이어지는가?
