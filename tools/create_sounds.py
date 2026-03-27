"""프로시저럴 게임 사운드 생성기 — 다크 판타지 웨이브 디펜스용
numpy + stdlib wave로 SFX 9종 + BGM 2종 생성.
"""

import wave
from pathlib import Path

import numpy as np

SAMPLE_RATE = 44100
OUT_SFX = Path(__file__).parent.parent / "project" / "assets" / "audio" / "sfx"
OUT_BGM = Path(__file__).parent.parent / "project" / "assets" / "audio" / "bgm"


def save_wav(path: Path, data: np.ndarray, sr: int = SAMPLE_RATE) -> None:
    """float32 [-1,1] → 16-bit WAV."""
    path.parent.mkdir(parents=True, exist_ok=True)
    clipped = np.clip(data, -1.0, 1.0)
    pcm = (clipped * 32767).astype(np.int16)
    with wave.open(str(path), "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes(pcm.tobytes())
    print(f"  ✓ {path.name} ({len(data)/sr:.2f}s, {path.stat().st_size/1024:.1f}KB)")


def envelope(length: int, attack: float = 0.01, decay: float = 0.1,
             sustain: float = 0.7, release: float = 0.2) -> np.ndarray:
    """ADSR envelope."""
    a = int(attack * SAMPLE_RATE)
    d = int(decay * SAMPLE_RATE)
    r = int(release * SAMPLE_RATE)
    s = max(length - a - d - r, 0)

    env = np.zeros(length)
    # Attack
    if a > 0:
        env[:a] = np.linspace(0, 1, a)
    # Decay
    if d > 0:
        env[a:a+d] = np.linspace(1, sustain, d)
    # Sustain
    if s > 0:
        env[a+d:a+d+s] = sustain
    # Release
    if r > 0:
        env[-r:] = np.linspace(sustain, 0, r)
    return env


def bandpass_simple(data: np.ndarray, low: float, high: float,
                    sr: int = SAMPLE_RATE) -> np.ndarray:
    """FFT-based bandpass filter."""
    fft = np.fft.rfft(data)
    freqs = np.fft.rfftfreq(len(data), 1.0 / sr)
    mask = (freqs >= low) & (freqs <= high)
    fft[~mask] *= 0.05  # soft rolloff
    return np.fft.irfft(fft, n=len(data))


def lowpass(data: np.ndarray, cutoff: float, sr: int = SAMPLE_RATE) -> np.ndarray:
    fft = np.fft.rfft(data)
    freqs = np.fft.rfftfreq(len(data), 1.0 / sr)
    rolloff = 1.0 / (1.0 + (freqs / max(cutoff, 1)) ** 4)
    fft *= rolloff
    return np.fft.irfft(fft, n=len(data))


def highpass(data: np.ndarray, cutoff: float, sr: int = SAMPLE_RATE) -> np.ndarray:
    fft = np.fft.rfft(data)
    freqs = np.fft.rfftfreq(len(data), 1.0 / sr)
    rolloff = 1.0 - 1.0 / (1.0 + (freqs / max(cutoff, 1)) ** 4)
    fft *= rolloff
    return np.fft.irfft(fft, n=len(data))


# ─── SFX ────────────────────────────────────────────────────────

def sfx_hit() -> np.ndarray:
    """타격음 — 금속성 임팩트 + 저음 펀치."""
    dur = 0.25
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)

    # Metal transient
    metal = np.sin(2 * np.pi * 1200 * t) * 0.4
    metal += np.sin(2 * np.pi * 2400 * t) * 0.2
    metal += np.sin(2 * np.pi * 3600 * t) * 0.1
    metal *= np.exp(-t * 30)

    # Bass punch
    bass_freq = 80 + 200 * np.exp(-t * 20)
    phase = np.cumsum(bass_freq / SAMPLE_RATE) * 2 * np.pi
    bass = np.sin(phase) * 0.6 * np.exp(-t * 15)

    # Noise burst
    noise = np.random.randn(n) * 0.3 * np.exp(-t * 40)
    noise = bandpass_simple(noise, 800, 4000)

    out = metal + bass + noise
    return out * envelope(n, 0.001, 0.02, 0.3, 0.1) * 0.8


