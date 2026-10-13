#!/usr/bin/env python3
# =====================================================================
#  pixel.py - gera os sprites em pixel art a partir do guia de estilo do
#  designer (design/estilo/designer/ermo_estilo.json, pedido 0.0).
#
#  Saidas (na pasta do jogo):
#    pixel.S     quadros (cabecalho de 8 bytes) e tabelas
#    pixel.h     numeros das camadas e dos objetos
#    pixpal.inc  a paleta-mestra do designer (indices 130..221)
#
#  Com o terceiro argumento (pedido 1.0, ermo_fase1.json) gera tambem as
#  imagens da interface em ARGB: a janela do personagem, a barra de XP,
#  o botao + nos 4 estados, os icones dos atributos e o retrato do heroi
#  (as camadas de frente). Cada imagem: largura, altura (.word), um .quad
#  para a textura (o jogo cria na primeira vez) e os pixels.
#  As areas da janela viram constantes UA_<NOME>_X/Y/W/H no pixel.h.
#
#  O quarto argumento (pedido 2.0, ermo_fase2.json) traz o lobo e o urso
#  animados (parado, andar, atacar, golpe, morrer): tabelas pixwolf e
#  pixbear, direcao * EN_NF + EN_<ANIMACAO> + quadro.
#  Sombras (pixshadow): ovais com o indice 254, que o blit escurece.
#
#  Uso: python3 arte/pixel.py design/estilo/designer/ermo_estilo.json . \
#           design/fase1/designer/ermo_fase1.json design/fase2/designer/ermo_fase2.json
#
#  Cada quadro: largura, altura, ancora x, ancora y, k, 0, 0, 0 e os
#  pixels (indices da paleta, 0 = transparente). k = profundidade por
#  linha abaixo da ancora: com o chao 32 x 16, uma linha do desenho
#  desce 1/16 de celula em u+v = 8 unidades de profundidade.
#  As direcoes saem na ordem de char_dir (heroi.S): S SO O NO N NE L SE;
#  SO, O e NO sao o espelho de SE, L e NE.
# =====================================================================
import json, sys, os

src = json.load(open(sys.argv[1]))
out = sys.argv[2] if len(sys.argv) > 2 else '.'
PAL0 = 130
K = 8
DIRS = ['S', 'SO', 'O', 'NO', 'N', 'NE', 'L', 'SE']
MIRROR = {'SO': 'SE', 'O': 'L', 'NO': 'NE'}

# ---- paleta ----
pal = src['_paleta']
GLOW = set(pal['brilho'])
idx = {'.': 0}
cores = []
for r in pal['rampas']:
    for t in r['tons']:
        c = t['c']
        assert c not in idx, c
        idx[c] = PAL0 + len(cores)
        a = 0xFE if c in GLOW else 0xFF
        cores.append((a << 24) | int(t['hex'].lstrip('#'), 16))
# rampas novas dos pedidos seguintes (fase 1: luz dourada; fase 2: pelo
# do urso, brilho de campeao e de chefe)
f1 = json.load(open(sys.argv[3])) if len(sys.argv) > 3 else {}
f2 = json.load(open(sys.argv[4])) if len(sys.argv) > 4 else {}
for r in f1.get('_paleta_adicoes', []) + f2.get('_paleta_adicoes', []):
    for t in r['tons']:
        c = t['c']
        assert c not in idx, c
        idx[c] = PAL0 + len(cores)
        if r.get('brilho'):
            GLOW.add(c)
        a = 0xFE if c in GLOW else 0xFF
        cores.append((a << 24) | int(t['hex'].lstrip('#'), 16))
assert PAL0 + len(cores) <= 254
idx['§'] = 254                         # sombra: o blit escurece o que ja esta ali

def check(rows, w, h, nome):
    assert len(rows) == h, (nome, len(rows), h)
    for r in rows:
        assert len(r) == w, (nome, len(r), w)
        for c in r:
            assert c in idx, (nome, c)
    return rows

def flip(rows):
    return [r[::-1] for r in rows]

S = []
w = S.append
lab_n = [0]

