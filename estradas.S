// =====================================================================
//  estradas.S - estradas de pedra
//
//  - A estrada e um piso (overlay = 4): o chao desenha o azulejo certo
//    pelos 4 vizinhos (ermo.S, terrain_color; azulejos em estruturas.S).
//    Anda-se 50% mais rapido nela (a terra batida da 25-30%).
//  - Voce: item Estrada (1 pedra no Fabricar), arrastado como a cerca.
//    A enxada desfaz a estrada e devolve a pedra.
// =====================================================================

#include "comum.h"

.equ OV_ROAD,    4

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

// =====================================================================
//  Teste automatico (--shot)
//   voce arrasta 6 estradas e desfaz uma com a enxada
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

// rt_spot -> w0, w1 = o meio de um quadrado de 31 x 31 celulas de terra,
// quase plano, o mais perto de voce (-1 se nao achou)
rt_spot:
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
    bl      rt_spot                     // um lugar plano de terra
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
rt_nl:      .asciz "\n"
    .p2align 2
rtres:      .space 128
