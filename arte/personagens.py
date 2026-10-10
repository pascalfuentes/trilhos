#!/usr/bin/env python3
# =====================================================================
#  personagens.py - gera personagens.S (os sprites do profeta e dos
#  moradores) a partir do desenho "Profeta - 8 direcoes" / "Cidadaos".
#
#  Cada quadro tem 14 x 22 pixels, os pes na ultima linha. 8 direcoes
#  (S, SO, O, NO, N, NE, L, SE) x 3 poses (parado, passo 1, passo 2);
#  O, NO e SO sao os espelhos de L, NE e SE.
#  Uso: python3 arte/personagens.py > personagens.S
# =====================================================================

LOW = {
 "robe": {
  "front": [["..ff..ff..", "..ff..ff.."], ["..ff..ff..", "..ff......"], ["..ff..ff..", "......ff.."]],
  "diag": [["...ff..ff.", "...ff..ff."], ["...ff..ff.", "...ff....."], ["...ff..ff.", ".......ff."]],
  "side": [["...FF.ff..", "...FF.ff.."], ["..FF...ff.", "..FF...ff."], ["..ff...FF.", "..ff...FF."]]},
 "pants": {
  "front": [["..pppppp..", "..pppppp..", "..pp..pp..", "..pp..pp..", "..pp..pp..", "..pp..pp..", "..ff..ff..", "..ff..ff.."],
            ["..pppppp..", "..pppppp..", "..pp..pp..", "..pp..pp..", "..pp..pp..", "..pp..ff..", "..ff..ff..", "..ff......"],
            ["..pppppp..", "..pppppp..", "..pp..pp..", "..pp..pp..", "..pp..pp..", "..ff..pp..", "..ff..ff..", "......ff.."]],
  "side": [["...pppp...", "...pppp...", "...pppp...", "...pppp...", "...pppp...", "...pppp...", "...ffff...", "...fffff.."],
           ["...pppp...", "...pppp...", "..PPppp...", "..PP.pp...", "..PP..pp..", "..PP..pp..", ".FF...fff.", ".FF...fff."],
           ["...pppp...", "...pppp...", "..ppPPP...", "..pp.PP...", "..pp..PP..", "..pp..PP..", ".ff...FFF.", ".ff...FFF."]]},
 "skirt": {
  "front": [["..dddddd..", "..dddddd..", ".dddddddd.", ".DDDDDDDD.", "..ss..ss..", "..ss..ss..", "..ff..ff..", "..ff..ff.."],
            ["..dddddd..", "..dddddd..", ".dddddddd.", ".DDDDDDDD.", "..ss..ss..", "..ss..ff..", "..ff..ff..", "..ff......"],
            ["..dddddd..", "..dddddd..", ".dddddddd.", ".DDDDDDDD.", "..ss..ss..", "..ff..ss..", "..ff..ff..", "......ff.."]],
  "side": [["...dddd...", "...dddd...", "..dddddd..", "..DDDDDD..", "....ss....", "....ss....", "....fff...", "....fff..."],
           ["...dddd...", "...dddd...", "..dddddd..", "..DDDDDD..", "..SS.ss...", ".SS...ss..", ".FF...fff.", ".FF...fff."],
           ["...dddd...", "...dddd...", "..dddddd..", "..DDDDDD..", "..ss.SS...", ".ss...SS..", ".ff...FFF.", ".ff...FFF."]]},
 "cpants": {
  "front": [["..pppppp..", "..pp..pp..", "..ss..ss..", "..ss..ss..", "..ff..ff..", "..ff..ff.."],
            ["..pppppp..", "..pp..pp..", "..ss..ss..", "..ss..ff..", "..ff..ff..", "..ff......"],
            ["..pppppp..", "..pp..pp..", "..ss..ss..", "..ff..ss..", "..ff..ff..", "......ff.."]],
  "side": [["...pppp...", "...pppp...", "....ss....", "....ss....", "....fff...", "....fff..."],
           ["...pppp...", "..PP.pp...", "..SS..ss..", "..SS..ss..", ".FF...fff.", ".FF...fff."],
           ["...pppp...", "..pp.PP...", "..ss..SS..", "..ss..SS..", ".ff...FFF.", ".ff...FFF."]]},
 "cskirt": {
  "front": [["..dddddd..", ".dddddddd.", ".DDDDDDDD.", "..ss..ss..", "..ff..ff..", "..ff..ff.."],
            ["..dddddd..", ".dddddddd.", ".DDDDDDDD.", "..ss..ff..", "..ff..ff..", "..ff......"],
            ["..dddddd..", ".dddddddd.", ".DDDDDDDD.", "..ff..ss..", "..ff..ff..", "......ff.."]],
  "side": [["...dddd...", "..dddddd..", "..DDDDDD..", "....ss....", "....fff...", "....fff..."],
           ["...dddd...", "..dddddd..", "..DDDDDD..", "..SS..ss..", ".FF...fff.", ".FF...fff."],
           ["...dddd...", "..dddddd..", "..DDDDDD..", "..ss..SS..", ".ff...FFF.", ".ff...FFF."]]},
}

