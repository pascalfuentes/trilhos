#!/usr/bin/env python3
# =====================================================================
#  estruturas.py - gera os desenhos das construcoes a partir do
#  design/estruturas/estruturas.json (o canvas do designer).
#
#  Saidas (na pasta do jogo):
#    estruturas.S   quadros (alta e baixa resolucao) e azulejos da estrada
#    estruturas.h   numeros dos quadros (EF_*) e das pilhas (PK_*)
#    estrpal.inc    as cores novas da paleta (indices 66..127)
#
#  Uso: python3 arte/estruturas.py design/estruturas/estruturas.json .
# =====================================================================
import json, sys, os
from collections import Counter

src = json.load(open(sys.argv[1]))
out = sys.argv[2] if len(sys.argv) > 2 else '.'
fmt = src['_formato']
E = src['estruturas']
PAL = fmt['paleta']
GLOW = ['F', 'L', 'V', 'Y']             # nao escurecem de noite (alfa 0xFE)
PAL0 = 66                               # primeiro indice livre na paleta
GLOW0 = 124                             # F L V Y = 124..127
HI_K, LO_K = 11, 21                     # profundidade por linha abaixo da ancora

# letra -> indice da paleta
idx = {'.': 0, 'x': 8, 'X': 9}
for k, g in enumerate(GLOW):
    idx[g] = GLOW0 + k
nxt = PAL0
for letra in sorted(PAL):
    if letra in idx:
        continue
    idx[letra] = nxt
    nxt += 1
assert nxt <= GLOW0, 'cores demais'

def argb(letra):
    h = PAL[letra].lstrip('#')
    a = 0xFE if letra in GLOW else 0xFF
    return (a << 24) | int(h, 16)

# quadros: (nome da constante, estrutura, estado)
frames = []
def add(est, estado):
    frames.append(('EF_%s_%s' % (est.upper(), estado.upper()), est, estado))

ORDEM = ['fogueira', 'bau', 'abrigo', 'cerca', 'portao', 'barraco', 'casa',
         'fornalha', 'lampiao']
for est in ORDEM:
    for estado in E[est]['quadros']:
        add(est, estado)
PILHAS = [n for n in E if n.startswith('pilha_')]
for est in PILHAS:
    for estado in ('pouco', 'metade', 'cheia'):
        add(est, estado)

def grid(est, estado):
    s = E[est]
    rows = s['quadros'][estado]
    w, h = s['tamanho']
    assert len(rows) == h and all(len(r) == w for r in rows), (est, estado)
    for r in rows:
        for c in r:
            assert c in idx, (est, estado, c)
    return rows

def half(rows):
    """1 pixel para cada 2 x 2: a cor mais comum (empate: a que nao e
    transparente)."""
    h, w = len(rows), len(rows[0])
    out_ = []
    for y in range(0, h, 2):
        line = ''
        for x in range(0, w, 2):
            bloco = [rows[yy][xx] for yy in (y, y + 1) for xx in (x, x + 1)
                     if yy < h and xx < w]
            cnt = Counter(bloco)
            best = max(cnt.items(), key=lambda kv: (kv[1], kv[0] != '.'))
            line += best[0]
        out_.append(line)
    return out_

def emit_frame(lab, rows, ax, ay, k):
    w, h = len(rows[0]), len(rows)
    data = [w, h, ax, ay, k, 0, 0, 0]
    for r in rows:
        data += [idx[c] for c in r]
    lines = ['%s:' % lab]
    for i in range(0, len(data), 32):
        lines.append('    .byte ' + ','.join(str(b) for b in data[i:i + 32]))
    return lines

S = []
w = S.append
w('// =====================================================================')
w('//  estruturas.S - construcoes, pilhas e estrada (GERADO: nao edite)')
w('//    python3 arte/estruturas.py design/estruturas/estruturas.json .')
w('//  Cada quadro: largura, altura, ancora x, ancora y, profundidade por')
w('//  linha abaixo da ancora, 0, 0, 0 e os pixels (indices da paleta).')
w('//  estrtab: (alta, baixa) por quadro; a baixa e para o zoom mais longe.')
w('// =====================================================================')
w('#include "comum.h"')
w('')
w('    .data')
w('    .p2align 3')
w('    .globl estrtab')
w('estrtab:')
for n, (c, est, estado) in enumerate(frames):
    w('    .quad ef%d_hi, ef%d_lo' % (n, n))
w('')
for n, (c, est, estado) in enumerate(frames):
    s = E[est]
    rows = grid(est, estado)
    ax, ay = s['ancora']
    w('// %d: %s %s' % (n, est, estado))
    S.extend(emit_frame('ef%d_hi' % n, rows, ax, ay, HI_K))
    S.extend(emit_frame('ef%d_lo' % n, half(rows), ax // 2, ay // 2, LO_K))

# estrada: 16 azulejos 24 x 12 em ARGB (0 = transparente), na ordem da mascara
road = E['estrada']
masc = road['mascara']['quadro_por_mascara']
assert road['mascara']['bits'] == {'+u': 1, '+v': 2, '-u': 4, '-v': 8}
w('')
w('// estrada: azulejo de cada mascara (+u 1, +v 2, -u 4, -v 8), 24 x 12 ARGB')
w('    .p2align 2')
w('    .globl roadtiles')
w('roadtiles:')
for m, nome in enumerate(masc):
    rows = grid('estrada', nome)
    w('// %d: %s' % (m, nome))
    for r in rows:
        w('    .word ' + ', '.join('0' if c == '.' else '0x%08X' % argb(c) for c in r))

# pilhas: quadro "pouco" de cada tipo (metade = +1, cheia = +2)
w('')
w('// pilhas: primeiro quadro (pouco) de cada tipo PK_*')
w('    .p2align 1')
w('    .globl pilebase')
w('pilebase:')
pk = []
for est in PILHAS:
    pk.append(est)
    base = [i for i, f in enumerate(frames) if f[1] == est][0]
    w('    .hword %d    // %s' % (base, est))

open(os.path.join(out, 'estruturas.S'), 'w').write('\n'.join(S) + '\n')

H = ['// estruturas.h - numeros dos quadros das construcoes (GERADO por',
     '// arte/estruturas.py: nao edite)']
for n, (c, est, estado) in enumerate(frames):
    H.append('.equ %s, %d' % (c.replace('+', 'P').replace('-', 'M'), n))
H.append('.equ EF_N, %d' % len(frames))
for k, est in enumerate(pk):
    H.append('.equ PK_%s, %d' % (est[6:].upper(), k))
H.append('.equ PK_N, %d' % len(pk))
H.append('.equ GLOW0, %d' % GLOW0)
for est in ORDEM:
    for estado, a in (E[est].get('animacoes') or {}).items():
        H.append('.equ EA_%s_MS, %d' % (est.upper(), a['ms']))
open(os.path.join(out, 'estruturas.h'), 'w').write('\n'.join(H) + '\n')

P = ['// estrpal.inc - cores das construcoes na paleta, indices %d..%d' % (PAL0, GLOW0 + 3),
     '// (GERADO por arte/estruturas.py; F L V Y brilham: alfa 0xFE)']
cores = [0] * (GLOW0 + 4 - PAL0)
for letra, i in idx.items():
    if i >= PAL0:
        cores[i - PAL0] = argb(letra)
for i in range(0, len(cores), 4):
    P.append('    .word ' + ', '.join('0x%08X' % c for c in cores[i:i + 4]) +
             '  // %d-%d' % (PAL0 + i, PAL0 + i + 3))
open(os.path.join(out, 'estrpal.inc'), 'w').write('\n'.join(P) + '\n')
print('ok: %d quadros, %d pilhas, %d cores' % (len(frames), len(pk), nxt - PAL0 + 4))
