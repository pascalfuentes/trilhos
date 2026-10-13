// =====================================================================
//  heroi.S - o desenho do heroi em 8 direcoes
//
//  Os quadros estao em pixel.S (gerado por arte/pixel.py a partir do guia
//  de estilo do designer): o corpo e cada peca de equipamento sao uma
//  camada, no mesmo quadro e com a mesma ancora.
// =====================================================================

#include "comum.h"
#include "pixel.h"

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

// hero_draw(w1 = x, w2 = y do ponto do chao, w4 = profundidade): o heroi
// do designer (pixel.S) virado para onde andou, camada por camada na
// ordem da direcao. Parado ele respira; andando, os quadros correm.
// Roupa de couro na mochila: botas; armadura: peitoral e capacete (e o
// cabelo cortado embaixo dele); espada na mao: a espada.
    .globl hero_draw
hero_draw:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    mov     w19, w1
    mov     w20, w2
    mov     w21, w4
    LA      x9, pllast                  // direcao: para onde andou
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
    mov     w22, w0
    ldr     w10, [x28, #G_FRAME]        // parado: respira devagar
    lsr     w10, w10, #5
    ldr     w11, [x28, #G_PMOVING]
    cbz     w11, 1f
    ldr     w10, [x28, #G_PFRAME]       // andando: mais depressa
    lsr     w10, w10, #2
1:  and     w10, w10, #3
    add     w24, w10, w22, lsl #2       // direcao * 4 + quadro
    ldr     w25, [x28, #G_Z256]         // escala: 1 pixel do desenho
    lsr     w25, w25, #10               // = Z256 / 1024 pixels
    cmp     w25, #1
    mov     w9, #1
    csel    w25, w9, w25, lt
    LA      x9, pixshadow               // sombra no chao
    ldr     x0, [x9]
    mov     w1, w19
    mov     w2, w20
    mov     w3, w25
    mov     w4, w21
    mov     w5, #0
    bl      blit
    LA      x23, pixorder
    add     x23, x23, x22, lsl #3
    mov     w26, #0
2:  cmp     w26, #8
    b.ge    9f
    ldrb    w0, [x23, x26]
    cmp     w0, #255
    b.eq    9f
    bl      hero_layer
    tbnz    w0, #31, 8f
6:  lsl     w0, w0, #5                  // camada * 32 + quadro
    add     w0, w0, w24
    LA      x9, pixhero
    ldr     x0, [x9, x0, lsl #3]
    mov     w1, w19
    mov     w2, w20
    mov     w3, w25
    mov     w4, w21
    mov     w5, #0
    bl      blit
8:  add     w26, w26, #1
    b       2b
9:  ldr     w9, [x28, #G_LVLT]          // subiu de nivel: a luz dourada sobe
    mov     w10, #180                   // (8 quadros, 5 frames cada)
    subs    w9, w10, w9
    b.lt    10f
    mov     w10, #5
    udiv    w9, w9, w10
    cmp     w9, #PX_LVL_N
    b.hs    10f
    LA      x10, pixlvl
    ldr     x0, [x10, x9, lsl #3]
    mov     w1, w19
    mov     w2, w20
    mov     w3, w25
    mov     w4, w21
    mov     w5, #0
    bl      blit
10: ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

    .data
pldir:      .byte 0
    .p2align 3
pllast:     .space 8

    .text
// hero_layer(w0 = camada) -> w0 = camada a desenhar com o equipamento de
// agora, ou -1 se nao aparece (sem armadura, sem casaco, sem espada)  folha
    .globl hero_layer
hero_layer:
    ldr     w9, [x28, #(G_INV + 4 * IT_ARMOR)]
    cmp     w0, #PL_CABELO              // com o capacete, o cabelo curto
    b.ne    3f
    cbz     w9, 6f
    mov     w0, #PL_CABELO_ELMO
    ret
3:  cmp     w0, #PL_PEITO
    b.eq    4f
    cmp     w0, #PL_CAPACETE
    b.ne    5f
4:  cbz     w9, 8f                      // sem armadura: nada
    ret
5:  cmp     w0, #PL_BOTAS
    b.ne    51f
    ldr     w9, [x28, #(G_INV + 4 * IT_COAT)]
    cbz     w9, 8f
    ret
51: cmp     w0, #PL_ARMA
    b.ne    6f
    ldr     w9, [x28, #G_HAND]
    cmp     w9, #(IT_SWORD + 1)
    b.ne    8f
6:  ret
8:  mov     w0, #-1
    ret

// hero_portrait(w0 x, w1 y): o heroi de frente na interface (retrato da
// janela C), com o equipamento de agora, camada por camada
    .globl hero_portrait
hero_portrait:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    LA      x21, pixorder               // direcao 0 (S)
    mov     w22, #0
1:  cmp     w22, #8
    b.ge    9f
    ldrb    w0, [x21, x22]
    cmp     w0, #255
    b.eq    9f
    bl      hero_layer
    tbnz    w0, #31, 2f
    LA      x9, uiheros
    ldr     x0, [x9, x0, lsl #3]
    mov     w1, w19
    mov     w2, w20
    mov     w3, #0
    bl      ui_img
2:  add     w22, w22, #1
    b       1b
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret
