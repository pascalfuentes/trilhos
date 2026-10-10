// =====================================================================
//  desafio.S - um mundo mais dificil
//
//  - Pedreiras e minas: a pedra, o ferro e o carvao ficam juntos em
//    manchas de varias celulas (3 x 3 ate 5 x 5) com muitas pedras em
//    cada uma; a celula que esgota vira um buraco de cascalho (pedra) ou
//    de terra de mina (ferro e carvao).
//  - Comida estraga: carne e peixe crus, frutas e assados perdem um
//    quarto (pelo menos 1) a cada periodo; no bau, metade da velocidade.
//  - Cervos andam em manada (seguem o primeiro do grupo e fogem juntos).
//  - Noites perigosas: a partir do 2o dia, ao anoitecer, pode vir uma
//    alcateia atras da vila (mais provavel e maior a cada dia, e no
//    inverno). De manha os lobos que sobraram vao embora.
//  - Soldado: tarefa da vila. Pega uma espada no bau, patrulha em volta
//    do bau, nao dorme (fica de vigia) e corre atras de lobos e ursos que
//    chegam perto (16 celulas). Com espada: 6 de dano; sem: 2.
// =====================================================================

#include "comum.h"
#include "pessoas.h"

.equ AN_U,      0
.equ AN_V,      4
.equ AN_DU,     8
.equ AN_DV,     12
.equ AN_TYPE,   16
.equ AN_HP,     17
.equ AN_GRP,    18                      // 0 sozinho, 1 alcateia, 2.. manada
.equ AN_HURT,   19
.equ AT_WALK,   8
.equ SPOILSTEP, (DAYLEN / 32)

    .text
    .p2align 2

// ---------------------------------------------------------------------
//  Pedreiras e minas
// ---------------------------------------------------------------------

// quarry_cell(w0 = u, w1 = v) -> w0 = tipo (O_ROCK, O_IRONV, O_COALV) ou
// -1, w1 = quantidade. O mapa e dividido em blocos de 8 x 8; cada bloco
// sorteia (pela altura do seu centro) se tem uma mancha, onde e de que.
    .globl quarry_cell
