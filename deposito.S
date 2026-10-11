// =====================================================================
//  deposito.S - depositos: zonas pintadas onde a vila empilha as coisas
//
//  - Quatro tipos de zona (Z, 5 a 8): Comida, Materiais, Ferramentas e
//    armas, e Geral (aceita tudo). As construcoes (fogueira, bau, abrigo,
//    cerca, portao, fornalha, lampiao) nao vao para deposito.
//  - Cada quadrado do deposito guarda UMA pilha de um item, ate um limite
//    (20 madeiras, 15 pedras, 40 sementes, 3 machados...). A pilha e um
//    objeto no chao (a mesma pilha de quando se larga um item): aparece no
//    mapa, voce pode pegar e ela estraga como comida no chao.
//  - Os moradores nao usam mais baus: levam a carga ao deposito mais perto
//    que tenha lugar, comem, pegam sementes, ferramentas e material nos
//    depositos. Cada viagem usa as pilhas a ate 5 celulas de onde chegou
//    (a "loja" ali): a funcao store_gather soma essas pilhas num quadro de
//    48 contadores (como um bau), o resto do codigo mexe nos contadores
//    como antes e store_close tira e poe as pilhas de verdade.
//  - Voce: botao direito num quadrado de deposito abre a janela dele (no
//    lugar do bau); clique pega, clique na sua mochila guarda.
// =====================================================================

#include "comum.h"
#include "pessoas.h"

.equ MAXDC,     4096                    // quadrados de deposito na lista
.equ MAXDP,     2048                    // pilhas em deposito na lista
.equ STR2,      25                      // a "loja": ate 5 celulas

    .text
    .p2align 2

// ---------------------------------------------------------------------
//  Itens e pilhas
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

// pile_type(w0 = item) -> w0 = tipo da pilha (-1 se nao vai para deposito)
// folha (w0, w1)
    .globl pile_type
pile_type:
    cmp     w0, #NITEMS
    b.hs    8f
    LA      x1, itemcat
    ldrb    w1, [x1, x0]
    cbz     w1, 8f
    cmp     w0, #IT_SEED
    b.hs    1f
    add     w0, w0, #O_LOGS
    ret
1:  cmp     w0, #IT_ORE
    b.hs    2f
    add     w0, w0, #(O_PILE2 - IT_SEED)
    ret
2:  add     w0, w0, #(O_PILE3 - IT_ORE)
    ret
8:  mov     w0, #-1
    ret

// dep_accepts(w0 = zona, w1 = item) -> w0 = 1 se esse deposito aceita
// folha (x0-x2)
    .globl dep_accepts
dep_accepts:
    sub     w0, w0, #Z_DEPF
    cmp     w0, #3
    b.hi    8f
    cmp     w1, #NITEMS
    b.hs    8f
    LA      x2, itemcat
    ldrb    w2, [x2, x1]
    cbz     w2, 8f
    cmp     w0, #3                      // geral: tudo
    b.eq    7f
    add     w0, w0, #1                  // comida 1, materiais 2, ferramentas 3
    cmp     w0, w2
    cset    w0, eq
    ret
7:  mov     w0, #1
    ret
8:  mov     w0, #0
    ret

// dep_dirty: as listas precisam ser refeitas   folha
    .globl dep_dirty
