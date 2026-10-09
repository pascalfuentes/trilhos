// =====================================================================
//  animais.S - animais, caca e flechas (com o arco na mao, o clique atira;
//  de dia o lobo so aparece na floresta).
//
//  - Os animais aparecem fora da vista (20-34 celulas do personagem),
//    de acordo com o terreno: caranguejo na praia, coelho no campo,
//    cervo, lobo e urso na floresta, cabra nas colinas e na rocha, urso
//    e cabra na neve. De noite aparecem mais lobos.
//  - Pacificos (coelho, cervo, cabra, caranguejo) andam a toa e fogem
//    quando voce chega perto ou quando sao feridos.
//  - Perigosos (lobo, urso) perseguem e mordem; de dia so de perto.
//    Tem medo de fogo: perto de uma fogueira (ou no abrigo) voce esta
//    seguro. Nenhum entra na agua nem passa por cercas e portoes.
//  - Abatidos, deixam pilhas de carne e couro no chao.
//  - Flechas voam em linha reta ate acertar um animal ou cair.
// =====================================================================

#include "comum.h"

// animal (32 bytes): u, v, du, dv (float), tipo (255 = vaga), vida,
// estado, ferido (quadros), tempo ate mudar de rumo (u16), espera da
// mordida (u16), passos (u16)
.equ AN_U,     0
.equ AN_V,     4
.equ AN_DU,    8
.equ AN_DV,    12
.equ AN_TYPE,  16
.equ AN_HP,    17
.equ AN_HURT,  19
.equ AN_TIMER, 20
.equ AN_CD,    22
.equ AN_ANIM,  24

// flecha (32 bytes): u, v, du, dv (float), vida (quadros), altura
.equ AR_LIFE,  16
.equ AR_E,     20

// tipo de animal (16 bytes): vida, perigoso, carne, couro, mordida,
// sprite, raio (celulas), 0, velocidade andando, correndo
.equ AT_HP,    0
.equ AT_HOST,  1
.equ AT_MEAT,  2
.equ AT_HIDE,  3
.equ AT_DMG,   4
.equ AT_SPR,   5
.equ AT_RAD,   6
.equ AT_WALK,  8
.equ AT_RUN,   12

    .text
    .p2align 2

// animals_reset: ninguem no mundo
    .globl animals_reset
animals_reset:
    LA      x9, animals
    mov     w10, #MAXANIM
    mov     w11, #255
