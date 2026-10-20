"""Le sim/samples.txt, grava sim/saida.wav e mede a frequencia de cada trecho.
Uso (na raiz do projeto): python3 tools/analisa_audio.py [fs_hz] [ms_por_trecho]
fs padrao = 48828.125 (XCK 12.5 MHz / 256).
"""
import sys, wave, struct
fs = float(sys.argv[1]) if len(sys.argv) > 1 else 48828.125
ms = float(sys.argv[2]) if len(sys.argv) > 2 else 30
x = [int(l) for l in open("sim/samples.txt") if l.strip()]
with wave.open("sim/saida.wav", "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(int(round(fs)))
    w.writeframes(b"".join(struct.pack("<h", max(-32768, min(32767, v))) for v in x))
print("amostras:", len(x), " duracao: %.1f ms" % (1000 * len(x) / fs), " -> sim/saida.wav")
n = int(fs * ms / 1000)
for k in range(len(x) // n):
    seg = x[k*n + n//10 : (k+1)*n - n//10]      # descarta bordas do trecho
    cross = [i for i in range(1, len(seg)) if seg[i-1] < 0 <= seg[i]]
    if len(cross) > 1:
        f = (len(cross) - 1) * fs / (cross[-1] - cross[0])
        print("trecho %d: pico %6d  frequencia ~ %.2f Hz" % (k, max(abs(v) for v in seg), f))
    else:
        print("trecho %d: sem cruzamentos (silencio?)" % k)
