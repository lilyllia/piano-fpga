"""Le sim/samples.txt, grava sim/saida.wav e mede a frequencia de cada trecho.

Para que serve: conferir, sem placa, se as notas saem na frequencia certa. Usado depois
do tb_synth_core (que toca trechos de 30 ms). Ex.: o trecho do La deve dar ~440 Hz.

Uso (na raiz do projeto): python3 tools/analisa_audio.py [fs_hz] [ms_por_trecho]
fs padrao = 48828.125 (XCK 12.5 MHz / 256); ms_por_trecho padrao = 30.
"""
import sys, wave, struct

fs = float(sys.argv[1]) if len(sys.argv) > 1 else 48828.125   # amostras por segundo
ms = float(sys.argv[2]) if len(sys.argv) > 2 else 30          # duracao de cada trecho
x = [int(l) for l in open("sim/samples.txt") if l.strip()]    # uma amostra por linha

# Grava o .wav: mono, 16 bits; cada amostra e limitada a faixa de 16 bits por seguranca
with wave.open("sim/saida.wav", "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(int(round(fs)))
    w.writeframes(b"".join(struct.pack("<h", max(-32768, min(32767, v))) for v in x))
print("amostras:", len(x), " duracao: %.1f ms" % (1000 * len(x) / fs), " -> sim/saida.wav")

# Mede a frequencia de cada trecho contando quantas vezes a onda cruza o zero subindo:
# cada cruzamento subindo e o inicio de um ciclo. Frequencia = ciclos / tempo entre o 1o e o ultimo.
n = int(fs * ms / 1000)                         # amostras por trecho
for k in range(len(x) // n):
    seg = x[k*n + n//10 : (k+1)*n - n//10]      # descarta 10% de cada borda (transicoes entre trechos)
    cross = [i for i in range(1, len(seg)) if seg[i-1] < 0 <= seg[i]]   # indices dos cruzamentos subindo
    if len(cross) > 1:
        f = (len(cross) - 1) * fs / (cross[-1] - cross[0])
        print("trecho %d: pico %6d  frequencia ~ %.2f Hz" % (k, max(abs(v) for v in seg), f))
    else:
        print("trecho %d: sem cruzamentos (silencio?)" % k)
