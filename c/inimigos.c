// =====================================================================
//  inimigos.c - regras dos inimigos em C (fase 2 do RPG)
//
//  an_xp: o XP de abater um bicho (etapa 2.3). Era assembly em animais.S.
// =====================================================================
#include "ermo.h"

// XP = nivel do bicho (metade nos pacificos), x2 campeao, x4 chefe;
// acima do seu nivel +10% por nivel (ate +50%); 5-6 abaixo 50%, 7-9
// abaixo 25%, 10 ou mais abaixo 10%; sempre pelo menos 1.
int an_xp(int nivel, int posto, int perigoso)
{
    int xp = perigoso ? nivel : (nivel + 1) / 2;
    if (posto == 1) xp *= 2;
    if (posto == 2) xp *= 4;

    int dif = nivel - G_I32(G_LEVEL);
    int pct = 100;
    if (dif > 0) {
        int bonus = dif * 10;
        pct += bonus > 50 ? 50 : bonus;
    } else if (dif <= -10) {
        pct = 10;
    } else if (dif <= -7) {
        pct = 25;
    } else if (dif <= -5) {
        pct = 50;
    }

    xp = (xp * pct + 50) / 100;
    return xp < 1 ? 1 : xp;
}
