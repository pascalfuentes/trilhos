// =====================================================================
//  numeros.c - numeros de dano subindo, como no Diablo (etapa 3.6)
//
//  Cada golpe ou flecha que acerta faz o dano subir da cabeca do bicho
//  (amarelo; branco quando mata). Errou: "Errou" cinza. Mordida no
//  heroi: o dano em vermelho subindo dele. Somem em 1 s, subindo 24 px.
// =====================================================================
#include "ermo.h"
#include <stdio.h>

extern void text(int x, int y, const char *texto) ASM(text);
extern void setcolor(int r, int g, int b, int a) ASM(setcolor);
extern int elev_at(float u, float v) ASM(elev_at);

#define MAXNUM   24
#define VIDA     60                     // quadros
#define SOBE     24                     // px (interface, 640 x 360)

typedef struct {
    float u, v;
    int nasceu;                         // G_FRAME quando apareceu
    int altura;                         // px de arte acima do chao
    int cor;                            // 0 amarelo, 1 branco, 2 cinza, 3 vermelho
    char txt[12];
} Numero;

static Numero nums[MAXNUM];
static int proximo;

void dmgnum_add(float u, float v, int altura, int cor, const char *txt)
{
    Numero *n = &nums[proximo];
    proximo = (proximo + 1) % MAXNUM;
    n->u = u;
    n->v = v;
    n->nasceu = G_I32(G_FRAME) + 1;
    n->altura = altura;
    n->cor = cor;
    snprintf(n->txt, sizeof n->txt, "%s", txt);
}

void dmgnum_value(float u, float v, int altura, int cor, int valor)
{
    char t[12];
    snprintf(t, sizeof t, "%d", valor);
    dmgnum_add(u, v, altura, cor, t);
}

// o mesmo calculo do proj (sobrevivencia.S), na escala da interface
static void tela_ui(float u, float v, int e, int *x, int *y)
{
    int X = (int)((u - v) * 64.0f);
    int Y = ((int)((u + v) * 64.0f) >> 1) - e;
    int z = G_I32(G_Z256);
    *x = ((((X - G_I32(G_CX)) * z) >> 12) + 640) / 2;
    *y = ((((Y - G_I32(G_CY)) * z) >> 12) + 360) / 2;
}

static const uint8_t cores[4][3] = {
    {255, 220, 80}, {255, 255, 255}, {170, 170, 170}, {240, 60, 50},
};

void dmgnum_draw(void)
{
    int agora = G_I32(G_FRAME);
    int s = G_I32(G_Z256) >> 10;
    if (s < 1)
        s = 1;
    for (int i = 0; i < MAXNUM; i++) {
        Numero *n = &nums[i];
        int idade = agora - n->nasceu;
        if (n->nasceu == 0 || idade < -1 || idade >= VIDA)
            continue;
        if (idade < 0)
            idade = 0;
        int e = elev_at(n->u, n->v);
        if (e < G_I32(G_FLOOD))
            e = G_I32(G_FLOOD);
        int x, y;
        tela_ui(n->u, n->v, e, &x, &y);
        y -= n->altura * s / 2 + idade * SOBE / VIDA;
        x -= (int)__builtin_strlen(n->txt) * 4;
        int a = idade < VIDA / 2 ? 255 : 255 * (VIDA - idade) / (VIDA / 2);
        setcolor(0, 0, 0, a);           // sombra
        text(x + 1, y + 1, n->txt);
        setcolor(cores[n->cor][0], cores[n->cor][1], cores[n->cor][2], a);
        text(x, y, n->txt);
    }
}

// mordida no heroi (pct = % da vida) -> o mesmo pct; o dano em pontos
// sobe em vermelho
extern int hp_max(void) ASM(hp_max);

float hero_bitten(float pct)
{
    int pontos = (int)(pct * hp_max() / 100.0f + 0.5f);
    if (pontos > 0)
        dmgnum_value(G_F32(G_PU), G_F32(G_PV), 44, 3, pontos);
    return pct;
}

// teste: quantos estao na tela agora
int dmgnum_count(void)
{
    int c = 0, agora = G_I32(G_FRAME);
    for (int i = 0; i < MAXNUM; i++)
        if (nums[i].nasceu && agora - nums[i].nasceu < VIDA)
            c++;
    return c;
}

// ---------------------------------------------------------------------
//  Foto (--shot): um lobo do lado leva 3 golpes (um erra) e morde voce
// ---------------------------------------------------------------------
extern int animal_spawn(int tipo, float u, float v) ASM(animal_spawn);
extern void an_setlevel(int animal, int nivel) ASM(an_setlevel);
extern int player_hit(int animal, int base, int distancia);
extern void hit_sure(int sim);
extern void draw_all(void) ASM(draw_all);
extern void save_bmp(const char *nome) ASM(save_bmp);
extern uint8_t animals[] ASM(animals);

void numbers_shot(void)
{
    float u = G_F32(G_PU) + 1.2f, v = G_F32(G_PV) - 1.2f;
    int c = animal_spawn(A_WOLF, u, v);
    if (c < 0)
        return;
    an_setlevel(c, 8);
    int f0 = G_I32(G_FRAME);
    G_I32(G_FRAME) = f0 - 40;           // o primeiro ja subiu um pouco
    player_hit(c, 6, 0);
    G_I32(G_FRAME) = f0 - 20;
    hit_sure(0);
    dmgnum_add(u, v, 34, 2, "Errou");
    hit_sure(1);
    G_I32(G_FRAME) = f0 - 8;
    player_hit(c, 9, 0);
    G_I32(G_FRAME) = f0 - 4;
    hero_bitten(12.0f);
    G_I32(G_FRAME) = f0;
    c = animal_spawn(A_WOLF, u + 0.3f, v + 1.5f);   // outro lobo, com o mouse
    G_I32(G_HOVANIM) = c;                           // em cima: contorno dourado
    draw_all();
    save_bmp("shot_dano.bmp");
    G_I32(G_HOVANIM) = -1;
    if (c >= 0)
        animals[c * 32 + 16] = 255;
    animals[c * 32 + 16] = 255;
}