dep_dirty:
    mov     w9, #1
    str     w9, [x28, #G_DEPDIRTY]
    ret

// dep_rebuild: refaz a lista de quadrados de deposito, a de pilhas dentro
// deles e quais quadrados estao ocupados (so quando algo mudou)
    .globl dep_rebuild
dep_rebuild:
    ldr     w9, [x28, #G_DEPDIRTY]
    cbnz    w9, 1f
    ret
1:  stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     wzr, [x28, #G_DEPDIRTY]
    LA      x19, zonegrid
    LA      x20, depcells
    LA      x23, depocc
    mov     w21, #0
    mov     w22, #0
2:  strb    wzr, [x23, x22]
    ldrb    w9, [x19, x22]
    sub     w9, w9, #Z_DEPF
    cmp     w9, #3
    b.hi    3f
    cmp     w21, #MAXDC
    b.hs    3f
    str     w22, [x20, x21, lsl #2]
    add     w21, w21, #1
3:  add     w22, w22, #1
    cmp     w22, #(MAPN * MAPN / 4096), lsl #12
    b.lo    2b
    LA      x9, ndc
    str     w21, [x9]
    LA      x19, objs                   // objetos dentro de depositos
    ldr     w20, [x28, #G_NOBJ]
    LA      x24, deplist
    mov     w21, #0
    mov     w22, #0
4:  cmp     w21, w20
    b.ge    9f
    add     x9, x19, x21, lsl #3
    ldrb    w0, [x9, #6]
    cmp     w0, #O_GONE
    b.eq    5f
    ldrh    w10, [x9]
    lsr     w10, w10, #6
    ldrh    w11, [x9, #2]
    lsr     w11, w11, #6
    add     w10, w10, w11, lsl #9
    LA      x11, zonegrid
    ldrb    w11, [x11, w10, uxtw]
    sub     w11, w11, #Z_DEPF
    cmp     w11, #3
    b.hi    5f
    mov     w12, #1
    strb    w12, [x23, w10, uxtw]
    bl      pile_item
    tbnz    w0, #31, 5f
    cmp     w22, #MAXDP
    b.hs    5f
    str     w21, [x24, x22, lsl #2]
    add     w22, w22, #1
5:  add     w21, w21, #1
    b       4b
9:  LA      x9, ndep
    str     w22, [x9]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
//  A "loja": as pilhas a ate 5 celulas de um ponto
// ---------------------------------------------------------------------

// store_gather(s0 = u, s1 = v) -> x0 = stmp (48 contadores: o que tem nas
// pilhas em volta). Guarda o ponto para store_close.
    .globl store_gather
store_gather:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    fcvtzs  w19, s0
    fcvtzs  w20, s1
    LA      x9, stanc
    stp     w19, w20, [x9]
    bl      dep_rebuild
    LA      x9, stmp
    mov     w10, #12
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    LA      x21, deplist
    LA      x9, ndep
    ldr     w22, [x9]
2:  cbz     w22, 7f
    ldr     w9, [x21], #4
    LA      x10, objs
    add     x10, x10, x9, lsl #3
    ldrb    w0, [x10, #6]
    bl      pile_item
    tbnz    w0, #31, 6f
    ldrh    w11, [x10]
    lsr     w11, w11, #6
    sub     w11, w11, w19
    ldrh    w12, [x10, #2]
    lsr     w12, w12, #6
    sub     w12, w12, w20
    mul     w11, w11, w11
    madd    w11, w12, w12, w11
    cmp     w11, #STR2
    b.gt    6f
    ldrb    w12, [x10, #7]
    LA      x13, stmp
    ldr     w14, [x13, x0, lsl #2]
    add     w14, w14, w12
    str     w14, [x13, x0, lsl #2]
6:  sub     w22, w22, #1
    b       2b
7:  LA      x9, stmp
    LA      x10, stbase
    mov     w11, #24
8:  ldr     x12, [x9], #8
    str     x12, [x10], #8
    subs    w11, w11, #1
    b.ne    8b
    LA      x0, stmp
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// store_cell(w0 = celula) -> x0 = stmp da loja em volta dela (0 se -1)
    .globl store_cell
store_cell:
    tbz     w0, #31, 1f
    mov     x0, #0
    ret
1:  and     w9, w0, #511
    lsr     w10, w0, #9
    scvtf   s0, w9
    scvtf   s1, w10
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    b       store_gather

// st_take(w0 item, w1 quantos) -> w0 = quantos tirou das pilhas da loja
st_take:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     w20, w1                     // falta
    mov     w23, #0                     // tirou
    bl      pile_type
    tbnz    w0, #31, 9f
    mov     w19, w0
    LA      x9, stanc
    ldp     w21, w22, [x9]
    LA      x24, deplist
    LA      x9, ndep
    ldr     w9, [x9]
    str     w9, [sp, #-16]!
1:  ldr     w9, [sp]
    cbz     w9, 8f
    sub     w9, w9, #1
    str     w9, [sp]
    cbz     w20, 8f
    ldr     w9, [x24], #4
    LA      x10, objs
    add     x10, x10, x9, lsl #3
    ldrb    w11, [x10, #6]
    cmp     w11, w19
    b.ne    1b
    ldrh    w11, [x10]
    lsr     w11, w11, #6
    ldrh    w12, [x10, #2]
    lsr     w12, w12, #6
    sub     w13, w11, w21
    sub     w14, w12, w22
    mul     w13, w13, w13
    madd    w13, w14, w14, w13
    cmp     w13, #STR2
    b.gt    1b
    ldrb    w13, [x10, #7]
    cmp     w13, w20
    csel    w14, w13, w20, lo           // tira o que der
    sub     w13, w13, w14
    strb    w13, [x10, #7]
    sub     w20, w20, w14
    add     w23, w23, w14
    cbnz    w13, 1b
    mov     w13, #O_GONE                // acabou a pilha
    strb    w13, [x10, #6]
    add     w11, w11, w12, lsl #9
    LA      x12, depocc
    strb    wzr, [x12, w11, uxtw]
    b       1b
8:  add     sp, sp, #16
9:  mov     w0, w23
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// st_put(w0 item, w1 quantos) -> w0 = quantos pos: primeiro nas pilhas
// desse item que tem lugar, depois em quadrados vazios que aceitam
st_put:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     x27, [sp, #80]
    mov     w25, w0                     // item
    mov     w20, w1                     // falta
    mov     w23, #0                     // pos
    bl      pile_type
    tbnz    w0, #31, 9f
    mov     w19, w0
    LA      x9, stackcap
    ldrb    w26, [x9, x25]              // cabe numa pilha
    cbz     w26, 9f
    LA      x9, stanc
    ldp     w21, w22, [x9]
    // ---- 1: pilhas que ja existem ----
    LA      x24, deplist
    LA      x9, ndep
    ldr     w27, [x9]
1:  cbz     w27, 3f
    cbz     w20, 9f
    sub     w27, w27, #1
    ldr     w9, [x24], #4
    LA      x10, objs
    add     x10, x10, x9, lsl #3
    ldrb    w11, [x10, #6]
    cmp     w11, w19
    b.ne    1b
    ldrh    w11, [x10]
    lsr     w11, w11, #6
    ldrh    w12, [x10, #2]
    lsr     w12, w12, #6
    sub     w13, w11, w21
    sub     w14, w12, w22
    mul     w13, w13, w13
    madd    w13, w14, w14, w13
    cmp     w13, #STR2
    b.gt    1b
    add     w11, w11, w12, lsl #9       // o deposito aceita?
    LA      x12, zonegrid
    ldrb    w0, [x12, w11, uxtw]
    mov     w1, w25
    bl      dep_accepts
    cbz     w0, 1b
    ldrb    w13, [x10, #7]
    subs    w14, w26, w13               // lugar
    b.ls    1b
    cmp     w14, w20
    csel    w14, w14, w20, lo
    add     w13, w13, w14
    strb    w13, [x10, #7]
    sub     w20, w20, w14
    add     w23, w23, w14
    b       1b
    // ---- 2: quadrados vazios ----
3:  LA      x24, depcells
    LA      x9, ndc
    ldr     w27, [x9]
4:  cbz     w27, 9f
    cbz     w20, 9f
    sub     w27, w27, #1
    ldr     w9, [x24], #4               // celula
    and     w10, w9, #511
    lsr     w11, w9, #9
    sub     w12, w10, w21
    sub     w13, w11, w22
    mul     w12, w12, w12
    madd    w12, w13, w13, w12
    cmp     w12, #STR2
    b.gt    4b
    LA      x12, depocc
    ldrb    w12, [x12, w9, uxtw]
    cbnz    w12, 4b
    str     w9, [sp, #88]
    LA      x12, zonegrid
    ldrb    w0, [x12, w9, uxtw]
    mov     w1, w25
    bl      dep_accepts
    cbz     w0, 4b
    ldr     w9, [sp, #88]
    and     w10, w9, #511
    lsr     w11, w9, #9
    LA      x12, elev                   // na agua nao
    ldrsh   w12, [x12, w9, uxtw #1]
    ldr     w13, [x28, #G_FLOOD]
    cmp     w12, w13
    b.lt    4b
    lsl     w0, w10, #6                 // pilha nova no meio do quadrado
    add     w0, w0, #32
    lsl     w1, w11, #6
    add     w1, w1, #32
    str     w0, [sp, #-16]!
    str     w1, [sp, #4]
    bl      sample_elev
    mov     w2, w0
    ldr     w0, [sp]
    ldr     w1, [sp, #4]
    add     sp, sp, #16
    cmp     w26, w20
    csel    w4, w26, w20, lo
    str     w4, [sp, #92]
    mov     w3, w19
    bl      add_obj
    ldr     w9, [x28, #G_NOBJ]
    sub     w9, w9, #1
    LA      x10, memtype
    strb    w19, [x10, x9]
    LA      x10, ndep                   // entra na lista
    ldr     w11, [x10]
    cmp     w11, #MAXDP
    b.hs    5f
    LA      x12, deplist
    str     w9, [x12, x11, lsl #2]
    add     w11, w11, #1
    str     w11, [x10]
5:  ldr     w9, [sp, #88]
    LA      x12, depocc
    mov     w13, #1
    strb    w13, [x12, w9, uxtw]
    ldr     w4, [sp, #92]
    sub     w20, w20, w4
    add     w23, w23, w4
    b       4b
9:  mov     w0, w23
    ldr     x27, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// store_close -> x0 = stover (o que nao coube, por item): aplica nas
// pilhas a diferenca entre stmp e o que tinha (stbase)
    .globl store_close
store_close:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, #0
1:  LA      x9, stover
    str     wzr, [x9, x19, lsl #2]
    LA      x9, stmp
    ldr     w10, [x9, x19, lsl #2]
    LA      x9, stbase
    ldr     w11, [x9, x19, lsl #2]
    subs    w20, w10, w11
    b.eq    8f
    b.gt    2f
    mov     w0, w19                     // tirou
    neg     w1, w20
    bl      st_take
    b       8f
2:  mov     w0, w19                     // pos
    mov     w1, w20
    bl      st_put
    sub     w20, w20, w0
    LA      x9, stover
    str     w20, [x9, x19, lsl #2]
8:  add     w19, w19, #1
    cmp     w19, #NITEMS
    b.lt    1b
    LA      x9, stmp                    // agora a loja e isto
    LA      x10, stbase
    mov     w11, #24
9:  ldr     x12, [x9], #8
    str     x12, [x10], #8
    subs    w11, w11, #1
    b.ne    9b
    LA      x0, stover
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// store_close_back: fecha a loja e o que nao coube volta para a mochila
// da pessoa (x20)
    .globl store_close_back
store_close_back:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x21, [sp, #16]
    bl      store_close
    mov     w21, #0
1:  LA      x9, stover
    ldr     w1, [x9, x21, lsl #2]
    cbz     w1, 2f
    mov     w0, w21
    bl      pinv_add
2:  add     w21, w21, #1
    cmp     w21, #NITEMS
    b.lt    1b
    ldr     x21, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
//  Achar um deposito (a partir de s0, s1 = u, v)
// ---------------------------------------------------------------------

// dep_count_at(w0 u, w1 v, w2 tipo de pilha) -> w0 = soma das pilhas
// desse tipo a ate 5 celulas   folha
dep_count_at:
    mov     w3, #0
    LA      x4, deplist
    LA      x5, ndep
    ldr     w5, [x5]
    LA      x6, objs
1:  cbz     w5, 9f
    sub     w5, w5, #1
    ldr     w7, [x4], #4
    add     x7, x6, x7, lsl #3
    ldrb    w8, [x7, #6]
    cmp     w8, w2
    b.ne    1b
    ldrh    w8, [x7]
    lsr     w8, w8, #6
    sub     w8, w8, w0
    ldrh    w9, [x7, #2]
    lsr     w9, w9, #6
    sub     w9, w9, w1
    mul     w8, w8, w8
    madd    w8, w9, w9, w8
    cmp     w8, #STR2
    b.gt    1b
    ldrb    w8, [x7, #7]
    add     w3, w3, w8
    b       1b
9:  mov     w0, w3
    ret

// dep_find_take(s0, s1, w0 item, w1 quantos, w2 item 2, w3 quantos 2)
// -> w0 = celula de uma pilha com a loja em volta tendo isso (-1)
    .globl dep_find_take
dep_find_take:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    cbnz    w1, 1f                      // o primeiro nao precisa: troca
    cbz     w3, 70f                     // nenhum: qualquer deposito
    mov     w0, w2
    mov     w1, w3
    mov     w3, #0
1:  fcvtzs  w19, s0
    fcvtzs  w20, s1
    mov     w21, w1                     // quantos
    mov     w22, w3                     // quantos 2
    str     w2, [sp, #-16]!
    bl      pile_type
    mov     w23, w0                     // tipo
    ldr     w0, [sp], #16
    mov     w24, #-1
    cbz     w22, 2f
    bl      pile_type
    mov     w24, w0                     // tipo 2
2:  tbnz    w23, #31, 80f
    bl      dep_rebuild
    mov     w25, #-1                    // melhor celula
    mov     w26, #0x7FFFFFFF
    mov     w27, #0
3:  LA      x9, ndep
    ldr     w9, [x9]
    cmp     w27, w9
    b.ge    9f
    LA      x9, deplist
    ldr     w9, [x9, x27, lsl #2]
    add     w27, w27, #1
    LA      x10, objs
    add     x10, x10, x9, lsl #3
    ldrb    w11, [x10, #6]
    cmp     w11, w23
    b.ne    3b
    ldrb    w11, [x10, #7]
    cbz     w11, 3b
    ldrh    w11, [x10]
    lsr     w11, w11, #6
    ldrh    w12, [x10, #2]
    lsr     w12, w12, #6
    sub     w13, w11, w19
    sub     w14, w12, w20
    mul     w13, w13, w13
    madd    w13, w14, w14, w13
    cmp     w13, w26
    b.ge    3b
    stp     w11, w12, [sp, #-16]!
    str     w13, [sp, #8]
    mov     w0, w11
    mov     w1, w12
    mov     w2, w23
    bl      dep_count_at
    cmp     w0, w21
    b.lo    4f
    tbnz    w24, #31, 5f
    ldp     w0, w1, [sp]
    mov     w2, w24
    bl      dep_count_at
    cmp     w0, w22
    b.lo    4f
5:  ldp     w11, w12, [sp]
    ldr     w26, [sp, #8]
    add     w25, w11, w12, lsl #9
4:  add     sp, sp, #16
    b       3b
70: bl      dep_find_any
    b       90f
80: mov     w0, #-1
    b       90f
9:  mov     w0, w25
90: ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// dep_find_food(s0, s1) -> w0 = celula da pilha de comida pronta para
// comer mais perto (-1)
    .globl dep_find_food
dep_find_food:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    fcvtzs  w19, s0
    fcvtzs  w20, s1
    bl      dep_rebuild
    mov     w21, #-1
    mov     w22, #0x7FFFFFFF
    mov     w23, #0
1:  LA      x9, ndep
    ldr     w9, [x9]
    cmp     w23, w9
    b.ge    9f
    LA      x9, deplist
    ldr     w9, [x9, x23, lsl #2]
    add     w23, w23, #1
    LA      x24, objs
    add     x24, x24, x9, lsl #3
    ldrb    w9, [x24, #7]
    cbz     w9, 1b
    ldrb    w0, [x24, #6]
    bl      pile_item
    tbnz    w0, #31, 1b
    LA      x9, eatvalue                // da para comer?
    ldr     s0, [x9, x0, lsl #2]
    fcmp    s0, #0.0
    b.le    1b
    ldrh    w11, [x24]
    lsr     w11, w11, #6
    ldrh    w12, [x24, #2]
    lsr     w12, w12, #6
    sub     w13, w11, w19
    sub     w14, w12, w20
    mul     w13, w13, w13
    madd    w13, w14, w14, w13
    cmp     w13, w22
    b.ge    1b
    mov     w22, w13
    add     w21, w11, w12, lsl #9
    b       1b
9:  mov     w0, w21
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// dep_find_put(s0, s1, w0 item) -> w0 = celula mais perto onde esse item
// cabe: uma pilha dele com lugar, ou um quadrado vazio que o aceita (-1)
    .globl dep_find_put
dep_find_put:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     x27, [sp, #80]
    fcvtzs  w19, s0
    fcvtzs  w20, s1
    mov     w25, w0                     // item
    bl      pile_type
    mov     w23, w0
    mov     w21, #-1
    tbnz    w23, #31, 9f
    LA      x9, stackcap
    ldrb    w26, [x9, x25]
    bl      dep_rebuild
    mov     w22, #0x7FFFFFFF
    // pilhas com lugar
    mov     w27, #0
1:  LA      x9, ndep
    ldr     w9, [x9]
    cmp     w27, w9
    b.ge    3f
    LA      x9, deplist
    ldr     w9, [x9, x27, lsl #2]
    add     w27, w27, #1
    LA      x24, objs
    add     x24, x24, x9, lsl #3
    ldrb    w9, [x24, #6]
    cmp     w9, w23
    b.ne    1b
    ldrb    w9, [x24, #7]
    cmp     w9, w26
    b.hs    1b
    ldrh    w11, [x24]
    lsr     w11, w11, #6
    ldrh    w12, [x24, #2]
    lsr     w12, w12, #6
    sub     w13, w11, w19
    sub     w14, w12, w20
    mul     w13, w13, w13
    madd    w13, w14, w14, w13
    cmp     w13, w22
    b.ge    1b
    add     w24, w11, w12, lsl #9
    str     w13, [sp, #88]
    LA      x9, zonegrid
    ldrb    w0, [x9, w24, uxtw]
    mov     w1, w25
    bl      dep_accepts
    cbz     w0, 1b
    ldr     w22, [sp, #88]
    mov     w21, w24
    b       1b
    // quadrados vazios
3:  mov     w27, #0
4:  LA      x9, ndc
    ldr     w9, [x9]
    cmp     w27, w9
    b.ge    9f
    LA      x9, depcells
    ldr     w24, [x9, x27, lsl #2]
    add     w27, w27, #1
    LA      x9, depocc
    ldrb    w9, [x9, w24, uxtw]
    cbnz    w9, 4b
    and     w11, w24, #511
    lsr     w12, w24, #9
    sub     w13, w11, w19
    sub     w14, w12, w20
    mul     w13, w13, w13
    madd    w13, w14, w14, w13
    cmp     w13, w22
    b.ge    4b
    str     w13, [sp, #88]
    LA      x9, elev
    ldrsh   w9, [x9, w24, uxtw #1]
    ldr     w10, [x28, #G_FLOOD]
    cmp     w9, w10
    b.lt    4b
    LA      x9, zonegrid
    ldrb    w0, [x9, w24, uxtw]
    mov     w1, w25
    bl      dep_accepts
    cbz     w0, 4b
    ldr     w22, [sp, #88]
    mov     w21, w24
    b       4b
9:  mov     w0, w21
    ldr     x27, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// dep_find_any(s0, s1) -> w0 = quadrado de deposito mais perto (-1)
    .globl dep_find_any
dep_find_any:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    fcvtzs  w9, s0
    fcvtzs  w10, s1
    stp     w9, w10, [sp, #-16]!
    bl      dep_rebuild
    ldp     w9, w10, [sp], #16
    mov     w0, #-1
    mov     w11, #0x7FFFFFFF
    LA      x12, depcells
    LA      x13, ndc
    ldr     w13, [x13]
1:  cbz     w13, 9f
    sub     w13, w13, #1
    ldr     w14, [x12], #4
    and     w15, w14, #511
    lsr     w16, w14, #9
    sub     w15, w15, w9
    sub     w16, w16, w10
    mul     w15, w15, w15
    madd    w15, w16, w16, w15
    cmp     w15, w11
    b.ge    1b
    mov     w11, w15
    mov     w0, w14
    b       1b
9:  ldp     x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
//  Para a vila (x19 = pessoa, w20 = numero)
// ---------------------------------------------------------------------

// dep_chestfind(w0 = 0 guardar a carga, 1 comer, 2 sementes) -> w0 =
// celula do deposito para onde ir (-1)
    .globl dep_chestfind
dep_chestfind:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    cmp     w0, #1
    b.ne    1f
    bl      dep_find_food
    b       9f
1:  cmp     w0, #2
    b.ne    2f
    mov     w0, #IT_SEED
    mov     w1, #1
    mov     w2, #0
    mov     w3, #0
    bl      dep_find_take
    b       9f
2:  LA      x9, pinv                    // guardar: o item com mais na mochila
    add     x9, x9, x20, lsl #8         // (da carga)
    LA      x10, cargolist
    mov     w21, #-1
    mov     w22, #0
3:  ldrb    w11, [x10], #1
    cmp     w11, #255
    b.eq    4f
    ldr     w12, [x9, x11, lsl #2]
    cmp     w12, w22
    b.ls    3b
    mov     w22, w12
    mov     w21, w11
    b       3b
4:  ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    tbnz    w21, #31, 5f
    mov     w0, w21
    bl      dep_find_put
    b       9f
5:  bl      dep_find_any
9:  ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// dep_take_find(w0 item, w1 quantos, w2 item 2, w3 quantos 2) -> w0 =
// deposito mais perto da pessoa com isso (-1)
    .globl dep_take_find
dep_take_find:
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    b       dep_find_take

// dep_home -> w0 = quadrado de deposito mais perto da pessoa (-1)
    .globl dep_home
dep_home:
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    b       dep_find_any

// dep_camp(w0 = celula): o primeiro deposito da vila (Geral, 5 x 5) com
// comida para os primeiros dias e sementes -> w0 = celula
    .globl dep_camp
dep_camp:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    and     w20, w19, #511
    lsr     w21, w19, #9
    mov     w22, #-2                    // dv
1:  mov     w9, #-2                     // du
2:  add     w10, w20, w9
    add     w11, w21, w22
    add     w12, w10, w11, lsl #9
    LA      x13, zonegrid
    ldrb    w14, [x13, w12, uxtw]
    cmp     w14, #Z_LOT
    b.eq    3f
    LA      x14, fencegrid
    ldrb    w14, [x14, w12, uxtw]
    cbnz    w14, 3f
    mov     w14, #Z_DEPG
    strb    w14, [x13, w12, uxtw]
3:  add     w9, w9, #1
    cmp     w9, #2
    b.le    2b
    add     w22, w22, #1
    cmp     w22, #2
    b.le    1b
    bl      dep_dirty
    mov     w0, w19
    bl      store_cell
    mov     w9, #30
    str     w9, [x0, #(4 * IT_BERRY)]
    mov     w9, #12
    str     w9, [x0, #(4 * IT_BREAD)]
    mov     w9, #8
    str     w9, [x0, #(4 * IT_SEED)]
    bl      store_close
    mov     w0, w19
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
//  Voce e o deposito (G_CHESTOPEN = 255, G_CHESTOBJ = celula)
// ---------------------------------------------------------------------

// depot_click -> w0 = 1 se o botao direito abriu um deposito
    .globl depot_click
depot_click:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w0, #0
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 9f
    ldr     w9, [x28, #G_HOVU]
    lsr     w10, w9, #6
    ldr     w9, [x28, #G_HOVV]
    lsr     w11, w9, #6
    add     w12, w10, w11, lsl #9
    LA      x9, zonegrid
    ldrb    w9, [x9, w12, uxtw]
    sub     w9, w9, #Z_DEPF
    cmp     w9, #3
    b.hi    9f
    scvtf   s0, w10                     // perto?
    scvtf   s1, w11
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    ldr     s2, [x28, #G_PU]
    fsub    s0, s0, s2
    ldr     s2, [x28, #G_PV]
    fsub    s1, s1, s2
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fmov    s1, #16.0                   // 4 celulas
    fcmp    s0, s1
    b.le    1f
    LA      x0, m_depfar
    bl      set_msg
    mov     w0, #1
    b       9f
1:  mov     w9, #255
    str     w9, [x28, #G_CHESTOPEN]
    str     w12, [x28, #G_CHESTOBJ]
    mov     w9, #1
    str     w9, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CRAFTOPEN]
    str     wzr, [x28, #G_PEOPLEOPEN]
    mov     w0, #1
9:  ldp     x29, x30, [sp], #16
    ret

// depot_ptr -> x0 = stmp da loja do deposito aberto
    .globl depot_ptr
depot_ptr:
    ldr     w0, [x28, #G_CHESTOBJ]
    b       store_cell

// depot_close_player: o deposito aberto e seu: o que nao coube volta
    .globl depot_close_player
depot_close_player:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    ldr     w9, [x28, #G_CHESTOPEN]
    cmp     w9, #255
    b.ne    9f
    bl      store_close
    mov     w19, #0
1:  LA      x9, stover
    ldr     w1, [x9, x19, lsl #2]
    cbz     w1, 2f
    mov     w0, w19
    bl      inv_add
2:  add     w19, w19, #1
    cmp     w19, #NITEMS
    b.lt    1b
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// depot_far -> w0 = 1 se voce se afastou do deposito aberto   folha
    .globl depot_far
depot_far:
    ldr     w9, [x28, #G_CHESTOBJ]
    and     w10, w9, #511
    lsr     w11, w9, #9
    scvtf   s0, w10
    scvtf   s1, w11
    ldr     s2, [x28, #G_PU]
    fsub    s0, s0, s2
    ldr     s2, [x28, #G_PV]
    fsub    s1, s1, s2
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fmov    s1, #25.0
    fcmp    s0, s1
    cset    w0, gt
    ret

// ---------------------------------------------------------------------
//  Comida no chao (pilhas, dentro ou fora de deposito) estraga: como na
//  mochila; com chuva, tempestade ou enchente, duas vezes mais rapido
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
    bl      dep_dirty
8:  add     x22, x22, #8
    b       3b
9:  ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
//  Teste automatico (--shot): um deposito de materiais 3 x 3 do seu lado
// ---------------------------------------------------------------------
    .globl dep_selftest
dep_selftest:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    LA      x24, dtres
    ldr     w9, [x28, #G_PU]            // guarda onde voce estava
    str     w9, [x24, #40]
    ldr     w9, [x28, #G_PV]
    str     w9, [x24, #44]
    ldr     w9, [x28, #G_TIME]          // e a hora (a foto e de dia)
    str     w9, [x24, #48]
    MOVI32  w9, (DAYLEN / 4)            // meio-dia (o dia comeca as 06:00)
    str     w9, [x28, #G_TIME]
    bl      dt_spot                     // longe dos depositos da vila
    mov     w19, w0
    mov     w20, w1
    scvtf   s0, w19                     // voce fica do lado
    fmov    s2, #-1.5
    fadd    s0, s0, s2
    scvtf   s1, w20
    fmov    s2, #0.5
    fadd    s1, s1, s2
    str     s0, [x28, #G_PU]
    str     s1, [x28, #G_PV]
    bl      elev_at                     // a altura do chao ali
    str     w0, [x28, #G_PE]
    bl      follow_camera
    mov     w0, w19
    mov     w1, w20
    mov     w2, #Z_DEPM
    bl      dep_test_paint
    str     w0, [x24]
    add     w23, w19, w20, lsl #9       // o meio
    // 100 madeiras
    mov     w0, w23
    bl      store_cell
    ldr     w9, [x0, #(4 * IT_WOOD)]
    add     w9, w9, #100
    str     w9, [x0, #(4 * IT_WOOD)]
    bl      store_close
    ldr     w9, [x0, #(4 * IT_WOOD)]
    str     w9, [x24, #4]               // nao coube
    mov     w0, #IT_WOOD
    bl      dt_piles
    str     w0, [x24, #8]
    // 50 pedras
    mov     w0, w23
    bl      store_cell
    ldr     w9, [x0, #(4 * IT_STONE)]
    add     w9, w9, #50
    str     w9, [x0, #(4 * IT_STONE)]
    bl      store_close
    ldr     w9, [x0, #(4 * IT_STONE)]
    str     w9, [x24, #12]
    mov     w0, #IT_STONE
    bl      dt_piles
    str     w0, [x24, #16]
    // frutas: deposito de materiais nao aceita
    mov     w0, w23
    bl      store_cell
    mov     w9, #10
    str     w9, [x0, #(4 * IT_BERRY)]
    bl      store_close
    ldr     w9, [x0, #(4 * IT_BERRY)]
    str     w9, [x24, #20]
    // tira 30 madeiras
    mov     w0, w23
    bl      store_cell
    ldr     w9, [x0, #(4 * IT_WOOD)]
    sub     w9, w9, #30
    str     w9, [x0, #(4 * IT_WOOD)]
    bl      store_close
    mov     w0, w23
    bl      store_cell
    ldr     w9, [x0, #(4 * IT_WOOD)]
    str     w9, [x24, #24]
    // voce abre o deposito e pega as pedras
    mov     w9, #255
    str     w9, [x28, #G_CHESTOPEN]
    str     w23, [x28, #G_CHESTOBJ]
    mov     w9, #1
    str     w9, [x28, #G_INVOPEN]
    ldr     w21, [x28, #(G_INV + 4 * IT_STONE)]
    mov     w0, #IT_STONE
    mov     w1, #1
    bl      chest_move
    ldr     w9, [x28, #(G_INV + 4 * IT_STONE)]
    sub     w9, w9, w21
    str     w9, [x24, #28]
    mov     w0, #IT_STONE
    bl      dt_piles
    str     w0, [x24, #32]
    // e guarda 20 de volta (foto: o deposito aberto)
    mov     w9, #20
    str     w9, [x28, #(G_INV + 4 * IT_STONE)]
    mov     w0, #IT_STONE
    mov     w1, #0
    bl      chest_move
    bl      depot_close_player          // fecha (a foto e das pilhas no chao)
    str     wzr, [x28, #G_CHESTOPEN]
    str     wzr, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_MSGT]
    str     wzr, [x28, #G_POPT]
    LA      x0, txt
    LA      x1, dt_d1
    ldr     w2, [x24]
    bl      dt_dnum
    LA      x1, dt_d2
    ldr     w2, [x24, #8]
    bl      dt_dnum
    LA      x1, dt_d3
    ldr     w2, [x24, #4]
    bl      dt_dnum
    LA      x1, dt_d4
    ldr     w2, [x24, #16]
    bl      dt_dnum
    LA      x1, dt_d3
    ldr     w2, [x24, #12]
    bl      dt_dnum
    LA      x1, dt_d5
    ldr     w2, [x24, #20]
    bl      dt_dnum
    LA      x1, dt_d6
    ldr     w2, [x24, #24]
    bl      dt_dnum
    LA      x1, dt_d7
    ldr     w2, [x24, #28]
    bl      dt_dnum
    LA      x1, dt_d8
    ldr     w2, [x24, #32]
    bl      dt_dnum
    LA      x1, dt_dnl
    bl      strcat_cur
    bl      sk_write
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// dep_test_paint(w0 u, w1 v, w2 zona) -> w0 quadrados: pinta um deposito
// 3 x 3 (so na terra) e limpa o terreno, como se tivesse cortado tudo (teste)
    .globl dep_test_paint
dep_test_paint:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    mov     w0, #0
    mov     w22, #-1
1:  mov     w2, #-1
2:  add     w9, w19, w2
    add     w10, w20, w22
    add     w9, w9, w10, lsl #9
    LA      x10, elev
    ldrsh   w10, [x10, w9, uxtw #1]
    ldr     w11, [x28, #G_FLOOD]
    cmp     w10, w11
    b.lt    3f
    LA      x10, zonegrid
    strb    w21, [x10, w9, uxtw]
    add     w0, w0, #1
3:  add     w2, w2, #1
    cmp     w2, #1
    b.le    2b
    add     w22, w22, #1
    cmp     w22, #1
    b.le    1b
    mov     w21, w0
    LA      x9, objs
    ldr     w10, [x28, #G_NOBJ]
1:  cbz     w10, 3f
    sub     w10, w10, #1
    add     x11, x9, x10, lsl #3
    ldrh    w12, [x11]
    lsr     w12, w12, #6
    sub     w12, w12, w19
    add     w12, w12, #1
    cmp     w12, #2
    b.hi    1b
    ldrh    w12, [x11, #2]
    lsr     w12, w12, #6
    sub     w12, w12, w20
    add     w12, w12, #1
    cmp     w12, #2
    b.hi    1b
    mov     w12, #O_GONE
    strb    w12, [x11, #6]
    b       1b
3:  bl      dep_dirty
    mov     w0, w21
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// dep_find_put_test(s0 u, s1 v, w0 item) -> w0 celula: como dep_find_put,
// mas se nao tem lugar pinta um deposito geral 3 x 3 ali perto (teste)
    .globl dep_find_put_test
dep_find_put_test:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     s0, s1, [sp, #16]
    bl      dep_find_put
    tbz     w0, #31, 9f
    ldp     s0, s1, [sp, #16]
    fcvtzs  w0, s0
    fcvtzs  w1, s1
    mov     w2, #4
    bl      dep_spot
    stp     w0, w1, [sp, #24]
    mov     w2, #Z_DEPG
    bl      dep_test_paint
    ldp     w0, w1, [sp, #24]
    add     w0, w0, w1, lsl #9
9:  ldp     x29, x30, [sp], #32
    ret

// dep_selftest_done: fecha o deposito e volta voce para onde estava
    .globl dep_selftest_done
dep_selftest_done:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      depot_close_player
    str     wzr, [x28, #G_CHESTOPEN]
    str     wzr, [x28, #G_INVOPEN]
    LA      x9, dtres
    ldr     w10, [x9, #48]
    str     w10, [x28, #G_TIME]
    ldr     w10, [x9, #40]
    str     w10, [x28, #G_PU]
    ldr     w10, [x9, #44]
    str     w10, [x28, #G_PV]
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    bl      elev_at
    str     w0, [x28, #G_PE]
    bl      update_ambient
    bl      follow_camera
    ldp     x29, x30, [sp], #16
    ret

// dt_spot -> w0, w1 = meio de um 3 x 3 de terra sem deposito a 7 celulas
// (procura em cruz, de 10 em 10 ... 58 celulas de voce; senao 3 ao lado)
dt_spot:
    ldr     s0, [x28, #G_PU]
    fcvtzs  w0, s0
    ldr     s0, [x28, #G_PV]
    fcvtzs  w1, s0
    mov     w2, #10
// dep_spot(w0 u, w1 v, w2 raio inicial) -> w0, w1   folha
    .globl dep_spot
dep_spot:
    mov     w12, w0
    mov     w13, w1
    LA      x14, elev
    LA      x15, zonegrid
    ldr     w16, [x28, #G_FLOOD]
1:  mov     w3, #0                      // direcao
2:  mov     w4, w12
    mov     w5, w13
    cmp     w3, #0
    b.ne    3f
    add     w4, w4, w2
3:  cmp     w3, #1
    b.ne    3f
    sub     w4, w4, w2
3:  cmp     w3, #2
    b.ne    3f
    add     w5, w5, w2
3:  cmp     w3, #3
    b.ne    3f
    sub     w5, w5, w2
3:  cmp     w4, #10                     // dentro do mapa
    b.lt    8f
    cmp     w5, #10
    b.lt    8f
    cmp     w4, #500
    b.gt    8f
    cmp     w5, #500
    b.gt    8f
    mov     w6, #-7                     // dv
4:  mov     w7, #-7                     // du
5:  add     w8, w4, w7
    add     w9, w5, w6
    add     w8, w8, w9, lsl #9
    ldrb    w9, [x15, w8, uxtw]
    cmp     w9, #Z_DEPF
    b.lt    6f
    cmp     w9, #Z_DEPG
    b.le    8f                          // tem deposito perto
6:  cmp     w6, #-1                     // o 3 x 3 do meio: terra
    b.lt    7f
    cmp     w6, #1
    b.gt    7f
    cmp     w7, #-1
    b.lt    7f
    cmp     w7, #1
    b.gt    7f
    ldrsh   w9, [x14, w8, uxtw #1]
    cmp     w9, w16
    b.lt    8f
7:  add     w7, w7, #1
    cmp     w7, #7
    b.le    5b
    add     w6, w6, #1
    cmp     w6, #7
    b.le    4b
    mov     w0, w4                      // achou
    mov     w1, w5
    ret
8:  add     w3, w3, #1
    cmp     w3, #4
    b.lt    2b
    add     w2, w2, #4
    cmp     w2, #58
    b.le    1b
    add     w0, w12, #3
    mov     w1, w13
    ret

// dep_total(w0 = item) -> w0 = quanto tem desse item em todos os depositos
    .globl dep_total
dep_total:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     w0, [sp, #-16]!
    bl      dep_rebuild
    ldr     w0, [sp], #16
    bl      pile_type
    ldp     x29, x30, [sp], #16
    mov     w2, w0
    mov     w3, #0
    LA      x4, deplist
    LA      x5, ndep
    ldr     w5, [x5]
    LA      x6, objs
1:  cbz     w5, 9f
    sub     w5, w5, #1
    ldr     w7, [x4], #4
    add     x7, x6, x7, lsl #3
    ldrb    w8, [x7, #6]
    cmp     w8, w2
    b.ne    1b
    ldrb    w8, [x7, #7]
    add     w3, w3, w8
    b       1b
9:  mov     w0, w3
    ret

// dt_piles(w0 = item) -> w0 = pilhas desse item em volta da loja aberta
dt_piles:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      pile_type
    mov     w2, w0
    LA      x9, stanc
    ldp     w0, w1, [x9]
    mov     w3, #0
    LA      x4, deplist
    LA      x5, ndep
    ldr     w5, [x5]
    LA      x6, objs
1:  cbz     w5, 9f
    sub     w5, w5, #1
    ldr     w7, [x4], #4
    add     x7, x6, x7, lsl #3
    ldrb    w8, [x7, #6]
    cmp     w8, w2
    b.ne    1b
    ldrh    w10, [x7]
    lsr     w10, w10, #6
    sub     w10, w10, w0
    ldrh    w11, [x7, #2]
    lsr     w11, w11, #6
    sub     w11, w11, w1
    mul     w10, w10, w10
    madd    w10, w11, w11, w10
    cmp     w10, #STR2
    b.gt    1b
    ldrb    w8, [x7, #7]
    cmp     w8, #0
    cinc    w3, w3, ne
    b       1b
9:  mov     w0, w3
    ldp     x29, x30, [sp], #16
    ret

// dt_dnum(x0 cursor, x1 rotulo, w2 numero) -> x0
dt_dnum:
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

// ---------------------------------------------------------------------
    .data
// categoria de cada item: 1 comida, 2 material, 3 ferramenta/arma/util,
// 0 construcao (nao vai para deposito)
itemcat:
    .byte 2, 2, 1, 3, 3, 3, 1, 3, 0, 0, 0, 3, 3, 1, 1, 2   //  0..15
    .byte 3, 3, 0, 0, 3, 1, 1, 3, 1, 1, 1, 2, 2, 2, 0, 3   // 16..31
    .byte 3, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0   // 32..47
// quanto cabe numa pilha
    .globl stackcap
stackcap:
    .byte 20, 15, 20, 5, 5, 10, 15, 3, 0, 0, 0, 3, 40, 10, 10, 10
    .byte 3, 3, 0, 0, 5, 10, 10, 5, 40, 20, 15, 15, 20, 10, 0, 3
    .byte 3, 3, 3, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
m_depfar:   .asciz "Longe demais do deposito"
dt_d1:  .asciz "deposito: materiais 3x3 (celulas)="
dt_d2:  .asciz " | 100 madeiras: pilhas="
dt_d3:  .asciz " nao coube="
dt_d4:  .asciz " | 50 pedras: pilhas="
dt_d5:  .asciz " | frutas (nao aceita) voltaram="
dt_d6:  .asciz " | tirou 30 madeiras: ficou="
dt_d7:  .asciz " | voce pegou pedras="
dt_d8:  .asciz " pilhas de pedra="
dt_dnl: .asciz "\n"
    .p2align 3
stanc:      .space 8                    // o ponto da loja (celula u, v)
stmp:       .space 192
stbase:     .space 192
stover:     .space 192
ndc:        .space 4
ndep:       .space 4
dtres:      .space 64

GBSS depcells, (MAXDC * 4)
GBSS deplist, (MAXDP * 4)
GBSS depocc, (MAPN * MAPN)
