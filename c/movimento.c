// =====================================================================
//  movimento.c - clicar para andar, como no Diablo (fase 3, etapa 3.1)
//
//  - Clique esquerdo no chao (sem nada para coletar, atacar ou pescar
//    ali, e sem enxada ou sementes na mao): o personagem anda ate o
//    ponto.
//  - Clique num bicho longe (etapa 3.2): vai ate ele, seguindo se ele
//    andar, e ao chegar a 1,6 celula da o golpe (melee_attack, ate 2
//    celulas). Desiste se ele sumir ou se nao conseguir chegar perto.
//    Com o arco ou a vara na mao, o clique atira/pesca de onde esta.
//  - Segurar o botao num bicho (etapa 3.3): continua atacando, golpe
//    atras de golpe (a espera entre golpes e a do melee_attack), indo
//    atras dele se ele se afastar, ate ele morrer ou voce soltar. Segurando o botao, o destino
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
#define ALCANCE     1.6f                // perto o bastante para o golpe
#define EMPACOU     45                  // quadros sem chegar mais perto

// bichos (animais.S): 32 bytes cada; u, v em float; tipo 255 = vaga
extern uint8_t animals[] ASM(animals);
#define AN_U     0
#define AN_V     4
#define AN_TYPE  16
extern int melee_attack(int animal) ASM(melee_attack);

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
    G_I32(G_MTANIM) = -1;
    G_I32(G_MOVETO) = 1;
    G_F32(G_MTDIST) = 1e9f;
}

// clique num bicho fora do alcance: vai ate ele e ataca
void moveto_enemy(int animal)
{
    if (animal < 0)
        return;
    G_I32(G_MTANIM) = animal;
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
    int alvo = G_I32(G_MTANIM);
    if (alvo >= 0) {                    // indo atras de um bicho
        uint8_t *a = animals + alvo * 32;
        if (a[AN_TYPE] == 255) {        // sumiu ou morreu
            G_I32(G_MOVETO) = 0;
            G_I32(G_MTANIM) = -1;
            return 0;
        }
        G_F32(G_MTU) = *(float *)(a + AN_U);
        G_F32(G_MTV) = *(float *)(a + AN_V);
    } else if (G_I32(G_LMB) && G_I32(G_HOVOK) && G_I32(G_HOVOBJ) < 0) {
        alvo_do_mouse();                // segurando no chao: segue o mouse
    }

    float du = G_F32(G_MTU) - G_F32(G_PU);
    float dv = G_F32(G_MTV) - G_F32(G_PV);
    float d = __builtin_sqrtf(du * du + dv * dv);
    if (alvo >= 0 && d < ALCANCE) {     // chegou no bicho: golpe
        G_I32(G_MOVETO) = 0;
        G_I32(G_MTANIM) = -1;
        melee_attack(alvo);
        return 0;
    }
    if (d < CHEGOU) {
        G_I32(G_MOVETO) = 0;
        return 0;
    }
    if (d >= G_F32(G_MTDIST) - 0.001f) {   // nao chegou mais perto
        if (++st > EMPACOU) {
            G_I32(G_MOVETO) = 0;
            G_I32(G_MTANIM) = -1;
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

// apertou o botao num bicho: segura o ataque nele
void attack_hold(int animal)
{
    G_I32(G_ATKHOLD) = animal + 1;
}

// clique sem Shift: o ataque volta a ir atras
void attack_moving(void)
{
    G_I32(G_ATKSTILL) = 0;
}

// soltou o botao
void attack_release(void)
{
    G_I32(G_ATKHOLD) = 0;
    G_I32(G_ATKSTILL) = 0;
}

// a cada quadro: segurando num bicho, golpeia de novo ou vai atras dele
extern void bow_tick(void);

void attack_hold_tick(void)
{
    bow_tick();                         // arco: puxando a corda (c/arco.c)
    int alvo = G_I32(G_ATKHOLD) - 1;
    if (alvo < 0)
        return;
    uint8_t *a = animals + alvo * 32;
    if (a[AN_TYPE] == 255 || G_I32(G_DEAD) || G_I32(G_SLEEP)) {
        G_I32(G_ATKHOLD) = 0;
        return;
    }
    if (G_I32(G_MOVETO))                // ainda indo ate ele
        return;
    float du = *(float *)(a + AN_U) - G_F32(G_PU);
    float dv = *(float *)(a + AN_V) - G_F32(G_PV);
    if (du * du + dv * dv <= ALCANCE * ALCANCE) {
        if (G_I32(G_ATKCD) == 0)
            melee_attack(alvo);
    } else if (!G_I32(G_ATKSTILL)) {    // com Shift: fica parado
        moveto_enemy(alvo);
    }
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

    // um cervo parado 5 celulas a frente: clica nele, vai e golpeia
    extern int animal_spawn(int tipo, float u, float v) ASM(animal_spawn);
    u0 = G_F32(G_PU);
    v0 = G_F32(G_PV);
    int c = animal_spawn(A_DEER, u0 + 5.0f, v0);
    int golpe = 0;
    quadros = 0;
    if (c >= 0) {
        uint8_t *a = animals + c * 32;
        int vida0 = *(uint16_t *)(a + 28);
        G_I32(G_ATKCD) = 0;
        moveto_enemy(c);
        while (G_I32(G_MOVETO) && quadros < 600) {
            *(float *)(a + 8) = 0;      // fica parado (du, dv)
            *(float *)(a + 12) = 0;
            *(float *)(a + AN_U) = u0 + 5.0f;
            *(float *)(a + AN_V) = v0;
            surv_update();
            quadros++;
        }
        golpe = a[AN_TYPE] == 255 || *(uint16_t *)(a + 28) < vida0;
        a[AN_TYPE] = 255;               // some
    }
    n = snprintf(buf, sizeof buf,
                 "movimento: clique num cervo a 5 celulas -> andou %.2f, golpeou=%d, em %d quadros\n",
                 G_F32(G_PU) - u0, golpe, quadros);
    if (write(1, buf, n) < 0) {}

    // segurando o botao num urso parado do lado: golpes seguidos
    u0 = G_F32(G_PU);
    v0 = G_F32(G_PV);
    c = animal_spawn(A_BEAR, u0 + 1.0f, v0);
    int golpes = 0, morreu = 0;
    if (c >= 0) {
        uint8_t *a = animals + c * 32;
        int vida = *(uint16_t *)(a + 28);
        G_I32(G_ATKCD) = 0;
        attack_hold(c);
        for (quadros = 0; quadros < 120; quadros++) {
            *(float *)(a + 8) = 0;
            *(float *)(a + 12) = 0;
            *(float *)(a + AN_U) = u0 + 1.0f;
            *(float *)(a + AN_V) = v0;
            *(uint16_t *)(a + 22) = 60;     // nao morde (espera da mordida)
            G_F32(G_HP) = 100.0f;
            surv_update();
            if (a[AN_TYPE] == 255) { morreu = 1; golpes++; break; }
            int v2 = *(uint16_t *)(a + 28);
            if (v2 < vida) golpes++;
            vida = v2;
        }
        attack_release();
        a[AN_TYPE] = 255;
    }
    n = snprintf(buf, sizeof buf,
                 "movimento: segurando num urso por 2 s -> golpes=%d morreu=%d\n", golpes, morreu);
    if (write(1, buf, n) < 0) {}
}
