"""Simula POLIFONIA (varias notas ao mesmo tempo) no modulo real poly_gen e gera sim/poly_<musica>.wav.

Para que serve: ouvir no computador como a placa tocaria acordes e melodias sobrepostas.
Passo a passo: converte a musica numa lista de trechos "quais notas estao ligadas e por
quanto tempo" -> escreve sim/poly.txt -> compila e roda tb/tb_poly.v -> grava o .wav.
Obs.: o tb_poly usa VOICE_SHIFT = 4, entao o .wav sai com metade do volume da placa.

Uso (na raiz do projeto):  python3 tools/poly.py [musica] [onda]
  musica: acordes | canon | todas | ode     (padrao: acordes)
  onda  : seno | quadrada | serra | triangular
Notas: C4 D4 E4 F4 G4 A4 B4 C5.  Precisa de iverilog no PATH.
"""
import subprocess, sys, os, wave, struct

N = {"C4":0,"D4":1,"E4":2,"F4":3,"G4":4,"A4":5,"B4":6,"C5":7}   # numero do bit de cada nota
ONDAS = {"seno":0,"quadrada":1,"serra":2,"triangular":3}
GAP = 40  # ms em que a tecla fica solta entre notas (o release do ADSR continua soando)

def intervalos(vozes):
    """Converte vozes independentes numa sequencia de trechos para o tb_poly.

    vozes: lista de (atraso_ms, melodia), melodia = lista de (nota, tempos); "_" = pausa.
    Retorna lista de (mascara, ms): em cada trecho, mascara tem 1 no bit de cada nota ligada.
    Ideia: anota inicio e fim de cada nota, ordena todos esses instantes ("cortes") e,
    entre dois cortes seguidos, ve quais notas estao soando.
    """
    ev = []  # (inicio, fim, nota)
    for atraso, melodia in vozes:
        t = atraso
        for nota, tempos in melodia:
            d = int(tempos * 500)                   # 1 tempo = 500 ms
            if nota != "_": ev.append((t, t + d - GAP, N[nota]))   # solta GAP ms antes da proxima
            t += d
    cortes = sorted({e[0] for e in ev} | {e[1] for e in ev})
    seg = []
    for a, b in zip(cortes, cortes[1:]):
        m = 0
        for (i, f, n) in ev:
            if i <= a and b <= f: m |= 1 << n       # nota n soa durante todo o trecho [a, b]
        seg.append((m, b - a))
    return seg

frere = [("C4",1),("D4",1),("E4",1),("C4",1)]*2 + [("E4",1),("F4",1),("G4",2)]*2 + \
        [("G4",.5),("A4",.5),("G4",.5),("F4",.5),("E4",1),("C4",1)]*2 + [("C4",1),("G4",1),("C4",2)]*2
acorde = lambda notas, t: [(m, t) for m in [sum(1 << N[n] for n in notas)]]   # (nao usado abaixo)
ode = [("E4",1),("E4",1),("F4",1),("G4",1),("G4",1),("F4",1),("E4",1),("D4",1),
       ("C4",1),("C4",1),("D4",1),("E4",1),("E4",1.5),("D4",.5),("D4",2)]
MUSICAS = {
  "ode": intervalos([(0, ode)]),
  # C - Am - F - G - C  (2 s cada, com 40 ms de pausa entre eles)
  # (o "G" aqui e D4 G4 B4, porque nao ha G3 nem D5 na placa)
  "acordes": sum(([(sum(1 << N[n] for n in c), 2000 - GAP), (0, GAP)] for c in
                  [["C4","E4","G4"], ["E4","A4","C5"], ["F4","A4","C5"], ["D4","G4","B4"], ["C4","E4","G4"]]), []),
  # canone a 2 vozes: a 2a voz entra 4 tempos (2 s) depois
  "canon": intervalos([(0, frere), (2000, frere)]),
  # pior caso para a mixagem: as 8 notas juntas (escala sendo empilhada: 1, 2, ... 8 notas)
  "todas": [((1 << (k + 1)) - 1, 1500) for k in range(8)],
}
musica = sys.argv[1] if len(sys.argv) > 1 else "acordes"
onda = ONDAS[sys.argv[2]] if len(sys.argv) > 2 else 0
os.makedirs("sim", exist_ok=True)

# 1. Partitura no formato do tb_poly: "mascara onda duracao_ms" por linha
with open("sim/poly.txt", "w") as f:
    for m, ms in MUSICAS[musica]:
        f.write("%d %d %d\n" % (m, onda, ms))

# 2. Compila e roda a simulacao (gera sim/samples.txt)
subprocess.check_call(["iverilog", "-g2005", "-o", "sim/poly.vvp", "tb/tb_poly.v", "src/poly_gen.v",
                       "src/note_rom.v", "src/wave_gen.v", "src/sine_lut.v"])
subprocess.check_call(["vvp", "sim/poly.vvp"])

# 3. Converte em .wav e mostra o pico (o mais perto de 32767, o maior volume sem distorcer)
x = [int(l) for l in open("sim/samples.txt") if l.strip()]
saida = "sim/poly_%s.wav" % musica
with wave.open(saida, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(48828)
    w.writeframes(b"".join(struct.pack("<h", max(-32768, min(32767, v))) for v in x))
print("%s: %.1f s, pico %d de 32767 -> %s" % (musica, len(x)/48828.125, max(abs(v) for v in x), saida))
