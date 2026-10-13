// =====================================================================
//  movimento.c - clicar para andar, como no Diablo (fase 3, etapa 3.1)
//
//  - Clique esquerdo no chao (sem nada para coletar, atacar ou pescar
//    ali, e sem enxada ou sementes na mao): o personagem anda ate o
//    ponto. (Clicar num bicho longe e ir ate ele: etapa 3.2.) Segurando o botao, o destino
//    acompanha o mouse.
//  - WASD continua funcionando e cancela o clique. Shift corre.
//  - Para ao chegar (a 0,15 celula) ou se empacar uns 0,75 s (agua,
//    pedra, cerca no caminho).
//
//  O assembly (sobrevivencia.S) chama moveto_click no clique e, a cada
//  quadro sem tecla de direcao, moveto_dir: se ela devolve 1, a direcao
//  esta em G_MTDU/G_MTDV e o resto do movimento (velocidade, correr,
//  agua, colisao) continua igual.
// =====================================================================
#include "ermo.h"

#define CHEGOU      0.15f
#define EMPACOU     45                  // quadros sem chegar mais perto

static void alvo_do_mouse(void)
{
    G_F32(G_MTU) = G_I32(G_HOVU) / 64.0f;
    G_F32(G_MTV) = G_I32(G_HOVV) / 64.0f;
}

// clique no chao: comeca a andar ate ali (nao em cima de bicho ou
// fogueira, e nao com enxada ou sementes na mao, que usam o chao)
void moveto_click(void)
{
    if (!G_I32(G_HOVOK) || G_I32(G_HOVANIM) >= 0 || G_I32(G_HOVFIRE) >= 0)
        return;
    int mao = G_I32(G_HAND) - 1;
    if (mao == IT_HOE || mao == IT_SEED)
        return;
    alvo_do_mouse();
    G_I32(G_MOVETO) = 1;
    G_F32(G_MTDIST) = 1e9f;
}

// -> 1 se esta indo para um ponto (direcao em G_MTDU/G_MTDV)
int moveto_dir(void)
{
    int st = G_I32(G_MOVETO);
    if (!st)
        return 0;
    if (G_I32(G_SLEEP) || G_I32(G_DEAD)) {
        G_I32(G_MOVETO) = 0;
        return 0;
    }
    // segurando o botao no chao: o destino segue o mouse
    if (G_I32(G_LMB) && G_I32(G_HOVOK) && G_I32(G_HOVOBJ) < 0)
        alvo_do_mouse();

    float du = G_F32(G_MTU) - G_F32(G_PU);
    float dv = G_F32(G_MTV) - G_F32(G_PV);
    float d = __builtin_sqrtf(du * du + dv * dv);
    if (d < CHEGOU) {
        G_I32(G_MOVETO) = 0;
        return 0;
    }
    if (d >= G_F32(G_MTDIST) - 0.001f) {   // nao chegou mais perto
        if (++st > EMPACOU) {
            G_I32(G_MOVETO) = 0;
            return 0;
        }
    } else {
        st = 1;
    }
    G_I32(G_MOVETO) = st;
    G_F32(G_MTDIST) = d;
    G_F32(G_MTDU) = du;
    G_F32(G_MTDV) = dv;
    return 1;
}

// ---------------------------------------------------------------------
//  Teste (--shot): clica 3 celulas a frente e deixa o tempo correr
// ---------------------------------------------------------------------
#include <stdio.h>
#include <unistd.h>

extern void surv_update(void) ASM(surv_update);

void moveto_selftest(void)
{
    float u0 = G_F32(G_PU), v0 = G_F32(G_PV);
    G_I32(G_TESTKEYS) = 0;
    G_I32(G_LMB) = 0;
    G_I32(G_HOVOK) = 1;
    G_I32(G_HOVANIM) = -1;
    G_I32(G_HOVFIRE) = -1;
    G_I32(G_HOVU) = (int)((u0 + 3.0f) * 64.0f);
    G_I32(G_HOVV) = (int)(v0 * 64.0f);
    moveto_click();
    int quadros = 0;
    while (G_I32(G_MOVETO) && quadros < 600) {
        surv_update();
        quadros++;
    }
    float du = G_F32(G_PU) - u0, dv = G_F32(G_PV) - v0;
    char buf[160];
    int n = snprintf(buf, sizeof buf,
                     "movimento: clique 3 celulas a frente -> andou %.2f em u, %.2f em v, "
                     "em %d quadros (parou=%d)\n",
                     du, dv, quadros, G_I32(G_MOVETO) == 0);
    if (write(1, buf, n) < 0) {}
}
