// =====================================================================
//  construcoes.S - os desenhos novos das construcoes no mundo
//
//  Os quadros vem de estruturas.S (gerado do canvas do designer). Aqui o
//  jogo escolhe o quadro de cada objeto conforme o estado:
//    bau aberto/fechado, cerca pelos vizinhos, portao aberto quando tem
//    alguem perto, casa com as janelas acesas de noite, fornalha acesa
//    quando o ferreiro trabalha (ou voce esta do lado), lampiao aceso de
//    noite, pilhas pelo tamanho (pouco, metade, cheia).
//  Fogueira acesa (animada) e as cinzas da que apagou (somem em 1 dia).
//  De perto: metade da escala, o dobro de detalhe (como os personagens);
//  no zoom mais longe, a versao reduzida.
// =====================================================================

#include "comum.h"
#include "pessoas.h"
#include "estruturas.h"

.equ MAXASH,    32                      // cinzas: 16 bytes (u, v, e, idade)
.equ NIGHTLIT,  64                      // G_NIGHTK a partir do qual acende

    .text
    .p2align 2

// estr_blit(w0 = quadro, w1 = x, w2 = y, w3 = escala dos sprites,
//           w4 = profundidade, w5 = variante)   folha (como blit)
    .globl estr_blit
estr_blit:
    LA      x9, estrtab
    add     x9, x9, x0, lsl #4
    cmp     w3, #2
    b.lt    1f
    ldr     x0, [x9]
    lsr     w3, w3, #1
    b       blit