M = "mirror"
CHARS = {
 "profeta": {"low": "robe", "staff": {"S": 12, "SE": 12, "E": 11, "NE": 1, "N": 1}, "up": {
  "S": [M, "..hhh", ".hhhh", ".hsss", ".hses", ".hwsS", ".hwww", "hHrww", "hHrrw", "hHrrw", "hHbbb", "ssrrr", "ssrrR", ".hrrR", ".hrrR", ".hrrR", ".hRRR"],
  "N": [M, "..hhh", ".hhhh", ".hhhh", ".hhhh", ".hhhh", ".HHHH", "HHhhh", "HHhhh", "HHhhh", "HHhhh", "sshhh", "sshhh", ".rrrr", ".rrrR", ".rrrR", ".RRRR"],
  "E": ["...hhhh...", "..hhhhhh..", "..hhhhsss.", "..hhhhses.", "..hhhhwsS.", "..hhhwwww.", "..HHrrwww.", "..HHrrrww.", "..HHrhhww.", "..HHbbhhh.", "..HHrrrhss", "..HHrrrrss", "..HHrrrr..", "..HHrrrR..", "..HHrrrR..", "..HRRRRR.."],
  "SE": ["...hhhhh..", "..hhhhhhh.", "..hhsssss.", "..hhseses.", "..hhwssSw.", "..hhwwwww.", ".hrrwwwwhH", ".hrrrwwwhH", ".hrrrrwwhH", ".hbbbbbbhH", ".srrrrrrss", ".srrrrRrss", ".hrrrrRrr.", ".hrrrrRrr.", ".hrrrrRrr.", ".hRRRRRRR."],
  "NE": ["...hhhhh..", "..hhhhhhh.", "..hhhhhhh.", "..hhhhhhs.", "..hhhhhhw.", "..HHHHHHw.", "HHhhhhhhH.", "HHhhhhhhH.", "HHhhhhhhH.", "HHhhhhhhH.", "sshhhhhhs.", "sshhhhhhs.", ".rrrrrrrr.", ".rrrrrrRr.", ".rrrrrrRr.", ".RRRRRRRR."]}},
 "homem": {"low": "pants", "up": {
  "S": [M, "..kkk", "..kkk", "..ses", "..sss", "..uus", "..uuu", "uuuuu", "uUuuu", "ssuuu", "ssccc"],
  "N": [M, "..kkk", "..kkk", "..kkk", "..kkk", "..uuu", "..uuu", "uuuuu", "uUuuu", "ssuuu", "ssccc"],
  "E": ["..kkkkk...", "..kkkkkk..", "..kkkses..", "..kkssssS.", "...uuuu...", "...uuuu...", "...uUUu...", "...uUUu...", "...ussu...", "...cssc..."],
  "SE": ["..kkkkkk..", "..kkkkkk..", "..kssese..", "..ksssss..", "..uuuuuu..", "..uuuuuu..", ".Uuuuuuuuu", ".UuuuuuuUu", ".suuuuuuss", ".sccccccss"],
  "NE": ["..kkkkkk..", "..kkkkkk..", "..kkkkkk..", "..kkkkks..", "..uuuuuu..", "..uuuuuu..", "uuuuuuuuu.", "uUuuuuuuU.", "ssuuuuuus.", "ssccccccs."]}},
 "mulher": {"low": "skirt", "up": {
  "S": [M, "..kkk", ".kkkk", ".kses", ".ksss", ".kddd", ".kddd", "ddddd", "dDddd", "ssddd", "ssccc"],
  "N": [M, "..kkk", ".kkkk", ".kkkk", ".kkkk", ".kkkk", "..kkk", "dddkk", "dDddk", "ssddd", "ssccc"],
  "E": ["..kkkkk...", ".kkkkkkk..", ".kkkkses..", ".kkkksssS.", ".kkkdddd..", "..kkdddd..", "..kdDDd...", "...dDDd...", "...dssd...", "...cssc..."],
  "SE": ["..kkkkkk..", ".kkkkkkkk.", ".kkssese..", ".kksssss..", ".kdddddd..", ".kdddddd..", ".Dddddddd.", ".DdddddddD", ".sddddddss", ".sccccccss"],
  "NE": ["..kkkkkk..", ".kkkkkkkk.", ".kkkkkkkk.", ".kkkkkkks.", ".kkkkkkk..", "..kkkkkd..", "dddkkkddd.", "dDddddddD.", "ssdddddds.", "ssccccccs."]}},
 "menino": {"low": "cpants", "up": {
  "S": [M, "..kkk", ".kkkk", "..ses", "..sss", "..uuu", ".uuuu", ".suuu", ".suuu"],
  "N": [M, "..kkk", ".kkkk", "..kkk", "..kkk", "..uuu", ".uuuu", ".suuu", ".suuu"],
  "E": ["..kkkkk...", ".kkkkkkk..", "..kkkses..", "..kkssssS.", "...uuuu...", "...uUUu...", "...ussu...", "...uuuu..."],
  "SE": ["...kkkkk..", "..kkkkkkk.", "..kssese..", "..ksssss..", "..uuuuuu..", ".UuuuuuuU.", ".suuuuuus.", ".suuuuuus."],
  "NE": ["...kkkkk..", "..kkkkkkk.", "..kkkkkk..", "..kkkkks..", "..uuuuuu..", ".UuuuuuuU.", ".suuuuuus.", ".suuuuuus."]}},
 "menina": {"low": "cskirt", "up": {
  "S": [M, "..kkk", ".kkkk", "kkses", "kksss", "..ddd", ".dddd", ".sddd", ".sddd"],
  "N": [M, "..kkk", ".kkkk", "kkkkk", "kkkkk", "..ddd", ".dddd", ".sddd", ".sddd"],
  "E": ["..kkkkk...", ".kkkkkkk..", "kkkkkses..", "kkkkssssS.", "...dddd...", "...dDDd...", "...dssd...", "...dddd..."],
  "SE": ["...kkkkk..", "..kkkkkkk.", "kkkssesekk", "kkkssssskk", "..dddddd..", ".DddddddD.", ".sdddddds.", ".sdddddds."],
  "NE": ["...kkkkk..", "..kkkkkkk.", "kkkkkkkkkk", "kkkkkkkskk", "..dddddd..", ".DddddddD.", ".sdddddds.", ".sdddddds."]}},
}