def emit(rows, ax, ay):
    lab = 'px%d' % lab_n[0]
    lab_n[0] += 1
    wd, ht = len(rows[0]), len(rows)
    data = [wd, ht, ax, ay, K, 0, 0, 0]
    for r in rows:
        data += [idx[c] for c in r]
    w('%s:' % lab)
    for i in range(0, len(data), 48):
        w('    .byte ' + ','.join(str(b) for b in data[i:i + 48]))
    return lab

def dir_frames(peca, chave='parado', fonte=None):
    """8 direcoes x n quadros -> lista de (linhas, ax, ay) na ordem DIRS."""
    p = src[peca]
    wd, ht = p['quadro']
    ax, ay = p['ancora']
    dd = fonte if fonte is not None else p['direcoes']
    res = []
    for d in DIRS:
        base = MIRROR.get(d, d)
        quadros = dd[base][chave]
        for q in quadros:
            rows = check(q, wd, ht, peca)
            if d in MIRROR:
                res.append((flip(rows), wd - ax, ay))
            else:
                res.append((rows, ax, ay))
    return res

def clip_top(frames, n_por_dir, y0):
    """cabelo sob o capacete: some o que fica acima de y0 (+1 nos quadros
    3 e 4, que descem com a respiracao)."""
    res = []
    for i, (rows, ax, ay) in enumerate(frames):
        q = i % n_por_dir
        lim = y0 + (1 if q >= 2 else 0)
        res.append((['.' * len(r) if y < lim else r for y, r in enumerate(rows)], ax, ay))
    return res

w('// =====================================================================')
w('//  pixel.S - sprites em pixel art do designer (GERADO: nao edite)')
w('//    python3 arte/pixel.py design/estilo/designer/ermo_estilo.json . design/fase1/designer/ermo_fase1.json design/fase2/designer/ermo_fase2.json')
w('//  Cada quadro: largura, altura, ancora x, ancora y, k, 0, 0, 0 e os')
w('//  pixels (indices da paleta 130.., 0 = transparente).')
w('// =====================================================================')
w('#include "comum.h"')
w('')
w('    .data')

# ---- heroi: camadas ----
CAMADAS = [  # (codigo, peca, nome)
    ('PL_CORPO', 'heroi_homem'),
    ('PL_CABELO', 'cabelo_homem'),
    ('PL_BOTAS', 'botas_couro'),
    ('PL_PEITO', 'peitoral_aco'),
    ('PL_CAPACETE', 'capacete_ferro'),
    ('PL_ARMA', 'espada_curta_mao'),
    ('PL_CABELO_ELMO', None),          # cabelo cortado sob o capacete
]
NQ = 4
labs = {}
for cod, peca in CAMADAS:
    if peca is None:
        fr = clip_top(dir_frames('cabelo_homem'), NQ, 13)
    else:
        fr = dir_frames(peca)
    assert len(fr) == 8 * NQ, (cod, len(fr))
    w('// %s: %s' % (cod, peca or 'cabelo_homem sob o capacete'))
    labs[cod] = [emit(*f) for f in fr]

w('')
w('// pixhero: camada * 32 + direcao * 4 + quadro')
w('    .p2align 3')
w('    .globl pixhero')
w('pixhero:')
for cod, _ in CAMADAS:
    ls = labs[cod]
    for i in range(0, len(ls), 8):
        w('    .quad ' + ', '.join(ls[i:i + 8]))

# ordem de desenho por direcao (codigos das camadas; 255 = fim)
NOMES = {'corpo': 'PL_CORPO', 'cabelo': 'PL_CABELO', 'botas': 'PL_BOTAS',
         'peito': 'PL_PEITO', 'capacete': 'PL_CAPACETE', 'arma': 'PL_ARMA'}
num = {cod: i for i, (cod, _) in enumerate(CAMADAS)}
ordem = src['_ordem_camadas']
w('')
w('// pixorder: 8 bytes por direcao, as camadas de tras para a frente')
w('    .globl pixorder')
w('pixorder:')
for d in DIRS:
    base = MIRROR.get(d, d)
    seq = [num[NOMES[c]] for c in ordem[base] if c in NOMES]
    seq += [255] * (8 - len(seq))
    w('    .byte ' + ', '.join(str(b) for b in seq) + '    // ' + d)

