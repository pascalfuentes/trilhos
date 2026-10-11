// =====================================================================
//  plantacao.S - trigo, enxada, sementes e plantacao (como no Minecraft)
//
//  - Trigo selvagem nasce nos campos abertos. Colhido (segurando o botao
//    esquerdo), da 1 trigo e 1-2 sementes.
//  - Enxada na mao (tecla 6): segure o botao esquerdo e passe o mouse
//    pela grama para arar (terra, nao areia, rocha nem agua; nada em cima).
//    A terra arada fica no mapa (overlay 2 = seca, 3 = molhada).
//  - Sementes na mao (tecla 7): passe pela terra arada para plantar.
//  - O trigo cresce em 4 estagios. Com agua a ate 4 quadrados a terra
//    fica molhada (mais escura) e ele cresce 2x mais rapido. Chuva e
//    tempestade: 1,5x. Calorao: metade, se a terra estiver seca. Neve
//    e inverno: para.
//  - Maduro (dourado): colher da 1 trigo e 1-3 sementes (a skill
//    Agricultura da chance de 1 a mais de cada). Verde nao sai: tem que
//    esperar. So a enxada desfaz a terra arada (volta a ser grama) e a
//    planta verde que estiver nela se perde, com a semente.
//    Numa mesma segurada do botao a enxada so ara ou so desfaz (o que
//    fez primeiro), para nao desfazer o que acabou de arar.
//  - Coelhos, cervos e cabras vao atras do trigo maduro e comem: a cerca
//    protege a plantacao.
//  - 3 trigos viram pao na fogueira.
// =====================================================================

#include "comum.h"

// campos do animal (os mesmos de animais.S)
.equ AN_U,     0
.equ AN_V,     4
.equ AN_DU,    8
.equ AN_DV,    12
.equ AN_TYPE,  16
.equ AN_HP,    17
.equ AN_TIMER, 20

    .text
    .p2align 2

// farm_reset: refaz a lista das plantas (objetos de trigo plantado)
    .globl farm_reset