1:  ldr     x0, [x9, #8]
    mov     w3, #1
    b       blit

// near_someone(w0 = u, w1 = v em 1/64, w2 = raio^2 em (1/64)^2)
// -> w0 = 1 se voce ou alguem da vila esta ali perto   folha
near_someone:
    scvtf   s0, w0
    scvtf   s1, w1
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    scvtf   s3, w2
    FC      s2, F_INV64
    fmul    s3, s3, s2
    fmul    s3, s3, s2                  // raio^2 em celulas
    ldr     s4, [x28, #G_PU]
    fsub    s4, s4, s0
    ldr     s5, [x28, #G_PV]
    fsub    s5, s5, s1
    fmul    s4, s4, s4
    fmadd   s4, s5, s5, s4
    mov     w0, #1
    fcmp    s4, s3
    b.le    9f
    ldr     w9, [x28, #G_NOPEOPLE]
    cbnz    w9, 8f
    LA      x9, people
    mov     w10, #MAXPEOPLE
1:  ldrb    w11, [x9, #P_ALIVE]
    cbz     w11, 2f
    ldrb    w11, [x9, #P_FLAGS]         // dentro de casa nao conta
    tbnz    w11, #0, 2f
    ldr     s4, [x9, #P_U]
    fsub    s4, s4, s0
    ldr     s5, [x9, #P_V]
    fsub    s5, s5, s1
    fmul    s4, s4, s4
    fmadd   s4, s5, s5, s4
    fcmp    s4, s3
    b.le    9f
2:  add     x9, x9, #PSIZE
    subs    w10, w10, #1
    b.ne    1b
8:  mov     w0, #0
9:  ret

// smelting_near(w0 = u, w1 = v em 1/64) -> w0 = 1 se o ferreiro esta
// trabalhando nessa fornalha (ou voce esta a ate 2,5 celulas)   folha
smelting_near:
    scvtf   s0, w0
    scvtf   s1, w1
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    ldr     s4, [x28, #G_PU]
    fsub    s4, s4, s0
    ldr     s5, [x28, #G_PV]
    fsub    s5, s5, s1
    fmul    s4, s4, s4
    fmadd   s4, s5, s5, s4
    fmov    s3, #6.25
    mov     w0, #1
    fcmp    s4, s3
    b.le    9f
    ldr     w9, [x28, #G_NOPEOPLE]
    cbnz    w9, 8f
    fmov    s3, #2.5                    // 1,6 celula
    LA      x9, people
    mov     w10, #MAXPEOPLE
1:  ldrb    w11, [x9, #P_ALIVE]
    cbz     w11, 2f
    ldrb    w11, [x9, #P_STATE]
    cmp     w11, #ST_WORK
    b.ne    2f
    ldrb    w11, [x9, #P_WKIND]
    cmp     w11, #WK_SMELT
    b.ne    2f
    ldr     s4, [x9, #P_U]
    fsub    s4, s4, s0
    ldr     s5, [x9, #P_V]
    fsub    s5, s5, s1
    fmul    s4, s4, s4
    fmadd   s4, s5, s5, s4
    fcmp    s4, s3
    b.le    9f
2:  add     x9, x9, #PSIZE
    subs    w10, w10, #1
    b.ne    1b
8:  mov     w0, #0
9:  ret

// anim(w0 = quadros de jogo por quadro do desenho, w1 = quantos) -> w0
anim:
    ldr     w9, [x28, #G_FRAME]
    udiv    w9, w9, w0
    udiv    w10, w9, w1
    msub    w0, w10, w1, w9
    ret

// obj_frame(w0 = tipo, w1 = variante, w2 = u, w3 = v em 1/64) -> w0 =
// quadro de estruturas.S (-1: sprite antigo)
    .globl obj_frame
obj_frame:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    mov     w22, w3
    lsr     w9, w2, #6                  // celula
    lsr     w10, w3, #6
    add     w9, w9, w10, lsl #9
    cmp     w19, #O_CHEST
    b.ne    10f
    ldr     w10, [x28, #G_CHESTOPEN]    // bau aberto por voce
    sub     w10, w10, #1
    mov     w0, #EF_BAU_FECHADO
    cmp     w10, w20
    cinc    w0, w0, eq
    b       99f
10: mov     w0, #EF_ABRIGO_NORMAL
    cmp     w19, #O_SHELTER
    b.eq    99f
    cmp     w19, #O_FENCE
    b.ne    20f
    LA      x10, fencegrid              // trilhos para os vizinhos em +u, +v
    add     x10, x10, w9, uxtw
    mov     w0, #EF_CERCA_POSTE
    ldrb    w11, [x10, #1]
    cmp     w11, #0
    cinc    w0, w0, ne
    ldrb    w11, [x10, #512]
    cbz     w11, 99f
    add     w0, w0, #2
    b       99f
20: cmp     w19, #O_GATE
    b.ne    30f
    LA      x10, fencegrid              // na fileira de u ou de v?
    add     x10, x10, w9, uxtw
    ldurb   w11, [x10, #-1]
    ldrb    w12, [x10, #1]
    orr     w11, w11, w12
    mov     w20, #EF_PORTAO_U_FECHADO
    cbnz    w11, 21f
    mov     w20, #EF_PORTAO_V_FECHADO
21: mov     w0, w21                     // alguem passando: aberto
    mov     w1, w22
    mov     w2, #6400                   // 1,25 celula
    bl      near_someone
    add     w0, w20, w0
    b       99f
30: mov     w0, #EF_BARRACO_NORMAL
    cmp     w19, #O_HUT
    b.eq    99f
    cmp     w19, #O_HOUSE
    b.ne    40f
    ldr     w9, [x28, #G_NIGHTK]        // de noite: janelas acesas
    mov     w0, #EF_CASA_DIA
    cmp     w9, #NIGHTLIT
    cinc    w0, w0, ge
    b       99f
40: cmp     w19, #O_LAMP
    b.ne    50f
    ldr     w9, [x28, #G_NIGHTK]
    mov     w0, #EF_LAMPIAO_APAGADO
    cmp     w9, #NIGHTLIT
    cinc    w0, w0, ge
    b       99f
50: cmp     w19, #O_FURNACE
    b.ne    60f
    mov     w0, w21
    mov     w1, w22
    bl      smelting_near
    mov     w9, w0
    mov     w0, #EF_FORNALHA_APAGADA
    cbz     w9, 99f
    mov     w0, #10                     // 160 ms por quadro
    mov     w1, #3
    bl      anim
    add     w0, w0, #EF_FORNALHA_ACESA1
    b       99f
60: mov     w0, w19                     // pilha
    bl      pile_item
    tbnz    w0, #31, 98f
    LA      x9, pilekind
    ldrb    w10, [x9, x0]
    cmp     w10, #255
    b.eq    98f
    LA      x9, pilebase
    ldrh    w11, [x9, x10, lsl #1]
    LA      x9, stackcap                // pouco, metade, cheia
    ldrb    w12, [x9, x0]
    cmp     w12, #0
    mov     w13, #10
    csel    w12, w13, w12, eq
    mov     w13, #3
    mul     w13, w20, w13               // quantidade * 3
    cmp     w13, w12
    b.ls    61f
    add     w11, w11, #1
    cmp     w13, w12, lsl #1
    b.ls    61f
    add     w11, w11, #1
61: mov     w0, w11
    b       99f
98: mov     w0, #-1
99: ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// fire_frame -> w0 = quadro da fogueira acesa agora (130 ms por quadro)
    .globl fire_frame
fire_frame:
    mov     w0, #8
    mov     w1, #4
    b       anim

// ---------------------------------------------------------------------
//  Cinzas: a fogueira que apagou fica no chao (apagada) por 1 dia
// ---------------------------------------------------------------------

// ash_add(x0 = a fogueira na lista fires)   folha
    .globl ash_add
ash_add:
    LA      x9, ashes
    mov     w10, #0                     // vaga livre (ou a mais velha)
    mov     w11, #0
    mov     w12, #-1
1:  add     x13, x9, x10, lsl #4
    ldr     w14, [x13, #12]
    cbz     w14, 3f
    cmp     w14, w12
    b.ls    2f
    mov     w12, w14
    mov     w11, w10
2:  add     w10, w10, #1
    cmp     w10, #MAXASH
    b.lt    1b
    mov     w10, w11
3:  add     x13, x9, x10, lsl #4
    ldp     w14, w15, [x0]
    stp     w14, w15, [x13]
    ldr     w14, [x0, #8]
    str     w14, [x13, #8]
    mov     w14, #1
    str     w14, [x13, #12]
    ret

// ash_clear(s0 = u, s1 = v): fogueira nova ali: as cinzas somem   folha
    .globl ash_clear
ash_clear:
    fcvtzs  w0, s0
    fcvtzs  w1, s1
    LA      x9, ashes
    mov     w10, #MAXASH
1:  ldr     s2, [x9]
    fcvtzs  w11, s2
    ldr     s2, [x9, #4]
    fcvtzs  w12, s2
    cmp     w11, w0
    b.ne    2f
    cmp     w12, w1
    b.ne    2f
    str     wzr, [x9, #12]
2:  add     x9, x9, #16
    subs    w10, w10, #1
    b.ne    1b
    ret

// ash_update: envelhecem; com 1 dia somem   folha
    .globl ash_update
ash_update:
    LA      x9, ashes
    mov     w10, #MAXASH
    MOVI32  w12, DAYLEN
1:  ldr     w11, [x9, #12]
    cbz     w11, 2f
    add     w11, w11, #1
    cmp     w11, w12
    csel    w11, wzr, w11, hs
    str     w11, [x9, #12]
2:  add     x9, x9, #16
    subs    w10, w10, #1
    b.ne    1b
    ret

// ash_reset: mundo novo / jogo carregado: sem cinzas   folha
    .globl ash_reset
ash_reset:
    LA      x9, ashes
    mov     w10, #(MAXASH * 2)
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #2
    b.ne    1b
    ret

// ash_draw(w0 = escala dos sprites)
    .globl ash_draw
ash_draw:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    mov     w21, w0
    mov     w19, #0
1:  LA      x20, ashes
    add     x20, x20, x19, lsl #4
    ldr     w9, [x20, #12]
    cbz     w9, 2f
    ldr     s0, [x20]
    ldr     s1, [x20, #4]
    ldr     w0, [x20, #8]
    bl      proj
    add     w4, w2, #4
    mov     w2, w1
    mov     w1, w0
    mov     w0, #EF_FOGUEIRA_APAGADA
    mov     w3, w21
    mov     w5, #0
    bl      estr_blit
2:  add     w19, w19, #1
    cmp     w19, #MAXASH
    b.lt    1b
    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

    .data
// tipo de pilha de cada item (PK_*; 255 = nao vira pilha)
pilekind:
    .byte PK_TORAS, PK_PEDRA, PK_FRUTAS, PK_FERRAMENTAS      // madeira pedra frutas machado
    .byte PK_FERRAMENTAS, PK_FERRAMENTAS, PK_FRUTAS, PK_FERRAMENTAS // picareta tocha assadas cesto
    .byte 255, 255, 255, PK_FERRAMENTAS                      // fogueira bau abrigo arco
    .byte PK_FERRAMENTAS, PK_CARNE, PK_CARNE, PK_COURO       // flechas carne carne assada couro
    .byte PK_COURO, PK_COURO, 255, 255                       // roupa mochila cerca portao
    .byte PK_FERRAMENTAS, PK_PEIXE, PK_PEIXE, PK_FERRAMENTAS // vara peixe peixe assado enxada
    .byte PK_SEMENTES, PK_TRIGO, PK_PAO, PK_MINERIO          // sementes trigo pao minerio
    .byte PK_CARVAO, PK_FERRO, 255, PK_FERRAMENTAS           // carvao ferro fornalha machado ferro
    .byte PK_FERRAMENTAS, PK_FERRAMENTAS, PK_FERRAMENTAS, PK_FERRAMENTAS // picareta enxada espada armadura
    .byte 255, 255, 255, 255, 255, 255, 255, 255             // lampiao estrada ...
    .byte 255, 255, 255, 255, 255, 255, 255, 255

GBSS ashes, (MAXASH * 16)
