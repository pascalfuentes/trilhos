// =====================================================================
//  estradas.S - estradas de pedra
//
//  - A estrada e um piso (overlay = 4): o chao desenha o azulejo certo
//    pelos 4 vizinhos (ermo.S, terrain_color; azulejos em estruturas.S).
//    Anda-se 50% mais rapido nela (a terra batida da 25-30%).
//  - Voce: item Estrada (1 pedra no Fabricar), arrastado como a cerca.
//    A enxada desfaz a estrada e devolve a pedra.
//  - A vila: quem tem a tarefa Obras, sem casa nem cerca para fazer,
//    pavimenta os caminhos de terra batida mais usados (de preferencia
//    emendando nas estradas que ja existem). Cada quadrado gasta 1 pedra
//    do deposito: o construtor busca ate 4 de uma vez, e so o que passa
//    de 12 (essas ficam para as casas).
// =====================================================================

#include "comum.h"
#include "pessoas.h"

.equ OV_ROAD,    4
.equ ROADR,      30                     // raio da procura (celulas)
.equ ROADMIN,    6                      // passadas minimas para pavimentar
.equ ROADTAKE,   4                      // pedras por viagem
.equ ROADKEEP,   12                     // pedras que ficam no deposito (casas)

    .text
    .p2align 2

// road_at(w0 = celula) -> w0 = 1 se tem estrada   folha
    .globl road_at
road_at:
    LA      x9, overlay
    ldrb    w9, [x9, w0, uxtw]
    cmp     w9, #OV_ROAD
    cset    w0, eq
    ret

// road_put(w0 = u, w1 = v) -> w0 = 1 se pavimentou (gasta 1 Estrada)
    .globl road_put
