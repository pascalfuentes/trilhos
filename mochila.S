// =====================================================================
//  mochila.S - a mochila de cada morador e o pescador da vila
//
//  - Cada pessoa tem a sua mochila (os mesmos 48 itens do bau): o que
//    junta no trabalho (madeira, pedra, minerio, trigo, peixe...), o
//    lanche (ate 2 comidas prontas: pao, frutas, assados) e a ferramenta
//    da tarefa (machado/picareta/enxada de ferro, vara de pesca).
//  - Quando a carga enche (ou nao tem mais o que fazer) leva tudo ao bau
//    mais perto, menos o lanche, a ferramenta e as sementes de quem
//    planta. Com fome, come primeiro da mochila; no bau, repoe o lanche.
//  - Botao direito numa pessoa (ou clique na coluna Agora do painel P):
//    abre a mochila dela no lugar do bau. Clique num item dela: voce pega;
//    na sua mochila: voce da.
//  - Pescador: pinte uma zona de Pesca (Z, 5) na agua. Ele pega uma vara
//    de pesca no bau, vai ate a margem e pesca; o peixe depende da agua
//    (lago 1, mar 1-2, mar fundo 3). Com 4 peixes, leva ao bau.
// =====================================================================

#include "comum.h"
#include "pessoas.h"

    .text
    .p2align 2

// ---------------------------------------------------------------------
//  Mochila (x19 = pessoa, w20 = numero)
// ---------------------------------------------------------------------

// pinv_clear(w0 = pessoa)   folha
    .globl pinv_clear
pinv_clear:
    LA      x9, pinv
    add     x9, x9, x0, lsl #8
    mov     w10, #16
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    ret

// pinv_add(w0 item, w1 quantos; pode ser negativo)   folha
    .globl pinv_add
