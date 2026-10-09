// =====================================================================
//  ferro.S - fornalha, lampioes, ferreiro, ferramentas de ferro da vila
//  e a visao dos moradores
//
//  - Veios de ferro e de carvao nascem nas colinas, rocha e neve; so a
//    picareta quebra (sobrevivencia.S). Na fornalha: 2 minerio + 1 carvao
//    = 1 barra de ferro; 3 madeira = 1 carvao.
//  - Perto de uma fornalha (3 celulas) aparecem as receitas de ferro.
//  - Lampiao: luz de noite (7 celulas) e visao em volta, sem lenha.
//  - Ferreiro (tarefa da vila): pega minerio e carvao no bau, trabalha na
//    fornalha mais perto e guarda a barra; sem minerio, faz carvao de
//    madeira (ate ter 10 no bau).
//  - Ferramentas da vila: quem tem tarefa (Floresta, Pedra, Plantar) pega
//    no bau o machado / picareta / enxada de ferro e trabalha 2x mais
//    rapido.
//  - Cada morador enxerga em volta (7 celulas de dia, 3 de noite): o mapa
//    se revela por onde a vila anda.
// =====================================================================

#include "comum.h"
#include "pessoas.h"

// constante float da tabela itf (usa x16)
.macro PF_IT sreg, off
    LA      x16, itf
    ldr     \sreg, [x16, #\off]
.endm

    .text
    .p2align 2

// iron_reset: sem lampioes; ferramentas de ferro novas
    .globl iron_reset
iron_reset:
    str     wzr, [x28, #G_NLAMP]
    str     wzr, [x28, #G_NEARFURN]
    str     wzr, [x28, #G_FURNT]
    mov     w9, #IRONDUR
    str     w9, [x28, #G_IRONDUR]
    str     w9, [x28, #(G_IRONDUR + 4)]
    str     w9, [x28, #(G_IRONDUR + 8)]
    ret

// iron_update: a cada 15 quadros ve se tem uma fornalha a ate 3 celulas
    .globl iron_update
iron_update:
    ldr     w9, [x28, #G_FURNT]
    add     w9, w9, #1
    cmp     w9, #15
    b.lo    8f
    mov     w9, #0
    ldr     s0, [x28, #G_PU]            // personagem em 1/64 de celula
    FC      s2, F_64
    fmul    s0, s0, s2
    fcvtzs  w12, s0
    ldr     s1, [x28, #G_PV]
    fmul    s1, s1, s2
    fcvtzs  w13, s1
    mov     w14, #0
    ldr     w10, [x28, #G_NOBJ]
    LA      x11, objs
1:  cbz     w10, 7f
    ldrb    w15, [x11, #6]
    cmp     w15, #O_FURNACE
    b.ne    2f
    ldrh    w15, [x11]
    sub     w15, w15, w12
    ldrh    w16, [x11, #2]
    sub     w16, w16, w13
    mul     w15, w15, w15
    madd    w15, w16, w16, w15
    mov     w16, #36864                 // (3 celulas)^2
    cmp     w15, w16
    b.hi    2f
    mov     w14, #1
    b       7f
2:  add     x11, x11, #8
    sub     w10, w10, #1
    b       1b
7:  str     w14, [x28, #G_NEARFURN]
8:  str     w9, [x28, #G_FURNT]
    ret

// ---------------------------------------------------------------------
//  Lampioes
// ---------------------------------------------------------------------

// lamp_add(w0 = objeto)   folha
    .globl lamp_add
lamp_add:
    ldr     w9, [x28, #G_NLAMP]
    cmp     w9, #MAXLAMP
    b.hs    9f
    LA      x10, lamps
    str     w0, [x10, x9, lsl #2]
    add     w9, w9, #1
    str     w9, [x28, #G_NLAMP]
9:  ret

// lamps_light(w0 = escala * 256): luz de cada lampiao (de noite)
    .globl lamps_light
lamps_light:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w21, w0
    mov     w19, #0
1:  ldr     w9, [x28, #G_NLAMP]
    cmp     w19, w9
    b.ge    9f
    LA      x9, lamps
    ldr     w9, [x9, x19, lsl #2]
    LA      x20, objs
    add     x20, x20, x9, lsl #3
    ldrb    w10, [x20, #6]
    cmp     w10, #O_LAMP
    b.ne    8f
    ldrh    w10, [x20]
    ucvtf   s0, w10
    ldrh    w10, [x20, #2]
    ucvtf   s1, w10
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    ldrsh   w0, [x20, #4]
    bl      proj
    mov     w9, #12                     // a luz fica la em cima
    mul     w9, w9, w21
    asr     w9, w9, #8
    sub     w1, w1, w9
    mov     w2, #28                     // 7 celulas
    mul     w2, w2, w21
    lsr     w2, w2, #8
    mov     w3, #230
    bl      add_light
8:  add     w19, w19, #1
    b       1b
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// lamps_vision: cada lampiao revela 6 celulas em volta
    .globl lamps_vision
lamps_vision:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, #0
1:  ldr     w9, [x28, #G_NLAMP]
    cmp     w19, w9
    b.ge    9f
    LA      x9, lamps
    ldr     w9, [x9, x19, lsl #2]
    LA      x20, objs
    add     x20, x20, x9, lsl #3
    ldrb    w10, [x20, #6]
    cmp     w10, #O_LAMP
    b.ne    8f
    ldrh    w10, [x20]
    ucvtf   s0, w10
    ldrh    w10, [x20, #2]
    ucvtf   s1, w10
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    LA      x9, fconst
    ldr     s2, [x9, #8]                // 6 celulas
    bl      cast_vision
8:  add     w19, w19, #1
    b       1b
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// people_vision: cada morador (fora de casa) enxerga em volta: 7 celulas
// de dia, 3 de noite (menos com chuva e neve), com 120 raios
    .globl people_vision
people_vision:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     d8, d9, [sp, #32]
    ldr     w9, [x28, #G_NOPEOPLE]
    cbnz    w9, 9f
    ldr     w9, [x28, #G_NIGHTK]        // 7 - 4 * noite
    scvtf   s0, w9
    LA      x9, fconst
    ldr     s1, [x9, #12]               // 4 / 256
    fmul    s0, s0, s1
    ldr     s8, [x9, #16]               // 7
    fsub    s8, s8, s0
    ldr     s1, [x28, #G_WVIS]
    fmul    s8, s8, s1
    mov     w20, #0
1:  cmp     w20, #MAXPEOPLE
    b.ge    9f
    LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 8f
    ldrb    w9, [x19, #P_FLAGS]         // dentro de casa: nao
    tbnz    w9, #0, 8f
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    fmov    s2, s8
    LA      x9, fconst
    ldr     s3, [x9]                    // cos 3 graus
    ldr     s4, [x9, #4]                // sin 3 graus
    mov     w0, #120
    bl      cast_vision_n
8:  add     w20, w20, #1
    b       1b
9:  ldp     d8, d9, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
//  Ferreiro e ferramentas da vila (x19 = pessoa, w20 = numero)
// ---------------------------------------------------------------------

// furnace_near -> w0 = fornalha mais perto da pessoa (-1)   folha
furnace_near:
    mov     w0, #-1
    LA      x9, fconst
    ldr     s4, [x9, #20]               // longe demais
    ldr     w10, [x28, #G_NOBJ]
    mov     w11, #0
    LA      x14, objs
1:  cmp     w11, w10
    b.ge    9f
    ldrb    w15, [x14, #6]
    cmp     w15, #O_FURNACE
    b.ne    2f
    ldrh    w15, [x14]
    ucvtf   s0, w15
    ldrh    w15, [x14, #2]
    ucvtf   s1, w15
    FC      s2, F_INV64
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
9:  ret

// smith_chest(w0 item, w1 quantos, w2 item 2, w3 quantos 2 (0 = nada))
// -> w0 = bau com isso mais perto da pessoa (-1)   folha
    .globl smith_chest
smith_chest:
    mov     w12, w0
    mov     w13, w1
    mov     w0, #-1
    LA      x9, fconst
    ldr     s4, [x9, #20]
    ldr     w10, [x28, #G_NOBJ]
    mov     w11, #0
    LA      x14, objs
1:  cmp     w11, w10
    b.ge    9f
    ldrb    w15, [x14, #6]
    cmp     w15, #O_CHEST
    b.ne    2f
    ldrb    w15, [x14, #7]
    LA      x16, chests
    add     x16, x16, x15, lsl #CHESTSHIFT
    ldr     w15, [x16, x12, lsl #2]
    cmp     w15, w13
    b.lo    2f
    cbz     w3, 11f
    ldr     w15, [x16, x2, lsl #2]
    cmp     w15, w3
    b.lo    2f
11: ldrh    w15, [x14]
    ucvtf   s0, w15
    ldrh    w15, [x14, #2]
    ucvtf   s1, w15
    LA      x16, fconst
    ldr     s2, [x16, #24]              // 1/64
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
9:  ret

// smith_work -> w0 = 1 se o ferreiro achou o que fazer (ja indo)
    .globl smith_work
smith_work:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    bl      furnace_near
    tbnz    w0, #31, 8f
    mov     w21, w0
    ldrb    w9, [x19, #P_BFAM]          // ja pegou o material: fornalha
    cbz     w9, 1f
    mov     w0, w21
    mov     w1, #WK_SMELT
    bl      ppl_gowork_obj
    b       7f
1:  mov     w0, #IT_ORE                 // barra: 2 minerio + 1 carvao
    mov     w1, #2
    mov     w2, #IT_COAL
    mov     w3, #1
    bl      smith_chest
    tbnz    w0, #31, 2f
    mov     w9, #1
    strb    w9, [x19, #P_BPROJ]
    mov     w1, #NX_SMITH
    bl      ppl_gochest
    b       7f
2:  mov     w0, #IT_WOOD                // carvao: 3 madeira (se o bau tem pouco)
    mov     w1, #3
    mov     w2, #0
    mov     w3, #0
    bl      smith_chest
    tbnz    w0, #31, 8f
    mov     w22, w0
    bl      ppl_chestptr
    ldr     w9, [x0, #(4 * IT_COAL)]
    cmp     w9, #10
    b.hs    8f
    mov     w9, #2
    strb    w9, [x19, #P_BPROJ]
    mov     w0, w22
    mov     w1, #NX_SMITH
    bl      ppl_gochest
7:  mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// smith_pay: o ferreiro chegou ao bau: pega o material e vai a fornalha
    .globl smith_pay
smith_pay:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w0, [x19, #P_TARGET]
    bl      ppl_chestptr
    cbz     x0, 8f
    ldrb    w9, [x19, #P_BPROJ]
    cmp     w9, #1
    b.ne    2f
    ldr     w10, [x0, #(4 * IT_ORE)]    // barra
    cmp     w10, #2
    b.lo    8f
    ldr     w11, [x0, #(4 * IT_COAL)]
    cbz     w11, 8f
    sub     w10, w10, #2
    str     w10, [x0, #(4 * IT_ORE)]
    sub     w11, w11, #1
    str     w11, [x0, #(4 * IT_COAL)]
    b       3f
2:  ldr     w10, [x0, #(4 * IT_WOOD)]   // carvao
    cmp     w10, #3
    b.lo    8f
    sub     w10, w10, #3
    str     w10, [x0, #(4 * IT_WOOD)]
3:  mov     w9, #1                      // material na mao
    strb    w9, [x19, #P_BFAM]
    bl      furnace_near
    tbnz    w0, #31, 8f
    mov     w1, #WK_SMELT
    bl      ppl_gowork_obj
    b       9f
8:  mov     w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    mov     w9, #30
    strh    w9, [x19, #P_THINK]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
9:  ldp     x29, x30, [sp], #16
    ret

// smith_valid(w0 = alvo) -> w0 = 1 se ainda e uma fornalha   folha
    .globl smith_valid
smith_valid:
    tbnz    w0, #31, 8f
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrb    w9, [x9, #6]
    cmp     w9, #O_FURNACE
    cset    w0, eq
    ret
8:  mov     w0, #0
    ret

// smith_done: saiu da fornalha uma barra de ferro (ou um carvao)
    .globl smith_done
smith_done:
    strb    wzr, [x19, #P_BFAM]
    ldrb    w9, [x19, #P_BPROJ]
    mov     w0, #IT_IRON
    cmp     w9, #1
    b.eq    1f
    mov     w0, #IT_COAL
1:  mov     w1, #1
    b       pinv_add                    // na mochila

// tool_fetch -> w0 = 1 se vai ao bau pegar a ferramenta de ferro da tarefa
    .globl tool_fetch
tool_fetch:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldrb    w9, [x19, #P_JOB]
    LA      x10, jobtool
    ldrb    w9, [x10, x9]
    cbz     w9, 8f
    str     w9, [sp, #-16]!
    mov     w0, w9                      // ja tem na mochila?
    bl      pinv_get
    mov     w10, w0
    ldr     w9, [sp], #16
    cbnz    w10, 8f
    mov     w0, w9
    mov     w1, #1
    mov     w2, #0
    mov     w3, #0
    bl      smith_chest
    tbnz    w0, #31, 8f
    mov     w1, #NX_TOOL
    bl      ppl_gochest
    mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldp     x29, x30, [sp], #16
    ret

// tool_take: chegou ao bau: troca pela ferramenta de ferro da tarefa
    .globl tool_take
tool_take:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w0, [x19, #P_TARGET]
    bl      ppl_chestptr
    cbz     x0, 9f
    ldrb    w9, [x19, #P_JOB]
    LA      x10, jobtool
    ldrb    w9, [x10, x9]
    cbz     w9, 9f
    ldr     w10, [x0, x9, lsl #2]
    cbz     w10, 9f
    sub     w10, w10, #1
    str     w10, [x0, x9, lsl #2]
    mov     w0, w9                      // na mochila (a de antes fica la ate
    mov     w1, #1                      // guardar no bau)
    bl      pinv_add
9:  ldp     x29, x30, [sp], #16
    ret

// tool_bonus -> w0 = 1 se a pessoa tem a ferramenta de ferro da tarefa  folha
    .globl tool_bonus
tool_bonus:
    ldrb    w9, [x19, #P_JOB]
    LA      x10, jobtool
    ldrb    w9, [x10, x9]
    mov     w0, #0
    cbz     w9, 9f
    cmp     w9, #IT_ROD                 // a vara so deixa pescar
    b.eq    9f
    LA      x10, pinv
    add     x10, x10, x20, lsl #8
    ldr     w10, [x10, x9, lsl #2]
    cmp     w10, #0
    cset    w0, ne
9:  ret


// =====================================================================
//  Teste automatico (--shot)
//    0: voce: veio sem picareta nao quebra; com ela, minerio e carvao;
//       fornalha, barras, carvao de madeira, ferramentas, espada,
//       armadura e lampiao; machado de ferro mais rapido; armadura contra
//       o lobo. Termina de noite ao lado da fornalha e do lampiao (foto)
//    1: a vila: ferreiro na fornalha, um veio na zona de pedra e o
//       machado de ferro no bau para quem trabalha na floresta
// =====================================================================

// it_num(x0 cursor, x1 rotulo, w2 numero) -> x0
it_num:
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

// it_craft(w0 = receita, w1 = vezes)
it_craft:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, w0
    mov     w20, w1
1:  cbz     w20, 9f
    mov     w0, w19
    bl      craft
    sub     w20, w20, #1
    b       1b
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// it_freecell(w0 u, w1 v) -> w0 = celula livre em terra a 2-5 celulas (-1)
it_freecell:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     x23, [sp, #48]
    mov     w19, w0
    mov     w20, w1
    mov     w21, #-5                    // dv
1:  mov     w23, #-5                    // du
2:  cmp     w21, #0                     // pelo menos 2 celulas de distancia
    cneg    w9, w21, lt
    cmp     w23, #0
    cneg    w10, w23, lt
    cmp     w9, w10
    csel    w9, w9, w10, gt
    cmp     w9, #2
    b.lt    3f
    add     w10, w19, w23
    add     w11, w20, w21
    cmp     w10, #4
    b.lt    3f
    cmp     w11, #4
    b.lt    3f
    cmp     w10, #507
    b.gt    3f
    cmp     w11, #507
    b.gt    3f
    add     w22, w10, w11, lsl #9
    mov     w0, w22
    bl      obj_in_cell
    tbz     w0, #31, 3f
    LA      x9, fencegrid
    ldrb    w13, [x9, w22, uxtw]
    cbnz    w13, 3f
    LA      x9, zonegrid
    ldrb    w13, [x9, w22, uxtw]
    cmp     w13, #Z_LOT
    b.eq    3f
    LA      x9, treecnt
    ldrb    w13, [x9, w22, uxtw]
    cbnz    w13, 3f
    LA      x9, elev                    // em terra boa
    ldrsh   w13, [x9, w22, uxtw #1]
    ldr     w14, [x28, #G_FLOOD]
    cmp     w13, w14
    b.lt    3f
    cmp     w13, #(E_SAND + 20)
    b.ge    8f
3:  add     w23, w23, #1
    cmp     w23, #5
    b.le    2b
    add     w21, w21, #1
    cmp     w21, #5
    b.le    1b
    mov     w22, #-1
8:  mov     w0, w22
    ldr     x23, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// it_addobj(w0 celula, w1 tipo, w2 variante): objeto no meio da celula
it_addobj:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    and     w9, w19, #511
    lsr     w10, w19, #9
    scvtf   s0, w9
    scvtf   s1, w10
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      elev_at
    mov     w2, w0
    and     w9, w19, #511
    lsl     w0, w9, #6
    add     w0, w0, #32
    lsr     w9, w19, #9
    lsl     w1, w9, #6
    add     w1, w1, #32
    mov     w3, w20
    mov     w4, w21
    bl      add_obj
    ldr     w0, [x28, #G_NOBJ]
    sub     w0, w0, #1
    LA      x9, memtype
    strb    w20, [x9, w0, uxtw]
    mov     w9, #-1
    str     w9, [x28, #G_OCCFRAME]
    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// it_light: esvazia a mochila (menos o que vai ser testado)
it_light:
    add     x9, x28, #G_INV
    mov     w10, #MAXITEMS
1:  str     wzr, [x9], #4
    subs    w10, w10, #1
    b.ne    1b
    str     wzr, [x28, #G_HAND]
    ret

// it_frames(w0 = quadros)
it_frames:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w0
1:  cbz     w19, 9f
    bl      surv_update
    sub     w19, w19, #1
    b       1b
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

    .globl iron_selftest
iron_selftest:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     d8, d9, [sp, #80]
    mov     w21, w0
    str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_HOVOK]
    str     wzr, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CRAFTOPEN]
    str     wzr, [x28, #G_CHESTOPEN]
    str     wzr, [x28, #G_PLACE]
    str     wzr, [x28, #G_PEOPLEOPEN]
    mov     w9, #6000                   // de dia
    str     w9, [x28, #G_TIME]
    cmp     w21, #1
    b.eq    it_stage1
    // ---- etapa 0: voce ----
    LA      x19, itres
    PF_IT   s0, 0                       // vida, fome e calor cheios
    str     s0, [x28, #G_HP]
    str     s0, [x28, #G_FOOD]
    str     s0, [x28, #G_WARM]
    str     wzr, [x28, #G_DEAD]
    ldr     s0, [x28, #G_PU]            // um veio de ferro e um de carvao
    fcvtzs  w0, s0                      // do lado
    ldr     s0, [x28, #G_PV]
    fcvtzs  w1, s0
    bl      it_freecell
    tbnz    w0, #31, 71f
    mov     w1, #O_IRONV
    mov     w2, #4
    bl      it_addobj
71: ldr     s0, [x28, #G_PU]
    fcvtzs  w0, s0
    ldr     s0, [x28, #G_PV]
    fcvtzs  w1, s0
    bl      it_freecell
    tbnz    w0, #31, 72f
    mov     w1, #O_COALV
    mov     w2, #5
    bl      it_addobj
72: bl      it_light                    // mochila vazia (o peso trava a coleta)
    mov     w9, #1
    str     w9, [x28, #(G_INV + 4 * IT_PICK)]
    str     w9, [x28, #(G_INV + 4 * IT_AXE)]
    ldr     w22, [x28, #(G_INV + 4 * IT_ORE)]
    str     wzr, [x28, #G_HAND]         // sem picareta: o veio nao quebra
    mov     w0, #O_IRONV
    mov     w1, #O_IRONV
    bl      mine_test
    ldr     w9, [x28, #(G_INV + 4 * IT_ORE)]
    sub     w9, w9, w22
    str     w9, [x19]
    mov     w9, #(IT_PICK + 1)          // com a picareta
    str     w9, [x28, #G_HAND]
    ldr     w22, [x28, #(G_INV + 4 * IT_ORE)]
    mov     w0, #O_IRONV
    mov     w1, #O_IRONV
    bl      mine_test
    ldr     w9, [x28, #(G_INV + 4 * IT_ORE)]
    sub     w9, w9, w22
    str     w9, [x19, #4]
    ldr     w22, [x28, #(G_INV + 4 * IT_COAL)]
    mov     w0, #O_COALV
    mov     w1, #O_COALV
    bl      mine_test
    ldr     w9, [x28, #(G_INV + 4 * IT_COAL)]
    sub     w9, w9, w22
    str     w9, [x19, #8]
    // material de presente para o resto
    ldr     w9, [x28, #(G_INV + 4 * IT_ORE)]
    add     w9, w9, #40
    str     w9, [x28, #(G_INV + 4 * IT_ORE)]
    ldr     w9, [x28, #(G_INV + 4 * IT_COAL)]
    add     w9, w9, #20
    str     w9, [x28, #(G_INV + 4 * IT_COAL)]
    ldr     w9, [x28, #G_WOOD]
    add     w9, w9, #40
    str     w9, [x28, #G_WOOD]
    ldr     w9, [x28, #G_STONE]
    add     w9, w9, #20
    str     w9, [x28, #G_STONE]
    ldr     w9, [x28, #(G_INV + 4 * IT_HIDE)]
    add     w9, w9, #2
    str     w9, [x28, #(G_INV + 4 * IT_HIDE)]
    bl      surv_update
    // fornalha do lado
    ldr     s8, [x28, #G_PU]
    ldr     s9, [x28, #G_PV]
    mov     w0, #19
    bl      craft
    fmov    s0, #2.0
    fadd    s0, s8, s0
    fmov    s1, s9
    bl      ct_click
    mov     w0, #O_FURNACE
    bl      ct_count
    str     w0, [x19, #12]
    mov     w0, #16
    bl      it_frames
    ldr     w9, [x28, #G_NEARFURN]
    str     w9, [x19, #16]
    mov     w0, #20                     // 18 barras
    mov     w1, #18
    bl      it_craft
    ldr     w9, [x28, #(G_INV + 4 * IT_IRON)]
    str     w9, [x19, #20]
    ldr     w22, [x28, #(G_INV + 4 * IT_COAL)]
    mov     w0, #21                     // carvao de madeira
    mov     w1, #1
    bl      it_craft
    ldr     w9, [x28, #(G_INV + 4 * IT_COAL)]
    sub     w9, w9, w22
    str     w9, [x19, #24]
    mov     w22, #22                    // machado, picareta, enxada, espada, armadura
1:  mov     w0, w22
    bl      craft
    add     w22, w22, #1
    cmp     w22, #27
    b.lt    1b
    mov     w9, #0
    mov     w10, #IT_IAXE
2:  add     x11, x28, #G_INV
    ldr     w11, [x11, x10, lsl #2]
    add     w9, w9, w11
    add     w10, w10, #1
    cmp     w10, #IT_ARMOR
    b.ls    2b
    str     w9, [x19, #28]
    mov     w0, #27                     // lampiao do outro lado
    bl      craft
    fmov    s0, s8
    fmov    s1, #2.0
    fadd    s1, s9, s1
    bl      ct_click
    ldr     w9, [x28, #G_NLAMP]
    str     w9, [x19, #32]
    // machado: tempo por madeira, de pedra e de ferro (mochila leve)
    bl      it_light
    mov     w9, #1
    str     w9, [x28, #(G_INV + 4 * IT_AXE)]
    str     w9, [x28, #(G_INV + 4 * IT_ARMOR)]
    mov     w9, #(IT_AXE + 1)
    str     w9, [x28, #G_HAND]
    str     wzr, [x28, #(G_INV + 4 * IT_IAXE)]
    mov     w0, #O_TREE
    mov     w1, #O_PINE
    bl      mine_test
    ldr     w9, [x28, #G_MINENEED]
    str     w9, [x19, #36]
    mov     w9, #1
    str     w9, [x28, #(G_INV + 4 * IT_IAXE)]
    mov     w0, #O_TREE
    mov     w1, #O_PINE
    bl      mine_test
    ldr     w9, [x28, #G_MINENEED]
    str     w9, [x19, #40]
    // armadura: mordida do lobo pela metade
    str     s8, [x28, #G_PU]
    str     s9, [x28, #G_PV]
    bl      surv_update
    PF_IT   s0, 0
    str     s0, [x28, #G_HP]
    bl      animals_reset
    ldr     w9, [x28, #G_NOPEOPLE]      // (sem a vila por perto: o lobo vem
    str     w9, [x19, #60]              // em voce)
    mov     w9, #1
    str     w9, [x28, #G_NOPEOPLE]
    mov     w22, #0                     // o lobo do lado, em terra
33: LA      x9, itwolf
    add     x9, x9, x22, lsl #3
    ldr     s0, [x9]
    ldr     s1, [x9, #4]
    ldr     s2, [x28, #G_PU]
    fadd    s0, s0, s2
    ldr     s2, [x28, #G_PV]
    fadd    s1, s1, s2
    stp     s0, s1, [sp, #-16]!
    bl      elev_at
    ldp     s0, s1, [sp], #16
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    b.ge    34f
    add     w22, w22, #1
    cmp     w22, #4
    b.lt    33b
34: LA      x9, animals
31: str     s0, [x9]
    str     s1, [x9, #4]
    stp     xzr, xzr, [x9, #8]
    stp     xzr, xzr, [x9, #24]
    str     wzr, [x9, #16]
    str     wzr, [x9, #20]
    mov     w10, #A_WOLF
    strb    w10, [x9, #16]
    mov     w10, #6
    strb    w10, [x9, #17]
    mov     w22, #0
3:  bl      surv_update
    ldr     s0, [x28, #G_HP]
    PF_IT   s1, 0
    fcmp    s0, s1
    b.lt    4f
    add     w22, w22, #1
    cmp     w22, #600
    b.lt    3b
4:  PF_IT   s1, 0
    fsub    s1, s1, s0
    fcvtzs  w9, s1
    str     w9, [x19, #44]
    ldr     w9, [x19, #60]
    str     w9, [x28, #G_NOPEOPLE]
    bl      animals_reset
    PF_IT   s0, 0
    str     s0, [x28, #G_HP]
    // foto: de noite, entre a fornalha e o lampiao
    str     s8, [x28, #G_PU]
    str     s9, [x28, #G_PV]
    mov     w9, #31000
    str     w9, [x28, #G_TIME]
    str     wzr, [x28, #G_HAND]
    mov     w0, #4
    bl      it_frames
    str     wzr, [x28, #G_MSGT]         // (sem mensagens na foto)
    str     wzr, [x28, #G_POPT]
    // ---- imprime ----
    LA      x0, txt
    LA      x1, it_t1
    ldr     w2, [x19]
    bl      it_num
    LA      x1, it_t2
    ldr     w2, [x19, #4]
    bl      it_num
    LA      x1, it_t3
    ldr     w2, [x19, #8]
    bl      it_num
    LA      x1, it_t4
    ldr     w2, [x19, #12]
    bl      it_num
    LA      x1, it_t5
    ldr     w2, [x19, #16]
    bl      it_num
    LA      x1, it_t6
    ldr     w2, [x19, #20]
    bl      it_num
    LA      x1, it_t7
    ldr     w2, [x19, #24]
    bl      it_num
    LA      x1, it_t8
    ldr     w2, [x19, #28]
    bl      it_num
    LA      x1, it_t9
    ldr     w2, [x19, #32]
    bl      it_num
    LA      x1, it_t10
    ldr     w2, [x19, #36]
    bl      it_num
    LA      x1, it_t11
    ldr     w2, [x19, #40]
    bl      it_num
    LA      x1, it_t12
    ldr     w2, [x19, #44]
    bl      it_num
    LA      x1, it_nl
    bl      strcat_cur
    bl      sk_write
    b       it_ret

    // ---- etapa 1: a vila ----
it_stage1:
    ldr     w9, [x28, #G_NOPEOPLE]
    cbnz    w9, it_ret
    LA      x19, people                 // bau mais perto da primeira pessoa
    mov     w20, #0
    mov     w0, #IT_WOOD
    mov     w1, #0
    mov     w2, #0
    mov     w3, #0
    bl      smith_chest
    tbnz    w0, #31, it_ret
    mov     w23, w0
    bl      ppl_chestptr
    mov     x24, x0
    mov     w9, #6                      // material: 6 minerio, 3 carvao, um
    str     w9, [x24, #(4 * IT_ORE)]    // machado de ferro
    mov     w9, #3
    str     w9, [x24, #(4 * IT_COAL)]
    mov     w9, #1
    str     w9, [x24, #(4 * IT_IAXE)]
    ldr     w9, [x24, #(4 * IT_WOOD)]
    add     w9, w9, #12
    str     w9, [x24, #(4 * IT_WOOD)]
    str     wzr, [x24, #(4 * IT_IRON)]
    LA      x9, objs                    // fornalha 3 celulas ao lado do bau
    add     x9, x9, x23, lsl #3
    ldrh    w0, [x9]
    ldrh    w1, [x9, #2]
    lsr     w25, w0, #6
    lsr     w26, w1, #6
    mov     w22, #0
5:  LA      x9, itoff
    add     x9, x9, x22, lsl #1
    ldrsb   w10, [x9]
    ldrsb   w11, [x9, #1]
    add     w10, w25, w10
    add     w11, w26, w11
    add     w0, w10, w11, lsl #9
    stp     w10, w11, [sp, #-16]!
    bl      obj_in_cell
    ldp     w10, w11, [sp], #16
    tbz     w0, #31, 51f
    LA      x9, fencegrid
    add     w12, w10, w11, lsl #9
    ldrb    w13, [x9, w12, uxtw]
    cbnz    w13, 51f
    LA      x9, elev                    // em terra boa
    ldrsh   w13, [x9, w12, uxtw #1]
    ldr     w14, [x28, #G_FLOOD]
    cmp     w13, w14
    b.lt    51f
    cmp     w13, #(E_SAND + 20)
    b.ge    52f
51: add     w22, w22, #1
    cmp     w22, #8
    b.lt    5b
    b       it_ret
52: lsl     w0, w10, #6
    add     w0, w0, #32
    lsl     w1, w11, #6
    add     w1, w1, #32
    stp     w0, w1, [sp, #-16]!
    scvtf   s0, w10
    scvtf   s1, w11
    bl      elev_at
    mov     w2, w0
    ldp     w0, w1, [sp], #16
    mov     w3, #O_FURNACE
    mov     w4, #0
    bl      add_obj
    // um veio de ferro numa celula livre da zona de pedra
    mov     w22, #0
6:  LA      x9, zonegrid
    ldrb    w9, [x9, x22]
    cmp     w9, #Z_STONE
    b.ne    61f
    mov     w0, w22
    bl      obj_in_cell
    tbz     w0, #31, 61f
    and     w9, w22, #511
    lsr     w10, w22, #9
    scvtf   s0, w9
    scvtf   s1, w10
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      elev_at
    mov     w2, w0
    and     w9, w22, #511
    lsl     w0, w9, #6
    add     w0, w0, #32
    lsr     w9, w22, #9
    lsl     w1, w9, #6
    add     w1, w1, #32
    mov     w3, #O_IRONV
    mov     w4, #3
    bl      add_obj
    b       62f
61: add     w22, w22, #1
    cmp     w22, #64, lsl #12
    b.lo    6b
62: mov     w9, #-1                     // ocupacao nova
    str     w9, [x28, #G_OCCFRAME]
    LA      x9, people                  // ferreiro: a mae da segunda familia
    mov     w10, #J_SMITH
    strb    w10, [x9, #(5 * PSIZE + P_JOB)]
    strb    wzr, [x9, #(5 * PSIZE + P_BFAM)]
    mov     w10, #ST_IDLE
    strb    w10, [x9, #(5 * PSIZE + P_STATE)]
    ldr     w26, [x24, #(4 * IT_ORE)]
    mov     w0, #3600                   // 2 horas de jogo
    bl      it_frames
    LA      x19, itres
    ldr     w9, [x24, #(4 * IT_IRON)]
    str     w9, [x19]
    ldr     w9, [x24, #(4 * IT_ORE)]
    str     w9, [x19, #4]
    ldr     w9, [x24, #(4 * IT_COAL)]
    str     w9, [x19, #8]
    LA      x9, pinv                // alguem pegou o machado de ferro?
    mov     w10, #0
    mov     w11, #0
63: ldr     w12, [x9, #(4 * IT_IAXE)]
    cmp     w12, #0
    cinc    w10, w10, ne
    add     x9, x9, #256
    add     w11, w11, #1
    cmp     w11, #MAXPEOPLE
    b.lt    63b
    str     w10, [x19, #12]

    mov     w0, #O_IRONV                // o veio da zona de pedra
    bl      ct_count
    str     w0, [x19, #16]
    LA      x0, txt
    LA      x1, it_u1
    ldr     w2, [x19]
    bl      it_num
    LA      x1, it_u2
    mov     w2, #6
    bl      it_num
    LA      x1, it_u3
    ldr     w2, [x19, #4]
    bl      it_num
    LA      x1, it_u4
    ldr     w2, [x19, #8]
    bl      it_num
    LA      x1, it_u5
    ldr     w2, [x19, #12]
    bl      it_num

    LA      x1, it_nl
    bl      strcat_cur
    bl      sk_write
it_ret:
    ldp     d8, d9, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// ---------------------------------------------------------------------
    .data
    .p2align 2
fconst:
    .float 0.99862953                   //  0 cos 3 graus
    .float 0.05233596                   //  4 sin 3 graus
    .float 6.0                          //  8 visao do lampiao
    .float 0.015625                     // 12 4 / 256
    .float 7.0                          // 16 visao do morador
    .float 1.0e9                        // 20 longe demais
    .float 0.015625                     // 24 1/64
// ferramenta de ferro de cada tarefa (nenhuma, floresta, pedra, plantar,
// obras, ferreiro)
    .globl jobtool
jobtool:
    .byte 0, IT_IAXE, IT_IPICK, IT_IHOE, 0, 0, IT_ROD
    .p2align 2

itf:
    .float 100.0
itwolf:
    .float 1.5, 0.0,  0.0, 1.5,  -1.5, 0.0,  0.0, -1.5
itoff:
    .byte 3, 0,  0, 3,  -3, 0,  0, -3,  3, 3,  -3, 3,  3, -3,  -3, -3
    .p2align 2
itres:
    .space 64
it_t1:  .asciz "ferro: veio sem picareta="
it_t2:  .asciz " com picareta: minerio="
it_t3:  .asciz " carvao="
it_t4:  .asciz " | fornalha="
it_t5:  .asciz " perto="
it_t6:  .asciz " barras="
it_t7:  .asciz " carvao de madeira="
it_t8:  .asciz " | ferramentas/espada/armadura="
it_t9:  .asciz " lampioes="
it_t10: .asciz " | quadros por madeira: machado de pedra="
it_t11: .asciz " de ferro="
it_t12: .asciz " | lobo com armadura: vida -"
it_u1:  .asciz "ferro na vila: ferreiro fez barras="
it_u2:  .asciz " (de "
it_u3:  .asciz " minerio; sobrou "
it_u4:  .asciz ") carvao no bau="
it_u5:  .asciz " | machado de ferro com um lenhador="

it_nl:  .asciz "\n"
    .p2align 2

GBSS lamps, (MAXLAMP * 4)