farm_reset:
    str     wzr, [x28, #G_FARMLAST]
    str     wzr, [x28, #G_CROPT]
    ldr     w9, [x28, #G_NOBJ]
    LA      x10, objs
    LA      x11, croplist
    mov     w12, #0
    mov     w13, #0
1:  cmp     w12, w9
    b.ge    9f
    ldrb    w14, [x10, #6]
    cmp     w14, #O_CROP
    b.ne    2f
    cmp     w13, #MAXCROP
    b.hs    2f
    str     w12, [x11, x13, lsl #2]
    add     w13, w13, #1
2:  add     x10, x10, #8
    add     w12, w12, #1
    b       1b
9:  str     w13, [x28, #G_NCROP]
    ret

// farm_wet(w0 = celula) -> w0 = 1 se tem agua a ate 4 quadrados   folha
    .globl farm_wet
farm_wet:
    and     w1, w0, #511
    lsr     w2, w0, #9
    ldr     w3, [x28, #G_FLOOD]
    LA      x4, elev
    mov     w5, #-4
1:  mov     w6, #-4
2:  add     w7, w1, w6
    add     w8, w2, w5
    cmp     w7, #511
    b.hs    3f
    cmp     w8, #511
    b.hs    3f
    add     w7, w7, w8, lsl #9
    ldrsh   w7, [x4, w7, uxtw #1]
    cmp     w7, w3
    b.lt    8f
3:  add     w6, w6, #1
    cmp     w6, #4
    b.le    2b
    add     w5, w5, #1
    cmp     w5, #4
    b.le    1b
    mov     w0, #0
    ret
8:  mov     w0, #1
    ret

// obj_in_cell(w0 = celula) -> w0 = objeto naquela celula (-1 nenhum)  folha
    .globl obj_in_cell
obj_in_cell:
    ldr     w9, [x28, #G_NOBJ]
    LA      x10, objs
    mov     w11, #0
    mov     w12, w0
1:  cmp     w11, w9
    b.ge    8f
    ldrb    w13, [x10, #6]
    cmp     w13, #O_LAST
    b.hi    2f
    ldrh    w14, [x10]
    lsr     w14, w14, #6
    ldrh    w15, [x10, #2]
    lsr     w15, w15, #6
    add     w14, w14, w15, lsl #9
    cmp     w14, w12
    b.ne    2f
    mov     w0, w11
    ret
2:  add     x10, x10, #8
    add     w11, w11, #1
    b       1b
8:  mov     w0, #-1
    ret

// till_ok(w0 = celula) -> x0 = 0 se a enxada ara ali (senao o motivo)
till_ok:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w0
    LA      x0, m_tilled
    LA      x9, overlay
    ldrb    w9, [x9, w19, uxtw]
    cbnz    w9, 9f
    LA      x0, m_notill
    LA      x9, fencegrid
    ldrb    w9, [x9, w19, uxtw]
    cbnz    w9, 9f
    and     w9, w19, #511               // terreno no meio da celula
    lsr     w10, w19, #9
    scvtf   s0, w9
    scvtf   s1, w10
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9                      // agua
    b.lt    7f
    cmp     w0, #(E_SAND + 20)          // praia
    b.lt    7f
    mov     w9, #E_ROCK                 // rocha e neve
    cmp     w0, w9
    b.ge    7f
    mov     w0, w19                     // arvore, pedra, bau... em cima
    bl      obj_in_cell
    tbz     w0, #31, 8f
    mov     x0, #0
    b       9f
7:  LA      x0, m_notill
    b       9f
8:  LA      x0, m_blocked
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// crop_add(w0 = objeto): entra na lista das plantas    folha
crop_add:
    ldr     w9, [x28, #G_NCROP]
    LA      x10, croplist
    LA      x11, objs
    mov     w12, #0
1:  cmp     w12, w9                     // vaga de uma planta que ja foi?
    b.ge    3f
    ldr     w13, [x10, x12, lsl #2]
    add     x14, x11, x13, lsl #3
    ldrb    w14, [x14, #6]
    cmp     w14, #O_CROP
    b.ne    4f
    add     w12, w12, #1
    b       1b
3:  cmp     w9, #MAXCROP
    b.hs    9f
    add     w9, w9, #1
    str     w9, [x28, #G_NCROP]
4:  str     w0, [x10, x12, lsl #2]
9:  ret

// plant_at(w0 = celula) -> w0 = objeto: semente plantada no meio da celula
    .globl plant_at
plant_at:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w0
    and     w9, w19, #511
    lsr     w10, w19, #9
    scvtf   s0, w9
    scvtf   s1, w10
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      elev_at
    mov     w2, w0
    and     w9, w19, #511
    lsl     w0, w9, #6
    add     w0, w0, #32
    lsr     w10, w19, #9
    lsl     w1, w10, #6
    add     w1, w1, #32
    mov     w3, #O_CROP
    mov     w4, #0
    bl      add_obj
    ldr     w0, [x28, #G_NOBJ]
    sub     w0, w0, #1
    LA      x9, memtype                 // ja aparece (a vista)
    mov     w10, #O_CROP
    strb    w10, [x9, w0, uxtw]
    str     w0, [sp, #24]
    bl      crop_add
    ldr     w0, [sp, #24]
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// farm_act -> w0 = 1 se fez algo: segurando o botao esquerdo com a enxada
// (ara) ou com sementes (planta) na celula sob o mouse, uma vez por celula
    .globl farm_act
farm_act:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    ldr     w9, [x28, #G_HAND]
    sub     w19, w9, #1                 // item na mao
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 90f
    ldr     w20, [x28, #G_HOVU]
    lsr     w20, w20, #6
    ldr     w21, [x28, #G_HOVV]
    lsr     w21, w21, #6
    cmp     w20, #2
    b.lt    90f
    cmp     w21, #2
    b.lt    90f
    cmp     w20, #509
    b.gt    90f
    cmp     w21, #509
    b.gt    90f
    add     w22, w20, w21, lsl #9       // celula
    ldr     w9, [x28, #G_FARMLAST]      // ja mexeu nesta celula
    add     w10, w22, #1
    cmp     w9, w10
    b.eq    90f
    scvtf   s0, w20                     // alcance: 3 celulas
    scvtf   s1, w21
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    ldr     s2, [x28, #G_PU]
    ldr     s3, [x28, #G_PV]
    fsub    s0, s0, s2
    fsub    s1, s1, s3
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fmov    s1, #9.0
    fcmp    s0, s1
    b.gt    90f
    cmp     w19, #IT_HOE
    b.ne    50f
    LA      x9, overlay                 // ja arada: a enxada desfaz
    ldrb    w9, [x9, w22, uxtw]
    cmp     w9, #2
    b.hs    20f
    // ---- arar ----
    ldr     w9, [x28, #G_FARMMODE]      // nesta segurada esta desfazendo
    cmp     w9, #1
    b.hi    90f
    mov     w0, w22
    bl      till_ok
    cbz     x0, 10f
    LA      x9, m_notill                // so avisa do terreno (com algo em
    cmp     x0, x9                      // cima, o botao colhe)
    b.ne    90f
    bl      set_msg
    b       85f
10: mov     w0, w22
    bl      farm_wet
    add     w0, w0, #2
    LA      x9, overlay
    strb    w0, [x9, w22, uxtw]
    mov     w9, #1                      // esta segurada: arar
    str     w9, [x28, #G_FARMMODE]
    mov     w0, #IT_HOE
    bl      tool_use
    mov     w0, #SK_FARM
    LA      x9, fpconst
    ldr     s0, [x9, #8]
    bl      skill_train
    LA      x0, p_till
    bl      popup
    b       80f
    // ---- desfazer a terra arada (e a planta verde, que se perde) ----
20: ldr     w9, [x28, #G_FARMMODE]      // nesta segurada esta arando
    cmp     w9, #1
    b.eq    90f
    cmp     w9, #3
    b.eq    90f
    LA      x9, overlay                 // estrada: a enxada desfaz (a pedra volta)
    ldrb    w9, [x9, w22, uxtw]
    cmp     w9, #4
    b.ne    201f
    mov     w0, w22
    bl      road_dig
    mov     w9, #2
    str     w9, [x28, #G_FARMMODE]
    mov     w0, #IT_HOE
    bl      tool_use
    b       80f
201: LA     x20, p_untill
    mov     w0, w22
    bl      obj_in_cell
    tbnz    w0, #31, 23f
    LA      x9, objs
    add     x10, x9, x0, lsl #3
    ldrb    w11, [x10, #6]
    cmp     w11, #O_CROP
    b.ne    90f
    ldrb    w11, [x10, #7]
    cmp     w11, #CROPRIPE
    b.lo    22f
    ldr     w9, [x28, #G_FARMMODE]      // madura: o botao colhe (e nao
    cbnz    w9, 90f                     // desfaz mais nesta segurada)
    mov     w9, #3
    str     w9, [x28, #G_FARMMODE]
    b       90f
22: mov     w11, #O_GONE
    strb    w11, [x10, #6]
    LA      x20, p_uproot
23: LA      x9, overlay
    strb    wzr, [x9, w22, uxtw]
    mov     w9, #2                      // esta segurada: desfazer
    str     w9, [x28, #G_FARMMODE]
    mov     w0, #IT_HOE
    bl      tool_use
    mov     x0, x20
    bl      popup
    b       80f
    // ---- plantar ----
50: LA      x9, overlay
    ldrb    w9, [x9, w22, uxtw]
    cmp     w9, #4                      // na estrada nao
    b.eq    90f
    cmp     w9, #2
    b.hs    51f
    mov     w0, w22                     // em cima de outra coisa: deixa colher
    bl      obj_in_cell
    tbz     w0, #31, 90f
    LA      x0, m_needtill
    bl      set_msg
    b       85f
51: mov     w0, w22                     // ja tem planta: deixa colher
    bl      obj_in_cell
    tbz     w0, #31, 90f
    ldr     w9, [x28, #(G_INV + 4 * IT_SEED)]
    cbz     w9, 90f
    mov     w0, w22
    bl      plant_at
    ldr     w9, [x28, #(G_INV + 4 * IT_SEED)]
    sub     w9, w9, #1
    str     w9, [x28, #(G_INV + 4 * IT_SEED)]
    bl      calc_stats
    LA      x0, p_plant
    bl      popup
    ldr     w9, [x28, #(G_INV + 4 * IT_SEED)]
    cbnz    w9, 80f
    str     wzr, [x28, #G_HAND]         // acabaram as sementes
    LA      x0, m_noseeds
    bl      set_msg
80: add     w9, w22, #1
    str     w9, [x28, #G_FARMLAST]
    mov     w0, #1
    b       99f
85: add     w9, w22, #1
    str     w9, [x28, #G_FARMLAST]
90: mov     w0, #0
99: ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// farm_tint(w0 = celula) -> w0 = cor do quadrado sob o mouse com a enxada
// ou as sementes na mao (0 = nao pinta: tem algo ali para colher)
//   verde = ara / planta, laranja = a enxada desfaz, vermelho = nao da
    .globl farm_tint
farm_tint:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, w0
    and     w9, w19, #511               // alcance: 3 celulas
    lsr     w10, w19, #9
    scvtf   s0, w9
    scvtf   s1, w10
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    ldr     s2, [x28, #G_PU]
    ldr     s3, [x28, #G_PV]
    fsub    s0, s0, s2
    fsub    s1, s1, s3
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fmov    s1, #9.0
    fcmp    s0, s1
    b.gt    7f
    ldr     w9, [x28, #G_HAND]
    sub     w20, w9, #1
    LA      x9, overlay
    ldrb    w9, [x9, w19, uxtw]
    cmp     w20, #IT_HOE
    b.ne    5f
    cmp     w9, #2                      // enxada na terra arada: desfaz
    b.lo    2f
    mov     w0, w19
    bl      obj_in_cell
    tbnz    w0, #31, 1f
    LA      x9, objs                    // trigo maduro: o botao colhe
    add     x9, x9, x0, lsl #3
    ldrb    w10, [x9, #7]
    cmp     w10, #CROPRIPE
    b.hs    8f
1:  MOVI32  w0, 0xFFF0A030
    b       9f
2:  mov     w0, w19                     // enxada na grama: ara?
    bl      till_ok
    cbz     x0, 6f
    LA      x9, m_blocked
    cmp     x0, x9
    b.eq    8f
    b       7f
5:  mov     w0, w19                     // sementes: terra arada vazia
    bl      obj_in_cell
    tbz     w0, #31, 8f
    LA      x9, overlay
    ldrb    w9, [x9, w19, uxtw]
    cmp     w9, #2
    b.lo    7f
    cmp     w9, #3
    b.hi    7f
6:  MOVI32  w0, 0xFF40E060
    b       9f
7:  MOVI32  w0, 0xFFE03C30
    b       9f
8:  mov     w0, #0
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// crop_update: a cada 16 quadros as plantas crescem um pouco
    .globl crop_update
crop_update:
    ldr     w9, [x28, #G_CROPT]
    add     w9, w9, #1
    and     w9, w9, #15
    str     w9, [x28, #G_CROPT]
    cbnz    w9, 1f
    b       crop_tick
1:  ret

// crop_tick: um passo de crescimento de todas as plantas.
// Chance por passo (em 1000): 71 (maduro em ~1 dia de jogo, 12 min);
// com agua perto 2x; chuva e tempestade 1,5x; calorao na terra seca
// metade; neve e inverno nada.
    .globl crop_tick
crop_tick:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
    mov     w23, #16                    // fator (em 16 avos)
    mov     w24, #0                     // calorao
    ldr     w9, [x28, #G_SEASON]
    cmp     w9, #2                      // outono e inverno: nada cresce
    b.lo    1f
    mov     w23, #0
1:  ldr     w9, [x28, #G_WEATHER]
    cmp     w9, #W_SNOW
    b.ne    2f
    mov     w23, #0
2:  cmp     w9, #W_RAIN
    b.eq    3f
    cmp     w9, #W_STORM
    b.ne    4f
3:  cbz     w23, 4f
    mov     w23, #24
4:  cmp     w9, #W_HEAT
    cset    w24, eq
    ldr     w19, [x28, #G_NCROP]
    mov     w20, #0
5:  cmp     w20, w19
    b.ge    99f
    LA      x9, croplist
    ldr     w10, [x9, x20, lsl #2]
    LA      x9, objs
    add     x22, x9, x10, lsl #3
    ldrb    w9, [x22, #6]
    cmp     w9, #O_CROP
    b.ne    8f
    ldrh    w9, [x22]                   // celula
    lsr     w9, w9, #6
    ldrh    w10, [x22, #2]
    lsr     w10, w10, #6
    add     w25, w9, w10, lsl #9
    mov     w0, w25
    bl      farm_wet
    mov     w21, w0
    LA      x9, overlay                 // terra molhada fica mais escura
    add     w10, w21, #2
    strb    w10, [x9, w25, uxtw]
    ldrb    w9, [x22, #7]
    cmp     w9, #CROPRIPE
    b.hs    8f
    mov     w10, #CROPP
    mul     w10, w10, w23
    lsr     w10, w10, #4
    lsl     w11, w10, #1                // agua perto: 2x
    cmp     w21, #0
    csel    w10, w11, w10, ne
    cbz     w24, 6f                     // calorao na terra seca: metade
    cbnz    w21, 6f
    lsr     w10, w10, #1
6:  mov     w25, w10
    mov     w0, #1000
    bl      rng_mod
    cmp     w0, w25
    b.hs    8f
    ldrb    w9, [x22, #7]
    add     w9, w9, #1
    strb    w9, [x22, #7]
8:  add     w20, w20, #1
    b       5b
99: ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// crop_harvest(w0 = objeto de trigo selvagem ou plantado): colhe
    .globl crop_harvest
crop_harvest:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    LA      x9, objs
    add     x19, x9, x0, lsl #3
    ldrb    w9, [x19, #6]
    ldrb    w10, [x19, #7]
    cmp     w9, #O_WHEAT
    b.ne    1f
    // selvagem: 1 trigo e 1 semente
    mov     w20, #1
    mov     w21, #1
    mov     w0, #SK_FARM
    LA      x9, fpconst
    ldr     s0, [x9, #12]
    bl      skill_train
    b       5f
1:  cmp     w10, #CROPRIPE
    b.hs    2f
    mov     w20, #0                     // verde: so a semente volta
    mov     w21, #1
    b       5f
    // maduro: 1 trigo, 1-2 sementes; a skill da chance de +1 de cada
2:  ldr     s0, [x28, #G_SKFARM]
    fcvtzs  w22, s0
    lsr     w22, w22, #1                // chance (%) = skill / 2
    mov     w0, #100
    bl      rng_mod
    cmp     w0, w22
    cset    w20, lo
    add     w20, w20, #1
    mov     w0, #2
    bl      rng_mod
    add     w21, w0, #1
    mov     w0, #100
    bl      rng_mod
    cmp     w0, w22
    cinc    w21, w21, lo
    mov     w0, #SK_FARM
    LA      x9, fpconst
    ldr     s0, [x9, #16]
    bl      skill_train
5:  mov     w9, #O_GONE
    strb    w9, [x19, #6]
    cbz     w20, 6f
    mov     w0, #IT_WHEAT
    mov     w1, w20
    bl      inv_add
6:  mov     w0, #IT_SEED
    mov     w1, w21
    bl      inv_add
    bl      calc_stats
    LA      x0, farmpop                 // "+1 trigo +2 sementes"
    cbz     w20, 7f
    LA      x1, s_plus
    bl      strcat_cur
    mov     w1, w20
    bl      numcat
    LA      x1, s_trigo
    bl      strcat_cur
7:  LA      x1, s_plus
    bl      strcat_cur
    mov     w1, w21
    bl      numcat
    LA      x1, s_sem
    cmp     w21, #1
    b.ne    8f
    LA      x1, s_sem1
8:  bl      strcat_cur
    LA      x0, farmpop
    bl      popup
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// crop_tipcat(x0 = cursor, w1 = objeto) -> x0: " (crescendo 40%)" ou maduro
    .globl crop_tipcat
crop_tipcat:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    LA      x9, objs
    add     x9, x9, x1, lsl #3
    ldrb    w10, [x9, #7]
    cmp     w10, #CROPRIPE
    b.lo    1f
    LA      x1, s_ripe
    bl      strcat_cur
    b       9f
1:  mov     w11, #100
    mul     w10, w10, w11
    mov     w11, #CROPRIPE
    udiv    w10, w10, w11
    str     w10, [sp, #16]
    LA      x1, s_grow
    bl      strcat_cur
    ldr     w1, [sp, #16]
    bl      numcat
    LA      x1, s_pct
    bl      strcat_cur
9:  ldp     x29, x30, [sp], #32
    ret

// crop_seek(x0 = animal, s0 = velocidade) -> w0 = 1 se foi atras do trigo:
// um bicho pacifico ve trigo maduro a ate 8 celulas e vai comer
    .globl crop_seek
crop_seek:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    stp     d10, d11, [sp, #64]
    stp     d12, d13, [sp, #80]
    mov     x19, x0
    fmov    s8, s0
    ldr     s9, [x19, #AN_U]
    ldr     s10, [x19, #AN_V]
    LA      x9, fpconst
    ldr     s11, [x9]                   // melhor distancia^2 (8 celulas)
    mov     w20, #-1
    mov     w21, #0
    ldr     w22, [x28, #G_NCROP]
1:  cmp     w21, w22
    b.ge    5f
    LA      x9, croplist
    ldr     w10, [x9, x21, lsl #2]
    LA      x9, objs
    add     x11, x9, x10, lsl #3
    ldrb    w12, [x11, #6]
    cmp     w12, #O_CROP
    b.ne    4f
    ldrb    w12, [x11, #7]
    cmp     w12, #CROPRIPE
    b.lo    4f
    ldrh    w12, [x11]
    ucvtf   s0, w12
    ldrh    w12, [x11, #2]
    ucvtf   s1, w12
    LA      x9, fpconst
    ldr     s2, [x9, #20]               // 1/64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    fsub    s0, s0, s9
    fsub    s1, s1, s10
    fmul    s3, s0, s0
    fmadd   s3, s1, s1, s3
    fcmp    s3, s11
    b.ge    4f
    fmov    s11, s3
    fmov    s12, s0
    fmov    s13, s1
    mov     w20, w10
4:  add     w21, w21, #1
    b       1b
5:  tbnz    w20, #31, 90f
    LA      x9, fpconst
    ldr     s2, [x9, #4]                // chegou (0,6 celula): come
    fcmp    s11, s2
    b.ge    6f
    LA      x9, objs
    add     x9, x9, x20, lsl #3
    mov     w10, #O_GONE
    strb    w10, [x9, #6]
    ldrh    w10, [x9]                   // a vista: avisa
    lsr     w10, w10, #6
    ldrh    w11, [x9, #2]
    lsr     w11, w11, #6
    add     w10, w10, w11, lsl #9
    LA      x9, vis
    ldrb    w10, [x9, w10, uxtw]
    cmp     w10, #VIS_MIN
    b.lo    51f
    LA      x0, m_eaten
    bl      set_msg
51: str     wzr, [x19, #AN_DU]
    str     wzr, [x19, #AN_DV]
    mov     w9, #60
    strh    w9, [x19, #AN_TIMER]
    mov     w0, #1
    b       99f
6:  fsqrt   s0, s11                     // vai ate la
    fdiv    s1, s8, s0
    fmul    s2, s12, s1
    fmul    s3, s13, s1
    str     s2, [x19, #AN_DU]
    str     s3, [x19, #AN_DV]
    mov     w9, #20
    strh    w9, [x19, #AN_TIMER]
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
//  Teste automatico (--shot)
//    0: acha um lugar com agua perto, ara 3 x 2 com a enxada, planta,
//       poe as plantas em estagios diferentes e um trigo selvagem (foto)
//    1: colhe o maduro, faz pao, compara o crescimento com e sem agua
//       e no inverno, e um coelho come o trigo maduro sem cerca
// =====================================================================

// ft_occ: marca em focc as celulas com algum objeto
ft_occ:
    LA      x9, focc
    mov     w10, #(MAPN * MAPN / 16)
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    LA      x9, focc
    LA      x10, objs
    ldr     w11, [x28, #G_NOBJ]
    mov     w15, #1
2:  cbz     w11, 9f
    ldrb    w12, [x10, #6]
    cmp     w12, #O_LAST
    b.hi    3f
    ldrh    w13, [x10]
    lsr     w13, w13, #6
    ldrh    w14, [x10, #2]
    lsr     w14, w14, #6
    add     w13, w13, w14, lsl #9
    strb    w15, [x9, w13, uxtw]
3:  add     x10, x10, #8
    sub     w11, w11, #1
    b       2b
9:  ret

// ft_free(w0 = celula) -> w0 = 1 se da para arar (rapido, usa focc)
ft_free:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w0
    LA      x9, focc
    ldrb    w9, [x9, w19, uxtw]
    cbnz    w9, 8f
    LA      x9, overlay
    ldrb    w9, [x9, w19, uxtw]
    cbnz    w9, 8f
    LA      x9, fencegrid
    ldrb    w9, [x9, w19, uxtw]
    cbnz    w9, 8f
    and     w9, w19, #511
    lsr     w10, w19, #9
    scvtf   s0, w9
    scvtf   s1, w10
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    b.lt    8f
    cmp     w0, #(E_SAND + 20)
    b.lt    8f
    mov     w9, #E_HILL
    cmp     w0, w9
    b.ge    8f
    mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ft_block(w0 = celula) -> w0 = 1 se o bloco 3 x 2 dali esta livre
ft_block:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, w0
    mov     w20, #0
1:  cmp     w20, #6
    b.ge    7f
    mov     w10, #3
    udiv    w11, w20, w10
    msub    w9, w11, w10, w20
    add     w0, w19, w9
    add     w0, w0, w11, lsl #9
    bl      ft_free
    cbz     w0, 8f
    add     w20, w20, #1
    b       1b
7:  mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ft_find(w0 = 1 com agua perto / 0 sem, w1 = raio inicial) -> w0 = celula
// de um bloco 3 x 2 livre, em quadrados cada vez maiores em volta do
// personagem (-1 = nao achou)
ft_find:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
    mov     w19, w0
    mov     w22, w1                     // raio
    ldr     s0, [x28, #G_PU]
    fcvtzs  w20, s0
    ldr     s0, [x28, #G_PV]
    fcvtzs  w21, s0
1:  neg     w23, w22                    // dv
2:  neg     w24, w22                    // du
3:  cmp     w24, #0                     // so a borda do quadrado
    cneg    w9, w24, lt
    cmp     w23, #0
    cneg    w10, w23, lt
    cmp     w9, w10
    csel    w9, w9, w10, gt
    cmp     w9, w22
    b.ne    4f
    add     w9, w20, w24
    add     w10, w21, w23
    cmp     w9, #4
    b.lt    4f
    cmp     w10, #4
    b.lt    4f
    cmp     w9, #500
    b.gt    4f
    cmp     w10, #500
    b.gt    4f
    add     w25, w9, w10, lsl #9
    mov     w0, w25
    bl      ft_block
    cbz     w0, 4f
    mov     w0, w25                     // agua (ou nao) na celula 0 ...
    bl      farm_wet
    cmp     w0, w19
    b.ne    4f
    add     w0, w25, #513               // ... e na celula 4 do bloco
    bl      farm_wet
    cmp     w0, w19
    b.ne    4f
    mov     w0, w25
    b       9f
4:  add     w24, w24, #1
    cmp     w24, w22
    b.le    3b
    add     w23, w23, #1
    cmp     w23, w22
    b.le    2b
    add     w22, w22, #1
    cmp     w22, #90
    b.le    1b
    mov     w0, #-1
9:  ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ft_cell(w0 = i 0..5) -> w0 = celula i do bloco do teste    folha
ft_cell:
    LA      x9, ft_res
    ldr     w9, [x9]
    mov     w10, #3
    udiv    w11, w0, w10
    msub    w12, w11, w10, w0
    add     w0, w9, w12
    add     w0, w0, w11, lsl #9
    ret

// ft_hov(w0 = celula): mouse no meio da celula    folha
ft_hov:
    and     w9, w0, #511
    lsl     w9, w9, #6
    add     w9, w9, #32
    str     w9, [x28, #G_HOVU]
    lsr     w9, w0, #9
    lsl     w9, w9, #6
    add     w9, w9, #32
    str     w9, [x28, #G_HOVV]
    mov     w9, #1
    str     w9, [x28, #G_HOVOK]
    ret

// ft_doblock: segura o botao passando pelas 6 celulas do bloco
ft_doblock:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, #0
1:  cmp     w19, #6
    b.ge    9f
    mov     w0, w19
    bl      ft_cell
    bl      ft_hov
    mov     w9, #1
    str     w9, [x28, #G_LMB]
    bl      surv_update
    add     w19, w19, #1
    b       1b
9:  str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_FARMLAST]
    str     wzr, [x28, #G_FARMMODE]
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ft_pct(w0 = objeto) -> w0 = quanto cresceu (0..100)    folha
ft_pct:
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrb    w0, [x9, #7]
    mov     w10, #100
    mul     w0, w0, w10
    mov     w10, #CROPRIPE
    udiv    w0, w0, w10
    ret

// ft_num(x0 = cursor, x1 = rotulo, w2 = numero) -> x0
ft_num:
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

    .globl farm_selftest
farm_selftest:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    mov     w19, w0
    str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_MX]
    str     wzr, [x28, #G_MY]
    str     wzr, [x28, #G_SLEEP]
    str     wzr, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CRAFTOPEN]
    str     wzr, [x28, #G_CHAROPEN]
    str     wzr, [x28, #G_PLACE]
    str     wzr, [x28, #G_HAND]
    cmp     w19, #1
    b.eq    ft_stage1
    // ---- etapa 0: ara, planta, foto ----
    mov     w9, #6000
    str     w9, [x28, #G_TIME]
    bl      animals_reset
    bl      ft_occ
    mov     w0, #1                      // bloco livre com agua perto
    mov     w1, #3
    bl      ft_find
    LA      x9, ft_res
    str     w0, [x9]
    tbnz    w0, #31, ft_ret
    mov     w20, w0
    and     w9, w20, #511               // personagem no meio do bloco
    scvtf   s0, w9
    fmov    s1, #1.5
    fadd    s0, s0, s1
    str     s0, [x28, #G_PU]
    lsr     w9, w20, #9
    scvtf   s0, w9
    fmov    s1, #1.0
    fadd    s0, s0, s1
    str     s0, [x28, #G_PV]
    mov     w0, #IT_HOE
    mov     w1, #1
    bl      inv_add
    mov     w9, #8
    str     w9, [x28, #(G_INV + 4 * IT_SEED)]
    bl      surv_update
    mov     w0, #IT_HOE                 // enxada: ara as 6 celulas
    bl      equip
    bl      ft_doblock
    str     wzr, [x28, #G_HAND]
    mov     w0, #IT_SEED                // sementes: planta
    bl      equip
    bl      ft_doblock
    str     wzr, [x28, #G_HAND]
    str     wzr, [x28, #G_HOVOK]
    // conta: aradas e plantadas; estagios 0, 1, 2 | 3, 3, 3 para a foto
    mov     w21, #0
    mov     w22, #0
    mov     w23, #0
1:  cmp     w23, #6
    b.ge    3f
    mov     w0, w23
    bl      ft_cell
    mov     w24, w0
    LA      x9, overlay
    ldrb    w9, [x9, w24, uxtw]
    cmp     w9, #2
    cinc    w21, w21, hs
    mov     w0, w24
    bl      obj_in_cell
    tbnz    w0, #31, 2f
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrb    w10, [x9, #6]
    cmp     w10, #O_CROP
    b.ne    2f
    add     w22, w22, #1
    cmp     w23, #3
    mov     w10, #3
    csel    w10, w23, w10, lo
    lsl     w10, w10, #6
    strb    w10, [x9, #7]
2:  add     w23, w23, #1
    b       1b
3:  LA      x9, ft_res
    str     w21, [x9, #4]
    str     w22, [x9, #8]
    add     w0, w20, #3                 // trigo selvagem do lado
    bl      ft_free
    cbz     w0, 4f
    add     w24, w20, #3
    and     w9, w24, #511
    lsl     w0, w9, #6
    add     w0, w0, #32
    lsr     w9, w24, #9
    lsl     w1, w9, #6
    add     w1, w1, #32
    mov     w2, #0
    mov     w3, #O_WHEAT
    mov     w4, #1
    bl      add_obj
    ldr     w0, [x28, #G_NOBJ]
    sub     w0, w0, #1
    LA      x9, memtype
    mov     w10, #O_WHEAT
    strb    w10, [x9, w0, uxtw]
    // personagem do lado do bloco, para a foto mostrar a plantacao
4:  mov     w22, #0
41: cmp     w22, #4
    b.ge    44f
    LA      x9, ft_side
    add     x9, x9, x22, lsl #1
    ldrsb   w10, [x9]
    ldrsb   w11, [x9, #1]
    and     w12, w20, #511
    add     w23, w12, w10               // u
    lsr     w13, w20, #9
    add     w24, w13, w11               // v
    add     w0, w23, w24, lsl #9
    bl      ft_free
    cbz     w0, 43f
    scvtf   s0, w23
    fmov    s1, #0.5
    fadd    s0, s0, s1
    str     s0, [x28, #G_PU]
    scvtf   s0, w24
    fadd    s0, s0, s1
    str     s0, [x28, #G_PV]
    b       44f
43: add     w22, w22, #1
    b       41b
44: bl      surv_update
    str     wzr, [x28, #G_POPT]         // sem textos por cima
    str     wzr, [x28, #G_MSGT]
    b       ft_ret

ft_stage1:
    LA      x9, ft_res
    ldr     w20, [x9]
    tbnz    w20, #31, ft_ret
    and     w9, w20, #511               // de volta para o meio do bloco
    scvtf   s0, w9
    fmov    s1, #1.5
    fadd    s0, s0, s1
    str     s0, [x28, #G_PU]
    lsr     w9, w20, #9
    scvtf   s0, w9
    fmov    s1, #1.0
    fadd    s0, s0, s1
    str     s0, [x28, #G_PV]
    bl      surv_update
    // ---- colhe o maduro (celula 3) com as maos vazias ----
    ldr     w21, [x28, #(G_INV + 4 * IT_WHEAT)]
    ldr     w22, [x28, #(G_INV + 4 * IT_SEED)]
    mov     w0, #3
    bl      ft_cell
    mov     w24, w0
    bl      obj_in_cell
    mov     w23, w0
    tbnz    w23, #31, 3f
    mov     w0, w24
    bl      ft_hov
    mov     w9, #1
    str     w9, [x28, #G_LMB]
    mov     w25, #0
1:  bl      surv_update
    LA      x9, objs
    add     x9, x9, x23, lsl #3
    ldrb    w9, [x9, #6]
    cmp     w9, #O_CROP
    b.ne    2f
    add     w25, w25, #1
    cmp     w25, #300
    b.lt    1b
2:  str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_HOVOK]
3:  ldr     w9, [x28, #(G_INV + 4 * IT_WHEAT)]
    sub     w9, w9, w21
    ldr     w10, [x28, #(G_INV + 4 * IT_SEED)]
    sub     w10, w10, w22
    LA      x11, ft_res
    str     w9, [x11, #12]
    str     w10, [x11, #16]
    // ---- verde (celula 1): segurando o botao nao sai ----
    mov     w0, #1
    bl      ft_cell
    mov     w24, w0
    bl      obj_in_cell
    mov     w23, w0
    tbnz    w23, #31, 39f
    mov     w0, w24
    bl      ft_hov
    mov     w9, #1
    str     w9, [x28, #G_LMB]
    mov     w25, #0
31: bl      surv_update
    add     w25, w25, #1
    cmp     w25, #120
    b.lt    31b
    str     wzr, [x28, #G_LMB]
    LA      x9, objs
    add     x9, x9, x23, lsl #3
    ldrb    w9, [x9, #6]
    cmp     w9, #O_CROP
    cset    w9, eq
    LA      x10, ft_res
    str     w9, [x10, #40]
    // ---- a enxada desfaz a terra e a planta verde (a semente se perde) ----
    ldr     w21, [x28, #(G_INV + 4 * IT_SEED)]
    mov     w0, #IT_HOE
    bl      equip
    mov     w0, w24
    bl      ft_hov
    mov     w9, #1
    str     w9, [x28, #G_LMB]
    bl      surv_update
    str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_FARMLAST]
    str     wzr, [x28, #G_FARMMODE]
    str     wzr, [x28, #G_HAND]
    LA      x9, objs
    add     x9, x9, x23, lsl #3
    ldrb    w9, [x9, #6]
    cmp     w9, #O_GONE
    cset    w10, eq
    LA      x9, overlay
    ldrb    w11, [x9, w24, uxtw]
    cmp     w11, #0
    cset    w11, eq
    and     w10, w10, w11
    ldr     w9, [x28, #(G_INV + 4 * IT_SEED)]
    sub     w9, w9, w21
    LA      x11, ft_res
    str     w10, [x11, #44]
    str     w9, [x11, #48]
39:
    // ---- pao: 3 trigos e uma fogueira do lado ----
    ldr     w9, [x28, #(G_INV + 4 * IT_WHEAT)]
    add     w9, w9, #3
    str     w9, [x28, #(G_INV + 4 * IT_WHEAT)]
    ldr     w9, [x28, #G_NFIRE]
    LA      x10, fires
    add     x10, x10, x9, lsl #4
    ldr     s0, [x28, #G_PU]
    fmov    s1, #1.0
    fadd    s0, s0, s1
    str     s0, [x10]
    ldr     s0, [x28, #G_PV]
    str     s0, [x10, #4]
    ldr     w11, [x28, #G_PE]
    str     w11, [x10, #8]
    MOVI32  w11, FIRETIME
    str     w11, [x10, #12]
    add     w9, w9, #1
    str     w9, [x28, #G_NFIRE]
    bl      surv_update
    ldr     w21, [x28, #(G_INV + 4 * IT_BREAD)]
    mov     w0, #18                     // receita do pao
    bl      craft
    ldr     w9, [x28, #(G_INV + 4 * IT_BREAD)]
    sub     w9, w9, w21
    LA      x11, ft_res
    str     w9, [x11, #20]
    // ---- crescimento: com agua (celula 4) e sem agua (outro lugar) ----
    mov     w0, #4
    bl      ft_cell
    bl      obj_in_cell
    mov     w23, w0                     // com agua
    bl      ft_occ
    mov     w0, #0                      // sem agua, a 10+ celulas
    mov     w1, #10
    bl      ft_find
    mov     w24, w0
    tbnz    w24, #31, 6f
    mov     w0, w24
    bl      farm_wet
    add     w0, w0, #2
    LA      x9, overlay
    strb    w0, [x9, w24, uxtw]
    mov     w0, w24
    bl      plant_at
    mov     w24, w0                     // sem agua
    tbnz    w23, #31, 6f
    LA      x9, objs                    // os dois do zero
    add     x10, x9, x23, lsl #3
    strb    wzr, [x10, #7]
    add     x10, x9, x24, lsl #3
    strb    wzr, [x10, #7]
    mov     w25, #0                     // meio dia de jogo (6 min)
4:  bl      crop_tick
    add     w25, w25, #1
    cmp     w25, #1350
    b.lt    4b
    mov     w0, w23
    bl      ft_pct
    LA      x9, ft_res
    str     w0, [x9, #24]
    mov     w0, w24
    bl      ft_pct
    LA      x9, ft_res
    str     w0, [x9, #28]
    // inverno: nada cresce
    LA      x9, objs
    add     x10, x9, x23, lsl #3
    strb    wzr, [x10, #7]
    ldr     w26, [x28, #G_SEASON]
    mov     w9, #3
    str     w9, [x28, #G_SEASON]
    mov     w25, #0
5:  bl      crop_tick
    add     w25, w25, #1
    cmp     w25, #1350
    b.lt    5b
    str     w26, [x28, #G_SEASON]
    mov     w0, w23
    bl      ft_pct
    LA      x9, ft_res
    str     w0, [x9, #32]
    // ---- um coelho perto do trigo maduro sem cerca ----
    LA      x9, objs
    add     x10, x9, x24, lsl #3
    mov     w11, #CROPRIPE
    strb    w11, [x10, #7]
    bl      animals_reset
    LA      x10, objs
    add     x10, x10, x24, lsl #3
    LA      x9, animals
    ldrh    w10, [x10]                  // 3 celulas a esquerda da planta
    ucvtf   s0, w10
    LA      x11, fpconst
    ldr     s2, [x11, #20]
    fmul    s0, s0, s2
    fmov    s1, #3.0
    fsub    s0, s0, s1
    str     s0, [x9, #AN_U]
    LA      x10, objs
    add     x10, x10, x24, lsl #3
    ldrh    w10, [x10, #2]
    ucvtf   s1, w10
    fmul    s1, s1, s2
    str     s1, [x9, #AN_V]
    str     wzr, [x9, #AN_DU]
    str     wzr, [x9, #AN_DV]
    str     wzr, [x9, #16]
    str     wzr, [x9, #20]
    str     wzr, [x9, #24]
    str     wzr, [x9, #28]
    mov     w10, #A_RABBIT
    strb    w10, [x9, #AN_TYPE]
    mov     w10, #2
    strb    w10, [x9, #AN_HP]
    mov     w25, #0
51: bl      surv_update
    LA      x9, objs
    add     x9, x9, x24, lsl #3
    ldrb    w9, [x9, #6]
    cmp     w9, #O_CROP
    b.ne    52f
    add     w25, w25, #1
    cmp     w25, #900
    b.lt    51b
52: LA      x9, objs
    add     x9, x9, x24, lsl #3
    ldrb    w9, [x9, #6]
    cmp     w9, #O_GONE
    cset    w9, eq
    LA      x10, ft_res
    str     w9, [x10, #36]
    bl      animals_reset
6:  // ---- imprime ----
    LA      x19, ft_res
    LA      x0, txt
    LA      x1, t_f1
    ldr     w2, [x19, #4]
    bl      ft_num
    LA      x1, t_f2
    ldr     w2, [x19, #8]
    bl      ft_num
    LA      x1, t_f3
    ldr     w2, [x19, #12]
    bl      ft_num
    LA      x1, t_f4
    ldr     w2, [x19, #16]
    bl      ft_num
    LA      x1, t_f5
    ldr     w2, [x19, #20]
    bl      ft_num
    LA      x1, t_f6
    ldr     w2, [x19, #24]
    bl      ft_num
    LA      x1, t_f7
    ldr     w2, [x19, #28]
    bl      ft_num
    LA      x1, t_f8
    ldr     w2, [x19, #32]
    bl      ft_num
    LA      x1, t_f9
    ldr     w2, [x19, #36]
    bl      ft_num
    LA      x1, t_f10
    ldr     w2, [x19, #40]
    bl      ft_num
    LA      x1, t_f11
    ldr     w2, [x19, #44]
    bl      ft_num
    LA      x1, t_f12
    ldr     w2, [x19, #48]
    bl      ft_num
    LA      x1, t_fnl
    bl      strcat_cur
    bl      sk_write
ft_ret:
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ---------------------------------------------------------------------
    .data
    .p2align 2
fpconst:
    .float 64.0                         // 0: 8 celulas^2 (bicho ve o trigo)
    .float 0.36                         // 4: 0,6 celula^2 (chegou: come)
    .float 0.15                         // 8: treino por celula arada
    .float 0.6                          // 12: treino por trigo selvagem
    .float 1.2                          // 16: treino por trigo maduro colhido
    .float 0.015625                     // 20: 1/64
ft_res:     .word -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
ft_side:    .byte -2, 1,  4, 1,  1, -2,  1, 3   // onde ficar para a foto

p_till:     .asciz "Arou"
p_untill:   .asciz "Desfez a terra"
p_uproot:   .asciz "Arrancou (perdeu a semente)"
p_plant:    .asciz "Plantou"
m_tilled:   .asciz "Ja esta arada"
m_notill:   .asciz "A enxada nao ara aqui (agua, areia ou rocha)"
m_blocked:  .asciz "Tem algo em cima"
m_needtill: .asciz "Plante na terra arada (use a enxada: tecla 6)"
m_noseeds:  .asciz "Acabaram as sementes"
m_eaten:    .asciz "Um bicho comeu o trigo maduro! Uma cerca protege"
s_plus:     .asciz "+"
s_trigo:    .asciz " trigo  "
s_sem:      .asciz " sementes"
s_sem1:     .asciz " semente"
s_ripe:     .asciz " - maduro! (segure: colher)"
s_grow:     .asciz " (verde, "
s_pct:      .asciz "%: espere)"
t_f1:       .asciz "plantacao: arou="
t_f2:       .asciz " plantou="
t_f3:       .asciz " | colheu maduro: trigo="
t_f4:       .asciz " sementes="
t_f5:       .asciz " | pao="
t_f6:       .asciz " | em 6 min: com agua="
t_f7:       .asciz "% sem agua="
t_f8:       .asciz "% inverno="
t_f9:       .asciz "% | coelho comeu o trigo sem cerca="
t_f10:      .asciz " | verde segurando o botao: ficou="
t_f11:      .asciz " | enxada desfez terra e planta="
t_f12:      .asciz " sementes de volta="
t_fnl:      .asciz "\n"
farmpop:    .space 40

GBSS croplist, (MAXCROP * 4)            // objetos de trigo plantado
GBSS focc, 262144                       // teste: celulas com objeto
