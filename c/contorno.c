// =====================================================================
//  contorno.c - contorno dourado no alvo (fase 3, etapa 3.11)
//
//  O bicho sob o mouse, ou o que voce esta atacando segurando o botao,
//  ganha uma borda dourada de 1 pixel do desenho em volta: assim voce
//  sabe quem esta selecionando. Vale para o lobo e o urso do designer
//  (os outros bichos ainda tem o desenho antigo); depois vale para os
//  NPCs das cidades.
// =====================================================================
#include "ermo.h"

extern uint32_t fb[] ASM(fb);
extern uint16_t zb[] ASM(zb);
extern const uint8_t *pixwolf[] ASM(pixwolf);
extern const uint8_t *pixbear[] ASM(pixbear);

#define OURO     0xFFFFD34Au            // dourado (alfa FF: escurece de noite)

static int alvo_atual(void)
{
    int a = G_I32(G_HOVANIM);
    if (a >= 0)
        return a;
    return G_I32(G_ATKHOLD) - 1;
}

static int opaco(const uint8_t *px, int w, int h, int x, int y)
{
    return x >= 0 && y >= 0 && x < w && y < h && px[y * w + x] != 0;
}

// chamado pelo animals_draw logo depois de desenhar cada lobo ou urso
void target_outline(int animal, int tipo, int x, int y, int prof, int quadro)
{
    if (animal != alvo_atual())
        return;
    const uint8_t *spr = (tipo == A_BEAR ? pixbear : pixwolf)[quadro];
    int s = G_I32(G_Z256) >> 10;
    if (s < 1)
        s = 1;
    if (spr[5] == 2) {                  // densidade 2 (estilo 2)
        if (s & 1)
            spr += 16 * (spr[6] | spr[7] << 8);
        else
            s >>= 1;
    }
    int w = spr[0], h = spr[1], ax = spr[2], ay = spr[3], k = spr[4];
    const uint8_t *px = spr + 8;
    int esq = x - ax * s, topo = y - ay * s;
    for (int yy = -1; yy <= h; yy++) {
        int p = prof + (yy > ay ? (yy - ay) * k : 0);
        for (int xx = -1; xx <= w; xx++) {
            if (opaco(px, w, h, xx, yy))
                continue;
            if (!opaco(px, w, h, xx - 1, yy) && !opaco(px, w, h, xx + 1, yy) &&
                !opaco(px, w, h, xx, yy - 1) && !opaco(px, w, h, xx, yy + 1))
                continue;
            for (int dy = 0; dy < s; dy++) {
                int sy = topo + yy * s + dy;
                if (sy < 0 || sy >= SCRH)
                    continue;
                for (int dx = 0; dx < s; dx++) {
                    int sx = esq + xx * s + dx;
                    if (sx < 0 || sx >= SCRW)
                        continue;
                    int i = sy * SCRW + sx;
                    if ((int)zb[i] - p > 16)    // algo na frente
                        continue;
                    fb[i] = OURO;
                }
            }
        }
    }
}
