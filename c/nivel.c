// =====================================================================
//  nivel.c - nivel e XP em C (o resto de nivel e atributos ainda esta
//  em nivel.S; vem para ca na etapa de migracao x-3).
//
//  Curva (etapa 1.8): do nivel 1 para o 2 sao 10 XP; cada nivel pede
//  1,25 vezes o anterior: 10, 13, 16, 20, 24, 31, 38, 48, 60, 75...
//  Sem nivel maximo; acima de 10^18 o valor para de crescer (64 bits).
// =====================================================================
#include "ermo.h"

#define XP_TETO 1000000000000000000.0

// XP para passar do nivel 'nivel' ao proximo
uint64_t xp_need(int nivel)
{
    double d = 10.0;
    for (int i = 1; i < nivel && d < XP_TETO; i++)
        d *= 1.25;
    if (d > XP_TETO)
        d = XP_TETO;
    return (uint64_t)(d + 0.5);
}

// save de antes da curva nova: recalcula quanto falta (o XP que ja tinha
// fica, ate o limite do nivel)
void xp_curve_fix(void)
{
    int nivel = G_I32(G_LEVEL);
    if (nivel < 1)
        return;
    uint64_t need = xp_need(nivel);
    G_U64(G_XPNEED) = need;
    if (G_U64(G_XP) >= need)
        G_U64(G_XP) = need - 1;
}
