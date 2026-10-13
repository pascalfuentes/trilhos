// =====================================================================
//  magia.c - primeira magia e ataque por tipo de arma (etapas 3.9, 3.10)
//
//  Cajado (fabrica: 4 madeira e 2 couro; tecla 9): com ele na mao, o
//  clique atira uma bola de energia (5 de mana) no ponto do mouse, ou
//  no bicho sob o mouse. Ela voa como a flecha (mesmo vetor arrows, com
//  o tipo 1 no byte 28), nunca erra e o dano e 5 +3% por ponto de
//  Energia acima de 10 (player_hit, distancia 2). Sem mana: "Sem mana".
//
//  Ataque por arma (3.9): o tempo entre golpes depende do que esta na
//  mao: espada 0,4 s, maos 0,45 s, machado 0,55 s, picareta 0,6 s, o
//  resto 0,5 s. As animacoes de cada tipo vem com o pedido 3.0.
// =====================================================================
#include "ermo.h"

extern uint8_t arrows[] ASM(arrows);
extern uint8_t animals[] ASM(animals);
extern void set_msg(const char *texto) ASM(set_msg);
extern int mp_max(void) ASM(mp_max);
extern int elev_at(float u, float v) ASM(elev_at);
extern void blit(const void *spr, int x, int y, int escala, int prof, int var) ASM(blit);
extern const void *pixorb[] ASM(pixorb);

#define AR_U    0
#define AR_V    4
#define AR_DU   8
#define AR_DV   12
#define AR_LIFE 16
#define AR_E    20
#define AR_DANO 24
#define AR_TIPO 28                      // 0 flecha, 1 magia
#define CUSTO   5                       // mana por bola

// tempo entre golpes (quadros) pelo que esta na mao
int weapon_cooldown(void)
{
    int mao = G_I32(G_HAND) - 1;
    if (mao == IT_SWORD) return 24;
    if (mao == -1) return 27;
    if (mao == IT_AXE || mao == IT_IAXE) return 33;
    if (mao == IT_PICK || mao == IT_IPICK) return 36;
    return 30;
}

// clique com o cajado na mao -> 1 se tratou (atirou ou avisou)
int staff_click(void)
{
    if (G_I32(G_HAND) != IT_STAFF + 1)
        return 0;
    if (G_I32(G_ATKCD))
        return 1;
    float mana = G_F32(G_MP) * mp_max() / 100.0f;
    if (mana < CUSTO) {
        set_msg("Sem mana (enche sozinha)");
        return 1;
    }
    float tu, tv;
    int alvo = G_I32(G_HOVANIM);
    if (alvo >= 0) {                    // no bicho sob o mouse
        tu = *(float *)(animals + alvo * 32);
        tv = *(float *)(animals + alvo * 32 + 4);
    } else if (G_I32(G_HOVOK)) {
        tu = G_I32(G_HOVU) / 64.0f;
        tv = G_I32(G_HOVV) / 64.0f;
    } else {
        return 1;
    }
    float du = tu - G_F32(G_PU), dv = tv - G_F32(G_PV);
    float d = __builtin_sqrtf(du * du + dv * dv);
    if (d < 0.25f)
        return 1;
    for (int i = 0; i < MAXARROW; i++) {
        uint8_t *a = arrows + i * 32;
        if (*(int32_t *)(a + AR_LIFE))
            continue;
        *(float *)(a + AR_U) = G_F32(G_PU);
        *(float *)(a + AR_V) = G_F32(G_PV);
        *(float *)(a + AR_DU) = du / d * 0.35f;
        *(float *)(a + AR_DV) = dv / d * 0.35f;
        *(int32_t *)(a + AR_LIFE) = 50;
        *(int32_t *)(a + AR_E) = G_I32(G_PE) + 72;
        *(int32_t *)(a + AR_DANO) = 5;
        *(int32_t *)(a + AR_TIPO) = 1;
        G_F32(G_MP) -= CUSTO * 100.0f / mp_max();
        G_I32(G_ATKCD) = 36;
        return 1;
    }
    return 1;
}