pinv_add:
    LA      x9, pinv
    add     x9, x9, x20, lsl #8
    ldr     w10, [x9, x0, lsl #2]
    adds    w10, w10, w1
    csel    w10, wzr, w10, mi
    str     w10, [x9, x0, lsl #2]
    ret

// pinv_get(w0 item) -> w0 = quantos   folha
    .globl pinv_get
pinv_get:
    LA      x9, pinv
    add     x9, x9, x20, lsl #8
    ldr     w0, [x9, x0, lsl #2]
    ret

// pinv_cargo -> w0 = carga (o que junta no trabalho)   folha
    .globl pinv_cargo
pinv_cargo:
    LA      x9, pinv
    add     x9, x9, x20, lsl #8
    LA      x10, cargolist
    mov     w0, #0
1:  ldrb    w11, [x10], #1
    cmp     w11, #255
    b.eq    9f
    ldr     w12, [x9, x11, lsl #2]
    add     w0, w0, w12
    b       1b
9:  ret

// pinv_deposit(x0 = bau): guarda tudo, menos a ferramenta da tarefa, o
// lanche e as sementes (quem planta fica com 10)   folha
    .globl pinv_deposit
pinv_deposit:
    LA      x9, pinv
    add     x9, x9, x20, lsl #8
    ldrb    w13, [x19, #P_JOB]
    LA      x10, jobtool
    ldrb    w14, [x10, x13]             // ferramenta da tarefa
    mov     w11, #0
1:  cmp     w11, #NITEMS
    b.ge    9f
    ldr     w12, [x9, x11, lsl #2]
    cbz     w12, 8f
    mov     w15, #0                     // quanto fica
    cmp     w11, w14
    b.ne    2f
    cbz     w14, 2f
    mov     w15, #1
2:  cmp     w11, #IT_SEED
    b.ne    3f
    cmp     w13, #J_FARM
    b.ne    3f
    mov     w15, #10
3:  LA      x10, lunchok                // lanche: ate 2
    ldrb    w10, [x10, x11]
    cbz     w10, 4f
    mov     w15, #2
4:  cmp     w12, w15
    b.ls    8f
    sub     w16, w12, w15
    str     w15, [x9, x11, lsl #2]
    ldr     w17, [x0, x11, lsl #2]
    add     w17, w17, w16
    str     w17, [x0, x11, lsl #2]
8:  add     w11, w11, #1
    b       1b
9:  ret

// pinv_takefood(x0 = bau): repoe o lanche (2 comidas prontas)   folha
    .globl pinv_takefood
pinv_takefood:
    LA      x9, pinv
    add     x9, x9, x20, lsl #8
    LA      x10, lunchlist
    mov     w13, #0                     // quanto ja tem
1:  ldrb    w11, [x10], #1
    cmp     w11, #255
    b.eq    2f
    ldr     w12, [x9, x11, lsl #2]
    add     w13, w13, w12
    b       1b
2:  LA      x10, lunchlist
3:  cmp     w13, #2
    b.hs    9f
    ldrb    w11, [x10], #1
    cmp     w11, #255
    b.eq    9f
4:  cmp     w13, #2
    b.hs    9f
    ldr     w12, [x0, x11, lsl #2]
    cbz     w12, 3b
    sub     w12, w12, #1
    str     w12, [x0, x11, lsl #2]
    ldr     w12, [x9, x11, lsl #2]
    add     w12, w12, #1
    str     w12, [x9, x11, lsl #2]
    add     w13, w13, #1
    b       4b
9:  ret

// pinv_eat -> w0 = 1 se comeu da propria mochila (ate ficar bem)  folha
    .globl pinv_eat
pinv_eat:
    LA      x9, pinv
    add     x9, x9, x20, lsl #8
    mov     w0, #0
1:  ldr     s0, [x19, #P_FOOD]
    LA      x16, pconst
    ldr     s1, [x16, #124]             // come ate 80
    fcmp    s0, s1
    b.ge    9f
    LA      x10, eatorder
    mov     w12, #0
2:  ldrb    w11, [x10, x12]
    ldr     w13, [x9, x11, lsl #2]
    cbnz    w13, 3f
    add     w12, w12, #1
    cmp     w12, #7
    b.lo    2b
    b       9f
3:  sub     w13, w13, #1
    str     w13, [x9, x11, lsl #2]
    LA      x14, eatvalue
    ldr     s1, [x14, x11, lsl #2]
    fadd    s0, s0, s1
    ldr     s1, [x16, #44]              // 100
    fmin    s0, s0, s1
    str     s0, [x19, #P_FOOD]
    mov     w0, #1
    b       1b
9:  ret

// ---------------------------------------------------------------------
//  Abrir a mochila de alguem (no lugar do bau)
// ---------------------------------------------------------------------

// open_ptr -> x0 = contadores do que esta aberto: bau (1..64) ou a
// mochila de uma pessoa (129..)   folha
    .globl open_ptr
open_ptr:
    ldr     w9, [x28, #G_CHESTOPEN]
    sub     w9, w9, #1
    cmp     w9, #128
    b.hs    1f
    LA      x0, chests
    add     x0, x0, x9, lsl #CHESTSHIFT
    ret
1:  sub     w9, w9, #128
    LA      x0, pinv
    add     x0, x0, x9, lsl #8
    ret

// open_title -> x0 = titulo da janela: "Bau" ou "Mochila de Ana Silva"
    .globl open_title
open_title:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #G_CHESTOPEN]
    cmp     w9, #128
    b.hi    1f
    LA      x0, s_chesttitle
    b       9f
1:  sub     w9, w9, #129
    str     w9, [sp, #-16]!
    LA      x0, otitle
    LA      x1, s_bagof
    bl      strcat_cur
    ldr     w1, [sp], #16
    bl      ppl_namecat
    LA      x0, otitle
9:  ldp     x29, x30, [sp], #16
    ret

// open_person(w0 = pessoa): abre a mochila dela e a sua
    .globl open_person
open_person:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w0
    add     w9, w19, #129
    str     w9, [x28, #G_CHESTOPEN]
    mov     w9, #-1
    str     w9, [x28, #G_CHESTOBJ]
    mov     w9, #1
    str     w9, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CRAFTOPEN]
    str     wzr, [x28, #G_PEOPLEOPEN]
    LA      x0, pmsgbuf
    LA      x1, s_bagof
    bl      strcat_cur
    mov     w1, w19
    bl      ppl_namecat
    LA      x1, s_baghint
    bl      strcat_cur
    LA      x0, pmsgbuf
    bl      set_msg
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// open_check: a pessoa da mochila aberta morreu (ou foi embora): fecha
    .globl open_check
open_check:
    ldr     w9, [x28, #G_CHESTOPEN]
    cmp     w9, #128
    b.ls    9f
    sub     w9, w9, #129
    LA      x10, people
    add     x10, x10, x9, lsl #6
    ldrb    w10, [x10, #P_ALIVE]
    cbnz    w10, 9f
    str     wzr, [x28, #G_CHESTOPEN]
9:  ret

// ---------------------------------------------------------------------
//  Pescador
// ---------------------------------------------------------------------

// fish_spot -> w0 = celula de agua da zona de Pesca (com margem) mais
// perto da pessoa, w1 = a celula da margem (-1)
fish_spot:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     x23, x24, [sp, #32]
    stp     x25, x26, [sp, #48]
    stp     x27, x28, [sp, #64]
    ldr     s0, [x19, #P_U]
    fcvtzs  w21, s0
    ldr     s0, [x19, #P_V]
    fcvtzs  w22, s0
    mov     w23, #-1                    // melhor agua
    mov     w27, #-1                    // e a margem
    mov     w24, #0x7FFFFFFF
    mov     w25, #-40                   // dv
1:  mov     w26, #-40                   // du
2:  mul     w9, w25, w25
    madd    w9, w26, w26, w9
    cmp     w9, w24
    b.ge    6f
    add     w10, w21, w26
    add     w11, w22, w25
    cmp     w10, #2
    b.lt    6f
    cmp     w11, #2
    b.lt    6f
    cmp     w10, #509
    b.gt    6f
    cmp     w11, #509
    b.gt    6f
    add     w12, w10, w11, lsl #9       // celula
    LA      x13, zonegrid
    ldrb    w13, [x13, w12, uxtw]
    cmp     w13, #Z_FISH
    b.ne    6f
    LA      x13, elev                   // agua?
    ldrsh   w14, [x13, w12, uxtw #1]
    ldr     w15, [x28, #G_FLOOD]
    cmp     w14, w15
    b.ge    6f
    mov     w16, #0                     // uma margem do lado
3:  LA      x17, nb4
    ldrsh   w17, [x17, x16, lsl #1]
    add     w17, w12, w17
    ldrsh   w14, [x13, w17, uxtw #1]
    cmp     w14, w15
    b.ge    4f
    add     w16, w16, #1
    cmp     w16, #4
    b.lt    3b
    b       6f
4:  str     w9, [sp, #80]
    str     w12, [sp, #84]
    str     w17, [sp, #88]
    mov     w0, w12
    mov     w1, #WK_FISH
    bl      ppl_reserved
    ldr     w9, [sp, #80]
    ldr     w12, [sp, #84]
    ldr     w17, [sp, #88]
    cbnz    w0, 6f
    mov     w24, w9
    mov     w23, w12
    mov     w27, w17
6:  add     w26, w26, #1
    cmp     w26, #40
    b.le    2b
    add     w25, w25, #1
    cmp     w25, #40
    b.le    1b
    mov     w0, w23
    mov     w1, w27
    ldp     x27, x28, [sp, #64]
    ldp     x25, x26, [sp, #48]
    ldp     x23, x24, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// fish_work -> w0 = 1 se o pescador achou onde pescar (ja indo)
    .globl fish_work
fish_work:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    mov     w0, #IT_ROD                 // sem vara nao pesca
    bl      pinv_get
    cbz     w0, 7f
    bl      fish_spot
    tbnz    w0, #31, 8f
    str     w0, [x19, #P_TARGET]
    mov     w9, #WK_FISH
    strb    w9, [x19, #P_WKIND]
    mov     w9, #NX_WORK
    strb    w9, [x19, #P_NEXT]
    and     w9, w1, #511                // vai ate o meio da margem
    lsr     w10, w1, #9
    scvtf   s0, w9
    scvtf   s1, w10
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    bl      ppl_gopoint
    mov     w0, #1
    b       9f
7:  ldr     w9, [x28, #G_PPLFRAME]      // avisa (de vez em quando)
    ldr     w10, [x28, #G_NOFISHT]
    sub     w11, w9, w10
    cmp     w11, #3600
    b.lo    8f
    str     w9, [x28, #G_NOFISHT]
    LA      x0, m_norod
    bl      set_msg
8:  mov     w0, #0
9:  ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// fish_valid(w0 = celula) -> w0 = 1 se ainda e agua da zona de Pesca  folha
    .globl fish_valid
fish_valid:
    tbnz    w0, #31, 8f
    LA      x9, zonegrid
    ldrb    w9, [x9, w0, uxtw]
    cmp     w9, #Z_FISH
    b.ne    8f
    LA      x9, elev
    ldrsh   w9, [x9, w0, uxtw #1]
    ldr     w10, [x28, #G_FLOOD]
    cmp     w9, w10
    cset    w0, lt
    ret
8:  mov     w0, #0
    ret

// fish_done: pegou peixe (lago 1, mar 1-2, mar fundo 3)
    .globl fish_done
fish_done:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    ldr     w9, [x19, #P_TARGET]
    and     w10, w9, #511               // distancia ate a borda do mapa
    lsr     w11, w9, #9
    mov     w12, #511
    sub     w13, w12, w10
    sub     w14, w12, w11
    cmp     w10, w11
    csel    w10, w10, w11, lt
    cmp     w10, w13
    csel    w10, w10, w13, lt
    cmp     w10, w14
    csel    w10, w10, w14, lt
    LA      x12, elev
    ldrsh   w12, [x12, w9, uxtw #1]
    ldr     w13, [x28, #G_FLOOD]
    sub     w12, w12, w13               // profundidade
    mov     w21, #1                     // lago: 1
    cmp     w10, #W_BORDER
    b.ge    1f
    mov     w21, #3                     // mar fundo: 3
    cmn     w12, #400
    b.le    1f
    bl      rng                         // mar: 1 ou 2
    and     w0, w0, #1
    add     w21, w0, #1
1:  mov     w0, #IT_FISH
    mov     w1, w21
    bl      pinv_add
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
//  Pincel de zonas
// ---------------------------------------------------------------------

// zone_paint(w0 u, w1 v, w2 raio, w3 tipo (0 = apaga)): circulo  folha
    .globl zone_paint
zone_paint:
    LA      x9, zonegrid
    mul     w15, w2, w2
    add     w15, w15, w2                // r^2 + r: circulo mais cheio
    neg     w10, w2                     // dv
1:  neg     w11, w2                     // du
2:  mul     w12, w10, w10
    madd    w12, w11, w11, w12
    cmp     w12, w15
    b.gt    3f
    add     w12, w0, w11
    add     w13, w1, w10
    cmp     w12, #1
    b.lt    3f
    cmp     w13, #1
    b.lt    3f
    cmp     w12, #510
    b.gt    3f
    cmp     w13, #510
    b.gt    3f
    add     w12, w12, w13, lsl #9
    ldrb    w13, [x9, w12, uxtw]
    cmp     w13, #Z_LOT                 // terreno de casa nao muda
    b.eq    3f
    strb    w3, [x9, w12, uxtw]
3:  add     w11, w11, #1
    cmp     w11, w2
    b.le    2b
    add     w10, w10, #1
    cmp     w10, w2
    b.le    1b
    ret

// zone_wheel(w0 = +1 / -1): tamanho do pincel (1 a 12)
    .globl zone_wheel
zone_wheel:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #G_ZBRUSH]
    add     w9, w9, w0
    cmp     w9, #1
    mov     w10, #1
    csel    w9, w10, w9, lt
    cmp     w9, #12
    mov     w10, #12
    csel    w9, w10, w9, gt
    str     w9, [x28, #G_ZBRUSH]
    LA      x0, pmsgbuf
    LA      x1, s_brush
    bl      strcat_cur
    ldr     w1, [x28, #G_ZBRUSH]
    bl      numcat
    LA      x0, pmsgbuf
    bl      set_msg
    ldp     x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
//  Teste automatico (--shot): o pincel, o pescador e as mochilas
// ---------------------------------------------------------------------

// mt_count(w0 = tipo de zona) -> w0 = celulas   folha
mt_count:
    LA      x9, zonegrid
    mov     w10, #0
    mov     w11, w0
    mov     w0, #0
1:  ldrb    w12, [x9, x10]
    cmp     w12, w11
    cinc    w0, w0, eq
    add     w10, w10, #1
    cmp     w10, #64, lsl #12
    b.lo    1b
    ret

// mt_num(x0 cursor, x1 rotulo, w2 numero) -> x0
mt_num:
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

// mt_frames(w0 = quadros)
mt_frames:
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

//   0: pincel (pinta e apaga), pescador com vara numa zona de Pesca,
//      mochilas (lanche, dar e pegar); foto: o pincel de Pesca na agua
//   1: foto: a mochila da pescadora aberta
    .globl mochila_selftest
mochila_selftest:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     d8, d9, [sp, #80]
    ldr     w9, [x28, #G_NOPEOPLE]
    cbnz    w9, mt_ret
    cbnz    w0, mt_stage1
    str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_CHESTOPEN]
    str     wzr, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_PEOPLEOPEN]
    mov     w9, #3000                   // de manha
    str     w9, [x28, #G_TIME]
    LA      x24, mtres
    // ---- pincel: tamanho 3 pinta um circulo; o direito apaga ----
    ldr     s0, [x28, #G_PU]
    fcvtzs  w21, s0
    ldr     s0, [x28, #G_PV]
    fcvtzs  w22, s0
    add     w21, w21, #30               // longe da vila
    mov     w0, #Z_FARM
    bl      mt_count
    mov     w23, w0
    mov     w9, #Z_FARM
    str     w9, [x28, #G_ZONEMODE]
    mov     w9, #3
    str     w9, [x28, #G_ZBRUSH]
    mov     w9, #1
    str     w9, [x28, #G_HOVOK]
    lsl     w9, w21, #6
    add     w9, w9, #32
    str     w9, [x28, #G_HOVU]
    lsl     w9, w22, #6
    add     w9, w9, #32
    str     w9, [x28, #G_HOVV]
    mov     w9, #1                      // segura o esquerdo
    str     w9, [x28, #G_ZDRAG]
    bl      people_update
    mov     w0, #Z_FARM
    bl      mt_count
    sub     w9, w0, w23
    str     w9, [x24]
    mov     w23, w0
    mov     w9, #2                      // segura o direito: apaga
    str     w9, [x28, #G_ZDRAG]
    bl      people_update
    str     wzr, [x28, #G_ZDRAG]
    mov     w0, #Z_FARM
    bl      mt_count
    sub     w9, w23, w0
    str     w9, [x24, #4]
    str     wzr, [x28, #G_ZONEMODE]
    str     wzr, [x28, #G_HOVOK]
    // ---- pescador: zona de Pesca na agua perto do bau, vara no bau ----
    LA      x19, people
    mov     w20, #0
    mov     w0, #IT_WOOD                // bau mais perto da primeira pessoa
    mov     w1, #0
    mov     w2, #0
    mov     w3, #0
    bl      mt_chest
    tbnz    w0, #31, mt_print
    mov     w25, w0
    bl      ppl_chestptr
    mov     x26, x0
    LA      x9, objs
    add     x9, x9, x25, lsl #3
    ldrh    w21, [x9]
    lsr     w21, w21, #6
    ldrh    w22, [x9, #2]
    lsr     w22, w22, #6
    mov     w23, #-1                    // agua com margem mais perto do bau
    mov     w9, #0x7FFFFFFF
    str     w9, [x24, #40]
    mov     w12, #-30
1:  mov     w13, #-30
2:  add     w10, w21, w13
    add     w11, w22, w12
    cmp     w10, #4
    b.lt    3f
    cmp     w11, #4
    b.lt    3f
    cmp     w10, #507
    b.gt    3f
    cmp     w11, #507
    b.gt    3f
    add     w14, w10, w11, lsl #9
    LA      x15, elev
    ldrsh   w16, [x15, w14, uxtw #1]
    ldr     w17, [x28, #G_FLOOD]
    cmp     w16, w17
    b.ge    3f
    add     w16, w14, #1                // margem em +u
    ldrsh   w16, [x15, w16, uxtw #1]
    cmp     w16, w17
    b.lt    3f
    mul     w16, w12, w12
    madd    w16, w13, w13, w16
    ldr     w17, [x24, #40]
    cmp     w16, w17
    b.ge    3f
    str     w16, [x24, #40]
    mov     w23, w14
3:  add     w13, w13, #1
    cmp     w13, #30
    b.le    2b
    add     w12, w12, #1
    cmp     w12, #30
    b.le    1b
    str     w23, [x24, #44]
    str     wzr, [x24, #8]
    tbnz    w23, #31, 5f
    and     w0, w23, #511               // zona de Pesca: circulo de raio 2
    lsr     w1, w23, #9
    mov     w2, #2
    mov     w3, #Z_FISH
    bl      zone_paint
    mov     w0, #Z_FISH
    bl      mt_count
    str     w0, [x24, #8]
5:  mov     w9, #1                      // vara de pesca no bau
    str     w9, [x26, #(4 * IT_ROD)]
    str     wzr, [x26, #(4 * IT_FISH)]
    LA      x9, people                  // pescadora: a mae da terceira familia
    add     x9, x9, #(9 * PSIZE)
    mov     w10, #J_FISH
    strb    w10, [x9, #P_JOB]
    mov     w10, #ST_IDLE
    strb    w10, [x9, #P_STATE]
    mov     w0, #3600                   // 2 horas de jogo
    bl      mt_frames
    ldr     w23, [x26, #(4 * IT_FISH)]  // peixe no bau + na mochila dela
    mov     w20, #9
    mov     w0, #IT_FISH
    bl      pinv_get
    add     w9, w23, w0
    str     w9, [x24, #12]
    mov     w0, #IT_ROD
    bl      pinv_get
    str     w0, [x24, #16]
    // ---- mochilas: quem tem lanche; dar e pegar ----
    mov     w21, #0
    mov     w20, #0
6:  LA      x9, people
    add     x19, x9, x20, lsl #6
    ldrb    w9, [x19, #P_ALIVE]
    cbz     w9, 61f
    LA      x10, lunchlist
    mov     w11, #0
62: ldrb    w12, [x10], #1
    cmp     w12, #255
    b.eq    63f
    LA      x13, pinv
    add     x13, x13, x20, lsl #8
    ldr     w13, [x13, x12, lsl #2]
    add     w11, w11, w13
    b       62b
63: cmp     w11, #0
    cinc    w21, w21, ne
61: add     w20, w20, #1
    cmp     w20, #MAXPEOPLE
    b.lt    6b
    str     w21, [x24, #20]
    mov     w0, #0                      // abre a mochila da primeira pessoa
    bl      open_person
    mov     w9, #3                      // da 3 paes
    str     w9, [x28, #(G_INV + 4 * IT_BREAD)]
    mov     w0, #IT_BREAD
    mov     w1, #0
    bl      chest_move
    mov     w20, #0
    mov     w0, #IT_BREAD
    bl      pinv_get
    str     w0, [x24, #24]
    mov     w0, #IT_BREAD               // e pega de volta
    mov     w1, #1
    bl      chest_move
    ldr     w9, [x28, #(G_INV + 4 * IT_BREAD)]
    str     w9, [x24, #28]
    // foto: voce na margem, o pincel de Pesca (3) sobre a agua
    str     wzr, [x28, #G_CHESTOPEN]
    str     wzr, [x28, #G_INVOPEN]
    ldr     w9, [x24, #44]
    tbnz    w9, #31, 7f
    and     w10, w9, #511
    lsr     w11, w9, #9
    add     w12, w10, #1
    scvtf   s0, w12
    scvtf   s1, w11
    fmov    s2, #0.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    str     s0, [x28, #G_PU]
    str     s1, [x28, #G_PV]
    bl      surv_update                 // a camera e a visao chegam la
    ldr     w9, [x24, #44]
    and     w10, w9, #511
    lsr     w11, w9, #9
    sub     w10, w10, #1
    str     w10, [x28, #G_ZBU]
    str     w11, [x28, #G_ZBV]
    mov     w9, #1
    str     w9, [x28, #G_HOVOK]
7:  mov     w9, #Z_FISH
    str     w9, [x28, #G_ZONEMODE]
    mov     w9, #3
    str     w9, [x28, #G_ZBRUSH]
    str     wzr, [x28, #G_MSGT]
    str     wzr, [x28, #G_POPT]
mt_print:
    LA      x0, txt
    LA      x1, mt_t1
    ldr     w2, [x24]
    bl      mt_num
    LA      x1, mt_t2
    ldr     w2, [x24, #4]
    bl      mt_num
    LA      x1, mt_t3
    ldr     w2, [x24, #8]
    bl      mt_num
    LA      x1, mt_t4
    ldr     w2, [x24, #12]
    bl      mt_num
    LA      x1, mt_t5
    ldr     w2, [x24, #16]
    bl      mt_num
    LA      x1, mt_t6
    ldr     w2, [x24, #20]
    bl      mt_num
    LA      x1, mt_t7
    ldr     w2, [x24, #24]
    bl      mt_num
    LA      x1, mt_t8
    ldr     w2, [x24, #28]
    bl      mt_num
    LA      x1, mt_nl
    bl      strcat_cur
    bl      sk_write
    b       mt_ret
mt_stage1:
    str     wzr, [x28, #G_ZONEMODE]
    mov     w0, #9                      // a pescadora
    bl      open_person
    str     wzr, [x28, #G_MSGT]
    str     wzr, [x28, #G_POPT]
mt_ret:
    ldp     d8, d9, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// mt_chest(w0 item, w1 quantos, w2, w3) -> bau mais perto da pessoa x19
mt_chest:
    b       smith_chest

// ---------------------------------------------------------------------
    .data
    .p2align 2
// o que conta como carga (leva ao bau quando enche)
cargolist:
    .byte IT_WOOD, IT_STONE, IT_ORE, IT_COAL, IT_IRON, IT_WHEAT, IT_FISH
    .byte IT_MEAT, IT_HIDE, IT_BERRY, 255
// lanche: comidas prontas (fica com ate 2)
lunchlist:
    .byte IT_CMEAT, IT_BREAD, IT_COOKED, IT_CFISH, 255
lunchok:
    .byte 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0
    .byte 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
// vizinhos de uma celula: +u, -u, +v, -v
    .p2align 1
nb4:
    .hword 1, -1, 512, -512
s_bagof:    .asciz "Mochila de "
s_baghint:  .asciz ": clique num item dela pega; na sua, da"
s_brush:    .asciz "Pincel: "
m_norod:    .asciz "Pescador sem vara: faca uma vara de pesca e ponha no bau"
mt_t1:  .asciz "mochila: pincel 3 pintou="
mt_t2:  .asciz " apagou="
mt_t3:  .asciz " | zona de pesca="
mt_t4:  .asciz " pescador: peixes="
mt_t5:  .asciz " vara na mochila="
mt_t6:  .asciz " | com lanche="
mt_t7:  .asciz " | deu pao="
mt_t8:  .asciz " pegou de volta="
mt_nl:  .asciz "\n"
    .p2align 2
otitle:     .space 64
mtres:      .space 64

GBSS pinv, (MAXPEOPLE * 256)
