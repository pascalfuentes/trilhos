// =====================================================================
//  clima.S - estacoes do ano e clima (sol, nublado, chuva, tempestade,
//  calorao, neve, granizo e enchente)
//
//  - 4 estacoes de 3 dias cada (primavera, verao, outono, inverno).
//  - Dentro da estacao o clima muda a cada poucos minutos, sorteado de
//    uma tabela da estacao (verao tem sol e calorao; inverno tem neve e
//    granizo...). Depois de uma tempestade pode vir uma enchente.
//  - Cada clima entra e sai devagar (20 s): a intensidade G_WK vai de 0
//    a 256 e todos os efeitos sao proporcionais a ela.
//  - weather_update calcula os efeitos (frio extra, fome, visao, fogo,
//    granizo, velocidade, stamina, escuridao, nivel da enchente) e o
//    resto do jogo so le esses numeros em G.
//  - weather_tint puxa a cor do mundo para a cor do clima (sem mexer na
//    neblina preta); weather_fx desenha chuva, neve e granizo direto no
//    framebuffer; weather_overlay faz o clarao do relampago.
// =====================================================================

#include "comum.h"

    .text
    .p2align 2

// weather_reset: comeca a partida com sol
    .globl weather_reset
weather_reset:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     wzr, [x28, #G_SEASON]
    mov     w0, #W_SUN
    MOVI32  w1, 14400                   // 4 min de sol
    mov     w2, #WFADE
    bl      weather_set
    ldp     x29, x30, [sp], #16
    ret

// weather_set(w0 = clima, w1 = duracao, w2 = quanto ja passou)
// (o teste usa para escolher o clima)
    .globl weather_set
weather_set:
    str     w0, [x28, #G_WEATHER]
    str     w1, [x28, #G_WDUR]
    sub     w1, w1, w2
    str     w1, [x28, #G_WTIME]
    str     wzr, [x28, #G_FLASH]
    b       weather_effects

// weather_next: sorteia o proximo clima pela tabela da estacao
weather_next:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    ldr     w19, [x28, #G_WEATHER]      // anterior
    ldr     w9, [x28, #G_SEASON]
    cmp     w19, #W_STORM               // depois de tempestade (fora do
    b.ne    1f                          // inverno): metade das vezes enche
    cmp     w9, #3
    b.eq    1f
    bl      rng
    mov     w20, #W_FLOOD
    tbz     w0, #3, 2f
1:  bl      rng
    and     w10, w0, #15
    ldr     w9, [x28, #G_SEASON]
    LA      x11, seasontab
    add     x11, x11, x9, lsl #4
    ldrb    w20, [x11, x10]
2:  // duracao: entre o minimo e o maximo desse clima (segundos * 60)
    LA      x11, wdur
    add     x11, x11, x20, lsl #2
    ldrh    w12, [x11]                  // minimo (s)
    ldrh    w13, [x11, #2]              // maximo (s)
    sub     w13, w13, w12
    add     w13, w13, #1
    bl      rng
    udiv    w14, w0, w13
    msub    w14, w14, w13, w0
    LA      x11, wdur                   // (rng mexe em registradores)
    add     x11, x11, x20, lsl #2
    ldrh    w12, [x11]
    add     w12, w12, w14
    mov     w13, #60
    mul     w12, w12, w13
    str     w20, [x28, #G_WEATHER]
    str     w12, [x28, #G_WDUR]
    str     w12, [x28, #G_WTIME]
    cmp     w20, w19                    // mudou: avisa
    b.eq    9f
    LA      x0, wmsgs
    add     x0, x0, x20, lsl #6
    bl      set_msg
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// weather_update: um quadro de clima (chamado por surv_update)
    .globl weather_update
weather_update:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    // estacao: muda a cada SEASONDAYS dias
    ldr     w9, [x28, #G_DAY]
    sub     w9, w9, #1
    mov     w10, #SEASONDAYS
    udiv    w9, w9, w10
    and     w9, w9, #3
    ldr     w10, [x28, #G_SEASON]
    cmp     w9, w10
    b.eq    1f
    str     w9, [x28, #G_SEASON]
    LA      x0, seasonmsgs
    add     x0, x0, x9, lsl #5
    bl      set_msg
    // tempo do clima atual
1:  ldr     w9, [x28, #G_WTIME]
    subs    w9, w9, #1
    b.gt    2f
    bl      weather_next
    b       3f
2:  str     w9, [x28, #G_WTIME]
    // relampago na tempestade forte
3:  ldr     w9, [x28, #G_FLASH]
    cbz     w9, 4f
    sub     w9, w9, #1
    str     w9, [x28, #G_FLASH]
4:  ldr     w9, [x28, #G_WEATHER]
    cmp     w9, #W_STORM
    b.ne    5f
    ldr     w9, [x28, #G_WK]
    cmp     w9, #200
    b.lt    5f
    bl      rng
    mov     w9, #420                    // em media a cada 7 s
    udiv    w10, w0, w9
    msub    w10, w10, w9, w0
    cbnz    w10, 5f
    mov     w9, #10
    str     w9, [x28, #G_FLASH]
5:  ldp     x29, x30, [sp], #16
    b       weather_effects

// weather_effects: intensidade, enchente e efeitos do clima atual   folha
weather_effects:
    ldr     w9, [x28, #G_WDUR]
    ldr     w10, [x28, #G_WTIME]
    sub     w11, w9, w10                // quanto ja passou
    cmp     w11, w10
    csel    w11, w11, w10, lt           // m = min(passou, falta)
    mov     w12, #256                   // k = min(256, m * 256 / 20 s)
    lsl     w13, w11, #8
    mov     w14, #WFADE
    udiv    w13, w13, w14
    cmp     w13, w12
    csel    w13, w13, w12, lt
    str     w13, [x28, #G_WK]
    // enchente: sobe no primeiro quarto, desce no ultimo
    mov     w14, #0
    ldr     w15, [x28, #G_WEATHER]
    cmp     w15, #W_FLOOD
    b.ne    1f
    lsr     w9, w9, #2                  // um quarto da duracao
    cmp     w9, #1
    csinc   w9, w9, wzr, ge
    mov     w12, #FLOODMAX
    mul     w14, w11, w12
    udiv    w14, w14, w9
    cmp     w14, w12
    csel    w14, w14, w12, lt
1:  str     w14, [x28, #G_FLOOD]
    // efeitos: valor = 1 + (tabela - 1) * k  (ou tabela * k)
    scvtf   s0, w13
    LA      x9, wconst
    ldr     s1, [x9]                    // 1/256
    fmul    s0, s0, s1                  // k em 0..1
    fmov    s7, #1.0
    LA      x9, wcold
    ldr     s1, [x9, x15, lsl #2]
    fmul    s1, s1, s0
    str     s1, [x28, #G_WCOLD]
    LA      x9, whail
    ldr     s1, [x9, x15, lsl #2]
    fmul    s1, s1, s0
    str     s1, [x28, #G_WHAIL]
    LA      x9, wfood
    ldr     s1, [x9, x15, lsl #2]
    fsub    s1, s1, s7
    fmadd   s1, s1, s0, s7
    str     s1, [x28, #G_WFOOD]
    ldr     w9, [x28, #G_SEASON]        // inverno: mais frio e mais fome
    cmp     w9, #3
    b.ne    71f
    LA      x9, wwinter
    ldr     s2, [x9]
    ldr     s3, [x28, #G_WCOLD]
    fadd    s3, s3, s2
    str     s3, [x28, #G_WCOLD]
    ldr     s2, [x9, #4]
    fmul    s1, s1, s2
    str     s1, [x28, #G_WFOOD]
71:
    LA      x9, wvis
    ldr     s1, [x9, x15, lsl #2]
    fsub    s1, s1, s7
    fmadd   s1, s1, s0, s7
    str     s1, [x28, #G_WVIS]
    LA      x9, wspeed
    ldr     s1, [x9, x15, lsl #2]
    fsub    s1, s1, s7
    fmadd   s1, s1, s0, s7
    str     s1, [x28, #G_WSPEED]
    LA      x9, wstam
    ldr     s1, [x9, x15, lsl #2]
    fsub    s1, s1, s7
    fmadd   s1, s1, s0, s7
    str     s1, [x28, #G_WSTAM]
    LA      x9, wrecov
    ldr     s1, [x9, x15, lsl #2]
    fsub    s1, s1, s7
    fmadd   s1, s1, s0, s7
    str     s1, [x28, #G_WRECOV]
    LA      x9, wfire                   // lenha extra (so com o clima forte)
    ldrb    w10, [x9, x15]
    cmp     w13, #128
    csel    w10, w10, wzr, ge
    str     w10, [x28, #G_WFIRE]
    LA      x9, wdark                   // escuridao
    ldrb    w10, [x9, x15]
    mul     w10, w10, w13
    lsr     w10, w10, #8
    str     w10, [x28, #G_WDARK]
    ret

// weather_status(x0 = cursor): acrescenta "   Primavera, Chuva"
    .globl weather_status
weather_status:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x1, s_wsep
    bl      strcat_cur
    ldr     w9, [x28, #G_SEASON]
    LA      x1, seasonnames
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    LA      x1, s_wcomma
    bl      strcat_cur
    ldr     w9, [x28, #G_WEATHER]
    LA      x1, wnames
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    ldp     x29, x30, [sp], #16
    ret

// weather_overlay: clarao do relampago (interface, 640x360)
    .globl weather_overlay
weather_overlay:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #G_FLASH]         // relampago
    cbz     w9, 2f
    mov     w3, #22
    mul     w3, w3, w9
    mov     w0, #235
    mov     w1, #240
    mov     w2, #255
    bl      setcolor
    mov     w0, #0
    mov     w1, #0
    mov     w2, #640
    mov     w3, #360
    bl      fillrect
2:  ldp     x29, x30, [sp], #16
    ret

// weather_tint: puxa a cor do mundo para a cor do clima (calorao alaranjado,
// neve esbranquicada...). A forca depende do brilho do pixel, entao a
// neblina preta continua preta. Roda nas 8 threads (faixas de colunas).
    .globl weather_tint
weather_tint:
    ldr     w9, [x28, #G_WEATHER]
    LA      x10, wtint
    add     x10, x10, x9, lsl #2
    ldrb    w11, [x10, #3]
    ldr     w12, [x28, #G_WK]
    mul     w11, w11, w12
    lsr     w11, w11, #8
    cbz     w11, 9f
    LA      x13, tintparam
    str     w11, [x13]
    ldr     w14, [x10]
    str     w14, [x13, #4]
    LA      x0, tint_cols
    b       par_cols
9:  ret

// tint_cols(w0 = primeira coluna, w1 = coluna final)   folha
tint_cols:
    LA      x2, tintparam
    ldr     w3, [x2]                    // forca maxima (0..255)
    ldrb    w4, [x2, #4]                // cor do clima
    ldrb    w5, [x2, #5]
    ldrb    w6, [x2, #6]
    LA      x7, fb
    mov     w8, #0                      // y
1:  mov     w9, #SCRW
    mul     w9, w8, w9
    add     w9, w9, w0                  // primeiro pixel da linha nesta faixa
    sub     w10, w1, w0                 // quantos
2:  ldr     w11, [x7, w9, uxtw #2]
    ubfx    w12, w11, #16, #8           // r
    ubfx    w13, w11, #8, #8            // g
    and     w14, w11, #255              // b
    cmp     w12, w13                    // brilho = max(r, g, b)
    csel    w15, w12, w13, hi
    cmp     w15, w14
    csel    w15, w15, w14, hi
    mul     w15, w15, w3                // forca deste pixel
    lsr     w15, w15, #8
    sub     w16, w4, w12                // cada canal anda na direcao da cor
    mul     w16, w16, w15
    add     w12, w12, w16, asr #8
    sub     w16, w5, w13
    mul     w16, w16, w15
    add     w13, w13, w16, asr #8
    sub     w16, w6, w14
    mul     w16, w16, w15
    add     w14, w14, w16, asr #8
    orr     w11, w14, w13, lsl #8
    orr     w11, w11, w12, lsl #16
    orr     w11, w11, #0xFF000000
    str     w11, [x7, w9, uxtw #2]
    add     w9, w9, #1
    subs    w10, w10, #1
    b.ne    2b
    add     w8, w8, #1
    cmp     w8, #SCRH
    b.lt    1b
    ret

// ---------------------------------------------------------------------
//  Particulas: chuva, neve e granizo, desenhadas no framebuffer
//  (sem estado: a posicao de cada uma vem do numero dela e do quadro)
// ---------------------------------------------------------------------

// fx_pix(w0 = x, w1 = y, w2 = cor): mistura 50% com o que ja esta la  folha
fx_pix:
    cmp     w0, #SCRW
    b.hs    9f
    cmp     w1, #SCRH
    b.hs    9f
    mov     w9, #SCRW
    madd    w9, w1, w9, w0
    LA      x10, fb
    ldr     w11, [x10, w9, uxtw #2]
    lsr     w11, w11, #1
    and     w11, w11, #0x7F7F7F7F
    lsr     w12, w2, #1
    and     w12, w12, #0x7F7F7F7F
    add     w11, w11, w12
    orr     w11, w11, #0xFF000000
    str     w11, [x10, w9, uxtw #2]
9:  ret

    .globl weather_fx
weather_fx:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     x27, [sp, #80]
    ldr     w9, [x28, #G_WEATHER]
    LA      x10, wpart
    ldrb    w19, [x10, x9]              // tipo de particula
    cbz     w19, fx_ret
    LA      x10, partcfg                // quantas, vy, vx, comprimento, tamanho
    add     x10, x10, x19, lsl #3
    ldrh    w20, [x10]
    ldrb    w21, [x10, #2]
    ldrb    w22, [x10, #3]
    ldrb    w23, [x10, #4]
    ldrb    w24, [x10, #5]
    ldr     w9, [x28, #G_WK]            // menos particulas enquanto entra/sai
    mul     w20, w20, w9
    lsr     w20, w20, #8
    ldr     w25, [x28, #G_FRAME]
    mov     w26, #0
fx_loop:
    cmp     w26, w20
    b.ge    fx_ret
    MOVI32  w9, 0x9E3779B1              // posicao inicial = hash do numero
    mul     w9, w26, w9
    eor     w9, w9, w9, lsr #15
    MOVI32  w10, 0x85EBCA6B
    mul     w9, w9, w10
    eor     w9, w9, w9, lsr #13
    and     w10, w9, #0xFFFF
    mov     w11, #SCRW
    mul     w10, w10, w11
    lsr     w10, w10, #16               // x0
    lsr     w12, w9, #16
    mov     w11, #(SCRH + 32)
    mul     w12, w12, w11
    lsr     w12, w12, #16               // y0
    madd    w12, w25, w21, w12          // y = (y0 + quadro*vy) mod (SCRH+32) - 16
    udiv    w13, w12, w11
    msub    w12, w13, w11, w12
    sub     w27, w12, #16
    madd    w10, w25, w22, w10          // x = x0 + quadro*vx
    cmp     w19, #3
    b.ne    1f
    add     w13, w25, w26, lsl #3       // neve: balanca de um lado para o outro
    and     w13, w13, #127
    subs    w13, w13, #64
    cneg    w13, w13, mi
    add     w10, w10, w13, lsr #3
1:  mov     w11, #SCRW
    udiv    w13, w10, w11
    msub    w3, w13, w11, w10           // x na tela
    cmp     w19, #3
    b.hs    fx_dot
    MOVI32  w15, 0xFFB4C8DC             // chuva: risco inclinado
    mov     w13, #0
2:  cmp     w13, w23
    b.ge    fx_next
    mul     w0, w13, w22
    udiv    w0, w0, w21
    add     w0, w3, w0
    add     w1, w27, w13
    mov     w2, w15
    bl      fx_pix
    add     w13, w13, #1
    b       2b
fx_dot:
    MOVI32  w15, 0xFFFFFFFF             // neve: branca; granizo: gelo
    cmp     w19, #4
    b.ne    3f
    MOVI32  w15, 0xFFDCE6F0
3:  mov     w13, #0
4:  cmp     w13, w24
    b.ge    fx_next
    mov     w14, #0
5:  cmp     w14, w24
    b.ge    6f
    add     w0, w3, w14
    add     w1, w27, w13
    mov     w2, w15
    bl      fx_pix
    add     w14, w14, #1
    b       5b
6:  add     w13, w13, #1
    b       4b
fx_next:
    add     w26, w26, #1
    b       fx_loop
fx_ret:
    ldr     x27, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// ---------------------------------------------------------------------
//  Dados
// ---------------------------------------------------------------------
    .data
    .p2align 2
wconst:
    .float 0.00390625                   // 1/256
// inverno: frio extra por quadro (mesmo de sol) e fome x1,25
wwinter:
    .float 0.016, 1.25

// por clima: sol, nublado, chuva, tempestade, calorao, neve, granizo, enchente
wcold:  .float 0, 0, 0.006, 0.010, -0.0075, 0.016, 0.006, 0.006
whail:  .float 0, 0, 0, 0, 0, 0, 0.004, 0
wfood:  .float 1, 1, 1, 1, 2, 1.5, 1, 1
wvis:   .float 1, 0.95, 0.85, 0.6, 1, 0.8, 0.8, 0.85
wspeed: .float 1, 1, 1, 0.9, 1, 0.8, 1, 1
wstam:  .float 1, 1, 1, 1.2, 1.5, 1.2, 1, 1
wrecov: .float 1, 1, 1, 1, 0.5, 1, 1, 1
wfire:  .byte 0, 0, 1, 3, 0, 1, 1, 1     // lenha extra por quadro (+1 = 2x mais rapido)
wdark:  .byte 0, 40, 70, 130, 0, 30, 60, 70
wpart:  .byte 0, 0, 1, 2, 0, 3, 4, 1     // 1 chuva, 2 chuva forte, 3 neve, 4 granizo
    .p2align 2
// cor do clima no mundo: r, g, b, forca maxima (0..255)
wtint:  .byte 0, 0, 0, 0
        .byte 110, 120, 135, 60
        .byte 70, 90, 115, 70
        .byte 40, 50, 75, 90
        .byte 255, 170, 60, 80
        .byte 240, 245, 255, 120
        .byte 190, 200, 215, 60
        .byte 70, 95, 120, 70
// duracao (segundos): minimo, maximo
    .p2align 1
wdur:   .hword 180, 360,  120, 240,  180, 300,  120, 180
        .hword 180, 360,  240, 360,   60, 120,  240, 240
// particulas: quantas, vy, vx, comprimento, tamanho (8 bytes cada)
    .p2align 3
partcfg:
    .hword 0
    .byte 0, 0, 0, 0, 0, 0
    .hword 420                          // 1 chuva
    .byte 14, 2, 10, 1, 0, 0
    .hword 760                          // 2 tempestade
    .byte 20, 7, 14, 1, 0, 0
    .hword 380                          // 3 neve
    .byte 2, 0, 0, 3, 0, 0
    .hword 200                          // 4 granizo
    .byte 16, 1, 0, 3, 0, 0

// o que pode cair em cada estacao (16 sorteios)
seasontab:
    .byte 0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3     // primavera
    .byte 0,0,0,0,0,0,0,4,4,4,4,4,1,1,3,3     // verao
    .byte 1,1,1,1,1,2,2,2,2,2,2,3,3,3,0,0     // outono
    .byte 5,5,5,5,5,5,5,1,1,1,1,6,6,6,0,0     // inverno

    .p2align 4
    .globl wnames
wnames:
    .asciz "Sol"
    .p2align 4
    .asciz "Nublado"
    .p2align 4
    .asciz "Chuva"
    .p2align 4
    .asciz "Tempestade"
    .p2align 4
    .asciz "Calorao"
    .p2align 4
    .asciz "Neve"
    .p2align 4
    .asciz "Granizo"
    .p2align 4
    .asciz "Enchente"
    .p2align 4
seasonnames:
    .asciz "Primavera"
    .p2align 4
    .asciz "Verao"
    .p2align 4
    .asciz "Outono"
    .p2align 4
    .asciz "Inverno"
    .p2align 5
seasonmsgs:
    .asciz "Chegou a primavera"
    .p2align 5
    .asciz "Chegou o verao: sol e calorao"
    .p2align 5
    .asciz "Chegou o outono: muita chuva"
    .p2align 5
    .asciz "Chegou o inverno: neve e frio"
    .p2align 6
wmsgs:
    .asciz "O sol apareceu"
    .p2align 6
    .asciz "O ceu fechou"
    .p2align 6
    .asciz "Comecou a chover: esfria e o fogo queima mais rapido"
    .p2align 6
    .asciz "Tempestade! Fique perto do fogo ou no abrigo"
    .p2align 6
    .asciz "Calorao: mais fome e cansa mais rapido"
    .p2align 6
    .asciz "Esta nevando: muito frio e anda devagar"
    .p2align 6
    .asciz "Granizo! Procure um abrigo"
    .p2align 6
    .asciz "Enchente! A agua esta subindo"
    .p2align 6
    .p2align 2
tintparam: .word 0, 0                   // forca e cor (para as threads)
s_wsep:   .asciz "   "
s_wcomma: .asciz ", "