def sfx_death() -> np.ndarray:
    """적 사망 — 하강 톤 + 육중한 타격."""
    dur = 0.4
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)

    # Descending tone
    freq = 400 * np.exp(-t * 5)
    phase = np.cumsum(freq / SAMPLE_RATE) * 2 * np.pi
    tone = np.sin(phase) * 0.5

    # Impact thud
    thud_freq = 60 + 100 * np.exp(-t * 25)
    thud_phase = np.cumsum(thud_freq / SAMPLE_RATE) * 2 * np.pi
    thud = np.sin(thud_phase) * 0.5 * np.exp(-t * 10)

    # Crunch noise
    noise = np.random.randn(n) * 0.2 * np.exp(-t * 15)
    noise = lowpass(noise, 2000)

    out = tone + thud + noise
    return out * envelope(n, 0.002, 0.05, 0.4, 0.15) * 0.7


def sfx_build() -> np.ndarray:
    """건물 배치 — 돌 블록 + 기계적 잠금."""
    dur = 0.35
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)

    # Stone thud
    thud = np.sin(2 * np.pi * 120 * t) * 0.5 * np.exp(-t * 12)

    # Mechanical click at 0.1s
    click_start = int(0.08 * SAMPLE_RATE)
    click = np.zeros(n)
    click_len = int(0.05 * SAMPLE_RATE)
    ct = np.linspace(0, 0.05, click_len)
    click[click_start:click_start+click_len] = (
        np.sin(2 * np.pi * 800 * ct) * 0.3 * np.exp(-ct * 40)
    )

    # Scrape noise
    noise = np.random.randn(n) * 0.15 * np.exp(-t * 10)
    noise = bandpass_simple(noise, 200, 1500)

    # Resonant tone (confirmation)
    confirm = np.sin(2 * np.pi * 523 * t) * 0.15 * np.exp(-(t - 0.15) ** 2 / 0.01)

    out = thud + click + noise + confirm
    return out * envelope(n, 0.005, 0.05, 0.5, 0.1) * 0.75


def sfx_destroy() -> np.ndarray:
    """건물 파괴 — 폭발 + 잔해 붕괴."""
    dur = 0.6
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)

    # Explosion bass
    exp_freq = 40 + 300 * np.exp(-t * 8)
    exp_phase = np.cumsum(exp_freq / SAMPLE_RATE) * 2 * np.pi
    explosion = np.sin(exp_phase) * 0.6 * np.exp(-t * 5)

    # Debris noise
    debris = np.random.randn(n) * 0.4
    debris *= np.exp(-t * 4)
    debris = bandpass_simple(debris, 100, 3000)

    # Crumble (delayed rattling)
    crumble = np.zeros(n)
    for i in range(6):
        offset = int((0.1 + i * 0.06) * SAMPLE_RATE)
        if offset < n:
            clen = min(int(0.08 * SAMPLE_RATE), n - offset)
            ct = np.linspace(0, 0.08, clen)
            crumble[offset:offset+clen] += (
                np.random.randn(clen) * 0.15 * np.exp(-ct * 20)
            )
    crumble = lowpass(crumble, 2500)

    out = explosion + debris + crumble
    return out * envelope(n, 0.003, 0.1, 0.3, 0.2) * 0.8


def sfx_wave_start() -> np.ndarray:
    """웨이브 시작 — 전쟁 뿔나팔."""
    dur = 1.2
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)

    # Horn fundamental + harmonics (rising)
    freq_base = 130 + 30 * t / dur
    phase = np.cumsum(freq_base / SAMPLE_RATE) * 2 * np.pi
    horn = np.sin(phase) * 0.4
    horn += np.sin(phase * 2) * 0.25  # octave
    horn += np.sin(phase * 3) * 0.1   # fifth
    horn += np.sin(phase * 4) * 0.05

    # Breath noise
    breath = np.random.randn(n) * 0.08
    breath = bandpass_simple(breath, 800, 3000)

    # Volume swell
    swell = np.sin(np.pi * t / dur) ** 0.7

    out = (horn + breath) * swell
    return out * envelope(n, 0.15, 0.1, 0.8, 0.3) * 0.7