quarry_cell:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     w19, w0
    mov     w20, w1
    lsr     w0, w19, #3
    lsr     w1, w20, #3
    ldr     w2, [x28, #G_SEED]
    add     w2, w2, #555
    bl      hash3
    mov     w21, w0                     // sorteio do bloco
    and     w9, w19, #~7
    ubfx    w10, w21, #8, #2
    add     w22, w9, w10
    add     w22, w22, #2                // centro u
    and     w9, w20, #~7
    ubfx    w10, w21, #10, #2
    add     w23, w9, w10
    add     w23, w23, #2                // centro v
    add     w9, w22, w23, lsl #9
    LA      x10, elev
    ldrsh   w24, [x10, w9, uxtw #1]
    mov     w9, #0                      // chance (em 256)
    cmp     w24, #(E_SAND + 60)
    b.lt    1f
    mov     w9, #5                      // campo: pequena e rara
    cmp     w24, #E_HILL
    b.lt    1f
    mov     w9, #40                     // colinas
    mov     w10, #E_ROCK
    cmp     w24, w10
    b.lt    1f
    mov     w9, #64                     // montanha
1:  and     w10, w21, #255
    cmp     w10, w9
    b.hs    8f
    mov     w11, #1                     // raio: 1 (3 x 3) ou 2 (5 x 5)
    cmp     w24, #E_HILL
    b.lt    2f
    ubfx    w10, w21, #12, #1
    add     w11, w11, w10
2:  sub     w12, w19, w22
    sub     w13, w20, w23
    mul     w12, w12, w12
    madd    w12, w13, w13, w12
    madd    w14, w11, w11, w11          // raio^2 + raio
    cmp     w12, w14
    b.gt    8f
    b.lt    3f
    mov     w0, w19                     // na borda: contorno irregular
    mov     w1, w20
    ldr     w2, [x28, #G_SEED]
    add     w2, w2, #556
    bl      hash3
    tbnz    w0, #0, 8f
3:  mov     w0, #O_ROCK
    ubfx    w1, w21, #20, #3
    add     w1, w1, #12                 // 12..19 pedras por celula
    cmp     w24, #E_HILL
    b.lt    9f
    ubfx    w9, w21, #16, #4
    cmp     w9, #4                      // 4 em 16: ferro
    b.hs    4f
    mov     w0, #O_IRONV
    mov     w1, #8
    b       9f
4:  cmp     w9, #6                      // 2 em 16: carvao
    b.hs    9f
    mov     w0, #O_COALV
    mov     w1, #10
    b       9f
8:  mov     w0, #-1
    mov     w1, #0
9:  ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// pits_clear: nenhum buraco (mundo novo)   folha
    .globl pits_clear
pits_clear:
    LA      x9, pitgrid
    mov     w10, #(MAPN * MAPN / 16)
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    ret

// quarry_ground(w0 = celula, w1 = tipo): o chao da pedreira (3) ou da
// mina (4), mais claro que o buraco   folha
    .globl quarry_ground
quarry_ground:
    mov     w10, #3
    cmp     w1, #O_ROCK
    b.eq    1f
    mov     w10, #4
1:  LA      x11, pitgrid
    strb    w10, [x11, w0, uxtw]
    ret

// quarry_done(x0 = objeto (ponteiro), w1 = tipo): a celula esgotou e
// vira buraco (1 cascalho, 2 terra de mina)   folha
    .globl quarry_done
quarry_done:
    ldrh    w9, [x0]
    lsr     w9, w9, #6
    ldrh    w10, [x0, #2]
    lsr     w10, w10, #6
    add     w9, w9, w10, lsl #9
    mov     w10, #1
    cmp     w1, #O_ROCK
    b.eq    1f
    mov     w10, #2
1:  LA      x11, pitgrid
    strb    w10, [x11, w9, uxtw]
    mov     w10, #-1
    str     w10, [x28, #G_OCCFRAME]
    ret

// ---------------------------------------------------------------------
//  Comida estraga
// ---------------------------------------------------------------------

// spoil_tick: a cada 1/32 de dia um passo (no teste --shot, so quando o
// teste pede)
    .globl spoil_tick
spoil_tick:
    ldr     w9, [x28, #G_SHOT]
    cbnz    w9, 9f
    ldr     w9, [x28, #G_SPOILT]
    add     w9, w9, #1
    cmp     w9, #SPOILSTEP
    b.hs    1f
    str     w9, [x28, #G_SPOILT]
9:  ret
1:  str     wzr, [x28, #G_SPOILT]
    b       spoil_step

// rot1(x0 = contador) -> w0 = quanto estragou (um quarto, pelo menos 1)
rot1:
    ldr     w1, [x0]
    cbz     w1, 8f
    lsr     w2, w1, #2
    cmp     w2, #1
    csinc   w2, w2, wzr, hs
    sub     w1, w1, w2
    str     w1, [x0]
    mov     w0, w2
    ret
8:  mov     w0, #0
    ret

// spoil_step: estraga o que esta no periodo (sua mochila, as mochilas da
// vila; os baus na metade da velocidade) e avisa o que estragou na sua
    .globl spoil_step
spoil_step:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    ldr     w19, [x28, #G_SPOILK]
    add     w19, w19, #1
    str     w19, [x28, #G_SPOILK]
    mov     w23, #-1                    // o que estragou na sua mochila
    mov     w24, #0
    LA      x20, spoiltab
1:  ldrb    w21, [x20], #1
    cmp     w21, #255
    b.eq    8f
    ldrb    w22, [x20], #1
    udiv    w9, w19, w22
    msub    w9, w9, w22, w19
    cbnz    w9, 1b
    add     x0, x28, #G_INV             // sua mochila
    add     x0, x0, x21, lsl #2
    bl      rot1
    cbz     w0, 2f
    mov     w23, w21
    mov     w24, w0
2:  LA      x9, pinv                    // as mochilas da vila
    add     x9, x9, x21, lsl #2
    mov     w10, #MAXPEOPLE
3:  mov     x0, x9
    bl      rot1
    add     x9, x9, #256
    subs    w10, w10, #1
    b.ne    3b
    lsl     w9, w22, #1                 // baus: a cada 2 periodos
    udiv    w10, w19, w9
    msub    w10, w10, w9, w19
    cbnz    w10, 1b
    LA      x9, chests
    add     x9, x9, x21, lsl #2
    mov     w10, #64
4:  mov     x0, x9
    bl      rot1
    add     x9, x9, #256
    subs    w10, w10, #1
    b.ne    4b
    b       1b
8:  tbnz    w23, #31, 9f
    bl      calc_stats
    LA      x0, dmsg                    // "Estragou: 2 Carne crua"
    LA      x1, s_rot
    bl      strcat_cur
    mov     w1, w24
    bl      numcat
    LA      x1, s_sp
    bl      strcat_cur
    LA      x1, itemnames
    add     x1, x1, x23, lsl #4
    bl      strcat_cur
    LA      x0, dmsg
    bl      set_msg
9:  ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
//  Manadas e alcateias
// ---------------------------------------------------------------------

// group_steer(x20 = animal, x22 = tipo, w19 = numero) -> w0 = 1 se
// mudou o rumo: a alcateia vai para a vila; na manada, cada um segue o
// primeiro do grupo   folha
    .globl group_steer
group_steer:
    ldrb    w9, [x20, #AN_GRP]
    cbz     w9, 8f
    ldr     s0, [x20, #AN_U]
    ldr     s1, [x20, #AN_V]
    cmp     w9, #1
    b.ne    2f
    ldr     s2, [x28, #G_PACKU]
    ldr     s3, [x28, #G_PACKV]
    LA      x10, dconst
    ldr     s6, [x10, #4]               // alcateia: 1,8x a velocidade de andar
    b       5f
2:  LA      x10, animals
    mov     w11, #0
3:  cmp     w11, w19
    b.ge    8f                          // e o primeiro: anda a toa
    ldrb    w12, [x10, #AN_TYPE]
    cmp     w12, #255
    b.eq    4f
    ldrb    w12, [x10, #AN_GRP]
    cmp     w12, w9
    b.ne    4f
    ldr     s2, [x10, #AN_U]
    ldr     s3, [x10, #AN_V]
    LA      x10, dconst
    ldr     s6, [x10, #8]               // manada: 1,3x
    b       5f
4:  add     x10, x10, #32
    add     w11, w11, #1
    b       3b
5:  fsub    s2, s2, s0
    fsub    s3, s3, s1
    fmul    s4, s2, s2
    fmadd   s4, s3, s3, s4
    LA      x11, dconst
    ldr     s5, [x11, #12]              // perto o bastante (2,5 celulas)^2
    fcmp    s4, s5
    b.le    8f
    fsqrt   s4, s4
    ldr     s5, [x22, #AT_WALK]
    fmul    s5, s5, s6
    fdiv    s5, s5, s4
    fmul    s2, s2, s5
    fmul    s3, s3, s5
    str     s2, [x20, #AN_DU]
    str     s3, [x20, #AN_DV]
    mov     w0, #1
    ret
8:  mov     w0, #0
    ret

// herd_alarm(x0 = animal): um da manada foi ferido: todos fogem   folha
    .globl herd_alarm
herd_alarm:
    ldrb    w9, [x0, #AN_GRP]
    cmp     w9, #2
    b.lo    9f
    LA      x10, animals
    mov     w11, #MAXANIM
    mov     w12, #40
1:  ldrb    w13, [x10, #AN_GRP]
    cmp     w13, w9
    b.ne    2f
    ldrb    w13, [x10, #AN_TYPE]
    cmp     w13, #255
    b.eq    2f
    strb    w12, [x10, #AN_HURT]
2:  add     x10, x10, #32
    subs    w11, w11, #1
    b.ne    1b
9:  ret

// herd_spawn(w0 = cervo): mais 2 ou 3 em volta, todos do mesmo grupo
    .globl herd_spawn
herd_spawn:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    LA      x9, animals
    add     x19, x9, x0, lsl #5
    ldr     w20, [x28, #G_HERDID]       // grupo novo (2..127)
    add     w20, w20, #1
    cmp     w20, #2
    mov     w9, #2
    csel    w20, w9, w20, lt
    cmp     w20, #127
    csel    w20, w9, w20, gt
    str     w20, [x28, #G_HERDID]
    strb    w20, [x19, #AN_GRP]
    ldr     s8, [x19, #AN_U]
    ldr     s9, [x19, #AN_V]
    bl      rng
    and     w21, w0, #1
    add     w21, w21, #2
    mov     w22, #0
1:  cmp     w22, w21
    b.ge    9f
    LA      x9, herdoff
    add     x9, x9, x22, lsl #3
    ldr     s0, [x9]
    ldr     s1, [x9, #4]
    fadd    s0, s0, s8
    fadd    s1, s1, s9
    bl      elev_at                     // na agua nao
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    b.lt    2f
    LA      x9, herdoff
    add     x9, x9, x22, lsl #3
    ldr     s0, [x9]
    ldr     s1, [x9, #4]
    fadd    s0, s0, s8
    fadd    s1, s1, s9
    mov     w0, #A_DEER
    bl      animal_spawn
    tbnz    w0, #31, 2f
    LA      x9, animals
    add     x9, x9, x0, lsl #5
    strb    w20, [x9, #AN_GRP]
2:  add     w22, w22, #1
    b       1b
9:  ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// night_tick: ao anoitecer pode vir uma alcateia; as 06:00 a que sobrou
// vai embora (vira lobos comuns)
    .globl night_tick
night_tick:
    ldr     w9, [x28, #G_TIME]
    cbnz    w9, 2f
    LA      x10, animals
    mov     w11, #MAXANIM
1:  ldrb    w12, [x10, #AN_GRP]
    cmp     w12, #1
    b.ne    11f
    strb    wzr, [x10, #AN_GRP]
11: add     x10, x10, #32
    subs    w11, w11, #1
    b.ne    1b
    ret
2:  mov     w10, #T_NIGHT
    cmp     w9, w10
    b.ne    9f
    ldr     w10, [x28, #G_SHOT]
    cbnz    w10, 9f
    ldr     w10, [x28, #G_DAY]
    cmp     w10, #2
    b.lt    9f
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    ldr     w19, [x28, #G_DAY]
    mov     w9, #10                     // chance: 25% + 10% por dia
    mov     w20, #25
    madd    w20, w19, w9, w20
    ldr     w9, [x28, #G_SEASON]        // inverno: +30%
    cmp     w9, #3
    b.ne    3f
    add     w20, w20, #30
3:  mov     w0, #100
    bl      rng_mod
    cmp     w0, w20
    b.hs    8f
    mov     w9, #3                      // tamanho: 2 + dias / 3 (ate 6)
    udiv    w0, w19, w9
    add     w0, w0, #2
    ldr     w9, [x28, #G_SEASON]
    cmp     w9, #3
    cinc    w0, w0, eq
    cmp     w0, #6
    mov     w9, #6
    csel    w0, w9, w0, gt
    bl      pack_spawn
8:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
9:  ret

// pack_spawn(w0 = lobos) -> w0 = quantos apareceram: a 22 celulas da vila
// (o bau mais perto de voce, se estiver a ate 45 celulas; senao, voce)
    .globl pack_spawn
pack_spawn:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     d8, d9, [sp, #64]
    stp     d10, d11, [sp, #80]
    stp     d12, d13, [sp, #96]
    mov     w19, w0
    ldr     s8, [x28, #G_PU]
    ldr     s9, [x28, #G_PV]
    mov     w0, #O_CHEST
    mov     w1, #O_CHEST
    bl      nearest_obj
    tbnz    w0, #31, 1f
    mov     w20, w0
    bl      obj_dist2
    LA      x9, dconst
    ldr     s1, [x9, #16]               // 45^2
    fcmp    s0, s1
    b.gt    1f
    LA      x9, objs
    add     x9, x9, x20, lsl #3
    ldrh    w10, [x9]
    ucvtf   s8, w10
    ldrh    w10, [x9, #2]
    ucvtf   s9, w10
    LA      x9, dconst
    ldr     s2, [x9]                    // 1/64
    fmul    s8, s8, s2
    fmul    s9, s9, s2
1:  str     s8, [x28, #G_PACKU]
    str     s9, [x28, #G_PACKV]
    bl      rng                         // de onde vem: uma das 16 direcoes
    and     w21, w0, #15
    mov     w22, #16
2:  LA      x9, dir16
    add     x9, x9, x21, lsl #3
    ldr     s0, [x9]
    ldr     s1, [x9, #4]
    LA      x9, dconst
    ldr     s2, [x9, #20]               // 22 celulas
    fmadd   s10, s0, s2, s8
    fmadd   s11, s1, s2, s9
    ldr     s2, [x9, #24]               // dentro do mapa (6..505)
    ldr     s3, [x9, #28]
    fcmp    s10, s2
    b.lt    3f
    fcmp    s11, s2
    b.lt    3f
    fcmp    s10, s3
    b.gt    3f
    fcmp    s11, s3
    b.gt    3f
    fmov    s0, s10
    fmov    s1, s11
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    b.lt    3f
    mov     w23, #21                    // e terra no caminho ate a vila
    LA      x9, dir16
    add     x9, x9, x21, lsl #3
    ldr     s12, [x9]
    ldr     s13, [x9, #4]
31: scvtf   s2, w23
    fmadd   s0, s12, s2, s8
    fmadd   s1, s13, s2, s9
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    b.lt    3f
    subs    w23, w23, #1
    b.ne    31b
    b       4f
3:  add     w21, w21, #1
    and     w21, w21, #15
    subs    w22, w22, #1
    b.ne    2b
    mov     w23, #0
    b       9f
4:  mov     w23, #0                     // apareceram
    mov     w24, #0
5:  cmp     w24, w19
    b.ge    6f
    LA      x9, ring6
    and     w10, w24, #7
    add     x9, x9, x10, lsl #3
    ldr     s0, [x9]
    ldr     s1, [x9, #4]
    fadd    s0, s0, s10
    fadd    s1, s1, s11
    mov     w0, #A_WOLF
    bl      animal_spawn
    tbnz    w0, #31, 51f
    LA      x9, animals
    add     x9, x9, x0, lsl #5
    mov     w10, #1
    strb    w10, [x9, #AN_GRP]
    add     w23, w23, #1
51: add     w24, w24, #1
    b       5b
6:  cbz     w23, 9f
    LA      x0, dmsg                    // "Uivos! Uma alcateia de 4 lobos..."
    LA      x1, s_pack1
    bl      strcat_cur
    mov     w1, w23
    bl      numcat
    LA      x1, s_pack2
    bl      strcat_cur
    LA      x0, dmsg
    bl      set_msg
9:  mov     w0, w23
    ldp     d12, d13, [sp, #96]
    ldp     d10, d11, [sp, #80]
    ldp     d8, d9, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #112
    ret

// ---------------------------------------------------------------------
//  Soldado (x19 = pessoa, w20 = numero)
// ---------------------------------------------------------------------

// hostile_near(s0 = u, s1 = v, s2 = distancia^2 maxima) -> w0 = lobo ou
// urso mais perto (-1)   folha
hostile_near:
    mov     w0, #-1
    LA      x9, animals
    mov     w10, #0
1:  ldrb    w12, [x9, #AN_TYPE]
    cmp     w12, #A_WOLF
    b.eq    2f
    cmp     w12, #A_BEAR
    b.ne    3f
2:  ldr     s3, [x9, #AN_U]
    fsub    s3, s3, s0
    ldr     s4, [x9, #AN_V]
    fsub    s4, s4, s1
    fmul    s3, s3, s3
    fmadd   s3, s4, s4, s3
    fcmp    s3, s2
    b.ge    3f
    fmov    s2, s3
    mov     w0, w10
3:  add     x9, x9, #32
    add     w10, w10, #1
    cmp     w10, #MAXANIM
    b.lt    1b
    ret

// soldier_frame -> w0 = 1 se cuidou deste quadro (lutando ou indo lutar)
    .globl soldier_frame
soldier_frame:
    ldrb    w9, [x19, #P_STATE]
    cmp     w9, #ST_SLEEP
    b.eq    8f
    cmp     w9, #ST_FIGHT
    b.eq    soldier_fight
    ldr     w9, [x28, #G_PPLFRAME]      // a cada 16 quadros olha em volta
    add     w9, w9, w20
    tst     w9, #15
    b.ne    8f
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     s0, [x19, #P_U]
    ldr     s1, [x19, #P_V]
    LA      x9, dconst
    ldr     s2, [x9, #32]               // 16 celulas^2
    bl      hostile_near
    ldp     x29, x30, [sp], #16
    tbnz    w0, #31, 8f
    str     w0, [x19, #P_TARGET]
    mov     w9, #ST_FIGHT
    strb    w9, [x19, #P_STATE]
    strb    wzr, [x19, #P_NEXT]
    strb    wzr, [x19, #P_WKIND]
    strh    wzr, [x19, #P_TIMER]
    strh    wzr, [x19, #P_BLOCK]
    strh    wzr, [x19, #P_DET]
    mov     w0, #1
    ret
8:  mov     w0, #0
    ret

// soldier_fight: corre atras do bicho e golpeia (a cada 40 quadros)
// -> w0 = 1
soldier_fight:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     x23, x24, [sp, #32]
    stp     d8, d9, [sp, #48]
    ldr     w21, [x19, #P_TARGET]
    tbnz    w21, #31, 80f
    cmp     w21, #MAXANIM
    b.hs    80f
    LA      x22, animals
    add     x22, x22, x21, lsl #5
    ldrb    w23, [x22, #AN_TYPE]
    cmp     w23, #A_WOLF
    b.eq    1f
    cmp     w23, #A_BEAR
    b.ne    80f
1:  ldr     s0, [x22, #AN_U]
    ldr     s1, [x19, #P_U]
    fsub    s8, s0, s1
    ldr     s0, [x22, #AN_V]
    ldr     s1, [x19, #P_V]
    fsub    s9, s0, s1
    fmul    s2, s8, s8
    fmadd   s2, s9, s9, s2
    LA      x9, dconst
    ldr     s3, [x9, #36]               // longe demais (30 celulas)^2: desiste
    fcmp    s2, s3
    b.gt    80f
    ldr     s3, [x9, #40]               // perto (1,1 celula)^2: golpeia
    fcmp    s2, s3
    b.le    3f
    ldr     s0, [x22, #AN_U]            // corre atras
    str     s0, [x19, #P_GU]
    ldr     s0, [x22, #AN_V]
    str     s0, [x19, #P_GV]
    bl      ppl_walk
    b       90f
3:  ldrh    w9, [x19, #P_TIMER]
    cbz     w9, 4f
    sub     w9, w9, #1
    strh    w9, [x19, #P_TIMER]
    b       90f
4:  mov     w9, #40
    strh    w9, [x19, #P_TIMER]
    mov     w0, #IT_SWORD               // espada: 6; sem: 2
    bl      pinv_get
    mov     w1, #2
    cbz     w0, 5f
    mov     w1, #6
5:  mov     w0, w21
    bl      animal_hit
    ldrb    w9, [x22, #AN_TYPE]
    cmp     w9, #255
    b.ne    90f
    LA      x9, dstat                   // abateu
    ldr     w10, [x9]
    add     w10, w10, #1
    str     w10, [x9]
    LA      x0, pmsgbuf                 // "Ana Silva (soldado) abateu: Lobo"
    mov     w1, w20
    bl      ppl_namecat
    LA      x1, s_soldkill
    bl      strcat_cur
    LA      x1, animnames
    add     x1, x1, x23, lsl #4
    bl      strcat_cur
    LA      x0, pmsgbuf
    bl      set_msg
80: mov     w9, #ST_IDLE                // volta a patrulhar
    strb    w9, [x19, #P_STATE]
    mov     w9, #20
    strh    w9, [x19, #P_THINK]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
90: mov     w0, #1
    ldp     d8, d9, [sp, #48]
    ldp     x23, x24, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// soldier_patrol -> w0 = 1: anda ate um ponto a ate 6 celulas do bau mais
// perto (a vila) e fica de vigia
    .globl soldier_patrol
soldier_patrol:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x21, x22, [sp, #16]
    stp     d8, d9, [sp, #32]
    stp     d10, d11, [sp, #48]
    ldr     s8, [x19, #P_U]
    ldr     s9, [x19, #P_V]
    mov     w0, #0
    bl      ppl_chestfind
    tbnz    w0, #31, 1f
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrh    w10, [x9]
    ucvtf   s8, w10
    ldrh    w10, [x9, #2]
    ucvtf   s9, w10
    LA      x9, dconst
    ldr     s2, [x9]
    fmul    s8, s8, s2
    fmul    s9, s9, s2
1:  mov     w21, #6                     // ate 6 tentativas
2:  mov     w0, #13
    bl      rng_mod
    sub     w0, w0, #6
    scvtf   s10, w0
    mov     w0, #13
    bl      rng_mod
    sub     w0, w0, #6
    scvtf   s11, w0
    fadd    s10, s10, s8
    fadd    s11, s11, s9
    fmov    s0, s10
    fmov    s1, s11
    bl      ppl_land
    cbnz    w0, 3f
    subs    w21, w21, #1
    b.ne    2b
    mov     w9, #ST_WAIT                // nao achou: vigia ali mesmo
    strb    w9, [x19, #P_STATE]
    mov     w9, #120
    strh    w9, [x19, #P_TIMER]
    b       9f
3:  fmov    s0, s10
    fmov    s1, s11
    bl      ppl_gopoint
    strb    wzr, [x19, #P_NEXT]
    strb    wzr, [x19, #P_WKIND]
    mov     w9, #-1
    str     w9, [x19, #P_TARGET]
9:  mov     w0, #1
    ldp     d10, d11, [sp, #48]
    ldp     d8, d9, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
//  Teste automatico (--shot)
// ---------------------------------------------------------------------

// dt_count(w0 = tipo, w1 = minimo) -> w0 = objetos desse tipo com pelo
// menos esse tanto   folha
dt_count:
    mov     w2, w0
    mov     w0, #0
    ldr     w9, [x28, #G_NOBJ]
    LA      x10, objs
1:  cbz     w9, 9f
    ldrb    w11, [x10, #6]
    cmp     w11, w2
    b.ne    2f
    ldrb    w11, [x10, #7]
    cmp     w11, w1
    cinc    w0, w0, hs
2:  add     x10, x10, #8
    sub     w9, w9, #1
    b       1b
9:  ret

// dt_num(x0 cursor, x1 rotulo, w2 numero) -> x0
dt_num:
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

// dt_frames(w0 = quadros)
dt_frames:
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

// dt_alive(w0 = grupo) -> w0 = animais vivos desse grupo   folha
dt_alive:
    mov     w2, w0
    mov     w0, #0
    LA      x9, animals
    mov     w10, #MAXANIM
1:  ldrb    w11, [x9, #AN_TYPE]
    cmp     w11, #255
    b.eq    2f
    ldrb    w11, [x9, #AN_GRP]
    cmp     w11, w2
    cinc    w0, w0, eq
2:  add     x9, x9, #32
    subs    w10, w10, #1
    b.ne    1b
    ret

//   0: conta pedreiras, veios, arbustos e trigo; esgota uma pedreira
//      (foto da pedreira)
//   1: comida estraga, inverno, manada; de noite, uma alcateia vem atras
//      da vila e um soldado com espada defende (foto)
//   2: o fim da luta e o resultado
    .globl desafio_selftest
desafio_selftest:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     d8, d9, [sp, #80]
    LA      x24, dres
    ldr     w9, [x28, #G_NOPEOPLE]
    cbnz    w9, dt_ret
    cmp     w0, #1
    b.eq    dt_stage1
    b.hi    dt_stage2
    // ---- quanto tem no mundo ----
    mov     w0, #O_ROCK
    mov     w1, #12
    bl      dt_count
    str     w0, [x24]                   // celulas de pedreira
    mov     w0, #O_ROCK
    mov     w1, #1
    bl      dt_count
    ldr     w9, [x24]
    sub     w0, w0, w9
    str     w0, [x24, #4]               // pedras soltas
    mov     w0, #O_IRONV
    mov     w1, #1
    bl      dt_count
    str     w0, [x24, #8]
    mov     w0, #O_COALV
    mov     w1, #1
    bl      dt_count
    str     w0, [x24, #12]
    mov     w0, #O_BUSH
    mov     w1, #1
    bl      dt_count
    str     w0, [x24, #16]
    mov     w0, #O_WHEAT
    mov     w1, #0
    bl      dt_count
    str     w0, [x24, #20]
    // ---- a pedreira mais perto: esgota a celula e as vizinhas ----
    ldr     w9, [x28, #(G_INV + 4 * IT_STONE)]
    str     w9, [x24, #24]
    mov     w21, #-1                    // pedreira mais perto de voce
    mov     w22, #0x7FFFFFFF
    ldr     s0, [x28, #G_PU]
    fcvtzs  w25, s0
    ldr     s0, [x28, #G_PV]
    fcvtzs  w26, s0
    ldr     w19, [x28, #G_NOBJ]
    mov     w20, #0
1:  cmp     w20, w19
    b.ge    2f
    LA      x9, objs
    add     x9, x9, x20, lsl #3
    ldrb    w10, [x9, #6]
    cmp     w10, #O_ROCK
    b.ne    11f
    ldrb    w10, [x9, #7]
    cmp     w10, #12
    b.lo    11f
    ldrh    w10, [x9]
    lsr     w10, w10, #6
    sub     w10, w10, w25
    ldrh    w11, [x9, #2]
    lsr     w11, w11, #6
    sub     w11, w11, w26
    mul     w10, w10, w10
    madd    w10, w11, w11, w10
    cmp     w10, w22
    b.ge    11f
    mov     w22, w10
    mov     w21, w20
11: add     w20, w20, #1
    b       1b
2:  str     wzr, [x24, #28]
    str     wzr, [x24, #32]
    tbnz    w21, #31, 7f
    LA      x9, objs
    add     x9, x9, x21, lsl #3
    ldrh    w25, [x9]
    lsr     w25, w25, #6                // celula da pedreira
    ldrh    w26, [x9, #2]
    lsr     w26, w26, #6
    mov     w20, #0                     // ela e as vizinhas (ate 2 celulas)
3:  cmp     w20, w19
    b.ge    6f
    LA      x23, objs
    add     x23, x23, x20, lsl #3
    ldrb    w10, [x23, #6]
    cmp     w10, #O_ROCK
    b.ne    5f
    ldrh    w10, [x23]
    lsr     w10, w10, #6
    sub     w10, w10, w25
    ldrh    w11, [x23, #2]
    lsr     w11, w11, #6
    sub     w11, w11, w26
    mul     w10, w10, w10
    madd    w10, w11, w11, w10
    cmp     w10, #2
    b.gt    5f
4:  ldrb    w10, [x23, #6]              // quebra ate acabar
    cmp     w10, #O_ROCK
    b.ne    41f
    mov     w0, w20
    bl      harvest
    b       4b
41: ldrh    w10, [x23]
    lsr     w10, w10, #6
    ldrh    w11, [x23, #2]
    lsr     w11, w11, #6
    add     w10, w10, w11, lsl #9
    LA      x11, pitgrid
    ldrb    w10, [x11, w10, uxtw]
    ldr     w11, [x24, #28]
    add     w11, w11, w10
    str     w11, [x24, #28]             // buracos
    ldr     w11, [x24, #32]
    add     w11, w11, #1
    str     w11, [x24, #32]             // celulas esgotadas
5:  add     w20, w20, #1
    b       3b
6:  ldr     w9, [x28, #(G_INV + 4 * IT_STONE)]
    ldr     w10, [x24, #24]
    str     w10, [x28, #(G_INV + 4 * IT_STONE)]
    sub     w9, w9, w10
    str     w9, [x24, #24]              // pedras que tirou
    bl      calc_stats
    // foto: voce do lado do buraco, de dia
    scvtf   s0, w25
    scvtf   s1, w26
    fmov    s2, #2.5
    fadd    s0, s0, s2
    fadd    s1, s1, s2
    str     s0, [x28, #G_PU]
    str     s1, [x28, #G_PV]
7:  mov     w9, #(DAYLEN / 6)           // 10:00
    str     w9, [x28, #G_TIME]
    mov     w0, #2
    bl      dt_frames
    str     wzr, [x28, #G_MSGT]
    str     wzr, [x28, #G_POPT]
    b       dt_ret

dt_stage1:
    // ---- comida estraga: 8 carnes cruas na mochila e no bau, 1 dia ----
    mov     w9, #8
    str     w9, [x28, #(G_INV + 4 * IT_MEAT)]
    LA      x19, people
    mov     w20, #0
    mov     w0, #IT_WOOD
    mov     w1, #0
    mov     w2, #0
    mov     w3, #0
    bl      smith_chest
    mov     x21, #0
    tbnz    w0, #31, 1f
    bl      ppl_chestptr
    mov     x21, x0
    mov     w9, #8
    str     w9, [x21, #(4 * IT_MEAT)]
1:  str     wzr, [x28, #G_SPOILK]
    mov     w22, #32
2:  bl      spoil_step
    subs    w22, w22, #1
    b.ne    2b
    ldr     w9, [x28, #(G_INV + 4 * IT_MEAT)]
    str     w9, [x24, #36]
    str     wzr, [x24, #40]
    cbz     x21, 3f
    ldr     w9, [x21, #(4 * IT_MEAT)]
    str     w9, [x24, #40]
    str     wzr, [x21, #(4 * IT_MEAT)]
3:  str     wzr, [x28, #(G_INV + 4 * IT_MEAT)]
    bl      calc_stats
    // ---- inverno: 10 s de sol, de dia, longe do fogo ----
    ldr     w25, [x28, #G_DAY]          // um dia de inverno (a estacao
    ldr     w26, [x28, #G_PLASTDAY]     // sai do dia)
    mov     w9, #(3 * SEASONDAYS + 1)
    str     w9, [x28, #G_DAY]
    str     w9, [x28, #G_PLASTDAY]
    mov     w0, #W_SUN
    MOVI32  w1, 14400
    mov     w2, #WFADE
    bl      weather_set
    mov     w9, #(DAYLEN / 4)           // 12:00
    str     w9, [x28, #G_TIME]
    mov     w9, #60
    scvtf   s0, w9
    str     s0, [x28, #G_WARM]
    mov     w0, #600
    bl      dt_frames
    ldr     s0, [x28, #G_WARM]
    fcvtzs  w9, s0
    str     w9, [x24, #44]
    str     w25, [x28, #G_DAY]
    str     w26, [x28, #G_PLASTDAY]
    FC      s0, F_HUNDRED
    str     s0, [x28, #G_WARM]
    // ---- manada: um cervo a 12 celulas, os outros vem junto ----
    mov     w9, #1
    str     w9, [x28, #G_NOSPAWN]
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    LA      x9, dconst
    ldr     s2, [x9, #44]               // 12
    fadd    s0, s0, s2
    mov     w0, #A_DEER
    bl      animal_spawn
    str     wzr, [x24, #48]
    mov     w9, #99
    str     w9, [x24, #52]
    tbnz    w0, #31, 5f
    mov     w21, w0
    bl      herd_spawn
    mov     w0, #900
    bl      dt_frames
    LA      x9, animals                 // quantos e a maior distancia ate o
    add     x22, x9, x21, lsl #5        // primeiro
    ldrb    w23, [x22, #AN_GRP]
    mov     w0, w23
    bl      dt_alive
    str     w0, [x24, #48]
    fmov    s8, wzr
    LA      x9, animals
    mov     w10, #MAXANIM
4:  ldrb    w11, [x9, #AN_TYPE]
    cmp     w11, #255
    b.eq    41f
    ldrb    w11, [x9, #AN_GRP]
    cmp     w11, w23
    b.ne    41f
    ldr     s0, [x9, #AN_U]
    ldr     s1, [x22, #AN_U]
    fsub    s0, s0, s1
    ldr     s1, [x9, #AN_V]
    ldr     s2, [x22, #AN_V]
    fsub    s1, s1, s2
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fmax    s8, s8, s0
41: add     x9, x9, #32
    subs    w10, w10, #1
    b.ne    4b
    fsqrt   s8, s8
    fcvtzs  w9, s8
    str     w9, [x24, #52]
5:  bl      animals_reset
    // ---- de noite: alcateia e soldado ----
    LA      x19, people                 // voce perto do bau da vila
    mov     w20, #0
    mov     w0, #IT_WOOD
    mov     w1, #0
    mov     w2, #0
    mov     w3, #0
    bl      smith_chest
    tbnz    w0, #31, 6f
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrh    w10, [x9]
    ucvtf   s0, w10
    ldrh    w10, [x9, #2]
    ucvtf   s1, w10
    LA      x9, dconst
    ldr     s2, [x9]
    fmul    s8, s0, s2
    fmul    s9, s1, s2
    LA      x21, ring6                  // um lugar em terra do lado do bau
    mov     w22, #7
61: ldr     s0, [x21, #8]
    ldr     s1, [x21, #12]
    fmov    s2, #2.0
    fmadd   s0, s0, s2, s8
    fmadd   s1, s1, s2, s9
    bl      ppl_land
    cbnz    w0, 62f
    add     x21, x21, #8
    subs    w22, w22, #1
    b.ne    61b
62: ldr     s0, [x21, #8]
    ldr     s1, [x21, #12]
    fmov    s2, #2.0
    fmadd   s0, s0, s2, s8
    fmadd   s1, s1, s2, s9
    str     s0, [x28, #G_PU]
    str     s1, [x28, #G_PV]
6:  FC      s0, F_HUNDRED
    str     s0, [x28, #G_HP]
    str     s0, [x28, #G_FOOD]
    str     s0, [x28, #G_WARM]
    str     wzr, [x28, #G_DEAD]
    mov     w9, #(T_NIGHT + 300)
    str     w9, [x28, #G_TIME]
    LA      x9, dstat
    str     wzr, [x9]
    mov     w20, #4                     // soldado: o pai da segunda familia
    LA      x9, people
    add     x19, x9, x20, lsl #6
    mov     w9, #J_SOLDIER
    strb    w9, [x19, #P_JOB]
    mov     w9, #ST_IDLE
    strb    w9, [x19, #P_STATE]
    strh    wzr, [x19, #P_THINK]
    ldrb    w9, [x19, #P_FLAGS]
    bic     w9, w9, #1
    strb    w9, [x19, #P_FLAGS]
    mov     w9, #100
    scvtf   s0, w9
    str     s0, [x19, #P_HP]
    str     s0, [x19, #P_FOOD]
    mov     w0, #IT_SWORD
    mov     w1, #1
    bl      pinv_add
    ldr     s0, [x28, #G_PU]            // ele do seu lado
    fmov    s1, #0.75
    fadd    s0, s0, s1
    str     s0, [x19, #P_U]
    ldr     s0, [x28, #G_PV]
    str     s0, [x19, #P_V]
    ldr     w9, [x28, #G_PEOPLEN]
    str     w9, [x24, #56]              // pessoas antes
    mov     w0, #4
    bl      pack_spawn
    str     w0, [x24, #60]              // lobos que vieram
    mov     w0, #420
    bl      dt_frames
    str     wzr, [x28, #G_MSGT]
    str     wzr, [x28, #G_POPT]
    b       dt_ret

dt_stage2:
    mov     w0, #1500
    bl      dt_frames
    mov     w0, #1
    bl      dt_alive
    str     w0, [x24, #64]              // lobos da alcateia que sobraram
    LA      x9, dstat
    ldr     w9, [x9]
    str     w9, [x24, #68]              // abatidos pelo soldado
    LA      x10, people
    ldr     s0, [x10, #(4 * PSIZE + P_HP)]
    fcvtzs  w9, s0
    ldrb    w10, [x10, #(4 * PSIZE + P_ALIVE)]
    cmp     w10, #0
    csel    w9, wzr, w9, eq
    str     w9, [x24, #72]              // vida do soldado
    ldr     w9, [x28, #G_PEOPLEN]
    str     w9, [x24, #76]
    str     wzr, [x28, #G_NOSPAWN]
    bl      animals_reset
    FC      s0, F_HUNDRED
    str     s0, [x28, #G_HP]
    str     s0, [x28, #G_FOOD]
    str     s0, [x28, #G_WARM]
    str     s0, [x28, #G_STAMINA]
    str     wzr, [x28, #G_DEAD]
    LA      x0, txt
    LA      x1, dt_t1
    ldr     w2, [x24]
    bl      dt_num
    LA      x1, dt_t2
    ldr     w2, [x24, #4]
    bl      dt_num
    LA      x1, dt_t3
    ldr     w2, [x24, #8]
    bl      dt_num
    LA      x1, dt_t4
    ldr     w2, [x24, #12]
    bl      dt_num
    LA      x1, dt_t5
    ldr     w2, [x24, #16]
    bl      dt_num
    LA      x1, dt_t6
    ldr     w2, [x24, #20]
    bl      dt_num
    LA      x1, dt_t7
    ldr     w2, [x24, #32]
    bl      dt_num
    LA      x1, dt_t8
    ldr     w2, [x24, #28]
    bl      dt_num
    LA      x1, dt_t9
    ldr     w2, [x24, #24]
    bl      dt_num
    LA      x1, dt_nl
    bl      strcat_cur
    LA      x1, dt_u1
    ldr     w2, [x24, #36]
    bl      dt_num
    LA      x1, dt_u2
    ldr     w2, [x24, #40]
    bl      dt_num
    LA      x1, dt_u3
    ldr     w2, [x24, #44]
    bl      dt_num
    LA      x1, dt_u4
    ldr     w2, [x24, #48]
    bl      dt_num
    LA      x1, dt_u5
    ldr     w2, [x24, #52]
    bl      dt_num
    LA      x1, dt_u6
    ldr     w2, [x24, #60]
    bl      dt_num
    LA      x1, dt_u7
    ldr     w2, [x24, #68]
    bl      dt_num
    LA      x1, dt_u8
    ldr     w2, [x24, #64]
    bl      dt_num
    LA      x1, dt_u9
    ldr     w2, [x24, #72]
    bl      dt_num
    LA      x1, dt_u10
    ldr     w2, [x24, #56]
    bl      dt_num
    LA      x1, dt_u11
    ldr     w2, [x24, #76]
    bl      dt_num
    LA      x1, dt_nl
    bl      strcat_cur
    bl      sk_write
dt_ret:
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
dconst:
    .float 0.015625                     //  0 1/64
    .float 1.8                          //  4 alcateia
    .float 1.3                          //  8 manada
    .float 6.25                         // 12 2,5 celulas^2
    .float 2025.0                       // 16 45 celulas^2
    .float 22.0                         // 20 a alcateia aparece a 22 celulas
    .float 6.0                          // 24 dentro do mapa
    .float 505.0                        // 28
    .float 256.0                        // 32 16 celulas^2 (soldado ve)
    .float 900.0                        // 36 30 celulas^2 (desiste)
    .float 1.21                         // 40 1,1 celula^2 (golpeia)
    .float 12.0                         // 44
// 16 direcoes (cos, sen)
dir16:
    .float 1.0, 0.0,  0.924, 0.383,  0.707, 0.707,  0.383, 0.924
    .float 0.0, 1.0,  -0.383, 0.924,  -0.707, 0.707,  -0.924, 0.383
    .float -1.0, 0.0,  -0.924, -0.383,  -0.707, -0.707,  -0.383, -0.924
    .float 0.0, -1.0,  0.383, -0.924,  0.707, -0.707,  0.924, -0.383
// os lobos da alcateia em volta do lugar
ring6:
    .float 0.0, 0.0,  0.9, 0.3,  -0.4, 0.9,  -0.8, -0.5
    .float 0.3, -0.9,  1.4, -0.6,  -1.3, 0.2,  0.5, 1.4
// os cervos em volta do primeiro
herdoff:
    .float 1.2, 0.4,  -0.6, 1.1,  0.3, -1.2
// o que estraga e de quantos em quantos passos (1/32 de dia); no bau, o
// dobro
spoiltab:
    .byte IT_MEAT, 8, IT_FISH, 8, IT_BERRY, 16
    .byte IT_COOKED, 24, IT_CMEAT, 24, IT_CFISH, 24, 255
s_rot:      .asciz "Estragou: "
s_sp:       .asciz " "
s_pack1:    .asciz "Uivos na noite! Uma alcateia de "
s_pack2:    .asciz " lobos vem atras da vila"
s_soldkill: .asciz " (soldado) abateu: "
dt_t1:  .asciz "desafio: pedreiras (celulas)="
dt_t2:  .asciz " pedras soltas="
dt_t3:  .asciz " veios de ferro="
dt_t4:  .asciz " carvao="
dt_t5:  .asciz " | arbustos com frutas="
dt_t6:  .asciz " trigo selvagem="
dt_t7:  .asciz " | pedreira: celulas esgotadas="
dt_t8:  .asciz " buracos="
dt_t9:  .asciz " pedras tiradas="
dt_u1:  .asciz "desafio: carne crua 8 em 1 dia -> mochila="
dt_u2:  .asciz " bau="
dt_u3:  .asciz " | inverno, 10 s de sol: calor 60 -> "
dt_u4:  .asciz " | manada: cervos="
dt_u5:  .asciz " longe do primeiro (celulas)="
dt_u6:  .asciz " | noite: alcateia="
dt_u7:  .asciz " soldado abateu="
dt_u8:  .asciz " sobraram="
dt_u9:  .asciz " vida do soldado="
dt_u10: .asciz " pessoas "
dt_u11: .asciz " -> "
dt_nl:  .asciz "\n"
    .p2align 2
dstat:  .space 16
dres:   .space 96
dmsg:   .space 96

GBSS pitgrid, (MAPN * MAPN)
