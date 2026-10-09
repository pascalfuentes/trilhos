// =====================================================================
//  ferrovia.S - trilhos, estacoes, sinais e trens (estilo OpenTTD)
//  Por enquanto so carga de passageiros.
//
//  Rede:  nos (pontos com um eixo) ligados por trilhos (curvas de Bezier
//         cubicas). Cada trilho e amostrado a cada ~1/4 de celula; as
//         amostras guardam posicao, tangente e elevacao do terreno.
//         Um trilho sai de um no por um dos dois "lados" do eixo; um trem
//         que chega por um lado so pode continuar pelo lado oposto. Varios
//         trilhos no mesmo lado formam um desvio (agulha).
//  Sinais: sinais de bloco. Os sinais cortam os trilhos em pedacos; os
//         pedacos ligados entre si formam blocos (union-find). Um sinal
//         fica vermelho se o bloco depois dele tem trem.
//  Trens: andam pela distancia ao longo dos trilhos. Para escolher o
//         caminho, cada estacao tem uma tabela com a distancia ate ela a
//         partir de cada trilho/sentido (Bellman-Ford), refeita quando a
//         rede muda.
// =====================================================================

#include "comum.h"

    .text
    .p2align 2

// =====================================================================
//  Auxiliares
// =====================================================================

// set_msg(x0 = texto): mostra uma mensagem por 3 segundos
    .globl set_msg