def sfx_synergy() -> np.ndarray:
    """시너지 발동 — 마법 상승 아르페지오."""
    dur = 0.6
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)
    out = np.zeros(n)

    # Ascending notes: C5, E5, G5, C6
    freqs = [523, 659, 784, 1047]
    for i, freq in enumerate(freqs):
        start = int(i * 0.12 * SAMPLE_RATE)
        note_len = int(0.35 * SAMPLE_RATE)
        if start + note_len > n:
            note_len = n - start
        nt = np.linspace(0, note_len / SAMPLE_RATE, note_len)
        note = np.sin(2 * np.pi * freq * nt) * 0.25
        note += np.sin(2 * np.pi * freq * 2 * nt) * 0.1  # shimmer
        note *= np.exp(-nt * 5)
        out[start:start+note_len] += note

    # Sparkle noise
    sparkle = np.random.randn(n) * 0.05
    sparkle = bandpass_simple(sparkle, 4000, 10000)
    sparkle *= np.linspace(0.3, 1.0, n) * np.exp(-t * 2)

    out = out + sparkle
    return out * envelope(n, 0.01, 0.05, 0.7, 0.15) * 0.7


def sfx_reward() -> np.ndarray:
    """보상 선택 — 보물 상자 열림 + 반짝임."""
    dur = 0.5
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)

    # Opening creak
    creak_freq = 300 + 500 * t / dur
    creak_phase = np.cumsum(creak_freq / SAMPLE_RATE) * 2 * np.pi
    creak = np.sin(creak_phase) * 0.15 * np.exp(-t * 6)

    # Chime (two notes)
    chime1 = np.sin(2 * np.pi * 880 * t) * 0.3 * np.exp(-t * 8)
    delay = int(0.1 * SAMPLE_RATE)
    chime2 = np.zeros(n)
    chime2_len = n - delay
    ct = np.linspace(0, chime2_len / SAMPLE_RATE, chime2_len)
    chime2[delay:] = np.sin(2 * np.pi * 1320 * ct) * 0.25 * np.exp(-ct * 6)

    # Sparkle
    sparkle = np.random.randn(n) * 0.06
    sparkle = bandpass_simple(sparkle, 5000, 12000)
    sparkle *= np.exp(-t * 4)

    out = creak + chime1 + chime2 + sparkle
    return out * envelope(n, 0.005, 0.05, 0.6, 0.15) * 0.75


def sfx_levelup() -> np.ndarray:
    """레벨업 — 파워업 상승음."""
    dur = 0.45
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)

    # Rising sweep
    freq = 300 + 900 * (t / dur) ** 1.5
    phase = np.cumsum(freq / SAMPLE_RATE) * 2 * np.pi
    sweep = np.sin(phase) * 0.35
    sweep += np.sin(phase * 2) * 0.15  # harmonic

    # Burst at end
    burst_env = np.exp(-((t - dur * 0.8) ** 2) / 0.005)
    burst = np.sin(2 * np.pi * 1200 * t) * 0.2 * burst_env

    # Shimmer
    shimmer = np.random.randn(n) * 0.04
    shimmer = bandpass_simple(shimmer, 3000, 8000)
    shimmer *= np.linspace(0.2, 1.0, n)

    out = sweep + burst + shimmer
    return out * envelope(n, 0.01, 0.03, 0.8, 0.1) * 0.7


def sfx_ui_click() -> np.ndarray:
    """UI 클릭 — 짧은 블립."""
    dur = 0.08
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)

    blip = np.sin(2 * np.pi * 1000 * t) * 0.4
    blip += np.sin(2 * np.pi * 1500 * t) * 0.2
    blip *= np.exp(-t * 60)

    click = np.random.randn(n) * 0.1 * np.exp(-t * 100)

    out = blip + click
    return out * 0.6


def sfx_explosion() -> np.ndarray:
    """폭발 — Exploder/Bomber용 큰 폭발."""
    dur = 0.8
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)

    # Deep boom
    boom_freq = 30 + 200 * np.exp(-t * 6)
    boom_phase = np.cumsum(boom_freq / SAMPLE_RATE) * 2 * np.pi
    boom = np.sin(boom_phase) * 0.7 * np.exp(-t * 3)

    # Fire noise
    fire = np.random.randn(n) * 0.5
    fire = bandpass_simple(fire, 60, 2000)
    fire *= np.exp(-t * 3)

    # Shrapnel (high freq transient)
    shrap = np.random.randn(n) * 0.3
    shrap = bandpass_simple(shrap, 2000, 6000)
    shrap *= np.exp(-t * 8)

    out = boom + fire + shrap
    return out * envelope(n, 0.005, 0.1, 0.3, 0.3) * 0.8


