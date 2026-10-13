// =====================================================================
//  tempo.c - o jogo anda a 60 passos por segundo em qualquer tela
//
//  Antes cada quadro desenhado era um passo do jogo; numa tela de 120 Hz
//  (os Macs com ProMotion) tudo andava 2 vezes mais rapido. Agora o laco
//  principal pergunta quantos passos dar pelo tempo que passou, a 60 por
//  segundo (no maximo 5 de uma vez, se o computador engasgar).
//
//  Velocidade do jogo: [ e ] mudam de 10% em 10% (50% a 150%).
// =====================================================================
#include "ermo.h"
#include <stdio.h>

extern uint64_t SDL_GetTicksNS(void);
extern void set_msg(const char *texto) ASM(set_msg);

#define PASSO_NS  (1000000000ULL / 60)
#define MAX_PASSOS 5

static uint64_t ultimo, sobra;
static int velocidade = 100;            // %

// -> quantos passos do jogo dar agora (0 numa tela mais rapida que 60 Hz)
int frame_steps(void)
{
    uint64_t agora = SDL_GetTicksNS();
    if (ultimo == 0) {
        ultimo = agora;
        return 1;
    }
    sobra += (agora - ultimo) * (uint64_t)velocidade / 100;
    ultimo = agora;
    int n = (int)(sobra / PASSO_NS);
    sobra -= (uint64_t)n * PASSO_NS;
    if (n > MAX_PASSOS) {
        n = MAX_PASSOS;
        sobra = 0;
    }
    return n;
}

// [ e ] : velocidade do jogo -> 1 se tratou a tecla
int speed_key(int scancode)
{
    int antes = velocidade;
    if (scancode == 47 && velocidade > 50)          // [
        velocidade -= 10;
    else if (scancode == 48 && velocidade < 150)    // ]
        velocidade += 10;
    else if (scancode != 47 && scancode != 48)
        return 0;
    static char msg[48];
    snprintf(msg, sizeof msg, "Velocidade do jogo: %d%%%s", velocidade,
             velocidade == antes ? " (limite)" : "");
    set_msg(msg);
    return 1;
}
