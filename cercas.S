// =====================================================================
//  cercas.S - cercas e portoes
//
//  - Cada celula do mapa pode ter uma cerca (1) ou um portao (2), na
//    grade fencegrid. Cerca: ninguem passa. Portao: voce passa, os
//    animais nao.
//  - Colocar: com cercas na mao, segure o clique e arraste; a fileira
//    vai seguindo o mouse, celula por celula (sem buracos na diagonal).
//  - O portao pode ser colocado em cima de uma cerca (troca por ela).
//  - Toda construcao fica presa na grade (um quadrado = uma celula; o
//    abrigo ocupa 2 x 2) e so vai em quadrado livre: nada em cima
//    (arvore, pedra, arbusto, trigo, pilha, bau, fogueira), sem cerca,
//    sem terra arada e fora da agua.
//  - Cada cerca tambem e um objeto do mapa (para desenhar, lembrar na
//    neblina e desmontar segurando o botao esquerdo).
// =====================================================================

#include "comum.h"

    .text
    .p2align 2

// fences_reset: mundo sem cercas
    .globl fences_reset
fences_reset:
    LA      x9, fencegrid
    mov     w10, #(MAPN * MAPN / 16)
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    str     wzr, [x28, #G_FDRAG]
    ret

// fence_at(s4 = u, s5 = v) -> w0 = 0 livre, 1 cerca, 2 portao   folha
// (so mexe em x0, x9, x10)
    .globl fence_at
fence_at:
    fcvtzs  w9, s4
    fcvtzs  w10, s5
    mov     w0, #0
    cmp     w9, #MAPN
    b.hs    9f
    cmp     w10, #MAPN
    b.hs    9f
    add     w9, w9, w10, lsl #9
    LA      x10, fencegrid
    ldrb    w0, [x10, w9, uxtw]
9:  ret

// occ_build: marca as celulas com alguma coisa em cima (arvore, pedra,
// arbusto, trigo, pilha, bau, abrigo 2 x 2, fogueira). Cerca e portao
// ficam na fencegrid, a terra arada no overlay. Chamada ao comecar a
// colocar, a cada quadro colocando e depois de colocar.
    .globl occ_build
occ_build:
    LA      x9, occgrid
    mov     w10, #(MAPN * MAPN / 16)
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    LA      x9, occgrid
    LA      x10, objs
    ldr     w11, [x28, #G_NOBJ]
    mov     w15, #1
2:  cbz     w11, 5f
    ldrb    w12, [x10, #6]
    cmp     w12, #O_LAST                // removido
    b.hi    4f
    cmp     w12, #O_FENCE               // cerca e portao: fencegrid
    b.eq    4f
    cmp     w12, #O_GATE
    b.eq    4f
    ldrh    w13, [x10]
    lsr     w13, w13, #6
    ldrh    w14, [x10, #2]
    lsr     w14, w14, #6
    add     w13, w13, w14, lsl #9
    strb    w15, [x9, w13, uxtw]
    cmp     w12, #O_SHELTER             // abrigo, barraco e casa: posicao no
    b.eq    31f                         // canto do meio do bloco 2 x 2
    cmp     w12, #O_HUT
    b.lo    4f
    cmp     w12, #O_HOUSE
    b.hi    4f
31: sub     w13, w13, #1
    strb    w15, [x9, w13, uxtw]
    sub     w13, w13, #512
    strb    w15, [x9, w13, uxtw]
    add     w13, w13, #1
    strb    w15, [x9, w13, uxtw]
4:  add     x10, x10, #8
    sub     w11, w11, #1
    b       2b
5:  LA      x10, fires
    ldr     w11, [x28, #G_NFIRE]
6:  cbz     w11, 9f
    ldr     s0, [x10]
    fcvtzs  w13, s0
    ldr     s0, [x10, #4]
    fcvtzs  w14, s0
    add     w13, w13, w14, lsl #9
    strb    w15, [x9, w13, uxtw]
    add     x10, x10, #16
    sub     w11, w11, #1
    b       6b
9:  ret

// build_check(s0 = u, s1 = v): da para colocar a construcao da mao
// (G_PLACE) no quadrado sob esse ponto?  -> x0 = 0 sim (senao o motivo),
// s0/s1 = onde vai (meio do quadrado; abrigo: canto do meio do bloco
// 2 x 2, com o quadrado do mouse em cima a esquerda), w1 = elevacao
    .globl build_check
    .globl fence_check
build_check:
fence_check:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     d8, d9, [sp, #80]
    fcvtzs  w19, s0                     // quadrado
    fcvtzs  w20, s1
    ldr     w21, [x28, #G_PLACE]
    sub     w21, w21, #1                // item
    mov     w22, #1                     // tamanho
    cmp     w21, #IT_SHELTER
    cinc    w22, w22, eq
    scvtf   s8, w19
    scvtf   s9, w20
    fmov    s2, #0.5
    cmp     w22, #2
    b.ne    1f
    fmov    s2, #1.0
1:  fadd    s8, s8, s2                  // ponto
    fadd    s9, s9, s2
    mov     w24, #0                     // elevacao
    LA      x0, m_far
    cmp     w19, #2                     // dentro do mapa
    b.lt    8f
    cmp     w20, #2
    b.lt    8f
    mov     w9, #508
    cmp     w19, w9
    b.gt    8f
    cmp     w20, w9
    b.gt    8f
    ldr     s2, [x28, #G_PU]            // alcance: cerca 8 celulas, o resto 5
    ldr     s3, [x28, #G_PV]
    fsub    s2, s8, s2
    fsub    s3, s9, s3
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    mov     w9, #25
    cmp     w21, #IT_FENCE
    b.eq    11f
    cmp     w21, #IT_ROAD
    b.eq    111f
    cmp     w21, #IT_GATE
    b.eq    11f
    b       12f
111: mov    w9, #FENCEREACH             // estrada: ate 8, pode ser debaixo de voce
    b       12f
11: mov     w9, #FENCEREACH
    LA      x0, m_onplayer              // cerca/portao: nao em cima de voce
    ldr     s3, [x28, #G_PU]
    fcvtzs  w10, s3
    ldr     s3, [x28, #G_PV]
    fcvtzs  w11, s3
    cmp     w10, w19
    b.ne    12f
    cmp     w11, w20
    b.eq    8f
12: scvtf   s3, w9
    LA      x0, m_far
    fcmp    s2, s3
    b.gt    8f
    cmp     w21, #IT_FIRE               // fogueiras demais?
    b.ne    13f
    ldr     w9, [x28, #G_NFIRE]
    LA      x0, m_toomanyfires
    cmp     w9, #MAXFIRE
    b.hs    8f
    // cada quadrado do bloco
13: mov     w23, #0                     // (dy << 1) | dx
2:  and     w9, w23, #1
    add     w25, w19, w9                // u
    lsr     w10, w23, #1
    add     w26, w20, w10               // v
    scvtf   s0, w25                     // agua? (no meio do quadrado)
    scvtf   s1, w26
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      elev_at
    cbnz    w23, 21f
    mov     w24, w0
21: ldr     w9, [x28, #G_FLOOD]
    LA      x1, m_water
    cmp     w0, w9
    mov     x0, x1
    b.lt    8f
    add     w9, w25, w26, lsl #9        // celula
    LA      x10, overlay                // terra arada (2, 3); estrada (4)
    ldrb    w11, [x10, w9, uxtw]
    LA      x0, m_hasroad
    cmp     w11, #4
    b.ne    22f
    cmp     w21, #IT_ROAD
    b.eq    8f
    b       23f
22: LA      x0, m_farmland
    cmp     w11, #2
    b.hs    8f
23:
    LA      x10, occgrid                // arvore, pedra, bau...
    ldrb    w11, [x10, w9, uxtw]
    LA      x0, m_occupied
    cbnz    w11, 8f
    LA      x10, fencegrid              // cerca (o portao pode trocar)
    ldrb    w11, [x10, w9, uxtw]
    cbz     w11, 3f
    LA      x0, m_hasfence
    cmp     w11, #1
    b.ne    8f
    cmp     w21, #IT_GATE
    b.ne    8f
3:  add     w23, w23, #1
    mul     w9, w22, w22                // 1 x 1 ou 2 x 2
    cmp     w23, w9
    b.lt    2b
    mov     x0, #0
8:  fmov    s0, s8
    fmov    s1, s9
    mov     w1, w24
    ldp     d8, d9, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// fence_put(w0 = celula u, w1 = celula v, w2 = 1 cerca / 2 portao)
// -> w0 = 1 se colocou (gasta o item da mochila)
    .globl fence_put
fence_put:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     x23, [sp, #48]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    mov     w0, #0
    cmp     w19, #2                     // dentro do mapa
    b.lt    9f
    cmp     w20, #2
    b.lt    9f
    cmp     w19, #509
    b.gt    9f
    cmp     w20, #509
    b.gt    9f
    mov     w9, #IT_FENCE               // tem o item?
    cmp     w21, #2
    b.ne    1f
    mov     w9, #IT_GATE
1:  add     x10, x28, #G_INV
    ldr     w11, [x10, x9, lsl #2]
    cbz     w11, 9f
    scvtf   s0, w19                     // checa o lugar
    scvtf   s1, w20
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      fence_check
    mov     w22, w1                     // elevacao
    mov     x9, x0
    mov     w0, #0
    cbnz    x9, 9f
    add     w23, w19, w20, lsl #9
    LA      x10, fencegrid
    ldrb    w9, [x10, w23, uxtw]
    cbz     w9, 3f
    // portao em cima de uma cerca: o objeto da cerca vira portao
    ldr     w9, [x28, #G_NOBJ]
    LA      x10, objs
    mov     w11, #0
2:  cmp     w11, w9
    b.ge    4f
    ldrb    w12, [x10, #6]
    cmp     w12, #O_FENCE
    b.ne    21f
    ldrh    w12, [x10]
    lsr     w12, w12, #6
    cmp     w12, w19
    b.ne    21f
    ldrh    w12, [x10, #2]
    lsr     w12, w12, #6
    cmp     w12, w20
    b.ne    21f
    mov     w12, #O_GATE
    strb    w12, [x10, #6]
    LA      x13, memtype
    strb    w12, [x13, x11]
    ldr     w12, [x28, #(G_INV + 4 * IT_FENCE)] // a cerca volta para a mochila
    add     w12, w12, #1
    str     w12, [x28, #(G_INV + 4 * IT_FENCE)]
    b       4f
21: add     x10, x10, #8
    add     w11, w11, #1
    b       2b
3:  lsl     w0, w19, #6                 // objeto novo no meio da celula
    add     w0, w0, #32
    lsl     w1, w20, #6
    add     w1, w1, #32
    ldr     w9, [x28, #G_FLOOD]
    cmp     w22, w9
    csel    w2, w9, w22, lt
    mov     w3, #O_FENCE
    cmp     w21, #2
    b.ne    31f
    mov     w3, #O_GATE
31: mov     w4, #0
    bl      add_obj
    ldr     w9, [x28, #G_NOBJ]
    sub     w9, w9, #1
    LA      x10, objs
    add     x10, x10, x9, lsl #3
    ldrb    w11, [x10, #6]
    LA      x10, memtype
    strb    w11, [x10, x9]
4:  LA      x10, fencegrid              // marca a grade e gasta o item
    strb    w21, [x10, w23, uxtw]
    mov     w9, #IT_FENCE
    cmp     w21, #2
    b.ne    5f
    mov     w9, #IT_GATE
5:  add     x10, x28, #G_INV
    ldr     w11, [x10, x9, lsl #2]
    sub     w11, w11, #1
    str     w11, [x10, x9, lsl #2]
    bl      calc_stats
    mov     w0, #1
9:  ldr     x23, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// fence_unset(w0 = objeto): desmontou uma cerca/portao: limpa a grade
    .globl fence_unset
fence_unset:
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrh    w10, [x9]
    lsr     w10, w10, #6
    ldrh    w11, [x9, #2]
    lsr     w11, w11, #6
    add     w10, w10, w11, lsl #9
    LA      x11, fencegrid
    strb    wzr, [x11, w10, uxtw]
    ret

// fence_drag (todo quadro): guarda a celula sob o mouse enquanto coloca
// qualquer construcao; arrastando cercas, mostra quantas a fileira gasta
    .globl fence_drag
fence_drag:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    ldr     w9, [x28, #G_PLACE]
    cbnz    w9, 1f
    str     wzr, [x28, #G_FDRAG]
    str     wzr, [x28, #G_FTGOK]
    b       9f
1:  cmp     w9, #(IT_FENCE + 1)         // so a cerca e a estrada arrastam
    b.eq    11f
    cmp     w9, #(IT_ROAD + 1)
    b.eq    11f
    str     wzr, [x28, #G_FDRAG]
11: bl      occ_build                   // o que ocupa cada quadrado
    ldr     w10, [x28, #G_HOVOK]
    str     w10, [x28, #G_FTGOK]
    cbz     w10, 2f
    ldr     w10, [x28, #G_HOVU]
    lsr     w10, w10, #6
    str     w10, [x28, #G_FTGU]
    ldr     w10, [x28, #G_HOVV]
    lsr     w10, w10, #6
    str     w10, [x28, #G_FTGV]
2:  ldr     w9, [x28, #G_FDRAG]
    cbz     w9, 9f
    bl      fence_plan                  // "Fileira: 9 cercas (voce tem 17)"
    bl      plan_new
    mov     w19, w0
    LA      x0, fmsgbuf
    LA      x1, m_row1
    bl      strcat_cur
    mov     w1, w19
    bl      numcat
    LA      x1, m_row2
    ldr     w9, [x28, #G_PLACE]
    cmp     w9, #(IT_ROAD + 1)
    b.ne    3f
    LA      x1, m_rrow2
3:  bl      strcat_cur
    bl      drag_item
    add     x9, x28, #G_INV
    ldr     w1, [x9, x1, lsl #2]
    bl      numcat
    LA      x1, m_row3
    bl      strcat_cur
    LA      x0, fmsgbuf
    bl      set_msg
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// plan_new -> w0 = quantas celulas da fileira ainda nao tem cerca
plan_new:
    ldr     w9, [x28, #G_FPLANN]
    LA      x10, fplan
    LA      x11, fencegrid
    mov     w14, #0                     // cerca: celula vazia = 0
    ldr     w15, [x28, #G_PLACE]
    cmp     w15, #(IT_ROAD + 1)
    b.ne    1f
    LA      x11, overlay                // estrada: celula sem estrada
    mov     w14, #4
1:  mov     w0, #0
2:  cbz     w9, 9f
    ldrh    w12, [x10], #2
    ldrh    w13, [x10], #2
    add     w12, w12, w13, lsl #9
    ldrb    w12, [x11, w12, uxtw]
    cmp     w14, #0
    b.ne    3f
    cmp     w12, #0
    cinc    w0, w0, eq
    b       4f
3:  cmp     w12, w14
    cinc    w0, w0, ne
4:  sub     w9, w9, #1
    b       2b
9:  ret

// drag_item -> w1 = o item que se arrasta (cerca ou estrada)   folha
drag_item:
    ldr     w1, [x28, #G_PLACE]
    sub     w1, w1, #1
    cmp     w1, #IT_ROAD
    mov     w9, #IT_FENCE
    csel    w1, w1, w9, eq
    ret

// fence_press: apertou o botao com cercas na mao: comeca a fileira aqui
    .globl fence_press
fence_press:
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 9f
    ldr     w10, [x28, #G_HOVU]
    lsr     w10, w10, #6
    ldr     w11, [x28, #G_HOVV]
    lsr     w11, w11, #6
    str     w10, [x28, #G_FLASTU]       // ancora
    str     w11, [x28, #G_FLASTV]
    str     w10, [x28, #G_FTGU]
    str     w11, [x28, #G_FTGV]
    str     w9, [x28, #G_FTGOK]
    str     w9, [x28, #G_FDRAG]
9:  ret

// fence_commit: soltou o botao: coloca a fileira toda
    .globl fence_commit
fence_commit:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    ldr     w9, [x28, #G_FDRAG]
    cbz     w9, 9f
    str     wzr, [x28, #G_FDRAG]
    ldr     w9, [x28, #G_HOVOK]         // o mouse agora
    cbz     w9, 1f
    ldr     w10, [x28, #G_HOVU]
    lsr     w10, w10, #6
    str     w10, [x28, #G_FTGU]
    ldr     w10, [x28, #G_HOVV]
    lsr     w10, w10, #6
    str     w10, [x28, #G_FTGV]
1:  bl      fence_plan
    mov     w19, w0                     // celulas
    mov     w20, #0                     // i
    mov     w21, #0                     // colocadas
    bl      drag_item
    mov     w22, w1                     // cerca ou estrada
2:  cmp     w20, w19
    b.ge    4f
    LA      x9, fplan
    add     x9, x9, x20, lsl #2
    ldrh    w0, [x9]
    ldrh    w1, [x9, #2]
    add     w10, w0, w1, lsl #9
    cmp     w22, #IT_ROAD
    b.ne    21f
    LA      x11, overlay                // ja tem estrada: pula
    ldrb    w10, [x11, w10, uxtw]
    cmp     w10, #4
    b.eq    3f
    bl      road_put
    b       22f
21: LA      x11, fencegrid              // ja tem cerca: pula
    ldrb    w10, [x11, w10, uxtw]
    cbnz    w10, 3f
    mov     w2, #1
    bl      fence_put
22: add     w21, w21, w0
    add     x9, x28, #G_INV
    ldr     w9, [x9, x22, lsl #2]
    cbz     w9, 4f
3:  add     w20, w20, #1
    b       2b
4:  add     x9, x28, #G_INV
    ldr     w9, [x9, x22, lsl #2]
    cbnz    w9, 5f
    str     wzr, [x28, #G_PLACE]        // acabaram as cercas (ou estradas)
5:  LA      x0, m_nofence
    cmp     w22, #IT_ROAD
    b.ne    51f
    LA      x0, m_noroad
51: cbz     w21, 6f
    LA      x0, fmsgbuf                 // "9 cercas colocadas"
    mov     w1, w21
    bl      numcat
    LA      x1, m_placed
    cmp     w22, #IT_ROAD
    b.ne    52f
    LA      x1, m_rplaced
52: bl      strcat_cur
    LA      x0, fmsgbuf
6:  bl      set_msg
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// fence_plan -> w0 = celulas da fileira em fplan (u16 u, u16 v), da ancora
// ate a celula sob o mouse, travada em 8 direcoes da tela: horizontal,
// vertical (diagonais do mapa: em escadinha, sem quina aberta) e as duas
// diagonais (eixos do mapa)
    .globl fence_plan
fence_plan:
    ldr     w0, [x28, #G_FLASTU]        // ancora
    ldr     w1, [x28, #G_FLASTV]
    ldr     w2, [x28, #G_FTGU]
    sub     w2, w2, w0                  // du
    ldr     w3, [x28, #G_FTGV]
    sub     w3, w3, w1                  // dv
    // candidatos (a, b): escolhe o mais perto na tela
    // tela: X ~ 2 (a - b), Y ~ (a + b)
    mov     w4, w2                      // eixo u: (du, 0)
    mov     w5, #0
    sub     w9, w4, w2
    sub     w10, w5, w3
    sub     w11, w9, w10
    lsl     w11, w11, #1
    add     w12, w9, w10
    mul     w11, w11, w11
    madd    w6, w12, w12, w11           // melhor distancia
    mov     w9, #0                      // eixo v: (0, dv)
    sub     w10, w3, w3
    sub     w9, w9, w2
    sub     w11, w9, w10
    lsl     w11, w11, #1
    add     w12, w9, w10
    mul     w11, w11, w11
    madd    w11, w12, w12, w11
    cmp     w11, w6
    b.ge    1f
    mov     w6, w11
    mov     w4, #0
    mov     w5, w3
1:  add     w7, w2, w3                  // vertical da tela: (k, k)
    mov     w8, #2
    sdiv    w7, w7, w8
    sub     w9, w7, w2
    sub     w10, w7, w3
    sub     w11, w9, w10
    lsl     w11, w11, #1
    add     w12, w9, w10
    mul     w11, w11, w11
    madd    w11, w12, w12, w11
    cmp     w11, w6
    b.ge    2f
    mov     w6, w11
    mov     w4, w7
    mov     w5, w7
2:  sub     w7, w2, w3                  // horizontal da tela: (k, -k)
    sdiv    w7, w7, w8
    neg     w13, w7
    sub     w9, w7, w2
    sub     w10, w13, w3
    sub     w11, w9, w10
    lsl     w11, w11, #1
    add     w12, w9, w10
    mul     w11, w11, w11
    madd    w11, w12, w12, w11
    cmp     w11, w6
    b.ge    3f
    mov     w4, w7
    mov     w5, w13
    // passos e sentido
3:  cmp     w4, #0
    cneg    w6, w4, lt                  // |a|
    cmp     w5, #0
    cneg    w7, w5, lt                  // |b|
    cmp     w6, w7
    csel    w6, w6, w7, gt              // n
    cmp     w6, #FENCEMAXSTEP
    mov     w7, #FENCEMAXSTEP
    csel    w6, w7, w6, gt
    cmp     w4, #0                      // su
    cset    w7, ne
    cneg    w7, w7, lt
    cmp     w5, #0                      // sv
    cset    w8, ne
    cneg    w8, w8, lt
    LA      x9, fplan
    mov     w10, #0                     // celulas
    mov     w11, w0                     // u, v atuais
    mov     w12, w1
    mov     w13, #0                     // i
4:  cmp     w11, #2                     // dentro do mapa
    b.lt    9f
    cmp     w12, #2
    b.lt    9f
    cmp     w11, #509
    b.gt    9f
    cmp     w12, #509
    b.gt    9f
    strh    w11, [x9], #2
    strh    w12, [x9], #2
    add     w10, w10, #1
    cmp     w13, w6
    b.ge    9f
    add     w13, w13, #1
    add     w11, w11, w7
    cbz     w7, 5f
    cbz     w8, 5f
    cmp     w11, #509                   // diagonal: degrau (anda em u, depois em v)
    b.gt    9f
    cmp     w11, #2
    b.lt    9f
    strh    w11, [x9], #2
    strh    w12, [x9], #2
    add     w10, w10, #1
5:  add     w12, w12, w8
    b       4b
9:  str     w10, [x28, #G_FPLANN]
    mov     w0, w10
    ret

// =====================================================================
//  Grade e previa (desenhadas por cima de tudo, depois da noite e do clima)
// =====================================================================

// ovl_pt(s0 = u, s1 = v) -> w0 x, w1 y, w2 prof. (na superficie do chao/agua)
ovl_pt:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     d8, d9, [sp, #16]
    fmov    s8, s0
    fmov    s9, s1
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    csel    w0, w9, w0, lt
    fmov    s0, s8
    fmov    s1, s9
    bl      proj
    ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ovl_plot: pixel (w0, w1) com profundidade w4, cor w5, w6 = 0 (25%) ou 1 (50%)
// folha: usa x14-x17
ovl_plot:
    cmp     w0, #SCRW
    b.hs    9f
    cmp     w1, #SCRH
    b.hs    9f
    mov     w14, #SCRW
    madd    w14, w1, w14, w0
    LA      x15, zb                     // algo na frente (arvore, bicho)?
    ldrh    w16, [x15, w14, uxtw #1]
    sub     w16, w16, w4
    cmp     w16, #40
    b.gt    9f
    LA      x15, fb
    ldr     w16, [x15, w14, uxtw #2]
    lsr     w17, w16, #1
    and     w17, w17, #0x7F7F7F7F
    cbnz    w6, 1f
    lsr     w16, w16, #2                // 25%: 3/4 fundo + 1/4 cor
    and     w16, w16, #0x3F3F3F3F
    add     w16, w16, w17
    lsr     w17, w5, #2
    and     w17, w17, #0x3F3F3F3F
    b       2f
1:  mov     w16, w17                    // 50%
    lsr     w17, w5, #1
    and     w17, w17, #0x7F7F7F7F
2:  add     w16, w16, w17
    orr     w16, w16, #0xFF000000
    str     w16, [x15, w14, uxtw #2]
9:  ret

// ovl_line(w0 x0, w1 y0, w2 x1, w3 y1, w4 prof., w5 cor, w6 modo)  folha
ovl_line:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w7, w0
    mov     w8, w1
    sub     w9, w2, w0                  // dx
    sub     w10, w3, w1                 // dy
    cmp     w9, #0
    cneg    w11, w9, lt
    cmp     w10, #0
    cneg    w12, w10, lt
    cmp     w11, w12
    csel    w11, w11, w12, gt           // passos
    cmp     w11, #400                   // segmento absurdo (fora da tela)
    b.gt    9f
    cmp     w11, #0
    csinc   w11, w11, wzr, gt
    mov     w12, #1                     // i (o ponto 0 ja foi no anterior)
1:  cmp     w12, w11
    b.gt    9f
    mul     w0, w9, w12
    sdiv    w0, w0, w11
    add     w0, w0, w7
    mul     w1, w10, w12
    sdiv    w1, w1, w11
    add     w1, w1, w8
    bl      ovl_plot
    add     w12, w12, #1
    b       1b
9:  ldp     x29, x30, [sp], #16
    ret

// ovl_edge(w0 u, w1 v, w2 = 0 lado em u / 1 lado em v, w3 cor, w4 modo):
// lado da celula seguindo o relevo (8 pedacos)
ovl_edge:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    mov     w22, w3
    mov     w23, w4
    mov     w24, #0                     // k
1:  scvtf   s0, w19
    scvtf   s1, w20
    scvtf   s2, w24
    fmov    s3, #0.125
    fmul    s2, s2, s3
    cbnz    w21, 2f
    fadd    s0, s0, s2
    b       3f
2:  fadd    s1, s1, s2
3:  bl      ovl_pt
    cbz     w24, 4f
    mov     w9, w0
    mov     w10, w1
    mov     w4, w2
    mov     w0, w25
    mov     w1, w26
    mov     w2, w9
    mov     w3, w10
    mov     w25, w9
    mov     w26, w10
    mov     w5, w22
    mov     w6, w23
    bl      ovl_line
    b       5f
4:  mov     w25, w0
    mov     w26, w1
    mov     w4, w2
    mov     w5, w22
    mov     w6, w23
    bl      ovl_plot
5:  add     w24, w24, #1
    cmp     w24, #8
    b.le    1b
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ovl_cell(w0 u, w1 v, w2 cor): pinta a celula (50%) e contorna
ovl_cell:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    scvtf   s0, w19                     // elevacao do meio
    scvtf   s1, w20
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    csel    w22, w9, w0, lt
    scvtf   s0, w19                     // canto de cima
    scvtf   s1, w20
    mov     w0, w22
    bl      proj
    mov     w23, w0                     // x do meio
    mov     w24, w1                     // y de cima
    scvtf   s0, w19                     // canto da direita
    fmov    s2, #1.0
    fadd    s0, s0, s2
    scvtf   s1, w20
    mov     w0, w22
    bl      proj
    sub     w25, w0, w23                // meia largura
    add     w4, w2, #64                 // profundidade (com folga)
    sub     w26, w1, w24                // meia altura
    cmp     w26, #1
    b.lt    5f
    // linhas de cima a baixo
    mov     w27, #0                     // dy desde o topo
1:  lsl     w9, w26, #1
    cmp     w27, w9
    b.ge    5f
    sub     w9, w27, w26                // distancia ao meio
    cmp     w9, #0
    cneg    w9, w9, lt
    sub     w9, w26, w9
    mul     w9, w9, w25
    sdiv    w9, w9, w26                 // meia largura nesta linha
    add     w1, w24, w27
    sub     w0, w23, w9
    add     w10, w23, w9
2:  cmp     w0, w10
    b.gt    3f
    mov     w5, w21
    mov     w6, #1
    stp     w0, w10, [sp, #-16]!
    bl      ovl_plot
    ldp     w0, w10, [sp], #16
    add     w0, w0, #1
    b       2b
3:  add     w27, w27, #1
    b       1b
5:  mov     w0, w19                     // contorno
    mov     w1, w20
    mov     w2, #0
    mov     w3, w21
    mov     w4, #1
    bl      ovl_edge
    mov     w0, w19
    mov     w1, w20
    mov     w2, #1
    mov     w3, w21
    mov     w4, #1
    bl      ovl_edge
    add     w0, w19, #1
    mov     w1, w20
    mov     w2, #1
    mov     w3, w21
    mov     w4, #1
    bl      ovl_edge
    mov     w0, w19
    add     w1, w20, #1
    mov     w2, #0
    mov     w3, w21
    mov     w4, #1
    bl      ovl_edge
    ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// grid_prep (antes do terreno): a grade aparece no chao com uma
// construcao, enxada ou sementes na mao, ou ligada pela tecla G. O
// terreno desenha as linhas (seguindo o relevo, atras das arvores).
    .globl grid_prep
grid_prep:
    str     wzr, [x28, #G_GRIDSHOW]
    str     wzr, [x28, #G_ZONESHOW]
    ldr     w9, [x28, #G_STATE]
    cbz     w9, 9f
    ldr     w9, [x28, #G_SLEEP]
    cbnz    w9, 9f
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, 9f
    ldr     w9, [x28, #G_ZONEMODE]      // zonas no chao: pintando ou com o
    ldr     w11, [x28, #G_PEOPLEOPEN]   // painel de pessoas aberto
    orr     w11, w11, w9
    str     w11, [x28, #G_ZONESHOW]
    mov     w10, #-1                    // alcance (linhas mais fortes)
    cbnz    w9, 2f                      // pintando zonas: a grade tambem
    ldr     w9, [x28, #G_PLACE]
    cbz     w9, 1f
    sub     w9, w9, #1
    mov     w10, #25                    // construcoes: 5 celulas
    cmp     w9, #IT_FENCE
    b.eq    11f
    cmp     w9, #IT_ROAD
    b.eq    11f
    cmp     w9, #IT_GATE
    b.ne    2f
11: mov     w10, #FENCEREACH            // cerca, portao e estrada: 8
    b       2f
1:  ldr     w9, [x28, #G_HAND]
    cmp     w9, #(IT_HOE + 1)
    b.lo    12f
    cmp     w9, #(IT_SEED + 1)
    b.hi    12f
    mov     w10, #9                     // enxada e sementes: 3
    b       2f
12: ldr     w9, [x28, #G_GRIDON]
    cbz     w9, 9f
2:  str     w10, [x28, #G_GRIDREACH]
    ldr     s0, [x28, #G_PU]
    fcvtzs  w9, s0
    str     w9, [x28, #G_GRIDPU]
    ldr     s0, [x28, #G_PV]
    fcvtzs  w9, s0
    str     w9, [x28, #G_GRIDPV]
    ldr     w9, [x28, #G_K]             // um passo do terreno: linha fina
    lsl     w9, w9, #2                  // (G_K em 1/256)
    str     w9, [x28, #G_GRIDW]
    mov     w9, #1
    str     w9, [x28, #G_GRIDSHOW]
9:  ret

// fence_overlay: previa do que esta na mao (a grade fica no chao).
// Construcao: o(s) quadrado(s) que vai ocupar, verde = da, vermelho = nao
// da, branco = ja tem cerca. Enxada e sementes: o quadrado sob o mouse.
    .globl fence_overlay
fence_overlay:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    ldr     w9, [x28, #G_SLEEP]
    cbnz    w9, 99f
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, 99f
    ldr     w9, [x28, #G_PLACE]
    cbz     w9, 50f
    sub     w26, w9, #1                 // item
    ldr     w9, [x28, #G_FTGOK]
    cbz     w9, 99f
    cmp     w26, #IT_ROAD
    b.eq    6f
    cmp     w26, #IT_FENCE
    b.ne    7f
6:  ldr     w9, [x28, #G_FDRAG]
    cbz     w9, 7f
    bl      fence_plan                  // arrastando cercas: a fileira
    b       8f
7:  LA      x9, fplan                   // so o quadrado sob o mouse
    ldr     w10, [x28, #G_FTGU]
    strh    w10, [x9]
    ldr     w10, [x28, #G_FTGV]
    strh    w10, [x9, #2]
    mov     w0, #1
8:  mov     w19, w0                     // quadrados
    add     x9, x28, #G_INV
    ldr     w21, [x9, x26, lsl #2]      // itens que sobram
    mov     w20, #0
10: cmp     w20, w19
    b.ge    99f
    LA      x9, fplan
    add     x9, x9, x20, lsl #2
    ldrh    w22, [x9]
    ldrh    w23, [x9, #2]
    MOVI32  w24, 0xFFFFFFFF             // ja tem cerca (e e cerca): branco
    add     w10, w22, w23, lsl #9
    cmp     w26, #IT_ROAD
    b.ne    101f
    LA      x11, overlay                // ja tem estrada: branco
    ldrb    w10, [x11, w10, uxtw]
    cmp     w10, #4
    b.eq    13f
    b       11f
101: LA     x11, fencegrid
    ldrb    w10, [x11, w10, uxtw]
    cmp     w26, #IT_FENCE
    b.ne    11f
    cbnz    w10, 13f
11: MOVI32  w24, 0xFFE03C30             // vermelho
    cbz     w21, 13f
    scvtf   s0, w22
    scvtf   s1, w23
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      build_check
    cbnz    x0, 13f
    MOVI32  w24, 0xFF40E060             // verde
    sub     w21, w21, #1
13: mov     w0, w22
    mov     w1, w23
    mov     w2, w24
    bl      ovl_cell
    cmp     w26, #IT_SHELTER            // abrigo: bloco 2 x 2
    b.ne    15f
    add     w0, w22, #1
    mov     w1, w23
    mov     w2, w24
    bl      ovl_cell
    mov     w0, w22
    add     w1, w23, #1
    mov     w2, w24
    bl      ovl_cell
    add     w0, w22, #1
    add     w1, w23, #1
    mov     w2, w24
    bl      ovl_cell
15: add     w20, w20, #1
    b       10b
    // ---- enxada e sementes: o quadrado sob o mouse ----
50: ldr     w9, [x28, #G_HAND]
    cmp     w9, #(IT_HOE + 1)
    b.lo    99f
    cmp     w9, #(IT_SEED + 1)
    b.hi    99f
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 99f
    ldr     w22, [x28, #G_HOVU]
    lsr     w22, w22, #6
    ldr     w23, [x28, #G_HOVV]
    lsr     w23, w23, #6
    cmp     w22, #2
    b.lt    99f
    cmp     w23, #2
    b.lt    99f
    cmp     w22, #509
    b.gt    99f
    cmp     w23, #509
    b.gt    99f
    add     w0, w22, w23, lsl #9
    bl      farm_tint
    cbz     w0, 99f
    mov     w2, w0
    mov     w0, w22
    mov     w1, w23
    bl      ovl_cell
99: ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ovl_inrange(w0 du, w1 dv) -> w0 = 1 se du^2 + dv^2 <= 64 (alcance)
ovl_inrange:
    mul     w9, w0, w0
    madd    w9, w1, w1, w9
    cmp     w9, #FENCEREACH
    cset    w0, le
    ret

// ---------------------------------------------------------------------
    .data
m_onplayer: .asciz "Voce esta ai: saia da celula primeiro"
m_hasfence: .asciz "Ja tem cerca aqui"
m_occupied: .asciz "Ocupado: tem algo nesse quadrado"
m_farmland: .asciz "Terra arada (a enxada desfaz)"
m_row1:     .asciz "Fileira: "
m_row2:     .asciz " cercas (voce tem "
m_rrow2:    .asciz " estradas (voce tem "
m_rplaced:  .asciz " quadrados de estrada"
m_noroad:   .asciz "Nenhuma estrada coube ai (vermelho = nao da)"
m_hasroad:  .asciz "Ja tem estrada aqui"
m_row3:     .asciz ")"
m_placed:   .asciz " cercas colocadas"
m_nofence:  .asciz "Nenhuma cerca coube ai (vermelho = nao da)"
fmsgbuf:    .space 64
    .p2align 2
GBSS fplan, 512                         // fileira: ate 128 celulas (u16 u, u16 v)

GBSS fencegrid, 262144                  // 0 nada, 1 cerca, 2 portao (por celula)
GBSS occgrid, 262144                    // 1 = tem algo em cima (para construir)