// as bolas de magia no mundo (o arrows_draw desenha so as flechas)
void magic_draw(void)
{
    int s = G_I32(G_Z256) >> 10;
    if (s < 1)
        s = 1;
    int z = G_I32(G_Z256);
    for (int i = 0; i < MAXARROW; i++) {
        uint8_t *a = arrows + i * 32;
        if (!*(int32_t *)(a + AR_LIFE) || *(int32_t *)(a + AR_TIPO) != 1)
            continue;
        float u = *(float *)(a + AR_U), v = *(float *)(a + AR_V);
        int e = *(int32_t *)(a + AR_E);
        int X = (int)((u - v) * 64.0f);
        int p = (int)((u + v) * 64.0f);
        int x = (((X - G_I32(G_CX)) * z) >> 12) + 640;
        int y = ((((p >> 1) - e) - G_I32(G_CY)) * z >> 12) + 360;
        blit(pixorb[(G_I32(G_FRAME) >> 2) & 1], x, y, s, p + 64, 0);
    }
}

// ---------------------------------------------------------------------
//  Teste (--shot): com o cajado, uma bola num cervo a 4 celulas
// ---------------------------------------------------------------------
#include <stdio.h>
#include <unistd.h>

extern int animal_spawn(int tipo, float u, float v) ASM(animal_spawn);
extern void arrows_update(void) ASM(arrows_update);

void magic_selftest(void)
{
    int mao0 = G_I32(G_HAND), inv0 = G_I32(G_INV + 4 * IT_STAFF);
    float mp0 = G_F32(G_MP);
    G_I32(G_INV + 4 * IT_STAFF) = 1;
    G_I32(G_HAND) = IT_STAFF + 1;
    G_F32(G_MP) = 100.0f;
    G_I32(G_ATKCD) = 0;
    float u0 = G_F32(G_PU), v0 = G_F32(G_PV);
    int c = animal_spawn(A_DEER, u0 + 4.0f, v0);
    int acertou = 0, gastou = 0, semmana = 0;
    if (c >= 0) {
        uint8_t *a = animals + c * 32;
        int vida = *(uint16_t *)(a + 28);
        G_I32(G_HOVANIM) = c;
        staff_click();
        gastou = (int)(100.0f - G_F32(G_MP) + 0.5f);
        for (int i = 0; i < 40; i++) {
            *(float *)(a + 0) = u0 + 4.0f;
            *(float *)(a + 4) = v0;
            arrows_update();
        }
        acertou = a[16] == 255 || *(uint16_t *)(a + 28) < vida;
        a[16] = 255;
        G_F32(G_MP) = 1.0f;             // quase sem mana: nao atira
        G_I32(G_ATKCD) = 0;
        int livres0 = 0, livres1 = 0;
        for (int i = 0; i < MAXARROW; i++) livres0 += !*(int32_t *)(arrows + i * 32 + AR_LIFE);
        G_I32(G_HOVANIM) = -1;
        G_I32(G_HOVOK) = 1;
        G_I32(G_HOVU) = (int)((u0 + 3) * 64);
        G_I32(G_HOVV) = (int)(v0 * 64);
        staff_click();
        for (int i = 0; i < MAXARROW; i++) livres1 += !*(int32_t *)(arrows + i * 32 + AR_LIFE);
        semmana = livres0 == livres1;
    }
    G_I32(G_HAND) = IT_SWORD + 1;
    int cd_espada = weapon_cooldown();
    G_I32(G_HAND) = 0;
    int cd_maos = weapon_cooldown();
    char buf[200];
    int n = snprintf(buf, sizeof buf,
                     "magia: cajado num cervo -> acertou=%d gastou %d%% da mana | sem mana nao atira=%d | "
                     "golpe a cada (quadros): espada %d, maos %d\n",
                     acertou, gastou, semmana, cd_espada, cd_maos);
    if (write(1, buf, n) < 0) {}
    G_I32(G_HAND) = mao0;
    G_I32(G_INV + 4 * IT_STAFF) = inv0;
    G_F32(G_MP) = mp0;
    G_I32(G_ATKCD) = 0;
    G_I32(G_MSGT) = 0;
}
