// =====================================================================
//  pesca.S - vara de pesca
//
//  - Vara na mao (tecla 5): clique na agua (ate 6 celulas) para lancar.
//    A boia fica balancando; depois de alguns segundos o peixe morde
//    ("Peixe! Clique!") e voce tem pouco tempo para clicar e fisgar.
//    Se demorar, ele escapa e volta a esperar. Clicar antes recolhe.
//  - O peixe depende da agua: lago (lambari, 1 peixe), mar perto da
//    borda (robalo, 1-2) e mar fundo (atum, 3).
//  - Skill Pesca: espera menor, mais tempo para fisgar e chance de um
//    peixe a mais.
// =====================================================================

#include "comum.h"

    .text
    .p2align 2

// fish_wait -> w0 = quadros ate morder: 4-10 s, ate a metade com a skill
fish_wait:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      rng
    mov     w9, #360
    udiv    w10, w0, w9
    msub    w10, w10, w9, w0
    add     w10, w10, #240
    scvtf   s0, w10
    ldr     s1, [x28, #G_SKFISH]        // * (1 - 0.5 * pesca / 100)
    LA      x9, fconst
    ldr     s2, [x9]
    fmul    s1, s1, s2
    fmov    s2, #1.0
    fsub    s1, s2, s1
    fmul    s0, s0, s1
    fcvtzs  w0, s0
    ldp     x29, x30, [sp], #16
    ret

// fish_click: clique esquerdo no mapa com a vara na mao
    .globl fish_click
fish_click:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     d8, d9, [sp, #16]
    ldr     w9, [x28, #G_FISH]
    cbz     w9, 1f
    cmp     w9, #2
    b.eq    5f
    str     wzr, [x28, #G_FISH]         // esperando: recolhe a linha
    LA      x0, p_reel
    bl      popup
    b       9f
1:  ldr     w9, [x28, #G_HOVOK]         // lancar
    cbz     w9, 9f
    ldr     w9, [x28, #G_WATER]
    cmp     w9, #2
    b.lt    2f
    LA      x0, m_swimfish
    bl      set_msg
    b       9f
2:  ldr     w9, [x28, #G_HOVU]
    scvtf   s8, w9
    ldr     w9, [x28, #G_HOVV]
    scvtf   s9, w9
    LA      x9, fconst
    ldr     s2, [x9, #4]                // 1/64
    fmul    s8, s8, s2
    fmul    s9, s9, s2
    ldr     s2, [x28, #G_PU]            // ate 6 celulas
    ldr     s3, [x28, #G_PV]
    fsub    s2, s8, s2
    fsub    s3, s9, s3
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    fmov    s3, #31.0
    fcmp    s2, s3
    b.le    3f
    LA      x0, m_fishfar
    bl      set_msg
    b       9f
3:  fmov    s0, s8                      // tem que ser agua
    fmov    s1, s9
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    sub     w9, w9, #10
    cmp     w0, w9
    b.lt    4f
    LA      x0, m_notwater
    bl      set_msg
    b       9f
4:  str     s8, [x28, #G_BOBU]
    str     s9, [x28, #G_BOBV]
    mov     w9, #1
    str     w9, [x28, #G_FISH]
    bl      fish_wait
    str     w0, [x28, #G_FISHT]
    LA      x0, p_cast
    bl      popup
    b       9f
5:  bl      fish_catch                  // mordeu: fisgou!
9:  ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// fish_update: um quadro de pesca (chamado por surv_update)
    .globl fish_update
fish_update:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #G_FISH]
    cbz     w9, 9f
    ldr     w10, [x28, #G_HAND]         // largou a vara ou foi dormir
    cmp     w10, #(IT_ROD + 1)
    b.ne    7f
    ldr     w10, [x28, #G_SLEEP]
    cbnz    w10, 7f
    ldr     s0, [x28, #G_BOBU]          // longe demais da boia: solta
    ldr     s1, [x28, #G_BOBV]
    ldr     s2, [x28, #G_PU]
    ldr     s3, [x28, #G_PV]
    fsub    s0, s0, s2
    fsub    s1, s1, s3
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fmov    s1, #31.0
    fadd    s1, s1, s1                  // ~8 celulas
    fcmp    s0, s1
    b.le    1f
    str     wzr, [x28, #G_FISH]
    LA      x0, p_lineoff
    bl      popup
    b       9f
1:  ldr     w10, [x28, #G_FISHT]
    subs    w10, w10, #1
    str     w10, [x28, #G_FISHT]
    b.gt    9f
    cmp     w9, #1
    b.ne    2f
    mov     w9, #2                      // mordeu! tempo para fisgar
    str     w9, [x28, #G_FISH]
    ldr     s0, [x28, #G_SKFISH]        // 50 quadros + 0.4 por ponto
    LA      x9, fconst
    ldr     s1, [x9, #8]
    fmul    s0, s0, s1
    fcvtzs  w10, s0
    add     w10, w10, #50
    str     w10, [x28, #G_FISHT]
    LA      x0, p_bitefish
    bl      popup
    b       9f
2:  mov     w9, #1                      // demorou: escapou
    str     w9, [x28, #G_FISH]
    bl      fish_wait
    str     w0, [x28, #G_FISHT]
    LA      x0, p_escaped
    bl      popup
    b       9f
7:  str     wzr, [x28, #G_FISH]
9:  ldp     x29, x30, [sp], #16
    ret

// fish_catch: qual peixe, quantos, skill e mensagem
fish_catch:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     wzr, [x28, #G_FISH]
    ldr     s0, [x28, #G_BOBU]          // distancia ate a borda do mapa
    ldr     s1, [x28, #G_BOBV]
    fcvtzs  w9, s0
    fcvtzs  w10, s1
    mov     w11, #511
    sub     w12, w11, w9
    sub     w13, w11, w10
    cmp     w9, w10
    csel    w9, w9, w10, lt
    cmp     w9, w12
    csel    w9, w9, w12, lt
    cmp     w9, w13
    csel    w19, w9, w13, lt
    bl      elev_at                     // profundidade
    ldr     w9, [x28, #G_FLOOD]
    sub     w20, w0, w9
    mov     w21, #0                     // 0 lago, 1 mar, 2 mar fundo
    cmp     w19, #W_BORDER
    b.ge    1f
    mov     w21, #1
    cmn     w20, #400
    b.gt    1f
    mov     w21, #2
1:  LA      x9, fishcount               // quantos
    ldrb    w22, [x9, x21]
    cmp     w21, #1                     // mar: 1 ou 2
    b.ne    2f
    bl      rng
    and     w9, w0, #1
    add     w22, w22, w9
2:  bl      rng                         // skill: chance de mais um
    mov     w9, #100
    udiv    w10, w0, w9
    msub    w10, w10, w9, w0
    ldr     s0, [x28, #G_SKFISH]
    fmov    s1, #0.5
    fmul    s0, s0, s1
    fcvtzs  w11, s0
    cmp     w10, w11
    cinc    w22, w22, lt
    mov     w0, #IT_FISH
    mov     w1, w22
    bl      inv_add
    bl      calc_stats
    mov     w0, #SK_FISH
    LA      x9, fconst
    ldr     s0, [x9, #12]
    bl      skill_train
    LA      x0, msgbuf                  // "Pegou um robalo! +2 peixe"
    LA      x1, s_caught
    bl      strcat_cur
    LA      x1, fishnames
    add     x1, x1, x21, lsl #4
    bl      strcat_cur
    LA      x1, s_caught2
    bl      strcat_cur
    mov     w1, w22
    bl      numcat
    LA      x1, s_caught3
    bl      strcat_cur
    LA      x0, msgbuf
    bl      set_msg
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// fish_draw(w0 = escala): linha da mao ate a boia, e a boia balancando
// (mordeu: afunda)
    .globl fish_draw
fish_draw:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
    ldr     w9, [x28, #G_FISH]
    cbz     w9, 9f
    mov     w19, w0
    ldr     s0, [x28, #G_PU]            // ponta da vara (acima da mao)
    ldr     s1, [x28, #G_PV]
    ldr     w0, [x28, #G_PE]
    add     w0, w0, #96
    bl      proj
    mov     w9, #4
    msub    w20, w19, w9, w0
    mov     w21, w1
    ldr     s0, [x28, #G_BOBU]          // boia na superficie
    ldr     s1, [x28, #G_BOBV]
    ldr     w0, [x28, #G_FLOOD]
    bl      proj
    mov     w22, w0
    mov     w23, w1
    mov     w24, w2
    ldr     w9, [x28, #G_FISH]          // balanco: esperando sobe e desce;
    cmp     w9, #2                      // mordeu: afunda
    b.eq    1f
    ldr     w9, [x28, #G_FRAME]
    lsr     w9, w9, #4
    and     w9, w9, #1
    mul     w9, w9, w19
    add     w23, w23, w9
    b       2f
1:  add     w23, w23, w19, lsl #1
    // linha (24 pontos)
2:  mov     w25, #0
3:  cmp     w25, #24
    b.ge    5f
    sub     w0, w22, w20
    mul     w0, w0, w25
    mov     w9, #24
    sdiv    w0, w0, w9
    add     w0, w0, w20
    sub     w1, w23, w21
    mul     w1, w1, w25
    sdiv    w1, w1, w9
    add     w1, w1, w21
    cmp     w0, #SCRW
    b.hs    4f
    cmp     w1, #SCRH
    b.hs    4f
    mov     w9, #SCRW
    madd    w9, w1, w9, w0
    LA      x10, fb
    MOVI32  w11, 0xFFD8D8D8
    str     w11, [x10, w9, uxtw #2]
4:  add     w25, w25, #1
    b       3b
5:  LA      x0, sprites                 // a boia
    add     x0, x0, #(SPR_BOBBER * 128) & 0xFFF
    add     x0, x0, #((SPR_BOBBER * 128) >> 12), lsl #12
    mov     w1, w22
    mov     w2, w23
    mov     w3, w19
    add     w4, w24, #30
    mov     w5, #0
    bl      blit
9:  ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ---------------------------------------------------------------------
    .data
    .p2align 2
fconst:
    .float 0.005                        // 0.5 / 100 (espera menor com a skill)
    .float 0.015625                     // 1/64
    .float 0.4                          // tempo extra para fisgar por ponto
    .float 1.0                          // treino de pesca por peixe

fishcount:
    .byte 1, 1, 3, 0                    // lago, mar (+0/1), mar fundo
    .p2align 4
fishnames:
    .asciz "um lambari"
    .p2align 4
    .asciz "um robalo"
    .p2align 4
    .asciz "um atum"
    .p2align 4

p_cast:      .asciz "Linha na agua..."
p_reel:      .asciz "Recolheu a linha"
p_bitefish:  .asciz "Peixe! Clique!"
p_escaped:   .asciz "Escapou..."
p_lineoff:   .asciz "A linha soltou"
m_swimfish:  .asciz "Nao da para pescar nadando"
m_fishfar:   .asciz "Longe demais: lance ate 6 celulas"
m_notwater:  .asciz "Lance a linha na agua"
s_caught:    .asciz "Pegou "
s_caught2:   .asciz "! +"
s_caught3:   .asciz " peixe"
