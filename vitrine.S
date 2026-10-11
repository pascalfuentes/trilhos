// =====================================================================
//  vitrine.S - todas as construcoes lado a lado, para fotos (--shot)
//
//  Acha um lugar plano perto de voce, limpa o terreno e monta:
//    atras:  2 barracos e 2 casas (as 4 cores de familia)
//    meio:   fogueira, bau, abrigo, fornalha, lampiao
//    frente: um cercado 4 x 4 com portao e as pilhas de um deposito
//  Tira uma foto de dia e outra de noite (luz da fogueira e do lampiao).
//  Serve para o designer ver as estruturas no ambiente de verdade, e para
//  conferir os desenhos novos quando chegarem.
// =====================================================================

#include "comum.h"

    .text
    .p2align 2

// cel(w0 = a, w1 = b) -> w0 = u, w1 = v da celula
// a anda na horizontal da tela (u+1, v-1); b anda para baixo (u+1, v+1)
vt_cel:
    LA      x9, vtpos
    ldp     w10, w11, [x9]
    add     w10, w10, w0
    add     w10, w10, w1
    sub     w11, w11, w0
    add     w11, w11, w1
    mov     w0, w10
    mov     w1, w11
    ret

// vt_add(w0 = a, w1 = b, w2 = tipo, w3 = variante, w4 = 1 no canto da
// celula (construcao 2 x 2), 0 no meio) -> w0 = objeto
vt_add:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w21, w2
    mov     w22, w3
    mov     w19, w4
    bl      vt_cel
    lsl     w0, w0, #6
    lsl     w1, w1, #6
    cbnz    w19, 1f
    add     w0, w0, #32
    add     w1, w1, #32
