// =====================================================================
//  cercas.S - cercas e portoes
//
//  - Cada celula do mapa pode ter uma cerca (1) ou um portao (2), na
//    grade fencegrid. Cerca: ninguem passa. Portao: voce passa, os
//    animais nao.
//  - Colocar: com cercas na mao, segure o clique e arraste; a fileira
//    vai seguindo o mouse, celula por celula (sem buracos na diagonal).
//  - O portao pode ser colocado em cima de uma cerca (troca por ela).
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

// fence_check(s0 = u, s1 = v) -> x0 = 0 se da para por cerca/portao
// ali (senao o motivo), s0/s1 = centro da celula, w1 = elevacao
    .globl fence_check
fence_check:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     d8, d9, [sp, #32]
    fcvtzs  w19, s0                     // celula
    fcvtzs  w20, s1
    scvtf   s8, w19
    scvtf   s9, w20
    fmov    s2, #0.5
    fadd    s8, s8, s2                  // centro
    fadd    s9, s9, s2
    LA      x0, m_far                   // ate 8 celulas
    ldr     s2, [x28, #G_PU]
    ldr     s3, [x28, #G_PV]
    fsub    s2, s8, s2
    fsub    s3, s9, s3
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    mov     w9, #FENCEREACH
    scvtf   s3, w9
    fcmp    s2, s3
    b.gt    8f
    LA      x0, m_onplayer              // nao na celula do personagem
    ldr     s2, [x28, #G_PU]
    fcvtzs  w9, s2
    ldr     s2, [x28, #G_PV]
    fcvtzs  w10, s2
    cmp     w9, w19
    b.ne    1f
    cmp     w10, w20
    b.eq    8f
1:  add     w9, w19, w20, lsl #9        // ja tem cerca? (portao pode trocar)
    LA      x10, fencegrid
    ldrb    w9, [x10, w9, uxtw]
    cbz     w9, 2f
    LA      x0, m_hasfence
    cmp     w9, #1
    b.ne    8f
    ldr     w10, [x28, #G_PLACE]
    cmp     w10, #(IT_GATE + 1)
    b.ne    8f
2:  fmov    s0, s8                      // agua?
    fmov    s1, s9
    bl      elev_at
    mov     w1, w0
    LA      x0, m_water
    ldr     w9, [x28, #G_FLOOD]
    cmp     w1, w9
    b.lt    8f
    mov     x0, #0
8:  fmov    s0, s8
    fmov    s1, s9
    ldp     d8, d9, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
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

// fence_drag: segurando o clique com cercas na mao, a fileira segue o
// mouse ate 8 celulas por quadro (passos em u ou em v, nunca na diagonal)
    .globl fence_drag
fence_drag:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    ldr     w9, [x28, #G_FDRAG]
    cbz     w9, 9f
    ldr     w9, [x28, #G_PLACE]
    cmp     w9, #(IT_FENCE + 1)
    b.eq    1f
    str     wzr, [x28, #G_FDRAG]
    b       9f
1:  ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 9f
    ldr     w19, [x28, #G_HOVU]         // celula alvo
    lsr     w19, w19, #6
    ldr     w20, [x28, #G_HOVV]
    lsr     w20, w20, #6
    mov     w22, #8
2:  ldr     w9, [x28, #G_FLASTU]
    ldr     w10, [x28, #G_FLASTV]
    subs    w11, w19, w9                // du
    sub     w12, w20, w10               // dv
    orr     w13, w11, w12
    cbz     w13, 9f                     // chegou
    cmp     w11, #0                     // |du| e |dv|
    cneg    w14, w11, lt
    cmp     w12, #0
    cneg    w15, w12, lt
    cmp     w14, w15
    b.lt    3f
    cmp     w11, #0                     // anda em u
    mov     w13, #1
    cneg    w13, w13, lt
    add     w9, w9, w13
    b       4f
3:  cmp     w12, #0                     // anda em v
    mov     w13, #1
    cneg    w13, w13, lt
    add     w10, w10, w13
4:  str     w9, [x28, #G_FLASTU]
    str     w10, [x28, #G_FLASTV]
    scvtf   s0, w9                      // longe demais: para
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
    mov     w11, #FENCEREACH
    scvtf   s1, w11
    fcmp    s0, s1
    b.gt    8f
    mov     w0, w9
    mov     w1, w10
    mov     w2, #1
    bl      fence_put
    ldr     w9, [x28, #(G_INV + 4 * IT_FENCE)]
    cbnz    w9, 5f
    str     wzr, [x28, #G_PLACE]        // acabaram as cercas
    b       8f
5:  subs    w22, w22, #1
    b.ne    2b
    b       9f
8:  str     wzr, [x28, #G_FDRAG]
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
    .data
m_onplayer: .asciz "Voce esta ai: saia da celula primeiro"
m_hasfence: .asciz "Ja tem cerca aqui"

GBSS fencegrid, 262144                  // 0 nada, 1 cerca, 2 portao (por celula)
