// =====================================================================
//  vila.S - casas, familias e arvore genealogica
//
//  - Cada familia (quem mora junto) tem um terreno 5 x 5 com a casa no
//    meio. O jogo comeca com 3 familias, cada uma num barraco.
//  - Obras (tarefa "Obras" no painel P): o construtor pega o material no
//    bau e trabalha no terreno. Na ordem: barraco para quem nao tem casa
//    (o terreno novo sai numa zona de Moradia, Z 4), depois o barraco
//    vira casa (cabem 8 em vez de 4) e o terreno ganha cerca e portao.
//      barraco: 10 madeira | casa: 25 madeira e 10 pedra | cerca: 12 madeira
//  - Casamentos: rapaz e moca solteiros (16+ anos) de sobrenomes
//    diferentes casam e formam uma familia nova (precisa de barraco).
//  - Nascimentos: casal com casa e lugar sobrando tem filhos de vez em
//    quando (um a cada ano e meio, no maximo); o filho leva o sobrenome
//    do pai.
//  - Arvores plantadas: muda -> jovem (1 ano) -> adulta (2 anos).
//  - Arvore genealogica: no painel P, aba Familias (quem morreu fica).
// =====================================================================

#include "comum.h"
#include "pessoas.h"

.equ MAXTLINES, 96              // linhas da arvore genealogica

    .text
    .p2align 2

// vila_reset: sem parentes, sem casas
    .globl vila_reset
vila_reset:
    LA      x9, kin
    mov     w10, #(MAXPEOPLE * 8 / 16)
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    LA      x9, fams
    mov     w10, #MAXFAM
    mov     w11, #-1