def sfx_mineral() -> np.ndarray:
    """미네랄 획득 — 코인/크리스탈 수집음."""
    dur = 0.2
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)

    # Two-tone chime
    tone1 = np.sin(2 * np.pi * 1400 * t) * 0.3 * np.exp(-t * 15)
    tone2 = np.zeros(n)
    d = int(0.04 * SAMPLE_RATE)
    if d < n:
        ct = np.linspace(0, (n - d) / SAMPLE_RATE, n - d)
        tone2[d:] = np.sin(2 * np.pi * 2100 * ct) * 0.25 * np.exp(-ct * 12)

    out = tone1 + tone2
    return out * 0.65


# ─── BGM ────────────────────────────────────────────────────────

def bgm_title() -> np.ndarray:
    """타이틀 BGM — 다크 판타지 앰비언트 드론 (30초 루프)."""
    dur = 30.0
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)
    out = np.zeros(n)

    # Deep drone (layered fifths)
    for freq, amp in [(55, 0.2), (82.5, 0.15), (110, 0.12), (165, 0.06)]:
        # Slow LFO modulation
        lfo = 1.0 + 0.15 * np.sin(2 * np.pi * 0.07 * t + freq * 0.1)
        phase = np.cumsum(freq * lfo / SAMPLE_RATE) * 2 * np.pi
        out += np.sin(phase) * amp

    # Dark pad (minor chord evolving)
    pad_freqs = [130.8, 155.6, 196.0, 261.6]  # Cm chord
    for i, freq in enumerate(pad_freqs):
        lfo = 1.0 + 0.02 * np.sin(2 * np.pi * (0.05 + i * 0.02) * t)
        phase = np.cumsum(freq * lfo / SAMPLE_RATE) * 2 * np.pi
        vol = 0.06 + 0.03 * np.sin(2 * np.pi * (0.03 + i * 0.01) * t)
        out += np.sin(phase) * vol

    # Ominous wind
    wind = np.random.randn(n) * 0.08
    wind = bandpass_simple(wind, 100, 800)
    wind_vol = 0.5 + 0.5 * np.sin(2 * np.pi * 0.05 * t)
    out += wind * wind_vol

    # Distant percussion hits (sparse)
    rng = np.random.default_rng(42)
    hit_times = rng.choice(range(int(2 * SAMPLE_RATE), n - SAMPLE_RATE, int(3.5 * SAMPLE_RATE)), size=6, replace=False)
    for ht in sorted(hit_times):
        hit_len = min(int(1.5 * SAMPLE_RATE), n - ht)
        ht_t = np.linspace(0, hit_len / SAMPLE_RATE, hit_len)
        drum = np.sin(2 * np.pi * 50 * ht_t) * 0.15 * np.exp(-ht_t * 3)
        drum += np.random.randn(hit_len) * 0.05 * np.exp(-ht_t * 5)
        out[ht:ht+hit_len] += drum

    # Eerie high tone (occasional)
    eerie_env = np.exp(-((t - 15) ** 2) / 20) * 0.04
    out += np.sin(2 * np.pi * 880 * t) * eerie_env

    # Crossfade for seamless loop (2 second overlap)
    fade_len = int(2.0 * SAMPLE_RATE)
    fade_out = np.linspace(1, 0, fade_len)
    fade_in = np.linspace(0, 1, fade_len)
    out[-fade_len:] = out[-fade_len:] * fade_out + out[:fade_len] * fade_in

    out = lowpass(out, 6000)
    # Normalize
    peak = np.max(np.abs(out))
    if peak > 0:
        out = out / peak * 0.7
    return out