# cores (0xRRGGBB); as roupas dos moradores (u/U, d/D) sao a cor da familia
# (os indices especiais 8 e 9 da paleta: a mesma cor dos telhados)
COMMON = {"s": 0xdfb48d, "S": 0xb98c66, "w": 0xdcd6c8, "W": 0xaaa395, "e": 0x28282c, "f": 0x28282c,
          "F": 0x3d3c44, "t": 0x7a5030, "T": 0x563921, "g": 0xf9de77, "G": 0xd9a94a}
OWN = {
 "profeta": {"h": 0x72492a, "H": 0x563921, "r": 0xc4ad80, "R": 0x9a8560, "b": 0xc99a3e},
 "homem": {"k": 0x36291a, "u": 8, "U": 9, "c": 0x563921, "p": 0x453929, "P": 0x30281c},
 "mulher": {"k": 0x36291a, "d": 8, "D": 9, "c": 0x5a3a28},
 "menino": {"k": 0x6b4426, "u": 8, "U": 9, "p": 0x453929, "P": 0x30281c},
 "menina": {"k": 0x36291a, "d": 8, "D": 9},
}
PAL0 = 48                     # primeiro indice livre na paleta do ermo.S

W, H = 14, 22
DIRS = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
SLOT = 320                    # bytes por quadro (4 de cabecalho + 14 x 22)