2:  stp     xzr, xzr, [x9]
    stp     xzr, xzr, [x9, #16]
    str     w11, [x9, #F_HOUSE]
    str     w11, [x9, #F_LOT]
    add     x9, x9, #FSIZE
    subs    w10, w10, #1
    b.ne    2b
    str     wzr, [x28, #G_PTAB]
    str     wzr, [x28, #G_PPAGE]
    str     wzr, [x28, #G_NOLOTT]
    LA      x9, vstat
    stp     xzr, xzr, [x9]
    ret

// vila_found: as 3 familias do comeco, cada uma num barraco num terreno
// perto do personagem (chamar depois de ppl_spawn_all e ppl_camp)
    .globl vila_found
vila_found:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    bl      occ_build
    mov     w20, #0
1:  cmp     w20, #NSURN
    b.ge    8f
    LA      x9, fams
    add     x19, x9, x20, lsl #5
    mov     w9, #1
    strb    w9, [x19, #F_USED]
    strb    w20, [x19, #F_SURN]
    LA      x9, famvarv
    ldrb    w9, [x9, x20]
    strb    w9, [x19, #F_VAR]
    mov     w0, #0                      // terreno livre perto do personagem
    ldr     s0, [x28, #G_PU]
    fcvtzs  w1, s0
    ldr     s0, [x28, #G_PV]
    fcvtzs  w2, s0
    mov     w3, #16
    bl      lot_find
    tbnz    w0, #31, 7f
    str     w0, [x19, #F_LOT]
    mov     w21, w0
    bl      lot_mark
    mov     w0, w20
    mov     w1, #B_HUT
    mov     w2, #1                      // (sem mensagem)
    bl      vila_done
    and     w22, w21, #511              // a familia na frente do barraco
    lsr     w23, w21, #9
    mov     w24, #0
    LA      x9, people
    mov     w10, #0
2:  cmp     w10, #MAXPEOPLE
    b.ge    7f
    add     x11, x9, x10, lsl #6
    ldrb    w12, [x11, #P_ALIVE]
    cbz     w12, 3f
    ldrb    w12, [x11, #P_FAM]
    cmp     w12, w20
    b.ne    3f
    add     w12, w22, w24
    scvtf   s0, w12
    fmov    s1, #0.5
    fadd    s0, s0, s1
    str     s0, [x11, #P_U]
    add     w12, w23, #4
    scvtf   s0, w12
    fadd    s0, s0, s1
    str     s0, [x11, #P_V]
    add     w24, w24, #1
3:  add     w10, w10, #1
    b       2b
7:  add     w20, w20, #1
    b       1b
8:  bl      occ_build
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
//  Terrenos
// ---------------------------------------------------------------------

// lot_ok(w0 u0, w1 v0, w2 modo) -> w0 = 1 se o terreno 5 x 5 com canto
// em (u0, v0) serve: chao bom, livre; modo 0 sem zona, 1 zona de Moradia
//   folha
lot_ok:
    cmp     w0, #2
    b.lt    8f
    cmp     w1, #2
    b.lt    8f
    cmp     w0, #(509 - LOTN)
    b.gt    8f
    cmp     w1, #(509 - LOTN)
    b.gt    8f
    ldr     w12, [x28, #G_FLOOD]
    mov     w13, #0                     // dv
1:  mov     w14, #0                     // du
2:  add     w15, w0, w14
    add     w9, w1, w13
    add     w15, w15, w9, lsl #9        // celula
    LA      x9, zonegrid
    ldrb    w10, [x9, w15, uxtw]
    cbz     w2, 3f
    cmp     w10, #Z_HOME
    b.ne    8f
    b       4f
3:  cbnz    w10, 8f
4:  LA      x9, occgrid
    ldrb    w10, [x9, w15, uxtw]
    cbnz    w10, 8f
    LA      x9, fencegrid
    ldrb    w10, [x9, w15, uxtw]
    cbnz    w10, 8f
    LA      x9, overlay
    ldrb    w10, [x9, w15, uxtw]
    cmp     w10, #1
    b.hi    8f
    LA      x9, elev
    ldrsh   w10, [x9, w15, uxtw #1]
    cmp     w10, w12
    b.lt    8f
    cmp     w10, #(E_SAND + 20)
    b.lt    8f
    mov     w11, #E_ROCK
    cmp     w10, w11
    b.ge    8f
    add     w14, w14, #1
    cmp     w14, #LOTN
    b.lt    2b
    add     w13, w13, #1
    cmp     w13, #LOTN
    b.lt    1b
    mov     w0, #1
    ret
8:  mov     w0, #0
    ret

// lot_find(w0 modo, w1 u, w2 v, w3 raio) -> w0 = canto do terreno livre
// mais perto do ponto (-1)
lot_find:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     x27, [sp, #80]
    mov     w19, w0
    sub     w20, w1, #2                 // canto = centro - 2
    sub     w21, w2, #2
    mov     w22, w3
    mov     w23, #-1
    mov     w24, #0x7FFFFFFF
    neg     w25, w22                    // dv
1:  neg     w26, w22                    // du
2:  mul     w9, w25, w25
    madd    w9, w26, w26, w9
    cmp     w9, w24
    b.ge    5f
    add     w0, w20, w26
    add     w1, w21, w25
    cbz     w19, 3f                     // Moradia: o canto ja diz
    cmp     w0, #0
    b.lt    5f
    cmp     w1, #0
    b.lt    5f
    cmp     w0, #511
    b.gt    5f
    cmp     w1, #511
    b.gt    5f
    add     w10, w0, w1, lsl #9
    LA      x11, zonegrid
    ldrb    w10, [x11, w10, uxtw]
    cmp     w10, #Z_HOME
    b.ne    5f
3:  mov     w27, w9
    mov     w2, w19
    bl      lot_ok
    cbz     w0, 5f
    mov     w24, w27
    add     w0, w20, w26
    add     w1, w21, w25
    add     w23, w0, w1, lsl #9
5:  add     w26, w26, #1
    cmp     w26, w22
    b.le    2b
    add     w25, w25, #1
    cmp     w25, w22
    b.le    1b
    mov     w0, w23
    ldr     x27, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// lot_mark(w0 = canto): o terreno fica reservado (zona Lote)   folha
lot_mark:
    LA      x9, zonegrid
    mov     w10, #0
1:  mov     w11, #0
2:  add     w12, w0, w11
    add     w12, w12, w10, lsl #9
    mov     w13, #Z_LOT
    strb    w13, [x9, w12, uxtw]
    add     w11, w11, #1
    cmp     w11, #LOTN
    b.lt    2b
    add     w10, w10, #1
    cmp     w10, #LOTN
    b.lt    1b
    ret

// ---------------------------------------------------------------------
//  Obras
// ---------------------------------------------------------------------

// vila_members(w0 = casa) -> w0 = quantos vivos moram la   folha
    .globl vila_members
vila_members:
    LA      x9, people
    mov     w10, #0
    mov     w11, w0
    mov     w0, #0
1:  cmp     w10, #MAXPEOPLE
    b.ge    9f
    ldrb    w12, [x9, #P_ALIVE]
    cbz     w12, 2f
    ldrb    w12, [x9, #P_FAM]
    cmp     w12, w11
    cinc    w0, w0, eq
2:  add     x9, x9, #PSIZE
    add     w10, w10, #1
    b       1b
9:  ret

// vila_cap(w0 = casa) -> w0 = quantos cabem (barraco 4, casa 8)   folha
vila_cap:
    LA      x9, fams
    add     x9, x9, x0, lsl #5
    ldrb    w9, [x9, #F_LEVEL]
    lsl     w0, w9, #2
    ret

// vila_cost(w0 = obra) -> w0 madeira, w1 pedra   folha
vila_cost:
    LA      x9, buildcost
    add     x9, x9, x0, lsl #1
    ldrb    w1, [x9, #1]
    ldrb    w0, [x9]
    ret

// vila_chestwith(w0 madeira, w1 pedra) -> w0 = bau com isso mais perto
// da pessoa x19 (-1)
vila_chestwith:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w12, w0
    mov     w13, w1
    mov     w0, #-1
    PF      s4, 76
    ldr     w10, [x28, #G_NOBJ]
    mov     w11, #0
    LA      x14, objs
1:  cmp     w11, w10
    b.ge    9f
    ldrb    w15, [x14, #6]
    cmp     w15, #O_CHEST
    b.ne    2f
    ldrb    w15, [x14, #7]
    LA      x9, chests
    add     x9, x9, x15, lsl #7
    ldr     w15, [x9, #(4 * IT_WOOD)]
    cmp     w15, w12
    b.lo    2f
    ldr     w15, [x9, #(4 * IT_STONE)]
    cmp     w15, w13
    b.lo    2f
    ldrh    w15, [x14]
    ucvtf   s0, w15
    ldrh    w15, [x14, #2]
    ucvtf   s1, w15
    PF      s2, 40
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    ldr     s2, [x19, #P_U]
    fsub    s0, s0, s2
    ldr     s2, [x19, #P_V]
    fsub    s1, s1, s2
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fcmp    s0, s4
    b.ge    2f
    fmov    s4, s0
    mov     w0, w11
2:  add     x14, x14, #8
    add     w11, w11, #1
    b       1b
9:  ldp     x29, x30, [sp], #16
    ret

// vila_gosite(w0 = casa): o construtor (x19) vai ate o terreno
vila_gosite:
    add     w9, w0, #1
    strb    w9, [x19, #P_BFAM]
    mov     w9, #0x10000
    add     w9, w9, w0
    str     w9, [x19, #P_TARGET]
    mov     w9, #WK_BUILD
    strb    w9, [x19, #P_WKIND]
    mov     w9, #NX_WORK
    strb    w9, [x19, #P_NEXT]
    LA      x9, fams
    add     x9, x9, x0, lsl #5
    ldr     w10, [x9, #F_LOT]
    and     w11, w10, #511
    lsr     w12, w10, #9
    add     w11, w11, #2
    add     w12, w12, #2
    scvtf   s0, w11
    scvtf   s1, w12
    b       ppl_gopoint

// vila_buildwork -> w0 = 1 se achou obra (o construtor x19 ja esta indo)
//   0: obras pagas; 1: barraco; 2: barraco vira casa; 3: cerca
    .globl vila_buildwork
vila_buildwork:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     x23, x24, [sp, #32]
    stp     x25, x26, [sp, #48]
    strb    wzr, [x19, #P_BFAM]
    mov     w21, #0                     // passada
1:  cmp     w21, #3
    b.gt    80f
    mov     w22, #0                     // casa
2:  cmp     w22, #MAXFAM
    b.ge    70f
    LA      x9, fams
    add     x23, x9, x22, lsl #5
    ldrb    w9, [x23, #F_USED]
    cbz     w9, 60f
    mov     w0, w22
    bl      vila_members
    cbz     w0, 60f
    ldrb    w24, [x23, #F_PAID]
    ldrb    w9, [x23, #F_LEVEL]
    cbnz    w21, 3f
    cbz     w24, 60f                    // passada 0: obra ja paga
    mov     w0, w22
    bl      vila_gosite
    b       90f
3:  cbnz    w24, 60f
    cmp     w21, #B_HUT
    b.ne    4f
    cbnz    w9, 60f
    ldr     w9, [x23, #F_LOT]           // precisa de terreno (zona de Moradia)
    tbz     w9, #31, 5f
    mov     w0, #1
    ldr     s0, [x19, #P_U]
    fcvtzs  w1, s0
    ldr     s0, [x19, #P_V]
    fcvtzs  w2, s0
    mov     w3, #60
    bl      lot_find
    tbnz    w0, #31, 35f
    str     w0, [x23, #F_LOT]
    bl      lot_mark
    b       5f
35: mov     w0, w22
    bl      vila_nolotmsg
    b       60f
4:  cmp     w21, #B_HOUSE
    b.ne    41f
    cmp     w9, #1
    b.ne    60f
    b       5f
41: cbz     w9, 60f                     // cerca: com casa e sem cerca
    ldrb    w9, [x23, #F_FENCE]
    cbnz    w9, 60f
5:  mov     w0, w21                     // tem material num bau?
    bl      vila_cost
    bl      vila_chestwith
    tbnz    w0, #31, 60f
    add     w9, w22, #1
    strb    w9, [x19, #P_BFAM]
    strb    w21, [x19, #P_BPROJ]
    mov     w1, #NX_PAY
    bl      ppl_gochest
    b       90f
60: add     w22, w22, #1
    b       2b
70: add     w21, w21, #1
    b       1b
80: mov     w0, #0
    b       99f
90: mov     w0, #1
99: ldp     x25, x26, [sp, #48]
    ldp     x23, x24, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// vila_nolotmsg(w0 = casa): avisa (de vez em quando) que falta Moradia
vila_nolotmsg:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w0
    ldr     w9, [x28, #G_PPLFRAME]
    ldr     w10, [x28, #G_NOLOTT]
    sub     w11, w9, w10
    cmp     w11, #3600
    b.lo    9f
    str     w9, [x28, #G_NOLOTT]
    LA      x0, pmsgbuf
    LA      x1, s_nolot
    bl      strcat_cur
    LA      x9, fams
    add     x9, x9, x19, lsl #5
    ldrb    w9, [x9, #F_SURN]
    LA      x1, psurn
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    LA      x1, s_nolot2
    bl      strcat_cur
    LA      x0, pmsgbuf
    bl      set_msg
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// vila_pay: o construtor (x19) chegou ao bau: paga a obra e vai ao terreno
    .globl vila_pay
vila_pay:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     x23, x24, [sp, #32]
    ldrb    w21, [x19, #P_BFAM]
    cbz     w21, 8f
    sub     w21, w21, #1
    LA      x9, fams
    add     x23, x9, x21, lsl #5
    ldrb    w9, [x23, #F_PAID]          // outro ja pagou: vai trabalhar
    cbnz    w9, 7f
    ldrb    w22, [x19, #P_BPROJ]
    ldr     w0, [x19, #P_TARGET]
    bl      ppl_chestptr
    cbz     x0, 8f
    mov     x24, x0
    mov     w0, w22
    bl      vila_cost
    ldr     w9, [x24, #(4 * IT_WOOD)]
    cmp     w9, w0
    b.lo    8f
    ldr     w10, [x24, #(4 * IT_STONE)]
    cmp     w10, w1
    b.lo    8f
    sub     w9, w9, w0
    str     w9, [x24, #(4 * IT_WOOD)]
    sub     w10, w10, w1
    str     w10, [x24, #(4 * IT_STONE)]
    strb    w22, [x23, #F_PAID]
    strb    wzr, [x23, #F_PROG]
7:  mov     w0, w21
    bl      vila_gosite
    b       9f
8:  strb    wzr, [x19, #P_BFAM]         // nao deu: pensa de novo
    mov     w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    mov     w9, #30
    strh    w9, [x19, #P_THINK]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
9:  ldp     x23, x24, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// vila_valid(w0 = alvo da obra) -> w0 = 1 se ainda tem obra paga la  folha
    .globl vila_valid
vila_valid:
    mov     w9, #0x10000
    subs    w9, w0, w9
    b.lt    8f
    cmp     w9, #MAXFAM
    b.hs    8f
    LA      x10, fams
    add     x10, x10, x9, lsl #5
    ldrb    w0, [x10, #F_PAID]
    cmp     w0, #0
    cset    w0, ne
    ret
8:  mov     w0, #0
    ret

// vila_step(w0 = alvo da obra) -> w0 = 1 se a obra ficou pronta
    .globl vila_step
vila_step:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w9, #0x10000
    sub     w0, w0, w9
    LA      x10, fams
    add     x10, x10, x0, lsl #5
    ldrb    w11, [x10, #F_PAID]
    cbz     w11, 7f
    ldrb    w12, [x10, #F_PROG]
    add     w12, w12, #1
    strb    w12, [x10, #F_PROG]
    LA      x13, buildsteps
    ldrb    w13, [x13, x11]
    cmp     w12, w13
    b.lo    8f
    mov     w1, w11
    mov     w2, #0
    bl      vila_done
7:  mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldp     x29, x30, [sp], #16
    ret

// vila_done(w0 casa, w1 obra, w2 1 = sem mensagem): a obra fica pronta
vila_done:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     w19, w0
    mov     w20, w1
    mov     w24, w2
    LA      x9, fams
    add     x21, x9, x19, lsl #5
    strb    wzr, [x21, #F_PAID]
    strb    wzr, [x21, #F_PROG]
    ldr     w9, [x21, #F_LOT]
    and     w22, w9, #511               // canto do terreno
    lsr     w23, w9, #9
    cmp     w20, #B_HUT
    b.ne    2f
    // ---- barraco no meio do terreno (bloco 2 x 2) ----
    add     w9, w22, #2
    scvtf   s0, w9
    add     w9, w23, #2
    scvtf   s1, w9
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    csel    w2, w9, w0, lt
    add     w0, w22, #2
    lsl     w0, w0, #6
    add     w1, w23, #2
    lsl     w1, w1, #6
    mov     w3, #O_HUT
    ldrb    w4, [x21, #F_VAR]
    bl      add_obj
    ldr     w0, [x28, #G_NOBJ]
    sub     w0, w0, #1
    str     w0, [x21, #F_HOUSE]
    LA      x9, memtype
    mov     w10, #O_HUT
    strb    w10, [x9, w0, uxtw]
    mov     w9, #1
    strb    w9, [x21, #F_LEVEL]
    LA      x1, s_bhut
    b       7f
2:  cmp     w20, #B_HOUSE
    b.ne    3f
    // ---- o barraco vira casa ----
    ldr     w0, [x21, #F_HOUSE]
    tbnz    w0, #31, 8f
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    mov     w10, #O_HOUSE
    strb    w10, [x9, #6]
    LA      x9, memtype
    strb    w10, [x9, w0, uxtw]
    mov     w9, #2
    strb    w9, [x21, #F_LEVEL]
    LA      x1, s_bhouse
    b       7f
    // ---- cerca na volta do terreno, portao na frente ----
3:  mov     w20, #0                     // dv
31: mov     w19, #0                     // du
32: cmp     w19, #0
    b.eq    33f
    cmp     w19, #(LOTN - 1)
    b.eq    33f
    cmp     w20, #0
    b.eq    33f
    cmp     w20, #(LOTN - 1)
    b.ne    35f
33: mov     w2, #1
    cmp     w19, #2
    b.ne    34f
    cmp     w20, #(LOTN - 1)
    b.ne    34f
    mov     w2, #2                      // portao
34: add     w0, w22, w19
    add     w1, w23, w20
    bl      vila_fence
35: add     w19, w19, #1
    cmp     w19, #LOTN
    b.lt    32b
    add     w20, w20, #1
    cmp     w20, #LOTN
    b.lt    31b
    mov     w9, #1
    strb    w9, [x21, #F_FENCE]
    LA      x1, s_bfence
7:  mov     w9, #-1                     // o chao mudou: refaz a ocupacao
    str     w9, [x28, #G_OCCFRAME]
    cbnz    w24, 8f
    mov     x22, x1
    LA      x0, pmsgbuf
    LA      x1, s_os
    bl      strcat_cur
    ldrb    w9, [x21, #F_SURN]
    LA      x1, psurn
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    mov     x1, x22
    bl      strcat_cur
    LA      x0, pmsgbuf
    bl      set_msg
8:  ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// vila_fence(w0 u, w1 v, w2 1 cerca / 2 portao): poe sem gastar nada
vila_fence:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    add     w22, w19, w20, lsl #9
    LA      x9, fencegrid
    ldrb    w9, [x9, w22, uxtw]
    cbnz    w9, 9f
    scvtf   s0, w19
    scvtf   s1, w20
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    csel    w2, w9, w0, lt
    lsl     w0, w19, #6
    add     w0, w0, #32
    lsl     w1, w20, #6
    add     w1, w1, #32
    mov     w3, #O_FENCE
    cmp     w21, #2
    b.ne    1f
    mov     w3, #O_GATE
1:  mov     w4, #0
    bl      add_obj
    ldr     w9, [x28, #G_NOBJ]
    sub     w9, w9, #1
    LA      x10, objs
    add     x10, x10, x9, lsl #3
    ldrb    w11, [x10, #6]
    LA      x10, memtype
    strb    w11, [x10, x9]
    LA      x10, fencegrid
    strb    w21, [x10, w22, uxtw]
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
//  Um dia novo: arvores crescem, casamentos, nascimentos
// ---------------------------------------------------------------------

    .globl vila_newday
vila_newday:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    bl      tree_grow
    // ---- casamentos ----
    mov     w20, #0
1:  cmp     w20, #MAXPEOPLE
    b.ge    20f
    LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 19f
    ldrb    w9, [x19, #P_SEX]
    cbnz    w9, 19f
    ldrh    w21, [x19, #P_AGE]
    cmp     w21, #MARRYDAYS
    b.lo    19f
    mov     w0, w20
    bl      kin_single
    cbz     w0, 19f
    ldr     s0, [x19, #P_FAITH]
    PF      s1, 116
    fcmp    s0, s1
    b.lt    19f
    mov     w0, #4                      // 1 em 4 por dia
    bl      rng_mod
    cbnz    w0, 19f
    mov     w0, #MAXPEOPLE
    bl      rng_mod
    mov     w22, w0                     // comeca de um lugar qualquer
    mov     w23, #0
11: cmp     w23, #MAXPEOPLE
    b.ge    19f
    add     w24, w22, w23
    and     w24, w24, #(MAXPEOPLE - 1)
    LA      x9, people
    add     x25, x9, x24, lsl #6
    ldrb    w9, [x25, #P_ALIVE]
    cbz     w9, 18f
    ldrb    w9, [x25, #P_SEX]
    cbz     w9, 18f
    ldrh    w9, [x25, #P_AGE]
    cmp     w9, #MARRYDAYS
    b.lo    18f
    subs    w10, w9, w21                // ate 20 anos de diferenca
    cneg    w10, w10, mi
    cmp     w10, #240
    b.hi    18f
    LA      x9, kin                     // de outra linhagem
    add     x10, x9, x20, lsl #3
    ldrb    w10, [x10, #K_SURN]
    add     x11, x9, x24, lsl #3
    ldrb    w11, [x11, #K_SURN]
    cmp     w10, w11
    b.eq    18f
    mov     w0, w24
    bl      kin_single
    cbz     w0, 18f
    mov     w0, w20
    mov     w1, w24
    bl      vila_marry
    b       19f
18: add     w23, w23, #1
    b       11b
19: add     w20, w20, #1
    b       1b
    // ---- nascimentos ----
20: mov     w20, #0
21: cmp     w20, #MAXPEOPLE
    b.ge    90f
    LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 29f
    ldrb    w9, [x19, #P_SEX]
    cbz     w9, 29f
    ldrh    w9, [x19, #P_AGE]
    cmp     w9, #MARRYDAYS
    b.lo    29f
    cmp     w9, #FERTEND
    b.hi    29f
    LA      x9, kin
    add     x9, x9, x20, lsl #3
    ldrb    w21, [x9, #K_SPOUSE]
    cmp     w21, #255
    b.eq    29f
    LA      x9, people
    add     x9, x9, x21, lsl #6
    ldrb    w9, [x9, #P_ALIVE]
    cbz     w9, 29f
    ldrb    w22, [x19, #P_FAM]          // cabe mais um na casa?
    mov     w0, w22
    bl      vila_members
    mov     w23, w0
    mov     w0, w22
    bl      vila_cap
    cmp     w23, w0
    b.hs    29f
    LA      x9, kin                     // bebe de menos de 1 ano e meio: espera
    LA      x10, people
    mov     w11, #0
22: add     x12, x9, x11, lsl #3
    ldrb    w13, [x12, #K_MOTHER]
    cmp     w13, w20
    b.ne    23f
    add     x12, x10, x11, lsl #6
    ldrb    w13, [x12, #P_ALIVE]
    cbz     w13, 23f
    ldrh    w13, [x12, #P_AGE]
    cmp     w13, #18
    b.lo    29f
23: add     w11, w11, #1
    cmp     w11, #MAXPEOPLE
    b.lt    22b
    mov     w0, #6                      // 1 em 6 por dia
    bl      rng_mod
    cbnz    w0, 29f
    mov     w0, w20
    mov     w1, w21
    bl      vila_birth
29: add     w20, w20, #1
    b       21b
90: ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// tree_grow: muda -> jovem -> adulta (um ano cada; nao no inverno)
tree_grow:
    ldr     w9, [x28, #G_SEASON]
    cmp     w9, #3
    b.eq    9f
    ldr     w9, [x28, #G_NOBJ]
    LA      x10, objs
1:  cbz     w9, 9f
    ldrb    w11, [x10, #6]
    cmp     w11, #O_SAPLING
    b.eq    2f
    cmp     w11, #O_YTREE
    b.ne    8f
2:  ldrb    w12, [x10, #7]
    add     w12, w12, #1
    strb    w12, [x10, #7]
    cmp     w12, #TREEYEAR
    b.lo    8f
    strb    wzr, [x10, #7]
    cmp     w11, #O_SAPLING
    b.ne    3f
    mov     w12, #O_YTREE               // virou jovem
    strb    w12, [x10, #6]
    b       8f
3:  ldrsh   w11, [x10, #4]              // virou adulta (pinheiro no alto)
    mov     w12, #O_TREE
    cmp     w11, #E_GRASS
    b.lt    4f
    mov     w12, #O_PINE
4:  strb    w12, [x10, #6]
    mov     w12, #4
    strb    w12, [x10, #7]
    ldrh    w11, [x10]                  // agora tapa a visao
    lsr     w11, w11, #6
    ldrh    w12, [x10, #2]
    lsr     w12, w12, #6
    add     w11, w11, w12, lsl #9
    LA      x12, treecnt
    ldrb    w13, [x12, w11, uxtw]
    cmp     w13, #255
    cinc    w13, w13, lo
    strb    w13, [x12, w11, uxtw]
8:  add     x10, x10, #8
    sub     w9, w9, #1
    b       1b
9:  ret

// kin_single(w0 = pessoa) -> w0 = 1 se solteira (ou viuva)   folha
kin_single:
    LA      x9, kin
    add     x9, x9, x0, lsl #3
    ldrb    w9, [x9, #K_SPOUSE]
    cmp     w9, #255
    b.eq    7f
    LA      x10, people
    add     x10, x10, x9, lsl #6
    ldrb    w9, [x10, #P_ALIVE]
    cbz     w9, 7f
    mov     w0, #0
    ret
7:  mov     w0, #1
    ret

// fam_alloc(w0 = sobrenome) -> w0 = casa nova (reaproveita uma casa
// vazia) ou -1
fam_alloc:
    LA      x9, fams
    mov     w10, #0
    mov     w15, w0
1:  cmp     w10, #MAXFAM                // casa vazia (todos morreram ou sairam)
    b.ge    3f
    add     x11, x9, x10, lsl #5
    ldrb    w12, [x11, #F_USED]
    cbz     w12, 2f
    ldrb    w12, [x11, #F_LEVEL]
    cbz     w12, 2f
    LA      x12, people
    mov     w13, #0
11: ldrb    w14, [x12, #P_ALIVE]
    cbz     w14, 12f
    ldrb    w14, [x12, #P_FAM]
    cmp     w14, w10
    b.eq    2f
12: add     x12, x12, #PSIZE
    add     w13, w13, #1
    cmp     w13, #MAXPEOPLE
    b.lt    11b
    strb    w15, [x11, #F_SURN]
    mov     w0, w10
    ret
2:  add     w10, w10, #1
    b       1b
3:  mov     w10, #0                     // vaga nova
4:  cmp     w10, #MAXFAM
    b.ge    8f
    add     x11, x9, x10, lsl #5
    ldrb    w12, [x11, #F_USED]
    cbz     w12, 5f
    add     w10, w10, #1
    b       4b
5:  stp     xzr, xzr, [x11]
    stp     xzr, xzr, [x11, #16]
    mov     w12, #-1
    str     w12, [x11, #F_HOUSE]
    str     w12, [x11, #F_LOT]
    mov     w12, #1
    strb    w12, [x11, #F_USED]
    strb    w15, [x11, #F_SURN]
    LA      x12, famvarv
    and     w13, w10, #3
    ldrb    w12, [x12, x13]
    strb    w12, [x11, #F_VAR]
    mov     w0, w10
    ret
8:  mov     w0, #-1
    ret

// vila_marry(w0 noivo, w1 noiva): casam e vao morar numa casa nova
vila_marry:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    LA      x9, kin
    add     x10, x9, x19, lsl #3
    strb    w20, [x10, #K_SPOUSE]
    add     x11, x9, x20, lsl #3
    strb    w19, [x11, #K_SPOUSE]
    ldrb    w0, [x10, #K_SURN]
    bl      fam_alloc
    tbnz    w0, #31, 1f
    LA      x9, people
    add     x10, x9, x19, lsl #6
    strb    w0, [x10, #P_FAM]
    add     x10, x9, x20, lsl #6
    strb    w0, [x10, #P_FAM]
1:  LA      x9, vstat
    ldr     w10, [x9]
    add     w10, w10, #1
    str     w10, [x9]
    LA      x0, pmsgbuf
    LA      x1, s_wed
    bl      strcat_cur
    mov     w1, w19
    bl      ppl_namecat
    LA      x1, s_and
    bl      strcat_cur
    mov     w1, w20
    bl      ppl_namecat
    LA      x0, pmsgbuf
    bl      set_msg
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// vila_birth(w0 mae, w1 pai): nasce um bebe na casa da mae
vila_birth:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     w21, w0
    mov     w22, w1
    LA      x9, kin                     // vaga nunca usada
    mov     w20, #0
1:  cmp     w20, #MAXPEOPLE
    b.ge    9f
    add     x10, x9, x20, lsl #3
    ldrb    w11, [x10, #K_REC]
    cbz     w11, 2f
    add     w20, w20, #1
    b       1b
2:  LA      x9, people
    add     x19, x9, x20, lsl #6
    add     x23, x9, x21, lsl #6        // mae
    stp     xzr, xzr, [x19]
    stp     xzr, xzr, [x19, #16]
    stp     xzr, xzr, [x19, #32]
    stp     xzr, xzr, [x19, #48]
    mov     w9, #1
    strb    w9, [x19, #P_ALIVE]
    ldrb    w9, [x23, #P_FAM]
    strb    w9, [x19, #P_FAM]
    ldr     s0, [x23, #P_U]
    str     s0, [x19, #P_U]
    ldr     s0, [x23, #P_V]
    str     s0, [x19, #P_V]
    PF      s0, 44
    str     s0, [x19, #P_HP]
    str     s0, [x19, #P_FOOD]
    fmov    s0, #30.0
    fadd    s0, s0, s0
    str     s0, [x19, #P_FAITH]         // 60
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
    str     w9, [x19, #P_SKIP]
    mov     w9, #60
    strh    w9, [x19, #P_THINK]
    bl      rng
    and     w9, w0, #1
    strb    w9, [x19, #P_SEX]
    LA      x9, kin
    add     x24, x9, x20, lsl #3
    strb    w22, [x24, #K_FATHER]
    strb    w21, [x24, #K_MOTHER]
    mov     w9, #255
    strb    w9, [x24, #K_SPOUSE]
    mov     w9, #1
    strb    w9, [x24, #K_REC]
    LA      x9, kin
    add     x9, x9, x22, lsl #3
    ldrb    w9, [x9, #K_SURN]
    strb    w9, [x24, #K_SURN]
3:  mov     w0, #12                     // nome diferente dos irmaos
    bl      rng_mod
    ldrb    w9, [x19, #P_SEX]
    mov     w10, #12
    madd    w0, w9, w10, w0
    LA      x9, kin
    LA      x10, people
    mov     w11, #0
4:  cmp     w11, #MAXPEOPLE
    b.ge    5f
    cmp     w11, w20
    b.eq    41f
    add     x12, x9, x11, lsl #3
    ldrb    w13, [x12, #K_REC]
    cbz     w13, 41f
    ldrb    w13, [x12, #K_MOTHER]
    cmp     w13, w21
    b.ne    41f
    add     x12, x10, x11, lsl #6
    ldrb    w13, [x12, #P_NAME]
    cmp     w13, w0
    b.eq    3b
41: add     w11, w11, #1
    b       4b
5:  strb    w0, [x19, #P_NAME]
    LA      x9, vstat
    ldr     w10, [x9, #4]
    add     w10, w10, #1
    str     w10, [x9, #4]
    LA      x0, pmsgbuf
    LA      x1, s_born
    bl      strcat_cur
    mov     w1, w20
    bl      ppl_namecat
    LA      x1, s_born2
    bl      strcat_cur
    LA      x9, people
    add     x9, x9, x21, lsl #6
    LA      x1, pnames
    ldrb    w9, [x9, #P_NAME]
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    LA      x1, s_born3
    bl      strcat_cur
    LA      x0, pmsgbuf
    bl      set_msg
9:  ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
//  Painel: titulo e arvore genealogica
// ---------------------------------------------------------------------

// vila_title(x0 = cursor) -> x0: "Vila: 12 pessoas, barracos: 3, casas: 1"
    .globl vila_title
vila_title:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x19, x0
    LA      x9, fams
    mov     w10, #0
    mov     w20, #0                     // barracos
    mov     w21, #0                     // casas
1:  ldrb    w11, [x9, #F_USED]
    cbz     w11, 2f
    ldrb    w11, [x9, #F_LEVEL]
    cmp     w11, #1
    cinc    w20, w20, eq
    cmp     w11, #2
    cinc    w21, w21, eq
2:  add     x9, x9, #FSIZE
    add     w10, w10, #1
    cmp     w10, #MAXFAM
    b.lt    1b
    mov     x0, x19
    LA      x1, s_vtitle
    bl      strcat_cur
    ldr     w1, [x28, #G_PEOPLEN]
    bl      numcat
    LA      x1, s_vpeople
    bl      strcat_cur
    mov     w1, w20
    bl      numcat
    LA      x1, s_vhuts
    bl      strcat_cur
    mov     w1, w21
    bl      numcat
    LA      x1, s_vhouses
    bl      strcat_cur
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// tree_lines -> w0 = linhas da arvore em tlines (3 bytes: tipo 0 titulo /
// 1 pessoa, profundidade, pessoa ou sobrenome)
    .globl tree_lines
tree_lines:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    LA      x9, tlinen
    str     wzr, [x9]
    mov     w19, #0                     // sobrenome
1:  cmp     w19, #NSURN
    b.ge    9f
    mov     w0, #0
    mov     w1, #0
    mov     w2, w19
    bl      tl_add
    mov     w20, #0                     // raizes: homens sem pais
2:  cmp     w20, #MAXPEOPLE
    b.ge    8f
    LA      x9, kin
    add     x9, x9, x20, lsl #3
    ldrb    w10, [x9, #K_REC]
    cbz     w10, 7f
    ldrb    w10, [x9, #K_SURN]
    cmp     w10, w19
    b.ne    7f
    ldrb    w10, [x9, #K_FATHER]
    cmp     w10, #255
    b.ne    7f
    ldrb    w10, [x9, #K_MOTHER]
    cmp     w10, #255
    b.ne    7f
    LA      x9, people
    add     x9, x9, x20, lsl #6
    ldrb    w10, [x9, #P_SEX]
    cbnz    w10, 7f
    mov     w0, w20
    mov     w1, #0
    bl      tree_dfs
7:  add     w20, w20, #1
    b       2b
8:  add     w19, w19, #1
    b       1b
9:  LA      x9, tlinen
    ldr     w0, [x9]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// tl_add(w0 tipo, w1 profundidade, w2 quem)   folha
tl_add:
    LA      x9, tlinen
    ldr     w10, [x9]
    cmp     w10, #MAXTLINES
    b.hs    9f
    add     w11, w10, #1
    str     w11, [x9]
    LA      x9, tlines
    mov     w11, #3
    mul     w10, w10, w11
    add     x9, x9, x10
    strb    w0, [x9]
    strb    w1, [x9, #1]
    strb    w2, [x9, #2]
9:  ret

// tree_dfs(w0 pessoa, w1 profundidade): a pessoa e os filhos dela
tree_dfs:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     w2, w19
    mov     w0, #1
    bl      tl_add
    cmp     w20, #6
    b.hs    9f
    mov     w21, #0
1:  cmp     w21, #MAXPEOPLE
    b.ge    9f
    LA      x9, kin
    add     x9, x9, x21, lsl #3
    ldrb    w10, [x9, #K_REC]
    cbz     w10, 2f
    ldrb    w10, [x9, #K_FATHER]
    cmp     w10, w19
    b.eq    11f
    ldrb    w10, [x9, #K_MOTHER]
    cmp     w10, w19
    b.ne    2f
11: mov     w0, w21
    add     w1, w20, #1
    bl      tree_dfs
2:  add     w21, w21, #1
    b       1b
9:  ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// tl_person(x0 cursor, w1 pessoa) -> x0: "Ana Silva 27" (+ " (morreu)")
tl_person:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, w1
    bl      ppl_namecat
    LA      x1, s_sp1
    bl      strcat_cur
    LA      x9, people
    add     x9, x9, x19, lsl #6
    ldrh    w9, [x9, #P_AGE]
    mov     w10, #12
    udiv    w1, w9, w10
    bl      numcat
    LA      x9, kin
    add     x9, x9, x19, lsl #3
    ldrb    w9, [x9, #K_REC]
    cmp     w9, #2
    b.lo    9f
    LA      x1, s_tdead
    b.eq    1f
    LA      x1, s_tleft
1:  bl      strcat_cur
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// vila_drawtree(w0 = primeira linha, w1 x, w2 y): desenha ate 14 linhas
// da arvore genealogica -> w0 = total de linhas
    .globl vila_drawtree
vila_drawtree:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    bl      tree_lines
    mov     w22, w0
    mov     w23, #0                     // linha na tela
1:  cmp     w23, #14
    b.ge    9f
    add     w24, w19, w23
    cmp     w24, w22
    b.ge    9f
    LA      x9, tlines
    mov     w10, #3
    mul     w10, w24, w10
    add     x25, x9, x10
    mov     w9, #16
    madd    w26, w23, w9, w21           // y
    ldrb    w9, [x25]
    cbnz    w9, 3f
    // ---- titulo da familia ----
    LA      x0, tbuf
    LA      x1, s_tfam
    bl      strcat_cur
    ldrb    w9, [x25, #2]
    LA      x1, psurn
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    RGBA    255, 215, 90, 255
    mov     w0, w20
    mov     w1, w26
    LA      x2, tbuf
    bl      text
    b       8f
    // ---- pessoa (e o conjuge) ----
3:  LA      x0, tbuf
    ldrb    w24, [x25, #1]              // recuo: "  " por geracao, "- " no fim
    cbz     w24, 32f
31: LA      x1, s_sp2
    bl      strcat_cur
    subs    w24, w24, #1
    b.ne    31b
    LA      x1, s_dash
    bl      strcat_cur
32: ldrb    w1, [x25, #2]
    bl      tl_person
    LA      x9, kin
    ldrb    w10, [x25, #2]
    add     x9, x9, x10, lsl #3
    ldrb    w24, [x9, #K_SPOUSE]
    cmp     w24, #255
    b.eq    33f
    LA      x1, s_plus
    bl      strcat_cur
    mov     w1, w24
    bl      tl_person
33: LA      x9, kin                     // morta: cinza
    ldrb    w10, [x25, #2]
    add     x9, x9, x10, lsl #3
    ldrb    w9, [x9, #K_REC]
    cmp     w9, #1
    b.ne    34f
    RGBA    235, 235, 240, 255
    b       35f
34: RGBA    140, 140, 150, 255
35: mov     w0, w20
    mov     w1, w26
    LA      x2, tbuf
    bl      text
8:  add     w23, w23, #1
    b       1b
9:  mov     w0, w22
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ---------------------------------------------------------------------
    .data
    .p2align 2
// obras: madeira e pedra (barraco, casa, cerca)
buildcost:
    .byte 0, 0,  10, 0,  25, 10,  12, 0
// passos de trabalho de cada obra
buildsteps:
    .byte 0, 4, 8, 6
// cor de cada familia (variante do telhado e da roupa)
famvarv:
    .byte 0, 2, 3, 1
s_os:       .asciz "Os "
s_bhut:     .asciz " fizeram um barraco"
s_bhouse:   .asciz " agora tem uma casa (cabem 8)"
s_bfence:   .asciz " cercaram o terreno"
s_nolot:    .asciz "Obras: falta lugar para os "
s_nolot2:   .asciz ". Pinte uma zona de Moradia (Z, 4)"
s_wed:      .asciz "Casamento: "
s_and:      .asciz " e "
s_born:     .asciz "Nasceu "
s_born2:    .asciz ", filho(a) de "
s_born3:    .asciz "!"
s_vtitle:   .asciz "Vila: "
s_vpeople:  .asciz " pessoas, barracos: "
s_vhuts:    .asciz ", casas: "
s_vhouses:  .asciz ""
s_tfam:     .asciz "Familia "
s_sp1:      .asciz " "
s_sp2:      .asciz "  "
s_dash:     .asciz "- "
s_plus:     .asciz " + "
s_tdead:    .asciz " (morreu)"
s_tleft:    .asciz " (foi embora)"
    .p2align 2
tlinen:     .word 0
tbuf:       .space 96
tlines:     .space (MAXTLINES * 3)
    .p2align 2
    .globl vstat
vstat:      .word 0, 0, 0, 0            // casamentos, nascimentos

GBSS kin, (MAXPEOPLE * 8)
GBSS fams, (MAXFAM * FSIZE)