def bgm_battle() -> np.ndarray:
    """전투 BGM — 다크 리듬 + 긴장감 (30초 루프)."""
    dur = 30.0
    n = int(dur * SAMPLE_RATE)
    t = np.linspace(0, dur, n)
    bpm = 140
    beat = 60.0 / bpm
    out = np.zeros(n)

    # Kick drum pattern (4-on-the-floor)
    for i in range(int(dur / beat)):
        start = int(i * beat * SAMPLE_RATE)
        kick_len = min(int(0.15 * SAMPLE_RATE), n - start)
        kt = np.linspace(0, kick_len / SAMPLE_RATE, kick_len)
        kick_freq = 50 + 150 * np.exp(-kt * 25)
        kick_phase = np.cumsum(kick_freq / SAMPLE_RATE) * 2 * np.pi
        kick = np.sin(kick_phase) * 0.35 * np.exp(-kt * 12)
        out[start:start+kick_len] += kick

    # Snare on 2 and 4
    for i in range(int(dur / beat)):
        if i % 2 == 1:
            start = int(i * beat * SAMPLE_RATE)
            sn_len = min(int(0.12 * SAMPLE_RATE), n - start)
            st = np.linspace(0, sn_len / SAMPLE_RATE, sn_len)
            snare = np.sin(2 * np.pi * 200 * st) * 0.15 * np.exp(-st * 20)
            snare += np.random.randn(sn_len) * 0.2 * np.exp(-st * 15)
            snare = bandpass_simple(snare, 150, 5000)
            out[start:start+sn_len] += snare

    # Hi-hat (8th notes)
    for i in range(int(dur / (beat / 2))):
        start = int(i * beat / 2 * SAMPLE_RATE)
        hh_len = min(int(0.04 * SAMPLE_RATE), n - start)
        hh = np.random.randn(hh_len) * 0.08 * np.exp(-np.linspace(0, 1, hh_len) * 30)
        hh = highpass(hh, 6000)
        out[start:start+hh_len] += hh

    # Dark bass line (root + octave, simple riff)
    bass_notes = [55, 55, 65.4, 55, 55, 73.4, 55, 82.4]  # Am-ish pattern
    note_dur = beat * 2
    for i, freq in enumerate(bass_notes * int(dur / (note_dur * len(bass_notes)) + 1)):
        start = int(i * note_dur * SAMPLE_RATE)
        if start >= n:
            break
        b_len = min(int(note_dur * SAMPLE_RATE), n - start)
        bt = np.linspace(0, b_len / SAMPLE_RATE, b_len)
        bass_phase = np.cumsum((freq + 0.5 * np.sin(2 * np.pi * 5 * bt)) / SAMPLE_RATE) * 2 * np.pi
        bass = np.sin(bass_phase) * 0.2
        bass += np.sin(bass_phase * 2) * 0.08  # warmth
        bass *= np.exp(-bt * 1.5)
        out[start:start+b_len] += bass

    # Dark strings sustained
    string_freqs = [220, 261.6, 329.6]  # Am chord
    for freq in string_freqs:
        lfo = 1.0 + 0.01 * np.sin(2 * np.pi * 4.5 * t)
        s_phase = np.cumsum(freq * lfo / SAMPLE_RATE) * 2 * np.pi
        string = np.sin(s_phase) * 0.06
        string += np.sin(s_phase * 2) * 0.02
        vol_env = 0.5 + 0.5 * np.sin(2 * np.pi * 0.08 * t)
        out += string * vol_env

    # Tension risers every 15 seconds
    for riser_start in [0, 15]:
        rs = int(riser_start * SAMPLE_RATE)
        r_dur = int(7.0 * SAMPLE_RATE)
        if rs + r_dur <= n:
            rt = np.linspace(0, 7.0, r_dur)
            riser_freq = 200 + 600 * (rt / 7.0) ** 2
            riser_phase = np.cumsum(riser_freq / SAMPLE_RATE) * 2 * np.pi
            riser = np.sin(riser_phase) * 0.04 * (rt / 7.0)
            out[rs:rs+r_dur] += riser

    # Crossfade loop (2 seconds)
    fade_len = int(2.0 * SAMPLE_RATE)
    fade_out = np.linspace(1, 0, fade_len)
    fade_in = np.linspace(0, 1, fade_len)
    out[-fade_len:] = out[-fade_len:] * fade_out + out[:fade_len] * fade_in

    # Normalize
    peak = np.max(np.abs(out))
    if peak > 0:
        out = out / peak * 0.75
    return out


# ─── Main ───────────────────────────────────────────────────────

def main() -> None:
    print("=== SIKMUBYNCH 프로시저럴 사운드 생성 ===\n")

    print("[SFX]")
    sfx_map = {
        "hit": sfx_hit,
        "death": sfx_death,
        "build": sfx_build,
        "destroy": sfx_destroy,
        "wave_start": sfx_wave_start,
        "synergy": sfx_synergy,
        "reward": sfx_reward,
        "levelup": sfx_levelup,
        "ui_click": sfx_ui_click,
        "explosion": sfx_explosion,
        "mineral": sfx_mineral,
    }
    for name, gen_fn in sfx_map.items():
        data = gen_fn()
        save_wav(OUT_SFX / f"{name}.wav", data)

    print("\n[BGM]")
    save_wav(OUT_BGM / "title.wav", bgm_title())
    save_wav(OUT_BGM / "battle.wav", bgm_battle())

    print(f"\n완료! SFX {len(sfx_map)}종 + BGM 2종 생성됨.")


if __name__ == "__main__":
    main()
