"""Simula POLIFONIA (varias notas ao mesmo tempo) no modulo real poly_gen e gera sim/poly_<musica>.wav.
Uso (na raiz do projeto):  python3 tools/poly.py [musica] [onda]
  musica: acordes | canon | todas | ode     (padrao: acordes)
  onda  : seno | quadrada | serra | triangular
Notas: C4 D4 E4 F4 G4 A4 B4 C5.  Precisa de iverilog no PATH.
"""
import subprocess, sys, os, wave, struct
N = {"C4":0,"D4":1,"E4":2,"F4":3,"G4":4,"A4":5,"B4":6,"C5":7}
ONDAS = {"seno":0,"quadrada":1,"serra":2,"triangular":3}
GAP = 40  # ms em que a tecla fica solta entre notas (o release do ADSR continua soando)

def intervalos(vozes):
    """vozes: lista de listas [(nota, tempos)], cada uma comecando em t=0 (ms); retorna segmentos (mascara, ms)."""
    ev = []  # (inicio, fim, nota)
    for atraso, melodia in vozes:
        t = atraso
        for nota, tempos in melodia:
            d = int(tempos * 500)
            if nota != "_": ev.append((t, t + d - GAP, N[nota]))
            t += d
    cortes = sorted({e[0] for e in ev} | {e[1] for e in ev})
    seg = []
    for a, b in zip(cortes, cortes[1:]):
        m = 0
        for (i, f, n) in ev:
            if i <= a and b <= f: m |= 1 << n
        seg.append((m, b - a))
    return seg

frere = [("C4",1),("D4",1),("E4",1),("C4",1)]*2 + [("E4",1),("F4",1),("G4",2)]*2 + \
        [("G4",.5),("A4",.5),("G4",.5),("F4",.5),("E4",1),("C4",1)]*2 + [("C4",1),("G4",1),("C4",2)]*2
acorde = lambda notas, t: [(m, t) for m in [sum(1 << N[n] for n in notas)]]
ode = [("E4",1),("E4",1),("F4",1),("G4",1),("G4",1),("F4",1),("E4",1),("D4",1),
       ("C4",1),("C4",1),("D4",1),("E4",1),("E4",1.5),("D4",.5),("D4",2)]
MUSICAS = {
  "ode": intervalos([(0, ode)]),
  # C - Am - F - G - C  (2 s cada, com 40 ms de pausa entre eles)
  "acordes": sum(([(sum(1 << N[n] for n in c), 2000 - GAP), (0, GAP)] for c in
                  [["C4","E4","G4"], ["E4","A4","C5"], ["F4","A4","C5"], ["D4","G4","B4"], ["C4","E4","G4"]]), []),
  # canone a 2 vozes: a 2a voz entra 4 tempos (2 s) depois
  "canon": intervalos([(0, frere), (2000, frere)]),
  # pior caso para a mixagem: as 8 notas juntas (escala sendo empilhada)
  "todas": [((1 << (k + 1)) - 1, 1500) for k in range(8)],
}
musica = sys.argv[1] if len(sys.argv) > 1 else "acordes"
onda = ONDAS[sys.argv[2]] if len(sys.argv) > 2 else 0
os.makedirs("sim", exist_ok=True)
with open("sim/poly.txt", "w") as f:
    for m, ms in MUSICAS[musica]:
        f.write("%d %d %d\n" % (m, onda, ms))
subprocess.check_call(["iverilog", "-g2005", "-o", "sim/poly.vvp", "tb/tb_poly.v", "src/poly_gen.v",
                       "src/note_rom.v", "src/wave_gen.v", "src/sine_lut.v"])
subprocess.check_call(["vvp", "sim/poly.vvp"])
x = [int(l) for l in open("sim/samples.txt") if l.strip()]
saida = "sim/poly_%s.wav" % musica
with wave.open(saida, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(48828)
    w.writeframes(b"".join(struct.pack("<h", max(-32768, min(32767, v))) for v in x))
print("%s: %.1f s, pico %d de 32767 -> %s" % (musica, len(x)/48828.125, max(abs(v) for v in x), saida))