road_put:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, w0
    mov     w20, w1
    mov     w0, #0
    ldr     w9, [x28, #(G_INV + 4 * IT_ROAD)]
    cbz     w9, 9f
    scvtf   s0, w19
    scvtf   s1, w20
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      build_check
    mov     x9, x0
    mov     w0, #0
    cbnz    x9, 9f
    add     w9, w19, w20, lsl #9
    LA      x10, overlay
    mov     w11, #OV_ROAD
    strb    w11, [x10, w9, uxtw]
    ldr     w9, [x28, #(G_INV + 4 * IT_ROAD)]
    sub     w9, w9, #1
    str     w9, [x28, #(G_INV + 4 * IT_ROAD)]
    bl      calc_stats
    mov     w0, #1
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// road_dig(w0 = celula): a enxada desfaz a estrada; a pedra volta
    .globl road_dig
road_dig:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x9, overlay
    strb    wzr, [x9, w0, uxtw]
    mov     w0, #IT_STONE
    mov     w1, #1
    bl      inv_add
    LA      x0, p_roadup
    bl      popup
    ldp     x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
//  A vila: Obras pavimenta os caminhos mais usados
// ---------------------------------------------------------------------

// road_pick -> w0 = a celula de caminho que mais vale pavimentar perto
// do construtor x19 (-1): passadas + bonus por emendar numa estrada
road_pick:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     s0, [x19, #P_U]
    fcvtzs  w12, s0
    ldr     s0, [x19, #P_V]
    fcvtzs  w13, s0
    LA      x14, overlay
    LA      x15, walkgrid
    LA      x16, fencegrid
    ldr     w17, [x19, #P_SKIP]
    mov     w0, #-1
    mov     w8, #0                      // melhor nota
    mov     w2, #-ROADR                 // dv
1:  mov     w3, #-ROADR                 // du
2:  add     w4, w12, w3
    add     w5, w13, w2
    cmp     w4, #3
    b.lt    7f
    cmp     w5, #3
    b.lt    7f
    cmp     w4, #508
    b.gt    7f
    cmp     w5, #508
    b.gt    7f
    add     w6, w4, w5, lsl #9
    ldrb    w7, [x14, w6, uxtw]
    cmp     w7, #1                      // terra batida
    b.ne    7f
    ldrb    w7, [x16, w6, uxtw]         // sem cerca
    cbnz    w7, 7f
    cmp     w6, w17                     // nao alcancou da outra vez
    b.eq    7f
    ldrb    w9, [x15, w6, uxtw]         // passadas
    cmp     w9, #ROADMIN
    b.lo    7f
    add     x10, x14, w6, uxtw          // emenda numa estrada: vale mais
    ldrb    w11, [x10, #1]
    cmp     w11, #OV_ROAD
    b.ne    3f
    add     w9, w9, #64
3:  ldurb   w11, [x10, #-1]
    cmp     w11, #OV_ROAD
    b.ne    4f
    add     w9, w9, #64
4:  ldrb    w11, [x10, #512]
    cmp     w11, #OV_ROAD
    b.ne    5f
    add     w9, w9, #64
5:  sub     x10, x10, #512
    ldrb    w11, [x10]
    cmp     w11, #OV_ROAD
    b.ne    6f
    add     w9, w9, #64
6:  mul     w10, w3, w3                 // perto vale um pouco mais
    madd    w10, w2, w2, w10
    lsr     w10, w10, #5
    subs    w9, w9, w10
    b.le    7f
    cmp     w9, w8
    b.le    7f
    mov     w8, w9
    mov     w0, w6
7:  add     w3, w3, #1
    cmp     w3, #ROADR
    b.le    2b
    add     w2, w2, #1
    cmp     w2, #ROADR
    b.le    1b
    tbnz    w0, #31, 9f
    str     w0, [sp, #-16]!             // em cima tem alguma coisa? fica
    bl      obj_in_cell                 // de fora daqui para a frente
    mov     w9, w0
    ldr     w0, [sp], #16
    tbnz    w9, #31, 9f
    LA      x9, walkgrid
    strb    wzr, [x9, w0, uxtw]
    mov     w0, #-1
9:  ldp     x29, x30, [sp], #16
    ret

// road_work -> w0 = 1 se o construtor x19 (indice w20) ja vai pavimentar
// (ou buscar pedra); 0 se nao tem estrada para fazer
    .globl road_work
road_work:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x21, [sp, #16]
    bl      road_pick
    tbnz    w0, #31, 8f
    mov     w21, w0
    mov     w0, #IT_STONE
    bl      pinv_get
    cbz     w0, 1f
    mov     w0, w21                     // tem pedra: vai pavimentar
    mov     w1, #WK_ROAD
    bl      ppl_gowork_cell
    mov     w0, #1
    b       9f
1:  mov     w0, #IT_STONE               // busca pedra no deposito (as 12
    mov     w1, #(ROADKEEP + 1)         // primeiras ficam para as casas)
    mov     w2, #IT_STONE
    mov     w3, #(ROADKEEP + 1)
    bl      dep_take_find
    tbnz    w0, #31, 8f
    mov     w1, #NX_ROADST
    bl      ppl_gochest
    mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldr     x21, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// road_takestone: chegou ao deposito: leva ate 4 pedras
    .globl road_takestone
road_takestone:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w0, [x19, #P_TARGET]
    bl      ppl_chestptr
    cbz     x0, 9f
    ldr     w9, [x0, #(4 * IT_STONE)]
    subs    w1, w9, #ROADKEEP           // so o que sobra das casas
    b.le    9f
    mov     w10, #ROADTAKE
    cmp     w1, w10
    csel    w1, w1, w10, lo
    sub     w9, w9, w1
    str     w9, [x0, #(4 * IT_STONE)]
    mov     w0, #IT_STONE
    bl      pinv_add
    bl      store_close
9:  ldp     x29, x30, [sp], #16
    ret

// road_valid(w0 = celula) -> w0 = 1 se ainda da para pavimentar ali
// (terra, sem estrada, e o construtor tem pedra)
    .globl road_valid
road_valid:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x9, overlay
    ldrb    w9, [x9, w0, uxtw]
    cmp     w9, #1
    b.hi    8f
    mov     w0, #IT_STONE
    bl      pinv_get
    cmp     w0, #0
    cset    w0, ne
    b       9f
8:  mov     w0, #0
9:  ldp     x29, x30, [sp], #16
    ret

// road_done(w0 = celula): pavimentou (gasta 1 pedra da mochila)
    .globl road_done
road_done:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x21, [sp, #16]
    mov     w21, w0
    LA      x9, overlay
    mov     w10, #OV_ROAD
    strb    w10, [x9, w21, uxtw]
    mov     w0, #IT_STONE
    mov     w1, #-1
    bl      pinv_add
    ldr     x21, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// road_count -> w0 = quadrados de estrada no mapa (teste)   folha
    .globl road_count
road_count:
    LA      x9, overlay
    mov     w10, #(MAPN * MAPN / 4096)
    lsl     w10, w10, #12
    mov     w0, #0
1:  ldrb    w11, [x9], #1
    cmp     w11, #OV_ROAD
    cinc    w0, w0, eq
    subs    w10, w10, #1
    b.ne    1b
    ret

// =====================================================================
//  Teste automatico (--shot)
//   voce arrasta 6 estradas e desfaz uma com a enxada; um construtor
//   sem obras pavimenta um caminho de terra batida de 12 celulas
// =====================================================================

// rt_clear(w0 = u, w1 = v) -> w0 = 1 se e terra: limpa (objetos, cerca,
// terra arada) para o teste
rt_clear:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    add     w19, w0, w1, lsl #9
    LA      x9, elev
    ldrsh   w9, [x9, w19, uxtw #1]
    ldr     w10, [x28, #G_FLOOD]
    add     w10, w10, #8
    mov     w0, #0
    cmp     w9, w10
    b.lt    9f
    LA      x9, overlay
    strb    wzr, [x9, w19, uxtw]
    LA      x9, fencegrid
    strb    wzr, [x9, w19, uxtw]
    LA      x9, pitgrid
    strb    wzr, [x9, w19, uxtw]
1:  mov     w0, w19
    bl      obj_in_cell
    tbnz    w0, #31, 2f
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    mov     w10, #O_GONE
    strb    w10, [x9, #6]
    b       1b
2:  mov     w0, #1
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

    .globl road_selftest
road_selftest:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    LA      x24, rtres
    ldr     w9, [x28, #G_PU]            // guarda onde voce estava
    str     w9, [x24, #48]
    ldr     w9, [x28, #G_PV]
    str     w9, [x24, #52]
    bl      vt_spot                     // um lugar plano de terra
    tbnz    w0, #31, 90f
    stp     w0, w1, [x24, #56]
    scvtf   s0, w0                      // voce no meio
    fmov    s2, #0.5
    fadd    s0, s0, s2
    scvtf   s1, w1
    fadd    s1, s1, s2
    str     s0, [x28, #G_PU]
    str     s1, [x28, #G_PV]
    // ---- voce: 6 estradas numa fileira em v ----
    add     w21, w0, #3
    sub     w22, w1, #6
    mov     w23, #0
1:  mov     w0, w21
    add     w1, w22, w23
    bl      rt_clear
    add     w23, w23, #1
    cmp     w23, #6
    b.lt    1b
    mov     w9, #6
    str     w9, [x28, #(G_INV + 4 * IT_ROAD)]
    mov     w9, #(IT_ROAD + 1)
    str     w9, [x28, #G_PLACE]
    str     w21, [x28, #G_FLASTU]
    str     w22, [x28, #G_FLASTV]
    str     w21, [x28, #G_FTGU]
    add     w9, w22, #5
    str     w9, [x28, #G_FTGV]
    mov     w9, #1
    str     w9, [x28, #G_FDRAG]
    str     wzr, [x28, #G_HOVOK]
    bl      occ_build
    bl      fence_commit
    mov     w23, #0
    mov     w25, #0
2:  add     w0, w22, w23
    add     w0, w21, w0, lsl #9
    bl      road_at
    add     w25, w25, w0
    add     w23, w23, #1
    cmp     w23, #6
    b.lt    2b
    str     w25, [x24]                  // colocadas
    ldr     w9, [x28, #(G_INV + 4 * IT_ROAD)]
    str     w9, [x24, #4]               // sobrou
    str     wzr, [x28, #G_PLACE]
    ldr     w25, [x28, #(G_INV + 4 * IT_STONE)]
    add     w0, w21, w22, lsl #9        // a enxada desfaz a primeira
    bl      road_dig
    ldr     w9, [x28, #(G_INV + 4 * IT_STONE)]
    sub     w9, w9, w25
    str     w9, [x24, #8]
    add     w0, w21, w22, lsl #9
    bl      road_at
    str     w0, [x24, #12]              // ainda tem estrada? (0)
    str     wzr, [x28, #G_MSGT]
    str     wzr, [x28, #G_POPT]
    // ---- a vila: o construtor sem obras pavimenta o caminho ----
    LA      x19, people                 // o primeiro adulto vivo
    mov     w20, #0
3:  ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 31f
    ldrh    w9, [x19, #P_AGE]
    cmp     w9, #ADULTDAYS
    b.hs    32f
31: add     x19, x19, #PSIZE
    add     w20, w20, #1
    cmp     w20, #MAXPEOPLE
    b.lt    3b
    b       80f
32: ldrb    w9, [x19, #P_JOB]
    strb    w9, [x24, #40]
    mov     w9, #J_BUILD
    strb    w9, [x19, #P_JOB]
    LA      x9, fams                    // obras ja feitas (guarda como estava)
    add     x10, x24, #64
    mov     w11, #0
4:  ldrb    w12, [x9, #F_LEVEL]
    strb    w12, [x10]
    ldrb    w12, [x9, #F_FENCE]
    strb    w12, [x10, #1]
    ldrb    w12, [x9, #F_PAID]
    strb    w12, [x10, #2]
    mov     w12, #2
    strb    w12, [x9, #F_LEVEL]
    mov     w12, #1
    strb    w12, [x9, #F_FENCE]
    strb    wzr, [x9, #F_PAID]
    add     x9, x9, #32
    add     x10, x10, #4
    add     w11, w11, #1
    cmp     w11, #MAXFAM
    b.lt    4b
    ldp     w21, w22, [x24, #56]        // o caminho: 12 celulas em u, ao lado
    sub     w21, w21, #6
    add     w22, w22, #4
    sub     w9, w21, #2                 // o construtor no comeco dele
    scvtf   s0, w9
    fmov    s2, #0.5
    fadd    s0, s0, s2
    add     w9, w22, #1
    scvtf   s1, w9
    fadd    s1, s1, s2
    str     s0, [x19, #P_U]
    str     s1, [x19, #P_V]
    ldrb    w9, [x19, #P_FLAGS]
    bic     w9, w9, #1
    strb    w9, [x19, #P_FLAGS]
    mov     w23, #0
    mov     w25, #0
5:  add     w0, w21, w23
    mov     w1, w22
    bl      rt_clear
    cbz     w0, 51f
    add     w9, w21, w23
    add     w9, w9, w22, lsl #9
    LA      x10, overlay
    mov     w11, #1
    strb    w11, [x10, w9, uxtw]
    LA      x10, walkgrid                // o caminho mais usado da regiao
    mov     w11, #250
    strb    w11, [x10, w9, uxtw]
    add     w25, w25, #1
51: add     w23, w23, #1
    cmp     w23, #12
    b.lt    5b
    str     w25, [x24, #16]             // celulas de caminho
    bl      dep_dirty
    sub     w0, w21, #4                 // um deposito geral 3 x 3 do lado,
    sub     w1, w22, #2                 // com 30 pedras
    mov     w2, #Z_DEPG
    bl      dep_test_paint
    sub     w0, w21, #4
    sub     w1, w22, #2
    add     w0, w0, w1, lsl #9
    bl      store_cell
    ldr     w9, [x0, #(4 * IT_STONE)]
    add     w9, w9, #30
    str     w9, [x0, #(4 * IT_STONE)]
    bl      store_close
6:  mov     w0, #IT_STONE               // sem pedra na mochila
    mov     w1, #-100
    bl      pinv_add
    mov     w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    strh    wzr, [x19, #P_THINK]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
    str     w9, [x19, #P_SKIP]
    ldr     w9, [x28, #G_TIME]
    str     w9, [x24, #44]
    MOVI32  w9, (DAYLEN / 4)            // de dia
    str     w9, [x28, #G_TIME]
    bl      road_count
    str     w0, [x24, #24]
    mov     w0, #7200                   // 2 horas de jogo
    bl      mt_frames
    bl      road_count
    ldr     w9, [x24, #24]
    sub     w0, w0, w9
    str     w0, [x24, #28]              // quadrados feitos (em qualquer lugar)
    mov     w23, #0
    mov     w25, #0
7:  add     w0, w21, w23
    add     w0, w0, w22, lsl #9
    bl      road_at
    add     w25, w25, w0
    add     w23, w23, #1
    cmp     w23, #12
    b.lt    7b
    str     w25, [x24, #20]             // pavimentou
    ldr     w9, [x24, #44]
    str     w9, [x28, #G_TIME]
    ldrb    w9, [x24, #40]              // volta tudo como estava
    strb    w9, [x19, #P_JOB]
    LA      x9, fams
    add     x10, x24, #64
    mov     w11, #0
8:  ldrb    w12, [x10]
    strb    w12, [x9, #F_LEVEL]
    ldrb    w12, [x10, #1]
    strb    w12, [x9, #F_FENCE]
    ldrb    w12, [x10, #2]
    strb    w12, [x9, #F_PAID]
    add     x9, x9, #32
    add     x10, x10, #4
    add     w11, w11, #1
    cmp     w11, #MAXFAM
    b.lt    8b
80: ldr     w9, [x24, #48]              // voce volta para onde estava
    str     w9, [x28, #G_PU]
    ldr     w9, [x24, #52]
    str     w9, [x28, #G_PV]
    bl      follow_camera
90: LA      x0, txt
    LA      x1, rt_t1
    ldr     w2, [x24]
    bl      rt_num
    LA      x1, rt_t2
    ldr     w2, [x24, #4]
    bl      rt_num
    LA      x1, rt_t3
    ldr     w2, [x24, #8]
    bl      rt_num
    LA      x1, rt_t4
    ldr     w2, [x24, #12]
    bl      rt_num
    LA      x1, rt_t5
    ldr     w2, [x24, #16]
    bl      rt_num
    LA      x1, rt_t6
    ldr     w2, [x24, #20]
    bl      rt_num
    LA      x1, rt_t7
    ldr     w2, [x24, #28]
    bl      rt_num
    LA      x1, rt_t8
    bl      strcat_cur
    LA      x1, rt_nl
    bl      strcat_cur
    bl      sk_write
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// rt_num(x0 cursor, x1 rotulo, w2 numero) -> x0
rt_num:
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

    .data
p_roadup:   .asciz "+1 pedra (desfez a estrada)"
rt_t1:      .asciz "estradas: voce arrastou 6: colocadas="
rt_t2:      .asciz " sobrou="
rt_t3:      .asciz " | enxada: pedra de volta="
rt_t4:      .asciz " estrada ficou="
rt_t5:      .asciz " | obras sem casa para fazer: caminho (celulas)="
rt_t6:      .asciz " pavimentou em 2 h="
rt_t7:      .asciz " (estradas novas no mapa="
rt_t8:      .asciz ")"
rt_nl:      .asciz "\n"
    .p2align 2
rtres:      .space 128
