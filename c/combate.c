// =====================================================================
//  combate.c - acerto e dano pelos atributos e pelo nivel (etapa 3.5)
//
//  Chance de acertar = 80% + 2% por ponto de Destreza acima de 10
//                      + 3% por nivel seu acima do bicho (ou -3% abaixo),
//  entre 20% e 95%. Errou: "Errou!" e nada de dano.
//  Dano = o da arma x (1 + 3% por ponto acima de 10): Forca no golpe,
//  Destreza na flecha; arredondado, minimo 1. A defesa do bicho vem
//  depois, no animal_hit.
//  Nos testes (--shot) sempre acerta, para os numeros nao variarem.
//  O dano (ou "Errou") sobe da cabeca do bicho: c/numeros.c.
// =====================================================================
#include "ermo.h"

extern void animal_hit(int animal, int dano) ASM(animal_hit);
extern void popup(const char *texto) ASM(popup);
extern uint32_t rng(void) ASM(rng);
extern uint8_t animals[] ASM(animals);

#define AN_LVL 27
#define AN_TYPE 16
#define AN_HP  28

extern void dmgnum_add(float u, float v, int altura, int cor, const char *txt);
extern void dmgnum_value(float u, float v, int altura, int cor, int valor);

// altura da cabeca do bicho (px de arte): lobo 34, urso 42, os outros 16
static int altura(int tipo)
{
    return tipo == A_WOLF ? 34 : tipo == A_BEAR ? 42 : 16;
}

static int sempre_acerta;

void hit_sure(int sim)
{
    sempre_acerta = sim;
}

int hit_chance(int animal)
{
    int nivel_bicho = animals[animal * 32 + AN_LVL];
    int pct = 80 + 2 * (G_I32(G_DEX) - 10) + 3 * (G_I32(G_LEVEL) - nivel_bicho);
    return pct < 20 ? 20 : pct > 95 ? 95 : pct;
}

int hit_damage(int base, int distancia)
{
    int attr = distancia == 2 ? G_I32(G_ENE) : distancia ? G_I32(G_DEX) : G_I32(G_STR);
    int dano = (base * (100 + 3 * (attr - 10)) + 50) / 100;
    return dano < 1 ? 1 : dano;
}

// golpe (distancia 0), flecha (1) ou magia (2, nunca erra; Energia)
// no bicho -> 1 se acertou
int player_hit(int animal, int base, int distancia)
{
    uint8_t *a = animals + animal * 32;
    float u = *(float *)a, v = *(float *)(a + 4);
    int tipo = a[AN_TYPE];
    if (distancia < 2 && !sempre_acerta && (int)(rng() % 100) >= hit_chance(animal)) {
        dmgnum_add(u, v, altura(tipo), 2, "Errou");
        return 0;
    }
    int antes = *(uint16_t *)(a + AN_HP);
    animal_hit(animal, hit_damage(base, distancia));
    int morreu = a[AN_TYPE] == 255;
    int dano = morreu ? antes : antes - *(uint16_t *)(a + AN_HP);
    dmgnum_value(u, v, altura(tipo), morreu ? 1 : 0, dano);
    return 1;
}

// na janela C: "Dano +30%" (Forca) e "Acerto 80%" (contra um bicho do
// seu nivel), nas areas do designer
extern void wtext(int x, int y, const char *texto) ASM(wtext);
#include <stdio.h>

void char_combat_text(void)
{
    char t[24];
    snprintf(t, sizeof t, "Dano +%d%%", 3 * (G_I32(G_STR) - 10));
    wtext(CHR_X + UA_DANO_X, CHR_Y + UA_DANO_Y, t);
    int pct = 80 + 2 * (G_I32(G_DEX) - 10);
    snprintf(t, sizeof t, "Acerto %d%%", pct < 20 ? 20 : pct > 95 ? 95 : pct);
    wtext(CHR_X + UA_ACERTO_X, CHR_Y + UA_ACERTO_Y, t);
}

// ---------------------------------------------------------------------
//  Teste (--shot)
// ---------------------------------------------------------------------
#include <stdio.h>
#include <unistd.h>

extern int animal_spawn(int tipo, float u, float v) ASM(animal_spawn);
extern void an_setlevel(int animal, int nivel) ASM(an_setlevel);

void combat_selftest(void)
{
    int str0 = G_I32(G_STR), dex0 = G_I32(G_DEX), lvl0 = G_I32(G_LEVEL);
    int c = animal_spawn(A_BEAR, G_F32(G_PU) + 30.0f, G_F32(G_PV));
    char buf[300];
    int n = 0, numeros = 0;
    if (c >= 0) {
        G_I32(G_LEVEL) = 1;
        G_I32(G_DEX) = 10;
        an_setlevel(c, 1);
        int a1 = hit_chance(c);
        an_setlevel(c, 6);
        int a2 = hit_chance(c);
        G_I32(G_DEX) = 30;
        int a3 = hit_chance(c);
        G_I32(G_STR) = 10;
        int d1 = hit_damage(6, 0);
        G_I32(G_STR) = 30;
        int d2 = hit_damage(6, 0);
        // 100 golpes com 50% de chance: quantos acertam?
        G_I32(G_DEX) = 10;
        G_I32(G_LEVEL) = 1;
        an_setlevel(c, 11);             // 80 - 30 = 50%
        sempre_acerta = 0;
        int acertos = 0;
        for (int i = 0; i < 100; i++) {
            an_setlevel(c, 11);         // vida cheia de novo
            acertos += player_hit(c, 1, 0);
        }
        sempre_acerta = 1;
        animals[c * 32 + 16] = 255;
        extern int dmgnum_count(void);
        numeros = dmgnum_count();
        extern int bow_selftest(int quadros);
        int inv = G_I32(G_INV + 4 * IT_ARROW);
        G_I32(G_INV + 4 * IT_ARROW) = 5;
        int arco0 = bow_selftest(0), arco30 = bow_selftest(30), arco60 = bow_selftest(80);
        G_I32(G_INV + 4 * IT_ARROW) = inv;
        G_I32(G_ATKCD) = 0;
        n = snprintf(buf, sizeof buf,
                     "combate: acerto nv1 x bicho nv1=%d%% nv6=%d%% (destreza 30: %d%%) | "
                     "golpe 6 com forca 10=%d forca 30=%d | 100 golpes a 50%% acertaram %d "
                     "(numeros na tela: %d) | arco: clique=%d meio s=%d 1 s=%d\n",
                     a1, a2, a3, d1, d2, acertos, numeros, arco0, arco30, arco60);
    }
    G_I32(G_STR) = str0;
    G_I32(G_DEX) = dex0;
    G_I32(G_LEVEL) = lvl0;
    G_I32(G_POPT) = 0;
    if (n > 0 && write(1, buf, n) < 0) {}
}
