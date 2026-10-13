// =====================================================================
//  heroi.S - o desenho do personagem em 8 direcoes
//
//  Os quadros estao em personagens.S (gerado por arte/personagens.py).
//  player_sprite escolhe o quadro pela direcao em que voce andou e pelo
//  passo; sem o cajado quando tem algo na mao ou a tocha acesa.
// =====================================================================

#include "comum.h"

    .text
    .p2align 2


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