1:  strb    w11, [x9, #AN_TYPE]
    add     x9, x9, #32
    subs    w10, w10, #1
    b.ne    1b
    LA      x9, arrows
    mov     w10, #MAXARROW
2:  str     wzr, [x9, #AR_LIFE]
    add     x9, x9, #32
    subs    w10, w10, #1
    b.ne    2b
    str     wzr, [x28, #G_NANIM]
    mov     w9, #60
    str     w9, [x28, #G_SPAWNT]
    ret

    .globl terrain_class
// terrain_class(s0 = u, s1 = v) -> w0: -1 agua, 0 praia, 1 campo seco,
// 2 campo, 3 floresta, 4 colinas, 5 rocha, 6 neve
terrain_class:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     d8, d9, [sp, #16]
    fmov    s8, s0
    fmov    s9, s1
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    b.lt    8f
    fcvtzs  w9, s8                      // umidade da celula
    fcvtzs  w10, s9
    add     w9, w9, w10, lsl #9
    LA      x10, moist
    ldrb    w9, [x10, w9, uxtw]
    mov     w1, w0
    mov     w0, #0
    cmp     w1, #E_SAND
    b.lt    9f
    cmp     w1, #E_GRASS
    b.ge    2f
    mov     w0, #3
    cmp     w9, #150
    b.hs    9f
    mov     w0, #2
    cmp     w9, #95
    b.hs    9f
    mov     w0, #1
    b       9f
2:  cmp     w1, #E_HILL
    b.ge    3f
    mov     w0, #3
    cmp     w9, #140
    b.hs    9f
    mov     w0, #4
    b       9f
3:  mov     w0, #5
    mov     w10, #E_ROCK
    cmp     w1, w10
    b.lt    9f
    mov     w0, #6
    b       9f
8:  mov     w0, #-1
9:  ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// animal_spawn(w0 = tipo, s0 = u, s1 = v) -> w0 = numero (-1 sem vaga)
    .globl animal_spawn
animal_spawn:
    LA      x9, animals
    mov     w10, #0
1:  ldrb    w11, [x9, #AN_TYPE]
    cmp     w11, #255
    b.eq    2f
    add     x9, x9, #32
    add     w10, w10, #1
    cmp     w10, #MAXANIM
    b.lt    1b
    mov     w0, #-1
    ret
2:  str     s0, [x9, #AN_U]
    str     s1, [x9, #AN_V]
    str     wzr, [x9, #AN_DU]
    str     wzr, [x9, #AN_DV]
    strb    w0, [x9, #AN_TYPE]
    LA      x11, atypes
    add     x11, x11, x0, lsl #4
    ldrb    w11, [x11, #AT_HP]
    strb    w11, [x9, #AN_HP]
    strb    wzr, [x9, #AN_HURT]
    strh    wzr, [x9, #AN_TIMER]
    strh    wzr, [x9, #AN_CD]
    strh    wzr, [x9, #AN_ANIM]
    mov     w0, w10
    ret

// try_spawn: um animal novo fora da vista, de acordo com o terreno
// -> w0 = 1 se o lugar sorteado nao servia (agua, fora do mapa)
try_spawn:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     d8, d9, [sp, #32]
    bl      rng                         // direcao e distancia (20..33)
    and     w9, w0, #15
    lsr     w19, w0, #4
    and     w19, w19, #15
    add     w19, w19, #20
    LA      x10, adirtab
    add     x10, x10, x9, lsl #2
    ldrsh   w11, [x10]
    scvtf   s0, w11
    ldrsh   w11, [x10, #2]
    scvtf   s1, w11
    LA      x10, aconst
    ldr     s2, [x10]                   // 1/64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    scvtf   s2, w19
    ldr     s3, [x28, #G_PU]
    fmadd   s8, s0, s2, s3
    ldr     s3, [x28, #G_PV]
    fmadd   s9, s1, s2, s3
    mov     w9, #3                      // dentro do mapa
    scvtf   s2, w9
    mov     w9, #508
    scvtf   s3, w9
    mov     w9, #1
    fcmp    s8, s2
    b.lt    91f
    fcmp    s8, s3
    b.gt    91f
    fcmp    s9, s2
    b.lt    91f
    fcmp    s9, s3
    b.gt    91f
    fmov    s0, s8
    fmov    s1, s9
    bl      terrain_class
    mov     w9, #1
    tbnz    w0, #31, 91f                // agua: tenta outro lugar
    mov     w19, w0
    bl      rng
    and     w9, w0, #7
    LA      x10, spawntab
    add     x10, x10, x19, lsl #3
    ldrb    w20, [x10, x9]
    // de noite, no campo/floresta/colinas: 1/3 de chance de ser lobo
    ldr     w9, [x28, #G_NIGHTK]
    cmp     w9, #128
    b.lt    1f
    cmp     w19, #2
    b.lt    1f
    cmp     w19, #4
    b.gt    1f
    lsr     w9, w0, #3
    mov     w10, #3
    udiv    w11, w9, w10
    msub    w11, w11, w10, w9
    cbnz    w11, 1f
    mov     w20, #A_WOLF
1:  cmp     w20, #255
    b.eq    9f
    mov     w0, w20
    fmov    s0, s8
    fmov    s1, s9
    bl      animal_spawn
9:  mov     w9, #0
91: mov     w0, w9
    ldp     d8, d9, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// animals_update: aparecer, andar, fugir, perseguir e morder
    .globl animals_update
animals_update:
    stp     x29, x30, [sp, #-128]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     d8, d9, [sp, #64]
    stp     d10, d11, [sp, #80]
    stp     d12, d13, [sp, #96]
    // de tempos em tempos tenta aparecer um animal
    ldr     w9, [x28, #G_SPAWNT]
    subs    w9, w9, #1
    b.gt    1f
    bl      rng
    and     w9, w0, #63
    add     w9, w9, #90                 // a cada 1.5 - 2.5 s
    str     w9, [x28, #G_SPAWNT]
    ldr     w10, [x28, #G_NOSPAWN]
    cbnz    w10, 2f
    ldr     w10, [x28, #G_NANIM]
    cmp     w10, #MAXALIVE
    b.ge    2f
    mov     w19, #4                     // ate 4 lugares (agua nao serve)
11: bl      try_spawn
    cbz     w0, 2f
    subs    w19, w19, #1
    b.ne    11b
    b       2f
1:  str     w9, [x28, #G_SPAWNT]
2:  mov     w23, #0                     // vivos
    mov     w19, #0
au_loop:
    cmp     w19, #MAXANIM
    b.ge    au_done
    LA      x20, animals
    add     x20, x20, x19, lsl #5
    ldrb    w21, [x20, #AN_TYPE]
    cmp     w21, #255
    b.eq    au_next
    LA      x22, atypes
    add     x22, x22, x21, lsl #4
    ldr     s0, [x20, #AN_U]            // ate o personagem
    ldr     s1, [x20, #AN_V]
    ldr     s8, [x28, #G_PU]
    fsub    s8, s8, s0                  // dx
    ldr     s9, [x28, #G_PV]
    fsub    s9, s9, s1                  // dy
    fmul    s10, s8, s8
    fmadd   s10, s9, s9, s10            // d2
    LA      x9, aconst
    ldr     s2, [x9, #4]                // 60^2: longe demais, some
    fcmp    s10, s2
    b.le    3f
    mov     w9, #255
    strb    w9, [x20, #AN_TYPE]
    b       au_next
3:  add     w23, w23, #1
    fsqrt   s11, s10                    // d
    ldrb    w9, [x20, #AN_HURT]         // ferido e espera da mordida
    subs    w9, w9, #1
    csel    w9, wzr, w9, lt
    strb    w9, [x20, #AN_HURT]
    ldrh    w9, [x20, #AN_CD]
    subs    w9, w9, #1
    csel    w9, wzr, w9, lt
    strh    w9, [x20, #AN_CD]
    ldrb    w9, [x22, #AT_RAD]          // raio de alerta
    scvtf   s12, w9
    ldr     s13, [x22, #AT_RUN]         // velocidade correndo
    ldrb    w9, [x22, #AT_HOST]
    cbz     w9, au_passive
    // ---- perigoso ----
    mov     x0, x20                     // uma pessoa da vila mais perto?
    mov     x1, x22
    fmov    s0, s10
    bl      beast_people
    cmp     w0, #1
    b.eq    au_move
    b.hi    au_next
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, au_wander
    ldr     w9, [x28, #G_NEARFIRE]      // medo de fogo; nao entra no abrigo
    cbnz    w9, au_wander
    ldr     w9, [x28, #G_INSHELTER]
    cbnz    w9, au_wander
    ldr     w9, [x28, #G_NIGHTK]        // de dia so ataca de perto
    cmp     w9, #128
    b.ge    4f
    fmov    s2, #0.5
    fmul    s12, s12, s2
4:  ldrb    w9, [x20, #AN_HP]           // ferido: furioso
    ldrb    w10, [x22, #AT_HP]
    cmp     w9, w10
    b.ge    5f
    fmov    s12, #15.0
5:  fmul    s2, s12, s12
    fcmp    s10, s2
    b.ge    au_wander
    fmov    s2, #1.0                    // perto: para e morde
    fcmp    s11, s2
    b.ge    6f
    str     wzr, [x20, #AN_DU]
    str     wzr, [x20, #AN_DV]
    ldrh    w9, [x20, #AN_CD]
    cbnz    w9, au_next
    mov     w9, #60
    strh    w9, [x20, #AN_CD]
    ldrb    w9, [x22, #AT_DMG]
    scvtf   s2, w9
    ldr     s3, [x28, #G_HP]
    fsub    s3, s3, s2
    str     s3, [x28, #G_HP]
    LA      x9, killmsg
    ldr     x9, [x9, x21, lsl #3]
    str     x9, [x28, #G_KILLER]
    mov     w9, #180
    str     w9, [x28, #G_KILLT]
    LA      x0, p_bite
    bl      popup
    b       au_next
6:  fdiv    s2, s13, s11                // persegue
    fmul    s0, s8, s2
    fmul    s1, s9, s2
    b       au_setmove
    // ---- pacifico: foge se voce chegar perto ou se ferido ----
au_passive:
    ldrb    w9, [x20, #AN_HURT]
    cbnz    w9, 7f
    fmul    s2, s12, s12
    fcmp    s10, s2
    b.ge    au_wander
7:  fmov    s2, #0.125
    fmax    s11, s11, s2
    fdiv    s2, s13, s11
    fmul    s0, s8, s2
    fmul    s1, s9, s2
    fneg    s0, s0
    fneg    s1, s1
    b       au_setmove
    // ---- andando a toa: muda de rumo de vez em quando ----
au_wander:
    ldrh    w9, [x20, #AN_TIMER]
    subs    w9, w9, #1
    b.gt    8f
    cmp     w21, #A_GOAT                // coelho, cervo e cabra: trigo maduro?
    b.hi    80f
    mov     x0, x20
    ldr     s0, [x22, #AT_WALK]
    fmov    s1, #1.5
    fmul    s0, s0, s1
    bl      crop_seek
    cbnz    w0, au_move
80: bl      rng
    mov     w24, w0
    and     w9, w0, #127
    add     w9, w9, #60
    strh    w9, [x20, #AN_TIMER]
    tst     w24, #3                     // 1 em 4: fica parado
    b.ne    81f
    str     wzr, [x20, #AN_DU]
    str     wzr, [x20, #AN_DV]
    b       au_move
81: lsr     w9, w24, #2
    and     w9, w9, #15
    LA      x10, adirtab
    add     x10, x10, x9, lsl #2
    ldrsh   w11, [x10]
    scvtf   s0, w11
    ldrsh   w11, [x10, #2]
    scvtf   s1, w11
    LA      x10, aconst
    ldr     s2, [x10]
    ldr     s3, [x22, #AT_WALK]
    fmul    s2, s2, s3
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    b       au_setmove
8:  strh    w9, [x20, #AN_TIMER]
    b       au_move
au_setmove:
    str     s0, [x20, #AN_DU]
    str     s1, [x20, #AN_DV]
    // ---- anda (nao entra na agua nem sai do mapa) ----
au_move:
    ldr     s0, [x20, #AN_DU]
    ldr     s1, [x20, #AN_DV]
    fmul    s2, s0, s0
    fmadd   s2, s1, s1, s2
    fcmp    s2, #0.0
    b.eq    au_next
    ldr     s2, [x20, #AN_U]
    fadd    s8, s2, s0
    ldr     s2, [x20, #AN_V]
    fadd    s9, s2, s1
    mov     w9, #2
    scvtf   s2, w9
    mov     w9, #509
    scvtf   s3, w9
    fcmp    s8, s2
    b.lt    au_block
    fcmp    s8, s3
    b.gt    au_block
    fcmp    s9, s2
    b.lt    au_block
    fcmp    s9, s3
    b.gt    au_block
    fmov    s4, s8                      // cerca ou portao: nao passa
    fmov    s5, s9
    bl      fence_at
    cbnz    w0, au_block
    fmov    s0, s8
    fmov    s1, s9
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    b.lt    au_block
    str     s8, [x20, #AN_U]
    str     s9, [x20, #AN_V]
    ldrh    w9, [x20, #AN_ANIM]
    add     w9, w9, #1
    strh    w9, [x20, #AN_ANIM]
    b       au_next
au_block:
    strh    wzr, [x20, #AN_TIMER]       // agua ou borda: escolhe outro rumo
    str     wzr, [x20, #AN_DU]
    str     wzr, [x20, #AN_DV]
au_next:
    add     w19, w19, #1
    b       au_loop
au_done:
    str     w23, [x28, #G_NANIM]
    ldp     d12, d13, [sp, #96]
    ldp     d10, d11, [sp, #80]
    ldp     d8, d9, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #128
    ret

// animal_hit(w0 = animal, w1 = dano): abatido deixa carne e couro
    .globl animal_hit
animal_hit:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    LA      x19, animals
    add     x19, x19, x0, lsl #5
    ldrb    w20, [x19, #AN_TYPE]
    cmp     w20, #255
    b.eq    9f
    mov     w9, #16
    strb    w9, [x19, #AN_HURT]
    ldrb    w9, [x19, #AN_HP]
    subs    w9, w9, w1
    csel    w9, wzr, w9, lt
    strb    w9, [x19, #AN_HP]
    cbnz    w9, 9f
    // abatido
    LA      x21, atypes
    add     x21, x21, x20, lsl #4
    mov     w0, #IT_MEAT
    ldrb    w1, [x21, #AT_MEAT]
    ldr     s0, [x19, #AN_U]
    ldr     s1, [x19, #AN_V]
    bl      pile_at
    ldrb    w1, [x21, #AT_HIDE]
    cbz     w1, 1f
    mov     w0, #IT_HIDE
    ldr     s0, [x19, #AN_U]
    ldr     s1, [x19, #AN_V]
    fmov    s2, #0.5
    fadd    s0, s0, s2
    bl      pile_at
1:  mov     w9, #255
    strb    w9, [x19, #AN_TYPE]
    LA      x0, msgbuf                  // "Abateu: Cervo"
    LA      x1, s_killed
    bl      strcat_cur
    LA      x1, animnames
    add     x1, x1, x20, lsl #4
    bl      strcat_cur
    LA      x0, msgbuf
    bl      set_msg
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// animal_at(w0 = u, w1 = v em 1/64) -> w0 animal (a vista) ate 1 celula
    .globl animal_at
animal_at:
    scvtf   s0, w0
    scvtf   s1, w1
    LA      x9, aconst
    ldr     s2, [x9]
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    fmov    s4, #1.0                    // melhor distancia^2
    mov     w0, #-1
    LA      x10, animals
    mov     w11, #0
1:  ldrb    w12, [x10, #AN_TYPE]
    cmp     w12, #255
    b.eq    2f
    ldr     s2, [x10, #AN_U]
    ldr     s3, [x10, #AN_V]
    fcvtzs  w13, s2                     // so se estiver a vista
    fcvtzs  w14, s3
    add     w13, w13, w14, lsl #9
    LA      x14, vis
    ldrb    w13, [x14, w13, uxtw]
    cmp     w13, #VIS_MIN
    b.lo    2f
    fsub    s2, s2, s0
    fsub    s3, s3, s1
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    fcmp    s2, s4
    b.ge    2f
    fmov    s4, s2
    mov     w0, w11
2:  add     x10, x10, #32
    add     w11, w11, #1
    cmp     w11, #MAXANIM
    b.lt    1b
    ret

// animal_desc(x0 = cursor, w1 = animal) -> x0, w1 = 1 se perigoso
// ("Lobo (vida 4/6) - perigoso!")
    .globl animal_desc
animal_desc:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    LA      x19, animals
    add     x19, x19, x1, lsl #5
    ldrb    w20, [x19, #AN_TYPE]
    LA      x21, atypes
    add     x21, x21, x20, lsl #4
    LA      x1, animnames
    add     x1, x1, x20, lsl #4
    bl      strcat_cur
    LA      x1, s_avida
    bl      strcat_cur
    ldrb    w1, [x19, #AN_HP]
    bl      numcat
    mov     w9, #47
    strb    w9, [x0], #1
    ldrb    w1, [x21, #AT_HP]
    bl      numcat
    mov     w9, #41
    strb    w9, [x0], #1
    strb    wzr, [x0]
    ldrb    w22, [x21, #AT_HOST]
    cbz     w22, 1f
    LA      x1, s_danger
    bl      strcat_cur
1:  mov     w1, w22
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// melee_attack(w0 = animal) -> w0 = 1 se golpeou (perto o bastante)
    .globl melee_attack
melee_attack:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w0
    LA      x9, animals
    add     x9, x9, x19, lsl #5
    ldr     s0, [x9, #AN_U]
    ldr     s1, [x9, #AN_V]
    ldr     s2, [x28, #G_PU]
    ldr     s3, [x28, #G_PV]
    fsub    s0, s0, s2
    fsub    s1, s1, s3
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fmov    s1, #4.0                    // ate 2 celulas
    mov     w0, #0
    fcmp    s0, s1
    b.gt    9f
    mov     w0, #1
    ldr     w9, [x28, #G_ATKCD]
    cbnz    w9, 9f
    mov     w9, #30
    str     w9, [x28, #G_ATKCD]
    ldr     w9, [x28, #G_HAND]          // dano pelo que esta na mao
    LA      x10, handdmg
    ldrb    w1, [x10, x9]
    mov     w0, w19
    bl      animal_hit
    LA      x0, p_hit
    bl      popup
    mov     w0, #1
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// shoot_arrow: atira uma flecha do personagem para o ponto do mouse
    .globl shoot_arrow
shoot_arrow:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #G_ATKCD]
    cbnz    w9, 9f
    ldr     w9, [x28, #(G_INV + 4 * IT_ARROW)]
    cbnz    w9, 1f
    LA      x0, m_noarrow
    bl      set_msg
    b       9f
1:  ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 9f
    ldr     w9, [x28, #G_HOVU]          // direcao
    scvtf   s0, w9
    ldr     w9, [x28, #G_HOVV]
    scvtf   s1, w9
    LA      x9, aconst
    ldr     s2, [x9]
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    ldr     s2, [x28, #G_PU]
    ldr     s3, [x28, #G_PV]
    fsub    s0, s0, s2
    fsub    s1, s1, s3
    fmul    s4, s0, s0
    fmadd   s4, s1, s1, s4
    fsqrt   s4, s4
    fmov    s5, #0.25
    fcmp    s4, s5
    b.lt    9f
    ldr     s5, [x9, #8]                // velocidade da flecha
    fdiv    s5, s5, s4
    fmul    s0, s0, s5
    fmul    s1, s1, s5
    LA      x10, arrows                 // vaga livre
    mov     w11, #0
2:  ldr     w12, [x10, #AR_LIFE]
    cbz     w12, 3f
    add     x10, x10, #32
    add     w11, w11, #1
    cmp     w11, #MAXARROW
    b.lt    2b
    b       9f
3:  str     s2, [x10, #AN_U]
    str     s3, [x10, #AN_V]
    str     s0, [x10, #AN_DU]
    str     s1, [x10, #AN_DV]
    mov     w12, #40                    // ~18 celulas de alcance
    str     w12, [x10, #AR_LIFE]
    ldr     w12, [x28, #G_PE]
    add     w12, w12, #64               // na altura do peito
    str     w12, [x10, #AR_E]
    ldr     w9, [x28, #(G_INV + 4 * IT_ARROW)]
    sub     w9, w9, #1
    str     w9, [x28, #(G_INV + 4 * IT_ARROW)]
    mov     w9, #30
    str     w9, [x28, #G_ATKCD]
    bl      calc_stats
9:  ldp     x29, x30, [sp], #16
    ret

// arrows_update: as flechas voam; acertando um animal, machucam
    .globl arrows_update
arrows_update:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    LA      x19, arrows
    mov     w20, #0
1:  ldr     w9, [x19, #AR_LIFE]
    cbz     w9, 5f
    sub     w9, w9, #1
    str     w9, [x19, #AR_LIFE]
    ldr     s0, [x19, #AN_U]
    ldr     s1, [x19, #AN_DU]
    fadd    s0, s0, s1
    str     s0, [x19, #AN_U]
    ldr     s1, [x19, #AN_V]
    ldr     s2, [x19, #AN_DV]
    fadd    s1, s1, s2
    str     s1, [x19, #AN_V]
    mov     w9, #2                      // saiu do mapa
    scvtf   s2, w9
    mov     w9, #509
    scvtf   s3, w9
    fcmp    s0, s2
    b.lt    4f
    fcmp    s0, s3
    b.gt    4f
    fcmp    s1, s2
    b.lt    4f
    fcmp    s1, s3
    b.gt    4f
    LA      x21, animals                // acertou alguem?
    mov     w22, #0
2:  ldrb    w9, [x21, #AN_TYPE]
    cmp     w9, #255
    b.eq    3f
    ldr     s2, [x21, #AN_U]
    ldr     s3, [x21, #AN_V]
    fsub    s2, s2, s0
    fsub    s3, s3, s1
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    LA      x9, aconst
    ldr     s3, [x9, #12]               // 0.6^2
    fcmp    s2, s3
    b.gt    3f
    mov     w0, w22
    mov     w1, #4                      // dano da flecha
    bl      animal_hit
    b       4f
3:  add     x21, x21, #32
    add     w22, w22, #1
    cmp     w22, #MAXANIM
    b.lt    2b
    b       5f
4:  str     wzr, [x19, #AR_LIFE]
5:  add     x19, x19, #32
    add     w20, w20, #1
    cmp     w20, #MAXARROW
    b.lt    1b
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// arrows_draw: cada flecha e um risco curto (ponta cinza)
    .globl arrows_draw
arrows_draw:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
    LA      x19, arrows
    mov     w20, #0
1:  ldr     w9, [x19, #AR_LIFE]
    cbz     w9, 8f
    ldr     s0, [x19, #AN_U]            // ponta
    ldr     s1, [x19, #AN_V]
    ldr     w0, [x19, #AR_E]
    bl      proj
    mov     w21, w0
    mov     w22, w1
    ldr     s0, [x19, #AN_U]            // rabo
    ldr     s2, [x19, #AN_DU]
    fmov    s3, #1.5
    fmsub   s0, s2, s3, s0
    ldr     s1, [x19, #AN_V]
    ldr     s2, [x19, #AN_DV]
    fmsub   s1, s2, s3, s1
    ldr     w0, [x19, #AR_E]
    bl      proj
    sub     w23, w0, w21                // vetor rabo - ponta
    sub     w24, w1, w22
    mov     w25, #0
2:  cmp     w25, #12
    b.ge    8f
    mul     w0, w23, w25                // ponto = ponta + vetor * i / 12
    mov     w9, #12
    sdiv    w0, w0, w9
    add     w0, w0, w21
    mul     w1, w24, w25
    sdiv    w1, w1, w9
    add     w1, w1, w22
    MOVI32  w2, 0xFF7A4A24
    cmp     w25, #3
    b.ge    3f
    MOVI32  w2, 0xFFC8C8C8
3:  cmp     w0, #SCRW
    b.hs    4f
    cmp     w1, #SCRH
    b.hs    4f
    mov     w9, #SCRW
    madd    w9, w1, w9, w0
    LA      x10, fb
    str     w2, [x10, w9, uxtw #2]
    add     w9, w9, #SCRW               // 2 pixels de grossura
    cmp     w1, #(SCRH - 1)
    b.hs    4f
    str     w2, [x10, w9, uxtw #2]
4:  add     w25, w25, #1
    b       2b
8:  add     x19, x19, #32
    add     w20, w20, #1
    cmp     w20, #MAXARROW
    b.lt    1b
    ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// animals_draw(w0 = escala): so os que estao a vista; ferido pisca
    .globl animals_draw
animals_draw:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     x23, [sp, #48]
    mov     w23, w0
    LA      x19, animals
    mov     w20, #0
1:  ldrb    w21, [x19, #AN_TYPE]
    cmp     w21, #255
    b.eq    8f
    ldrb    w9, [x19, #AN_HURT]
    tbnz    w9, #1, 8f
    ldr     s0, [x19, #AN_U]
    ldr     s1, [x19, #AN_V]
    fcvtzs  w9, s0
    fcvtzs  w10, s1
    add     w9, w9, w10, lsl #9
    LA      x10, vis
    ldrb    w9, [x10, w9, uxtw]
    cmp     w9, #VIS_MIN
    b.lo    8f
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    csel    w0, w9, w0, lt
    ldr     s0, [x19, #AN_U]
    ldr     s1, [x19, #AN_V]
    bl      proj
    mov     w4, w2
    add     w4, w4, #20
    mov     w2, w1
    mov     w1, w0
    LA      x9, atypes
    add     x9, x9, x21, lsl #4
    ldrb    w9, [x9, #AT_SPR]
    ldrh    w10, [x19, #AN_ANIM]        // dois quadros andando
    lsr     w10, w10, #3
    and     w10, w10, #1
    add     w9, w9, w10
    LA      x0, sprites
    add     x0, x0, x9, lsl #7
    mov     w3, w23
    mov     w5, #0
    bl      blit
8:  add     x19, x19, #32
    add     w20, w20, #1
    cmp     w20, #MAXANIM
    b.lt    1b
    ldr     x23, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ct_animals(w0 = tipo) -> w0 = quantos vivos (teste)
    .globl ct_animals
ct_animals:
    LA      x9, animals
    mov     w10, #0
    mov     w11, #0
1:  ldrb    w12, [x9, #AN_TYPE]
    cmp     w12, w0
    cinc    w11, w11, eq
    add     x9, x9, #32
    add     w10, w10, #1
    cmp     w10, #MAXANIM
    b.lt    1b
    mov     w0, w11
    ret

// ---------------------------------------------------------------------
//  Dados
// ---------------------------------------------------------------------
    .data
    .p2align 2
aconst:
    .float 0.015625                     // 1/64
    .float 3600.0                       // 60 celulas^2: some
    .float 0.45                         // velocidade da flecha
    .float 0.49                         // flecha acerta a 0.7 celula

// vida, perigoso, carne, couro, mordida, sprite, raio, 0, anda, corre
    .p2align 4
    .globl atypes
atypes:
    .byte 2, 0, 1, 0, 0, 30, 6, 0       // coelho
    .float 0.03, 0.12
    .byte 6, 0, 2, 2, 0, 32, 8, 0       // cervo
    .float 0.03, 0.11
    .byte 5, 0, 2, 1, 0, 34, 6, 0       // cabra
    .float 0.025, 0.09
    .byte 6, 1, 1, 1, 8, 36, 9, 0       // lobo (voce correndo escapa)
    .float 0.03, 0.105
    .byte 14, 1, 4, 3, 15, 38, 6, 0     // urso
    .float 0.02, 0.085
    .byte 1, 0, 1, 0, 0, 40, 3, 0       // caranguejo
    .float 0.015, 0.04

// o que aparece em cada terreno (8 sorteios; 255 = nada)
spawntab:
    .byte 5, 5, 5, 5, 5, 255, 255, 255  // praia: caranguejo
    .byte 0, 0, 0, 0, 0, 255, 255, 255  // campo seco: coelho
    .byte 0, 0, 0, 0, 1, 1, 255, 255    // campo: coelho, cervo (lobo so de noite)
    .byte 1, 1, 1, 1, 1, 3, 4, 0        // floresta: cervo, lobo, urso
    .byte 2, 2, 2, 2, 0, 0, 255, 255    // colinas: cabra, coelho
    .byte 2, 2, 2, 2, 2, 4, 255, 255    // rocha: cabra, urso
    .byte 2, 2, 2, 4, 4, 255, 255, 255  // neve: cabra, urso

// dano do golpe pelo que esta na mao (item + 1; 0 = maos vazias)
handdmg:
    .byte 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
    .byte 1, 1, 1, 1, 1, 1, 1, 1

    .p2align 2
adirtab:
    .hword 64, 0,    59, 24,   45, 45,   24, 59
    .hword 0, 64,   -24, 59,  -45, 45,  -59, 24
    .hword -64, 0,  -59, -24, -45, -45, -24, -59
    .hword 0, -64,   24, -59,  45, -45,  59, -24

    .p2align 3
killmsg:
    .quad 0, 0, 0, m_wolf, m_bear, 0

    .p2align 4
    .globl animnames
animnames:
    .asciz "Coelho"
    .p2align 4
    .asciz "Cervo"
    .p2align 4
    .asciz "Cabra"
    .p2align 4
    .asciz "Lobo"
    .p2align 4
    .asciz "Urso"
    .p2align 4
    .asciz "Caranguejo"
    .p2align 4

m_wolf:     .asciz "Um lobo pegou voce"
m_bear:     .asciz "Um urso pegou voce"
m_noarrow:  .asciz "Sem flechas (fabrique: Tab)"
p_bite:     .asciz "Mordida!"
p_hit:      .asciz "Pow!"
s_killed:   .asciz "Abateu: "
s_avida:    .asciz " (vida "
s_danger:   .asciz " - perigoso!"

// ---- memoria ------------------------------------------------------------
GBSS animals, 1536                      // 48 animais x 32 bytes
GBSS arrows,  512                       // 16 flechas x 32 bytes
