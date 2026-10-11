// =====================================================================
//  colisao.S - ninguem atravessa ninguem
//
//  - Cabem no maximo 2 pessoas por quadrado (voce conta tambem): dois
//    podem se cruzar indo em sentidos opostos.
//  - Quem anda e ve alguem no quadrado da frente vai pela direita (cada
//    um pela sua direita: se cruzam sem bater).
//  - Ninguem fica trancado: quem espera demais passa assim mesmo (os
//    moradores ~2 s, voce ~1 s).
//  Contagem: crowd (1 byte por celula), refeita a cada quadro a partir
//  de onde cada um esta, e atualizada na hora quando alguem muda de
//  celula.
// =====================================================================

#include "comum.h"
#include "pessoas.h"

.equ CROWDMAX,   2
.equ NCROWD,     (MAXPEOPLE + 1)         // as pessoas e voce (a ultima)

    .text
    .p2align 2

// crowd_frame: conta quem esta em cada celula (chamar 1 vez por quadro)
    .globl crowd_frame
crowd_frame:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x9, crowd
    LA      x10, lastcell
    mov     w11, #0
1:  ldr     w12, [x10, x11, lsl #2]     // apaga as contas do quadro passado
    tbnz    w12, #31, 2f
    strb    wzr, [x9, w12, uxtw]
2:  add     w11, w11, #1
    cmp     w11, #NCROWD
    b.lt    1b
    mov     w11, #0
    LA      x13, people
3:  mov     w12, #-1
    ldr     w14, [x28, #G_NOPEOPLE]
    cbnz    w14, 4f
    ldrb    w14, [x13, #P_ALIVE]
    cbz     w14, 4f
    ldrb    w14, [x13, #P_FLAGS]        // dentro de casa nao ocupa
    tbnz    w14, #0, 4f
    ldr     s0, [x13, #P_U]
    fcvtzs  w14, s0
    ldr     s0, [x13, #P_V]
    fcvtzs  w15, s0
    bl      cr_cell
4:  str     w12, [x10, x11, lsl #2]
    add     x13, x13, #PSIZE
    add     w11, w11, #1
    cmp     w11, #MAXPEOPLE
    b.lt    3b
    mov     w12, #-1                    // voce
    ldr     w14, [x28, #G_SLEEP]
    cbnz    w14, 5f
    ldr     w14, [x28, #G_DEAD]
    cbnz    w14, 5f
    ldr     w14, [x28, #G_STATE]
    cbz     w14, 5f
    ldr     s0, [x28, #G_PU]
    fcvtzs  w14, s0
    ldr     s0, [x28, #G_PV]
    fcvtzs  w15, s0
    bl      cr_cell
5:  str     w12, [x10, x11, lsl #2]
    ldp     x29, x30, [sp], #16
    ret

// cr_cell(w14 u, w15 v) -> w12 = celula (conta mais um)   folha
// (so mexe em w12, w16)
cr_cell:
    cmp     w14, #MAPN
    b.hs    8f
    cmp     w15, #MAPN
    b.hs    8f
    add     w12, w14, w15, lsl #9
    ldrb    w16, [x9, w12, uxtw]
    cmp     w16, #255
    cinc    w16, w16, lo
    strb    w16, [x9, w12, uxtw]
    ret
8:  mov     w12, #-1
    ret

// crowd_try(w0 = quem (MAXPEOPLE = voce), w1 = celula de antes, w2 =
// celula nova, w3 = quantas tentativas ate passar assim mesmo)
// -> w0 = 1 pode entrar (as contas mudam), 0 esta cheio   folha
    .globl crowd_try
crowd_try:
    cmp     w1, w2
    b.eq    7f
    cmp     w2, #(MAPN * MAPN / 4096), lsl #12
    b.hs    7f
    LA      x9, crowd
    LA      x10, cwait
    add     x10, x10, w0, uxtw #1
    ldrb    w11, [x9, w2, uxtw]
    cmp     w11, #CROWDMAX
    b.lo    1f
    ldrh    w12, [x10]                  // cheio: espera (ou passa, se demorou)
    add     w12, w12, #1
    strh    w12, [x10]
    cmp     w12, w3
    b.lo    8f
1:  strh    wzr, [x10]
    cmp     w1, #(MAPN * MAPN / 4096), lsl #12
    b.hs    2f
    ldrb    w12, [x9, w1, uxtw]
    cmp     w12, #0
    b.eq    2f
    sub     w12, w12, #1
    strb    w12, [x9, w1, uxtw]
2:  ldrb    w12, [x9, w2, uxtw]
    cmp     w12, #255
    cinc    w12, w12, lo
    strb    w12, [x9, w2, uxtw]
    LA      x9, lastcell
    str     w2, [x9, w0, uxtw #2]
7:  mov     w0, #1
    ret
8:  mov     w0, #0
    ret

// crowd_at(w0 = celula) -> w0 = quantos estao la   folha
    .globl crowd_at
crowd_at:
    cmp     w0, #(MAPN * MAPN / 4096), lsl #12
    b.hs    8f
    LA      x9, crowd
    ldrb    w0, [x9, w0, uxtw]
    ret
8:  mov     w0, #0
    ret

// crowd_reset: ninguem em lugar nenhum (mundo novo / carregou)   folha
    .globl crowd_reset
crowd_reset:
    LA      x9, crowd
    mov     w10, #(MAPN * MAPN / 16)
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    LA      x9, lastcell
    mov     w10, #-1
    mov     w11, #NCROWD
2:  str     w10, [x9], #4
    subs    w11, w11, #1
    b.ne    2b
    LA      x9, cwait
    mov     w11, #NCROWD
3:  strh    wzr, [x9], #2
    subs    w11, w11, #1
    b.ne    3b
    ret

// =====================================================================
//  Teste automatico (--shot): 4 pessoas se cruzam num corredor (2 de
//  cada lado, na mesma fileira) e todas chegam; conta o maximo no mesmo
//  quadrado
// =====================================================================
    .globl crowd_selftest
crowd_selftest:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    LA      x24, ctres
    bl      vt_spot                     // um lugar plano de terra
    tbnz    w0, #31, 90f
    mov     w21, w0                     // meio do corredor
    mov     w22, w1
    mov     w23, #-6                    // limpa 13 x 3
1:  mov     w25, #-1
2:  add     w0, w21, w23
    add     w1, w22, w25
    bl      ct_clear
    add     w25, w25, #1
    cmp     w25, #1
    b.le    2b
    add     w23, w23, #1
    cmp     w23, #6
    b.le    1b
    ldr     w9, [x28, #G_TIME]
    str     w9, [x24, #40]
    MOVI32  w9, (DAYLEN / 4)
    str     w9, [x28, #G_TIME]
    // as 4 primeiras pessoas vivas e acordadas
    LA      x19, people
    mov     w20, #0
    mov     w23, #0                     // quantas
3:  ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 39f
    ldrb    w9, [x19, #P_FLAGS]
    bic     w9, w9, #1
    strb    w9, [x19, #P_FLAGS]
    strb    w20, [x24, x23]             // guarda quem e
    mov     w9, #-5                     // 0 e 1: de -5 para +5; 2 e 3: ao contrario
    cmp     w23, #2
    b.lo    31f
    mov     w9, #5
31: add     w9, w9, w21
    scvtf   s0, w9
    fmov    s2, #0.5
    fadd    s0, s0, s2
    scvtf   s1, w22
    fadd    s1, s1, s2
    tst     w23, #1                     // um um pouco atras do outro
    b.eq    32f
    fmov    s3, #-1.0
    cmp     w23, #2
    b.lo    33f
    fmov    s3, #1.0
33: fadd    s0, s0, s3
32: str     s0, [x19, #P_U]
    str     s1, [x19, #P_V]
    neg     w9, w9                      // vai para o outro lado
    add     w9, w9, w21, lsl #1
    scvtf   s0, w9
    fadd    s0, s0, s2
    FC      s3, F_HUNDRED
    str     s3, [x19, #P_FOOD]
    bl      ppl_gopoint
    strb    wzr, [x19, #P_NEXT]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
    add     w23, w23, #1
    cmp     w23, #4
    b.ge    4f
39: add     x19, x19, #PSIZE
    add     w20, w20, #1
    cmp     w20, #MAXPEOPLE
    b.lt    3b
4:  str     w23, [x24, #4]
    str     wzr, [x24, #20]             // chegou? (1 byte cada)
    str     wzr, [x24, #8]              // maximo no mesmo quadrado
    str     wzr, [x24, #12]             // quadros com 3 ou mais
    mov     w25, #0                     // quadros
5:  bl      surv_update
    mov     w23, #-6                    // o corredor
6:  add     w0, w21, w23
    add     w0, w0, w22, lsl #9
    bl      crowd_at
    ldr     w9, [x24, #8]
    cmp     w0, w9
    csel    w9, w0, w9, hi
    str     w9, [x24, #8]
    cmp     w0, #3
    b.lo    61f
    ldr     w9, [x24, #12]
    add     w9, w9, #1
    str     w9, [x24, #12]
61: add     w23, w23, #1
    cmp     w23, #6
    b.le    6b
    mov     w26, #0                     // quem ja chegou (a 1 celula)
64: ldrb    w9, [x24, x26]
    LA      x19, people
    add     x19, x19, x9, lsl #6
    mov     w9, #5
    cmp     w26, #2
    b.lo    65f
    mov     w9, #-5
65: add     w9, w9, w21
    scvtf   s0, w9
    fmov    s2, #0.5
    fadd    s0, s0, s2
    ldr     s1, [x19, #P_U]
    fsub    s0, s0, s1
    fabs    s0, s0
    fmov    s1, #1.0
    fcmp    s0, s1
    b.gt    66f
    add     x9, x24, #20
    mov     w10, #1
    strb    w10, [x9, x26]
66: add     w26, w26, #1
    ldr     w9, [x24, #4]
    cmp     w26, w9
    b.lt    64b
62: add     w25, w25, #1
    cmp     w25, #1200                  // 20 s
    b.lt    5b
    ldrb    w25, [x24, #20]             // quantas chegaram
    ldrb    w9, [x24, #21]
    add     w25, w25, w9
    ldrb    w9, [x24, #22]
    add     w25, w25, w9
    ldrb    w9, [x24, #23]
    add     w25, w25, w9
8:  str     w25, [x24, #16]
    ldr     w9, [x24, #40]
    str     w9, [x28, #G_TIME]
90: LA      x0, txt
    LA      x1, ct_t1
    ldr     w2, [x24, #4]
    bl      ct_num
    LA      x1, ct_t2
    ldr     w2, [x24, #16]
    bl      ct_num
    LA      x1, ct_t3
    ldr     w2, [x24, #8]
    bl      ct_num
    LA      x1, ct_t4
    ldr     w2, [x24, #12]
    bl      ct_num
    LA      x1, ct_nl
    bl      strcat_cur
    bl      sk_write
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// ct_clear(w0 u, w1 v): tira o que tem na celula (teste)
ct_clear:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    add     w19, w0, w1, lsl #9
    LA      x9, fencegrid
    strb    wzr, [x9, w19, uxtw]
1:  mov     w0, w19
    bl      obj_in_cell
    tbnz    w0, #31, 9f
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    mov     w10, #O_GONE
    strb    w10, [x9, #6]
    b       1b
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

ct_num:
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
ct_t1:      .asciz "colisao: pessoas cruzando um corredor="
ct_t2:      .asciz " chegaram="
ct_t3:      .asciz " | maximo no mesmo quadrado="
ct_t4:      .asciz " quadros com 3 ou mais="
ct_nl:      .asciz "\n"
    .p2align 2
ctres:      .space 64
lastcell:   .fill NCROWD, 4, -1         // onde cada um foi contado
cwait:      .space (NCROWD * 2)         // quanto esta esperando para entrar

GBSS crowd, 262144                       // quantos em cada celula