set_msg:
    str     x0, [x28, #G_MSG]
    mov     w9, #180
    str     w9, [x28, #G_MSGT]
    ret

// proj(s0 = u, s1 = v em celulas, w0 = elevacao) -> w0 = x, w1 = y, w2 = prof.
// folha: usa x9-x12, x16, s0-s3
proj:
    fsub    s2, s0, s1
    fadd    s3, s0, s1
    FC      s1, F_64
    fmul    s2, s2, s1
    fmul    s3, s3, s1
    fcvtzs  w2, s3                      // profundidade (u+v)*64
    fcvtzs  w9, s2                      // X = (u-v)*64
    asr     w10, w2, #1
    sub     w10, w10, w0                // Y = (u+v)*32 - e
    ldr     w11, [x28, #G_CX]
    sub     w9, w9, w11
    ldr     w12, [x28, #G_Z256]
    mul     w9, w9, w12
    asr     w9, w9, #12
    add     w0, w9, #640
    ldr     w11, [x28, #G_CY]
    sub     w10, w10, w11
    mul     w10, w10, w12
    asr     w10, w10, #12
    add     w1, w10, #360
    ret

// projoff(x0 = amostra, s0 = deslocamento lateral, w1 = elevacao extra)
// folha: usa x0-x2, x9-x12, x16, s0-s4
projoff:
    ldr     s1, [x0]
    ldr     s2, [x0, #4]
    ldr     s3, [x0, #12]
    ldr     s4, [x0, #16]
    fmsub   s1, s4, s0, s1              // u - tv*w
    fmadd   s2, s3, s0, s2              // v + tu*w
    ldr     w9, [x0, #8]
    add     w0, w9, w1
    fmov    s0, s1
    fmov    s1, s2
    b       proj

// elev_at(s0 = u, s1 = v) -> w0 elevacao (fora do mapa: -2000)
// usa x0-x7, x16, s2, s3
elev_at:
    FC      s2, F_64
    fmul    s3, s0, s2
    fcvtzs  w0, s3
    fmul    s3, s1, s2
    fcvtzs  w1, s3
    MOVI32  w2, 32640
    cmp     w0, w2
    b.hs    1f
    cmp     w1, w2
    b.hs    1f
    b       sample_elev
1:  mov     w0, #-2000
    ret

// shade(w0 = cor, w1 = fator 0..256) -> w0   (usa w9-w12)
shade:
    ubfx    w9, w0, #16, #8
    mul     w9, w9, w1
    lsr     w9, w9, #8
    ubfx    w10, w0, #8, #8
    mul     w10, w10, w1
    lsr     w10, w10, #8
    and     w11, w0, #255
    mul     w11, w11, w1
    lsr     w11, w11, #8
    orr     w0, w11, w10, lsl #8
    orr     w0, w0, w9, lsl #16
    orr     w0, w0, #0xFF000000
    ret

// =====================================================================
//  Rasterizacao com z-buffer
// =====================================================================

// fill_tri(w0..w5 = x0,y0,x1,y1,x2,y2, w6 = cor, w7 = profundidade)
// triangulo cheio por funcoes de aresta. folha: usa x0-x17
fill_tri:
    sub     sp, sp, #48
    sub     w8, w2, w0
    sub     w9, w5, w1
    mul     w8, w8, w9
    sub     w9, w4, w0
    sub     w10, w3, w1
    msub    w8, w9, w10, w8             // area * 2
    cbz     w8, ft_ret
    cmp     w8, #0
    b.gt    1f
    mov     w9, w2                      // garante orientacao positiva
    mov     w2, w4
    mov     w4, w9
    mov     w9, w3
    mov     w3, w5
    mov     w5, w9
1:  cmp     w0, w2
    csel    w13, w0, w2, lt
    cmp     w13, w4
    csel    w13, w13, w4, lt            // minx
    cmp     w0, w2
    csel    w14, w0, w2, gt
    cmp     w14, w4
    csel    w14, w14, w4, gt            // maxx
    cmp     w1, w3
    csel    w15, w1, w3, lt
    cmp     w15, w5
    csel    w15, w15, w5, lt            // miny
    cmp     w1, w3
    csel    w9, w1, w3, gt
    cmp     w9, w5
    csel    w9, w9, w5, gt              // maxy
    cmp     w13, #0
    csel    w13, wzr, w13, lt
    mov     w10, #(SCRW - 1)
    cmp     w14, w10
    csel    w14, w10, w14, gt
    cmp     w15, #0
    csel    w15, wzr, w15, lt
    mov     w10, #(SCRH - 1)
    cmp     w9, w10
    csel    w9, w10, w9, gt
    cmp     w13, w14
    b.gt    ft_ret
    cmp     w15, w9
    b.gt    ft_ret
    str     w9, [sp]                    // maxy
    sub     w10, w3, w5                 // A12
    sub     w11, w4, w2                 // B12
    sub     w12, w5, w1                 // A20
    sub     w9, w0, w4                  // B20
    str     w11, [sp, #4]
    str     w9, [sp, #8]
    sub     w9, w1, w3                  // A01
    sub     w11, w2, w0                 // B01
    str     w11, [sp, #12]
    ldr     w11, [sp, #4]               // r12 = B12*(miny-y1) + A12*(minx-x1)
    sub     w17, w15, w3
    mul     w17, w17, w11
    sub     w11, w13, w2
    madd    w17, w10, w11, w17
    ldr     w11, [sp, #8]               // r20 = B20*(miny-y2) + A20*(minx-x2)
    sub     w16, w15, w5
    mul     w16, w16, w11
    sub     w11, w13, w4
    madd    w16, w12, w11, w16
    ldr     w11, [sp, #12]              // r01 = B01*(miny-y0) + A01*(minx-x0)
    sub     w3, w15, w1
    mul     w3, w3, w11
    sub     w11, w13, w0
    madd    w4, w9, w11, w3
    mov     w2, w17
    mov     w3, w16
    mov     w8, w10                     // A12
    mov     w10, w9                     // A01
    mov     w9, w12                     // A20
    str     w13, [sp, #16]              // minx
    mov     w1, w15                     // y
    mov     w11, w6                     // cor
    mov     w12, w7                     // profundidade
    LA      x16, fb
    LA      x17, zb
ft_row:
    mov     w5, w2
    mov     w6, w3
    mov     w7, w4
    ldr     w0, [sp, #16]
ft_px:
    orr     w13, w5, w6
    orr     w13, w13, w7
    tbnz    w13, #31, 2f
    add     w13, w0, w1, lsl #10
    add     w13, w13, w1, lsl #8
    ldrh    w15, [x17, w13, uxtw #1]
    sub     w15, w15, w12
    cmp     w15, #64
    b.gt    2f
    str     w11, [x16, w13, uxtw #2]
    strh    w12, [x17, w13, uxtw #1]
2:  add     w5, w5, w8
    add     w6, w6, w9
    add     w7, w7, w10
    add     w0, w0, #1
    cmp     w0, w14
    b.le    ft_px
    ldr     w13, [sp, #4]
    add     w2, w2, w13
    ldr     w13, [sp, #8]
    add     w3, w3, w13
    ldr     w13, [sp, #12]
    add     w4, w4, w13
    add     w1, w1, #1
    ldr     w13, [sp]
    cmp     w1, w13
    b.le    ft_row
ft_ret:
    add     sp, sp, #48
    ret

// line_z(w0 x0, w1 y0, w2 x1, w3 y1, w4 cor, w5 profundidade, w6 espessura)
// folha: usa x0-x17
line_z:
    // descarta linhas totalmente fora da tela
    cmn     w0, #64
    b.ge    1f
    cmn     w2, #64
    b.lt    lz_ret
1:  mov     w7, #(SCRW + 64)
    cmp     w0, w7
    b.le    2f
    cmp     w2, w7
    b.gt    lz_ret
2:  cmn     w1, #64
    b.ge    3f
    cmn     w3, #64
    b.lt    lz_ret
3:  mov     w7, #(SCRH + 64)
    cmp     w1, w7
    b.le    4f
    cmp     w3, w7
    b.gt    lz_ret
4:  sub     w2, w2, w0                  // dx
    sub     w3, w3, w1                  // dy
    cmp     w2, #0
    cneg    w7, w2, lt
    cmp     w3, #0
    cneg    w8, w3, lt
    cmp     w7, w8
    csel    w7, w7, w8, gt              // n
    cmp     w7, #1
    b.ge    5f
    mov     w7, #1
5:  lsl     w2, w2, #16
    sdiv    w2, w2, w7                  // incx
    lsl     w3, w3, #16
    sdiv    w3, w3, w7                  // incy
    lsl     w0, w0, #16
    add     w0, w0, #0x8000
    lsl     w1, w1, #16
    add     w1, w1, #0x8000
    add     w7, w7, #1                  // pontos
    lsr     w8, w6, #1
    LA      x16, fb
    LA      x17, zb
lz_pt:
    asr     w12, w0, #16
    sub     w12, w12, w8                // x inicial do bloco
    asr     w13, w1, #16
    sub     w13, w13, w8                // y inicial do bloco
    mov     w10, #0
lz_y:
    add     w9, w13, w10
    cmp     w9, #SCRH
    b.hs    lz_ny
    mov     w11, #0
lz_x:
    add     w14, w12, w11
    cmp     w14, #SCRW
    b.hs    lz_nx
    add     w14, w14, w9, lsl #10
    add     w14, w14, w9, lsl #8
    ldrh    w15, [x17, w14, uxtw #1]
    sub     w15, w15, w5
    cmp     w15, #48
    b.gt    lz_nx
    str     w4, [x16, w14, uxtw #2]
    strh    w5, [x17, w14, uxtw #1]
lz_nx:
    add     w11, w11, #1
    cmp     w11, w6
    b.lt    lz_x
lz_ny:
    add     w10, w10, #1
    cmp     w10, w6
    b.lt    lz_y
    add     w0, w0, w2
    add     w1, w1, w3
    subs    w7, w7, #1
    b.ne    lz_pt
lz_ret:
    ret

// =====================================================================
//  Curvas: Bezier e amostragem
// =====================================================================

// compute_curve(w0 = no A, s0/s1 = ponto P, w1 = no final M ou -1)
// -> w0 = 0 ok / 1 curto / 2 longo / 3 curva fechada.  preenche `cur`
// folha: usa x9-x11, x16, s0-s1, s16-s28
compute_curve:
    LA      x9, nodes
    add     x9, x9, x0, lsl #6
    ldr     s16, [x9]
    ldr     s17, [x9, #4]
    ldr     s18, [x9, #8]
    ldr     s19, [x9, #12]
    fsub    s20, s0, s16
    fsub    s21, s1, s17
    fmul    s22, s20, s20
    fmadd   s22, s21, s21, s22
    fsqrt   s22, s22                    // comprimento da corda
    FC      s23, F_MINLEN
    fcmp    s22, s23
    b.lt    cc_e1
    FC      s23, F_MAXLEN
    fcmp    s22, s23
    b.gt    cc_e2
    fdiv    s20, s20, s22
    fdiv    s21, s21, s22               // direcao da corda
    fmul    s23, s18, s18
    fmadd   s23, s19, s19, s23
    fcmp    s23, #0.0
    b.ne    1f
    fmov    s18, s20                    // no sem eixo: sai reto
    fmov    s19, s21
    mov     w10, #1
    b       2f
1:  fmul    s23, s18, s20
    fmadd   s23, s19, s21, s23
    mov     w10, #1
    fcmp    s23, #0.0
    b.ge    11f
    mov     w10, #-1                    // sai pelo outro lado do no
    fneg    s18, s18
    fneg    s19, s19
    fneg    s23, s23
11: FC      s24, F_MINDOT
    fcmp    s23, s24
    b.lt    cc_e3
2:  LA      x11, cur
    str     w10, [x11, #40]
    str     s22, [x11, #44]
    str     s18, [x11, #48]
    str     s19, [x11, #52]
    tbnz    w1, #31, cc_refl
    LA      x9, nodes
    add     x9, x9, x1, lsl #6
    ldr     s24, [x9, #8]
    ldr     s25, [x9, #12]
    fmul    s26, s24, s24
    fmadd   s26, s25, s25, s26
    fcmp    s26, #0.0
    b.eq    cc_refl
    fmul    s26, s24, s20
    fmadd   s26, s25, s21, s26
    fcmp    s26, #0.0
    b.ge    3f
    fneg    s24, s24
    fneg    s25, s25
    fneg    s26, s26
3:  FC      s27, F_MINDOT
    fcmp    s26, s27
    b.lt    cc_e3
    b       4f
cc_refl:                                // arco simetrico: reflete t0 na corda
    fmul    s26, s20, s18
    fmadd   s26, s21, s19, s26
    fadd    s26, s26, s26
    fmul    s24, s20, s26
    fsub    s24, s24, s18
    fmul    s25, s21, s26
    fsub    s25, s25, s19
4:  str     s24, [x11, #32]
    str     s25, [x11, #36]
    FC      s27, F_THIRD
    fmul    s27, s22, s27               // alcas = corda/3
    str     s16, [x11]
    str     s17, [x11, #4]
    fmadd   s28, s18, s27, s16
    str     s28, [x11, #8]
    fmadd   s28, s19, s27, s17
    str     s28, [x11, #12]
    fmsub   s28, s24, s27, s0
    str     s28, [x11, #16]
    fmsub   s28, s25, s27, s1
    str     s28, [x11, #20]
    str     s0, [x11, #24]
    str     s1, [x11, #28]
    mov     w0, #0
    ret
cc_e1:
    mov     w0, #1
    ret
cc_e2:
    mov     w0, #2
    ret
cc_e3:
    mov     w0, #3
    ret

// make_samples(x0 = bezier, x1 = destino, w2 = max)
// -> w0 = n amostras (0 = falhou), s0 = comprimento, s1 = passo, w1 = agua?
make_samples:
    stp     x29, x30, [sp, #-128]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
    stp     d8, d9, [sp, #80]
    stp     d10, d11, [sp, #96]
    stp     d12, d13, [sp, #112]
    mov     x19, x0
    mov     x20, x1
    mov     w21, w2
    // 1) 65 pontos da curva e comprimento acumulado
    mov     w12, #0
    fmov    s13, wzr
ms_pt:
    LA      x9, tmpu
    LA      x10, tmpv
    LA      x11, tmpc
    scvtf   s0, w12
    FC      s1, F_INV64
    fmul    s0, s0, s1                  // t
    fmov    s1, #1.0
    fsub    s1, s1, s0                  // 1-t
    fmul    s2, s1, s1
    fmul    s2, s2, s1                  // b0
    fmov    s7, #3.0
    fmul    s3, s1, s1
    fmul    s3, s3, s0
    fmul    s3, s3, s7                  // b1
    fmul    s4, s0, s0
    fmul    s4, s4, s1
    fmul    s4, s4, s7                  // b2
    fmul    s5, s0, s0
    fmul    s5, s5, s0                  // b3
    ldr     s6, [x19]
    fmul    s6, s6, s2
    ldr     s7, [x19, #8]
    fmadd   s6, s7, s3, s6
    ldr     s7, [x19, #16]
    fmadd   s6, s7, s4, s6
    ldr     s7, [x19, #24]
    fmadd   s6, s7, s5, s6              // u
    ldr     s10, [x19, #4]
    fmul    s10, s10, s2
    ldr     s7, [x19, #12]
    fmadd   s10, s7, s3, s10
    ldr     s7, [x19, #20]
    fmadd   s10, s7, s4, s10
    ldr     s7, [x19, #28]
    fmadd   s10, s7, s5, s10            // v
    str     s6, [x9, x12, lsl #2]
    str     s10, [x10, x12, lsl #2]
    cbz     w12, 1f
    sub     w13, w12, #1
    ldr     s7, [x9, x13, lsl #2]
    fsub    s7, s6, s7
    ldr     s11, [x10, x13, lsl #2]
    fsub    s11, s10, s11
    fmul    s7, s7, s7
    fmadd   s7, s11, s11, s7
    fsqrt   s7, s7
    fadd    s13, s13, s7
1:  str     s13, [x11, x12, lsl #2]
    add     w12, w12, #1
    cmp     w12, #65
    b.lt    ms_pt
    fmov    s8, s13                     // comprimento total
    // 2) amostras igualmente espacadas
    FC      s0, F_STEP
    fdiv    s0, s8, s0
    frintp  s0, s0
    fcvtzs  w25, s0
    mov     w9, #1
    cmp     w25, #1
    csel    w25, w9, w25, lt
    scvtf   s0, w25
    fdiv    s9, s8, s0                  // passo
    add     w25, w25, #1                // numero de amostras
    cmp     w25, w21
    b.gt    ms_fail
    mov     w24, #0
    mov     w22, #0
    mov     w23, #0
ms_samp:
    scvtf   s10, w22
    fmul    s10, s10, s9                // distancia desta amostra
    LA      x11, tmpc
2:  cmp     w23, #63
    b.ge    3f
    add     w9, w23, #1
    ldr     s0, [x11, x9, lsl #2]
    fcmp    s0, s10
    b.ge    3f
    mov     w23, w9
    b       2b
3:  ldr     s0, [x11, x23, lsl #2]
    add     w9, w23, #1
    ldr     s1, [x11, x9, lsl #2]
    fsub    s2, s1, s0
    fsub    s3, s10, s0
    fcmp    s2, #0.0
    b.gt    4f
    fmov    s3, wzr
    fmov    s2, #1.0
4:  fdiv    s11, s3, s2
    fmov    s4, wzr
    fmax    s11, s11, s4
    fmov    s4, #1.0
    fmin    s11, s11, s4                // fracao no intervalo
    LA      x12, tmpu
    ldr     s0, [x12, x23, lsl #2]
    ldr     s1, [x12, x9, lsl #2]
    fsub    s5, s1, s0
    fmadd   s12, s5, s11, s0            // u
    LA      x12, tmpv
    ldr     s0, [x12, x23, lsl #2]
    ldr     s1, [x12, x9, lsl #2]
    fsub    s6, s1, s0
    fmadd   s13, s6, s11, s0            // v
    fmul    s0, s5, s5
    fmadd   s0, s6, s6, s0
    fsqrt   s0, s0
    fcmp    s0, #0.0
    b.gt    5f
    fmov    s0, #1.0
5:  fdiv    s5, s5, s0
    fdiv    s6, s6, s0                  // tangente unitaria
    add     x13, x20, x22, lsl #5
    str     s12, [x13]
    str     s13, [x13, #4]
    str     s5, [x13, #12]
    str     s6, [x13, #16]
    scvtf   s0, w23
    fadd    s0, s0, s11
    FC      s1, F_INV64
    fmul    s0, s0, s1
    str     s0, [x13, #20]              // parametro t da Bezier
    fmov    s0, s12
    fmov    s1, s13
    bl      elev_at
    add     x13, x20, x22, lsl #5
    str     w0, [x13, #8]
    tbz     w0, #31, 6f
    mov     w24, #1                     // passa pela agua
6:  add     w22, w22, #1
    cmp     w22, w25
    b.lt    ms_samp
    mov     w0, w25
    fmov    s0, s8
    fmov    s1, s9
    mov     w1, w24
    b       ms_ret
ms_fail:
    mov     w0, #0
    mov     w1, #0
ms_ret:
    ldp     d12, d13, [sp, #112]
    ldp     d10, d11, [sp, #96]
    ldp     d8, d9, [sp, #80]
    ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #128
    ret

// seg_point(w0 = trilho, s0 = distancia) -> s0 u, s1 v, w0 e, s2/s3 tangente,
// s4 = t.   folha: usa x9-x13, s5-s7
seg_point:
    LA      x9, segs
    add     x9, x9, x0, lsl #7
    ldr     s5, [x9, #36]
    fdiv    s6, s0, s5
    fcvtzs  w10, s6
    ldr     w11, [x9, #28]
    sub     w11, w11, #2
    cmp     w10, #0
    csel    w10, wzr, w10, lt
    cmp     w10, w11
    csel    w10, w11, w10, gt
    scvtf   s7, w10
    fsub    s6, s6, s7
    fmov    s7, wzr
    fmax    s6, s6, s7
    fmov    s7, #1.0
    fmin    s6, s6, s7
    ldr     w12, [x9, #24]
    add     w12, w12, w10
    LA      x13, samples
    add     x13, x13, x12, lsl #5
    ldr     s0, [x13]
    ldr     s1, [x13, #32]
    fsub    s1, s1, s0
    fmadd   s0, s1, s6, s0
    ldr     s1, [x13, #4]
    ldr     s7, [x13, #36]
    fsub    s7, s7, s1
    fmadd   s1, s7, s6, s1
    ldr     w10, [x13, #8]
    ldr     w11, [x13, #40]
    sub     w11, w11, w10
    scvtf   s7, w11
    fmul    s7, s7, s6
    fcvtzs  w11, s7
    add     w0, w10, w11
    ldr     s2, [x13, #12]
    ldr     s3, [x13, #16]
    ldr     s4, [x13, #20]
    ldr     s7, [x13, #52]
    fsub    s7, s7, s4
    fmadd   s4, s7, s6, s4
    ret

// seg_bbox(w0 = trilho): caixa envolvente das amostras.  folha
seg_bbox:
    LA      x9, segs
    add     x9, x9, x0, lsl #7
    ldr     w10, [x9, #24]
    ldr     w11, [x9, #28]
    LA      x12, samples
    add     x12, x12, x10, lsl #5
    ldr     s0, [x12]
    ldr     s1, [x12, #4]
    fmov    s2, s0
    fmov    s3, s1
1:  ldr     s4, [x12]
    ldr     s5, [x12, #4]
    fmin    s0, s0, s4
    fmax    s2, s2, s4
    fmin    s1, s1, s5
    fmax    s3, s3, s5
    add     x12, x12, #32
    subs    w11, w11, #1
    b.ne    1b
    str     s0, [x9, #96]
    str     s1, [x9, #100]
    str     s2, [x9, #104]
    str     s3, [x9, #108]
    ret

// clear_objects_near(s0 = u, s1 = v, s2 = raio^2): remove arvores/casas
// folha: usa x9-x14, s3-s7
clear_objects_near:
    ldr     w9, [x28, #G_NOBJ]
    LA      x10, objs
    FC      s7, F_INV64
1:  cbz     w9, 3f
    ldrb    w11, [x10, #6]
    cmp     w11, #8
    b.hs    2f
    ldrh    w12, [x10]
    scvtf   s3, w12
    fmul    s3, s3, s7
    fsub    s3, s3, s0
    ldrh    w12, [x10, #2]
    scvtf   s4, w12
    fmul    s4, s4, s7
    fsub    s4, s4, s1
    fmul    s3, s3, s3
    fmadd   s3, s4, s4, s3
    fcmp    s3, s2
    b.ge    2f
    mov     w11, #255
    strb    w11, [x10, #6]
2:  add     x10, x10, #8
    sub     w9, w9, #1
    b       1b
3:  ret

// clear_objects_along(w0 = trilho): limpa o caminho do trilho
// folha: usa x9-x15, s0-s7
clear_objects_along:
    LA      x9, segs
    add     x9, x9, x0, lsl #7
    ldr     s0, [x9, #96]
    ldr     s1, [x9, #100]
    ldr     s2, [x9, #104]
    ldr     s3, [x9, #108]
    fmov    s4, #1.0
    fsub    s0, s0, s4
    fsub    s1, s1, s4
    fadd    s2, s2, s4
    fadd    s3, s3, s4
    ldr     w13, [x9, #24]
    ldr     w14, [x9, #28]
    LA      x15, samples
    add     x15, x15, x13, lsl #5       // primeira amostra
    ldr     w9, [x28, #G_NOBJ]
    LA      x10, objs
1:  cbz     w9, 9f
    ldrb    w11, [x10, #6]
    cmp     w11, #8
    b.hs    8f
    ldrh    w12, [x10]
    scvtf   s4, w12
    FC      s7, F_INV64
    fmul    s4, s4, s7                  // u do objeto
    ldrh    w12, [x10, #2]
    scvtf   s5, w12
    fmul    s5, s5, s7                  // v do objeto
    fcmp    s4, s0
    b.lt    8f
    fcmp    s4, s2
    b.gt    8f
    fcmp    s5, s1
    b.lt    8f
    fcmp    s5, s3
    b.gt    8f
    mov     x12, x15
    mov     w13, w14
    FC      s7, F_CLEAR2
2:  ldr     s6, [x12]
    fsub    s6, s6, s4
    fmul    s6, s6, s6
    ldr     s16, [x12, #4]
    fsub    s16, s16, s5
    fmadd   s6, s16, s16, s6
    fcmp    s6, s7
    b.lt    7f
    add     x12, x12, #32
    subs    w13, w13, #1
    b.ne    2b
    b       8f
7:  mov     w11, #255
    strb    w11, [x10, #6]
8:  add     x10, x10, #8
    sub     w9, w9, #1
    b       1b
9:  ret

// =====================================================================
//  Nos
// =====================================================================

// node_new(s0 u, s1 v, s2/s3 eixo) -> w0 id (-1 cheio).  usa x9-x10
node_new:
    ldr     w0, [x28, #G_NNODE]
    cmp     w0, #MAXNODE
    b.hs    9f
    add     w9, w0, #1
    str     w9, [x28, #G_NNODE]
    LA      x10, nodes
    add     x10, x10, x0, lsl #6
    str     s0, [x10]
    str     s1, [x10, #4]
    str     s2, [x10, #8]
    str     s3, [x10, #12]
    str     wzr, [x10, #16]
    mov     w9, #1
    str     w9, [x10, #52]
    ret
9:  mov     w0, #-1
    ret

// node_attach(w0 no, w1 trilho)   usa x9-x11
node_attach:
    LA      x10, nodes
    add     x10, x10, x0, lsl #6
    ldr     w9, [x10, #16]
    cmp     w9, #8
    b.hs    9f
    add     x11, x10, #20
    str     w1, [x11, x9, lsl #2]
    add     w9, w9, #1
    str     w9, [x10, #16]
9:  ret

// node_detach(w0 no, w1 trilho)   usa x9-x13
node_detach:
    LA      x10, nodes
    add     x10, x10, x0, lsl #6
    ldr     w9, [x10, #16]
    add     x11, x10, #20
    mov     w12, #0
1:  cmp     w12, w9
    b.ge    3f
    ldr     w13, [x11, x12, lsl #2]
    cmp     w13, w1
    b.eq    2f
    add     w12, w12, #1
    b       1b
2:  sub     w9, w9, #1
    ldr     w13, [x11, x9, lsl #2]
    str     w13, [x11, x12, lsl #2]
    str     w9, [x10, #16]
    cbnz    w9, 3f
    str     wzr, [x10, #52]             // no sem trilhos some
3:  ret

// node_replace(w0 no, w1 antigo, w2 novo)   usa x9-x13
node_replace:
    LA      x10, nodes
    add     x10, x10, x0, lsl #6
    ldr     w9, [x10, #16]
    add     x11, x10, #20
    mov     w12, #0
1:  cmp     w12, w9
    b.ge    2f
    ldr     w13, [x11, x12, lsl #2]
    cmp     w13, w1
    b.ne    3f
    str     w2, [x11, x12, lsl #2]
3:  add     w12, w12, #1
    b       1b
2:  ret

// find_node_near(s0 u, s1 v, w0 = no ignorado) -> w0 (-1)
// folha: usa x9-x13, x16, s2-s5
find_node_near:
    mov     w13, w0
    FC      s5, F_SNAP2
    mov     w0, #-1
    ldr     w9, [x28, #G_NNODE]
    LA      x10, nodes
    mov     w11, #0
1:  cmp     w11, w9
    b.ge    9f
    ldr     w12, [x10, #52]
    cbz     w12, 2f
    cmp     w11, w13
    b.eq    2f
    ldr     s2, [x10]
    ldr     s3, [x10, #4]
    fsub    s2, s2, s0
    fsub    s3, s3, s1
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    fcmp    s2, s5
    b.ge    2f
    fmov    s5, s2
    mov     w0, w11
2:  add     x10, x10, #64
    add     w11, w11, #1
    b       1b
9:  ret

// find_seg_near(s0 u, s1 v) -> w0 trilho (-1), s0 = distancia no trilho,
// s1 = distancia^2.   folha: usa x9-x16, s2-s7
find_seg_near:
    fmov    s6, s0
    fmov    s7, s1
    FC      s5, F_SEGHIT2
    mov     w0, #-1
    fmov    s4, wzr
    ldr     w9, [x28, #G_NSEG]
    LA      x10, segs
    mov     w11, #0
fs_seg:
    cmp     w11, w9
    b.ge    fs_done
    ldr     w12, [x10, #16]
    cbz     w12, fs_next
    fmov    s3, #1.0
    ldr     s2, [x10, #96]
    fsub    s2, s2, s3
    fcmp    s6, s2
    b.lt    fs_next
    ldr     s2, [x10, #104]
    fadd    s2, s2, s3
    fcmp    s6, s2
    b.gt    fs_next
    ldr     s2, [x10, #100]
    fsub    s2, s2, s3
    fcmp    s7, s2
    b.lt    fs_next
    ldr     s2, [x10, #108]
    fadd    s2, s2, s3
    fcmp    s7, s2
    b.gt    fs_next
    ldr     w12, [x10, #24]
    ldr     w13, [x10, #28]
    LA      x14, samples
    add     x14, x14, x12, lsl #5
    mov     w15, #0
1:  cmp     w15, w13
    b.ge    fs_next
    ldr     s2, [x14]
    ldr     s3, [x14, #4]
    fsub    s2, s2, s6
    fsub    s3, s3, s7
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    fcmp    s2, s5
    b.ge    2f
    fmov    s5, s2
    mov     w0, w11
    ldr     s3, [x10, #36]
    scvtf   s4, w15
    fmul    s4, s4, s3
2:  add     x14, x14, #32
    add     w15, w15, #1
    b       1b
fs_next:
    add     x10, x10, #128
    add     w11, w11, #1
    b       fs_seg
fs_done:
    fmov    s0, s4
    fmov    s1, s5
    ret

// =====================================================================
//  Construcao de trilhos
// =====================================================================

// build_segment(w0 = no A, w1 = no M ou -1, s0/s1 = ponto final)
// -> w0 = trilho, ou negativo (codigo de erro)
build_segment:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    mov     w19, w0
    mov     w20, w1
    fmov    s8, s0
    fmov    s9, s1
    bl      compute_curve
    cbz     w0, 1f
    neg     w0, w0
    b       bs_ret
1:  ldr     w21, [x28, #G_NSEG]
    cmp     w21, #MAXSEG
    b.hs    bs_full
    ldr     w9, [x28, #G_NNODE]
    mov     w10, #(MAXNODE - 2)
    cmp     w9, w10
    b.hs    bs_full
    LA      x9, nodes
    add     x9, x9, x19, lsl #6
    ldr     w10, [x9, #16]
    cmp     w10, #8
    b.hs    bs_full6
    tbnz    w20, #31, 2f
    LA      x9, nodes
    add     x9, x9, x20, lsl #6
    ldr     w10, [x9, #16]
    cmp     w10, #8
    b.hs    bs_full6
2:  LA      x0, cur
    ldr     w9, [x28, #G_NSAMP]
    LA      x1, samples
    add     x1, x1, x9, lsl #5
    MOVI32  w2, MAXSAMP
    sub     w2, w2, w9
    bl      make_samples
    cbz     w0, bs_full
    cbnz    w1, bs_water
    // grava o trilho
    LA      x22, segs
    add     x22, x22, x21, lsl #7
    str     w19, [x22]
    LA      x9, cur
    ldr     w10, [x9, #40]
    str     w10, [x22, #8]              // lado em A
    mov     w10, #1
    str     w10, [x22, #16]             // vivo
    str     wzr, [x22, #20]
    ldr     w10, [x28, #G_NSAMP]
    str     w10, [x22, #24]
    str     w0, [x22, #28]
    add     w10, w10, w0
    str     w10, [x28, #G_NSAMP]
    str     s0, [x22, #32]
    str     s1, [x22, #36]
    mov     w10, #-1
    str     w10, [x22, #112]            // sem estacao
    ldp     x10, x11, [x9]
    stp     x10, x11, [x22, #64]
    ldp     x10, x11, [x9, #16]
    stp     x10, x11, [x22, #80]
    add     w10, w21, #1
    str     w10, [x28, #G_NSEG]
    // eixo do no A (se ainda nao tinha)
    LA      x9, nodes
    add     x9, x9, x19, lsl #6
    ldr     s2, [x9, #8]
    ldr     s3, [x9, #12]
    fmul    s4, s2, s2
    fmadd   s4, s3, s3, s4
    fcmp    s4, #0.0
    b.ne    3f
    LA      x10, cur
    ldr     s2, [x10, #48]
    ldr     s3, [x10, #52]
    str     s2, [x9, #8]
    str     s3, [x9, #12]
3:  LA      x10, cur
    ldr     s2, [x10, #32]
    ldr     s3, [x10, #36]
    tbz     w20, #31, 4f
    fmov    s0, s8                      // no novo no ponto final
    fmov    s1, s9
    bl      node_new
    mov     w20, w0
4:  LA      x9, nodes
    add     x9, x9, x20, lsl #6
    ldr     s4, [x9, #8]
    ldr     s5, [x9, #12]
    LA      x10, cur
    ldr     s2, [x10, #32]
    ldr     s3, [x10, #36]
    fmul    s6, s4, s4
    fmadd   s6, s5, s5, s6
    fcmp    s6, #0.0
    b.ne    5f
    str     s2, [x9, #8]
    str     s3, [x9, #12]
    fmov    s4, s2
    fmov    s5, s3
5:  fmul    s6, s2, s4
    fmadd   s6, s3, s5, s6
    mov     w10, #-1
    mov     w11, #1
    fcmp    s6, #0.0
    csel    w10, w10, w11, ge           // lado em M
    str     w20, [x22, #4]
    str     w10, [x22, #12]
    mov     w0, w19
    mov     w1, w21
    bl      node_attach
    mov     w0, w20
    mov     w1, w21
    bl      node_attach
    mov     w0, w21
    bl      seg_bbox
    mov     w0, w21
    bl      clear_objects_along
    mov     w9, #1
    str     w9, [x28, #G_NETDIRTY]
    mov     w0, w21
    b       bs_ret
bs_full:
    mov     w0, #-5
    b       bs_ret
bs_full6:
    mov     w0, #-6
    b       bs_ret
bs_water:
    mov     w0, #-4
bs_ret:
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// train_uses_seg(w0 = trilho) -> w0 = 1 se algum trem esta nele.  folha
train_uses_seg:
    ldr     w9, [x28, #G_NTRAIN]
    LA      x10, trains
1:  cbz     w9, 8f
    ldr     w11, [x10]
    cbz     w11, 3f
    ldr     w12, [x10, #104]
    add     x13, x10, #72
2:  cbz     w12, 3f
    ldr     w14, [x13], #4
    lsr     w14, w14, #1
    cmp     w14, w0
    b.eq    9f
    sub     w12, w12, #1
    b       2b
3:  add     x10, x10, #128
    sub     w9, w9, #1
    b       1b
8:  mov     w0, #0
    ret
9:  mov     w0, #1
    ret

// split_segment(w0 = trilho, s0 = distancia) -> w0 = no no ponto (ou erro)
split_segment:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     d8, d9, [sp, #64]
    stp     d10, d11, [sp, #80]
    mov     w19, w0
    fmov    s8, s0
    LA      x20, segs
    add     x20, x20, x19, lsl #7
    // perto das pontas: usa o no da ponta
    FC      s1, F_EDGE
    fcmp    s8, s1
    b.ge    1f
    ldr     w0, [x20]
    b       sp_ret
1:  ldr     s2, [x20, #32]
    fsub    s2, s2, s1
    fcmp    s8, s2
    b.le    2f
    ldr     w0, [x20, #4]
    b       sp_ret
2:  ldr     w9, [x20, #112]
    tbnz    w9, #31, 3f
    mov     w0, #-7                     // tem estacao
    b       sp_ret
3:  mov     w0, w19
    bl      train_uses_seg
    cbz     w0, 4f
    mov     w0, #-8                     // tem trem
    b       sp_ret
4:  ldr     w9, [x28, #G_NSEG]
    cmp     w9, #(MAXSEG - 1)
    b.hs    sp_full
    ldr     w9, [x28, #G_NNODE]
    mov     w10, #(MAXNODE - 1)
    cmp     w9, w10
    b.hs    sp_full
    ldr     w9, [x28, #G_NSAMP]
    ldr     w10, [x20, #28]
    add     w9, w9, w10
    add     w9, w9, #64
    MOVI32  w10, MAXSAMP
    cmp     w9, w10
    b.hs    sp_full
    // parametro t no ponto de corte
    mov     w0, w19
    fmov    s0, s8
    bl      seg_point
    fmov    s10, s4
    // de Casteljau: divide a Bezier em duas
    add     x9, x20, #64
    LA      x10, cur                    // metade 1
    LA      x11, cur2                   // metade 2
    mov     w12, #0
5:  ldr     s16, [x9, x12, lsl #2]      // P0
    add     w13, w12, #2
    ldr     s17, [x9, x13, lsl #2]      // P1
    add     w13, w12, #4
    ldr     s18, [x9, x13, lsl #2]      // P2
    add     w13, w12, #6
    ldr     s19, [x9, x13, lsl #2]      // P3
    fsub    s20, s17, s16
    fmadd   s20, s20, s10, s16          // P01
    fsub    s21, s18, s17
    fmadd   s21, s21, s10, s17          // P12
    fsub    s22, s19, s18
    fmadd   s22, s22, s10, s18          // P23
    fsub    s23, s21, s20
    fmadd   s23, s23, s10, s20          // P012
    fsub    s24, s22, s21
    fmadd   s24, s24, s10, s21          // P123
    fsub    s25, s24, s23
    fmadd   s25, s25, s10, s23          // P0123
    str     s16, [x10, x12, lsl #2]
    add     w13, w12, #2
    str     s20, [x10, x13, lsl #2]
    add     w13, w12, #4
    str     s23, [x10, x13, lsl #2]
    add     w13, w12, #6
    str     s25, [x10, x13, lsl #2]
    str     s25, [x11, x12, lsl #2]
    add     w13, w12, #2
    str     s24, [x11, x13, lsl #2]
    add     w13, w12, #4
    str     s22, [x11, x13, lsl #2]
    add     w13, w12, #6
    str     s19, [x11, x13, lsl #2]
    add     w12, w12, #1
    cmp     w12, #2
    b.lt    5b
    // eixo do novo no: direcao da curva no corte
    ldr     s0, [x11]
    ldr     s1, [x11, #4]
    ldr     s2, [x11, #8]
    ldr     s3, [x11, #12]
    fsub    s2, s2, s0
    fsub    s3, s3, s1
    fmul    s4, s2, s2
    fmadd   s4, s3, s3, s4
    fsqrt   s4, s4
    fcmp    s4, #0.0
    b.gt    6f
    fmov    s4, #1.0
6:  fdiv    s2, s2, s4
    fdiv    s3, s3, s4
    bl      node_new
    mov     w21, w0                     // novo no N
    // metade 1 continua sendo o trilho k
    LA      x0, cur
    ldr     w9, [x28, #G_NSAMP]
    LA      x1, samples
    add     x1, x1, x9, lsl #5
    MOVI32  w2, MAXSAMP
    sub     w2, w2, w9
    bl      make_samples
    ldr     w9, [x28, #G_NSAMP]
    str     w9, [x20, #24]
    str     w0, [x20, #28]
    add     w9, w9, w0
    str     w9, [x28, #G_NSAMP]
    str     s0, [x20, #32]
    str     s1, [x20, #36]
    fmov    s11, s0                     // comprimento da metade 1
    LA      x9, cur
    ldp     x10, x11, [x9]
    stp     x10, x11, [x20, #64]
    ldp     x10, x11, [x9, #16]
    stp     x10, x11, [x20, #80]
    ldr     w23, [x20, #4]              // antigo no b
    ldr     w24, [x20, #12]             // antigo lado b
    str     w21, [x20, #4]
    mov     w9, #-1
    str     w9, [x20, #12]
    // metade 2 vira um trilho novo
    ldr     w22, [x28, #G_NSEG]
    add     w9, w22, #1
    str     w9, [x28, #G_NSEG]
    LA      x0, cur2
    ldr     w9, [x28, #G_NSAMP]
    LA      x1, samples
    add     x1, x1, x9, lsl #5
    MOVI32  w2, MAXSAMP
    sub     w2, w2, w9
    bl      make_samples
    LA      x10, segs
    add     x10, x10, x22, lsl #7
    ldr     w9, [x28, #G_NSAMP]
    str     w9, [x10, #24]
    str     w0, [x10, #28]
    add     w9, w9, w0
    str     w9, [x28, #G_NSAMP]
    str     s0, [x10, #32]
    str     s1, [x10, #36]
    str     w21, [x10]
    mov     w9, #1
    str     w9, [x10, #8]
    str     w23, [x10, #4]
    str     w24, [x10, #12]
    str     w9, [x10, #16]
    str     wzr, [x10, #20]
    mov     w9, #-1
    str     w9, [x10, #112]
    LA      x9, cur2
    ldp     x11, x12, [x9]
    stp     x11, x12, [x10, #64]
    ldp     x11, x12, [x9, #16]
    stp     x11, x12, [x10, #80]
    mov     w0, w23
    mov     w1, w19
    mov     w2, w22
    bl      node_replace
    mov     w0, w21
    mov     w1, w19
    bl      node_attach
    mov     w0, w21
    mov     w1, w22
    bl      node_attach
    mov     w0, w19
    bl      seg_bbox
    mov     w0, w22
    bl      seg_bbox
    // sinais depois do corte passam para o trilho novo
    ldr     w9, [x28, #G_NSIG]
    LA      x10, signals
7:  cbz     w9, 8f
    ldr     w11, [x10]
    cmp     w11, w19
    b.ne    71f
    ldr     s0, [x10, #4]
    fcmp    s0, s11
    b.le    71f
    fsub    s0, s0, s11
    str     s0, [x10, #4]
    str     w22, [x10]
71: add     x10, x10, #16
    sub     w9, w9, #1
    b       7b
8:  mov     w9, #1
    str     w9, [x28, #G_NETDIRTY]
    mov     w0, w21
    b       sp_ret
sp_full:
    mov     w0, #-5
sp_ret:
    ldp     d10, d11, [sp, #80]
    ldp     d8, d9, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #112
    ret

// =====================================================================
//  Ferramentas
// =====================================================================

    .globl rail_reset
rail_reset:
    str     wzr, [x28, #G_NNODE]
    str     wzr, [x28, #G_NSEG]
    str     wzr, [x28, #G_NST]
    str     wzr, [x28, #G_NSIG]
    str     wzr, [x28, #G_NTRAIN]
    str     wzr, [x28, #G_NSAMP]
    str     wzr, [x28, #G_PAX]
    str     wzr, [x28, #G_TOOL]
    str     wzr, [x28, #G_PAUSE]
    str     wzr, [x28, #G_NPIECE]
    mov     w9, #-1
    str     w9, [x28, #G_CHAIN]
    str     w9, [x28, #G_TRSEL]
    mov     w9, #1
    str     w9, [x28, #G_NETDIRTY]
    ret

// tool_select(w0 = ferramenta 1..5): liga, ou desliga se ja estava ligada
    .globl tool_select
tool_select:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w0
    bl      tool_cancel
    ldr     w9, [x28, #G_TOOL]
    cmp     w9, w19
    csel    w19, wzr, w19, eq
    str     w19, [x28, #G_TOOL]
    LA      x9, toolhints
    ldr     x0, [x9, x19, lsl #3]
    cbz     x0, 1f
    bl      set_msg
1:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// tool_cancel: termina o trilho em construcao e a montagem de trem
    .globl tool_cancel
tool_cancel:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #G_CHAIN]
    tbnz    w9, #31, 1f
    LA      x10, nodes
    add     x10, x10, x9, lsl #6
    ldr     w11, [x10, #16]
    cbnz    w11, 2f
    str     wzr, [x10, #52]             // ponto inicial sem trilho: some
2:  mov     w9, #-1
    str     w9, [x28, #G_CHAIN]
1:  bl      train_finish
    ldp     x29, x30, [sp], #16
    ret

// tool_click: clique esquerdo no mapa com a ferramenta atual
    .globl tool_click
tool_click:
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 9f
    ldr     w9, [x28, #G_HOVU]
    scvtf   s0, w9
    FC      s2, F_INV64
    fmul    s0, s0, s2
    ldr     w9, [x28, #G_HOVV]
    scvtf   s1, w9
    fmul    s1, s1, s2
    ldr     w9, [x28, #G_TOOL]
    cmp     w9, #1
    b.eq    track_click
    cmp     w9, #2
    b.eq    station_click
    cmp     w9, #3
    b.eq    signal_click
    cmp     w9, #4
    b.eq    train_click
    cmp     w9, #5
    b.eq    demolish_click
9:  ret

// ---- trilho ------------------------------------------------------------
track_click:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     d8, d9, [sp, #32]
    fmov    s8, s0
    fmov    s9, s1
    ldr     w19, [x28, #G_CHAIN]
    tbz     w19, #31, tk_cont
    // primeiro ponto: no existente, meio de um trilho, ou ponto novo
    mov     w0, #-1
    bl      find_node_near
    tbz     w0, #31, tk_setchain
    fmov    s0, s8
    fmov    s1, s9
    bl      find_seg_near
    tbnz    w0, #31, tk_new
    bl      split_segment
    tbnz    w0, #31, tk_err
    b       tk_setchain
tk_new:
    fmov    s0, s8
    fmov    s1, s9
    fmov    s2, wzr
    fmov    s3, wzr
    bl      node_new
    tbz     w0, #31, tk_setchain
    mov     w0, #-5
    b       tk_err
tk_setchain:
    str     w0, [x28, #G_CHAIN]
    LA      x0, m_next
    bl      set_msg
    b       tk_done
tk_cont:
    mov     w0, w19
    fmov    s0, s8
    fmov    s1, s9
    bl      find_node_near
    mov     w20, w0
    tbz     w20, #31, 1f
    fmov    s0, s8
    fmov    s1, s9
    bl      find_seg_near
    tbnz    w0, #31, 2f
    bl      split_segment
    tbnz    w0, #31, tk_err
    cmp     w0, w19
    b.eq    2f
    mov     w20, w0
    b       1f
2:  mov     w20, #-1
1:  tbnz    w20, #31, 3f
    LA      x9, nodes                   // liga exatamente no no
    add     x9, x9, x20, lsl #6
    ldr     s8, [x9]
    ldr     s9, [x9, #4]
3:  mov     w0, w19
    mov     w1, w20
    fmov    s0, s8
    fmov    s1, s9
    bl      build_segment
    tbnz    w0, #31, tk_err
    tbz     w20, #31, 4f
    LA      x9, segs
    add     x9, x9, x0, lsl #7
    ldr     w9, [x9, #4]
    str     w9, [x28, #G_CHAIN]         // continua a partir do fim
    LA      x0, m_built
    bl      set_msg
    b       tk_done
4:  mov     w9, #-1
    str     w9, [x28, #G_CHAIN]
    LA      x0, m_connected
    bl      set_msg
    b       tk_done
tk_err:
    neg     w0, w0
    LA      x9, errmsgs
    ldr     x0, [x9, x0, lsl #3]
    bl      set_msg
tk_done:
    ldp     d8, d9, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ---- estacao -----------------------------------------------------------
station_click:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     d8, d9, [sp, #64]
    stp     d10, d11, [sp, #80]
    bl      find_seg_near
    tbz     w0, #31, 1f
    LA      x0, m_clicktrack
    b       sc_msg
1:  mov     w19, w0
    fmov    s8, s0
    LA      x20, segs
    add     x20, x20, x19, lsl #7
    ldr     w9, [x20, #112]
    tbnz    w9, #31, 2f
    LA      x0, m_hasstation
    b       sc_msg
2:  ldr     s9, [x20, #32]              // comprimento do trilho
    FC      s0, F_STMIN
    fcmp    s9, s0
    b.ge    3f
    LA      x0, m_shorttrack
    b       sc_msg
3:  ldr     w21, [x28, #G_NST]
    cmp     w21, #MAXST
    b.lo    4f
    LA      x0, m_limit
    b       sc_msg
4:  FC      s0, F_STHALF                // plataforma de 5 celulas
    fsub    s10, s8, s0
    fadd    s11, s8, s0
    fmov    s1, #0.125
    fcmp    s10, s1
    b.ge    5f
    fmov    s10, s1
    FC      s0, F_STLEN
    fadd    s11, s10, s0
5:  fsub    s2, s9, s1
    fcmp    s11, s2
    b.le    6f
    fmov    s11, s2
    FC      s0, F_STLEN
    fsub    s10, s11, s0
6:  add     w9, w21, #1
    str     w9, [x28, #G_NST]
    LA      x22, stations
    add     x22, x22, x21, lsl #6
    str     w19, [x22]
    str     s10, [x22, #4]
    str     s11, [x22, #8]
    str     wzr, [x22, #12]
    str     wzr, [x22, #28]
    mov     w9, #1
    str     w9, [x22, #36]
    str     w21, [x20, #112]
    // centro
    fadd    s0, s10, s11
    fmov    s1, #0.5
    fmul    s0, s0, s1
    mov     w0, w19
    bl      seg_point
    str     s0, [x22, #16]
    str     s1, [x22, #20]
    str     w0, [x22, #24]
    fmov    s8, s0
    fmov    s9, s1
    // limpa arvores em volta do predio da estacao
    FC      s4, F_STOFF
    fmsub   s0, s3, s4, s8
    fmadd   s1, s2, s4, s9
    fmov    s2, #4.0
    bl      clear_objects_near
    // cidades atendidas e cidade mais proxima
    mov     w23, #0                     // mascara
    mov     w24, #-1                    // mais proxima
    FC      s10, F_INF
    ldr     w9, [x28, #G_NTOWNS]
    mov     w10, #0
7:  cmp     w10, w9
    b.ge    8f
    LA      x11, towns
    add     x11, x11, x10, lsl #6
    ldr     w12, [x11]
    scvtf   s0, w12
    fsub    s0, s0, s8
    ldr     w12, [x11, #4]
    scvtf   s1, w12
    fsub    s1, s1, s9
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    ldr     w12, [x11, #44]
    add     w12, w12, #10
    mul     w12, w12, w12
    scvtf   s1, w12
    fcmp    s0, s1
    b.gt    71f
    mov     w13, #1
    lsl     w13, w13, w10
    orr     w23, w23, w13
71: fcmp    s0, s10
    b.ge    72f
    fmov    s10, s0
    mov     w24, w10
72: add     w10, w10, #1
    b       7b
8:  str     w23, [x22, #32]
    str     w24, [x22, #40]
    // nome: cidade mais proxima (+ numero se ja houver outra)
    add     x0, x22, #44
    tbnz    w24, #31, 9f
    LA      x1, towns
    add     x1, x1, x24, lsl #6
    add     x1, x1, #12
    mov     w9, #16
81: ldrb    w10, [x1], #1
    cbz     w10, 82f
    strb    w10, [x0], #1
    subs    w9, w9, #1
    b.ne    81b
82: strb    wzr, [x0]
    mov     w9, #0                      // outras estacoes desta cidade
    mov     w10, #0
83: cmp     w10, w21
    b.ge    84f
    LA      x11, stations
    add     x11, x11, x10, lsl #6
    ldr     w12, [x11, #36]
    cbz     w12, 85f
    ldr     w12, [x11, #40]
    cmp     w12, w24
    b.ne    85f
    add     w9, w9, #1
85: add     w10, w10, #1
    b       83b
84: cbz     w9, 10f
    mov     w10, #32
    strb    w10, [x0], #1
    add     w1, w9, #1
    bl      numcat
    b       10f
9:  LA      x1, s_estacao
    bl      strcat_cur
    add     w1, w21, #1
    bl      numcat
10: mov     w9, #1
    str     w9, [x28, #G_NETDIRTY]
    LA      x0, m_station
sc_msg:
    bl      set_msg
    ldp     d10, d11, [sp, #80]
    ldp     d8, d9, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// ---- sinal -------------------------------------------------------------
signal_click:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     d8, d9, [sp, #32]
    bl      find_seg_near
    tbz     w0, #31, 1f
    LA      x0, m_clicktrack
    b       sg_msg
1:  mov     w19, w0
    fmov    s8, s0
    // ja existe um sinal aqui? entao gira o sentido
    ldr     w9, [x28, #G_NSIG]
    LA      x10, signals
    mov     w20, #0                     // sinais neste trilho
2:  cbz     w9, 4f
    ldr     w11, [x10]
    cmp     w11, w19
    b.ne    3f
    add     w20, w20, #1
    ldr     s0, [x10, #4]
    fsub    s0, s0, s8
    fabs    s0, s0
    fmov    s1, #1.0
    fcmp    s0, s1
    b.ge    3f
    ldr     w11, [x10, #8]
    add     w11, w11, #1
    cmp     w11, #3
    csel    w11, wzr, w11, ge
    str     w11, [x10, #8]
    mov     w9, #1
    str     w9, [x28, #G_NETDIRTY]
    LA      x9, sigmsgs
    ldr     x0, [x9, x11, lsl #3]
    b       sg_msg
3:  add     x10, x10, #16
    sub     w9, w9, #1
    b       2b
4:  cmp     w20, #4
    b.lo    5f
    LA      x0, m_toomanysig
    b       sg_msg
5:  ldr     w9, [x28, #G_NSIG]
    cmp     w9, #MAXSIG
    b.lo    6f
    LA      x0, m_limit
    b       sg_msg
6:  add     w10, w9, #1
    str     w10, [x28, #G_NSIG]
    LA      x10, signals
    add     x10, x10, x9, lsl #4
    str     w19, [x10]
    str     s8, [x10, #4]
    str     wzr, [x10, #8]
    str     wzr, [x10, #12]
    mov     w9, #1
    str     w9, [x28, #G_NETDIRTY]
    LA      x0, m_signal
sg_msg:
    bl      set_msg
    ldp     d8, d9, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// find_station_at(s0 u, s1 v) -> w0 estacao (-1).  folha
find_station_at:
    mov     w0, #-1
    FC      s5, F_STHIT2
    ldr     w9, [x28, #G_NST]
    LA      x10, stations
    mov     w11, #0
1:  cmp     w11, w9
    b.ge    9f
    ldr     w12, [x10, #36]
    cbz     w12, 2f
    ldr     s2, [x10, #16]
    fsub    s2, s2, s0
    ldr     s3, [x10, #20]
    fsub    s3, s3, s1
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    fcmp    s2, s5
    b.ge    2f
    fmov    s5, s2
    mov     w0, w11
2:  add     x10, x10, #64
    add     w11, w11, #1
    b       1b
9:  ret

// ---- trem --------------------------------------------------------------
train_click:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    bl      find_station_at
    tbz     w0, #31, 1f
    LA      x0, m_clickstation
    b       tr_msg
1:  mov     w19, w0
    ldr     w9, [x28, #G_TRSEL]
    tbz     w9, #31, tr_add
    // cria um trem novo parado na estacao
    ldr     w9, [x28, #G_NTRAIN]
    LA      x10, trains
    mov     w11, #0
2:  cmp     w11, w9
    b.ge    3f
    ldr     w12, [x10]
    cbz     w12, 4f                     // reaproveita vaga
    add     x10, x10, #128
    add     w11, w11, #1
    b       2b
3:  cmp     w9, #MAXTRAIN
    b.lo    31f
    LA      x0, m_limit
    b       tr_msg
31: add     w9, w9, #1
    str     w9, [x28, #G_NTRAIN]
4:  mov     w20, w11
    LA      x12, stations
    add     x12, x12, x19, lsl #6
    mov     w9, #4
    str     w9, [x10]                   // montando
    ldr     w9, [x12]
    str     w9, [x10, #4]               // trilho
    str     wzr, [x10, #8]              // sentido
    ldr     s0, [x12, #8]
    str     s0, [x10, #12]              // cabeca na ponta da plataforma
    str     wzr, [x10, #16]
    mov     w13, #1
    str     w13, [x10, #20]
    str     wzr, [x10, #24]
    str     w19, [x10, #28]
    str     wzr, [x10, #60]
    str     wzr, [x10, #64]
    mov     w13, #120
    str     w13, [x10, #68]
    lsl     w9, w9, #1
    str     w9, [x10, #72]
    mov     w13, #1
    str     w13, [x10, #104]
    mov     w13, #-2
    str     w13, [x10, #108]
    mov     x19, x10
    bl      rng
    and     w0, w0, #3
    str     w0, [x19, #112]
    str     w20, [x28, #G_TRSEL]
    LA      x0, m_trainorders
    b       tr_msg
tr_add:
    LA      x10, trains
    add     x10, x10, x9, lsl #7
    ldr     w11, [x10, #20]
    cmp     w11, #8
    b.hs    9f
    add     x12, x10, #28
    sub     w13, w11, #1
    ldr     w13, [x12, x13, lsl #2]
    cmp     w13, w19
    b.eq    9f
    str     w19, [x12, x11, lsl #2]
    add     w11, w11, #1
    str     w11, [x10, #20]
    LA      x0, m_orderadded
    b       tr_msg
9:  LA      x0, m_ordersame
tr_msg:
    bl      set_msg
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// train_finish: fecha a lista de paradas do trem em montagem
train_finish:
    ldr     w9, [x28, #G_TRSEL]
    tbnz    w9, #31, 9f
    mov     w10, #-1
    str     w10, [x28, #G_TRSEL]
    LA      x10, trains
    add     x10, x10, x9, lsl #7
    ldr     w11, [x10, #20]
    cmp     w11, #2
    b.lt    1f
    mov     w11, #2                     // embarca e parte
    str     w11, [x10]
    mov     w11, #40
    str     w11, [x10, #60]
    str     wzr, [x10, #24]
    LA      x0, m_trainstart
    b       set_msg
1:  str     wzr, [x10]
    LA      x0, m_needtwo
    b       set_msg
9:  ret

// ---- demolir -----------------------------------------------------------
demolish_click:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    stp     d10, d11, [sp, #64]
    fmov    s8, s0
    fmov    s9, s1
    // 1) trem
    mov     w19, #0
dm_tr:
    ldr     w9, [x28, #G_NTRAIN]
    cmp     w19, w9
    b.ge    dm_sig
    LA      x20, trains
    add     x20, x20, x19, lsl #7
    ldr     w9, [x20]
    cbz     w9, 2f
    mov     w21, #0
1:  scvtf   s0, w21
    FC      s1, F_VSP
    fmul    s0, s0, s1
    FC      s1, F_HALF
    fadd    s0, s0, s1
    mov     x0, x20
    bl      walk_back
    bl      seg_point
    fsub    s0, s0, s8
    fsub    s1, s1, s9
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    FC      s1, F_TRHIT2
    fcmp    s0, s1
    b.lt    dm_deltrain
    add     w21, w21, #1
    cmp     w21, #4
    b.lt    1b
2:  add     w19, w19, #1
    b       dm_tr
dm_deltrain:
    str     wzr, [x20]
    ldr     w9, [x28, #G_TRSEL]
    cmp     w9, w19
    b.ne    3f
    mov     w9, #-1
    str     w9, [x28, #G_TRSEL]
3:  LA      x0, m_deltrain
    b       dm_msg
    // 2) sinal
dm_sig:
    mov     w19, #0
4:  ldr     w9, [x28, #G_NSIG]
    cmp     w19, w9
    b.ge    dm_st
    LA      x20, signals
    add     x20, x20, x19, lsl #4
    ldr     w0, [x20]
    tbnz    w0, #31, 5f
    ldr     s0, [x20, #4]
    bl      seg_point
    fsub    s0, s0, s8
    fsub    s1, s1, s9
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    FC      s1, F_SIGHIT2
    fcmp    s0, s1
    b.ge    5f
    mov     w9, #-1
    str     w9, [x20]
    mov     w9, #1
    str     w9, [x28, #G_NETDIRTY]
    LA      x0, m_delsig
    b       dm_msg
5:  add     w19, w19, #1
    b       4b
    // 3) estacao
dm_st:
    fmov    s0, s8
    fmov    s1, s9
    bl      find_station_at
    tbnz    w0, #31, dm_seg
    mov     w19, w0
    LA      x20, stations
    add     x20, x20, x19, lsl #6
    str     wzr, [x20, #36]
    ldr     w9, [x20]
    LA      x10, segs
    add     x10, x10, x9, lsl #7
    mov     w9, #-1
    str     w9, [x10, #112]
    // tira a estacao das rotas dos trens
    ldr     w9, [x28, #G_NTRAIN]
    LA      x10, trains
6:  cbz     w9, 7f
    ldr     w11, [x10]
    cbz     w11, 69f
    ldr     w12, [x10, #20]
    add     x13, x10, #28
    mov     w14, #0                     // leitura
    mov     w15, #0                     // escrita
61: cmp     w14, w12
    b.ge    62f
    ldr     w11, [x13, x14, lsl #2]
    cmp     w11, w19
    b.eq    63f
    str     w11, [x13, x15, lsl #2]
    add     w15, w15, #1
63: add     w14, w14, #1
    b       61b
62: str     w15, [x10, #20]
    str     wzr, [x10, #24]
    cmp     w15, #2
    b.ge    69f
    ldr     w11, [x10]
    cmp     w11, #4
    b.eq    69f
    str     wzr, [x10]                  // trem sem rota e removido
69: add     x10, x10, #128
    sub     w9, w9, #1
    b       6b
7:  mov     w9, #1
    str     w9, [x28, #G_NETDIRTY]
    LA      x0, m_delstation
    b       dm_msg
    // 4) trilho
dm_seg:
    fmov    s0, s8
    fmov    s1, s9
    bl      find_seg_near
    tbz     w0, #31, 8f
    LA      x0, m_nothing
    b       dm_msg
8:  mov     w19, w0
    LA      x20, segs
    add     x20, x20, x19, lsl #7
    ldr     w9, [x20, #112]
    tbnz    w9, #31, 81f
    LA      x0, m_segstation
    b       dm_msg
81: mov     w0, w19
    bl      train_uses_seg
    cbz     w0, 82f
    LA      x0, m_segtrain
    b       dm_msg
82: str     wzr, [x20, #16]
    ldr     w0, [x20]
    mov     w1, w19
    bl      node_detach
    ldr     w0, [x20, #4]
    mov     w1, w19
    bl      node_detach
    ldr     w9, [x28, #G_NSIG]
    LA      x10, signals
83: cbz     w9, 84f
    ldr     w11, [x10]
    cmp     w11, w19
    b.ne    85f
    mov     w11, #-1
    str     w11, [x10]
85: add     x10, x10, #16
    sub     w9, w9, #1
    b       83b
84: mov     w9, #-1
    str     w9, [x28, #G_CHAIN]
    mov     w9, #1
    str     w9, [x28, #G_NETDIRTY]
    LA      x0, m_delseg
dm_msg:
    bl      set_msg
    ldp     d10, d11, [sp, #64]
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// =====================================================================
//  Rede: blocos de sinal e tabelas de distancia
// =====================================================================

// uf_find(w0 = pedaco) -> w0 raiz   (usa x9-x11)
uf_find:
    LA      x9, uparent
1:  ldr     w10, [x9, x0, lsl #2]
    cmp     w10, w0
    b.eq    2f
    ldr     w11, [x9, x10, lsl #2]
    str     w11, [x9, x0, lsl #2]
    mov     w0, w11
    b       1b
2:  ret

// piece_end(w0 = trilho, w1 = no) -> w0 pedaco que toca o no  (usa x9-x10)
piece_end:
    LA      x9, segs
    add     x9, x9, x0, lsl #7
    ldr     w10, [x9]
    ldr     w0, [x9, #40]
    cmp     w10, w1
    b.eq    1f
    ldr     w10, [x9, #20]
    add     w0, w0, w10
1:  ret

net_rebuild:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    // 1) sinais de cada trilho, em ordem de distancia
    ldr     w9, [x28, #G_NSEG]
    LA      x10, segs
1:  cbz     w9, 2f
    str     wzr, [x10, #20]
    add     x10, x10, #128
    sub     w9, w9, #1
    b       1b
2:  mov     w19, #0
3:  ldr     w9, [x28, #G_NSIG]
    cmp     w19, w9
    b.ge    6f
    LA      x10, signals
    add     x10, x10, x19, lsl #4
    ldr     w11, [x10]
    tbnz    w11, #31, 5f
    LA      x12, segs
    add     x12, x12, x11, lsl #7
    ldr     w13, [x12, #16]
    cbz     w13, 51f
    ldr     w13, [x12, #20]
    cmp     w13, #4
    b.lo    4f
51: mov     w13, #-1                    // sem lugar: remove o sinal
    str     w13, [x10]
    b       5f
4:  ldr     s0, [x10, #4]
    add     x14, x12, #48
    mov     w15, w13                    // insercao ordenada
41: cbz     w15, 42f
    sub     w0, w15, #1
    ldr     w1, [x14, x0, lsl #2]
    LA      x2, signals
    add     x2, x2, x1, lsl #4
    ldr     s1, [x2, #4]
    fcmp    s1, s0
    b.le    42f
    str     w1, [x14, x15, lsl #2]
    mov     w15, w0
    b       41b
42: str     w19, [x14, x15, lsl #2]
    add     w13, w13, #1
    str     w13, [x12, #20]
5:  add     w19, w19, #1
    b       3b
    // 2) numeracao dos pedacos
6:  mov     w9, #0
    ldr     w10, [x28, #G_NSEG]
    LA      x11, segs
7:  cbz     w10, 8f
    str     w9, [x11, #40]
    ldr     w12, [x11, #20]
    add     w9, w9, w12
    add     w9, w9, #1
    add     x11, x11, #128
    sub     w10, w10, #1
    b       7b
8:  str     w9, [x28, #G_NPIECE]
    // 3) union-find: pedacos ligados por nos formam um bloco
    LA      x10, uparent
    mov     w11, #0
9:  cmp     w11, w9
    b.ge    10f
    str     w11, [x10, x11, lsl #2]
    add     w11, w11, #1
    b       9b
10: mov     w19, #0
11: ldr     w9, [x28, #G_NNODE]
    cmp     w19, w9
    b.ge    14f
    LA      x20, nodes
    add     x20, x20, x19, lsl #6
    ldr     w9, [x20, #52]
    cbz     w9, 13f
    ldr     w21, [x20, #16]
    cmp     w21, #2
    b.lt    13f
    ldr     w0, [x20, #20]
    mov     w1, w19
    bl      piece_end
    bl      uf_find
    mov     w22, w0                     // raiz do primeiro
    mov     w23, #1
12: cmp     w23, w21
    b.ge    13f
    add     x9, x20, #20
    ldr     w0, [x9, x23, lsl #2]
    mov     w1, w19
    bl      piece_end
    bl      uf_find
    cmp     w0, w22
    b.eq    121f
    LA      x9, uparent
    str     w22, [x9, x0, lsl #2]
121: add    w23, w23, #1
    b       12b
13: add     w19, w19, #1
    b       11b
14: ldr     w19, [x28, #G_NPIECE]
    mov     w20, #0
15: cmp     w20, w19
    b.ge    16f
    mov     w0, w20
    bl      uf_find
    LA      x9, ublock
    str     w0, [x9, x20, lsl #2]
    add     w20, w20, #1
    b       15b
    // 4) tabelas de distancia ate cada estacao
16: mov     w19, #0
17: ldr     w9, [x28, #G_NST]
    cmp     w19, w9
    b.ge    18f
    mov     w0, w19
    bl      bellman
    add     w19, w19, #1
    b       17b
18: str     wzr, [x28, #G_NETDIRTY]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// succ_min(w0 trilho, w1 sentido, x2 tabela) -> s0 menor distancia,
// w0 melhor estado (-1), w1 quantos sucessores, w2 primeiro sucessor
// folha: usa x0-x16, s0-s1
succ_min:
    LA      x9, segs
    add     x9, x9, x0, lsl #7
    cbnz    w1, 1f
    ldr     w10, [x9, #4]               // indo de a para b: sai em b
    ldr     w11, [x9, #12]
    b       2f
1:  ldr     w10, [x9]
    ldr     w11, [x9, #8]
2:  neg     w11, w11                    // lado pelo qual se continua
    LA      x12, nodes
    add     x12, x12, x10, lsl #6
    ldr     w13, [x12, #16]
    add     x12, x12, #20
    FC      s0, F_INF
    mov     w3, #-1
    mov     w4, #0
    mov     w5, #-1
    mov     w6, #0
3:  cmp     w6, w13
    b.ge    9f
    ldr     w7, [x12, x6, lsl #2]
    cmp     w7, w0
    b.eq    8f
    LA      x14, segs
    add     x14, x14, x7, lsl #7
    ldr     w15, [x14, #16]
    cbz     w15, 8f
    ldr     w15, [x14]
    cmp     w15, w10
    b.ne    4f
    ldr     w15, [x14, #8]
    mov     w8, #0
    b       5f
4:  ldr     w15, [x14, #12]
    mov     w8, #1
5:  cmp     w15, w11
    b.ne    8f
    add     w8, w8, w7, lsl #1          // estado = trilho*2 + sentido
    add     w4, w4, #1
    cmn     w5, #1
    b.ne    6f
    mov     w5, w8
6:  ldr     s1, [x2, x8, lsl #2]
    fcmp    s1, s0
    b.ge    8f
    fmov    s0, s1
    mov     w3, w8
8:  add     w6, w6, #1
    b       3b
9:  mov     w0, w3
    mov     w1, w4
    mov     w2, w5
    ret

// bellman(w0 = estacao): distancia de cada (trilho, sentido) ate ela
bellman:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     d8, [sp, #80]
    LA      x19, dist
    add     x19, x19, x0, lsl #14
    LA      x9, stations
    add     x9, x9, x0, lsl #6
    ldr     w20, [x9]                   // trilho da estacao
    ldr     w10, [x9, #36]
    FC      s0, F_INF
    ldr     w11, [x28, #G_NSEG]
    lsl     w11, w11, #1
    mov     w12, #0
1:  cmp     w12, w11
    b.ge    2f
    str     s0, [x19, x12, lsl #2]
    add     w12, w12, #1
    b       1b
2:  cbz     w10, bf_ret                 // estacao removida
    ldr     s1, [x9, #8]
    lsl     w12, w20, #1
    str     s1, [x19, x12, lsl #2]      // sentido 0: ate s1
    LA      x13, segs
    add     x13, x13, x20, lsl #7
    ldr     s2, [x13, #32]
    ldr     s1, [x9, #4]
    fsub    s1, s2, s1
    add     w12, w12, #1
    str     s1, [x19, x12, lsl #2]      // sentido 1: ate s0
    mov     w21, #0                     // iteracao
bf_iter:
    mov     w22, #0                     // mudou?
    mov     w23, #0                     // trilho
bf_seg:
    ldr     w9, [x28, #G_NSEG]
    cmp     w23, w9
    b.ge    bf_end
    cmp     w23, w20
    b.eq    bf_next
    LA      x25, segs
    add     x25, x25, x23, lsl #7
    ldr     w9, [x25, #16]
    cbz     w9, bf_next
    ldr     s8, [x25, #32]
    mov     w24, #0
bf_dir:
    mov     w0, w23
    mov     w1, w24
    mov     x2, x19
    bl      succ_min
    fadd    s0, s0, s8
    add     w9, w24, w23, lsl #1
    ldr     s1, [x19, x9, lsl #2]
    FC      s2, F_HUGE
    fcmp    s0, s2
    b.ge    3f
    fmov    s2, #0.125
    fadd    s2, s0, s2
    fcmp    s2, s1
    b.ge    3f
    str     s0, [x19, x9, lsl #2]
    mov     w22, #1
3:  add     w24, w24, #1
    cmp     w24, #2
    b.lt    bf_dir
bf_next:
    add     w23, w23, #1
    b       bf_seg
bf_end:
    cbz     w22, bf_ret
    add     w21, w21, #1
    cmp     w21, #500
    b.lt    bf_iter
bf_ret:
    ldr     d8, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// piece_of(w0 trilho, s0 distancia) -> w0 pedaco.  folha (x9-x13)
piece_of:
    LA      x9, segs
    add     x9, x9, x0, lsl #7
    ldr     w10, [x9, #40]
    ldr     w11, [x9, #20]
    add     x12, x9, #48
1:  cbz     w11, 9f
    ldr     w13, [x12], #4
    LA      x14, signals
    add     x14, x14, x13, lsl #4
    ldr     s1, [x14, #4]
    fcmp    s1, s0
    b.ge    9f
    add     w10, w10, #1
    sub     w11, w11, #1
    b       1b
9:  mov     w0, w10
    ret

// =====================================================================
//  Simulacao
// =====================================================================

    .globl rail_update
rail_update:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     d8, [sp, #64]
    ldr     w9, [x28, #G_MSGT]
    cbz     w9, 1f
    sub     w9, w9, #1
    str     w9, [x28, #G_MSGT]
1:  ldr     w9, [x28, #G_NETDIRTY]
    cbz     w9, 2f
    bl      net_rebuild
2:  ldr     w9, [x28, #G_PAUSE]
    cbnz    w9, ru_ret
    ldr     w9, [x28, #G_SIMFRAME]
    add     w9, w9, #1
    str     w9, [x28, #G_SIMFRAME]
    // passageiros aparecem nas estacoes (a cada 30 quadros)
    mov     w10, #30
    udiv    w11, w9, w10
    msub    w11, w11, w10, w9
    cbnz    w11, ru_occ
    ldr     w19, [x28, #G_NST]
    LA      x20, stations
3:  cbz     w19, ru_occ
    ldr     w9, [x20, #36]
    cbz     w9, 5f
    ldr     w21, [x20, #32]             // mascara de cidades
    ldr     w22, [x20, #12]
    mov     w23, #0
4:  cbz     w21, 41f
    tbz     w21, #0, 42f
    LA      x9, towns
    add     x9, x9, x23, lsl #6
    ldr     w10, [x9, #8]
    mov     w11, #1000
    udiv    w10, w10, w11
    add     w22, w22, w10
    add     w22, w22, #1
42: lsr     w21, w21, #1
    add     w23, w23, #1
    b       4b
41: mov     w9, #999
    cmp     w22, w9
    csel    w22, w9, w22, gt
    str     w22, [x20, #12]
5:  add     x20, x20, #64
    sub     w19, w19, #1
    b       3b
    // blocos ocupados por trens
ru_occ:
    ldr     w9, [x28, #G_NPIECE]
    LA      x10, uocc
6:  cbz     w9, 7f
    strb    wzr, [x10], #1
    sub     w9, w9, #1
    b       6b
7:  mov     w19, #0
71: ldr     w9, [x28, #G_NTRAIN]
    cmp     w19, w9
    b.ge    ru_sig
    LA      x20, trains
    add     x20, x20, x19, lsl #7
    ldr     w9, [x20]
    cbz     w9, 74f
    fmov    s8, wzr
72: mov     x0, x20
    fmov    s0, s8
    bl      walk_back
    bl      piece_of
    LA      x9, ublock
    ldr     w0, [x9, x0, lsl #2]
    LA      x9, uocc
    mov     w10, #1
    strb    w10, [x9, x0]
    fmov    s0, #0.5
    fadd    s8, s8, s0
    FC      s0, F_TLEN
    fcmp    s8, s0
    b.le    72b
74: add     w19, w19, #1
    b       71b
    // cor de cada sinal
ru_sig:
    mov     w19, #0
8:  ldr     w9, [x28, #G_NSIG]
    cmp     w19, w9
    b.ge    ru_trains
    LA      x20, signals
    add     x20, x20, x19, lsl #4
    ldr     w10, [x20]
    tbnz    w10, #31, 89f
    LA      x11, segs
    add     x11, x11, x10, lsl #7
    ldr     w12, [x11, #20]
    add     x13, x11, #48
    mov     w14, #0
81: cmp     w14, w12
    b.ge    89f
    ldr     w15, [x13, x14, lsl #2]
    cmp     w15, w19
    b.eq    82f
    add     w14, w14, #1
    b       81b
82: ldr     w15, [x11, #40]
    add     w15, w15, w14               // pedaco antes do sinal
    LA      x9, ublock
    LA      x10, uocc
    add     w0, w15, #1
    ldr     w0, [x9, x0, lsl #2]
    ldrb    w1, [x10, x0]               // bloco depois (sentido 0)
    ldr     w0, [x9, x15, lsl #2]
    ldrb    w2, [x10, x0]               // bloco antes (sentido 1)
    orr     w1, w1, w2, lsl #1
    str     w1, [x20, #12]
89: add     w19, w19, #1
    b       8b
ru_trains:
    mov     w19, #0
9:  ldr     w9, [x28, #G_NTRAIN]
    cmp     w19, w9
    b.ge    ru_ret
    LA      x0, trains
    add     x0, x0, x19, lsl #7
    ldr     w9, [x0]
    cbz     w9, 91f
    bl      train_step
91: add     w19, w19, #1
    b       9b
ru_ret:
    ldr     d8, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// walk_back(x0 = trem, s0 = distancia para tras da cabeca)
// -> w0 trilho, s0 distancia, w1 sentido, w2 indice no historico
// folha: usa x0-x8, s0-s4
walk_back:
    fmov    s1, s0
    mov     w2, #0
    ldr     w3, [x0, #4]
    ldr     w4, [x0, #8]
    ldr     s2, [x0, #12]
    ldr     w5, [x0, #104]
wb_loop:
    LA      x6, segs
    add     x6, x6, x3, lsl #7
    ldr     s3, [x6, #32]
    cbnz    w4, 1f
    fmov    s4, s2                      // indo para b: atras fica o inicio
    b       2f
1:  fsub    s4, s3, s2
2:  fcmp    s1, s4
    b.gt    3f
    cbnz    w4, 21f
    fsub    s0, s2, s1
    b       wb_ret
21: fadd    s0, s2, s1
    b       wb_ret
3:  fsub    s1, s1, s4
    add     w2, w2, #1
    cmp     w2, w5
    b.lt    4f
    sub     w2, w2, #1                  // acabou o historico
    cbnz    w4, 31f
    fmov    s0, wzr
    b       wb_ret
31: fmov    s0, s3
    b       wb_ret
4:  add     x7, x0, #72
    ldr     w8, [x7, x2, lsl #2]
    lsr     w3, w8, #1
    and     w4, w8, #1
    LA      x6, segs
    add     x6, x6, x3, lsl #7
    ldr     s3, [x6, #32]
    cbnz    w4, 41f
    fmov    s2, s3                      // saiu pela ponta b
    b       wb_loop
41: fmov    s2, wzr                     // saiu pela ponta a
    b       wb_loop
wb_ret:
    mov     w0, w3
    mov     w1, w4
    ret

// train_reverse(x0 = trem): a cauda vira a cabeca
train_reverse:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     x19, x0
    FC      s0, F_TLEN
    bl      walk_back
    str     w0, [x19, #4]
    eor     w1, w1, #1
    str     w1, [x19, #8]
    str     s0, [x19, #12]
    // historico invertido
    add     x9, x19, #72
    add     x10, sp, #32
    mov     w11, #0
1:  sub     w12, w2, w11
    ldr     w13, [x9, x12, lsl #2]
    eor     w13, w13, #1
    str     w13, [x10, x11, lsl #2]
    add     w11, w11, #1
    cmp     w11, w2
    b.le    1b
    mov     w12, #0
2:  ldr     w13, [x10, x12, lsl #2]
    str     w13, [x9, x12, lsl #2]
    add     w12, w12, #1
    cmp     w12, w11
    b.lt    2b
    str     w11, [x19, #104]
    str     wzr, [x19, #16]
    mov     w9, #-2
    str     w9, [x19, #108]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// train_push(x0 = trem, w1 = estado): entrou em um trilho novo.  folha
train_push:
    ldr     w9, [x0, #104]
    add     x10, x0, #72
    cmp     w9, #7
    mov     w11, #7
    csel    w11, w9, w11, lt
1:  cbz     w11, 2f
    sub     w12, w11, #1
    ldr     w13, [x10, x12, lsl #2]
    str     w13, [x10, x11, lsl #2]
    mov     w11, w12
    b       1b
2:  str     w1, [x10]
    add     w9, w9, #1
    cmp     w9, #8
    mov     w11, #8
    csel    w9, w9, w11, lt
    str     w9, [x0, #104]
    lsr     w12, w1, #1
    str     w12, [x0, #4]
    and     w12, w1, #1
    str     w12, [x0, #8]
    ret

// target_dist(x0 = trem) -> x2 = tabela da estacao alvo, x3 = estacao
target_dist:
    ldr     w9, [x0, #24]
    add     x10, x0, #28
    ldr     w9, [x10, x9, lsl #2]
    LA      x2, dist
    add     x2, x2, x9, lsl #14
    LA      x3, stations
    add     x3, x3, x9, lsl #6
    ret

// decide_next(x0 = trem): escolhe o trilho seguinte no proximo no
decide_next:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     x19, x0
    bl      target_dist
    ldr     w0, [x19, #4]
    ldr     w1, [x19, #8]
    bl      succ_min
    tbz     w0, #31, 1f
    mov     w0, w2                      // sem rota: qualquer saida
1:  str     w0, [x19, #108]
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// route_cost(w0 trilho, w1 sentido, s0 posicao, x2 tabela, x3 estacao) -> s0
route_cost:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x3]
    cmp     w9, w0
    b.ne    2f
    cbnz    w1, 1f
    ldr     s1, [x3, #8]
    fsub    s1, s1, s0
    b       11f
1:  ldr     s1, [x3, #4]
    fsub    s1, s0, s1
11: FC      s2, F_M005
    fcmp    s1, s2
    b.lt    2f
    fmov    s2, wzr
    fmax    s0, s1, s2                  // estacao logo a frente
    b       9f
2:  LA      x9, segs
    add     x9, x9, x0, lsl #7
    ldr     s1, [x9, #32]
    cbnz    w1, 3f
    fsub    s1, s1, s0
    b       4f
3:  fmov    s1, s0
4:  str     s1, [sp, #-16]!
    bl      succ_min
    ldr     s1, [sp], #16
    fadd    s0, s0, s1
9:  ldp     x29, x30, [sp], #16
    ret

// train_choose_dir(x0 = trem): depois de parar, ve se vale inverter
train_choose_dir:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     d8, d9, [sp, #32]
    mov     x19, x0
    bl      target_dist
    ldr     w0, [x19, #4]
    ldr     w1, [x19, #8]
    ldr     s0, [x19, #12]
    bl      route_cost
    fmov    s8, s0                      // custo seguindo em frente
    mov     x0, x19
    FC      s0, F_TLEN
    bl      walk_back
    eor     w1, w1, #1
    mov     w20, w0
    fmov    s9, s0
    mov     x0, x19
    bl      target_dist
    mov     w0, w20
    ldr     w9, [x19, #8]
    fmov    s0, s9
    bl      route_cost                  // custo invertendo
    fmov    s1, #1.0
    fadd    s1, s0, s1
    fcmp    s1, s8
    b.ge    1f
    fmov    s8, s0
    mov     x0, x19
    bl      train_reverse
1:  FC      s0, F_HUGE
    fcmp    s8, s0
    b.lt    9f
    mov     w9, #5                      // sem rota: espera e tenta de novo
    str     w9, [x19]
    mov     w9, #90
    str     w9, [x19, #60]
9:  ldp     d8, d9, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// train_exchange(x0 = trem): desembarca e embarca passageiros
train_exchange:
    ldr     w9, [x0, #24]
    add     x10, x0, #28
    ldr     w9, [x10, x9, lsl #2]
    LA      x10, stations
    add     x10, x10, x9, lsl #6
    ldr     w11, [x0, #64]
    ldr     w12, [x28, #G_PAX]
    add     w12, w12, w11
    str     w12, [x28, #G_PAX]
    ldr     w12, [x10, #28]
    add     w12, w12, w11
    str     w12, [x10, #28]
    ldr     w11, [x10, #12]
    ldr     w12, [x0, #68]
    cmp     w11, w12
    csel    w12, w11, w12, lt
    sub     w11, w11, w12
    str     w11, [x10, #12]
    str     w12, [x0, #64]
    ret

// sig_ahead(w0 trilho, w1 sentido, s0 posicao, s1 distancia ja somada)
// -> s0 distancia ate parar antes do proximo sinal vermelho (INF)
// folha: usa x9-x15, x16, s0-s5
sig_ahead:
    fmov    s4, s0
    fmov    s5, s1
    FC      s0, F_INF
    LA      x9, segs
    add     x9, x9, x0, lsl #7
    ldr     w10, [x9, #20]
    add     x11, x9, #48
1:  cbz     w10, 9f
    ldr     w12, [x11], #4
    sub     w10, w10, #1
    LA      x13, signals
    add     x13, x13, x12, lsl #4
    ldr     w14, [x13, #8]
    cmp     w14, #2
    b.eq    2f
    cmp     w14, w1
    b.ne    1b
2:  ldr     w14, [x13, #12]
    lsr     w14, w14, w1
    tbz     w14, #0, 1b                 // verde
    ldr     s1, [x13, #4]
    cbnz    w1, 3f
    fsub    s1, s1, s4
    b       4f
3:  fsub    s1, s4, s1
4:  fcmp    s1, #0.0
    b.lt    1b                          // ja passou
    fadd    s1, s1, s5
    FC      s2, F_SIGM
    fsub    s1, s1, s2
    fmin    s0, s0, s1
    b       1b
9:  ret

// train_step(x0 = trem): um quadro de simulacao
train_step:
    stp     x29, x30, [sp, #-128]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
    stp     d8, d9, [sp, #80]
    stp     d10, d11, [sp, #96]
    stp     d12, d13, [sp, #112]
    mov     x19, x0
    ldr     w9, [x19]
    cmp     w9, #1
    b.eq    ts_run
    cmp     w9, #2
    b.eq    ts_load
    cmp     w9, #5
    b.eq    ts_wait
    b       ts_done
ts_load:                                // parado na estacao
    ldr     w9, [x19, #60]
    sub     w9, w9, #1
    str     w9, [x19, #60]
    cmp     w9, #30
    b.ne    1f
    mov     x0, x19
    bl      train_exchange
    ldr     w9, [x19, #60]
1:  cmp     w9, #0
    b.gt    ts_done
    ldr     w9, [x19, #24]              // proxima parada
    add     w9, w9, #1
    ldr     w10, [x19, #20]
    cmp     w9, w10
    csel    w9, wzr, w9, ge
    str     w9, [x19, #24]
    mov     w9, #1
    str     w9, [x19]
    mov     w9, #-2
    str     w9, [x19, #108]
    mov     x0, x19
    bl      train_choose_dir
    b       ts_done
ts_wait:                                // sem rota
    ldr     w9, [x19, #60]
    sub     w9, w9, #1
    str     w9, [x19, #60]
    cmp     w9, #0
    b.gt    ts_done
    mov     w9, #1
    str     w9, [x19]
    mov     w9, #-2
    str     w9, [x19, #108]
    mov     x0, x19
    bl      train_choose_dir
    b       ts_done
ts_run:
    mov     x0, x19
    bl      target_dist
    mov     x20, x3                     // estacao alvo
    ldr     w21, [x19, #4]
    ldr     w22, [x19, #8]
    ldr     s8, [x19, #12]
    ldr     s9, [x19, #16]
    LA      x23, segs
    add     x23, x23, x21, lsl #7
    ldr     s10, [x23, #32]
    FC      s11, F_INF                  // distancia ate onde parar
    mov     w24, #0                     // motivo: 1 estacao 2 sinal 3 fim
    // estacao neste trilho
    ldr     w9, [x20]
    cmp     w9, w21
    b.ne    2f
    cbnz    w22, 11f
    ldr     s0, [x20, #8]
    fsub    s0, s0, s8
    b       12f
11: ldr     s0, [x20, #4]
    fsub    s0, s8, s0
12: FC      s1, F_M005
    fcmp    s0, s1
    b.lt    2f
    fmov    s1, wzr
    fmax    s11, s0, s1
    mov     w24, #1
2:  mov     w0, w21                     // sinais neste trilho
    mov     w1, w22
    fmov    s0, s8
    fmov    s1, wzr
    bl      sig_ahead
    fcmp    s0, s11
    b.ge    3f
    fmov    s11, s0
    mov     w24, #2
3:  cbnz    w22, 31f                    // quanto falta para o no
    fsub    s12, s10, s8
    b       32f
31: fmov    s12, s8
32: FC      s0, F_LOOK
    fcmp    s12, s0
    b.ge    ts_speed
    ldr     w9, [x19, #108]
    cmn     w9, #2
    b.ne    4f
    mov     x0, x19
    bl      decide_next
    ldr     w9, [x19, #108]
4:  tbz     w9, #31, 41f
    FC      s0, F_TENTH                 // fim da linha
    fsub    s0, s12, s0
    fcmp    s0, s11
    b.ge    ts_speed
    fmov    s11, s0
    mov     w24, #3
    b       ts_speed
41: lsr     w25, w9, #1                 // proximo trilho
    and     w10, w9, #1
    str     w10, [sp, #-16]!
    LA      x13, segs
    add     x13, x13, x25, lsl #7
    ldr     s13, [x13, #32]
    ldr     w12, [x20]
    cmp     w12, w25
    b.ne    42f
    cbnz    w10, 411f
    ldr     s0, [x20, #8]
    b       412f
411: ldr    s0, [x20, #4]
    fsub    s0, s13, s0
412: fadd   s0, s0, s12
    fcmp    s0, s11
    b.ge    42f
    fmov    s11, s0
    mov     w24, #1
42: ldr     w1, [sp], #16
    mov     w0, w25
    fmov    s0, wzr
    cbz     w1, 43f
    fmov    s0, s13
43: fmov    s1, s12
    bl      sig_ahead
    fcmp    s0, s11
    b.ge    ts_speed
    fmov    s11, s0
    mov     w24, #2
ts_speed:                               // acelera ou freia
    FC      s2, F_DEC
    fmul    s0, s9, s9
    fadd    s1, s2, s2
    fdiv    s0, s0, s1
    fadd    s0, s0, s9
    fadd    s0, s0, s9
    fcmp    s11, s0
    b.gt    5f
    fsub    s9, s9, s2
    fmov    s1, wzr
    fmax    s9, s9, s1
    b       6f
5:  FC      s2, F_ACC
    fadd    s9, s9, s2
    FC      s1, F_VMAX
    fmin    s9, s9, s1
6:  FC      s0, F_STOPEPS
    fcmp    s11, s0
    b.gt    ts_move
    FC      s1, F_DEC
    fcmp    s9, s1
    b.gt    ts_move
    fmov    s9, wzr
    str     s9, [x19, #16]
    cmp     w24, #1
    b.ne    7f
    ldr     w9, [x20]
    cmp     w9, w21
    b.ne    ts_move
    mov     w9, #2                      // chegou na estacao
    str     w9, [x19]
    mov     w9, #150
    str     w9, [x19, #60]
    b       ts_done
7:  cmp     w24, #3
    b.ne    ts_move
    mov     x0, x19                     // fim da linha: inverte
    bl      train_reverse
    b       ts_done
ts_move:
    str     s9, [x19, #16]
    cbnz    w22, 81f
    fadd    s8, s8, s9
    fcmp    s8, s10
    b.le    ts_store
    fsub    s13, s8, s10                // passou do fim do trilho
    b       82f
81: fsub    s8, s8, s9
    fcmp    s8, #0.0
    b.ge    ts_store
    fneg    s13, s8
82: ldr     w9, [x19, #108]
    cmn     w9, #2
    b.ne    83f
    mov     x0, x19
    bl      decide_next
    ldr     w9, [x19, #108]
83: tbz     w9, #31, 84f
    cbnz    w22, 831f
    fmov    s8, s10
    b       832f
831: fmov   s8, wzr
832: fmov   s9, wzr
    str     s9, [x19, #16]
    b       ts_store
84: mov     x0, x19
    mov     w1, w9
    bl      train_push
    ldr     w21, [x19, #4]
    ldr     w22, [x19, #8]
    LA      x23, segs
    add     x23, x23, x21, lsl #7
    ldr     s10, [x23, #32]
    cbnz    w22, 85f
    fmov    s8, s13
    b       86f
85: fsub    s8, s10, s13
86: mov     w9, #-2
    str     w9, [x19, #108]
ts_store:
    str     s8, [x19, #12]
ts_done:
    ldp     d12, d13, [sp, #112]
    ldp     d10, d11, [sp, #96]
    ldp     d8, d9, [sp, #80]
    ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #128
    ret

// =====================================================================
//  Desenho
// =====================================================================

    .globl rail_draw
rail_draw:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      draw_tracks
    bl      draw_stations
    bl      draw_signals
    bl      draw_trains
    bl      draw_preview
    ldp     x29, x30, [sp], #16
    ret

// QUAD base: desenha o quadrilatero p0 p1 p2 p3 guardado em [base]
// (4 x (x, y, prof)), com a cor em [base+48] e a profundidade em [base+52]
.macro QUAD base
    ldr     w0, [\base]
    ldr     w1, [\base, #4]
    ldr     w2, [\base, #12]
    ldr     w3, [\base, #16]
    ldr     w4, [\base, #24]
    ldr     w5, [\base, #28]
    ldr     w6, [\base, #48]
    ldr     w7, [\base, #52]
    bl      fill_tri
    ldr     w0, [\base]
    ldr     w1, [\base, #4]
    ldr     w2, [\base, #24]
    ldr     w3, [\base, #28]
    ldr     w4, [\base, #36]
    ldr     w5, [\base, #40]
    ldr     w6, [\base, #48]
    ldr     w7, [\base, #52]
    bl      fill_tri
.endm

// guarda o resultado de projoff (w0,w1,w2) em [base, #off]
.macro PSTORE base, off
    str     w0, [\base, #\off]
    str     w1, [\base, #(\off + 4)]
    str     w2, [\base, #(\off + 8)]
.endm

draw_tracks:
    stp     x29, x30, [sp, #-176]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    add     x27, sp, #96                // 4 pontos projetados
    ldr     w25, [x28, #G_ZOOM]
    mov     w24, #2
    cmp     w25, #2
    b.lt    1f
    mov     w24, #1                     // de perto: todas as amostras
1:  ldr     w26, [x28, #G_Z256]
    lsr     w26, w26, #8
    cmp     w26, #1
    mov     w9, #1
    csel    w26, w9, w26, lt            // espessura das linhas
    mov     w20, #0
dtk_seg:
    ldr     w9, [x28, #G_NSEG]
    cmp     w20, w9
    b.ge    dtk_done
    LA      x19, segs
    add     x19, x19, x20, lsl #7
    ldr     w9, [x19, #16]
    cbz     w9, dtk_next
    ldr     w22, [x19, #28]
    ldr     w9, [x19, #24]
    LA      x23, samples
    add     x23, x23, x9, lsl #5
    mov     w21, #0
dtk_samp:
    sub     w9, w22, #1
    cmp     w21, w9
    b.ge    dtk_next
    add     w9, w21, w24
    sub     w10, w22, #1
    cmp     w9, w10
    csel    w9, w10, w9, gt
    add     x10, x23, x21, lsl #5       // p
    str     x10, [sp, #152]
    add     x10, x23, x9, lsl #5        // q
    str     x10, [sp, #160]
    // descarta se longe da tela
    ldr     x0, [sp, #152]
    fmov    s0, wzr
    mov     w1, #0
    bl      projoff
    cmn     w0, #80
    b.lt    dtk_adv
    mov     w9, #(SCRW + 80)
    cmp     w0, w9
    b.gt    dtk_adv
    cmn     w1, #80
    b.lt    dtk_adv
    mov     w9, #(SCRH + 80)
    cmp     w1, w9
    b.gt    dtk_adv
    // lastro
    ldr     x0, [sp, #152]
    FC      s0, F_BALLAST
    mov     w1, #4
    bl      projoff
    PSTORE  x27, 0
    ldr     x0, [sp, #160]
    FC      s0, F_BALLAST
    mov     w1, #4
    bl      projoff
    PSTORE  x27, 12
    ldr     x0, [sp, #160]
    FC      s0, F_BALLAST
    fneg    s0, s0
    mov     w1, #4
    bl      projoff
    PSTORE  x27, 24
    ldr     x0, [sp, #152]
    FC      s0, F_BALLAST
    fneg    s0, s0
    mov     w1, #4
    bl      projoff
    PSTORE  x27, 36
    MOVI32  w9, 0xFF968A78
    str     w9, [x27, #48]
    ldr     w10, [x27, #8]
    str     w10, [x27, #52]
    QUAD    x27
    cbz     w25, dtk_far
    // dormente
    ldr     x0, [sp, #152]
    FC      s0, F_SLEEPER
    mov     w1, #6
    bl      projoff
    PSTORE  x27, 0
    ldr     x0, [sp, #152]
    FC      s0, F_SLEEPER
    fneg    s0, s0
    mov     w1, #6
    bl      projoff
    mov     w3, w1
    mov     w5, w2
    mov     w2, w0
    ldr     w0, [x27]
    ldr     w1, [x27, #4]
    MOVI32  w4, 0xFF5E4630
    mov     w6, w26
    bl      line_z
    // trilhos
    ldr     x0, [sp, #152]
    FC      s0, F_RAIL
    mov     w1, #10
    bl      projoff
    PSTORE  x27, 0
    ldr     x0, [sp, #160]
    FC      s0, F_RAIL
    mov     w1, #10
    bl      projoff
    mov     w3, w1
    mov     w2, w0
    ldr     w0, [x27]
    ldr     w1, [x27, #4]
    ldr     w5, [x27, #8]
    MOVI32  w4, 0xFFD4D6DC
    mov     w6, w26
    bl      line_z
    ldr     x0, [sp, #152]
    FC      s0, F_RAIL
    fneg    s0, s0
    mov     w1, #10
    bl      projoff
    PSTORE  x27, 0
    ldr     x0, [sp, #160]
    FC      s0, F_RAIL
    fneg    s0, s0
    mov     w1, #10
    bl      projoff
    mov     w3, w1
    mov     w2, w0
    ldr     w0, [x27]
    ldr     w1, [x27, #4]
    ldr     w5, [x27, #8]
    MOVI32  w4, 0xFFB8BAC2
    mov     w6, w26
    bl      line_z
    b       dtk_adv
dtk_far:                                // de longe: uma linha escura
    ldr     x0, [sp, #152]
    fmov    s0, wzr
    mov     w1, #8
    bl      projoff
    PSTORE  x27, 0
    ldr     x0, [sp, #160]
    fmov    s0, wzr
    mov     w1, #8
    bl      projoff
    mov     w3, w1
    mov     w2, w0
    ldr     w0, [x27]
    ldr     w1, [x27, #4]
    ldr     w5, [x27, #8]
    MOVI32  w4, 0xFF3A3530
    mov     w6, #1
    bl      line_z
dtk_adv:
    add     w21, w21, w24
    b       dtk_samp
dtk_next:
    add     w20, w20, #1
    b       dtk_seg
dtk_done:
    ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #176
    ret

// plataformas e predio das estacoes
draw_stations:
    stp     x29, x30, [sp, #-192]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    stp     d8, d9, [sp, #176]
    add     x27, sp, #96
    mov     w20, #0
dst_loop:
    ldr     w9, [x28, #G_NST]
    cmp     w20, w9
    b.ge    dst_done
    LA      x19, stations
    add     x19, x19, x20, lsl #6
    ldr     w9, [x19, #36]
    cbz     w9, dst_next
    ldr     w9, [x19]
    LA      x21, segs
    add     x21, x21, x9, lsl #7
    ldr     s0, [x21, #36]
    ldr     s1, [x19, #4]
    fdiv    s1, s1, s0
    frintp  s1, s1
    fcvtzs  w22, s1                     // primeira amostra
    ldr     s1, [x19, #8]
    fdiv    s1, s1, s0
    frintm  s1, s1
    fcvtzs  w23, s1                     // ultima amostra
    ldr     w9, [x21, #24]
    LA      x24, samples
    add     x24, x24, x9, lsl #5
    mov     w25, #0                     // lado (0 = +, 1 = -)
dst_side:
    mov     w26, w22
dst_samp:
    cmp     w26, w23
    b.ge    dst_sidedone
    add     x9, x24, x26, lsl #5
    str     x9, [sp, #152]
    add     x9, x9, #32
    str     x9, [sp, #160]
    FC      s8, F_PIN
    FC      s9, F_POUT
    cbz     w25, 1f
    fneg    s8, s8
    fneg    s9, s9
1:  ldr     x0, [sp, #152]
    fmov    s0, s8
    mov     w1, #22
    bl      projoff
    PSTORE  x27, 0
    ldr     x0, [sp, #160]
    fmov    s0, s8
    mov     w1, #22
    bl      projoff
    PSTORE  x27, 12
    ldr     x0, [sp, #160]
    fmov    s0, s9
    mov     w1, #22
    bl      projoff
    PSTORE  x27, 24
    ldr     x0, [sp, #152]
    fmov    s0, s9
    mov     w1, #22
    bl      projoff
    PSTORE  x27, 36
    MOVI32  w9, 0xFFCFCBC0
    str     w9, [x27, #48]
    ldr     w10, [x27, #8]
    add     w10, w10, #8
    str     w10, [x27, #52]
    QUAD    x27
    add     w26, w26, #1
    b       dst_samp
dst_sidedone:
    add     w25, w25, #1
    cmp     w25, #2
    b.lt    dst_side
    // predio
    ldr     s0, [x19, #4]
    ldr     s1, [x19, #8]
    fadd    s0, s0, s1
    fmov    s1, #0.5
    fmul    s0, s0, s1
    ldr     w0, [x19]
    bl      seg_point
    FC      s4, F_STOFF
    fmsub   s0, s3, s4, s0
    fmadd   s1, s2, s4, s1
    bl      proj
    mov     w4, w2
    mov     w2, w1
    mov     w1, w0
    LA      x0, sprites
    add     x0, x0, #(SPR_STATION * 128)
    ldr     w3, [x28, #G_Z256]
    lsr     w3, w3, #8
    cmp     w3, #1
    mov     w5, #1
    csel    w3, w5, w3, lt
    mov     w5, #0
    bl      blit
dst_next:
    add     w20, w20, #1
    b       dst_loop
dst_done:
    ldp     d8, d9, [sp, #176]
    ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #192
    ret

draw_signals:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    mov     w20, #0
dsg_loop:
    ldr     w9, [x28, #G_NSIG]
    cmp     w20, w9
    b.ge    dsg_done
    LA      x19, signals
    add     x19, x19, x20, lsl #4
    ldr     w0, [x19]
    tbnz    w0, #31, dsg_next
    ldr     s0, [x19, #4]
    bl      seg_point
    FC      s4, F_SIGOFF
    ldr     w9, [x19, #8]
    cmp     w9, #1
    b.ne    1f
    fneg    s4, s4
1:  fmsub   s0, s3, s4, s0
    fmadd   s1, s2, s4, s1
    bl      proj
    mov     w4, w2
    add     w4, w4, #32
    mov     w2, w1
    mov     w1, w0
    // vermelho no sentido do sinal?
    ldr     w9, [x19, #8]
    ldr     w10, [x19, #12]
    cmp     w9, #2
    b.eq    2f
    lsr     w10, w10, w9
    and     w10, w10, #1
2:  LA      x0, sprites
    add     x0, x0, #(SPR_SIG_GREEN * 128)
    cbz     w10, 3f
    add     x0, x0, #128
3:  ldr     w3, [x28, #G_Z256]
    lsr     w3, w3, #8
    cmp     w3, #1
    mov     w5, #1
    csel    w3, w5, w3, lt
    mov     w5, #0
    bl      blit
dsg_next:
    add     w20, w20, #1
    b       dsg_loop
dsg_done:
    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// draw_box(s0/s1 centro, w0 elevacao, s2/s3 frente, w1 altura,
//          w2 cor do teto, w3 cor do lado, s4 meio-comprimento, s5 meia-largura)
// caixa 3D (vagao) com as faces visiveis
draw_box:
    stp     x29, x30, [sp, #-240]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     d8, d9, [sp, #80]
    stp     d10, d11, [sp, #96]
    stp     d12, d13, [sp, #112]
    stp     d14, d15, [sp, #128]
    fmov    s8, s0                      // centro
    fmov    s9, s1
    add     w19, w0, #8                 // base
    fmul    s10, s2, s4                 // A = frente * meio-comprimento
    fmul    s11, s3, s4
    fneg    s12, s3                     // B = normal * meia-largura
    fmul    s12, s12, s5
    fmul    s13, s2, s5
    fmov    s14, s2                     // frente unitaria
    fmov    s15, s3
    mov     w20, w1
    mov     w21, w2
    mov     w22, w3
    add     x23, sp, #144               // 8 pontos (x,y) + profundidade
    // cantos C0=c+A+B C1=c-A+B C2=c-A-B C3=c+A-B
    mov     w24, #0
1:  fmov    s0, s8
    fmov    s1, s9
    cmp     w24, #1
    b.eq    2f
    cmp     w24, #2
    b.eq    2f
    fadd    s0, s0, s10
    fadd    s1, s1, s11
    b       3f
2:  fsub    s0, s0, s10
    fsub    s1, s1, s11
3:  cmp     w24, #2
    b.ge    4f
    fadd    s0, s0, s12
    fadd    s1, s1, s13
    b       5f
4:  fsub    s0, s0, s12
    fsub    s1, s1, s13
5:  str     s0, [sp, #208]
    str     s1, [sp, #212]
    mov     w0, w19
    bl      proj
    add     x9, x23, x24, lsl #3
    str     w0, [x9]                    // base
    str     w1, [x9, #4]
    ldr     s0, [sp, #208]
    ldr     s1, [sp, #212]
    add     w0, w19, w20
    bl      proj
    add     x9, x23, x24, lsl #3
    str     w0, [x9, #32]               // topo
    str     w1, [x9, #36]
    add     w24, w24, #1
    cmp     w24, #4
    b.lt    1b
    fmov    s0, s8
    fmov    s1, s9
    mov     w0, w19
    bl      proj
    add     w25, w2, #40                // profundidade do vagao
    // faces laterais visiveis (normal com u+v > 0)
    mov     w24, #0
6:  cmp     w24, #0
    b.ne    61f
    fneg    s0, s15                     // +n
    fmov    s1, s14
    b       65f
61: cmp     w24, #1
    b.ne    62f
    fneg    s0, s14                     // -f
    fneg    s1, s15
    b       65f
62: cmp     w24, #2
    b.ne    63f
    fmov    s0, s15                     // -n
    fneg    s1, s14
    b       65f
63: fmov    s0, s14                     // +f
    fmov    s1, s15
65: fadd    s2, s0, s1
    fcmp    s2, #0.0
    b.le    69f
    mov     w1, #160                    // lado mais iluminado ou nao
    fcmp    s0, s1
    b.gt    66f
    mov     w1, #215
66: mov     w0, w22
    bl      shade
    mov     w26, w0
    and     w9, w24, #3
    add     w10, w24, #1
    and     w10, w10, #3
    add     x11, x23, x9, lsl #3
    add     x12, x23, x10, lsl #3
    ldr     w0, [x11]                   // Bj
    ldr     w1, [x11, #4]
    ldr     w2, [x12]                   // Bj+1
    ldr     w3, [x12, #4]
    ldr     w4, [x12, #32]              // Tj+1
    ldr     w5, [x12, #36]
    mov     w6, w26
    mov     w7, w25
    bl      fill_tri
    and     w9, w24, #3
    add     w10, w24, #1
    and     w10, w10, #3
    add     x11, x23, x9, lsl #3
    add     x12, x23, x10, lsl #3
    ldr     w0, [x11]
    ldr     w1, [x11, #4]
    ldr     w2, [x12, #32]
    ldr     w3, [x12, #36]
    ldr     w4, [x11, #32]              // Tj
    ldr     w5, [x11, #36]
    mov     w6, w26
    mov     w7, w25
    bl      fill_tri
69: add     w24, w24, #1
    cmp     w24, #4
    b.lt    6b
    // teto
    ldr     w0, [x23, #32]
    ldr     w1, [x23, #36]
    ldr     w2, [x23, #40]
    ldr     w3, [x23, #44]
    ldr     w4, [x23, #48]
    ldr     w5, [x23, #52]
    mov     w6, w21
    mov     w7, w25
    bl      fill_tri
    ldr     w0, [x23, #32]
    ldr     w1, [x23, #36]
    ldr     w2, [x23, #48]
    ldr     w3, [x23, #52]
    ldr     w4, [x23, #56]
    ldr     w5, [x23, #60]
    mov     w6, w21
    mov     w7, w25
    bl      fill_tri
    ldp     d14, d15, [sp, #128]
    ldp     d12, d13, [sp, #112]
    ldp     d10, d11, [sp, #96]
    ldp     d8, d9, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #240
    ret

draw_trains:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     d8, [sp, #48]
    mov     w20, #0
dtr_loop:
    ldr     w9, [x28, #G_NTRAIN]
    cmp     w20, w9
    b.ge    dtr_done
    LA      x19, trains
    add     x19, x19, x20, lsl #7
    ldr     w9, [x19]
    cbz     w9, dtr_next
    mov     w21, #0                     // vagao
dtr_car:
    scvtf   s0, w21
    FC      s1, F_VSP
    fmul    s0, s0, s1
    FC      s1, F_HALF
    fadd    s0, s0, s1
    mov     x0, x19
    bl      walk_back
    mov     w22, w1                     // sentido
    bl      seg_point
    cbz     w22, 1f
    fneg    s2, s2
    fneg    s3, s3
1:  cbnz    w21, 2f
    mov     w1, #96                     // locomotiva
    MOVI32  w2, 0xFF6E2018
    MOVI32  w3, 0xFFC0392B
    b       3f
2:  mov     w1, #80                     // vagao de passageiros
    MOVI32  w2, 0xFFB4B6B8
    ldr     w9, [x19, #112]
    LA      x10, carcolors
    ldr     w3, [x10, x9, lsl #2]
3:  FC      s4, F_HL
    FC      s5, F_HW
    bl      draw_box
    add     w21, w21, #1
    cmp     w21, #4
    b.lt    dtr_car
dtr_next:
    add     w20, w20, #1
    b       dtr_loop
dtr_done:
    ldr     d8, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// previa do trilho que sera construido
draw_preview:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     d8, d9, [sp, #64]
    ldr     w9, [x28, #G_TOOL]
    cmp     w9, #1
    b.ne    dpv_ret
    ldr     w19, [x28, #G_CHAIN]
    tbnz    w19, #31, dpv_ret
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, dpv_ret
    ldr     w9, [x28, #G_HOVU]
    scvtf   s8, w9
    FC      s2, F_INV64
    fmul    s8, s8, s2
    ldr     w9, [x28, #G_HOVV]
    scvtf   s9, w9
    fmul    s9, s9, s2
    mov     w0, w19
    fmov    s0, s8
    fmov    s1, s9
    bl      find_node_near
    mov     w20, w0
    tbnz    w20, #31, 1f
    LA      x9, nodes
    add     x9, x9, x20, lsl #6
    ldr     s8, [x9]
    ldr     s9, [x9, #4]
1:  mov     w0, w19
    mov     w1, w20
    fmov    s0, s8
    fmov    s1, s9
    bl      compute_curve
    MOVI32  w24, 0xFFE8382E             // vermelho = invalido
    cbnz    w0, dpv_line
    LA      x0, cur
    LA      x1, prevsamp
    mov     w2, #400
    bl      make_samples
    cbz     w0, dpv_line
    mov     w21, w0
    cbnz    w1, 2f
    MOVI32  w24, 0xFFFFD84A             // amarelo = ok
2:  LA      x22, prevsamp
    mov     w23, #0
3:  sub     w9, w21, #1
    cmp     w23, w9
    b.ge    dpv_ret
    add     x0, x22, x23, lsl #5
    fmov    s0, wzr
    mov     w1, #12
    bl      projoff
    str     w0, [sp, #80]
    str     w1, [sp, #84]
    add     w9, w23, #1
    add     x0, x22, x9, lsl #5
    fmov    s0, wzr
    mov     w1, #12
    bl      projoff
    mov     w3, w1
    mov     w2, w0
    ldr     w0, [sp, #80]
    ldr     w1, [sp, #84]
    mov     w4, w24
    mov     w5, #65535
    mov     w6, #2
    bl      line_z
    add     w23, w23, #1
    b       3b
dpv_line:                               // so uma reta vermelha
    LA      x9, nodes
    add     x9, x9, x19, lsl #6
    ldr     s0, [x9]
    ldr     s1, [x9, #4]
    bl      elev_at
    mov     w20, w0
    LA      x9, nodes
    add     x9, x9, x19, lsl #6
    ldr     s0, [x9]
    ldr     s1, [x9, #4]
    mov     w0, w20
    bl      proj
    str     w0, [sp, #80]
    str     w1, [sp, #84]
    fmov    s0, s8
    fmov    s1, s9
    bl      elev_at
    fmov    s0, s8
    fmov    s1, s9
    bl      proj
    mov     w3, w1
    mov     w2, w0
    ldr     w0, [sp, #80]
    ldr     w1, [sp, #84]
    mov     w4, w24
    mov     w5, #65535
    mov     w6, #2
    bl      line_z
dpv_ret:
    ldp     d8, d9, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// =====================================================================
//  Interface (texto, em espaco 640x360 com escala 2)
// =====================================================================

// rail_status: acrescenta trens/passageiros na linha de status (txt)
    .globl rail_status
rail_status:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    LA      x0, txt
1:  ldrb    w9, [x0]
    cbz     w9, 2f
    add     x0, x0, #1
    b       1b
2:  LA      x1, s_trens
    bl      strcat_cur
    mov     x19, x0
    mov     w1, #0                      // conta trens vivos
    ldr     w9, [x28, #G_NTRAIN]
    LA      x10, trains
3:  cbz     w9, 4f
    ldr     w11, [x10]
    cmp     w11, #0
    cinc    w1, w1, ne
    add     x10, x10, #128
    sub     w9, w9, #1
    b       3b
4:  mov     x0, x19
    bl      numcat
    LA      x1, s_pax
    bl      strcat_cur
    ldr     w1, [x28, #G_PAX]
    bl      numcat
    ldr     w9, [x28, #G_PAUSE]
    cbz     w9, 5f
    LA      x1, s_paused
    bl      strcat_cur
5:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// rail_ui: placas das estacoes, barra de ferramentas e mensagem
    .globl rail_ui
rail_ui:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    // placas das estacoes
    mov     w19, #0
ru_st:
    ldr     w9, [x28, #G_NST]
    cmp     w19, w9
    b.ge    ru_bar
    LA      x20, stations
    add     x20, x20, x19, lsl #6
    ldr     w9, [x20, #36]
    cbz     w9, ru_stn
    ldr     s0, [x20, #16]
    ldr     s1, [x20, #20]
    ldr     w0, [x20, #24]
    bl      proj
    asr     w21, w0, #1
    asr     w22, w1, #1
    sub     w22, w22, #18
    LA      x0, lbl
    add     x1, x20, #44
    bl      strcat_cur
    LA      x1, s_paren
    bl      strcat_cur
    ldr     w1, [x20, #12]
    bl      numcat
    LA      x1, s_paren2
    bl      strcat_cur
    LA      x0, lbl
    bl      mystrlen
    lsl     w0, w0, #3
    str     w0, [sp, #48]
    mov     w0, #25
    mov     w1, #70
    mov     w2, #150
    mov     w3, #210
    bl      setcolor
    ldr     w9, [sp, #48]
    sub     w0, w21, w9, lsr #1
    sub     w0, w0, #3
    sub     w1, w22, #3
    add     w2, w9, #6
    mov     w3, #13
    bl      fillrect
    mov     w0, #255
    mov     w1, #255
    mov     w2, #255
    mov     w3, #255
    bl      setcolor
    ldr     w9, [sp, #48]
    sub     w0, w21, w9, lsr #1
    mov     w1, w22
    LA      x2, lbl
    bl      text
ru_stn:
    add     w19, w19, #1
    b       ru_st
    // barra de ferramentas
ru_bar:
    mov     w0, #0
    mov     w1, #0
    mov     w2, #0
    mov     w3, #190
    bl      setcolor
    mov     w0, #0
    mov     w1, #346
    mov     w2, #640
    mov     w3, #14
    bl      fillrect
    mov     w19, #0
1:  ldr     w9, [x28, #G_TOOL]
    sub     w9, w9, #1
    cmp     w9, w19
    b.ne    2f
    mov     w0, #215
    mov     w1, #160
    mov     w2, #40
    mov     w3, #240
    b       3f
2:  mov     w0, #60
    mov     w1, #64
    mov     w2, #72
    mov     w3, #230
3:  bl      setcolor
    mov     w9, #92
    mul     w20, w19, w9
    add     w20, w20, #2
    mov     w0, w20
    mov     w1, #347
    mov     w2, #88
    mov     w3, #12
    bl      fillrect
    mov     w0, #255
    mov     w1, #255
    mov     w2, #255
    mov     w3, #255
    bl      setcolor
    add     w0, w20, #4
    mov     w1, #349
    LA      x2, toolnames
    add     x2, x2, x19, lsl #4
    bl      text
    add     w19, w19, #1
    cmp     w19, #5
    b.lt    1b
    mov     w0, #170
    mov     w1, #170
    mov     w2, #170
    mov     w3, #255
    bl      setcolor
    mov     w0, #464
    mov     w1, #349
    LA      x2, s_help2
    bl      text
    // mensagem
    ldr     w9, [x28, #G_MSGT]
    cbz     w9, ru_ret2
    ldr     x0, [x28, #G_MSG]
    bl      mystrlen
    lsl     w19, w0, #3
    mov     w0, #0
    mov     w1, #0
    mov     w2, #0
    mov     w3, #200
    bl      setcolor
    mov     w9, #640
    sub     w0, w9, w19
    asr     w0, w0, #1
    sub     w0, w0, #6
    mov     w1, #322
    add     w2, w19, #12
    mov     w3, #16
    bl      fillrect
    mov     w0, #255
    mov     w1, #230
    mov     w2, #140
    mov     w3, #255
    bl      setcolor
    mov     w0, #640
    mov     w1, #326
    ldr     x2, [x28, #G_MSG]
    mov     w3, #0
    bl      text_center
ru_ret2:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// =====================================================================
//  Teste automatico (usado por ./trilhos --shot)
//  Constroi uma linha perto de uma cidade, 2 estacoes, 1 sinal e 1 trem,
//  simula 900 quadros e imprime o estado do trem.
// =====================================================================
    .globl rail_selftest
rail_selftest:
    stp     x29, x30, [sp, #-128]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     d8, d9, [sp, #64]
    stp     d10, d11, [sp, #80]
    stp     d12, d13, [sp, #96]
    mov     w9, #1
    str     w9, [x28, #G_STATE]
    // procura uma reta de 40 celulas em terra firme saindo de uma cidade
    mov     w19, #0                     // cidade
rst_town:
    ldr     w9, [x28, #G_NTOWNS]
    cmp     w19, w9
    b.ge    rst_fail
    LA      x9, towns
    add     x9, x9, x19, lsl #6
    ldr     w10, [x9]
    scvtf   s8, w10
    ldr     w10, [x9, #4]
    scvtf   s9, w10
    mov     w20, #0                     // direcao
rst_dir:
    cmp     w20, #16
    b.ge    rst_ntown
    LA      x9, dirtab
    add     x9, x9, x20, lsl #2
    ldrsh   w10, [x9]
    scvtf   s10, w10
    ldrsh   w10, [x9, #2]
    scvtf   s11, w10
    FC      s0, F_INV64
    fmul    s10, s10, s0
    fmul    s11, s11, s0
    mov     w21, #0
1:  scvtf   s12, w21
    fmov    s0, #0.5
    fmul    s12, s12, s0
    fmov    s0, #6.0
    fadd    s12, s12, s0                // 6 .. 46 celulas
    fmadd   s0, s10, s12, s8
    fmadd   s1, s11, s12, s9
    bl      elev_at
    cmp     w0, #80
    b.lt    rst_ndir
    add     w21, w21, #1
    cmp     w21, #81
    b.lt    1b
    b       rst_found
rst_ndir:
    add     w20, w20, #1
    b       rst_dir
rst_ntown:
    add     w19, w19, #1
    b       rst_town
rst_found:
    // A = base + d*6, B = base + d*24 + perp*3, C = base + d*44
    mov     w9, #1
    str     w9, [x28, #G_TOOL]
    fmov    s12, #6.0
    fmadd   s0, s10, s12, s8
    fmadd   s1, s11, s12, s9
    bl      track_click
    mov     w9, #24
    scvtf   s12, w9
    fmadd   s0, s10, s12, s8
    fmadd   s1, s11, s12, s9
    fmov    s13, #3.0
    fmsub   s0, s11, s13, s0
    fmadd   s1, s10, s13, s1
    bl      track_click
    mov     w9, #44
    scvtf   s12, w9
    fmadd   s0, s10, s12, s8
    fmadd   s1, s11, s12, s9
    bl      track_click
    bl      tool_cancel
    // estacoes perto das pontas (pontos tirados do proprio trilho)
    mov     w9, #2
    str     w9, [x28, #G_TOOL]
    mov     w0, #0
    fmov    s0, #4.0
    bl      seg_point
    bl      station_click
    LA      x9, segs
    ldr     s0, [x9, #(128 + 32)]       // comprimento do trilho 1
    fmov    s1, #4.0
    fsub    s0, s0, s1
    mov     w0, #1
    bl      seg_point
    bl      station_click
    // um sinal no comeco do trilho 1
    mov     w9, #3
    str     w9, [x28, #G_TOOL]
    mov     w0, #1
    fmov    s0, #6.0
    bl      seg_point
    bl      signal_click
    // trem: estacao 0 -> estacao 1
    mov     w9, #4
    str     w9, [x28, #G_TOOL]
    LA      x9, stations
    ldr     s0, [x9, #16]
    ldr     s1, [x9, #20]
    bl      train_click
    LA      x9, stations
    ldr     s0, [x9, #80]
    ldr     s1, [x9, #84]
    bl      train_click
    bl      tool_cancel
    str     wzr, [x28, #G_TOOL]
    // simula
    mov     w19, #0
2:  bl      rail_update
    add     w19, w19, #1
    mov     w9, #2000
    cmp     w19, w9
    b.lt    2b
    // camera no trem
    LA      x0, trains
    FC      s0, F_HALF
    bl      walk_back
    bl      seg_point
    fsub    s2, s0, s1
    fadd    s3, s0, s1
    FC      s4, F_64
    fmul    s2, s2, s4
    fcvtzs  w9, s2
    str     w9, [x28, #G_CX]
    FC      s4, F_64
    fmul    s3, s3, s4
    fcvtzs  w9, s3
    asr     w9, w9, #1
    sub     w9, w9, w0
    str     w9, [x28, #G_CY]
    mov     w0, #2
    bl      set_zoom
    // imprime o estado
    LA      x0, txt
    LA      x1, s_t1
    bl      strcat_cur
    ldr     w1, [x28, #G_NSEG]
    bl      numcat
    LA      x1, s_t2
    bl      strcat_cur
    ldr     w1, [x28, #G_NST]
    bl      numcat
    LA      x1, s_t3
    bl      strcat_cur
    LA      x9, trains
    ldr     w1, [x9]
    bl      numcat
    LA      x1, s_t4
    bl      strcat_cur
    LA      x9, trains
    ldr     w1, [x9, #24]
    bl      numcat
    LA      x1, s_t5
    bl      strcat_cur
    LA      x9, trains
    ldr     w1, [x9, #64]
    bl      numcat
    LA      x1, s_t6
    bl      strcat_cur
    ldr     w1, [x28, #G_PAX]
    bl      numcat
    LA      x1, s_t7
    bl      strcat_cur
    LA      x9, trains
    ldr     s0, [x9, #12]
    fcvtzs  w1, s0
    bl      numcat
    LA      x1, s_nl2
    bl      strcat_cur
    LA      x9, txt
    sub     x2, x0, x9
    mov     x1, x9
    mov     w0, #1
    bl      F(write)
    b       rst_ret
rst_fail:
    LA      x1, s_tfail
    mov     w0, #1
    mov     x2, #24
    bl      F(write)
rst_ret:
    ldp     d12, d13, [sp, #96]
    ldp     d10, d11, [sp, #80]
    ldp     d8, d9, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #128
    ret

// =====================================================================
//  Dados
// =====================================================================
    .data
    .p2align 2
    .globl fconsts
fconsts:
    .float 64.0             // F_64
    .float 0.015625         // F_INV64
    .float 0.25             // F_STEP
    .float 0.42             // F_BALLAST
    .float 0.17             // F_RAIL
    .float 0.30             // F_SLEEPER
    .float 0.55             // F_PIN
    .float 0.95             // F_POUT
    .float 0.33333334       // F_THIRD
    .float 0.81             // F_SNAP2
    .float 0.64             // F_SEGHIT2
    .float 0.09             // F_VMAX
    .float 0.0012           // F_ACC
    .float 0.0025           // F_DEC
    .float 0.50             // F_HL
    .float 0.22             // F_HW
    .float 1.1              // F_VSP
    .float 4.4              // F_TLEN
    .float 2.5              // F_STHALF
    .float 10.0             // F_LOOK
    .float 0.45             // F_SIGM
    .float 1.0e30           // F_INF
    .float 0.35             // F_MINDOT
    .float 1.5              // F_MINLEN
    .float 48.0             // F_MAXLEN
    .float 0.65             // F_SIGOFF
    .float 1.9              // F_STOFF
    .float 0.5              // F_HALF
    .float -0.05            // F_M005
    .float 0.1              // F_TENTH
    .float 5.0              // F_STLEN
    .float 0.6              // F_EDGE
    .float 9.0              // F_STHIT2
    .float 1.21             // F_TRHIT2
    .float 1.0e29           // F_HUGE
    .float 0.03             // F_STOPEPS
    .float 5.3              // F_STMIN
    .float 0.5              // F_CLEAR2
    .float 0.81             // F_SIGHIT2

    .p2align 2
dirtab:
    .hword 64, 0,    59, 24,   45, 45,   24, 59
    .hword 0, 64,   -24, 59,  -45, 45,  -59, 24
    .hword -64, 0,  -59, -24, -45, -45, -24, -59
    .hword 0, -64,   24, -59,  45, -45,  59, -24

carcolors:
    .word 0xFF2E7D4F, 0xFF2F5D9E, 0xFFD9A62E, 0xFF8A3E8E

    .p2align 3
errmsgs:
    .quad 0, m_e1, m_e2, m_e3, m_e4, m_e5, m_e6, m_e7, m_e8
toolhints:
    .quad 0, m_h1, m_h2, m_h3, m_h4, m_h5
sigmsgs:
    .quad m_sig0, m_sig1, m_sig2

    .p2align 4
toolnames:
    .asciz "1 Trilho"
    .p2align 4
    .asciz "2 Estacao"
    .p2align 4
    .asciz "3 Sinal"
    .p2align 4
    .asciz "4 Trem"
    .p2align 4
    .asciz "5 Demolir"
    .p2align 4

m_e1:           .asciz "Trilho curto demais"
m_e2:           .asciz "Trilho longo demais: clique mais perto"
m_e3:           .asciz "Curva fechada demais"
m_e4:           .asciz "Nao da para construir sobre a agua"
m_e5:           .asciz "Limite atingido"
m_e6:           .asciz "Trilhos demais neste ponto"
m_e7:           .asciz "Nao da para dividir um trilho com estacao"
m_e8:           .asciz "Tem um trem neste trilho"
m_h1:           .asciz "Trilho: clique ponto a ponto. Botao direito termina"
m_h2:           .asciz "Estacao: clique sobre um trilho"
m_h3:           .asciz "Sinal: clique no trilho. Clique de novo para virar"
m_h4:           .asciz "Trem: clique na 1a estacao e depois nas paradas"
m_h5:           .asciz "Demolir: clique no que quer remover"
m_next:         .asciz "Clique o proximo ponto do trilho"
m_built:        .asciz "Trilho construido. Continue ou use o botao direito"
m_connected:    .asciz "Trilhos conectados!"
m_clicktrack:   .asciz "Clique sobre um trilho"
m_hasstation:   .asciz "Este trilho ja tem uma estacao"
m_shorttrack:   .asciz "Trilho curto demais para uma estacao"
m_limit:        .asciz "Limite atingido"
m_station:      .asciz "Estacao construida"
m_toomanysig:   .asciz "Sinais demais neste trilho"
m_signal:       .asciz "Sinal criado (clique nele de novo para virar)"
m_sig0:         .asciz "Sinal: sentido A"
m_sig1:         .asciz "Sinal: sentido B"
m_sig2:         .asciz "Sinal: nos dois sentidos"
m_clickstation: .asciz "Clique em uma estacao"
m_trainorders:  .asciz "Agora clique nas paradas. Botao direito termina"
m_orderadded:   .asciz "Parada adicionada"
m_ordersame:    .asciz "Essa ja e a ultima parada"
m_trainstart:   .asciz "Trem partiu!"
m_needtwo:      .asciz "Um trem precisa de pelo menos 2 estacoes"
m_deltrain:     .asciz "Trem removido"
m_delsig:       .asciz "Sinal removido"
m_delstation:   .asciz "Estacao removida"
m_delseg:       .asciz "Trilho removido"
m_segstation:   .asciz "Remova a estacao primeiro"
m_segtrain:     .asciz "Tem um trem neste trilho"
m_nothing:      .asciz "Nada para remover aqui"
s_estacao:      .asciz "Estacao "
s_trens:        .asciz "   -   Trens: "
s_pax:          .asciz "   Passageiros: "
s_paused:       .asciz "   PAUSADO"
s_paren:        .asciz " ("
s_paren2:       .asciz ")"
s_help2:        .asciz "dir: mover  esp: pausa"
s_t1:           .asciz "teste: trilhos="
s_t2:           .asciz " estacoes="
s_t3:           .asciz " trem.estado="
s_t4:           .asciz " parada="
s_t5:           .asciz " a_bordo="
s_t6:           .asciz " entregues="
s_t7:           .asciz " s="
s_nl2:          .asciz "\n"
s_tfail:        .asciz "teste: sem lugar p/ linha\n"

// ---- memoria ------------------------------------------------------------
GBSS nodes,    131072
GBSS segs,     262144
GBSS samples,  4194304
GBSS stations, 2048
GBSS signals,  4096
GBSS trains,   8192
GBSS uparent,  40960
GBSS ublock,   40960
GBSS uocc,     10240
GBSS dist,     524288
GBSS tmpu,     512
GBSS tmpv,     512
GBSS tmpc,     512
GBSS cur,      64
GBSS cur2,     64
GBSS prevsamp, 13312
GBSS lbl,      64
