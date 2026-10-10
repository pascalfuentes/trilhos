// =====================================================================
//  pessoas.S - a vila: 3 familias (pai, mae e 2 filhos) que voce comanda
//
//  - Voce (o personagem) nao envelhece: e uma especie de profeta. Quem
//    fica perto de voce (6 celulas) ganha fe; longe, a fe cai devagar.
//    Fe alta: trabalha mais rapido (ate 1,5x). Fe baixa (< 25): as vezes
//    enrola e pode recusar ordens. Fe zerada: vai embora.
//  - Todos envelhecem 1 ano a cada 12 dias. Com 14 anos uma crianca vira
//    adulto e pode receber tarefa. Bem velhos (65+) podem morrer.
//  - Comem do bau (frutas, pao, carne, peixe...) quando a fome passa de
//    60%; sem nada no bau, colhem frutas de arbustos. Sem comida perdem
//    vida e morrem. De noite vao dormir na cabana (ou perto de uma
//    fogueira acesa). Em noite de inverno ou neve, fora da cabana e longe
//    do fogo, passam frio. Lobos e ursos atacam; eles fogem.
//  - Tarefas (painel P): Floresta, Pedra, Plantar, Obras. Cada uma so
//    trabalha dentro das zonas pintadas na grade (tecla Z) para ela, e
//    guarda o que juntou no bau mais perto.
//      Floresta: corta as arvores adultas da zona (4 por viagem) e planta
//        uma muda no lugar; sem arvore adulta, planta mudas no chao vazio
//        (um quadrado sim, outro nao). Muda -> jovem (1 ano) -> adulta.
//      Pedra: quebra pedras da zona (3 por viagem).
//      Plantar: colhe o trigo maduro (e replanta), planta nas terras
//        aradas vazias (pega sementes no bau) e ara o resto da zona.
//      Obras: barracos, casas e cercas das familias (vila.S).
//  - Clique numa pessoa para seleciona-la; botao direito no mapa: ela
//    vai ate la (e depois volta a tarefa).
//  - Por onde se anda muito vira caminho de terra batida (mais rapido).
// =====================================================================

#include "comum.h"

#include "pessoas.h"

.equ PATHN,      16             // passadas para virar caminho
.equ FINDR,      40             // raio de busca de quadrados para trabalhar

// painel de pessoas e paleta de zonas (espaco da interface 640 x 360)
.equ PP_X,     224
.equ PP_Y,     32
.equ PP_W,     412
.equ PP_H,     272
.equ PP_ROW0,  28
.equ PP_ROWS,  14
.equ ZP_X,     4
.equ ZP_Y,     118
.equ ZP_W,     190
.equ ZP_H,     196

    .text
    .p2align 2

// =====================================================================
//  Comeco do jogo
// =====================================================================

// people_reset: 3 familias em volta do personagem, sem zonas nem caminhos;
// um bau com comida e sementes do lado (no teste --shot ficam paradas)
    .globl people_reset
people_reset:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x9, people
    mov     w10, #(MAXPEOPLE * PSIZE / 16)
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    LA      x9, zonegrid
    mov     w10, #(MAPN * MAPN / 16)
2:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    2b
    LA      x9, walkgrid
    mov     w10, #(MAPN * MAPN / 16)
3:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    3b
    mov     w9, #-1
    str     w9, [x28, #G_HOVPERS]
    str     w9, [x28, #G_SELPERS]
    str     w9, [x28, #G_PLCELL]
    str     w9, [x28, #G_OCCFRAME]
    str     wzr, [x28, #G_PEOPLEOPEN]
    str     wzr, [x28, #G_ZONEMODE]
    str     wzr, [x28, #G_ZDRAG]
    str     wzr, [x28, #G_ZONESHOW]
    mov     w9, #3
    str     w9, [x28, #G_ZBRUSH]
    ldr     w9, [x28, #G_DAY]
    str     w9, [x28, #G_PLASTDAY]
    LA      x9, pinv                    // mochilas vazias...
    mov     w10, #(MAXPEOPLE * 256 / 16)
5:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    5b
    LA      x9, pinv                    // ... com 2 frutas assadas de lanche
    mov     w10, #2
    mov     w11, #12
6:  str     w10, [x9, #(4 * IT_COOKED)]
    add     x9, x9, #256
    subs    w11, w11, #1
    b.ne    6b
    bl      vila_reset
    bl      ppl_spawn_all
    ldr     w9, [x28, #G_SHOT]
    cbz     w9, 4f
    mov     w9, #1                      // teste: so quando o teste pedir
    str     w9, [x28, #G_NOPEOPLE]
    b       9f
4:  str     wzr, [x28, #G_NOPEOPLE]
    bl      ppl_camp
    bl      vila_found                  // um barraco para cada familia
9:  ldp     x29, x30, [sp], #16
    ret

// ppl_spawn_all: as 12 pessoas (pai, mae e 2 filhos de cada familia)
ppl_spawn_all:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    mov     w20, #0
1:  cmp     w20, #12
    b.ge    9f
    LA      x9, people
    add     x19, x9, x20, lsl #6
    stp     xzr, xzr, [x19]
    stp     xzr, xzr, [x19, #16]
    stp     xzr, xzr, [x19, #32]
    stp     xzr, xzr, [x19, #48]
    mov     w9, #1
    strb    w9, [x19, #P_ALIVE]
    mov     w10, #4
    udiv    w21, w20, w10               // familia
    msub    w22, w21, w10, w20          // 0 pai, 1 mae, 2 e 3 filhos
    strb    w21, [x19, #P_FAM]
    LA      x9, kin                     // parentes
    add     x9, x9, x20, lsl #3
    mov     w10, #255
    strb    w10, [x9, #K_FATHER]
    strb    w10, [x9, #K_MOTHER]
    strb    w10, [x9, #K_SPOUSE]
    mov     w10, #1
    strb    w10, [x9, #K_REC]
    strb    w21, [x9, #K_SURN]
    lsl     w10, w21, #2                // pai = familia * 4, mae = + 1
    cmp     w22, #1
    b.hi    11f
    eor     w11, w22, #1                // pai e mae: casados
    add     w11, w10, w11
    strb    w11, [x9, #K_SPOUSE]
    b       12f
11: strb    w10, [x9, #K_FATHER]
    add     w11, w10, #1
    strb    w11, [x9, #K_MOTHER]
12: mov     w9, w22
    cmp     w22, #2
    b.lo    2f
    bl      rng
    and     w9, w0, #1
2:  strb    w9, [x19, #P_SEX]
21: mov     w0, #12                     // nome (12 de homem, 12 de mulher)
    bl      rng_mod
    ldrb    w9, [x19, #P_SEX]
    mov     w10, #12
    madd    w0, w9, w10, w0
    lsl     w9, w21, #2                 // ninguem da familia com o mesmo nome
22: cmp     w9, w20
    b.ge    23f
    LA      x10, people
    add     x10, x10, x9, lsl #6
    ldrb    w11, [x10, #P_NAME]
    cmp     w11, w0
    b.eq    21b
    add     w9, w9, #1
    b       22b
23: strb    w0, [x19, #P_NAME]
    cmp     w22, #2                     // idade: adultos 30-42, filhos 14-17 e 3-11
    b.hs    3f
    mov     w0, #13
    bl      rng_mod
    add     w0, w0, #30
    b       4f
3:  b.ne    31f
    mov     w0, #4
    bl      rng_mod
    add     w0, w0, #14
    b       4f
31: mov     w0, #9
    bl      rng_mod
    add     w0, w0, #3
4:  mov     w9, #12
    mul     w21, w0, w9
    mov     w0, #12
    bl      rng_mod
    add     w21, w21, w0
    strh    w21, [x19, #P_AGE]
    PF      s0, 44
    str     s0, [x19, #P_HP]
    mov     w0, #30
    bl      rng_mod
    add     w0, w0, #70
    scvtf   s0, w0
    str     s0, [x19, #P_FOOD]
    mov     w0, #30
    bl      rng_mod
    add     w0, w0, #40
    scvtf   s0, w0
    str     s0, [x19, #P_FAITH]
    mov     w0, #60
    bl      rng_mod
    strh    w0, [x19, #P_THINK]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
    str     w9, [x19, #P_SKIP]
    mov     w21, #0                     // lugar em terra perto do personagem
5:  mov     w0, #9
    bl      rng_mod
    sub     w0, w0, #4
    scvtf   s8, w0
    mov     w0, #9
    bl      rng_mod
    sub     w0, w0, #4
    scvtf   s9, w0
    ldr     s0, [x28, #G_PU]
    fadd    s8, s8, s0
    ldr     s0, [x28, #G_PV]
    fadd    s9, s9, s0
    PF      s2, 96
    fadd    s8, s8, s2
    fadd    s9, s9, s2
    fmov    s0, s8
    fmov    s1, s9
    bl      ppl_land
    cbnz    w0, 6f
    add     w21, w21, #1
    cmp     w21, #24
    b.lt    5b
    ldr     s8, [x28, #G_PU]
    ldr     s9, [x28, #G_PV]
6:  str     s8, [x19, #P_U]
    str     s9, [x19, #P_V]
    add     w20, w20, #1
    b       1b
9:  ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ppl_camp -> w0 = objeto do bau da vila (comida e sementes), perto do
// personagem (-1 se nao coube)
ppl_camp:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    bl      occ_build
    ldr     s0, [x28, #G_PU]
    fcvtzs  w19, s0
    ldr     s0, [x28, #G_PV]
    fcvtzs  w20, s0
    mov     w21, #0
1:  cmp     w21, #12
    b.ge    8f
    LA      x9, campoff
    add     x9, x9, x21, lsl #1
    ldrsb   w10, [x9]
    ldrsb   w11, [x9, #1]
    add     w10, w19, w10
    add     w11, w20, w11
    add     w22, w10, w11, lsl #9       // celula
    LA      x9, occgrid
    ldrb    w9, [x9, w22, uxtw]
    cbnz    w9, 2f
    LA      x9, fencegrid
    ldrb    w9, [x9, w22, uxtw]
    cbnz    w9, 2f
    LA      x9, overlay
    ldrb    w9, [x9, w22, uxtw]
    cbnz    w9, 2f
    scvtf   s0, w10
    scvtf   s1, w11
    PF      s2, 96
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      ppl_land
    cbnz    w0, 3f
2:  add     w21, w21, #1
    b       1b
3:  mov     w0, w22                     // o primeiro deposito (deposito.S)
    bl      dep_camp
    mov     w19, w0
    bl      occ_build
    mov     w0, w19
    b       9f
8:  mov     w0, #-1
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ppl_newchest(w0 = celula) -> w0 = objeto do bau novo, w1 = numero dele
ppl_newchest:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    mov     w19, w0
    LA      x9, chestused
    mov     x10, #0
1:  ldrb    w11, [x9, x10]
    cbz     w11, 2f
    add     x10, x10, #1
    cmp     x10, #MAXCHEST
    b.lt    1b
    mov     w0, #-1
    b       9f
2:  mov     w11, #1
    strb    w11, [x9, x10]
    mov     w20, w10
    LA      x11, chests
    add     x11, x11, x10, lsl #CHESTSHIFT
    mov     w12, #8
3:  stp     xzr, xzr, [x11], #16
    subs    w12, w12, #1
    b.ne    3b
    and     w9, w19, #511
    lsr     w10, w19, #9
    scvtf   s0, w9
    scvtf   s1, w10
    PF      s2, 96
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      elev_at
    mov     w2, w0
    and     w9, w19, #511
    lsl     w0, w9, #6
    add     w0, w0, #32
    lsr     w9, w19, #9
    lsl     w1, w9, #6
    add     w1, w1, #32
    mov     w3, #O_CHEST
    mov     w4, w20
    bl      add_obj
    ldr     w0, [x28, #G_NOBJ]
    sub     w0, w0, #1
    LA      x9, memtype
    mov     w10, #O_CHEST
    strb    w10, [x9, w0, uxtw]
    mov     w1, w20
9:  ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ppl_land(s0 = u, s1 = v) -> w0 = 1 se da para ficar ali (terra; as
// pessoas da vila passam pelas cercas)
    .globl ppl_land
ppl_land:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     d8, d9, [sp, #16]
    fmov    s8, s0
    fmov    s9, s1
    mov     w0, #0
    PF      s2, 88
    fcmp    s8, s2
    b.lt    9f
    fcmp    s9, s2
    b.lt    9f
    PF      s2, 92
    fcmp    s8, s2
    b.gt    9f
    fcmp    s9, s2
    b.gt    9f
    fmov    s0, s8
    fmov    s1, s9
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    cset    w0, ge
9:  ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// =====================================================================
//  Um quadro da vila
// =====================================================================

// zone_update: o pincel segue o mouse; segurando, pinta (ou apaga)
zone_update:
    ldr     w9, [x28, #G_ZONEMODE]
    cbz     w9, 9f
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 9f
    ldr     w9, [x28, #G_HOVU]
    lsr     w0, w9, #6
    str     w0, [x28, #G_ZBU]
    ldr     w9, [x28, #G_HOVV]
    lsr     w1, w9, #6
    str     w1, [x28, #G_ZBV]
    ldr     w9, [x28, #G_ZDRAG]
    cbz     w9, 9f
    ldr     w3, [x28, #G_ZONEMODE]
    cmp     w3, #Z_ERASE
    csel    w3, wzr, w3, eq
    cmp     w9, #2                      // direito: apaga
    csel    w3, wzr, w3, eq
    ldr     w2, [x28, #G_ZBRUSH]
    subs    w2, w2, #1
    csel    w2, wzr, w2, lt
    b       zone_paint
9:  ret

    .globl people_update
people_update:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    bl      zone_update
    ldr     w9, [x28, #G_NOPEOPLE]
    cbnz    w9, 99f
    bl      night_tick                  // alcateias de noite (desafio.S)
    ldr     w9, [x28, #G_PPLFRAME]
    add     w9, w9, #1
    str     w9, [x28, #G_PPLFRAME]
    ldr     w9, [x28, #G_DAY]           // virou o dia: aniversarios
    ldr     w10, [x28, #G_PLASTDAY]
    cmp     w9, w10
    b.eq    1f
    str     w9, [x28, #G_PLASTDAY]
    bl      ppl_newday
1:  ldr     s0, [x28, #G_PU]            // o personagem tambem faz caminho
    fcvtzs  w9, s0
    ldr     s0, [x28, #G_PV]
    fcvtzs  w10, s0
    add     w0, w9, w10, lsl #9
    ldr     w9, [x28, #G_PLCELL]
    cmp     w0, w9
    b.eq    4f
    str     w0, [x28, #G_PLCELL]
    bl      path_step
4:  mov     w20, #0
    mov     w21, #0
5:  cmp     w20, #MAXPEOPLE
    b.ge    8f
    LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 6f
    bl      ppl_one
    ldrb    w9, [x19, #P_ALIVE]
    add     w21, w21, w9
6:  add     w20, w20, #1
    b       5b
8:  str     w21, [x28, #G_PEOPLEN]
99: ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ppl_one: um quadro de uma pessoa (x19 = pessoa, w20 = numero; todas as
// funcoes ppl_* usam x19/w20 assim e nao mexem neles)
ppl_one:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    // ---- fome ----
    ldr     s0, [x19, #P_FOOD]
    PF      s1, 0
    ldrb    w9, [x19, #P_STATE]
    cmp     w9, #ST_SLEEP
    b.ne    1f
    PF      s2, 96
    fmul    s1, s1, s2
1:  fsub    s0, s0, s1
    fmov    s2, wzr
    fmax    s0, s0, s2
    str     s0, [x19, #P_FOOD]
    ldr     s1, [x19, #P_HP]
    mov     w22, #CAUSE_FOME
    fcmp    s0, #0.0
    b.gt    2f
    PF      s2, 4                       // sem comida: perde vida
    fsub    s1, s1, s2
    b       3f
2:  PF      s2, 104                     // bem alimentado: recupera
    fcmp    s0, s2
    b.le    3f
    PF      s2, 8
    fadd    s1, s1, s2
    PF      s2, 44
    fmin    s1, s1, s2
    // ---- frio: noite de inverno (ou neve) fora da cabana e longe do fogo ----
3:  ldr     w9, [x28, #G_TIME]
    mov     w10, #T_NIGHT
    cmp     w9, w10
    b.lo    4f
    ldr     w9, [x28, #G_SEASON]
    cmp     w9, #3
    b.eq    31f
    ldr     w9, [x28, #G_WEATHER]
    cmp     w9, #W_SNOW
    b.ne    4f
31: ldrb    w9, [x19, #P_FLAGS]
    tst     w9, #3
    b.ne    4f
    PF      s2, 12
    fsub    s1, s1, s2
    mov     w22, #CAUSE_FRIO
4:  str     s1, [x19, #P_HP]
    fcmp    s1, #0.0
    b.gt    5f
    mov     w0, w22
    bl      ppl_die
    b       99f
    // ---- fe: perto do personagem sobe, longe cai devagar ----
5:  ldr     s0, [x19, #P_U]
    ldr     s1, [x28, #G_PU]
    fsub    s0, s0, s1
    ldr     s1, [x19, #P_V]
    ldr     s2, [x28, #G_PV]
    fsub    s1, s1, s2
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    ldr     s3, [x19, #P_FAITH]
    PF      s2, 56
    fcmp    s0, s2
    b.gt    51f
    PF      s2, 16
    fadd    s3, s3, s2
    PF      s2, 44
    fmin    s3, s3, s2
    b       52f
51: PF      s2, 20
    fsub    s3, s3, s2
52: str     s3, [x19, #P_FAITH]
    fcmp    s3, #0.0
    b.gt    6f
    mov     w0, #CAUSE_FE
    bl      ppl_die
    b       99f
    // ---- perto do fogo? (a cada 32 quadros) ----
6:  ldr     w9, [x28, #G_PPLFRAME]
    add     w9, w9, w20
    tst     w9, #31
    b.ne    7f
    bl      ppl_nearfire
    // ---- soldado: nao foge nem vai dormir; luta (desafio.S) ----
7:  ldrb    w9, [x19, #P_JOB]
    cmp     w9, #J_SOLDIER
    b.ne    70f
    bl      soldier_frame
    cbnz    w0, 99f
    b       80f
    // ---- foge de bicho perigoso (a cada 8 quadros) ----
70: ldrb    w9, [x19, #P_FLAGS]
    tbnz    w9, #0, 8f
    ldrb    w9, [x19, #P_STATE]
    cmp     w9, #ST_FLEE
    b.eq    8f
    ldr     w9, [x28, #G_PPLFRAME]
    add     w9, w9, w20
    tst     w9, #7
    b.ne    8f
    bl      ppl_checkflee
    // ---- hora de dormir: larga o trabalho (e o passeio) ----
8:  ldr     w9, [x28, #G_TIME]
    mov     w10, #BEDTIME
    cmp     w9, w10
    b.lo    80f
    ldrb    w9, [x19, #P_STATE]
    cmp     w9, #ST_WORK
    b.eq    801f
    cmp     w9, #ST_WAIT
    b.eq    801f
    cmp     w9, #ST_WALK
    b.ne    80f
    ldrb    w10, [x19, #P_NEXT]
    cmp     w10, #NX_WORK
    b.eq    801f
    cmp     w10, #NX_NONE
    b.ne    80f
801: mov    w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    strh    wzr, [x19, #P_THINK]
    strb    wzr, [x19, #P_NEXT]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
    // ---- o que esta fazendo ----
80: ldrb    w9, [x19, #P_STATE]
    cmp     w9, #ST_IDLE
    b.ne    81f
    ldrh    w9, [x19, #P_THINK]
    subs    w9, w9, #1
    csel    w9, wzr, w9, lt
    strh    w9, [x19, #P_THINK]
    cbnz    w9, 99f
    bl      ppl_decide
    b       99f
81: cmp     w9, #ST_WALK
    b.eq    82f
    cmp     w9, #ST_FLEE
    b.ne    83f
82: bl      ppl_walk
    cbz     w0, 99f
    ldrb    w9, [x19, #P_STATE]
    cmp     w9, #ST_FLEE
    b.ne    821f
    mov     w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    strh    wzr, [x19, #P_THINK]
    b       99f
821: bl     ppl_arrive
    b       99f
83: cmp     w9, #ST_WORK
    b.ne    84f
    ldrh    w9, [x19, #P_TIMER]
    subs    w9, w9, #1
    csel    w9, wzr, w9, lt
    strh    w9, [x19, #P_TIMER]
    cbnz    w9, 99f
    bl      ppl_workdone
    b       99f
84: cmp     w9, #ST_WAIT
    b.ne    85f
    ldrh    w9, [x19, #P_TIMER]
    subs    w9, w9, #1
    csel    w9, wzr, w9, lt
    strh    w9, [x19, #P_TIMER]
    cbnz    w9, 99f
    mov     w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    b       99f
85: cmp     w9, #ST_SLEEP
    b.ne    99f
    ldr     w9, [x28, #G_TIME]          // amanheceu?
    mov     w10, #T_DUSK
    cmp     w9, w10
    b.hs    99f
    ldrb    w9, [x19, #P_FLAGS]
    bic     w9, w9, #1
    strb    w9, [x19, #P_FLAGS]
    mov     w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    lsl     w9, w20, #2
    strh    w9, [x19, #P_THINK]
99: ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ppl_nearfire: liga o bit 2 se tem fogueira acesa a ate 5 celulas  folha
ppl_nearfire:
    ldrb    w9, [x19, #P_FLAGS]
    bic     w9, w9, #2
    ldr     w10, [x28, #G_NFIRE]
    LA      x11, fires
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    PF      s4, 60
1:  cbz     w10, 8f
    ldr     w12, [x11, #12]
    cbz     w12, 2f
    ldr     s2, [x11]
    fsub    s2, s2, s0
    ldr     s3, [x11, #4]
    fsub    s3, s3, s1
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    fcmp    s2, s4
    b.gt    2f
    orr     w9, w9, #2
    b       8f
2:  add     x11, x11, #16
    sub     w10, w10, #1
    b       1b
8:  strb    w9, [x19, #P_FLAGS]
    ret

// ppl_checkflee: lobo ou urso a ate 5 celulas: corre para o outro lado
ppl_checkflee:
    LA      x9, animals
    LA      x11, atypes
    mov     w10, #0
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
1:  cmp     w10, #MAXANIM
    b.ge    9f
    ldrb    w12, [x9, #16]
    cmp     w12, #255
    b.eq    2f
    add     x13, x11, x12, lsl #4
    ldrb    w13, [x13, #1]              // perigoso?
    cbz     w13, 2f
    ldr     s2, [x9]
    fsub    s2, s0, s2
    ldr     s3, [x9, #4]
    fsub    s3, s1, s3
    fmul    s4, s2, s2
    fmadd   s4, s3, s3, s4
    PF      s5, 60
    fcmp    s4, s5
    b.gt    2f
    fsqrt   s4, s4
    PF      s5, 100
    fmax    s4, s4, s5
    PF      s5, 108
    fdiv    s5, s5, s4
    fmul    s2, s2, s5
    fmul    s3, s3, s5
    fadd    s2, s2, s0
    fadd    s3, s3, s1
    str     s2, [x19, #P_GU]
    str     s3, [x19, #P_GV]
    mov     w12, #ST_FLEE
    strb    w12, [x19, #P_STATE]
    strb    wzr, [x19, #P_NEXT]
    strh    wzr, [x19, #P_BLOCK]
    b       9f
2:  add     x9, x9, #32
    add     w10, w10, #1
    b       1b
9:  ret

// ppl_die(w0 = causa): a pessoa morre (ou vai embora) e avisa
ppl_die:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x21, [sp, #16]
    mov     w21, w0
    strb    wzr, [x19, #P_ALIVE]
    LA      x9, kin                     // fica na arvore genealogica
    add     x9, x9, x20, lsl #3
    strb    w21, [x9, #K_CAUSE]
    mov     w10, #2
    cmp     w21, #CAUSE_FE
    cinc    w10, w10, eq                // 3: foi embora
    strb    w10, [x9, #K_REC]
    ldr     w9, [x28, #G_SELPERS]
    cmp     w9, w20
    b.ne    1f
    mov     w9, #-1
    str     w9, [x28, #G_SELPERS]
1:  LA      x0, pmsgbuf
    mov     w1, w20
    bl      ppl_namecat
    LA      x9, causemsgs
    ldr     x1, [x9, x21, lsl #3]
    bl      strcat_cur
    LA      x0, pmsgbuf
    bl      set_msg
    ldr     x21, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ppl_namecat(x0 = cursor, w1 = pessoa) -> x0: "Ana Silva"
    .globl ppl_namecat
ppl_namecat:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    uxtw    x1, w1
    str     x1, [sp, #24]
    LA      x9, people
    add     x19, x9, x1, lsl #6
    LA      x1, pnames
    ldrb    w9, [x19, #P_NAME]
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    LA      x1, s_sp
    bl      strcat_cur
    LA      x9, kin                     // sobrenome (do pai)
    ldr     x10, [sp, #24]
    add     x9, x9, x10, lsl #3
    ldrb    w9, [x9, #K_SURN]
    LA      x1, psurn
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ppl_newday: todos ficam um dia mais velhos (aniversario a cada 12 dias)
// e os caminhos pouco usados voltam a ser mato
    .globl ppl_newday
ppl_newday:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    LA      x9, walkgrid
    mov     w10, #(MAPN * MAPN / 16)
1:  ldr     q0, [x9]
    ushr    v0.16b, v0.16b, #1
    str     q0, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    mov     w20, #0
2:  cmp     w20, #MAXPEOPLE
    b.ge    9f
    LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 8f
    mov     w9, #-1                     // tenta de novo o que nao alcancou
    str     w9, [x19, #P_SKIP]
    ldrh    w21, [x19, #P_AGE]
    add     w21, w21, #1
    strh    w21, [x19, #P_AGE]
    mov     w9, #12
    udiv    w22, w21, w9
    msub    w9, w22, w9, w21
    cbnz    w9, 8f
    cmp     w22, #14                    // virou adulto
    b.ne    3f
    LA      x0, pmsgbuf
    mov     w1, w20
    bl      ppl_namecat
    LA      x1, s_adult
    bl      strcat_cur
    LA      x0, pmsgbuf
    bl      set_msg
    b       8f
3:  cmp     w22, #65                    // velhice
    b.lo    8f
    sub     w21, w22, #60
    lsl     w21, w21, #2
    mov     w0, #100
    bl      rng_mod
    cmp     w0, w21
    b.hs    8f
    mov     w0, #CAUSE_VELHO
    bl      ppl_die
8:  add     w20, w20, #1
    b       2b
9:  bl      vila_newday                 // arvores, casamentos, nascimentos
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// path_step(w0 = celula): mais uma passada ali; muitas viram caminho  folha
path_step:
    LA      x9, walkgrid
    ldrb    w10, [x9, w0, uxtw]
    cmp     w10, #255
    cinc    w10, w10, lo
    strb    w10, [x9, w0, uxtw]
    cmp     w10, #PATHN
    b.lo    9f
    LA      x9, overlay
    ldrb    w11, [x9, w0, uxtw]
    cbnz    w11, 9f
    LA      x12, elev
    ldrsh   w12, [x12, w0, uxtw #1]
    ldr     w13, [x28, #G_FLOOD]
    cmp     w12, w13
    b.lt    9f
    mov     w11, #1
    strb    w11, [x9, w0, uxtw]
9:  ret

// =====================================================================
//  Decidir o que fazer
// =====================================================================

ppl_decide:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     x23, x24, [sp, #32]
    // ---- hora de dormir (o soldado fica de vigia) ----
    ldrb    w9, [x19, #P_JOB]
    cmp     w9, #J_SOLDIER
    b.eq    10f
    ldr     w9, [x28, #G_TIME]
    mov     w10, #BEDTIME
    cmp     w9, w10
    b.lo    10f
    bl      ppl_gosleep
    b       90f
    // ---- com fome: come do bau (ou colhe frutas) ----
10: ldr     s0, [x19, #P_FOOD]
    PF      s1, 112
    fcmp    s0, s1
    b.ge    20f
    bl      pinv_eat                    // o lanche da mochila primeiro
    ldr     s0, [x19, #P_FOOD]
    PF      s1, 112
    fcmp    s0, s1
    b.ge    20f
    mov     w0, #1
    bl      ppl_chestfind
    tbnz    w0, #31, 11f
    mov     w1, #NX_EAT
    bl      ppl_gochest
    b       90f
11: mov     w0, #O_BUSH
    mov     w1, #O_BUSH
    mov     w2, #0
    mov     w3, #WK_FORAGE
    PF      s0, 68
    bl      ppl_findobj
    tbnz    w0, #31, 20f
    mov     w1, #WK_FORAGE
    bl      ppl_gowork_obj
    b       90f
    // ---- crianca ou sem tarefa: passeia ----
20: ldrh    w9, [x19, #P_AGE]
    cmp     w9, #ADULTDAYS
    b.lo    80f
    ldrb    w21, [x19, #P_JOB]
    cbz     w21, 80f
    // ---- carregando outra coisa, ou cheio: guarda no bau ----
    bl      pinv_cargo
    cbz     w0, 30f
    LA      x9, jobcap
    ldrb    w9, [x9, x21]
    cmp     w0, w9
    b.lo    30f
25: mov     w0, #0
    bl      ppl_chestfind
    tbnz    w0, #31, 26f
    mov     w1, #NX_DEPOSIT
    bl      ppl_gochest
    b       90f
26: bl      ppl_nochestmsg
    b       80f
    // ---- pouca fe: as vezes enrola ----
30: ldr     s0, [x19, #P_FAITH]
    PF      s1, 116
    fcmp    s0, s1
    b.ge    31f
    mov     w0, #100
    bl      rng_mod
    cmp     w0, #40
    b.lo    80f
    // ---- trabalho da tarefa ----
31: bl      tool_fetch                  // pega a ferramenta de ferro no bau
    cbnz    w0, 90f
    mov     w0, w21
    bl      ppl_findwork
    cbnz    w0, 90f
    bl      pinv_cargo                  // nada para fazer: guarda o que tem
    cbz     w0, 80f
    mov     w0, #0
    bl      ppl_chestfind
    tbnz    w0, #31, 80f
    mov     w1, #NX_DEPOSIT
    bl      ppl_gochest
    b       90f
80: bl      ppl_wander
90: mov     w0, #40
    bl      rng_mod
    add     w0, w0, #30
    strh    w0, [x19, #P_THINK]
    ldp     x23, x24, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ppl_nochestmsg: avisa (de vez em quando) que falta um bau
ppl_nochestmsg:
    ldr     w9, [x28, #G_PPLFRAME]
    ldr     w10, [x28, #G_PNOCHEST]
    sub     w11, w9, w10
    cmp     w11, #1800
    b.lo    9f
    str     w9, [x28, #G_PNOCHEST]
    LA      x0, m_nochest
    b       set_msg
9:  ret

// ppl_findwork(w0 = tarefa) -> w0 = 1 se achou o que fazer (ja indo)
ppl_findwork:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    mov     w21, w0
    cmp     w21, #J_FOREST
    b.ne    2f
    mov     w0, #O_TREE                 // floresta: corta as adultas...
    mov     w1, #O_PINE
    mov     w2, #Z_FOREST
    mov     w3, #WK_CHOP
    PF      s0, 76
    bl      ppl_findobj
    tbnz    w0, #31, 1f
    mov     w1, #WK_CHOP
    bl      ppl_gowork_obj
    b       7f
1:  bl      ppl_ensure_occ              // ... senao planta mudas
    mov     w0, #Z_FOREST
    mov     w1, #WK_SAPLING
    bl      ppl_findcell
    tbnz    w0, #31, 8f
    mov     w1, #WK_SAPLING
    bl      ppl_gowork_cell
    b       7f
2:  cmp     w21, #J_STONE
    b.ne    3f
    bl      pinv_cargo                  // de mochila vazia: veios primeiro
    cbnz    w0, 21f
    mov     w0, #O_IRONV                // sem zona: ate 40 celulas
    mov     w1, #O_COALV
    mov     w2, #0
    mov     w3, #WK_MINE
    PF      s0, 68
    bl      ppl_findobj
    tbz     w0, #31, 22f
21: mov     w0, #O_ROCK
    mov     w1, #O_ROCK
    mov     w2, #0
    mov     w3, #WK_MINE
    PF      s0, 68
    bl      ppl_findobj
    tbnz    w0, #31, 8f
22:
    mov     w1, #WK_MINE
    bl      ppl_gowork_obj
    b       7f
3:  cmp     w21, #J_FARM
    b.ne    4f
    bl      ppl_farmwork
    b       9f
4:  cmp     w21, #J_BUILD
    b.ne    5f
    bl      vila_buildwork              // obras (vila.S)
    b       9f
5:  cmp     w21, #J_SMITH
    b.ne    6f
    bl      smith_work                  // ferreiro (ferro.S)
    b       9f
6:  cmp     w21, #J_FISH
    b.ne    61f
    bl      fish_work                   // pescador (mochila.S)
    b       9f
61: cmp     w21, #J_SOLDIER
    b.ne    8f
    bl      soldier_patrol              // soldado (desafio.S)
    b       9f
7:  mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ppl_farmwork -> w0 = 1: colher > plantar (busca sementes) > arar
ppl_farmwork:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      ppl_findripe
    tbnz    w0, #31, 1f
    mov     w1, #WK_HARV
    bl      ppl_gowork_obj
    b       7f
1:  bl      ppl_ensure_occ
    mov     w0, #Z_FARM
    mov     w1, #WK_PLANT
    bl      ppl_findcell
    tbnz    w0, #31, 3f
    str     w0, [sp, #-16]!
    mov     w0, #IT_SEED
    bl      pinv_get
    mov     w9, w0
    ldr     w0, [sp], #16
    cbz     w9, 2f
    mov     w1, #WK_PLANT
    bl      ppl_gowork_cell
    b       7f
2:  mov     w0, #2                      // sem sementes: pega no bau
    bl      ppl_chestfind
    tbnz    w0, #31, 3f
    mov     w1, #NX_SEEDS
    bl      ppl_gochest
    b       7f
3:  mov     w0, #Z_FARM
    mov     w1, #WK_TILL
    bl      ppl_findcell
    tbnz    w0, #31, 8f
    mov     w1, #WK_TILL
    bl      ppl_gowork_cell
7:  mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldp     x29, x30, [sp], #16
    ret

// ppl_ensure_occ: a grade de ocupacao (cercas.S) feita neste quadro
ppl_ensure_occ:
    ldr     w9, [x28, #G_OCCFRAME]
    ldr     w10, [x28, #G_PPLFRAME]
    cmp     w9, w10
    b.eq    9f
    str     w10, [x28, #G_OCCFRAME]
    b       occ_build
9:  ret

// ppl_reserved(w0 = alvo, w1 = tipo) -> w0 = 1 se outra pessoa ja vai
// fazer esse trabalho (ou se esta pessoa nao conseguiu chegar la)   folha
    .globl ppl_reserved
ppl_reserved:
    ldr     w9, [x19, #P_SKIP]
    cmp     w9, w0
    b.ne    0f
    ldrb    w9, [x19, #P_SKIPK]
    cmp     w9, w1
    b.eq    7f
0:  LA      x9, people
    mov     w10, #0
1:  cmp     w10, #MAXPEOPLE
    b.ge    8f
    cmp     w10, w20
    b.eq    2f
    ldrb    w11, [x9, #P_ALIVE]
    cbz     w11, 2f
    ldr     w11, [x9, #P_TARGET]
    cmp     w11, w0
    b.ne    2f
    ldrb    w11, [x9, #P_WKIND]
    cmp     w11, w1
    b.ne    2f
    ldrb    w11, [x9, #P_STATE]
    cmp     w11, #ST_WORK
    b.eq    7f
    cmp     w11, #ST_WALK
    b.ne    2f
    ldrb    w11, [x9, #P_NEXT]
    cmp     w11, #NX_WORK
    b.eq    7f
2:  add     x9, x9, #PSIZE
    add     w10, w10, #1
    b       1b
7:  mov     w0, #1
    ret
8:  mov     w0, #0
    ret

// ppl_findobj(w0 tipo min, w1 tipo max, w2 zona (0 = qualquer), w3 tipo de
// trabalho, s0 distancia^2 maxima) -> w0 = objeto mais perto (com algo
// para tirar, livre) ou -1
ppl_findobj:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     x23, x24, [sp, #32]
    stp     x25, x26, [sp, #48]
    stp     d8, d9, [sp, #64]
    mov     w21, w0
    mov     w22, w1
    mov     w23, w2
    str     w3, [sp, #76]
    fmov    s8, s0
    mov     w26, #-1
    ldr     w24, [x28, #G_NOBJ]
    mov     w25, #0
1:  cmp     w25, w24
    b.ge    9f
    LA      x9, objs
    add     x9, x9, x25, lsl #3
    ldrb    w10, [x9, #6]
    cmp     w10, w21
    b.lo    5f
    cmp     w10, w22
    b.hi    5f
    ldrb    w10, [x9, #7]
    cbz     w10, 5f
    ldrh    w10, [x9]
    ldrh    w11, [x9, #2]
    cbz     w23, 2f
    lsr     w12, w10, #6
    lsr     w13, w11, #6
    add     w12, w12, w13, lsl #9
    LA      x13, zonegrid
    ldrb    w12, [x13, w12, uxtw]
    cmp     w12, w23
    b.ne    5f
2:  ucvtf   s0, w10
    ucvtf   s1, w11
    PF      s2, 40
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    ldr     s2, [x19, #P_U]
    fsub    s0, s0, s2
    ldr     s2, [x19, #P_V]
    fsub    s1, s1, s2
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fcmp    s0, s8
    b.ge    5f
    fmov    s9, s0
    mov     w0, w25
    ldr     w1, [sp, #76]
    bl      ppl_reserved
    cbnz    w0, 5f
    fmov    s8, s9
    mov     w26, w25
5:  add     w25, w25, #1
    b       1b
9:  mov     w0, w26
    ldp     d8, d9, [sp, #64]
    ldp     x25, x26, [sp, #48]
    ldp     x23, x24, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ppl_findripe -> w0 = trigo maduro mais perto numa zona de plantar (-1)
ppl_findripe:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     x23, x24, [sp, #32]
    stp     d8, d9, [sp, #48]
    PF      s8, 76
    mov     w23, #-1
    ldr     w21, [x28, #G_NCROP]
    mov     w22, #0
1:  cmp     w22, w21
    b.ge    9f
    LA      x9, croplist
    ldr     w24, [x9, x22, lsl #2]
    LA      x9, objs
    add     x9, x9, x24, lsl #3
    ldrb    w10, [x9, #6]
    cmp     w10, #O_CROP
    b.ne    5f
    ldrb    w10, [x9, #7]
    cmp     w10, #CROPRIPE
    b.lo    5f
    ldrh    w10, [x9]
    ldrh    w11, [x9, #2]
    lsr     w12, w10, #6
    lsr     w13, w11, #6
    add     w12, w12, w13, lsl #9
    LA      x13, zonegrid
    ldrb    w12, [x13, w12, uxtw]
    cmp     w12, #Z_FARM
    b.ne    5f
    ucvtf   s0, w10
    ucvtf   s1, w11
    PF      s2, 40
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    ldr     s2, [x19, #P_U]
    fsub    s0, s0, s2
    ldr     s2, [x19, #P_V]
    fsub    s1, s1, s2
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fcmp    s0, s8
    b.ge    5f
    fmov    s9, s0
    mov     w0, w24
    mov     w1, #WK_HARV
    bl      ppl_reserved
    cbnz    w0, 5f
    fmov    s8, s9
    mov     w23, w24
5:  add     w22, w22, #1
    b       1b
9:  mov     w0, w23
    ldp     d8, d9, [sp, #48]
    ldp     x23, x24, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ppl_findcell(w0 = zona, w1 = tipo de trabalho) -> w0 = celula mais perto
// (ate FINDR) da zona onde da para fazer aquilo (-1)
//   WK_PLANT: terra arada vazia; WK_TILL: chao para arar;
//   WK_SAPLING: chao livre (um quadrado sim, outro nao)
ppl_findcell:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     x23, x24, [sp, #32]
    stp     x25, x26, [sp, #48]
    stp     x27, x28, [sp, #64]
    str     w0, [sp, #80]               // zona
    str     w1, [sp, #84]               // tipo
    ldr     s0, [x19, #P_U]
    fcvtzs  w21, s0
    ldr     s0, [x19, #P_V]
    fcvtzs  w22, s0
    mov     w23, #-1                    // melhor celula
    mov     w24, #0x7FFFFFFF            // melhor distancia^2
    mov     w25, #-FINDR                // dv
1:  mov     w26, #-FINDR                // du
2:  mul     w9, w25, w25                // mais longe que o melhor: pula
    madd    w9, w26, w26, w9
    cmp     w9, w24
    b.ge    6f
    add     w10, w21, w26
    add     w11, w22, w25
    cmp     w10, #2
    b.lt    6f
    cmp     w11, #2
    b.lt    6f
    cmp     w10, #509
    b.gt    6f
    cmp     w11, #509
    b.gt    6f
    add     w27, w10, w11, lsl #9       // celula
    LA      x12, zonegrid
    ldrb    w12, [x12, w27, uxtw]
    ldr     w13, [sp, #80]
    cmp     w12, w13
    b.ne    6f
    LA      x12, occgrid
    ldrb    w12, [x12, w27, uxtw]
    cbnz    w12, 6f
    LA      x12, fencegrid
    ldrb    w12, [x12, w27, uxtw]
    cbnz    w12, 6f
    LA      x12, overlay
    ldrb    w12, [x12, w27, uxtw]
    ldr     w13, [sp, #84]
    cmp     w13, #WK_PLANT
    b.ne    3f
    cmp     w12, #2                     // plantar: terra arada
    b.lo    6f
    b       5f
3:  cmp     w12, #1                     // arar e mudas: chao sem nada
    b.hi    6f
    cmp     w13, #WK_TILL
    b.eq    4f
    add     w14, w10, w11               // mudas: um quadrado sim, outro nao
    tbnz    w14, #0, 6f
    cbnz    w12, 6f                     // (nem no caminho)
4:  LA      x12, elev                   // terra boa (nem praia, nem rocha)
    ldrsh   w12, [x12, w27, uxtw #1]
    ldr     w14, [x28, #G_FLOOD]
    cmp     w12, w14
    b.lt    6f
    cmp     w12, #(E_SAND + 20)
    b.lt    6f
    mov     w14, #E_ROCK
    cmp     w12, w14
    b.ge    6f
5:  mov     w0, w27
    ldr     w1, [sp, #84]
    str     w9, [sp, #88]
    bl      ppl_reserved
    ldr     w9, [sp, #88]
    cbnz    w0, 6f
    mov     w24, w9
    mov     w23, w27
6:  add     w26, w26, #1
    cmp     w26, #FINDR
    b.le    2b
    add     w25, w25, #1
    cmp     w25, #FINDR
    b.le    1b
    mov     w0, w23
    ldp     x27, x28, [sp, #64]
    ldp     x25, x26, [sp, #48]
    ldp     x23, x24, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// ppl_chestfind(w0 = 0 guardar, 1 comer, 2 sementes) -> w0 = celula do
// deposito para onde ir (-1)   (deposito.S)
    .globl ppl_chestfind
ppl_chestfind:
    b       dep_chestfind

// ppl_chestptr(w0 = celula) -> x0 = os contadores da "loja" em volta dela
// (0 se -1); quem mexe chama store_close depois   (deposito.S)
    .globl ppl_chestptr
ppl_chestptr:
    b       store_cell

// ---- ir ate um lugar ----

// ppl_gopoint(s0 = u, s1 = v): vai para do lado do ponto (0,6 celula)  folha
    .globl ppl_gopoint
ppl_gopoint:
    ldr     s2, [x19, #P_U]
    fsub    s2, s2, s0
    ldr     s3, [x19, #P_V]
    fsub    s3, s3, s1
    fmul    s4, s2, s2
    fmadd   s4, s3, s3, s4
    fsqrt   s4, s4
    PF      s5, 100
    fmax    s4, s4, s5
    PF      s5, 72
    fdiv    s5, s5, s4
    fmadd   s0, s2, s5, s0
    fmadd   s1, s3, s5, s1
    str     s0, [x19, #P_GU]
    str     s1, [x19, #P_GV]
    mov     w9, #ST_WALK
    strb    w9, [x19, #P_STATE]
    strh    wzr, [x19, #P_BLOCK]
    strh    wzr, [x19, #P_DET]
    ret

// ppl_goobj(w0 = objeto): vai para do lado dele   folha
ppl_goobj:
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrh    w10, [x9]
    ucvtf   s0, w10
    ldrh    w10, [x9, #2]
    ucvtf   s1, w10
    PF      s2, 40
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    b       ppl_gopoint

// ppl_gochest(w0 = celula do deposito, w1 = o que fazer la)
    .globl ppl_gochest
ppl_gochest:
    strb    w1, [x19, #P_NEXT]
    str     w0, [x19, #P_TARGET]
    strb    wzr, [x19, #P_WKIND]
    and     w9, w0, #511
    lsr     w10, w0, #9
    scvtf   s0, w9
    scvtf   s1, w10
    PF      s2, 96
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    b       ppl_gopoint

// ppl_gowork_obj(w0 = objeto, w1 = tipo de trabalho)
    .globl ppl_gowork_obj
ppl_gowork_obj:
    str     w0, [x19, #P_TARGET]
    strb    w1, [x19, #P_WKIND]
    mov     w9, #NX_WORK
    strb    w9, [x19, #P_NEXT]
    b       ppl_goobj

// ppl_gowork_cell(w0 = celula, w1 = tipo de trabalho)
ppl_gowork_cell:
    str     w0, [x19, #P_TARGET]
    strb    w1, [x19, #P_WKIND]
    mov     w9, #NX_WORK
    strb    w9, [x19, #P_NEXT]
    and     w9, w0, #511
    lsr     w10, w0, #9
    scvtf   s0, w9
    scvtf   s1, w10
    PF      s2, 96
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    b       ppl_gopoint

// ppl_wander: passeia um pouco (longe do bau: volta para perto dele)
ppl_wander:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     d8, d9, [sp, #32]
    stp     d10, d11, [sp, #48]
    ldr     s8, [x19, #P_U]
    ldr     s9, [x19, #P_V]
    bl      dep_home                    // perto do deposito
    tbnz    w0, #31, 1f
    and     w9, w0, #511
    lsr     w10, w0, #9
    scvtf   s0, w9
    scvtf   s1, w10
    PF      s2, 96
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    fsub    s2, s0, s8
    fsub    s3, s1, s9
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    PF      s3, 136                     // 12 celulas^2
    fcmp    s2, s3
    b.le    1f
    fmov    s8, s0
    fmov    s9, s1
1:  mov     w21, #0
2:  mov     w0, #7
    bl      rng_mod
    sub     w0, w0, #3
    scvtf   s10, w0
    mov     w0, #7
    bl      rng_mod
    sub     w0, w0, #3
    scvtf   s11, w0
    fadd    s10, s10, s8
    fadd    s11, s11, s9
    fmov    s0, s10
    fmov    s1, s11
    bl      ppl_land
    cbnz    w0, 3f
    add     w21, w21, #1
    cmp     w21, #4
    b.lt    2b
    mov     w9, #ST_WAIT
    strb    w9, [x19, #P_STATE]
    mov     w9, #60
    strh    w9, [x19, #P_TIMER]
    b       9f
3:  str     s10, [x19, #P_GU]
    str     s11, [x19, #P_GV]
    strb    wzr, [x19, #P_NEXT]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
    mov     w9, #ST_WALK
    strb    w9, [x19, #P_STATE]
    strh    wzr, [x19, #P_BLOCK]
9:  ldp     d10, d11, [sp, #48]
    ldp     d8, d9, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ppl_gosleep: cabana mais perto; senao a fogueira acesa; senao ali mesmo
ppl_gosleep:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     d8, d9, [sp, #32]
    LA      x9, fams                    // a casa da familia
    ldrb    w10, [x19, #P_FAM]
    add     x9, x9, x10, lsl #5
    ldr     w21, [x9, #F_HOUSE]
    tbnz    w21, #31, 0f
    LA      x10, objs
    add     x10, x10, x21, lsl #3
    ldrb    w11, [x10, #6]
    cmp     w11, #O_HUT
    b.lo    0f
    cmp     w11, #O_HOUSE
    b.ls    3f
0:  mov     w21, #-1
    PF      s8, 120                     // ate 30 celulas
    ldr     w22, [x28, #G_NOBJ]
    mov     w9, #0
1:  cmp     w9, w22
    b.ge    3f
    LA      x10, objs
    add     x10, x10, x9, lsl #3
    ldrb    w11, [x10, #6]
    cmp     w11, #O_SHELTER
    b.ne    2f
    ldrh    w11, [x10]
    ucvtf   s0, w11
    ldrh    w11, [x10, #2]
    ucvtf   s1, w11
    PF      s2, 40
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    ldr     s2, [x19, #P_U]
    fsub    s0, s0, s2
    ldr     s2, [x19, #P_V]
    fsub    s1, s1, s2
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fcmp    s0, s8
    b.ge    2f
    fmov    s8, s0
    mov     w21, w9
2:  add     w9, w9, #1
    b       1b
3:  tbnz    w21, #31, 4f
    LA      x10, objs                   // entra na cabana
    add     x10, x10, x21, lsl #3
    ldrh    w11, [x10]
    ucvtf   s0, w11
    ldrh    w11, [x10, #2]
    ucvtf   s1, w11
    PF      s2, 40
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    str     s0, [x19, #P_GU]
    str     s1, [x19, #P_GV]
    str     w21, [x19, #P_TARGET]
    b       7f
4:  mov     w21, #-1                    // fogueira acesa mais perto
    PF      s8, 120
    ldr     w22, [x28, #G_NFIRE]
    mov     w9, #0
    LA      x10, fires
5:  cmp     w9, w22
    b.ge    6f
    ldr     w11, [x10, #12]
    cbz     w11, 51f
    ldr     s0, [x10]
    ldr     s2, [x19, #P_U]
    fsub    s0, s0, s2
    ldr     s1, [x10, #4]
    ldr     s2, [x19, #P_V]
    fsub    s1, s1, s2
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fcmp    s0, s8
    b.ge    51f
    fmov    s8, s0
    mov     w21, w9
51: add     x10, x10, #16
    add     w9, w9, #1
    b       5b
6:  tbnz    w21, #31, 8f
    LA      x10, fires                  // deita em volta do fogo
    add     x10, x10, x21, lsl #4
    and     w9, w20, #7
    LA      x11, ring8
    add     x11, x11, x9, lsl #3
    ldr     s0, [x10]
    ldr     s2, [x11]
    fadd    s0, s0, s2
    ldr     s1, [x10, #4]
    ldr     s2, [x11, #4]
    fadd    s1, s1, s2
    str     s0, [x19, #P_GU]
    str     s1, [x19, #P_GV]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
7:  mov     w9, #NX_SLEEP
    strb    w9, [x19, #P_NEXT]
    strb    wzr, [x19, #P_WKIND]
    mov     w9, #ST_WALK
    strb    w9, [x19, #P_STATE]
    strh    wzr, [x19, #P_BLOCK]
    strh    wzr, [x19, #P_DET]
    b       9f
8:  mov     w9, #ST_SLEEP               // sem cabana nem fogo: ali mesmo
    strb    w9, [x19, #P_STATE]
9:  ldp     d8, d9, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// =====================================================================
//  Andar
// =====================================================================

// ppl_walk -> w0 = 1 chegou
    .globl ppl_walk
ppl_walk:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     d8, d9, [sp, #16]
    stp     d10, d11, [sp, #32]
    ldrb    w9, [x19, #P_FLAGS]         // saiu da cabana
    bic     w9, w9, #1
    strb    w9, [x19, #P_FLAGS]
    ldr     s0, [x19, #P_GU]
    ldr     s1, [x19, #P_U]
    fsub    s8, s0, s1
    ldr     s0, [x19, #P_GV]
    ldr     s1, [x19, #P_V]
    fsub    s9, s0, s1
    fmul    s10, s8, s8
    fmadd   s10, s9, s9, s10
    PF      s2, 48
    fcmp    s10, s2
    b.gt    1f
    mov     w0, #1
    b       99f
1:  fsqrt   s10, s10
    PF      s11, 24                     // adulto, crianca, fugindo
    ldrh    w9, [x19, #P_AGE]
    cmp     w9, #ADULTDAYS
    b.hs    2f
    PF      s11, 28
2:  ldrb    w9, [x19, #P_STATE]
    cmp     w9, #ST_FLEE
    b.eq    21f
    cmp     w9, #ST_FIGHT               // soldado lutando: corre
    b.ne    3f
21: PF      s11, 32
3:  ldr     s0, [x19, #P_U]             // caminho de terra batida: mais rapido
    fcvtzs  w9, s0
    ldr     s0, [x19, #P_V]
    fcvtzs  w10, s0
    add     w9, w9, w10, lsl #9
    LA      x10, overlay
    ldrb    w9, [x10, w9, uxtw]
    cmp     w9, #1
    b.ne    4f
    PF      s0, 36
    fmul    s11, s11, s0
4:  fmin    s11, s11, s10
    fdiv    s0, s11, s10
    fmul    s8, s8, s0
    fmul    s9, s9, s0
    ldrh    w9, [x19, #P_DET]           // desviando: anda de lado
    cbz     w9, 5f
    sub     w9, w9, #1
    strh    w9, [x19, #P_DET]
    fneg    s0, s9
    fmov    s1, s8
    ldrb    w10, [x19, #P_FLAGS]
    tbz     w10, #2, 41f
    fneg    s0, s0
    fneg    s1, s1
41: fmov    s8, s0
    fmov    s9, s1
5:  fmov    s0, s8
    fmov    s1, s9
    bl      ppl_trymove
    cbnz    w0, 7f
    fmov    s0, s8
    fmov    s1, wzr
    bl      ppl_trymove
    cbnz    w0, 7f
    fmov    s0, wzr
    fmov    s1, s9
    bl      ppl_trymove
    cbnz    w0, 7f
    fmov    s0, #1.0                    // travou ja do lado: serve
    fcmp    s10, s0
    b.ge    51f
    strh    wzr, [x19, #P_BLOCK]
    mov     w0, #1
    b       99f
51: ldrh    w9, [x19, #P_BLOCK]         // travou: desvia por um lado
    add     w9, w9, #1
    strh    w9, [x19, #P_BLOCK]
    mov     w10, #40
    strh    w10, [x19, #P_DET]
    tst     w9, #63                     // demorou: tenta o outro lado
    b.ne    6f
    ldrb    w10, [x19, #P_FLAGS]
    eor     w10, w10, #4
    strb    w10, [x19, #P_FLAGS]
6:  cmp     w9, #300                    // desiste (e nao tenta esse de novo)
    b.lo    8f
    ldr     w10, [x19, #P_TARGET]
    str     w10, [x19, #P_SKIP]
    ldrb    w10, [x19, #P_WKIND]
    strb    w10, [x19, #P_SKIPK]
    strh    wzr, [x19, #P_BLOCK]
    strh    wzr, [x19, #P_DET]
    mov     w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    mov     w9, #60
    strh    w9, [x19, #P_THINK]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
    b       8f
7:  ldrh    w9, [x19, #P_BLOCK]
    cbz     w9, 8f
    sub     w9, w9, #1
    strh    w9, [x19, #P_BLOCK]
8:  mov     w0, #0
99: ldp     d10, d11, [sp, #32]
    ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ppl_trymove(s0 = du, s1 = dv) -> w0 = 1 andou (nao entra na agua nem
// passa por cerca; portao passa)
ppl_trymove:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     d8, d9, [sp, #16]
    str     x21, [sp, #32]
    ldr     s2, [x19, #P_U]
    fadd    s8, s2, s0
    ldr     s2, [x19, #P_V]
    fadd    s9, s2, s1
    fmov    s0, s8
    fmov    s1, s9
    bl      ppl_land
    cbz     w0, 9f
    ldr     s0, [x19, #P_U]             // celula de antes
    fcvtzs  w9, s0
    ldr     s0, [x19, #P_V]
    fcvtzs  w10, s0
    add     w21, w9, w10, lsl #9
    str     s8, [x19, #P_U]
    str     s9, [x19, #P_V]
    ldrh    w9, [x19, #P_ANIM]
    add     w9, w9, #1
    strh    w9, [x19, #P_ANIM]
    fcvtzs  w9, s8
    fcvtzs  w10, s9
    add     w0, w9, w10, lsl #9
    cmp     w0, w21
    b.eq    8f
    bl      path_step                   // entrou noutra celula
8:  mov     w0, #1
9:  ldr     x21, [sp, #32]
    ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// =====================================================================
//  Chegou / trabalho
// =====================================================================

ppl_arrive:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldrb    w9, [x19, #P_NEXT]
    strb    wzr, [x19, #P_NEXT]
    cmp     w9, #NX_WORK
    b.ne    1f
    mov     w9, #NX_WORK                // (ppl_startwork confere de novo)
    strb    w9, [x19, #P_NEXT]
    bl      ppl_startwork
    b       9f
1:  cmp     w9, #NX_DEPOSIT
    b.ne    2f
    bl      ppl_deposit
    b       8f
2:  cmp     w9, #NX_EAT
    b.ne    3f
    bl      ppl_eat
    b       8f
3:  cmp     w9, #NX_SEEDS
    b.ne    31f
    bl      ppl_takeseeds
    b       8f
31: cmp     w9, #NX_PAY                 // obras: paga no bau e vai ao terreno
    b.ne    32f
    bl      vila_pay
    b       9f
32: cmp     w9, #NX_SMITH               // ferreiro: material e fornalha
    b.ne    33f
    bl      smith_pay
    b       9f
33: cmp     w9, #NX_TOOL                // pega a ferramenta de ferro
    b.ne    4f
    bl      tool_take
    b       8f
4:  cmp     w9, #NX_SLEEP
    b.ne    5f
    ldr     w0, [x19, #P_TARGET]        // na cabana: some (dentro dela)
    tbnz    w0, #31, 41f
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrb    w10, [x9, #6]
    cmp     w10, #O_SHELTER
    b.eq    40f
    cmp     w10, #O_HUT
    b.lo    41f
    cmp     w10, #O_HOUSE
    b.hi    41f
40: ldrb    w9, [x19, #P_FLAGS]
    orr     w9, w9, #1
    strb    w9, [x19, #P_FLAGS]
41: mov     w9, #ST_SLEEP
    strb    w9, [x19, #P_STATE]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
    b       9f
5:  mov     w9, #ST_WAIT                // chegou num passeio ou numa ordem
    strb    w9, [x19, #P_STATE]
    mov     w0, #120
    bl      rng_mod
    add     w0, w0, #60
    strh    w0, [x19, #P_TIMER]
    b       9f
8:  mov     w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    mov     w9, #10
    strh    w9, [x19, #P_THINK]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
9:  ldp     x29, x30, [sp], #16
    ret

// ppl_valid(w0 = alvo, w1 = tipo) -> w0 = 1 se ainda da para fazer
ppl_valid:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    mov     w21, w0
    mov     w22, w1
    tbnz    w21, #31, 8f
    cmp     w22, #WK_BUILD
    b.ne    61f
    bl      vila_valid
    b       9f
61: cmp     w22, #WK_SMELT
    b.ne    62f
    bl      smith_valid
    b       9f
62: cmp     w22, #WK_FISH
    b.ne    1f
    bl      fish_valid
    b       9f
1:  cmp     w22, #WK_PLANT
    b.eq    30f
    cmp     w22, #WK_TILL
    b.eq    40f
    cmp     w22, #WK_SAPLING
    b.eq    40f
    LA      x9, objs                    // objeto
    add     x9, x9, x21, lsl #3
    ldrb    w10, [x9, #6]
    ldrb    w11, [x9, #7]
    cmp     w22, #WK_CHOP
    b.ne    1f
    cmp     w10, #O_PINE
    b.hi    8f
    cbz     w11, 8f
    b       7f
1:  cmp     w22, #WK_MINE
    b.ne    2f
    cmp     w10, #O_ROCK
    b.eq    11f
    cmp     w10, #O_IRONV
    b.lo    8f
    cmp     w10, #O_COALV
    b.hi    8f
11: cbz     w11, 8f
    b       7f
2:  cmp     w22, #WK_HARV
    b.ne    3f
    cmp     w10, #O_CROP
    b.ne    8f
    cmp     w11, #CROPRIPE
    b.lo    8f
    b       7f
3:  cmp     w10, #O_BUSH                // frutas
    b.ne    8f
    cbz     w11, 8f
    b       7f
30: LA      x9, overlay                 // plantar: arada e vazia
    ldrb    w9, [x9, w21, uxtw]
    cmp     w9, #2
    b.lo    8f
    mov     w0, w21
    bl      obj_in_cell
    tbz     w0, #31, 8f
    b       7f
40: LA      x9, overlay                 // arar / muda: chao sem nada
    ldrb    w9, [x9, w21, uxtw]
    cmp     w9, #1
    b.hi    8f
    LA      x9, fencegrid
    ldrb    w9, [x9, w21, uxtw]
    cbnz    w9, 8f
    mov     w0, w21
    bl      obj_in_cell
    tbz     w0, #31, 8f
7:  mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ppl_startwork: comeca (o tempo depende da fe: 50% a 150%)
ppl_startwork:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    ldr     w0, [x19, #P_TARGET]
    ldrb    w1, [x19, #P_WKIND]
    mov     w22, w1
    bl      ppl_valid
    cbz     w0, 8f
    LA      x9, worktime
    ldrh    w9, [x9, x22, lsl #1]
    ldr     s0, [x19, #P_FAITH]
    fcvtzs  w10, s0
    add     w10, w10, #50
    mov     w11, #100
    mul     w9, w9, w11
    udiv    w9, w9, w10
    mov     w21, w9
    bl      tool_bonus                  // ferramenta de ferro: 2x
    lsr     w9, w21, w0
    strh    w9, [x19, #P_TIMER]
    mov     w9, #ST_WORK
    strb    w9, [x19, #P_STATE]
    b       9f
8:  mov     w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    strh    wzr, [x19, #P_THINK]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
    strb    wzr, [x19, #P_NEXT]
9:  ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ppl_workdone: terminou um pedaco do trabalho
ppl_workdone:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     x23, x24, [sp, #32]
    ldr     w21, [x19, #P_TARGET]
    ldrb    w22, [x19, #P_WKIND]
    mov     w0, w21
    mov     w1, w22
    bl      ppl_valid
    cbz     w0, 80f
    cmp     w22, #WK_SMELT              // fornalha: barra (ou carvao) pronta
    b.ne    68f
    bl      smith_done
    b       79f
68: cmp     w22, #WK_FISH               // pescou: continua ate encher
    b.ne    69f
    bl      fish_done
    bl      pinv_cargo
    LA      x13, jobcap
    mov     w12, #J_FISH
    ldrb    w13, [x13, x12]
    cmp     w0, w13
    b.hs    79f
    bl      ppl_startwork
    b       99f
69: cmp     w22, #WK_BUILD              // obra: mais um passo
    b.ne    10f
    mov     w0, w21
    bl      vila_step
    cbnz    w0, 79f
    bl      ppl_startwork
    b       99f
10: cmp     w22, #WK_MINE
    b.hi    20f
    // ---- madeira / pedra ----
    LA      x9, objs
    add     x23, x9, x21, lsl #3
    ldrb    w9, [x23, #7]
    sub     w9, w9, #1
    strb    w9, [x23, #7]
    mov     w10, #(IT_WOOD + 1)
    cmp     w22, #WK_CHOP
    b.eq    11f
    mov     w10, #(IT_STONE + 1)
    ldrb    w11, [x23, #6]              // veio: minerio ou carvao
    cmp     w11, #O_IRONV
    mov     w12, #(IT_ORE + 1)
    csel    w10, w12, w10, eq
    cmp     w11, #O_COALV
    mov     w12, #(IT_COAL + 1)
    csel    w10, w12, w10, eq
11: str     w9, [sp, #-16]!
    sub     w0, w10, #1                 // na mochila
    mov     w1, #1
    bl      pinv_add
    bl      pinv_cargo
    mov     w11, w0
    ldr     w9, [sp], #16
    cbnz    w9, 13f
    ldrb    w12, [x23, #6]              // acabou: some
    mov     w13, #O_GONE
    strb    w13, [x23, #6]
    cmp     w12, #O_PINE                // arvore: deixa de tapar a visao
    b.ls    16f
    mov     x0, x23                     // pedreira ou veio: vira buraco
    mov     w1, w12
    bl      quarry_done
    b       78f
16:
    ldrh    w13, [x23]
    lsr     w13, w13, #6
    ldrh    w14, [x23, #2]
    lsr     w14, w14, #6
    add     w13, w13, w14, lsl #9
    LA      x14, treecnt
    ldrb    w15, [x14, w13, uxtw]
    cbz     w15, 14f
    sub     w15, w15, #1
    strb    w15, [x14, w13, uxtw]
14: LA      x14, zonegrid               // na floresta: planta uma muda no lugar
    ldrb    w15, [x14, w13, uxtw]
    cmp     w15, #Z_FOREST
    b.ne    79f
    mov     w0, w13
    bl      ppl_sapling_at
    b       78f
13: ldrb    w12, [x19, #P_JOB]          // ainda cabe: continua
    LA      x13, jobcap
    ldrb    w13, [x13, x12]
    cmp     w11, w13
    b.hs    79f
    bl      ppl_startwork
    b       99f
    // ---- colhe o trigo maduro e replanta ali ----
20: cmp     w22, #WK_HARV
    b.ne    30f
    LA      x9, objs
    add     x23, x9, x21, lsl #3
    mov     w9, #O_GONE
    strb    w9, [x23, #6]
    mov     w0, #2
    bl      rng_mod
    add     w24, w0, #1
    mov     w0, #IT_WHEAT
    mov     w1, w24
    bl      pinv_add
    mov     w0, #2
    bl      rng_mod
    add     w1, w0, #1
    mov     w0, #IT_SEED
    bl      pinv_add
    ldrh    w9, [x23]
    lsr     w9, w9, #6
    ldrh    w10, [x23, #2]
    lsr     w10, w10, #6
    add     w0, w9, w10, lsl #9
    bl      plant_at
    mov     w0, #IT_SEED
    mov     w1, #-1
    bl      pinv_add
    b       78f
30: cmp     w22, #WK_PLANT
    b.ne    40f
    mov     w0, #IT_SEED
    bl      pinv_get
    cbz     w0, 79f
    mov     w0, #IT_SEED
    mov     w1, #-1
    bl      pinv_add
    mov     w0, w21
    bl      plant_at
    b       78f
40: cmp     w22, #WK_TILL
    b.ne    50f
    mov     w0, w21
    bl      farm_wet
    add     w0, w0, #2
    LA      x9, overlay
    strb    w0, [x9, w21, uxtw]
    b       78f
50: cmp     w22, #WK_SAPLING
    b.ne    60f
    mov     w0, w21
    bl      ppl_sapling_at
    b       78f
    // ---- frutas (com fome) ----
60: LA      x9, objs
    add     x23, x9, x21, lsl #3
    ldrb    w9, [x23, #7]
    sub     w9, w9, #1
    strb    w9, [x23, #7]
    cbnz    w9, 61f
    mov     w10, #O_BUSHE
    strb    w10, [x23, #6]
61: ldr     s0, [x19, #P_FOOD]
    PF      s1, 128
    fadd    s0, s0, s1
    PF      s1, 44
    fmin    s0, s0, s1
    str     s0, [x19, #P_FOOD]
    cbz     w9, 79f
    PF      s1, 124
    fcmp    s0, s1
    b.ge    79f
    bl      ppl_startwork
    b       99f
78: mov     w9, #-1                     // o chao mudou: refaz a ocupacao
    str     w9, [x28, #G_OCCFRAME]
79: mov     w9, #-1
    str     w9, [x19, #P_TARGET]
80: mov     w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    mov     w9, #5
    strh    w9, [x19, #P_THINK]
    strb    wzr, [x19, #P_NEXT]
99: ldp     x23, x24, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ppl_sapling_at(w0 = celula): planta uma muda no meio da celula (se
// estiver livre)
ppl_sapling_at:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x21, [sp, #16]
    mov     w21, w0
    LA      x9, fencegrid
    ldrb    w9, [x9, w21, uxtw]
    cbnz    w9, 9f
    bl      obj_in_cell
    tbz     w0, #31, 9f
    and     w9, w21, #511
    lsr     w10, w21, #9
    scvtf   s0, w9
    scvtf   s1, w10
    PF      s2, 96
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      elev_at
    mov     w2, w0
    and     w9, w21, #511
    lsl     w0, w9, #6
    add     w0, w0, #32
    lsr     w9, w21, #9
    lsl     w1, w9, #6
    add     w1, w1, #32
    mov     w3, #O_SAPLING
    mov     w4, #0
    bl      add_obj
    ldr     w0, [x28, #G_NOBJ]
    sub     w0, w0, #1
    LA      x9, memtype
    mov     w10, #O_SAPLING
    strb    w10, [x9, w0, uxtw]
9:  ldr     x21, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ppl_deposit: poe no bau o que carrega (e as sementes que sobram de 10)
ppl_deposit:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w0, [x19, #P_TARGET]
    bl      ppl_chestptr
    cbz     x0, 9f
    str     x0, [sp, #-16]!
    bl      pinv_deposit                // tudo menos ferramenta, lanche, sementes
    ldr     x0, [sp], #16
    bl      pinv_takefood               // e repoe o lanche
    bl      store_close_back            // empilha; o que nao coube volta
9:  ldp     x29, x30, [sp], #16
    ret

// ppl_eat: come do bau (o que enche mais primeiro) ate ficar bem
ppl_eat:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    mov     x21, #0
    ldr     w0, [x19, #P_TARGET]
    bl      ppl_chestptr
    cbz     x0, 9f
    mov     x21, x0
1:  ldr     s0, [x19, #P_FOOD]
    PF      s1, 124
    fcmp    s0, s1
    b.ge    9f
    LA      x9, eatorder
    mov     w22, #0
2:  ldrb    w10, [x9, x22]
    ldr     w11, [x21, x10, lsl #2]
    cbnz    w11, 3f
    add     w22, w22, #1
    cmp     w22, #7
    b.lo    2b
    b       9f
3:  sub     w11, w11, #1
    str     w11, [x21, x10, lsl #2]
    LA      x12, eatvalue
    ldr     s1, [x12, x10, lsl #2]
    fadd    s0, s0, s1
    PF      s1, 44
    fmin    s0, s0, s1
    str     s0, [x19, #P_FOOD]
    b       1b
9:  cbz     x21, 91f                    // e leva um lanche
    mov     x0, x21
    bl      pinv_takefood
    bl      store_close
91: ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ppl_takeseeds: pega sementes no bau (ate ficar com 10)
ppl_takeseeds:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w0, [x19, #P_TARGET]
    bl      ppl_chestptr
    cbz     x0, 9f
    mov     x12, x0
    mov     w0, #IT_SEED
    bl      pinv_get
    mov     w9, w0
    mov     w10, #10
    subs    w10, w10, w9
    b.ls    9f
    ldr     w11, [x12, #(4 * IT_SEED)]
    cmp     w11, w10
    csel    w10, w11, w10, lo
    sub     w11, w11, w10
    str     w11, [x12, #(4 * IT_SEED)]
    mov     w0, #IT_SEED
    mov     w1, w10
    bl      pinv_add
    bl      store_close
9:  ldp     x29, x30, [sp], #16
    ret

// =====================================================================
//  Lobos e ursos atacam pessoas tambem (chamado por animais.S)
// =====================================================================

// beast_people(x0 = animal, x1 = tipo do animal, s0 = distancia^2 ate o
// personagem) -> w0 = 0 (cuida do personagem), 1 (indo atras de uma
// pessoa), 2 (mordeu / parado)
    .globl beast_people
beast_people:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    stp     d10, d11, [sp, #64]
    stp     d12, d13, [sp, #80]
    mov     x21, x0
    mov     x22, x1
    fmov    s12, s0
    ldr     w9, [x28, #G_NOPEOPLE]
    cbnz    w9, 90f
    ldrb    w9, [x22, #6]               // raio de alerta
    scvtf   s13, w9
    ldr     w9, [x28, #G_NIGHTK]        // de dia, so de perto
    cmp     w9, #128
    b.ge    1f
    PF      s1, 96
    fmul    s13, s13, s1
1:  ldrb    w9, [x21, #17]              // ferido: furioso
    ldrb    w10, [x22, #0]
    cmp     w9, w10
    b.ge    2f
    PF      s13, 80
2:  fmul    s13, s13, s13
    ldr     w9, [x28, #G_DEAD]          // o personagem nao conta se esta
    cbnz    w9, 3f                      // protegido (fogo, cabana) ou morto
    ldr     w9, [x28, #G_NEARFIRE]
    cbnz    w9, 3f
    ldr     w9, [x28, #G_INSHELTER]
    cbz     w9, 4f
3:  PF      s12, 76
4:  mov     w20, #-1
    fmov    s11, s13
    LA      x9, people
    mov     w10, #0
    ldr     s0, [x21, #0]
    ldr     s1, [x21, #4]
5:  cmp     w10, #MAXPEOPLE
    b.ge    7f
    ldrb    w11, [x9, #P_ALIVE]
    cbz     w11, 6f
    ldrb    w11, [x9, #P_FLAGS]         // na cabana ou perto do fogo: seguro
    tst     w11, #3
    b.ne    6f
    ldr     s2, [x9, #P_U]
    fsub    s2, s2, s0
    ldr     s3, [x9, #P_V]
    fsub    s3, s3, s1
    fmul    s4, s2, s2
    fmadd   s4, s3, s3, s4
    fcmp    s4, s11
    b.ge    6f
    fmov    s11, s4
    fmov    s8, s2
    fmov    s9, s3
    mov     w20, w10
6:  add     x9, x9, #PSIZE
    add     w10, w10, #1
    b       5b
7:  tbnz    w20, #31, 90f
    fcmp    s11, s12                    // o personagem esta mais perto
    b.ge    90f
    fsqrt   s10, s11
    fmov    s2, #1.0
    fcmp    s10, s2
    b.ge    8f
    str     wzr, [x21, #8]              // chegou: morde
    str     wzr, [x21, #12]
    ldrh    w9, [x21, #22]
    cbnz    w9, 89f
    mov     w9, #60
    strh    w9, [x21, #22]
    LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x22, #4]
    scvtf   s0, w9
    LA      x9, pinv                    // armadura na mochila: metade
    add     x9, x9, x20, lsl #8
    ldr     w9, [x9, #(4 * IT_ARMOR)]
    cbz     w9, 88f
    fmov    s1, #0.5
    fmul    s0, s0, s1
88: ldr     s1, [x19, #P_HP]
    fsub    s1, s1, s0
    str     s1, [x19, #P_HP]
    fcmp    s1, #0.0
    b.gt    89f
    mov     w0, #CAUSE_BICHO
    bl      ppl_die
89: mov     w0, #2
    b       99f
8:  ldr     s2, [x22, #12]              // corre atras
    fdiv    s2, s2, s10
    fmul    s0, s8, s2
    fmul    s1, s9, s2
    str     s0, [x21, #8]
    str     s1, [x21, #12]
    mov     w0, #1
    b       99f
90: mov     w0, #0
99: ldp     d12, d13, [sp, #80]
    ldp     d10, d11, [sp, #64]
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// =====================================================================
//  Desenho no mundo
// =====================================================================

// people_draw(w0 = escala dos sprites)
    .globl people_draw
people_draw:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
    ldr     w9, [x28, #G_NOPEOPLE]
    cbnz    w9, 9f
    mov     w21, w0
    mov     w20, #0
1:  cmp     w20, #MAXPEOPLE
    b.ge    9f
    LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 8f
    ldrb    w9, [x19, #P_FLAGS]         // dentro da cabana
    tbnz    w9, #0, 8f
    ldr     s0, [x19, #P_U]             // so o que esta a vista
    fcvtzs  w9, s0
    ldr     s0, [x19, #P_V]
    fcvtzs  w10, s0
    add     w9, w9, w10, lsl #9
    LA      x10, vis
    ldrb    w9, [x10, w9, uxtw]
    cmp     w9, #VIS_MIN
    b.lo    8f
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    csel    w0, w9, w0, lt
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    bl      proj
    mov     w22, w0                     // x
    mov     w23, w1                     // y
    add     w24, w2, #24                // profundidade
    cmp     w21, #2                     // perto: o desenho grande (personagens.S)
    b.lt    40f
    LA      x9, plast                   // direcao: para onde andou
    add     x9, x9, x20, lsl #3
    ldp     s2, s3, [x9]
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    stp     s0, s1, [x9]
    fsub    s0, s0, s2
    fsub    s1, s1, s3
    LA      x25, pdirs
    ldrb    w0, [x25, x20]
    bl      char_dir
    strb    w0, [x25, x20]
    mov     w1, w0
    mov     w2, #0                      // pose: parado ou o passo
    ldrb    w10, [x19, #P_STATE]
    cmp     w10, #ST_WALK
    b.eq    41f
    cmp     w10, #ST_FLEE
    b.ne    42f
41: ldrh    w10, [x19, #P_ANIM]
    lsr     w10, w10, #3
    and     w10, w10, #3
    LA      x11, poseseq
    ldrb    w2, [x11, x10]
42: ldrh    w10, [x19, #P_AGE]          // homem, mulher, menino ou menina
    ldrb    w11, [x19, #P_SEX]
    mov     w0, #2
    mov     w12, #4
    cmp     w10, #ADULTDAYS
    csel    w0, w0, w12, hs
    add     w0, w0, w11
    bl      char_ptr
    lsr     w3, w21, #1                 // metade da escala, o dobro de detalhe
    b       43f
40: mov     w9, #SPR_KID                // sprite: crianca, homem ou mulher
    ldrh    w10, [x19, #P_AGE]
    cmp     w10, #ADULTDAYS
    b.lo    2f
    mov     w9, #SPR_MAN
    ldrb    w10, [x19, #P_SEX]
    cbz     w10, 2f
    mov     w9, #SPR_WOMAN
2:  ldrb    w10, [x19, #P_STATE]        // andando: as pernas mexem
    cmp     w10, #ST_WALK
    b.eq    3f
    cmp     w10, #ST_FLEE
    b.ne    4f
3:  ldrh    w10, [x19, #P_ANIM]
    lsr     w10, w10, #3
    and     w10, w10, #1
    add     w9, w9, w10
4:  LA      x0, sprites
    add     x0, x0, x9, lsl #7
    mov     w3, w21
43: mov     w1, w22
    mov     w2, w23
    mov     w4, w24
    LA      x9, fams                    // cor da roupa: a da familia
    ldrb    w10, [x19, #P_FAM]
    add     x9, x9, x10, lsl #5
    ldrb    w5, [x9, #F_VAR]
    bl      blit
    ldr     w9, [x28, #G_SELPERS]       // selecionada: setinha em cima
    cmp     w9, w20
    b.ne    8f
    LA      x0, sprites
    add     x0, x0, #(SPR_MARK * 128) & 0xFFF
    add     x0, x0, #((SPR_MARK * 128) >> 12), lsl #12
    mov     w1, w22
    mov     w9, #12
    msub    w2, w21, w9, w23
    mov     w3, w21
    add     w4, w24, #8
    mov     w5, #0
    bl      blit
8:  add     w20, w20, #1
    b       1b
9:  ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// person_at(w0 = u, w1 = v em 1/64) -> w0 = pessoa sob o mouse (-1)   folha
    .globl person_at
person_at:
    mov     w9, #-1
    ldr     w10, [x28, #G_NOPEOPLE]
    cbnz    w10, 9f
    scvtf   s0, w0
    scvtf   s1, w1
    PF      s2, 40
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    PF      s4, 64                      // ate 0,8 celula
    LA      x10, people
    mov     w11, #0
1:  cmp     w11, #MAXPEOPLE
    b.ge    9f
    ldrb    w12, [x10, #P_ALIVE]
    cbz     w12, 2f
    ldrb    w12, [x10, #P_FLAGS]
    tbnz    w12, #0, 2f
    ldr     s2, [x10, #P_U]
    fsub    s2, s2, s0
    ldr     s3, [x10, #P_V]
    fsub    s3, s3, s1
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    fcmp    s2, s4
    b.ge    2f
    fmov    s4, s2
    mov     w9, w11
2:  add     x10, x10, #PSIZE
    add     w11, w11, #1
    b       1b
9:  mov     w0, w9
    ret

// person_desc(x0 = cursor, w1 = pessoa) -> x0:
// "Ana Silva, 27 anos - Madeira | fe 62%"
    .globl person_desc
person_desc:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w20, w1
    LA      x9, people
    add     x19, x9, x20, lsl #6
    bl      ppl_namecat
    LA      x1, s_comma
    bl      strcat_cur
    ldrh    w9, [x19, #P_AGE]
    mov     w10, #12
    udiv    w1, w9, w10
    bl      numcat
    LA      x1, s_anos
    bl      strcat_cur
    LA      x1, s_kid
    ldrh    w9, [x19, #P_AGE]
    cmp     w9, #ADULTDAYS
    b.lo    1f
    LA      x1, jobnames
    ldrb    w9, [x19, #P_JOB]
    add     x1, x1, x9, lsl #4
1:  bl      strcat_cur
    LA      x1, s_fe
    bl      strcat_cur
    ldr     s0, [x19, #P_FAITH]
    fcvtzs  w1, s0
    bl      numcat
    LA      x1, s_pct
    bl      strcat_cur
    LA      x1, s_bar               // o que esta fazendo
    bl      strcat_cur
    bl      ppl_doing
    bl      strcat_cur
    LA      x1, s_hungry
    ldr     s0, [x19, #P_FOOD]
    PF      s1, 112
    fcmp    s0, s1
    b.lt    2f
    b       9f
2:  bl      strcat_cur
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ppl_doing -> x1 = o que a pessoa x19 esta fazendo agora ("cortando")
// folha (nao mexe em x0)
    .globl ppl_doing
ppl_doing:
    ldrb    w9, [x19, #P_STATE]
    LA      x1, d_fight
    cmp     w9, #ST_FIGHT
    b.eq    9f
    ldrb    w10, [x19, #P_JOB]
    cmp     w10, #J_SOLDIER
    b.ne    0f
    LA      x1, d_guard
    cmp     w9, #ST_SLEEP
    b.ne    9f
0:  LA      x1, d_idle
    cmp     w9, #ST_SLEEP
    b.ne    1f
    LA      x1, d_sleep
    ret
1:  cmp     w9, #ST_FLEE
    b.ne    2f
    LA      x1, d_flee
    ret
2:  cmp     w9, #ST_WORK
    b.ne    3f
    ldrb    w10, [x19, #P_WKIND]
    LA      x11, d_work
    ldr     x1, [x11, x10, lsl #3]
    ret
3:  cmp     w9, #ST_WALK
    b.ne    9f
    ldrb    w10, [x19, #P_NEXT]
    LA      x11, d_walk
    ldr     x1, [x11, x10, lsl #3]
9:  ret

// =====================================================================
//  Comandos: teclas, cliques, zonas
// =====================================================================

// people_key(w0 = tecla) -> w0 = 1 se usou   P: painel, Z: zonas;
// pintando zonas, 1-4 escolhem o tipo e 0 apaga
    .globl people_key
people_key:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    cmp     w0, #19                     // P
    b.ne    2f
    ldr     w9, [x28, #G_PEOPLEOPEN]
    eor     w9, w9, #1
    str     w9, [x28, #G_PEOPLEOPEN]
    cbz     w9, 7f
    str     wzr, [x28, #G_CRAFTOPEN]    // abre no mesmo lugar delas
    str     wzr, [x28, #G_CHESTOPEN]
    str     wzr, [x28, #G_INVOPEN]
    b       7f
2:  cmp     w0, #29                     // Z
    b.ne    4f
    ldr     w9, [x28, #G_ZONEMODE]
    cbz     w9, 3f
    str     wzr, [x28, #G_ZONEMODE]
    str     wzr, [x28, #G_ZDRAG]
    b       7f
3:  mov     w9, #Z_FOREST
    str     w9, [x28, #G_ZONEMODE]
    str     wzr, [x28, #G_ZDRAG]
    str     wzr, [x28, #G_CHAROPEN]
    str     wzr, [x28, #G_PLACE]
    LA      x0, m_zonemode
    bl      set_msg
    b       7f
4:  ldr     w9, [x28, #G_ZONEMODE]
    cbz     w9, 8f
    sub     w10, w0, #30                // 1-8
    cmp     w10, #8
    b.hs    5f
    LA      x9, zptypes
    ldrb    w10, [x9, x10]
    str     w10, [x28, #G_ZONEMODE]
    b       7f
5:  cmp     w0, #39                     // 0: apagar
    b.ne    51f
    mov     w10, #Z_ERASE
    str     w10, [x28, #G_ZONEMODE]
    b       7f
51: cmp     w0, #47                     // [ e ]: tamanho do pincel
    b.ne    52f
    mov     w0, #-1
    bl      zone_wheel
    b       7f
52: cmp     w0, #48
    b.ne    8f
    mov     w0, #1
    bl      zone_wheel
7:  mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldp     x29, x30, [sp], #16
    ret

// people_esc -> w0 = 1 se usou o ESC (sai das zonas, fecha o painel,
// tira a selecao)   folha
    .globl people_esc
people_esc:
    ldr     w9, [x28, #G_ZONEMODE]
    cbz     w9, 1f
    str     wzr, [x28, #G_ZONEMODE]
    str     wzr, [x28, #G_ZDRAG]
    b       7f
1:  ldr     w9, [x28, #G_PEOPLEOPEN]
    cbz     w9, 2f
    str     wzr, [x28, #G_PEOPLEOPEN]
    b       7f
2:  ldr     w9, [x28, #G_SELPERS]
    tbnz    w9, #31, 8f
    mov     w9, #-1
    str     w9, [x28, #G_SELPERS]
7:  mov     w0, #1
    ret
8:  mov     w0, #0
    ret

// people_world_click(w0 = botao) -> w0 = 1 se usou o clique no mundo:
// pintando zonas: esquerdo comeca o retangulo, direito sai; esquerdo numa
// pessoa: seleciona; direito com alguem selecionado: "va ate la"
    .globl people_world_click
people_world_click:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w21, w0
    ldr     w9, [x28, #G_ZONEMODE]
    cbz     w9, 10f
    mov     w9, #1                      // esquerdo pinta, direito apaga
    cmp     w21, #3
    b.ne    1f
    mov     w9, #2
1:  str     w9, [x28, #G_ZDRAG]
    bl      zone_update                 // ja pinta onde clicou
    b       7f
10: ldr     w9, [x28, #G_NOPEOPLE]
    cbnz    w9, 8f
    ldr     w9, [x28, #G_PLACE]         // construindo: o clique e da obra
    cbnz    w9, 8f
    cmp     w21, #1
    b.ne    20f
    ldr     w20, [x28, #G_HOVPERS]      // esquerdo numa pessoa: seleciona
    tbz     w20, #31, 11f
    mov     w9, #-1                     // no vazio: tira a selecao
    str     w9, [x28, #G_SELPERS]
    b       8f
11: str     w20, [x28, #G_SELPERS]
    LA      x0, pmsgbuf
    mov     w1, w20
    bl      ppl_namecat
    LA      x1, s_selected
    bl      strcat_cur
    LA      x0, pmsgbuf
    bl      set_msg
    b       7f
20: cmp     w21, #3
    b.ne    8f
    ldr     w0, [x28, #G_HOVPERS]       // direito numa pessoa: a mochila dela
    tbnz    w0, #31, 22f
    bl      open_person
    b       7f
22: ldr     w20, [x28, #G_SELPERS]      // direito: "va ate la"
    tbnz    w20, #31, 8f
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 8f
    LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 8f
    ldr     s0, [x19, #P_FAITH]         // pouca fe: pode nao querer
    PF      s1, 116
    fcmp    s0, s1
    b.ge    21f
    mov     w0, #2
    bl      rng_mod
    cbz     w0, 21f
    LA      x0, pmsgbuf
    mov     w1, w20
    bl      ppl_namecat
    LA      x1, s_refuse
    bl      strcat_cur
    LA      x0, pmsgbuf
    bl      set_msg
    b       7f
21: ldr     w9, [x28, #G_HOVU]
    ucvtf   s0, w9
    ldr     w9, [x28, #G_HOVV]
    ucvtf   s1, w9
    PF      s2, 40
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    str     s0, [x19, #P_GU]
    str     s1, [x19, #P_GV]
    mov     w9, #NX_ORDER
    strb    w9, [x19, #P_NEXT]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
    strb    wzr, [x19, #P_WKIND]
    mov     w9, #ST_WALK
    strb    w9, [x19, #P_STATE]
    strh    wzr, [x19, #P_BLOCK]
    strh    wzr, [x19, #P_DET]
    LA      x0, pmsgbuf
    mov     w1, w20
    bl      ppl_namecat
    LA      x1, s_going
    bl      strcat_cur
    LA      x0, pmsgbuf
    bl      set_msg
7:  mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// zone_fill(w0 u0, w1 v0, w2 u1, w3 v1, w4 tipo) -> w0 = quadrados  folha
    .globl zone_fill
zone_fill:
    mov     w9, #1                      // depositos: refazer as listas
    str     w9, [x28, #G_DEPDIRTY]
    cmp     w0, w2                      // ordena e prende no mapa
    csel    w9, w0, w2, lt
    csel    w2, w2, w0, lt
    mov     w0, w9
    cmp     w1, w3
    csel    w9, w1, w3, lt
    csel    w3, w3, w1, lt
    mov     w1, w9
    cmp     w0, #1
    mov     w9, #1
    csel    w0, w9, w0, lt
    cmp     w1, #1
    csel    w1, w9, w1, lt
    mov     w9, #510
    cmp     w2, w9
    csel    w2, w9, w2, gt
    cmp     w3, w9
    csel    w3, w9, w3, gt
    LA      x10, zonegrid
    mov     w11, #0
    mov     w12, w1
1:  cmp     w12, w3
    b.gt    9f
    mov     w13, w0
2:  cmp     w13, w2
    b.gt    3f
    add     w14, w13, w12, lsl #9
    ldrb    w15, [x10, w14, uxtw]       // terreno de casa nao muda
    cmp     w15, #Z_LOT
    b.eq    21f
    sub     w15, w15, #Z_DEPF           // nem deposito
    cmp     w15, #3
    b.ls    21f
    strb    w4, [x10, w14, uxtw]
    add     w11, w11, #1
21:
    add     w13, w13, #1
    b       2b
3:  add     w12, w12, #1
    b       1b
9:  mov     w0, w11
    ret

// zone_release: soltou o botao: o pincel para   folha
    .globl zone_release
zone_release:
    str     wzr, [x28, #G_ZDRAG]
    ret

// =====================================================================
//  Interface: painel de pessoas (P) e paleta de zonas (Z)
// =====================================================================

// people_ui_hit(w0 = x, w1 = y) -> w0 = 9 painel (w1 = linha * 8 +
// coluna: 0 nome, 1 tarefa, 2 resto; -1 fora de uma linha), 10 paleta
// (w1 = tipo 1..5), 0 nada   folha
    .globl people_ui_hit
people_ui_hit:
    ldr     w9, [x28, #G_PEOPLEOPEN]
    cbz     w9, 5f
    sub     w9, w0, #PP_X
    cmp     w9, #PP_W
    b.hs    5f
    sub     w10, w1, #PP_Y
    cmp     w10, #PP_H
    b.hs    5f
    mov     w11, #-1
    cmp     w10, #(PP_H - 17)           // embaixo: abas e paginas
    b.lo    1f
    mov     w11, #1000
    cmp     w9, #72
    b.lo    4f
    mov     w11, #1001
    cmp     w9, #154
    b.lo    4f
    mov     w11, #1002
    sub     w12, w9, #320
    cmp     w12, #22
    b.lo    4f
    mov     w11, #1003
    sub     w12, w9, #384
    cmp     w12, #22
    b.lo    4f
    mov     w11, #-1
    b       4f
1:  subs    w10, w10, #PP_ROW0
    b.lt    4f
    mov     w12, #16
    udiv    w12, w10, w12
    LA      x13, prows
    ldr     w13, [x13]
    cmp     w12, w13
    b.hs    4f
    cmp     w9, #150
    mov     w14, #0
    b.lo    3f
    cmp     w9, #232
    mov     w14, #1
    b.lo    3f
    mov     w14, #2
3:  lsl     w11, w12, #3
    add     w11, w11, w14
4:  mov     w0, #9
    mov     w1, w11
    ret
5:  ldr     w9, [x28, #G_ZONEMODE]
    cbz     w9, 8f
    sub     w9, w0, #ZP_X
    cmp     w9, #ZP_W
    b.hs    8f
    sub     w10, w1, #ZP_Y
    cmp     w10, #ZP_H
    b.hs    8f
    mov     w11, #-1
    subs    w10, w10, #20
    b.lt    6f
    mov     w12, #16
    udiv    w12, w10, w12
    cmp     w12, #9
    b.hs    6f
    LA      x11, zptypes
    ldrb    w11, [x11, x12]
6:  mov     w0, #10
    mov     w1, w11
    ret
8:  mov     w0, #0
    mov     w1, #-1
    ret

// people_ui_click(w0 = botao, w1 = linha/tipo, w2 = 9 painel / 10 paleta)
    .globl people_ui_click
people_ui_click:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w21, w0                     // botao
    tbnz    w1, #31, 9f
    cmp     w1, #1000                   // abas e paginas
    b.lo    0f
    ldr     w9, [x28, #G_PPAGE]
    cmp     w1, #1002
    b.hs    63f
    sub     w10, w1, #1000
    str     w10, [x28, #G_PTAB]
    str     wzr, [x28, #G_PPAGE]
    b       9f
63: b.ne    64f
    subs    w9, w9, #1
    csel    w9, wzr, w9, lt
    str     w9, [x28, #G_PPAGE]
    b       9f
64: add     w9, w9, #1                  // (a ultima pagina segura no desenho)
    str     w9, [x28, #G_PPAGE]
    b       9f
0:  cmp     w2, #10
    b.ne    1f
    str     w1, [x28, #G_ZONEMODE]      // paleta: escolhe o tipo
    b       9f
1:  lsr     w9, w1, #3                  // painel
    and     w22, w1, #7
    LA      x10, prowmap
    ldrb    w20, [x10, x9]
    LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 9f
    cmp     w22, #1
    b.eq    2f
    cmp     w22, #2                     // Agora: a mochila
    b.ne    10f
    mov     w0, w20
    bl      open_person
    b       9f
10: str     w20, [x28, #G_SELPERS]      // nome: seleciona
    b       9f
2:  ldrh    w9, [x19, #P_AGE]           // tarefa: crianca nao trabalha
    cmp     w9, #ADULTDAYS
    b.hs    3f
    LA      x0, pmsgbuf
    mov     w1, w20
    bl      ppl_namecat
    LA      x1, s_kidnojob
    bl      strcat_cur
    b       8f
3:  ldr     s0, [x19, #P_FAITH]         // pouca fe: pode nao querer
    PF      s1, 116
    fcmp    s0, s1
    b.ge    4f
    mov     w0, #2
    bl      rng_mod
    cbz     w0, 4f
    LA      x0, pmsgbuf
    mov     w1, w20
    bl      ppl_namecat
    LA      x1, s_refuse
    bl      strcat_cur
    b       8f
4:  ldrb    w9, [x19, #P_JOB]           // esquerdo: proxima; direito: volta
    add     w9, w9, #1
    cmp     w21, #3
    b.ne    5f
    add     w9, w9, #(NJOBS - 2)
5:  mov     w10, #NJOBS
    udiv    w11, w9, w10
    msub    w9, w11, w10, w9
    strb    w9, [x19, #P_JOB]
    strb    wzr, [x19, #P_BFAM]
    ldrb    w10, [x19, #P_STATE]        // larga o que estava fazendo
    cmp     w10, #ST_SLEEP
    b.eq    6f
    mov     w10, #ST_IDLE
    strb    w10, [x19, #P_STATE]
    strh    wzr, [x19, #P_THINK]
    mov     w10, #-1
    str     w10, [x19, #P_TARGET]
    strb    wzr, [x19, #P_NEXT]
6:  LA      x0, pmsgbuf
    mov     w1, w20
    bl      ppl_namecat
    LA      x1, s_colon
    bl      strcat_cur
    LA      x1, jobnames
    ldrb    w9, [x19, #P_JOB]
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
8:  LA      x0, pmsgbuf
    bl      set_msg
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// people_ui_draw: painel, paleta e o nome de quem esta selecionado
    .globl people_ui_draw
people_ui_draw:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #G_NOPEOPLE]
    cbnz    w9, 9f
    ldr     w9, [x28, #G_CRAFTOPEN]     // fabricar, mochila e bau abrem no
    ldr     w10, [x28, #G_INVOPEN]      // mesmo lugar: fecham o painel
    orr     w9, w9, w10
    ldr     w10, [x28, #G_CHESTOPEN]
    orr     w9, w9, w10
    cbz     w9, 1f
    str     wzr, [x28, #G_PEOPLEOPEN]
1:  bl      ppl_drawsel
    ldr     w9, [x28, #G_PEOPLEOPEN]
    cbz     w9, 2f
    bl      ppl_drawpanel
2:  ldr     w9, [x28, #G_ZONEMODE]
    cbz     w9, 9f
    bl      ppl_drawpalette
9:  ldp     x29, x30, [sp], #16
    ret

// ppl_bar(w0 x, w1 y, s0 valor 0..100, w2 cor 0xRRGGBB)
ppl_bar:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    fcvtzs  w22, s0
    cmp     w22, #0
    csel    w22, wzr, w22, lt
    cmp     w22, #100
    mov     w9, #100
    csel    w22, w9, w22, gt
    RGBA    30, 30, 38, 255
    mov     w0, w19
    add     w1, w20, #1
    mov     w2, #20
    mov     w3, #6
    bl      fillrect
    ubfx    w0, w21, #16, #8
    ubfx    w1, w21, #8, #8
    and     w2, w21, #255
    mov     w3, #255
    bl      setcolor
    mov     w9, #20
    mul     w2, w22, w9
    mov     w9, #100
    udiv    w2, w2, w9
    cbz     w2, 9f
    mov     w0, w19
    add     w1, w20, #1
    mov     w3, #6
    bl      fillrect
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

ppl_drawpanel:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    LA      x0, ptitle                  // "Vila: 12 pessoas, ..."
    bl      vila_title
    mov     w0, #PP_X
    mov     w1, #PP_Y
    mov     w2, #PP_W
    mov     w3, #PP_H
    LA      x4, ptitle
    bl      ui_panel
    LA      x9, prows
    str     wzr, [x9]
    ldr     w9, [x28, #G_PTAB]
    cbz     w9, 10f
    RGBA    170, 175, 195, 255          // aba Familias: arvore genealogica
    mov     w0, #(PP_X + 6)
    mov     w1, #(PP_Y + 17)
    LA      x2, s_htree
    bl      text
    ldr     w0, [x28, #G_PPAGE]
    mov     w9, #PP_ROWS
    mul     w0, w0, w9
    mov     w1, #(PP_X + 6)
    mov     w2, #(PP_Y + PP_ROW0 + 2)
    bl      vila_drawtree
    mov     w23, w0
    b       85f
10: RGBA    170, 175, 195, 255          // cabecalho
    mov     w0, #(PP_X + 6)
    mov     w1, #(PP_Y + 17)
    LA      x2, s_hname
    bl      text
    mov     w0, #(PP_X + 114)
    mov     w1, #(PP_Y + 17)
    LA      x2, s_hage
    bl      text
    mov     w0, #(PP_X + 154)
    mov     w1, #(PP_Y + 17)
    LA      x2, s_hjob
    bl      text
    mov     w0, #(PP_X + 236)
    mov     w1, #(PP_Y + 17)
    LA      x2, s_hnow
    bl      text
    mov     w0, #(PP_X + 330)
    mov     w1, #(PP_Y + 17)
    LA      x2, s_hfe
    bl      text
    mov     w0, #(PP_X + 354)
    mov     w1, #(PP_Y + 17)
    LA      x2, s_hfood
    bl      text
    mov     w0, #(PP_X + 378)
    mov     w1, #(PP_Y + 17)
    LA      x2, s_hhp
    bl      text
    mov     w23, #0                     // linha
    mov     w20, #0                     // pessoa
    ldr     w21, [x28, #G_PPAGE]        // pula as paginas de antes
    mov     w9, #PP_ROWS
    mul     w21, w21, w9
1:  cmp     w20, #MAXPEOPLE
    b.ge    8f
    cmp     w23, #PP_ROWS
    b.ge    8f
    LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 7f
    cbz     w21, 11f
    sub     w21, w21, #1
    b       7f
11: LA      x9, prowmap
    strb    w20, [x9, x23]
    mov     w9, #16
    mov     w10, #(PP_Y + PP_ROW0 + 2)
    madd    w24, w23, w9, w10           // y da linha
    ldr     w9, [x28, #G_SELPERS]       // selecionada: fundo claro
    cmp     w9, w20
    b.ne    2f
    RGBA    60, 70, 110, 220
    mov     w0, #(PP_X + 2)
    sub     w1, w24, #3
    mov     w2, #(PP_W - 4)
    mov     w3, #15
    bl      fillrect
2:  LA      x0, pbuf                    // nome (laranja com pouca fe)
    mov     w1, w20
    bl      ppl_namecat
    ldr     s0, [x19, #P_FAITH]
    PF      s1, 116
    fcmp    s0, s1
    b.ge    21f
    RGBA    255, 150, 90, 255
    b       22f
21: RGBA    235, 235, 240, 255
22: mov     w0, #(PP_X + 6)
    mov     w1, w24
    LA      x2, pbuf
    bl      text
    LA      x0, pbuf                    // idade
    ldrh    w9, [x19, #P_AGE]
    mov     w10, #12
    udiv    w1, w9, w10
    bl      numcat
    RGBA    200, 200, 210, 255
    mov     w0, #(PP_X + 126)
    mov     w1, w24
    LA      x2, pbuf
    bl      text
    RGBA    40, 46, 70, 255             // tarefa (parece um botao)
    mov     w0, #(PP_X + 150)
    sub     w1, w24, #2
    mov     w2, #80
    mov     w3, #12
    bl      fillrect
    ldrh    w9, [x19, #P_AGE]
    cmp     w9, #ADULTDAYS
    b.hs    3f
    RGBA    150, 150, 160, 255
    LA      x2, s_kidcap
    b       4f
3:  RGBA    255, 220, 120, 255
    LA      x2, jobnames
    ldrb    w9, [x19, #P_JOB]
    add     x2, x2, x9, lsl #4
4:  mov     w0, #(PP_X + 154)
    mov     w1, w24
    bl      text
    RGBA    170, 210, 240, 255          // o que esta fazendo agora
    bl      ppl_doing
    mov     x2, x1
    mov     w0, #(PP_X + 236)
    mov     w1, w24
    bl      text
    mov     w0, #(PP_X + 330)           // fe, fome, vida
    mov     w1, w24
    ldr     s0, [x19, #P_FAITH]
    MOVI32  w2, 0xFFD750
    bl      ppl_bar
    mov     w0, #(PP_X + 354)
    mov     w1, w24
    ldr     s0, [x19, #P_FOOD]
    MOVI32  w2, 0xEB9628
    bl      ppl_bar
    mov     w0, #(PP_X + 378)
    mov     w1, w24
    ldr     s0, [x19, #P_HP]
    MOVI32  w2, 0xD73C32
    bl      ppl_bar
    add     w23, w23, #1
7:  add     w20, w20, #1
    b       1b
8:  LA      x9, prows
    str     w23, [x9]
    ldr     w23, [x28, #G_PEOPLEN]      // total de linhas (paginas)
85: bl      ppl_drawfoot
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ppl_drawfoot(w23 = total de linhas): abas e paginas embaixo do painel
ppl_drawfoot:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    add     w19, w23, #(PP_ROWS - 1)    // paginas
    mov     w9, #PP_ROWS
    udiv    w19, w19, w9
    cmp     w19, #1
    mov     w9, #1
    csel    w19, w9, w19, lt
    ldr     w20, [x28, #G_PPAGE]        // pagina dentro do que existe
    cmp     w20, w19
    b.lo    1f
    sub     w20, w19, #1
    str     w20, [x28, #G_PPAGE]
1:  ldr     w9, [x28, #G_PTAB]          // abas
    cbnz    w9, 2f
    RGBA    60, 70, 110, 255
    b       3f
2:  RGBA    40, 46, 70, 255
3:  mov     w0, #(PP_X + 4)
    mov     w1, #(PP_Y + PP_H - 17)
    mov     w2, #66
    mov     w3, #14
    bl      fillrect
    ldr     w9, [x28, #G_PTAB]
    cbz     w9, 4f
    RGBA    60, 70, 110, 255
    b       5f
4:  RGBA    40, 46, 70, 255
5:  mov     w0, #(PP_X + 74)
    mov     w1, #(PP_Y + PP_H - 17)
    mov     w2, #78
    mov     w3, #14
    bl      fillrect
    RGBA    40, 46, 70, 255             // < e >
    mov     w0, #(PP_X + 322)
    mov     w1, #(PP_Y + PP_H - 17)
    mov     w2, #18
    mov     w3, #14
    bl      fillrect
    mov     w0, #(PP_X + 386)
    mov     w1, #(PP_Y + PP_H - 17)
    mov     w2, #18
    mov     w3, #14
    bl      fillrect
    RGBA    235, 235, 240, 255
    mov     w0, #(PP_X + 9)
    mov     w1, #(PP_Y + PP_H - 14)
    LA      x2, s_tabp
    bl      text
    mov     w0, #(PP_X + 81)
    mov     w1, #(PP_Y + PP_H - 14)
    LA      x2, s_tabf
    bl      text
    mov     w0, #(PP_X + 327)
    mov     w1, #(PP_Y + PP_H - 14)
    LA      x2, s_lt
    bl      text
    mov     w0, #(PP_X + 391)
    mov     w1, #(PP_Y + PP_H - 14)
    LA      x2, s_gt
    bl      text
    LA      x0, pbuf                    // "1/2"
    add     w1, w20, #1
    bl      numcat
    LA      x1, s_slash
    bl      strcat_cur
    mov     w1, w19
    bl      numcat
    RGBA    200, 200, 210, 255
    mov     w0, #(PP_X + 346)
    mov     w1, #(PP_Y + PP_H - 14)
    LA      x2, pbuf
    bl      text
    RGBA    150, 150, 165, 255          // dica
    mov     w0, #(PP_X + 162)
    mov     w1, #(PP_Y + PP_H - 14)
    LA      x2, s_pfoot
    ldr     w9, [x28, #G_PTAB]
    cbz     w9, 6f
    LA      x2, s_tfoot
6:  bl      text
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

ppl_drawpalette:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w0, #ZP_X
    mov     w1, #ZP_Y
    mov     w2, #ZP_W
    mov     w3, #ZP_H
    LA      x4, s_ztitle
    bl      ui_panel
    mov     w22, #0                     // linha
1:  cmp     w22, #9
    b.ge    8f
    mov     w10, #16
    mov     w11, #(ZP_Y + 20)
    madd    w20, w22, w10, w11
    LA      x9, zptypes
    ldrb    w19, [x9, x22]
    ldr     w9, [x28, #G_ZONEMODE]
    cmp     w9, w19
    b.ne    2f
    RGBA    60, 70, 110, 220
    mov     w0, #(ZP_X + 2)
    sub     w1, w20, #3
    mov     w2, #(ZP_W - 4)
    mov     w3, #15
    bl      fillrect
2:  LA      x9, zonecolors
    ldr     w21, [x9, x19, lsl #2]
    ubfx    w0, w21, #16, #8
    ubfx    w1, w21, #8, #8
    and     w2, w21, #255
    mov     w3, #255
    bl      setcolor
    mov     w0, #(ZP_X + 8)
    sub     w1, w20, #1
    mov     w2, #10
    mov     w3, #10
    bl      fillrect
    RGBA    235, 235, 240, 255
    mov     w0, #(ZP_X + 24)
    mov     w1, w20
    LA      x2, zonenames
    add     x2, x2, x19, lsl #4
    bl      text
    add     w22, w22, #1
    b       1b
8:  RGBA    150, 150, 165, 255
    LA      x0, pmsgbuf2
    LA      x1, s_zfoot
    bl      strcat_cur
    ldr     w1, [x28, #G_ZBRUSH]
    bl      numcat
    LA      x1, s_zfoot2
    bl      strcat_cur
    mov     w0, #(ZP_X + 6)
    mov     w1, #(ZP_Y + ZP_H - 26)
    LA      x2, pmsgbuf2
    bl      text
    mov     w0, #(ZP_X + 6)
    mov     w1, #(ZP_Y + ZP_H - 13)
    LA      x2, s_zfoot3
    bl      text
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ppl_drawsel: o nome de quem esta selecionado, em cima da cabeca
ppl_drawsel:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    ldr     w20, [x28, #G_SELPERS]
    tbnz    w20, #31, 9f
    LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 9f
    ldrb    w9, [x19, #P_FLAGS]
    tbnz    w9, #0, 9f
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    csel    w0, w9, w0, lt
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    bl      proj
    asr     w21, w0, #1                 // espaco da interface
    asr     w22, w1, #1
    sub     w22, w22, #34
    LA      x0, pbuf
    mov     w1, w20
    bl      ppl_namecat
    LA      x0, pbuf
    bl      mystrlen
    lsl     w0, w0, #2
    sub     w21, w21, w0
    RGBA    20, 20, 20, 255
    add     w0, w21, #1
    add     w1, w22, #1
    LA      x2, pbuf
    bl      text
    RGBA    255, 225, 110, 255
    mov     w0, w21
    mov     w1, w22
    LA      x2, pbuf
    bl      text
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// =====================================================================
//  Teste automatico (--shot)
//    0: a vila em volta do personagem: bau, 3 barracos, zonas e tarefas;
//       1 hora de jogo trabalhando (foto pintando zonas)
//    2: painel aberto (foto)
//    1: mais 2 horas; confere o bau, a plantacao, as mudas, os
//       caminhos, as obras e a noite; passa 24 dias (as mudas crescem,
//       casamentos, nascimentos), mais 2 horas de obras e um lobo
//    3: aba Familias (foto da arvore genealogica)
// =====================================================================

// pt_count(w0 = tipo, w1 = zona ou 0) -> w0 = objetos desse tipo  folha
pt_count:
    ldr     w9, [x28, #G_NOBJ]
    LA      x10, objs
    LA      x15, zonegrid
    mov     w11, w0
    mov     w0, #0
1:  cbz     w9, 9f
    ldrb    w12, [x10, #6]
    cmp     w12, w11
    b.ne    2f
    cbz     w1, 3f
    ldrh    w12, [x10]
    lsr     w12, w12, #6
    ldrh    w13, [x10, #2]
    lsr     w13, w13, #6
    add     w12, w12, w13, lsl #9
    ldrb    w12, [x15, w12, uxtw]
    cmp     w12, w1
    b.ne    2f
3:  add     w0, w0, #1
2:  add     x10, x10, #8
    sub     w9, w9, #1
    b       1b
9:  ret

// pt_run(w0 = quadros): o jogo andando
pt_run:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w0
1:  cbz     w19, 9f
    bl      surv_update
    sub     w19, w19, #1
    b       1b
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// pt_num(x0 = cursor, x1 = rotulo, w2 = numero) -> x0
pt_num:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w2
    bl      strcat_cur
    mov     w1, w19
    bl      numcat
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// pt_houses -> w0 casas (nivel 2), w1 cercas, w2 familias com casa ou
// barraco, w3 familias com gente   folha
pt_houses:
    LA      x9, fams
    mov     w10, #0
    mov     w0, #0
    mov     w1, #0
    mov     w2, #0
    mov     w3, #0
1:  ldrb    w11, [x9, #F_USED]
    cbz     w11, 2f
    ldrb    w11, [x9, #F_LEVEL]
    cmp     w11, #2
    cinc    w0, w0, eq
    cmp     w11, #1
    cinc    w2, w2, hs
    ldrb    w11, [x9, #F_FENCE]
    add     w1, w1, w11
    LA      x12, people                 // tem gente?
    mov     w13, #0
11: ldrb    w14, [x12, #P_ALIVE]
    cbz     w14, 12f
    ldrb    w14, [x12, #P_FAM]
    cmp     w14, w10
    b.ne    12f
    add     w3, w3, #1
    b       2f
12: add     x12, x12, #PSIZE
    add     w13, w13, #1
    cmp     w13, #MAXPEOPLE
    b.lt    11b
2:  add     x9, x9, #FSIZE
    add     w10, w10, #1
    cmp     w10, #MAXFAM
    b.lt    1b
    ret

// pt_cellok(w0 = celula) -> w0 = 1 se e chao bom e livre (sem zona)  folha
pt_cellok:
    LA      x9, occgrid
    ldrb    w10, [x9, w0, uxtw]
    LA      x9, fencegrid
    ldrb    w11, [x9, w0, uxtw]
    orr     w10, w10, w11
    LA      x9, overlay
    ldrb    w11, [x9, w0, uxtw]
    orr     w10, w10, w11
    LA      x9, zonegrid
    ldrb    w11, [x9, w0, uxtw]
    orr     w10, w10, w11
    cbnz    w10, 8f
    LA      x9, elev
    ldrsh   w10, [x9, w0, uxtw #1]
    ldr     w11, [x28, #G_FLOOD]
    cmp     w10, w11
    b.lt    8f
    cmp     w10, #(E_SAND + 20)
    b.lt    8f
    mov     w11, #E_ROCK
    cmp     w10, w11
    b.ge    8f
    mov     w0, #1
    ret
8:  mov     w0, #0
    ret

// pt_block(w0 = largura, w1 = altura, w2 = zona): marca a zona no
// retangulo de chao bom mais perto do bau do teste (ate 16 celulas)
pt_block:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     w19, w0
    mov     w20, w1
    str     w2, [sp, #96]
    LA      x9, pt_res
    ldr     w9, [x9]
    and     w21, w9, #511               // deposito: u, v
    lsr     w22, w9, #9
    mov     w23, #-1                    // melhor canto
    mov     w24, #0x7FFFFFFF
    mov     w25, #-16                   // dv
1:  mov     w26, #-16                   // du
2:  mul     w9, w25, w25
    madd    w9, w26, w26, w9
    cmp     w9, w24
    b.ge    7f
    mov     w27, #0                     // confere cada celula
3:  udiv    w10, w27, w19
    msub    w11, w10, w19, w27
    add     w12, w21, w26
    add     w12, w12, w11
    add     w13, w22, w25
    add     w13, w13, w10
    add     w0, w12, w13, lsl #9
    str     w9, [sp, #100]
    bl      pt_cellok
    ldr     w9, [sp, #100]
    cbz     w0, 7f
    add     w27, w27, #1
    mul     w10, w19, w20
    cmp     w27, w10
    b.lo    3b
    mov     w24, w9                     // cabe inteiro
    add     w12, w21, w26
    add     w13, w22, w25
    add     w23, w12, w13, lsl #9
7:  add     w26, w26, #1
    cmp     w26, #16
    b.le    2b
    add     w25, w25, #1
    cmp     w25, #16
    b.le    1b
    tbnz    w23, #31, 9f
    and     w0, w23, #511
    lsr     w1, w23, #9
    add     w2, w0, w19
    sub     w2, w2, #1
    add     w3, w1, w20
    sub     w3, w3, #1
    ldr     w4, [sp, #96]
    bl      zone_fill
9:  ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #112
    ret

// pt_reach(w0 tipo min, w1 tipo max) -> w0 = objeto (com algo) mais
// perto do bau do teste com chao seco em linha reta ate ele (-1)
pt_reach:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     d8, d9, [sp, #64]
    stp     d10, d11, [sp, #80]
    stp     d12, d13, [sp, #96]
    mov     w21, w0
    mov     w22, w1
    mov     w23, #-1
    PF      s12, 76                     // melhor distancia^2
    LA      x9, pt_res
    ldr     w9, [x9]
    and     w11, w9, #511               // deposito
    lsr     w12, w9, #9
    scvtf   s8, w11
    scvtf   s9, w12
    PF      s2, 96
    fadd    s8, s8, s2
    fadd    s9, s9, s2
    mov     w19, #0
1:  ldr     w9, [x28, #G_NOBJ]
    cmp     w19, w9
    b.ge    9f
    LA      x9, objs
    add     x20, x9, x19, lsl #3
    ldrb    w10, [x20, #6]
    cmp     w10, w21
    b.lo    5f
    cmp     w10, w22
    b.hi    5f
    ldrb    w10, [x20, #7]
    cbz     w10, 5f
    ldrh    w10, [x20]
    ucvtf   s10, w10
    ldrh    w10, [x20, #2]
    ucvtf   s11, w10
    PF      s2, 40
    fmul    s10, s10, s2
    fmul    s11, s11, s2
    fsub    s10, s10, s8                // do bau ate ele
    fsub    s11, s11, s9
    fmul    s0, s10, s10
    fmadd   s0, s11, s11, s0
    fcmp    s0, s12
    b.ge    5f
    fmov    s13, s0
    fsqrt   s0, s0                      // passos de meia celula
    fadd    s0, s0, s0
    fcvtzs  w24, s0
    add     w24, w24, #1
    scvtf   s0, w24
    fdiv    s10, s10, s0
    fdiv    s11, s11, s0
    sub     w24, w24, #1                // (o ultimo passo e o proprio objeto)
2:  cbz     w24, 4f
    scvtf   s0, w24
    fmadd   s0, s10, s0, s8
    scvtf   s1, w24
    fmadd   s1, s11, s1, s9
    bl      ppl_land
    cbz     w0, 5f
    sub     w24, w24, #1
    b       2b
4:  fmov    s12, s13
    mov     w23, w19
5:  add     w19, w19, #1
    b       1b
9:  mov     w0, w23
    ldp     d12, d13, [sp, #96]
    ldp     d10, d11, [sp, #80]
    ldp     d8, d9, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #112
    ret

// pt_zone_at(w0 = objeto, w1 = raio, w2 = tipo): zona em volta do objeto
pt_zone_at:
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrh    w10, [x9]
    lsr     w10, w10, #6
    ldrh    w11, [x9, #2]
    lsr     w11, w11, #6
    mov     w4, w2
    sub     w0, w10, w1
    add     w2, w10, w1
    add     w3, w11, w1
    sub     w1, w11, w1
    b       zone_fill

    .globl people_selftest
people_selftest:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    mov     w21, w0
    str     wzr, [x28, #G_LMB]
    mov     w9, #1260                   // mouse no canto (sem dica)
    scvtf   s0, w9
    str     s0, [x28, #G_MX]
    mov     w9, #560
    scvtf   s0, w9
    str     s0, [x28, #G_MY]
    str     wzr, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CRAFTOPEN]
    str     wzr, [x28, #G_CHAROPEN]
    str     wzr, [x28, #G_PLACE]
    str     wzr, [x28, #G_HAND]
    cmp     w21, #1
    b.eq    pt_stage1
    cmp     w21, #2
    b.eq    pt_stage2
    cmp     w21, #3
    b.eq    pt_stage3
    // ---- etapa 0 ----
    str     wzr, [x28, #G_NOPEOPLE]
    mov     w9, #3000                   // de manha
    str     w9, [x28, #G_TIME]
    bl      animals_reset
    bl      vila_reset
    bl      ppl_spawn_all
    bl      ppl_camp
    LA      x9, pt_res
    str     w0, [x9]                    // o bau
    bl      ppl_chestptr                // material para as obras
    cbz     x0, 0f
    mov     w9, #40
    str     w9, [x0, #(4 * IT_WOOD)]
    mov     w9, #10
    str     w9, [x0, #(4 * IT_STONE)]
    bl      store_close
0:  bl      vila_found
    // zonas: floresta em volta da arvore mais perto do bau (sem agua no
    // caminho), pedra em volta da pedra; plantacao e moradia perto do bau
    LA      x19, people
    mov     w20, #0
    mov     w0, #O_TREE
    mov     w1, #O_PINE
    bl      pt_reach
    tbnz    w0, #31, 1f
    mov     w1, #5
    mov     w2, #Z_FOREST
    bl      pt_zone_at
1:  mov     w0, #O_ROCK
    mov     w1, #O_ROCK
    bl      pt_reach
    tbnz    w0, #31, 2f
    mov     w1, #4
    mov     w2, #Z_STONE
    bl      pt_zone_at
2:  LA      x9, pt_res
    ldr     w0, [x9]
    tbnz    w0, #31, 3f
    bl      ppl_ensure_occ
    mov     w0, #4                      // plantacao: 4 x 3 de chao bom
    mov     w1, #3                      // perto do bau
    mov     w2, #Z_FARM
    bl      pt_block
    mov     w0, #10                     // moradia: 2 terrenos
    mov     w1, #5
    mov     w2, #Z_HOME
    bl      pt_block
    mov     w0, #6                      // e mais um deposito geral 6 x 5
    mov     w1, #5
    mov     w2, #Z_DEPG
    bl      pt_block
3:  LA      x9, people                  // tarefas dos pais e maes
    mov     w10, #J_FOREST
    strb    w10, [x9, #(0 * PSIZE + P_JOB)]
    mov     w10, #J_FARM
    strb    w10, [x9, #(1 * PSIZE + P_JOB)]
    mov     w10, #J_STONE
    strb    w10, [x9, #(4 * PSIZE + P_JOB)]
    mov     w10, #J_BUILD
    strb    w10, [x9, #(5 * PSIZE + P_JOB)]
    mov     w10, #J_FOREST
    strb    w10, [x9, #(8 * PSIZE + P_JOB)]
    mov     w10, #J_FARM
    strb    w10, [x9, #(9 * PSIZE + P_JOB)]
    mov     w0, #1800                   // 1 hora de jogo
    bl      pt_run
    mov     w9, #Z_FARM                 // foto: pintando zonas
    str     w9, [x28, #G_ZONEMODE]
    mov     w9, #1
    str     w9, [x28, #G_SELPERS]
    str     wzr, [x28, #G_MSGT]
    str     wzr, [x28, #G_POPT]
    b       pt_ret

pt_stage3:
    mov     w9, #1                      // foto: arvore genealogica
    str     w9, [x28, #G_PEOPLEOPEN]
    str     w9, [x28, #G_PTAB]
    str     wzr, [x28, #G_PPAGE]
    str     wzr, [x28, #G_ZONEMODE]
    str     wzr, [x28, #G_MSGT]
    b       pt_ret

pt_stage2:
    str     wzr, [x28, #G_ZONEMODE]     // foto: painel aberto
    mov     w9, #1
    str     w9, [x28, #G_PEOPLEOPEN]
    str     wzr, [x28, #G_MSGT]
    b       pt_ret

pt_stage1:
    str     wzr, [x28, #G_PEOPLEOPEN]
    mov     w9, #-1
    str     w9, [x28, #G_SELPERS]
    LA      x9, pt_res
    ldr     w0, [x9]
    tbnz    w0, #31, pt_ret
    mov     w0, #7200                   // mais 2 horas de jogo
    bl      pt_run
    // ---- o que tem no bau ----
    LA      x9, pt_res
    ldr     w0, [x9]
    bl      ppl_chestptr
    mov     x24, x0
    // ---- terra arada na plantacao, trigo plantado, mudas, caminhos ----
    mov     w22, #0                     // aradas
    mov     w23, #0                     // caminho
    LA      x9, zonegrid
    LA      x10, overlay
    mov     w11, #0
4:  ldrb    w12, [x9, x11]
    ldrb    w13, [x10, x11]
    cmp     w12, #Z_FARM
    b.ne    41f
    cmp     w13, #2
    cinc    w22, w22, hs
41: cmp     w13, #1
    cinc    w23, w23, eq
    add     w11, w11, #1
    cmp     w11, #64, lsl #12
    b.lo    4b
    LA      x9, pt_res
    str     w22, [x9, #4]
    str     w23, [x9, #8]
    mov     w0, #O_CROP                 // trigo na zona de plantar
    mov     w1, #Z_FARM
    bl      pt_count
    LA      x9, pt_res
    str     w0, [x9, #12]
    mov     w0, #O_SAPLING
    mov     w1, #0
    bl      pt_count
    LA      x9, pt_res
    str     w0, [x9, #16]
    bl      pt_houses                   // casas e cercas
    LA      x9, pt_res
    str     w0, [x9, #44]
    str     w1, [x9, #48]
    // ---- de noite: vao dormir ----
    mov     w9, #28000
    str     w9, [x28, #G_TIME]
    mov     w0, #900
    bl      pt_run
    mov     w22, #0
    LA      x9, people
    mov     w10, #0
5:  ldrb    w11, [x9, #P_ALIVE]
    cbz     w11, 51f
    ldrb    w11, [x9, #P_STATE]
    cmp     w11, #ST_SLEEP
    cinc    w22, w22, eq
    cmp     w11, #ST_WALK               // (ou indo deitar)
    b.ne    51f
    ldrb    w11, [x9, #P_NEXT]
    cmp     w11, #NX_SLEEP
    cinc    w22, w22, eq
51: add     x9, x9, #PSIZE
    add     w10, w10, #1
    cmp     w10, #MAXPEOPLE
    b.lt    5b
    LA      x9, pt_res
    str     w22, [x9, #20]
    mov     w9, #3000
    str     w9, [x28, #G_TIME]
    LA      x9, people                  // acorda todo mundo
    mov     w10, #0
52: mov     w11, #ST_IDLE
    strb    w11, [x9, #P_STATE]
    ldrb    w11, [x9, #P_FLAGS]
    bic     w11, w11, #1
    strb    w11, [x9, #P_FLAGS]
    add     x9, x9, #PSIZE
    add     w10, w10, #1
    cmp     w10, #MAXPEOPLE
    b.lt    52b
    // ---- 24 dias: dois anos mais velhos; as mudas viram arvore ----
    LA      x9, people
    ldrh    w22, [x9, #P_AGE]
    mov     w10, #12
    udiv    w22, w22, w10
    mov     w25, #0
6:  bl      ppl_newday
    add     w25, w25, #1
    cmp     w25, #12
    b.ne    61f
    mov     w0, #O_YTREE                // depois de 1 ano: jovens
    mov     w1, #0
    bl      pt_count
    LA      x9, pt_res
    str     w0, [x9, #52]
61: cmp     w25, #24
    b.lt    6b
    mov     w0, #O_SAPLING              // depois de 2: quantas ainda nao
    mov     w1, #0
    bl      pt_count
    mov     w26, w0
    mov     w0, #O_YTREE
    mov     w1, #0
    bl      pt_count
    add     w26, w26, w0
    LA      x9, pt_res
    ldr     w10, [x9, #16]
    sub     w10, w10, w26
    str     w10, [x9, #56]
    LA      x9, people
    ldrh    w23, [x9, #P_AGE]
    mov     w10, #12
    udiv    w23, w23, w10
    LA      x9, pt_res
    str     w22, [x9, #24]
    str     w23, [x9, #28]
    mov     w9, #3000                   // mais 2 horas: obras para os casais novos
    str     w9, [x28, #G_TIME]
    mov     w0, #3600
    bl      pt_run
    bl      pt_houses
    LA      x9, pt_res
    str     w2, [x9, #60]
    str     w3, [x9, #64]
    // ---- um lobo perto de uma pessoa longe do personagem ----
    LA      x19, people
    add     x19, x19, #(1 * PSIZE)      // a mae da primeira familia
    mov     w20, #1
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 8f
    mov     w25, #0                     // lugar em terra a ~14 celulas
7:  LA      x9, ring8
    and     w10, w25, #7
    add     x9, x9, x10, lsl #3
    ldr     s0, [x9]
    ldr     s1, [x9, #4]
    PF      s2, 140
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    ldr     s2, [x28, #G_PU]
    fadd    s0, s0, s2
    ldr     s2, [x28, #G_PV]
    fadd    s1, s1, s2
    str     s0, [x19, #P_U]
    str     s1, [x19, #P_V]
    bl      ppl_land
    cbnz    w0, 71f
    add     w25, w25, #1
    cmp     w25, #8
    b.lt    7b
71: mov     w9, #ST_WAIT                // fica parada ali
    strb    w9, [x19, #P_STATE]
    mov     w9, #2000
    strh    w9, [x19, #P_TIMER]
    ldrb    w9, [x19, #P_FLAGS]
    and     w9, w9, #4
    strb    w9, [x19, #P_FLAGS]
    PF      s0, 44
    str     s0, [x19, #P_HP]
    bl      animals_reset
    mov     w25, #0                     // o lobo, 2 celulas do lado (em terra)
72: LA      x9, ring8
    and     w10, w25, #7
    add     x9, x9, x10, lsl #3
    ldr     s0, [x9]
    ldr     s1, [x9, #4]
    PF      s2, 84
    PF      s3, 132
    fdiv    s2, s2, s3
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    ldr     s2, [x19, #P_U]
    fadd    s0, s0, s2
    ldr     s2, [x19, #P_V]
    fadd    s1, s1, s2
    LA      x9, pt_res
    str     s0, [x9, #36]
    str     s1, [x9, #40]
    bl      ppl_land
    cbnz    w0, 73f
    add     w25, w25, #1
    cmp     w25, #8
    b.lt    72b
73: LA      x10, pt_res
    LA      x9, animals
    ldr     s0, [x10, #36]
    str     s0, [x9]
    ldr     s0, [x10, #40]
    str     s0, [x9, #4]
    stp     xzr, xzr, [x9, #8]
    stp     xzr, xzr, [x9, #24]
    str     wzr, [x9, #16]
    str     wzr, [x9, #20]
    mov     w10, #A_WOLF
    strb    w10, [x9, #16]
    mov     w10, #6
    strb    w10, [x9, #17]
    mov     w0, #300
    bl      pt_run
    ldr     s0, [x19, #P_HP]
    fcvtzs  w9, s0
    LA      x10, pt_res
    str     w9, [x10, #32]
    PF      s0, 44
    str     s0, [x19, #P_HP]
    bl      animals_reset
8:  // ---- imprime ----
    LA      x19, pt_res
    LA      x0, txt
    LA      x1, t_p1
    ldr     w2, [x28, #G_PEOPLEN]
    bl      pt_num
    LA      x1, t_p2
    ldr     w2, [x24, #(4 * IT_WOOD)]
    bl      pt_num
    LA      x1, t_p3
    ldr     w2, [x24, #(4 * IT_STONE)]
    bl      pt_num
    LA      x1, t_p4
    ldr     w2, [x19, #4]
    bl      pt_num
    LA      x1, t_p5
    ldr     w2, [x19, #12]
    bl      pt_num
    LA      x1, t_p6
    ldr     w2, [x19, #16]
    bl      pt_num
    LA      x1, t_p7
    ldr     w2, [x19, #8]
    bl      pt_num
    LA      x1, t_p8
    ldr     w2, [x19, #20]
    bl      pt_num
    LA      x1, t_p9
    ldr     w2, [x19, #24]
    bl      pt_num
    LA      x1, t_p10
    ldr     w2, [x19, #28]
    bl      pt_num
    LA      x1, t_p11
    ldr     w2, [x19, #32]
    bl      pt_num
    LA      x1, t_pnl
    bl      strcat_cur
    bl      sk_write
    LA      x19, pt_res                 // a vila
    LA      x9, vstat
    ldr     w22, [x9]
    ldr     w23, [x9, #4]
    LA      x0, txt
    LA      x1, t_q1
    ldr     w2, [x19, #44]
    bl      pt_num
    LA      x1, t_q2
    ldr     w2, [x19, #48]
    bl      pt_num
    LA      x1, t_q3
    ldr     w2, [x19, #16]
    bl      pt_num
    LA      x1, t_q4
    ldr     w2, [x19, #52]
    bl      pt_num
    LA      x1, t_q5
    ldr     w2, [x19, #56]
    bl      pt_num
    LA      x1, t_q6
    mov     w2, w22
    bl      pt_num
    LA      x1, t_q7
    mov     w2, w23
    bl      pt_num
    LA      x1, t_q8
    ldr     w2, [x19, #60]
    bl      pt_num
    LA      x1, t_q9
    ldr     w2, [x19, #64]
    bl      pt_num
    LA      x1, t_q10
    ldr     w2, [x28, #G_PEOPLEN]
    bl      pt_num
    LA      x1, t_pnl
    bl      strcat_cur
    bl      sk_write
pt_ret:
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ---------------------------------------------------------------------

// =====================================================================
//  Personagens em 8 direcoes (os quadros estao em personagens.S)
// =====================================================================

// char_dir(s0 = du, s1 = dv: quanto andou, w0 = direcao de antes) -> w0
// direcao na tela: 0 S, 1 SO, 2 O, 3 NO, 4 N, 5 NE, 6 L, 7 SE   folha
    .globl char_dir
char_dir:
    fsub    s2, s0, s1                  // x na tela
    fadd    s3, s0, s1
    fmov    s4, #0.5
    fmul    s3, s3, s4                  // y na tela (para baixo)
    fabs    s4, s2
    fabs    s5, s3
    fadd    s6, s4, s5
    MOVI32  w9, 0x38D1B717              // 0,0001: parado, fica como estava
    fmov    s7, w9
    fcmp    s6, s7
    b.lt    9f
    fmov    s7, #0.40625                // ~ tan(22,5 graus)
    fmul    s6, s4, s7
    fcmp    s5, s6
    b.gt    1f
    mov     w0, #6                      // de lado: L ou O
    mov     w9, #2
    fcmp    s2, #0.0
    csel    w0, w0, w9, gt
    ret
1:  fmul    s6, s5, s7
    fcmp    s4, s6
    b.gt    2f
    mov     w0, #0                      // de frente (S) ou de costas (N)
    mov     w9, #4
    fcmp    s3, #0.0
    csel    w0, w0, w9, gt
    ret
2:  fcmp    s3, #0.0                    // diagonais
    b.le    3f
    mov     w0, #7                      // SE
    mov     w9, #1                      // SO
    fcmp    s2, #0.0
    csel    w0, w0, w9, gt
    ret
3:  mov     w0, #5                      // NE
    mov     w9, #3                      // NO
    fcmp    s2, #0.0
    csel    w0, w0, w9, gt
9:  ret

// char_ptr(w0 = conjunto, w1 = direcao, w2 = pose) -> x0 = quadro   folha
    .globl char_ptr
char_ptr:
    mov     w9, #24
    mov     w10, #3
    madd    w9, w0, w9, w2
    madd    w9, w1, w10, w9
    mov     w10, #320
    mul     w9, w9, w10
    LA      x0, charspr
    add     x0, x0, x9
    ret

// player_sprite -> x0 = o quadro do profeta (direcao em que andou; sem o
// cajado quando tem algo na mao ou a tocha acesa)
    .globl player_sprite
player_sprite:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x9, pllast
    ldp     s2, s3, [x9]
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    stp     s0, s1, [x9]
    fsub    s0, s0, s2
    fsub    s1, s1, s3
    LA      x9, pldir
    ldrb    w0, [x9]
    bl      char_dir
    LA      x9, pldir
    strb    w0, [x9]
    mov     w1, w0
    mov     w2, #0
    ldr     w10, [x28, #G_PMOVING]
    cbz     w10, 1f
    ldr     w10, [x28, #G_PFRAME]
    lsr     w10, w10, #3
    and     w10, w10, #3
    LA      x11, poseseq
    ldrb    w2, [x11, x10]
1:  ldr     w9, [x28, #G_HAND]
    ldr     w10, [x28, #G_TORCHLIT]
    orr     w9, w9, w10
    cmp     w9, #0
    cset    w0, ne
    bl      char_ptr
    ldp     x29, x30, [sp], #16
    ret

    .data
poseseq:    .byte 0, 1, 0, 2            // o ciclo de passos
pldir:      .byte 0
    .p2align 3
pllast:     .space 8
plast:      .space (MAXPEOPLE * 8)      // onde cada um estava no ultimo quadro
pdirs:      .space MAXPEOPLE
    .p2align 2
    .p2align 2
pconst:
    .float 0.002                        //   0 fome por quadro (cheio -> vazio em ~14 min)
    .float 0.008                        //   4 vida perdida sem comida
    .float 0.004                        //   8 vida recuperada bem alimentado
    .float 0.006                        //  12 vida perdida no frio
    .float 0.00833                      //  16 fe ganha perto do personagem (~30/min)
    .float 0.000556                     //  20 fe perdida longe (~2/min)
    .float 0.045                        //  24 velocidade: adulto
    .float 0.035                        //  28 crianca
    .float 0.085                        //  32 fugindo
    .float 1.3                          //  36 no caminho de terra batida
    .float 0.015625                     //  40 1/64
    .float 100.0                        //  44
    .float 0.0144                       //  48 chegou (0,12 celula)^2
    .float 0.36                         //  52
    .float 36.0                         //  56 6 celulas^2 (fe)
    .float 25.0                         //  60 5 celulas^2 (fogo, bicho)
    .float 0.64                         //  64 0,8 celula^2 (mouse)
    .float 1600.0                       //  68 40 celulas^2
    .float 0.6                          //  72 fica do lado (0,6 celula)
    .float 1.0e9                        //  76 longe demais
    .float 15.0                         //  80 bicho furioso
    .float 2.0                          //  84
    .float 2.0                          //  88 borda do mapa
    .float 509.0                        //  92
    .float 0.5                          //  96
    .float 0.1                          // 100
    .float 50.0                         // 104
    .float 6.0                          // 108 foge 6 celulas
    .float 40.0                         // 112 come abaixo disto
    .float 25.0                         // 116 pouca fe
    .float 900.0                        // 120 30 celulas^2
    .float 80.0                         // 124 come ate isto
    .float 15.0                         // 128 uma fruta
    .float 1.3                          // 132
    .float 144.0                        // 136 12 celulas^2
    .float 10.8                         // 140 teste: ~14 celulas (x 1.3)

// 8 lugares em volta de uma fogueira
ring8:
    .float 1.3, 0.0,   0.9, 0.9,   0.0, 1.3,   -0.9, 0.9
    .float -1.3, 0.0,  -0.9, -0.9, 0.0, -1.3,  0.9, -0.9

// tempo de cada tipo de trabalho (quadros, com fe 50)
    .p2align 1
worktime:
    .hword 0, 150, 210, 60, 40, 90, 90, 40, 150, 300, 500

// o que cada tarefa carrega e quanto cabe
jobitem:
    .byte 0, IT_WOOD, IT_STONE, IT_WHEAT, 0, IT_IRON, IT_FISH, 0
jobcap:
    .byte 0, 4, 3, 6, 0, 1, 4, 0
// tipos de zona na paleta (a Pedra nao tem zona: procura sozinha)
zptypes:
    .byte Z_FOREST, Z_FARM, Z_HOME, Z_FISH, Z_DEPF, Z_DEPM, Z_DEPT, Z_DEPG
    .byte Z_ERASE
// cor da roupa de cada familia (variante dos sprites: vermelho, azul, laranja)
famvar:
    .byte 0, 2, 3
campoff:
    .byte 2, 0,  0, 2,  -2, 0,  0, -2,  2, 2,  -2, 2,  2, -2,  -2, -2
    .byte 3, 0,  0, 3,  -3, 0,  0, -3

    .p2align 2
    .globl zonecolors
zonecolors:
    .word 0, 0xFF30B050, 0xFFA8A8C8, 0xFFF0D040, 0xFFE09060, 0xFF38C8F0, 0xFFB86A3C, 0xFFE04848
    .word 0xFFF08C3C, 0xFF9C7A5A, 0xFFA884E0, 0xFFE8E8F0

    .p2align 3
causemsgs:
    .quad s_dnone, s_dfome, s_dfrio, s_dbicho, s_dvelho, s_dfe

    .p2align 4
pnames:
    .asciz "Joao"
    .p2align 4
    .asciz "Pedro"
    .p2align 4
    .asciz "Lucas"
    .p2align 4
    .asciz "Mateus"
    .p2align 4
    .asciz "Tiago"
    .p2align 4
    .asciz "Rafael"
    .p2align 4
    .asciz "Bruno"
    .p2align 4
    .asciz "Davi"
    .p2align 4
    .asciz "Caio"
    .p2align 4
    .asciz "Enzo"
    .p2align 4
    .asciz "Gabriel"
    .p2align 4
    .asciz "Hugo"
    .p2align 4
    .asciz "Ana"
    .p2align 4
    .asciz "Maria"
    .p2align 4
    .asciz "Julia"
    .p2align 4
    .asciz "Clara"
    .p2align 4
    .asciz "Lara"
    .p2align 4
    .asciz "Bia"
    .p2align 4
    .asciz "Lia"
    .p2align 4
    .asciz "Sofia"
    .p2align 4
    .asciz "Luiza"
    .p2align 4
    .asciz "Alice"
    .p2align 4
    .asciz "Helena"
    .p2align 4
    .asciz "Rita"
    .p2align 4
psurn:
    .asciz "Silva"
    .p2align 4
    .asciz "Souza"
    .p2align 4
    .asciz "Lima"
    .p2align 4
jobnames:
    .asciz "Nenhuma"
    .p2align 4
    .asciz "Floresta"
    .p2align 4
    .asciz "Pedra"
    .p2align 4
    .asciz "Plantar"
    .p2align 4
    .asciz "Obras"
    .p2align 4
    .asciz "Ferreiro"
    .p2align 4
    .asciz "Pescador"
    .p2align 4
    .asciz "Soldado"
    .p2align 4
zonenames:
    .asciz ""
    .p2align 4
    .asciz "1 Floresta"
    .p2align 4
    .asciz ""
    .p2align 4
    .asciz "2 Plantacao"
    .p2align 4
    .asciz "3 Moradia"
    .p2align 4
    .asciz "4 Pesca"
    .p2align 4
    .asciz ""
    .p2align 4
    .asciz "0 Apagar"
    .p2align 4
    .asciz "5 Dep. comida"
    .p2align 4
    .asciz "6 Dep. material"
    .p2align 4
    .asciz "7 Dep. ferram."
    .p2align 4
    .asciz "8 Dep. geral"
    .p2align 4

s_sp:       .asciz " "
s_comma:    .asciz ", "
s_colon:    .asciz ": "
s_anos:     .asciz " anos - "
s_fe:       .asciz " | fe "
s_pct:      .asciz "%"
s_kid:      .asciz "crianca"
s_kidcap:   .asciz "Crianca"
s_sleeping: .asciz " (dormindo)"
s_hungry:   .asciz " (com fome)"
s_adult:    .asciz " fez 14 anos: ja pode trabalhar"
s_dnone:    .asciz " se foi"
s_dfome:    .asciz " morreu de fome"
s_dfrio:    .asciz " morreu de frio"
s_dbicho:   .asciz " foi morto(a) por um bicho"
s_dvelho:   .asciz " morreu de velhice"
s_dfe:      .asciz " perdeu a fe e foi embora"
s_kidnojob: .asciz ": crianca ainda nao trabalha (14 anos)"
s_refuse:   .asciz " nao quis (pouca fe)"
s_going:    .asciz ": indo"
s_selected: .asciz " - botao direito no mapa: va ate la"
m_nochest:  .asciz "A vila precisa de deposito com lugar: pinte um (Z, 5 a 8)"
m_zonemode: .asciz "Zonas: 1-8 escolhe, 0 apaga; pinte segurando o botao (direito apaga), roda ou [ ] muda o pincel (Z sai)"
s_zonedone: .asciz "Zona marcada: "
s_zoneerase: .asciz "Zona apagada: "
s_quads:    .asciz " quadrados"
s_ptitle:   .asciz "Pessoas (P)"
s_ztitle:   .asciz "Zonas (Z)"
s_hname:    .asciz "Nome"
s_hage:     .asciz "Anos"
s_hjob:     .asciz "Tarefa"
s_hfe:      .asciz "Fe"
s_hnow:     .asciz "Agora"
s_bar:      .asciz " | "
d_idle:     .asciz "parado"
d_sleep:    .asciz "dormindo"
d_flee:     .asciz "fugindo!"
d_chop:     .asciz "cortando"
d_mine:     .asciz "quebrando"
d_harv:     .asciz "colhendo"
d_plant:    .asciz "plantando"
d_till:     .asciz "arando"
d_sapl:     .asciz "pondo muda"
d_fruit:    .asciz "pega fruta"
d_build:    .asciz "construindo"
d_smelt:    .asciz "na fornalha"
d_fish:     .asciz "pescando"
d_fight:    .asciz "lutando!"
d_guard:    .asciz "de guarda"
d_walk0:    .asciz "passeando"
d_walk1:    .asciz "a caminho"
d_walk2:    .asciz "vai guardar"
d_walk3:    .asciz "vai comer"
d_walk4:    .asciz "vai ao bau"
d_walk5:    .asciz "vai dormir"
d_walk6:    .asciz "ordem"
    .p2align 3
d_work:     .quad d_idle, d_chop, d_mine, d_harv, d_plant, d_till, d_sapl, d_fruit, d_build, d_smelt, d_fish
d_walk:     .quad d_walk0, d_walk1, d_walk2, d_walk3, d_walk4, d_walk5, d_walk6, d_walk4, d_walk4, d_walk4
s_hfood:    .asciz "Fo"
s_hhp:      .asciz "Vi"
s_pfoot:    .asciz "clique na tarefa"
s_tfoot:    .asciz "cinza: ja se foi"
s_htree:    .asciz "Arvore genealogica (filho leva o sobrenome do pai)"
s_tabp:     .asciz "Pessoas"
s_tabf:     .asciz "Familias"
s_lt:       .asciz "<"
s_gt:       .asciz ">"
s_slash:    .asciz "/"
s_zfoot:    .asciz "Pincel: "
s_zfoot2:   .asciz " (roda, [ ])"
s_zfoot3:   .asciz "Esq pinta, dir apaga"
t_p1:       .asciz "pessoas: vivas="
t_p2:       .asciz " | no bau: madeira="
t_p3:       .asciz " pedra="
t_p4:       .asciz " | aradas="
t_p5:       .asciz " trigo plantado="
t_p6:       .asciz " mudas="
t_p7:       .asciz " | caminho="
t_p8:       .asciz " | de noite dormindo (ou indo)="
t_p9:       .asciz " | idade: "
t_p10:      .asciz " -> "
t_p11:      .asciz " (24 dias) | lobo: vida 100 -> "
t_q1:       .asciz "vila: casas (barraco -> casa)="
t_q2:       .asciz " cercas="
t_q3:       .asciz " | floresta: mudas="
t_q4:       .asciz " -> jovens (1 ano)="
t_q5:       .asciz " -> adultas (2 anos)="
t_q6:       .asciz " | casamentos="
t_q7:       .asciz " nascimentos="
t_q8:       .asciz " | depois das obras: familias com casa="
t_q9:       .asciz " de "
t_q10:      .asciz " | vivos="
t_pnl:      .asciz "\n"
    .globl pmsgbuf, psurn, pnames, pconst
pmsgbuf:    .space 96
pmsgbuf2:   .space 64
pbuf:       .space 64
ptitle:     .space 64
pt_res:     .word -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
prows:      .word 0
prowmap:    .space PP_ROWS

GBSS people, (MAXPEOPLE * PSIZE)
GBSS zonegrid, 262144                   // zona de trabalho de cada celula (Z_*)
GBSS walkgrid, 262144                   // passadas (vira caminho)
