// =====================================================================
//  pilhas.S - pilhas de itens no chao
//
//  - Largar um item faz uma pilha no chao (um objeto, pile_at em
//    sobrevivencia.S); clicar nela pega de volta.
//  - Cada pilha guarda ate stackcap itens (20 madeiras, 15 pedras...).
//  - Comida no chao estraga (spoil_piles), mais rapido na chuva.
// =====================================================================

#include "comum.h"

    .text
    .p2align 2

// ---------------------------------------------------------------------

// pile_item(w0 = tipo de objeto) -> w0 = item da pilha (-1)   folha (w0, w1)
    .globl pile_item
pile_item:
    cmp     w0, #O_LOGS
    b.lo    8f
    cmp     w0, #(O_LOGS + 23)
    b.hi    1f
    cmp     w0, #O_CHEST
    b.eq    8f
    cmp     w0, #O_SHELTER
    b.eq    8f
    sub     w0, w0, #O_LOGS
    ret
1:  cmp     w0, #O_PILE2
    b.lo    8f
    cmp     w0, #(O_PILE2 + 2)
    b.hi    2f
    sub     w0, w0, #(O_PILE2 - IT_SEED)
    ret
2:  cmp     w0, #O_PILE3
    b.lo    8f
    cmp     w0, #(O_PILE3 + NITEMS - 1 - IT_ORE)
    b.hi    8f
    sub     w0, w0, #(O_PILE3 - IT_ORE)
    ret
8:  mov     w0, #-1
    ret

// ---------------------------------------------------------------------

// spoil_piles(w0 = passo, x1 = tabela item/periodo)
    .globl spoil_piles
spoil_piles:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     w19, w0
    mov     x20, x1
    mov     w23, #0                     // chuva?
    ldr     w9, [x28, #G_WEATHER]
    cmp     w9, #W_RAIN
    b.eq    1f
    cmp     w9, #W_STORM
    b.eq    1f
    cmp     w9, #W_FLOOD
    b.ne    2f
1:  mov     w23, #1
2:  ldr     w21, [x28, #G_NOBJ]
    LA      x22, objs
3:  cbz     w21, 9f
    sub     w21, w21, #1
    ldrb    w0, [x22, #6]
    bl      pile_item
    tbnz    w0, #31, 8f
    mov     x9, x20                     // perecivel? periodo
4:  ldrb    w10, [x9], #1
    cmp     w10, #255
    b.eq    8f
    ldrb    w11, [x9], #1
    cmp     w10, w0
    b.ne    4b
    lsr     w12, w11, w23               // chuva: metade do periodo
    udiv    w13, w19, w12
    msub    w13, w13, w12, w19
    cbnz    w13, 8f
    ldrb    w10, [x22, #7]              // perde um quarto (pelo menos 1)
    lsr     w11, w10, #2
    cmp     w11, #1
    csinc   w11, w11, wzr, hs
    subs    w10, w10, w11
    csel    w10, wzr, w10, lt
    strb    w10, [x22, #7]
    cbnz    w10, 8f
    mov     w10, #O_GONE
    strb    w10, [x22, #6]
8:  add     x22, x22, #8
    b       3b
9:  ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

    .data
// quanto cabe numa pilha
    .globl stackcap
stackcap:
    .byte 20, 15, 20, 5, 5, 10, 15, 3, 0, 0, 0, 3, 40, 10, 10, 10
    .byte 3, 3, 0, 0, 5, 10, 10, 5, 40, 20, 15, 15, 20, 10, 0, 3
    .byte 3, 3, 3, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