def frame(ch, d, pose, staff):
    c = CHARS[ch]
    U = c["up"][d]
    if U[0] == M:
        U = [r + r[::-1] for r in U[1:]]
    L = LOW[c["low"]]
    view = "side" if d == "E" else ("diag" if d in ("SE", "NE") and "diag" in L else "front")
    lo = L[view][pose]
    bob = 1 if pose else 0
    y0 = H - len(U) - len(lo)
    g = [["."] * W for _ in range(H)]
    for y, r in enumerate(lo):
        for x, p in enumerate(r):
            if p != ".":
                g[y0 + len(U) + y][x + 2] = p
    for y, r in enumerate(U):
        for x, p in enumerate(r):
            if p != ".":
                g[y0 + y + bob][x + 2] = p
    if staff and "staff" in c:
        sc = c["staff"][d]
        for y in range(3 + bob, H):
            if g[y][sc] not in "sS":
                g[y][sc] = "t" if y % 5 else "T"
        g[bob][sc] = "g"
        g[bob + 1][sc - 1] = "G"
        g[bob + 1][sc] = "g"
        g[bob + 1][sc + 1] = "G"
        g[bob + 2][sc] = "G"
    return g


def full(ch, d, pose, staff):
    m = {"W": "E", "SW": "SE", "NW": "NE"}
    if d in m:
        return [r[::-1] for r in frame(ch, m[d], pose, staff)]
    return frame(ch, d, pose, staff)


SETS = [("profeta", True, "profeta com o cajado"), ("profeta", False, "profeta sem o cajado (ferramenta ou tocha na mao)"),
        ("homem", False, "homem"), ("mulher", False, "mulher"), ("menino", False, "menino"), ("menina", False, "menina")]

colors = []
def pidx(ch, p):
    v = OWN[ch].get(p, COMMON.get(p))
    if v is None:
        raise SystemExit("cor sem nome: %s %s" % (ch, p))
    if v < 16:
        return v
    if v not in colors:
        colors.append(v)
    return PAL0 + colors.index(v)


out = []
w = out.append
w("// =====================================================================")
w("//  personagens.S - sprites do profeta (voce) e dos moradores da vila")
w("//  GERADO por arte/personagens.py: mude la e rode de novo")
w("//    python3 arte/personagens.py > personagens.S")
w("//")
w("//  14 x 22 pixels por quadro, pes na ultima linha; desenhados com metade")
w("//  da escala dos outros sprites (o dobro de detalhe, o mesmo tamanho).")
w("//  quadro = conjunto * 24 + direcao * 3 + pose")
w("//    direcao: 0 S, 1 SO, 2 O, 3 NO, 4 N, 5 NE, 6 L, 7 SE (na tela)")
w("//    pose: 0 parado, 1 e 2 os passos (ciclo 0 1 0 2)")
w("//    conjuntos: 0 profeta, 1 profeta sem cajado, 2 homem, 3 mulher,")
w("//               4 menino, 5 menina")
w("// =====================================================================")
w('#include "comum.h"')
w("")
w("    .data")
w("    .p2align 6")
w("    .globl charspr")
w("charspr:")
for si, (ch, staff, name) in enumerate(SETS):
    w("// %d: %s" % (si, name))
    for di, d in enumerate(DIRS):
        for pose in range(3):
            g = full(ch, d, pose, staff)
            data = [W, H, 7, 0]
            for row in g:
                for p in row:
                    data.append(0 if p == "." else pidx(ch, p))
            data += [0] * (SLOT - len(data))
            w("    .byte " + ",".join(str(b) for b in data))

w("")
w("// as cores ficam na paleta do ermo.S, a partir do indice %d, nesta ordem:" % PAL0)
for i in range(0, len(colors), 4):
    w("//    .word " + ", ".join("0xFF%06X" % c for c in colors[i:i + 4]))
print("\n".join(out))
