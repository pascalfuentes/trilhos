// =====================================================================
//  teclas.c - teclas e ataque parado, como no Diablo (fase 3, etapa 3.4)
//
//  - R liga e desliga o correr (antes era segurar Shift).
//  - Shift + clique: ataca parado, sem andar ate o bicho nem coletar;
//    segurando, continua golpeando ali mesmo (so acerta quem estiver ao
//    alcance). Com o arco na mao, o Shift nao muda nada (ja atira parado).
// =====================================================================
#include "ermo.h"

extern void set_msg(const char *texto) ASM(set_msg);
extern int melee_attack(int animal) ASM(melee_attack);
extern void attack_hold(int animal);

#define SC_R        21
#define SC_LSHIFT   225
#define SC_RSHIFT   229

static int shift_apertado(void)
{
    const uint8_t *k = (const uint8_t *)(uintptr_t)G_U64(G_KEYS);
    return k && (k[SC_LSHIFT] || k[SC_RSHIFT]);
}

// tecla apertada -> 1 se tratou aqui (o assembly segue com as outras)
int key_c(int scancode)
{
    if (scancode == SC_R) {
        G_I32(G_RUNTOG) = !G_I32(G_RUNTOG);
        set_msg(G_I32(G_RUNTOG) ? "Correr: ligado (R)" : "Correr: desligado (R)");
        return 1;
    }
    return 0;
}

// clique esquerdo -> 1 se foi um ataque parado (Shift)
int shift_attack(void)
{
    if (!shift_apertado())
        return 0;
    if (G_I32(G_HAND) == IT_BOW + 1)    // arco: o assembly atira, como sempre
        return 0;
    int alvo = G_I32(G_HOVANIM);
    G_I32(G_ATKSTILL) = 1;
    if (alvo >= 0) {
        attack_hold(alvo);
        melee_attack(alvo);
    }
    return 1;
}

// ---------------------------------------------------------------------
//  Teste (--shot)
// ---------------------------------------------------------------------
#include <stdio.h>
#include <unistd.h>

extern uint8_t animals[] ASM(animals);
extern int animal_spawn(int tipo, float u, float v) ASM(animal_spawn);
extern void surv_update(void) ASM(surv_update);
extern void attack_release(void);

void keys_selftest(void)
{
    static uint8_t falsas[512];         // teclado de mentira: so o Shift
    uint64_t reais = G_U64(G_KEYS);
    int r0 = G_I32(G_RUNTOG);
    key_c(SC_R);
    int ligou = G_I32(G_RUNTOG) != r0;
    key_c(SC_R);

    falsas[SC_LSHIFT] = 1;
    G_U64(G_KEYS) = (uint64_t)(uintptr_t)falsas;
    G_I32(G_HAND) = 0;
    float u0 = G_F32(G_PU), v0 = G_F32(G_PV);
    int perto = animal_spawn(A_DEER, u0 + 1.0f, v0);
    int longe = animal_spawn(A_DEER, u0 + 4.0f, v0);
    int acertou = 0, andou = 0;
    if (perto >= 0 && longe >= 0) {
        uint8_t *a = animals + perto * 32;
        int vida = *(uint16_t *)(a + 28);
        G_I32(G_ATKCD) = 0;
        G_I32(G_HOVANIM) = perto;
        shift_attack();
        acertou = a[16] == 255 || *(uint16_t *)(a + 28) < vida;
        attack_release();
        a[16] = 255;
        G_I32(G_ATKCD) = 0;             // no longe: segura 1 s, nao sai do lugar
        G_I32(G_HOVANIM) = longe;
        shift_attack();
        uint8_t *b = animals + longe * 32;
        for (int i = 0; i < 60; i++) {
            *(float *)(b + 8) = 0;
            *(float *)(b + 12) = 0;
            *(float *)(b + 0) = u0 + 4.0f;
            *(float *)(b + 4) = v0;
            surv_update();
        }
        andou = G_F32(G_PU) != u0 || G_F32(G_PV) != v0;
        attack_release();
        b[16] = 255;
    }
    G_U64(G_KEYS) = reais;
    char buf[160];
    int n = snprintf(buf, sizeof buf,
                     "teclas: R liga o correr=%d | Shift+clique no cervo do lado acertou=%d, "
                     "no cervo longe andou=%d\n", ligou, acertou, andou);
    if (write(1, buf, n) < 0) {}
}
