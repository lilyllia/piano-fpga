"""Simula uma melodia nos modulos reais (tone_gen + note_rom) e gera sim/<musica>.wav.
Uso (na raiz do projeto):  python3 tools/tocar.py [musica] [onda]
  musica: ode | frere | escala         (padrao: ode)
  onda  : seno | quadrada | serra | triangular   (padrao: seno)
Notas disponiveis na placa: C4 D4 E4 F4 G4 A4 B4 C5.  Precisa de iverilog no PATH.
"""
import subprocess, sys, os, wave, struct
NOTAS = {"C4":0,"D4":1,"E4":2,"F4":3,"G4":4,"A4":5,"B4":6,"C5":7,"_":8}
ONDAS = {"seno":0,"quadrada":1,"serra":2,"triangular":3}
MUSICAS = {  # (nota, tempos); 1 tempo = 500 ms (120 bpm)
 "ode": [("E4",1),("E4",1),("F4",1),("G4",1),("G4",1),("F4",1),("E4",1),("D4",1),
         ("C4",1),("C4",1),("D4",1),("E4",1),("E4",1.5),("D4",.5),("D4",2),
         ("E4",1),("E4",1),("F4",1),("G4",1),("G4",1),("F4",1),("E4",1),("D4",1),
         ("C4",1),("C4",1),("D4",1),("E4",1),("D4",1.5),("C4",.5),("C4",2)],
 "frere": [("C4",1),("D4",1),("E4",1),("C4",1)]*2 + [("E4",1),("F4",1),("G4",2)]*2 +
          [("G4",.5),("A4",.5),("G4",.5),("F4",.5),("E4",1),("C4",1)]*2 +
          [("C4",1),("G4",1),("C4",2)]*2,
 "escala": [(n,1) for n in ["C4","D4","E4","F4","G4","A4","B4","C5"]] +
           [(n,1) for n in ["C5","B4","A4","G4","F4","E4","D4","C4"]],
}
musica = sys.argv[1] if len(sys.argv) > 1 else "ode"
onda = ONDAS[sys.argv[2]] if len(sys.argv) > 2 else 0
os.makedirs("sim", exist_ok=True)
with open("sim/melodia.txt", "w") as f:
    for nota, t in MUSICAS[musica]:
        ms = int(t * 500)
        f.write("%d %d %d\n" % (NOTAS[nota], onda, ms - 40))   # nota
        f.write("8 0 40\n")                                     # pausa curta: separa as notas
subprocess.check_call(["iverilog", "-g2005", "-o", "sim/melodia.vvp", "tb/tb_melody.v",
                       "src/tone_gen.v", "src/wave_gen.v", "src/sine_lut.v", "src/note_rom.v"])
subprocess.check_call(["vvp", "sim/melodia.vvp"])
x = [int(l) for l in open("sim/samples.txt") if l.strip()]
saida = "sim/%s.wav" % musica
with wave.open(saida, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(48828)
    w.writeframes(b"".join(struct.pack("<h", v) for v in x))
print("%s: %d amostras, %.1f s -> %s" % (musica, len(x), len(x)/48828.125, saida))
