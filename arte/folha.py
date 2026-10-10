#!/usr/bin/env python3
# =====================================================================
#  folha.py - desenha os sprites do ermo.S em PNG, ampliados, para o
#  designer (pixels exatos, fundo transparente, a celula do chao embaixo).
#  Uso: python3 arte/folha.py ermo.S pasta_de_saida
# =====================================================================
import re, sys, os
from PIL import Image, ImageDraw, ImageFont

src = open(sys.argv[1]).read()
out = sys.argv[2]
os.makedirs(out, exist_ok=True)

def words(label):
    i = src.index('\n' + label + ':')
    vals = []
    for line in src[i + 1:].splitlines()[1:]:
        if line.strip().startswith('//'):
            continue
        line = line.split('//')[0].strip()
        if not line:
            if vals:
                break
            continue
        if not line.startswith('.word'):
            break
        vals += [int(t.strip(), 0) for t in line[5:].split(',') if t.strip()]
    return vals

pal = words('palette')
roof = words('roofc')                   # 4 cores de familia x (claro, escuro)

# sprites: cada "// N: nome" seguido de .byte (largura, altura, ancora, 0, pixels)
i = src.index('\nsprites:')
spr = {}
for m in re.finditer(r'// (\d+): ([^\n]*)\n(?://[^\n]*\n)*((?:    \.byte [^\n]*\n)+)', src[i:]):
    n = int(m.group(1))
    nums = [int(x) for x in re.findall(r'-?\d+', ' '.join(l.split('.byte')[1] for l in m.group(3).splitlines()))]
    w, h, ax = nums[0], nums[1], nums[2]
    spr[n] = (m.group(2).strip(), w, h, ax, nums[4:4 + w * h])
    if n >= 90:
        break

def color(c, var, row):
    if c in (8, 9):
        return roof[(var & 3) * 2 + (c - 8)]
    if c == 15:                          # janela acesa (bit da linha na variante)
        return 0xFFFFE38A if (var >> (row & 7)) & 1 else 0xFF3C4656
    return pal[c]

def render(n, var=0, z=8):
    name, w, h, ax, px = spr[n]
    im = Image.new('RGBA', (w * z, h * z), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y in range(h):
        for x in range(w):
            c = px[y * w + x]
            if c:
                v = color(c, var, y)
                d.rectangle([x * z, y * z, x * z + z - 1, y * z + z - 1],
                            fill=((v >> 16) & 255, (v >> 8) & 255, v & 255, 255))
    return im

# estruturas: (sprite, nome no arquivo, celulas (largura do bloco), variantes)
EST = [(5, 'fogueira_1', 1, [0]), (6, 'fogueira_2', 1, [0]), (20, 'bau', 1, [0]),
       (21, 'abrigo', 2, [0]), (45, 'cerca_poste', 1, [0]), (46, 'cerca_trilho_u', 1, [0]),
       (47, 'cerca_trilho_v', 1, [0]), (48, 'cerca_dois', 1, [0]), (49, 'portao_u', 1, [0]),
       (50, 'portao_v', 1, [0]), (70, 'barraco', 2, [0, 1, 2, 3]), (72, 'casa', 2, [0, 1, 2, 3]),
       (78, 'fornalha', 1, [0]), (85, 'lampiao', 1, [0]), (17, 'tocha', 1, [0]),
       (12, 'pilha_toras', 1, [0]), (13, 'pilha_pedras', 1, [0]), (14, 'pilha_frutas', 1, [0])]

Z = 8
CELL = 12                                # celula do chao na escala 1 dos sprites: 12 x 6
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 18)
except Exception:
    font = ImageFont.load_default()

cards = []
for n, fname, cells, vars_ in EST:
    name, w, h, ax, _ = spr[n]
    for var in vars_:
        im = render(n, var, Z)
        suf = '' if len(vars_) == 1 else '_cor%d' % var
        im.save(os.path.join(out, '%s%s.png' % (fname, suf)))
    # cartao: sprite sobre o losango do chao (a ancora em cima do ponto do objeto)
    dw = CELL * cells * Z
    dh = CELL // 2 * cells * Z
    W = max(w * Z, dw, 300) + 60
    H = h * Z + dh // 2 + 90
    card = Image.new('RGBA', (W, H), (40, 46, 38, 255))
    d = ImageDraw.Draw(card)
    bx = W // 2                          # ponto do objeto na tela
    by = 30 + h * Z
    d.polygon([(bx - dw // 2, by), (bx, by - dh // 2), (bx + dw // 2, by), (bx, by + dh // 2)],
              fill=(112, 164, 76, 255), outline=(150, 200, 110, 255))
    sx = bx - ax * Z - Z // 2
    for k, var in enumerate(vars_[:1]):
        card.alpha_composite(render(n, var, Z), (sx, by - h * Z))
    d.text((10, H - 50), '%s  (sprite %d)' % (fname, n), fill=(233, 228, 212), font=font)
    d.text((10, H - 26), '%d x %d px, ancora x=%d, %d x %d celula(s)' % (w, h, ax, cells, cells),
           fill=(183, 191, 169), font=font)
    cards.append(card)

# folha com todos os cartoes
cols = 4
rows = (len(cards) + cols - 1) // cols
cw = max(c.width for c in cards) + 16
chh = max(c.height for c in cards) + 16
sheet = Image.new('RGBA', (cols * cw + 16, rows * chh + 16), (27, 33, 24, 255))
for k, c in enumerate(cards):
    sheet.alpha_composite(c, (16 + (k % cols) * cw, 16 + (k // cols) * chh))
sheet.save(os.path.join(out, 'folha_estruturas.png'))

# paleta usada (indice, cor)
used = sorted(set(c for n, *_ in EST for c in spr[n][4] if c))
sw = Image.new('RGBA', (8 * 150, ((len(used) + 4 + 7) // 8) * 60 + 10), (27, 33, 24, 255))
d = ImageDraw.Draw(sw)
items = [(c, pal[c]) for c in used if c not in (8, 9, 15)]
items += [('fam%d' % k, roof[k * 2]) for k in range(4)]
for k, (c, v) in enumerate(items):
    x, y = 10 + (k % 8) * 150, 10 + (k // 8) * 60
    d.rectangle([x, y, x + 40, y + 40], fill=((v >> 16) & 255, (v >> 8) & 255, v & 255))
    d.text((x + 48, y + 2), str(c), fill=(233, 228, 212), font=font)
    d.text((x + 48, y + 22), '#%06X' % (v & 0xFFFFFF), fill=(183, 191, 169), font=font)
sw.save(os.path.join(out, 'paleta.png'))
print('ok', len(cards), 'estruturas')
