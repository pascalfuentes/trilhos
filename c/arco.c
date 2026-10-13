// =====================================================================
//  arco.c - puxar a corda do arco (fase 3, etapa 3.8)
//
//  Com o arco na mao: apertar o botao comeca a puxar a corda, soltar
//  atira. Um clique rapido atira como antes (dano 4, ~18 celulas);
//  segurando 1 s a corda fica toda puxada: dano 7, a flecha vai 40% mais
//  rapida e mais longe. Uma barrinha em cima do heroi mostra o quanto ja
//  puxou (dourada quando cheia). A Destreza e o acerto entram depois, no
//  player_hit (c/combate.c).
// =====================================================================
#include "ermo.h"

extern uint8_t arrows[] ASM(arrows);
extern void set_msg(const char *texto) ASM(set_msg);
extern void calc_stats(void) ASM(calc_stats);
extern void setcolor(int r, int g, int b, int a) ASM(setcolor);
extern void fillrect(int x, int y, int w, int h) ASM(fillrect);
extern const char m_noarrow[] ASM(m_noarrow);

#define AR_U     0
#define AR_V     4
#define AR_DU    8
#define AR_DV    12
#define AR_LIFE  16
#define AR_E     20
#define AR_DANO  24                     // dano desta flecha (0 = 4, antigas)
#define CHEIA    60                     // quadros para puxar tudo (1 s)

static int puxando;                     // quadros puxando (0 = nao)

// apertou o botao com o arco na mao
void bow_press(void)
{
    if (G_I32(G_ATKCD))
        return;
    if (G_I32(G_INV + 4 * IT_ARROW) == 0) {
        set_msg(m_noarrow);
        return;
    }
    puxando = 1;
}

// a cada quadro (attack_hold_tick): a corda vai sendo puxada
void bow_tick(void)
{
    if (puxando && puxando < CHEIA)
        puxando++;
}

// soltou o botao: atira com a forca de quanto puxou
void bow_release(void)
{
    if (!puxando)
        return;
    float forca = (float)(puxando - 1) / (CHEIA - 1);   // 0 .. 1
    puxando = 0;
    if (!G_I32(G_HOVOK) || G_I32(G_INV + 4 * IT_ARROW) == 0)
        return;
    float du = G_I32(G_HOVU) / 64.0f - G_F32(G_PU);
    float dv = G_I32(G_HOVV) / 64.0f - G_F32(G_PV);
    float d = __builtin_sqrtf(du * du + dv * dv);
    if (d < 0.25f)
        return;
    for (int i = 0; i < MAXARROW; i++) {
        uint8_t *a = arrows + i * 32;
        if (*(int32_t *)(a + AR_LIFE))
            continue;
        float vel = 0.45f * (1.0f + 0.4f * forca);
        *(float *)(a + AR_U) = G_F32(G_PU);
        *(float *)(a + AR_V) = G_F32(G_PV);
        *(float *)(a + AR_DU) = du / d * vel;
        *(float *)(a + AR_DV) = dv / d * vel;
        *(int32_t *)(a + AR_LIFE) = 40 + (int)(10 * forca);
        *(int32_t *)(a + AR_E) = G_I32(G_PE) + 64;      // na altura do peito
        *(int32_t *)(a + AR_DANO) = 4 + (int)(3 * forca + 0.5f);
        G_I32(G_INV + 4 * IT_ARROW) -= 1;
        G_I32(G_ATKCD) = 30;
        calc_stats();
        return;
    }
}

// barrinha em cima do heroi enquanto puxa (interface, 640 x 360)
void bow_draw(void)
{
    if (!puxando)
        return;
    int s = G_I32(G_Z256) >> 10;
    if (s < 1)
        s = 1;
    int x = 320 - 12, y = 180 - 26 * s;          // o heroi fica no meio da tela
    int w = 24 * puxando / CHEIA;
    setcolor(20, 16, 12, 200);
    fillrect(x - 1, y - 1, 26, 5);
    if (puxando >= CHEIA)
        setcolor(255, 210, 80, 255);
    else
        setcolor(200, 200, 210, 255);
    fillrect(x, y, w, 3);
}

// teste
int bow_selftest(int quadros)
{
    G_I32(G_ATKCD) = 0;
    bow_press();
    for (int i = 0; i < quadros; i++)
        bow_tick();
    int antes[MAXARROW];
    for (int i = 0; i < MAXARROW; i++)
        antes[i] = *(int32_t *)(arrows + i * 32 + AR_LIFE);
    bow_release();
    for (int i = 0; i < MAXARROW; i++) {
        uint8_t *a = arrows + i * 32;
        if (!antes[i] && *(int32_t *)(a + AR_LIFE)) {
            int dano = *(int32_t *)(a + AR_DANO);
            *(int32_t *)(a + AR_LIFE) = 0;      // some
            return dano;
        }
    }
    return 0;
}