1:  mov     w19, w0
    mov     w20, w1
    scvtf   s0, w0
    scvtf   s1, w1
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    bl      elev_at
    mov     w2, w0
    mov     w0, w19
    mov     w1, w20
    mov     w3, w21
    mov     w4, w22
    bl      add_obj
    ldr     w0, [x28, #G_NOBJ]
    sub     w0, w0, #1
    LA      x9, memtype
    strb    w21, [x9, w0, uxtw]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// vt_spot -> w0, w1 = o meio de um quadrado de 31 x 31 celulas de terra,
// quase plano, o mais perto de voce (-1 se nao achou)
    .globl vt_spot
vt_spot:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     s0, [x28, #G_PU]
    fcvtzs  w12, s0
    ldr     s0, [x28, #G_PV]
    fcvtzs  w13, s0
    LA      x14, elev
    ldr     w15, [x28, #G_FLOOD]
    add     w15, w15, #8                // fora da beira da agua
    mov     w16, #-1                    // melhor: u, v, distancia^2
    mov     w17, #-1
    mov     w8, #0x7FFFFFFF
    mov     w3, #24                     // v candidato
1:  mov     w2, #24                     // u candidato
2:  sub     w4, w2, w12                 // longe demais do que ja achou? pula
    sub     w5, w3, w13
    mul     w4, w4, w4
    madd    w4, w5, w5, w4
    cmp     w4, w8
    b.ge    7f
    add     w5, w2, w3, lsl #9          // altura do meio
    ldrsh   w5, [x14, w5, uxtw #1]
    cmp     w5, w15
    b.lt    7f
    mov     w6, #-15                    // dv
3:  mov     w7, #-15                    // du
4:  add     w9, w2, w7
    add     w10, w3, w6
    add     w9, w9, w10, lsl #9
    ldrsh   w9, [x14, w9, uxtw #1]
    cmp     w9, w15
    b.lt    7f
    subs    w10, w9, w5
    cneg    w10, w10, mi
    cmp     w10, #160                   // quase plano
    b.gt    7f
    add     w7, w7, #3                  // de 3 em 3 basta
    cmp     w7, #15
    b.le    4b
    add     w6, w6, #3
    cmp     w6, #15
    b.le    3b
    mov     w16, w2                     // achou um mais perto
    mov     w17, w3
    mov     w8, w4
7:  add     w2, w2, #4
    cmp     w2, #487
    b.le    2b
    add     w3, w3, #4
    cmp     w3, #487
    b.le    1b
    mov     w0, w16
    mov     w1, w17
    ldp     x29, x30, [sp], #16
    ret

// vitrine_setup -> w0 = 1 se montou (0 se nao achou lugar)
    .globl vitrine_setup
vitrine_setup:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    LA      x24, vtpos
    ldr     w9, [x28, #G_PU]            // guarda voce, a hora e o clima
    str     w9, [x24, #8]
    ldr     w9, [x28, #G_PV]
    str     w9, [x24, #12]
    ldr     w9, [x28, #G_TIME]
    str     w9, [x24, #16]
    bl      vt_spot
    tbnz    w0, #31, 90f
    stp     w0, w1, [x24]
    mov     w19, w0
    mov     w20, w1
    // limpa 33 x 33 celulas: objetos, zonas, cercas, buracos; tudo a vista
    LA      x9, objs
    ldr     w10, [x28, #G_NOBJ]
1:  cbz     w10, 3f
    sub     w10, w10, #1
    add     x11, x9, x10, lsl #3
    ldrh    w12, [x11]
    lsr     w12, w12, #6
    sub     w12, w12, w19
    add     w12, w12, #16
    cmp     w12, #32
    b.hi    1b
    ldrh    w12, [x11, #2]
    lsr     w12, w12, #6
    sub     w12, w12, w20
    add     w12, w12, #16
    cmp     w12, #32
    b.hi    1b
    mov     w12, #O_GONE
    strb    w12, [x11, #6]
    b       1b
3:  mov     w21, #-16                   // dv
4:  mov     w22, #-16                   // du
5:  add     w9, w19, w22
    add     w10, w20, w21
    add     w9, w9, w10, lsl #9
    LA      x10, zonegrid
    strb    wzr, [x10, w9, uxtw]
    LA      x10, fencegrid
    strb    wzr, [x10, w9, uxtw]
    LA      x10, pitgrid
    strb    wzr, [x10, w9, uxtw]
    LA      x10, overlay
    strb    wzr, [x10, w9, uxtw]
    add     w22, w22, #1
    cmp     w22, #16
    b.le    5b
    add     w21, w21, #1
    cmp     w21, #16
    b.le    4b
    bl      dep_dirty
    // as construcoes (tabela vttab: a, b, tipo, variante, canto)
    LA      x23, vttab
6:  ldrsb   w0, [x23]
    cmp     w0, #127
    b.eq    7f
    ldrsb   w1, [x23, #1]
    ldrb    w2, [x23, #2]
    ldrb    w3, [x23, #3]
    ldrb    w4, [x23, #4]
    bl      vt_add
    ldrb    w9, [x23, #2]
    cmp     w9, #O_LAMP
    b.ne    61f
    bl      lamp_add                    // lampiao: acende de noite
61: add     x23, x23, #5
    b       6b
    // fogueira acesa no meio da fileira
7:  mov     w0, #-9
    mov     w1, #0
    bl      vt_cel
    scvtf   s0, w0
    scvtf   s1, w1
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    stp     s0, s1, [sp, #-16]!
    bl      elev_at
    ldp     s0, s1, [sp], #16
    ldr     w9, [x28, #G_NFIRE]
    LA      x10, fires
    add     x10, x10, x9, lsl #4
    str     s0, [x10]
    str     s1, [x10, #4]
    str     w0, [x10, #8]
    MOVI32  w11, FIRETIME
    str     w11, [x10, #12]
    add     w9, w9, #1
    str     w9, [x28, #G_NFIRE]
    // cercado 4 x 4 (em u e v) com portao no lado da frente
    mov     w0, #-8
    mov     w1, #4
    bl      vt_cel
    mov     w21, w0                     // u0
    mov     w22, w1                     // v0
    mov     w23, #0                     // dv
8:  mov     w24, #0                     // du
81: cmp     w23, #0                     // so a volta
    b.eq    82f
    cmp     w23, #3
    b.eq    82f
    cmp     w24, #0
    b.eq    82f
    cmp     w24, #3
    b.ne    85f
82: add     w0, w21, w24
    add     w1, w22, w23
    add     w9, w0, w1, lsl #9
    mov     w10, #1                     // cerca
    mov     w3, #O_FENCE
    cmp     w23, #3                     // portao: frente, segundo quadrado
    b.ne    83f
    cmp     w24, #1
    b.ne    83f
    mov     w10, #2
    mov     w3, #O_GATE
83: LA      x11, fencegrid
    strb    w10, [x11, w9, uxtw]
    lsl     w19, w0, #6
    add     w19, w19, #32
    lsl     w20, w1, #6
    add     w20, w20, #32
    str     w3, [sp, #-16]!
    scvtf   s0, w0
    scvtf   s1, w1
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      elev_at
    mov     w2, w0
    ldr     w3, [sp], #16
    mov     w0, w19
    mov     w1, w20
    mov     w4, #0
    str     w3, [sp, #-16]!
    bl      add_obj
    ldr     w3, [sp], #16
    ldr     w0, [x28, #G_NOBJ]
    sub     w0, w0, #1
    LA      x9, memtype
    strb    w3, [x9, w0, uxtw]
85: add     w24, w24, #1
    cmp     w24, #3
    b.le    81b
    add     w23, w23, #1
    cmp     w23, #3
    b.le    8b
    // estradas: uma reta em u que cruza uma em v, e um T
    LA      x24, vtpos
    ldp     w19, w20, [x24]
    LA      x10, overlay
    mov     w11, #4
    mov     w9, #-9                     // em u, na fileira v0 + 3
1:  add     w12, w19, w9
    add     w13, w20, #3
    add     w12, w12, w13, lsl #9
    strb    w11, [x10, w12, uxtw]
    add     w9, w9, #1
    cmp     w9, #5
    b.le    1b
    mov     w9, #-4                     // em v, na coluna u0 + 5
2:  add     w12, w19, #5
    add     w13, w20, w9
    add     w12, w12, w13, lsl #9
    strb    w11, [x10, w12, uxtw]
    add     w9, w9, #1
    cmp     w9, #8
    b.le    2b
    mov     w9, #4                      // um T: em v na coluna u0 - 6
3:  sub     w12, w19, #6
    add     w13, w20, w9
    add     w12, w12, w13, lsl #9
    strb    w11, [x10, w12, uxtw]
    add     w9, w9, #1
    cmp     w9, #8
    b.le    3b
    // voce no meio (a camera tambem), tudo a vista, sol
    LA      x24, vtpos
    ldp     w19, w20, [x24]
    scvtf   s0, w19
    scvtf   s1, w20
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    str     s0, [x28, #G_PU]
    str     s1, [x28, #G_PV]
    bl      elev_at
    str     w0, [x28, #G_PE]
    mov     w0, #W_SUN
    mov     w1, #30000
    mov     w2, #0
    bl      weather_set
    mov     w0, #1
    b       91f
90: mov     w0, #0
91: ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// vitrine_frame(w0 = hora em quadros, w1 = zoom): prepara a foto (camera,
// luz, visao)
    .globl vitrine_frame
vitrine_frame:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     w0, [x28, #G_TIME]
    LA      x9, noui
    mov     w10, #1
    strb    w10, [x9]
    str     wzr, [x28, #G_MSGT]
    str     wzr, [x28, #G_POPT]
    mov     w0, w1
    bl      set_zoom
    bl      follow_camera
    bl      update_ambient
    bl      update_vision
    LA      x9, vtpos                   // tudo a vista em volta
    ldp     w19, w20, [x9]
    mov     w10, #-18
1:  mov     w11, #-18
2:  add     w12, w19, w11
    add     w13, w20, w10
    add     w12, w12, w13, lsl #9
    mov     w13, #255
    LA      x14, vis
    strb    w13, [x14, w12, uxtw]
    LA      x14, seen
    strb    w13, [x14, w12, uxtw]
    add     w11, w11, #1
    cmp     w11, #18
    b.le    2b
    add     w10, w10, #1
    cmp     w10, #18
    b.le    1b
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// vitrine_done: volta voce para onde estava, na hora de antes
    .globl vitrine_done
vitrine_done:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x9, noui
    strb    wzr, [x9]
    LA      x9, vtpos
    ldr     w10, [x9, #8]
    str     w10, [x28, #G_PU]
    ldr     w10, [x9, #12]
    str     w10, [x28, #G_PV]
    ldr     w10, [x9, #16]
    str     w10, [x28, #G_TIME]
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    bl      elev_at
    str     w0, [x28, #G_PE]
    bl      follow_camera
    bl      update_ambient
    bl      update_vision
    ldp     x29, x30, [sp], #16
    ret

    .data
    .globl noui
noui:   .byte 0                         // 1 = draw_all nao desenha a interface
    .p2align 2
vtpos:  .space 32                       // u, v do meio; voce; a hora
// a, b, tipo, variante (cor da familia), 1 = no canto da celula (2 x 2)
vttab:
    .byte -9, -5, O_HUT, 0, 1           // atras: barracos e casas
    .byte -4, -5, O_HUT, 1, 1
    .byte  1, -5, O_HOUSE, 2, 1
    .byte  7, -5, O_HOUSE, 3, 1
    .byte -6,  0, O_CHEST, 0, 0         // meio (a fogueira fica em a = -9)
    .byte -2,  0, O_SHELTER, 0, 1
    .byte  3,  0, O_FURNACE, 0, 0
    .byte  6,  0, O_LAMP, 0, 0
    .byte  1,  5, O_LOGS, 20, 0         // frente: as pilhas de um deposito
    .byte  3,  5, O_STONES, 15, 0
    .byte  5,  5, O_BERRIES, 20, 0
    .byte  7,  5, (O_PILE2 + IT_BREAD - IT_SEED), 15, 0
    .byte  9,  5, (O_PILE3 + IT_IRON - IT_ORE), 10, 0
    .byte 127
