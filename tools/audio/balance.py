"""Measures every sound in audio/: length, peak, loudness and pitch, and works
out the gain each needs so they sit together. Retunes the block pulses to the
notes their names say.

    python tools/audio/balance.py <project root>            report only
    python tools/audio/balance.py <project root> --retune   also retune the pulses

Needs numpy, scipy and ffmpeg on PATH.

Loudness is the loudest 100 ms of the clip, K-weighted as in ITU-R BS.1770 (the
curve LUFS uses): for sounds this short, the loudest moment is what the ear
compares, not the average. Each sound has a role, and each role a target, so a
click sits under a level's start sound and the pulses under everything. The
gains are printed as SfxPlayer's GAIN_DB table; paste it over the old one.

Retuning resamples (pitch and length change together, as on a tape), which for
a tenth of a second is fine. A pulse's original is copied to audio/source/
first (Godot ignores that folder), so running this twice retunes from the
original, never from an earlier retune.
"""
import math, os, re, shutil, subprocess, sys

import numpy as np
from scipy import signal

RATE = 48000
NOTES = {"c": 0, "c#": 1, "d": 2, "d#": 3, "e": 4, "f": 5, "f#": 6, "g": 7, "g#": 8, "a": 9, "a#": 10, "b": 11}
NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# Loudest-100-ms K-weighted loudness each kind of sound should have, in LUFS.
ROLES = {
    "pulse": -30.0,     # one per block run: under everything
    "ui": -24.0,        # a click, a block picked up, dropped, thrown away
    "event": -21.0,     # a level opening, the next room
    "result": -19.0,    # the win, the fail
}
ROLE_OF = {
    "button_click": "ui", "block_picked_up": "ui", "block_drop": "ui", "block_trash": "ui",
    "level_start": "event", "next_room": "event",
    "success": "result", "fail": "result",
}


def decode(path):
    raw = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", path, "-ac", "1",
                          "-ar", str(RATE), "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def k_weight(x):
    """BS.1770's two filters: a high shelf (+4 dB above ~1.7 kHz) and a high-pass."""
    f0, g, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = math.tan(math.pi * f0 / RATE)
    vh, vb = 10 ** (g / 20), 10 ** (g / 20) ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    b = [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    a = [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    x = signal.lfilter(b, a, x)
    f0, q = 38.13547087602444, 0.5003270373238773
    k = math.tan(math.pi * f0 / RATE)
    a0 = 1 + k / q + k * k
    return signal.lfilter([1, -2, 1], [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0], x)


def loudness(x):
    """Loudest 100 ms, K-weighted, in LUFS. A clip shorter than that counts as
    100 ms with silence after it: the ear sums a short sound over about that
    long, so a 50 ms blip sounds quieter than a held note at the same level."""
    y = k_weight(x) ** 2
    n = max(1, int(0.1 * RATE))
    if len(y) <= n:
        power = y.sum() / n
    else:
        power = np.convolve(y, np.ones(n) / n, mode="valid").max()
    return -0.691 + 10 * math.log10(max(power, 1e-12))


def pitch(x):
    """The strongest partial in the loudest 50 ms, refined by parabolic
    interpolation; a strong partial an octave down wins, as the fundamental."""
    n = int(0.05 * RATE)
    if len(x) > n:
        energy = np.convolve(x ** 2, np.ones(n), mode="valid")
        start = int(energy.argmax())
        x = x[start:start + n]
    w = x * np.hanning(len(x))
    size = 1 << 18
    spec = np.abs(np.fft.rfft(w, size))
    freqs = np.fft.rfftfreq(size, 1 / RATE)
    band = (freqs > 120) & (freqs < 5000)
    k = int(np.argmax(np.where(band, spec, 0)))
    half = int(round(k / 2))
    if freqs[half] > 120 and spec[half - 3:half + 4].max() > 0.35 * spec[k]:
        k = half - 3 + int(np.argmax(spec[half - 3:half + 4]))
    a, b, c = spec[k - 1], spec[k], spec[k + 1]
    shift = 0.5 * (a - c) / (a - 2 * b + c) if (a - 2 * b + c) != 0 else 0.0
    return (k + shift) * RATE / size


def note_name(f):
    midi = 69 + 12 * math.log2(f / 440)
    r = round(midi)
    return "%s%d %+.0fc" % (NAMES[r % 12], r // 12 - 1, (midi - r) * 100)


def note_freq(name):
    m = re.fullmatch(r"([a-g]#?)(\d)", name)
    if not m:
        return None
    midi = 12 * (int(m.group(2)) + 1) + NOTES[m.group(1)]
    return 440 * 2 ** ((midi - 69) / 12)


def retune(path, source, cents):
    """Writes `source` to `path` shifted by `cents`, by resampling."""
    ratio = 2 ** (cents / 1200)
    rate = int(subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                               "stream=sample_rate", "-of", "csv=p=0", source],
                              capture_output=True, text=True, check=True).stdout.strip())
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", source,
                    "-af", "asetrate=%.3f,aresample=%d" % (rate * ratio, rate),
                    "-c:a", "libmp3lame", "-q:a", "2", path], check=True)


def main():
    root = sys.argv[1]
    do_retune = "--retune" in sys.argv
    audio = os.path.join(root, "audio")
    source_dir = os.path.join(audio, "source")
    rows, gains = [], {}
    for name in sorted(os.listdir(audio)):
        if not name.endswith(".mp3"):
            continue
        stem = name[:-4]
        path = os.path.join(audio, name)
        role = "pulse" if stem.startswith("block_pulse_") else ROLE_OF.get(stem)
        if role is None:
            print("no role for", name, "- add it to ROLE_OF")
            continue
        if role == "pulse" and do_retune:
            want = note_freq(stem[len("block_pulse_"):])
            original = os.path.join(source_dir, name)
            if not os.path.exists(original):
                os.makedirs(source_dir, exist_ok=True)
                shutil.copy2(path, original)
            have = pitch(decode(original))
            cents = 1200 * math.log2(want / have)
            if abs(cents) > 5:
                retune(path, original, cents)
                print("retuned %-22s %s -> %s (%+.0f cents)" % (name, note_name(have), note_name(want), cents))
        x = decode(path)
        lufs = loudness(x)
        peak = 20 * math.log10(max(np.abs(x).max(), 1e-9))
        gain = ROLES[role] - lufs
        # Never more than the clip's headroom: a gain past 0 dBFS would clip.
        gain = min(gain, -peak - 0.5)
        gains[stem] = round(gain, 1)
        rows.append((name, role, len(x) / RATE, peak, lufs, pitch(x), gain))

    print("\n%-22s %-6s %6s %7s %7s %-16s %6s" % ("file", "role", "length", "peak", "LUFS", "pitch", "gain"))
    for name, role, length, peak, lufs, f, gain in rows:
        print("%-22s %-6s %5.2fs %6.1f %7.1f %-16s %+5.1f" % (name, role, length, peak, lufs, note_name(f), gain))
    if os.path.isdir(source_dir) and not os.path.exists(os.path.join(source_dir, ".gdignore")):
        open(os.path.join(source_dir, ".gdignore"), "w").close()
    print("\nconst GAIN_DB := {")
    for stem, gain in gains.items():
        print('\t"%s": %.1f,' % (stem, gain))
    print("}")


if __name__ == "__main__":
    main()
