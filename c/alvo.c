// =====================================================================
//  alvo.c - qual bicho esta sob o mouse (zona de clique pelo desenho)
//
//  Antes valia so o ponto do chao sob o mouse, a ate 1 celula do bicho:
//  era preciso clicar bem nos pes. Agora vale o retangulo do desenho na
//  tela (mais 4 px de folga em volta): clicar no corpo, na cabeca ou no
//  rabo pega o bicho. Se dois se sobrepoem, vale o da frente.
// =====================================================================
#include "ermo.h"

extern uint8_t animals[] ASM(animals);
extern uint8_t vis[] ASM(vis);
extern int elev_at(float u, float v) ASM(elev_at);

#define AN_U    0
#define AN_V    4
#define AN_TYPE 16
#define FOLGA   4                       // px de folga em volta do desenho

// tamanho do desenho (largura, altura, ancora x, ancora y) por tipo:
// coelho, cervo, cabra, lobo e urso do designer, caranguejo
static const int16_t caixa[6][4] = {
    {16, 14, 8, 13}, {24, 24, 12, 23}, {20, 20, 10, 19},
    {48, 40, 24, 37}, {64, 48, 32, 45}, {16, 10, 8, 9},
};

// o mesmo calculo do proj (sobrevivencia.S): celula -> tela
static void tela(float u, float v, int e, int *x, int *y, int *prof)
{
    int X = (int)((u - v) * 64.0f);
    int p = (int)((u + v) * 64.0f);
    int Y = (p >> 1) - e;
    int z = G_I32(G_Z256);
    *x = (((X - G_I32(G_CX)) * z) >> 12) + 640;
    *y = (((Y - G_I32(G_CY)) * z) >> 12) + 360;
    *prof = p;
}

// -> o bicho sob o mouse (-1 nenhum)
int animal_pick(void)
{
    int mx = (int)G_F32(G_MX), my = (int)G_F32(G_MY);
    int s = G_I32(G_Z256) >> 10;
    if (s < 1)
        s = 1;
    int melhor = -1, melhor_prof = -1 << 30;
    for (int i = 0; i < MAXANIM; i++) {
        uint8_t *a = animals + i * 32;
        int t = a[AN_TYPE];
        if (t > 5)
            continue;
        float u = *(float *)(a + AN_U), v = *(float *)(a + AN_V);
        int cu = (int)u, cv = (int)v;
        if (cu < 0 || cv < 0 || cu >= MAPN || cv >= MAPN || vis[cu + cv * MAPN] < VIS_MIN)
            continue;
        int e = elev_at(u, v);
        if (e < G_I32(G_FLOOD))
            e = G_I32(G_FLOOD);
        int x, y, prof;
        tela(u, v, e, &x, &y, &prof);
        int esq = x - caixa[t][2] * s - FOLGA, dir = esq + caixa[t][0] * s + 2 * FOLGA;
        int cima = y - caixa[t][3] * s - FOLGA, baixo = cima + caixa[t][1] * s + 2 * FOLGA;
        if (mx < esq || mx >= dir || my < cima || my >= baixo)
            continue;
        if (prof > melhor_prof) {
            melhor = i;
            melhor_prof = prof;
        }
    }
    return melhor;
}

// ---------------------------------------------------------------------
//  Teste (--shot): um lobo do lado; o mouse no lombo dele (bem acima dos
//  pes) tem que pegar o lobo
// ---------------------------------------------------------------------
#include <stdio.h>
#include <unistd.h>

extern int animal_spawn(int tipo, float u, float v) ASM(animal_spawn);

void pick_selftest(void)
{
    float u = G_F32(G_PU) + 2.0f, v = G_F32(G_PV) - 2.0f;
    int c = animal_spawn(A_WOLF, u, v);
    int pegou_corpo = -2, pegou_longe = -2;
    if (c >= 0) {
        int e = elev_at(u, v);
        if (e < G_I32(G_FLOOD))
            e = G_I32(G_FLOOD);
        int x, y, prof, s = G_I32(G_Z256) >> 10;
        if (s < 1)
            s = 1;
        tela(u, v, e, &x, &y, &prof);
        G_F32(G_MX) = (float)(x + 14 * s);     // no lombo, 20 px de arte acima
        G_F32(G_MY) = (float)(y - 20 * s);
        pegou_corpo = animal_pick() == c;
        G_F32(G_MX) = (float)(x + 60 * s);     // longe dele
        pegou_longe = animal_pick() == c;
        animals[c * 32 + AN_TYPE] = 255;
    }
    char buf[120];
    int n = snprintf(buf, sizeof buf, "alvo: mouse no lombo do lobo pega=%d, longe pega=%d\n",
                     pegou_corpo, pegou_longe);
    if (write(1, buf, n) < 0) {}
}
