# BuildVibes sound asset provenance (F5, review 50)

## sent.wav

- What: the short, soft sound when a post or a sign-off is accepted by the server.
- Made for BuildVibes on 17 Oct 2026, synthesised in code (nothing downloaded, no samples).
- How: 180 ms, mono, 16-bit PCM at 22 050 Hz. A sine at 1318.5 Hz (E6) with a quieter sine an octave below (659.25 Hz), a 6 ms fade-in and an exponential fade-out (time constant 45 ms), peak level 0.22 of full scale.
- Licence: our own work, no third-party rights. BuildVibes may use, change and ship it freely.

To make it again, run this Python 3 (standard library only) with the output path:

```python
import math, struct, sys, wave
rate, dur = 22050, 0.18
frames = []
for i in range(int(rate * dur)):
    t = i / rate
    env = min(1.0, t / 0.006) * math.exp(-t / 0.045)
    s = math.sin(2 * math.pi * 1318.5 * t) * 0.8 + math.sin(2 * math.pi * 659.25 * t) * 0.35
    v = 0.22 * env * s
    frames.append(struct.pack('<h', int(max(-1, min(1, v)) * 32767)))
with wave.open(sys.argv[1], 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(b''.join(frames))
```
