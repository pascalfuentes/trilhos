// =====================================================================
//  morte.c - morrer custa 1 nivel (fase 3, etapa 3.7)
//
//  Na tela de morte, ENTER renasce no comeco da partida (ate as cidades
//  existirem): vida, fome e calor cheios, um nivel a menos (minimo 1) e
//  o XP no comeco desse nivel. Os pontos de atributo ja gastos ficam;
//  subir de novo ate o nivel perdido nao da pontos outra vez (G_MAXLVL).
//  N comeca um mundo novo (o que o ENTER fazia antes).
// =====================================================================
#include "ermo.h"
#include <stdio.h>

extern uint64_t xp_need(int nivel);
extern int elev_at(float u, float v) ASM(elev_at);
extern void follow_camera(void) ASM(follow_camera);
extern void set_msg(const char *texto) ASM(set_msg);
extern void calc_stats(void) ASM(calc_stats);

// no xp_gain, a cada nivel que sobe: 5 pontos so se passou do maior
void level_up_points(void)
{
    int novo = G_I32(G_LEVEL) + 1;
    if (G_I32(G_MAXLVL) < G_I32(G_LEVEL))
        G_I32(G_MAXLVL) = G_I32(G_LEVEL);
    if (novo > G_I32(G_MAXLVL)) {
        G_I32(G_APTS) += 5;
        G_I32(G_MAXLVL) = novo;
    }
}

void player_respawn(void)
{
    int nivel = G_I32(G_LEVEL);
    if (G_I32(G_MAXLVL) < nivel)
        G_I32(G_MAXLVL) = nivel;
    if (nivel > 1)
        nivel--;
    G_I32(G_LEVEL) = nivel;
    G_U64(G_XP) = 0;
    G_U64(G_XPNEED) = xp_need(nivel);

    G_F32(G_HP) = 100.0f;
    G_F32(G_FOOD) = 100.0f;
    G_F32(G_WARM) = 100.0f;
    G_F32(G_STAMINA) = G_F32(G_STAMAX) > 0 ? G_F32(G_STAMAX) : 100.0f;
    G_I32(G_DEAD) = 0;
    G_U64(G_DEATHMSG) = 0;
    G_I32(G_WATER) = 0;
    G_I32(G_SHARK) = 0;
    G_I32(G_LMB) = 0;
    G_I32(G_MOVETO) = 0;
    G_I32(G_ATKHOLD) = 0;
    G_I32(G_SLEEP) = 0;
    G_I32(G_PLACE) = 0;

    float u = G_F32(G_HOMEU), v = G_F32(G_HOMEV);
    G_F32(G_PU) = u;
    G_F32(G_PV) = v;
    G_I32(G_PE) = elev_at(u, v);
    follow_camera();
    calc_stats();

    static char msg[64];
    snprintf(msg, sizeof msg, "Voce renasceu no comeco. Perdeu 1 nivel: agora %d", nivel);
    set_msg(msg);
}

// carregar um save com G menor (de antes de G crescer): o resto e 0
extern uint8_t G[] ASM(G);
void g_load_tail(int tamanho)
{
    for (int i = tamanho; i < GSIZE; i++)
        G[i] = 0;
}

// ---------------------------------------------------------------------
//  Teste (--shot): nivel 6 morre, renasce no 5; volta ao 6 sem pontos
// ---------------------------------------------------------------------
#include <unistd.h>
extern void xp_gain(int xp) ASM(xp_gain);

void death_selftest(void)
{
    int l0 = G_I32(G_LEVEL), p0 = G_I32(G_APTS), m0 = G_I32(G_MAXLVL);
    uint64_t x0 = G_U64(G_XP), n0 = G_U64(G_XPNEED);
    float u0 = G_F32(G_PU), v0 = G_F32(G_PV);

    G_I32(G_LEVEL) = 6;
    G_I32(G_MAXLVL) = 6;
    G_U64(G_XPNEED) = xp_need(6);
    G_U64(G_XP) = 10;
    G_I32(G_APTS) = 0;
    G_I32(G_DEAD) = 1;
    player_respawn();
    int nivel = G_I32(G_LEVEL), xp = (int)G_U64(G_XP), vivo = !G_I32(G_DEAD);
    float casa = __builtin_fabsf(G_F32(G_PU) - G_F32(G_HOMEU)) + __builtin_fabsf(G_F32(G_PV) - G_F32(G_HOMEV));
    xp_gain((int)xp_need(5));           // volta ao 6: sem pontos
    int pts6 = G_I32(G_APTS);
    xp_gain((int)xp_need(6));           // passa do 6: 5 pontos
    int pts7 = G_I32(G_APTS);

    char buf[200];
    int n = snprintf(buf, sizeof buf,
                     "morte: nivel 6 morreu -> renasceu no nivel %d, xp=%d, vivo=%d, no comeco=%d | "
                     "de volta ao 6: pontos=%d | no 7: pontos=%d\n",
                     nivel, xp, vivo, casa < 0.01f, pts6, pts7);
    if (write(1, buf, n) < 0) {}

    G_I32(G_LEVEL) = l0;
    G_I32(G_APTS) = p0;
    G_I32(G_MAXLVL) = m0;
    G_U64(G_XP) = x0;
    G_U64(G_XPNEED) = n0;
    G_F32(G_PU) = u0;
    G_F32(G_PV) = v0;
    G_I32(G_MSGT) = 0;
    G_I32(G_POPT) = 0;
}
