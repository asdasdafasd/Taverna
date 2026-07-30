#!/usr/bin/env python3
"""Generates all audio assets for The Wandering Flagon.

Every sound is synthesized from scratch (noise, sines, Karplus-Strong
plucked strings) so the project stays fully original and CC0. Run from the
repository root:

    python3 tools/generate_audio.py

Outputs 16-bit mono WAV files at 22050 Hz into assets/audio/.
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
random.seed(41)


def write_wav(name: str, samples: list) -> None:
    path = os.path.join(OUT_DIR, name)
    frames = bytearray()
    for s in samples:
        s = max(-1.0, min(1.0, s))
        frames += struct.pack("<h", int(s * 32767))
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print(f"  {name}  ({len(samples) / SR:.2f}s, {len(frames) // 1024} KiB)")


def silence(dur: float) -> list:
    return [0.0] * int(dur * SR)


def mix_into(track: list, samples: list, at: float, gain: float = 1.0) -> None:
    start = int(at * SR)
    for i, s in enumerate(samples):
        j = start + i
        if 0 <= j < len(track):
            track[j] += s * gain


def env_ad(n: int, attack: float, decay_pow: float = 2.0) -> list:
    a = max(1, int(attack * SR))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            t = (i - a) / max(1, n - a)
            out.append((1.0 - t) ** decay_pow)
    return out


def lowpass(samples: list, alpha: float) -> list:
    out, y = [], 0.0
    for x in samples:
        y += alpha * (x - y)
        out.append(y)
    return out


def highpass(samples: list, alpha: float) -> list:
    lp = lowpass(samples, alpha)
    return [x - l for x, l in zip(samples, lp)]


def noise(dur: float) -> list:
    return [random.uniform(-1, 1) for _ in range(int(dur * SR))]


def sine(freq: float, dur: float, amp: float = 1.0) -> list:
    return [amp * math.sin(2 * math.pi * freq * i / SR) for i in range(int(dur * SR))]


def pluck(freq: float, dur: float, amp: float = 0.3, damp: float = 0.996) -> list:
    """Karplus-Strong plucked string."""
    n = max(2, int(SR / freq))
    buf = [random.uniform(-1, 1) for _ in range(n)]
    out = []
    for i in range(int(dur * SR)):
        v = buf[i % n]
        buf[i % n] = damp * 0.5 * (buf[i % n] + buf[(i + 1) % n])
        out.append(amp * v)
    # soften the attack a hair and fade the tail
    for i in range(min(64, len(out))):
        out[i] *= i / 64
    for i in range(min(512, len(out))):
        out[-1 - i] *= i / 512
    return out


def loop_smooth(track: list, fade: float = 0.05) -> list:
    """Crossfades the tail into the head so the loop clicks less."""
    n = int(fade * SR)
    for i in range(n):
        t = i / n
        track[i] = track[i] * t + track[len(track) - n + i] * (1 - t)
    for i in range(n):
        track[len(track) - 1 - i] *= i / n
    return track


# --- UI / interaction one-shots ------------------------------------------------

def gen_ui_click() -> None:
    n = int(0.05 * SR)
    body = highpass(noise(0.05), 0.4)
    tone = sine(1300, 0.05, 0.5)
    env = env_ad(n, 0.002, 3.0)
    write_wav("ui_click.wav", [(b * 0.35 + t) * e * 0.5 for b, t, e in zip(body, tone, env)])


def gen_interact_thunk() -> None:
    n = int(0.11 * SR)
    thump = sine(170, 0.11, 0.9)
    tap = lowpass(noise(0.11), 0.25)
    env = env_ad(n, 0.002, 3.0)
    write_wav("interact_thunk.wav",
              [(a * 0.8 + b * 0.4) * e * 0.7 for a, b, e in zip(thump, tap, env)])


def gen_door_creak() -> None:
    dur = 0.8
    n = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        freq = 85 - 18 * t + 6 * math.sin(2 * math.pi * 5.5 * t)
        phase += 2 * math.pi * freq / SR
        saw = 2 * ((phase / (2 * math.pi)) % 1.0) - 1
        out.append(saw * 0.5 + math.sin(phase * 2) * 0.2)
    grit = lowpass(noise(dur), 0.12)
    env = env_ad(n, 0.05, 1.4)
    write_wav("door_creak.wav",
              [(o * 0.6 + g * 0.25) * e * 0.55 for o, g, e in zip(out, grit, env)])


def gen_footsteps() -> None:
    for k in range(1, 4):
        dur = 0.09 + 0.015 * k
        n = int(dur * SR)
        tap = lowpass(noise(dur), 0.22 + 0.04 * k)
        thump = sine(62 + 6 * k, dur, 0.8)
        env = env_ad(n, 0.001, 3.5)
        write_wav(f"footstep_wood_{k}.wav",
                  [(a * 0.55 + b * 0.6) * e * 0.6 for a, b, e in zip(tap, thump, env)])


def gen_coin_pay() -> None:
    track = silence(0.5)
    for i, f in enumerate([5200, 6400, 4700]):
        clink = [a + b for a, b in zip(sine(f, 0.16, 0.5), sine(f * 1.51, 0.16, 0.25))]
        env = env_ad(len(clink), 0.001, 4.0)
        mix_into(track, [c * e for c, e in zip(clink, env)], 0.07 * i, 0.7)
    write_wav("coin_pay.wav", track)


def gen_quest_complete() -> None:
    track = silence(1.6)
    for i, f in enumerate([293.66, 349.23, 440.0, 587.33]):
        mix_into(track, pluck(f, 1.0, 0.34, 0.9975), 0.11 * i)
    write_wav("quest_complete.wav", track)


def gen_quest_failed() -> None:
    track = silence(1.2)
    mix_into(track, pluck(146.83, 1.1, 0.4, 0.998), 0.0)
    mix_into(track, pluck(155.56, 1.0, 0.28, 0.998), 0.09)
    write_wav("quest_failed.wav", track)


def gen_event_ping() -> None:
    track = silence(0.9)
    mix_into(track, pluck(440.0, 0.8, 0.3, 0.997), 0.0)
    write_wav("event_ping.wav", track)


def gen_brawl_punch() -> None:
    n = int(0.16 * SR)
    thump = sine(75, 0.16, 1.0)
    smack = lowpass(noise(0.16), 0.35)
    env = env_ad(n, 0.001, 3.0)
    write_wav("brawl_punch.wav",
              [(a * 0.9 + b * 0.6) * e * 0.85 for a, b, e in zip(thump, smack, env)])


def gen_tension_sting() -> None:
    dur = 1.4
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        trem = 0.7 + 0.3 * math.sin(2 * math.pi * 7 * t)
        v = (math.sin(2 * math.pi * 73.42 * t)
             + 0.5 * math.sin(2 * math.pi * 110.0 * t + 0.4)
             + 0.3 * math.sin(2 * math.pi * 77.78 * t))
        out.append(v * trem)
    env = env_ad(n, 0.02, 1.6)
    write_wav("tension_sting.wav", [o * e * 0.4 for o, e in zip(out, env)])


# --- Ambient loop ------------------------------------------------------------------

def gen_ambient() -> None:
    dur = 14.0
    track = silence(dur)
    # room tone: brown-ish noise
    y = 0.0
    tone = []
    for _ in range(int(dur * SR)):
        y += random.uniform(-1, 1) * 0.02
        y *= 0.985
        tone.append(y)
    for i, v in enumerate(tone):
        track[i] += v * 1.1
    # hearth crackle: sparse filtered pops
    for _ in range(120):
        at = random.uniform(0, dur - 0.05)
        p = lowpass(noise(0.02 + random.uniform(0, 0.02)), random.uniform(0.2, 0.5))
        env = env_ad(len(p), 0.001, 3.0)
        mix_into(track, [a * e for a, e in zip(p, env)], at, random.uniform(0.04, 0.12))
    # murmur: band-passed noise swells
    murmur = highpass(lowpass(noise(dur), 0.08), 0.02)
    for i, v in enumerate(murmur):
        t = i / SR
        swell = 0.5 + 0.5 * math.sin(2 * math.pi * 0.11 * t + 1.3)
        swell *= 0.5 + 0.5 * math.sin(2 * math.pi * 0.047 * t)
        track[i] += v * 0.32 * swell
    # occasional mug clink, far away
    for _ in range(6):
        at = random.uniform(0.5, dur - 0.3)
        f = random.choice([3800, 4400, 5100])
        clink = sine(f, 0.1, 0.4)
        env = env_ad(len(clink), 0.001, 4.0)
        mix_into(track, [c * e for c, e in zip(clink, env)], at, 0.05)
    peak = max(abs(s) for s in track)
    track = [s / peak * 0.5 for s in track]
    write_wav("ambient_tavern_loop.wav", loop_smooth(track))


# --- Music loops ----------------------------------------------------------------------

D2, A2, D3, F3, G3, A3 = 73.42, 110.0, 146.83, 174.61, 196.0, 220.0
C4, D4, F4, G4, A4 = 261.63, 293.66, 349.23, 392.0, 440.0


def gen_music_day() -> None:
    beat = 0.7
    dur = beat * 16
    track = silence(dur + 1.5)
    bass = [(0, D3), (2, A3), (4, F3), (6, A3), (8, C4), (10, A3), (12, G3), (14, A3)]
    lead = [(1, D4), (3, F4), (5, G4), (7, A4), (9, F4), (11, D4), (13, C4), (15, D4)]
    for b, f in bass:
        mix_into(track, pluck(f, 1.5, 0.26, 0.9985), b * beat)
    for b, f in lead:
        mix_into(track, pluck(f, 1.2, 0.16, 0.998), b * beat)
    track = track[:int(dur * SR)]
    write_wav("music_day_loop.wav", loop_smooth(track, 0.08))


def gen_music_night() -> None:
    beat = 0.95
    dur = beat * 16
    n = int(dur * SR)
    track = silence(dur)
    for i in range(n):
        t = i / SR
        drone = (math.sin(2 * math.pi * D2 * t)
                 + 0.6 * math.sin(2 * math.pi * (D2 * 1.005) * t)
                 + 0.4 * math.sin(2 * math.pi * A2 * t))
        swell = 0.6 + 0.4 * math.sin(2 * math.pi * t / dur * 2)
        track[i] += drone * 0.055 * swell
    for b, f in [(0, D3), (3, F3), (6, A3), (9, G3), (12, F3), (14, C4)]:
        mix_into(track, pluck(f, 1.8, 0.2, 0.9985), b * beat)
    write_wav("music_night_loop.wav", loop_smooth(track, 0.1))


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    print("Generating audio assets:")
    gen_ui_click()
    gen_interact_thunk()
    gen_door_creak()
    gen_footsteps()
    gen_coin_pay()
    gen_quest_complete()
    gen_quest_failed()
    gen_event_ping()
    gen_brawl_punch()
    gen_tension_sting()
    gen_ambient()
    gen_music_day()
    gen_music_night()
    print("Done.")


if __name__ == "__main__":
    main()