# ---- inimigos (pedido 2.0): lobo e urso animados ----
ANIMS = ['parado', 'andar', 'atacar', 'golpe', 'morrer']
EN = {}
if f2:
    NF = sum(f2['_animacoes'][a] for a in ANIMS)
    for tab, peca in (('pixwolf', 'lobo_inimigo'), ('pixbear', 'urso_inimigo')):
        p2 = f2[peca]
        wd, ht = p2['quadro']
        ax, ay = p2['ancora']
        w('')
        w('// %s (%s): direcao * %d + animacao + quadro' % (tab, peca, NF))
        labs2 = []
        for d in DIRS:
            base = MIRROR.get(d, d)
            for a in ANIMS:
                qs = p2['direcoes'][base][a]
                assert len(qs) == f2['_animacoes'][a], (peca, d, a)
                for q in qs:
                    rows = check(q, wd, ht, peca)
                    if d in MIRROR:
                        labs2.append(emit(flip(rows), wd - ax, ay))
                    else:
                        labs2.append(emit(rows, ax, ay))
        w('    .p2align 3')
        w('    .globl %s' % tab)
        w('%s:' % tab)
        for i in range(0, len(labs2), 8):
            w('    .quad ' + ', '.join(labs2[i:i + 8]))
    b0 = 0
    for a in ANIMS:
        EN['EN_' + a.upper()] = b0
        b0 += f2['_animacoes'][a]
    EN['EN_NF'] = NF
else:
    w('')
    w('// lobo: direcao * 4 + quadro')
    lobo = [emit(*f) for f in dir_frames('lobo_cinzento')]
    w('    .p2align 3')
    w('    .globl pixwolf')
    w('pixwolf:')
    for i in range(0, len(lobo), 8):
        w('    .quad ' + ', '.join(lobo[i:i + 8]))

# ---- sombras: ovais no chao (indice 254), heroi, lobo e urso ----
def oval(wd, ht):
    rows = []
    for y in range(ht):
        r = ''
        for x in range(wd):
            dx = (x + 0.5 - wd / 2) / (wd / 2)
            dy = (y + 0.5 - ht / 2) / (ht / 2)
            r += '§' if dx * dx + dy * dy <= 1.0 else '.'
        rows.append(r)
    return rows
w('')
w('// sombras (heroi, lobo, urso): o blit escurece o chao')
sl = [emit(oval(sw, sh), sw // 2, sh // 2) for sw, sh in ((22, 8), (30, 8), (44, 12))]
w('    .p2align 3')
w('    .globl pixshadow')
w('pixshadow: .quad ' + ', '.join(sl))

# ---- objetos ----
OBJ = [('PX_ARVORE', 'arvore_folha'), ('PX_PINHEIRO', 'pinheiro_neve'),
       ('PX_PEDRA', 'pedra'), ('PX_TOCHA0', 'tocha', 0), ('PX_TOCHA1', 'tocha', 1),
       ('PX_PENHASCO', 'penhasco_neve')]
olabs = []
w('')
for o in OBJ:
    cod, peca = o[0], o[1]
    p = src[peca]
    wd, ht = p['quadro']
    ax, ay = p['ancora']
    rows = p['parado'][o[2]] if len(o) > 2 else p['linhas']
    w('// %s: %s' % (cod, peca))
    olabs.append(emit(check(rows, wd, ht, peca), ax, ay))
w('    .p2align 3')
w('    .globl pixobj')
w('pixobj:')
w('    .quad ' + ', '.join(olabs))


# ---- chao: azulejos de 32 x 16 em ARGB, lidos pelo terreno (ermo.S) ----
HEX = {}
for r in pal['rampas']:
    for t in r['tons']:
        HEX[t['c']] = 0xFF000000 | int(t['hex'].lstrip('#'), 16)

def fill(rows):
    """o losango vira um retangulo: cada '.' pega a cor mais perto na
    mesma linha (o terreno le pelo ponto dentro da celula; nas bordas o
    arredondamento pode cair fora do losango). A 16a linha copia a 15a."""
    rows = [list(r) for r in rows]
    rows[15] = list(rows[14])
    for r in rows:
        cols = [i for i, c in enumerate(r) if c != '.']
        for i in range(len(r)):
            if r[i] == '.':
                j = min(cols, key=lambda c: abs(c - i))
                r[i] = r[j]
    return [''.join(r) for r in rows]

def recolor(rows, m):
    return [''.join(m.get(c, c) for c in r) for r in rows]

V = lambda peca, i=0: src[peca]['variacoes'][i]
TILES = [
    ('TL_GRAMA', V('chao_grama', 0)), ('TL_GRAMA1', V('chao_grama', 1)),
    ('TL_GRAMA2', V('chao_grama', 2)), ('TL_GRAMA3', V('chao_grama', 3)),
    ('TL_FLORESTA', recolor(V('chao_grama', 0), {'G': 'H', 'H': 'I', 'I': 'J'})),
    ('TL_SECO', recolor(V('chao_grama', 2), {'H': 'G', 'I': 'H', 'J': 'I'})),
    ('TL_AREIA', V('chao_areia')), ('TL_NEVE', V('chao_neve')),
    ('TL_ROCHA', recolor(V('chao_neve'), {'N': 'P', 'O': 'Q', 'Y': 'R', 'Z': 'S'})),
    ('TL_AGUA_RASA', V('chao_agua_rasa')), ('TL_AGUA_FUNDA', V('chao_agua_funda')),
    ('TL_ESTRADA', V('chao_estrada')),
    ('TL_ARADA', recolor(V('chao_grama', 0), {'G': 'T', 'H': 'T', 'I': 'U', 'J': 'V'})),
    ('TL_ARADA_MOLHADA', recolor(V('chao_grama', 0), {'G': 'U', 'H': 'U', 'I': 'V', 'J': 'V'})),
    ('TL_CAMINHO', recolor(V('chao_areia'), {'A': 'T', 'B': 'T', 'C': 'U', 'D': 'U'})),
    ('TL_BURACO', recolor(V('chao_estrada'), {'P': 'Q', 'Q': 'R', 'R': 'S'})),
]
w('')
w('// pixtiles: azulejos do chao, 32 x 16 ARGB (2048 bytes cada)')
w('    .p2align 4')
w('    .globl pixtiles')
w('pixtiles:')
for cod, rows in TILES:
    rows = fill(check(rows, 32, 16, cod) if len(rows) == 16 else rows)
    w('// %s' % cod)
    for r in rows:
        w('    .word ' + ', '.join('0x%08X' % HEX[c] for c in r))

# ---- interface (pedido 1.0) ----
UA = []
if f1:
    for r in f1.get('_paleta_adicoes', []):
        for t in r['tons']:
            HEX[t['c']] = 0xFF000000 | int(t['hex'].lstrip('#'), 16)

    def ui_img(lab, rows, cores=None):
        cmap = dict(HEX)
        for c, h in (cores or {}).items():
            cmap[c] = 0xFF000000 | int(h.split()[0].lstrip('#'), 16)
        wd, ht = len(rows[0]), len(rows)
        for r in rows:
            assert len(r) == wd, (lab, len(r), wd)
        w('    .p2align 3')
        w('    .globl %s' % lab)
        w('%s:' % lab)
        w('    .word %d, %d' % (wd, ht))
        w('    .quad 0')
        for r in rows:
            px = [0 if c == '.' else cmap[c] for c in r]
            for i in range(0, len(px), 16):
                w('    .word ' + ', '.join('0x%08X' % v for v in px[i:i + 16]))

    w('')
    w('// ---- interface: imagens ARGB (largura, altura, textura, pixels) ----')
    jp = f1['janela_personagem']
    ui_img('uiwin', jp['linhas'], jp['cores'])
    xp = f1['xp_cheia_janela']
    ui_img('uixp', xp['linhas'], xp['cores'])
    bt = f1['botao_mais']
    for i, e in enumerate(['normal', 'mouse', 'apertado', 'desligado']):
        ui_img('uibtn%d' % i, bt['estados'][e], bt['cores'])
    ic = f1['icones_atributo']
    for i, e in enumerate(['forca', 'destreza', 'vitalidade', 'energia']):
        ui_img('uiicon%d' % i, ic['icones'][e], ic['cores'])
    # retrato: cada camada do heroi de frente (S, quadro 0)
    for cod, peca in CAMADAS:
        fr = dir_frames(peca or 'cabelo_homem')
        if peca is None:
            fr = clip_top(fr, NQ, 13)
        ui_img('uihero_%s' % cod.lower(), fr[0][0])
    # barra de XP da tela: pontas, meio (esticado) e o preenchimento
    bx = f1['barra_xp_tela']
    for lab, k in (('uixpl', 'esquerda'), ('uixpm', 'meio'), ('uixpr', 'direita'),
                   ('uixpf', 'preenchimento'), ('uixpp', 'preenchimento_ponta')):
        ui_img(lab, bx[k], bx['cores'])
    # efeito de subir de nivel: quadros do mundo (paleta, brilho)
    ef = f1['efeito_subir_nivel']
    ew, eh = ef['quadro']
    eax, eay = ef['ancora']
    w('// efeito de subir de nivel: 8 quadros de %d x %d' % (ew, eh))
    elabs = [emit(check(q, ew, eh, 'efeito'), eax, eay) for q in ef['quadros']]
    w('    .p2align 3')
    w('    .globl pixlvl')
    w('pixlvl: .quad ' + ', '.join(elabs))
    UA.append('.equ PX_LVL_N, %d' % len(elabs))
    w('    .p2align 3')
    w('    .globl uibtns, uiicons, uiheros')
    w('uibtns:  .quad uibtn0, uibtn1, uibtn2, uibtn3')
    w('uiicons: .quad uiicon0, uiicon1, uiicon2, uiicon3')
    w('uiheros: .quad ' + ', '.join('uihero_%s' % c.lower() for c, _ in CAMADAS))
    ar = jp['areas']
    for n, (x, y, wd, ht) in ar.items():
        UA += ['.equ UA_%s_X, %d' % (n.upper(), x), '.equ UA_%s_Y, %d' % (n.upper(), y),
               '.equ UA_%s_W, %d' % (n.upper(), wd), '.equ UA_%s_H, %d' % (n.upper(), ht)]
    ATR = ['forca', 'destreza', 'vitalidade', 'energia']
    passo = ar['destreza_mais'][1] - ar['forca_mais'][1]
    for k in ('icone', 'nome', 'valor', 'mais'):
        ys = [ar['%s_%s' % (a, k)][1] for a in ATR]
        assert all(ys[i + 1] - ys[i] == passo for i in range(3)), k
    UA.append('.equ UA_PASSO, %d          // de uma linha de atributo para a outra' % passo)
    UA.append('.equ UI_WIN_W, %d' % jp['quadro'][0])
    UA.append('.equ UI_WIN_H, %d' % jp['quadro'][1])

open(os.path.join(out, 'pixel.S'), 'w').write('\n'.join(S) + '\n')

H = ['// pixel.h - camadas do heroi e objetos em pixel art (GERADO por',
     '// arte/pixel.py: nao edite)']
for cod, _ in CAMADAS:
    H.append('.equ %s, %d' % (cod, num[cod]))
H.append('.equ PL_N, %d' % len(CAMADAS))
for i, o in enumerate(OBJ):
    H.append('.equ %s, %d' % (o[0], i))
H.append('.equ PX_K, %d' % K)
for k, v in EN.items():
    H.append('.equ %s, %d' % (k, v))
H += UA
for i, (cod, _) in enumerate(TILES):
    H.append('.equ %s, %d' % (cod, i))
open(os.path.join(out, 'pixel.h'), 'w').write('\n'.join(H) + '\n')

P = ['// pixpal.inc - paleta-mestra do designer, indices %d..%d' % (PAL0, PAL0 + len(cores) - 1),
     '// (GERADO por arte/pixel.py; cores de brilho com alfa 0xFE)']
for i in range(0, len(cores), 4):
    P.append('    .word ' + ', '.join('0x%08X' % c for c in cores[i:i + 4]) +
             '  // %d-%d' % (PAL0 + i, PAL0 + min(i + 3, len(cores) - 1)))
open(os.path.join(out, 'pixpal.inc'), 'w').write('\n'.join(P) + '\n')
print('ok: %d quadros, %d cores' % (lab_n[0], len(cores)))
