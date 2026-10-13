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
//  - Nivel (RPG, fase 2): cada bicho tem um nivel. Vida e mordida crescem
//    20% por nivel acima do 1 (an_maxhp); a defesa tira 1 ponto de cada
//    golpe a cada 4 niveis (golpe minimo 1). O nivel vem da regiao: 1 +
//    1 a cada 16 celulas de distancia do comeco da partida, mais 0 a 2
//    de sorte (region_level).
//  - Lobo e urso sao os do designer (pedido 2.0), animados: parado,
//    andar, atacar (logo depois da mordida), golpe (ferido) e morrer. Ao
//    morrer viram um corpo (corpses) que cai e fica 6 s no chao. Os dois
//    tem sombra (pixshadow).
//  - Grupos (etapa 2.5): lobos vem em grupos de 2 a 4. As vezes o lider e
//    um campeao (+2 niveis, vida x1,5, anel azul) ou um chefe (+4 a +5
//    niveis, vida x2, anel dourado, nome proprio); o urso, sozinho, tambem
//    pode ser campeao ou chefe. A barra do topo usa a placa de cada um.
//  - Noite (etapa 2.6): lobo e urso que nascem de noite tem +2 niveis
//    (mais perigo e mais XP); a alcateia da noite tambem.
//  - Invasao de elite (etapa 2.7): a cada uns 3 minutos, se voce esta
//    numa area 5 ou mais niveis abaixo do seu, pode aparecer (1 em 3) um
//    grupo de 3 lobos do seu nivel, com um campeao, que vem atras de voce.
//    O aviso aparece na tela.
//  - XP (etapa 2.3): o nivel do bicho (metade nos pacificos), x2 o
//    campeao e x4 o chefe; acima do seu nivel +10% por nivel (ate +50%),
//    5-6 abaixo 50%, 7-9 abaixo 25%, 10 ou mais abaixo 10% (minimo 1).
// =====================================================================

#include "comum.h"
#include "pixel.h"

// animal (32 bytes): u, v, du, dv (float), tipo (255 = vaga), (livre),
// grupo, ferido (quadros), tempo ate mudar de rumo (u16), espera da
// mordida (u16), passos (u16), direcao, nivel, vida (u16)
.equ AN_U,     0
.equ AN_V,     4
.equ AN_DU,    8
.equ AN_DV,    12
.equ AN_TYPE,  16
.equ AN_HP,    28                      // vida (u16)
.equ AN_LVL,   27                      // nivel (1..255)
.equ AN_RANK,  30                      // 0 normal, 1 campeao, 2 chefe
.equ AN_HURT,  19
.equ AN_TIMER, 20
.equ AN_CD,    22
.equ AN_ANIM,  24
.equ AN_DIR,   26                      // direcao em que anda (lobo do designer)

// flecha (32 bytes): u, v, du, dv (float), vida (quadros), altura
.equ MAXCORPSE, 16                     // corpo no chao (16 bytes): u, v,
.equ CP_TYPE,  8                       // tipo, direcao, quadros desde
.equ CP_DIR,   9                       // que morreu (u16; 0 = vaga)
.equ CP_T,     10
.equ CP_LIFE,  360                     // 6 s
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
    LA      x9, corpses
    mov     w10, #MAXCORPSE
3:  strh    wzr, [x9, #CP_T]
    add     x9, x9, #16
    subs    w10, w10, #1
    b.ne    3b
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
    strh    w11, [x9, #AN_HP]
    mov     w11, #1
    strb    w11, [x9, #AN_LVL]
    strb    wzr, [x9, #AN_RANK]
    strb    wzr, [x9, #AN_HURT]
    strb    wzr, [x9, #18]              // grupo (desafio.S)
    strb    wzr, [x9, #AN_DIR]
    strh    wzr, [x9, #AN_TIMER]
    strh    wzr, [x9, #AN_CD]
    strh    wzr, [x9, #AN_ANIM]
    mov     w0, w10
    ret

// try_spawn: um animal novo fora da vista, de acordo com o terreno
// -> w0 = 1 se o lugar sorteado nao servia (agua, fora do mapa)
try_spawn:
    stp     x29, x30, [sp, #-64]!
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
    ldr     w9, [x28, #G_SEASON]        // inverno: quase nenhum bicho de caca
    cmp     w9, #3
    b.ne    2f
    cmp     w20, #A_WOLF
    b.eq    2f
    cmp     w20, #A_BEAR
    b.eq    2f
    bl      rng
    tst     w0, #3
    b.ne    9f
2:  mov     w0, w20
    fmov    s0, s8
    fmov    s1, s9
    bl      animal_spawn
    tbnz    w0, #31, 9f
    mov     w19, w0                     // nivel da regiao + 0 a 2
    fmov    s0, s8
    fmov    s1, s9
    bl      region_level
    bl      night_bonus                 // de noite, lobo e urso +2
    str     w0, [sp, #48]
    bl      rng
    and     w9, w0, #3
    cmp     w9, #3
    csel    w9, wzr, w9, eq
    ldr     w1, [sp, #48]
    add     w1, w1, w9
    mov     w0, w19
    bl      an_setlevel
    str     w19, [sp, #56]
    cmp     w20, #A_BEAR                // urso: 1/8 chefe, 1/8 campeao
    b.ne    5f
    bl      rng
    and     w9, w0, #7
    cmp     w9, #2
    b.hs    8f
    mov     w1, #2
    sub     w1, w1, w9
    mov     w0, w19
    bl      an_setrank
    b       8f
5:  cmp     w20, #A_WOLF                // lobo: grupo de 2 a 4
    b.ne    8f
    bl      rng
    and     w9, w0, #3
    cmp     w9, #3
    csel    w9, wzr, w9, eq
    add     w9, w9, #1
    str     w9, [sp, #52]
6:  ldr     w9, [sp, #52]
    cbz     w9, 7f
    sub     w9, w9, #1
    str     w9, [sp, #52]
    LA      x10, grpofs                 // em volta do primeiro
    add     x10, x10, x9, lsl #3
    ldr     s0, [x10]
    ldr     s1, [x10, #4]
    fadd    s0, s0, s8
    fadd    s1, s1, s9
    mov     w0, #A_WOLF
    bl      animal_spawn
    tbnz    w0, #31, 7f
    mov     w19, w0
    bl      rng
    and     w9, w0, #1
    ldr     w1, [sp, #48]
    add     w1, w1, w9
    mov     w0, w19
    bl      an_setlevel
    b       6b
7:  bl      rng                         // o lider: 1/12 chefe, 2/12 campeao
    mov     w9, #12
    udiv    w10, w0, w9
    msub    w9, w10, w9, w0
    cmp     w9, #3
    b.hs    8f
    mov     w1, #1
    cmp     w9, #0
    b.ne    71f
    mov     w1, #2
71: ldr     w0, [sp, #56]
    bl      an_setrank
8:  ldr     w0, [sp, #56]
    cmp     w20, #A_DEER                // cervo: vem em manada
    b.ne    9f
    tbnz    w0, #31, 9f
    bl      herd_spawn
9:  mov     w9, #0
91: mov     w0, w9
    ldp     d8, d9, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
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
    LA      x9, corpses                 // corpos: 6 s no chao
    mov     w10, #MAXCORPSE
2:  ldrh    w11, [x9, #CP_T]
    cbz     w11, 3f
    add     w11, w11, #1
    cmp     w11, #CP_LIFE
    csel    w11, wzr, w11, ge
    strh    w11, [x9, #CP_T]
3:  add     x9, x9, #16
    subs    w10, w10, #1
    b.ne    2b
    bl      elite_tick                  // invasao de elite (etapa 2.7)
    // de tempos em tempos tenta aparecer um animal
    ldr     w9, [x28, #G_SPAWNT]
    subs    w9, w9, #1
    b.gt    1f
    bl      rng
    and     w9, w0, #127
    add     w9, w9, #300                // a cada 5 - 7 s
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
4:  mov     x0, x20                     // ferido: furioso
    bl      an_maxhp                    // (usa so x0, x9, x10)
    mov     w10, w0
    ldrh    w9, [x20, #AN_HP]
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
    ldrb    w10, [x20, #AN_LVL]         // +20% por nivel
    add     w10, w10, #4
    mul     w9, w9, w10
    scvtf   s2, w9
    fmov    s3, #5.0
    fdiv    s2, s2, s3
    bl      hp_scale                    // em % da vida maxima (Vitalidade)
    ldr     w9, [x28, #(G_INV + 4 * IT_ARMOR)] // armadura: metade
    cbz     w9, 1f
    fmov    s3, #0.5
    fmul    s2, s2, s3
1:  fmov    s0, s2                      // o dano sobe em vermelho do heroi
    bl      F(hero_bitten)              // (c/numeros.c; devolve o mesmo s0)
    fmov    s2, s0
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
    bl      group_steer                 // alcateia e manada (desafio.S)
    cbnz    w0, au_move
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

// region_level(s0 = u, s1 = v) -> w0 = nivel da regiao: 1 + distancia
// do comeco da partida / 16 celulas   folha
    .globl region_level
region_level:
    ldr     s2, [x28, #G_HOMEU]
    ldr     s3, [x28, #G_HOMEV]
    fsub    s0, s0, s2
    fsub    s1, s1, s3
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    fsqrt   s0, s0
    fmov    s1, #16.0
    fdiv    s0, s0, s1
    fcvtzs  w0, s0
    add     w0, w0, #1
    cmp     w0, #250
    mov     w9, #250
    csel    w0, w9, w0, gt
    ret

// elite_tick: de tempos em tempos, numa area baixa, uma invasao de elite
elite_tick:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #G_ELITET]
    subs    w9, w9, #1
    b.gt    8f
    bl      rng                         // proxima chance: 3 a 4 min
    and     w9, w0, #4095
    mov     w10, #10800
    add     w9, w9, w10
    str     w9, [x28, #G_ELITET]
    ldr     w9, [x28, #G_NOSPAWN]
    cbnz    w9, 9f
    ldr     w9, [x28, #G_INSHELTER]
    cbnz    w9, 9f
    bl      rng                         // 1 em 3
    mov     w9, #3
    udiv    w10, w0, w9
    msub    w9, w10, w9, w0
    cbnz    w9, 9f
    ldr     s0, [x28, #G_PU]            // a area e 5+ niveis abaixo de voce?
    ldr     s1, [x28, #G_PV]
    bl      region_level
    add     w0, w0, #5
    ldr     w9, [x28, #G_LEVEL]
    cmp     w9, w0
    b.lt    9f
    bl      elite_spawn
    b       9f
8:  str     w9, [x28, #G_ELITET]
9:  ldp     x29, x30, [sp], #16
    ret

// elite_spawn -> w0 = quantos lobos vieram: 3 lobos do seu nivel (o lider
// campeao) a 18 celulas, que vem atras de voce (grupo 1, como a alcateia)
    .globl elite_spawn
elite_spawn:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    mov     w21, #8                     // ate 8 tentativas de lugar
1:  bl      rng
    and     w9, w0, #15
    LA      x10, adirtab
    add     x10, x10, x9, lsl #2
    ldrsh   w11, [x10]
    scvtf   s0, w11
    ldrsh   w11, [x10, #2]
    scvtf   s1, w11
    mov     w9, #18                     // 18/64 x 64 = 18 celulas
    scvtf   s2, w9
    LA      x10, aconst
    ldr     s3, [x10]
    fmul    s2, s2, s3
    ldr     s3, [x28, #G_PU]
    fmadd   s8, s0, s2, s3
    ldr     s3, [x28, #G_PV]
    fmadd   s9, s1, s2, s3
    mov     w9, #4
    scvtf   s2, w9
    mov     w9, #507
    scvtf   s3, w9
    fcmp    s8, s2
    b.lt    2f
    fcmp    s8, s3
    b.gt    2f
    fcmp    s9, s2
    b.lt    2f
    fcmp    s9, s3
    b.gt    2f
    fmov    s0, s8
    fmov    s1, s9
    bl      terrain_class
    tbz     w0, #31, 3f                 // terra: serve
2:  subs    w21, w21, #1
    b.ne    1b
    mov     w0, #0
    b       9f
3:  mov     w19, #0                     // quantos vieram
    mov     w20, #0
4:  cmp     w20, #3
    b.ge    6f
    LA      x10, grpofs
    add     x10, x10, x20, lsl #3
    ldr     s0, [x10]
    ldr     s1, [x10, #4]
    fadd    s0, s0, s8
    fadd    s1, s1, s9
    mov     w0, #A_WOLF
    bl      animal_spawn
    tbnz    w0, #31, 5f
    mov     w22, w0
    LA      x9, animals
    add     x9, x9, x22, lsl #5
    mov     w10, #1                     // grupo: vem atras de voce
    strb    w10, [x9, #18]
    ldr     w1, [x28, #G_LEVEL]
    mov     w0, w22
    bl      an_setlevel
    cbnz    w19, 41f                    // o primeiro: campeao (+2)
    mov     w0, w22
    mov     w1, #1
    bl      an_setrank
41: add     w19, w19, #1
5:  add     w20, w20, #1
    b       4b
6:  cbz     w19, 7f
    LA      x0, msgbuf                  // "Invasao de elite! Lobos nivel 12..."
    LA      x1, s_elite1
    bl      strcat_cur
    ldr     w1, [x28, #G_LEVEL]
    bl      numcat
    LA      x1, s_elite2
    bl      strcat_cur
    LA      x0, msgbuf
    bl      set_msg
7:  mov     w0, w19
9:  ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// night_bonus(w0 = nivel, w20 = tipo) -> w0: +2 de noite se perigoso
// folha
night_bonus:
    ldr     w9, [x28, #G_NIGHTK]
    cmp     w9, #128
    b.lt    1f
    cmp     w20, #A_WOLF
    b.eq    2f
    cmp     w20, #A_BEAR
    b.ne    1f
2:  add     w0, w0, #2
1:  ret

// an_spawnlevel(w0 = animal): nivel da regiao + 0 a 2 de sorte (+2 de
// noite se perigoso), para quem nasce fora do try_spawn (alcateia)
    .globl an_spawnlevel
an_spawnlevel:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, w0
    LA      x9, animals
    add     x9, x9, x19, lsl #5
    ldrb    w20, [x9, #AN_TYPE]
    ldr     s0, [x9, #AN_U]
    ldr     s1, [x9, #AN_V]
    bl      region_level
    bl      night_bonus
    mov     w20, w0
    bl      rng
    and     w9, w0, #3
    cmp     w9, #3
    csel    w9, wzr, w9, eq
    add     w1, w20, w9
    mov     w0, w19
    bl      an_setlevel
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// an_xp: em C (c/inimigos.c)

// an_maxhp(x0 = animal) -> w0 = vida maxima: base x (4 + nivel) / 5   folha
    .globl an_maxhp
an_maxhp:
    ldrb    w9, [x0, #AN_TYPE]
    LA      x10, atypes
    add     x10, x10, x9, lsl #4
    ldrb    w9, [x10, #AT_HP]
    ldrb    w10, [x0, #AN_LVL]
    add     w10, w10, #4
    mul     w9, w9, w10
    ldrb    w10, [x0, #AN_RANK]         // campeao x1,5, chefe x2
    cmp     w10, #2
    b.ls    1f
    mov     w10, #0
1:  add     w10, w10, #2
    mul     w9, w9, w10
    mov     w10, #10
    udiv    w0, w9, w10
    ret

// an_setlevel(w0 = animal, w1 = nivel): muda o nivel e enche a vida
    .globl an_setlevel
an_setlevel:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x9, animals
    add     x0, x9, x0, lsl #5
    cmp     w1, #1
    mov     w9, #1
    csel    w1, w9, w1, lt
    cmp     w1, #255
    mov     w9, #255
    csel    w1, w9, w1, gt
    strb    w1, [x0, #AN_LVL]
    mov     x11, x0                     // an_maxhp nao mexe no x11
    bl      an_maxhp
    strh    w0, [x11, #AN_HP]
    ldp     x29, x30, [sp], #16
    ret

// an_setrank(w0 = animal, w1 = 1 campeao / 2 chefe): sobe o nivel (+2,
// ou +4 a +5 o chefe) e enche a vida
    .globl an_setrank
an_setrank:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, w0
    mov     w20, w1
    LA      x9, animals
    add     x9, x9, x19, lsl #5
    strb    w20, [x9, #AN_RANK]
    ldrb    w1, [x9, #AN_LVL]
    add     w1, w1, #2
    cmp     w20, #2
    b.ne    1f
    bl      rng
    and     w9, w0, #1
    LA      x10, animals
    add     x10, x10, x19, lsl #5
    ldrb    w1, [x10, #AN_LVL]
    add     w1, w1, #4
    add     w1, w1, w9
1:  mov     w0, w19
    bl      an_setlevel
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// animals_fix: save de antes do nivel: nivel 1, vida do byte antigo
    .globl animals_fix
animals_fix:
    LA      x9, animals
    mov     w10, #MAXANIM
1:  ldrb    w11, [x9, #AN_TYPE]
    cmp     w11, #255
    b.eq    2f
    ldrb    w11, [x9, #AN_RANK]
    cmp     w11, #2
    b.ls    4f
    strb    wzr, [x9, #AN_RANK]
4:  ldrb    w11, [x9, #AN_LVL]
    cbnz    w11, 2f
    strb    wzr, [x9, #AN_RANK]
    mov     w11, #1
    strb    w11, [x9, #AN_LVL]
    ldrb    w11, [x9, #17]
    strh    w11, [x9, #AN_HP]
2:  add     x9, x9, #32
    subs    w10, w10, #1
    b.ne    1b
    ret

// an_selftest(x0 = cursor) -> x0: " | lobo nv 1 vida=6 nv 6 vida=12,
// golpe de 6 tira 5" (um lobo longe, que some depois)
    .globl an_selftest
an_selftest:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    mov     x21, x0
    mov     w0, #A_WOLF
    mov     w9, #10
    scvtf   s0, w9
    scvtf   s1, w9
    bl      animal_spawn
    mov     w19, w0
    tbnz    w19, #31, 9f
    LA      x20, animals
    add     x20, x20, x19, lsl #5
    mov     x0, x21
    LA      x1, s_ant1
    bl      strcat_cur
    ldrh    w1, [x20, #AN_HP]
    bl      numcat
    mov     x21, x0
    mov     w0, w19
    mov     w1, #6
    bl      an_setlevel
    mov     x0, x21
    LA      x1, s_ant2
    bl      strcat_cur
    ldrh    w1, [x20, #AN_HP]
    bl      numcat
    mov     x21, x0
    ldrh    w9, [x20, #AN_HP]
    str     w9, [sp, #40]
    mov     w0, w19
    mov     w1, #6
    bl      animal_hit
    mov     x0, x21
    LA      x1, s_ant3
    bl      strcat_cur
    ldr     w9, [sp, #40]
    ldrh    w10, [x20, #AN_HP]
    sub     w1, w9, w10
    bl      numcat
    mov     x21, x0
    mov     w9, #255                    // some
    strb    w9, [x20, #AN_TYPE]
    mov     x0, x21                     // regiao: no comeco, a 64 e a 200
    LA      x1, s_ant4
    bl      strcat_cur
    mov     x21, x0
    mov     w19, #0
1:  ldr     s0, [x28, #G_HOMEU]
    ldr     s1, [x28, #G_HOMEV]
    LA      x9, regdist
    ldr     w9, [x9, x19, lsl #2]
    scvtf   s2, w9
    fadd    s0, s0, s2
    bl      region_level
    mov     w1, w0
    mov     x0, x21
    bl      numcat
    cmp     w19, #2
    b.eq    2f
    mov     w9, #47
    strb    w9, [x0], #1
    strb    wzr, [x0]
2:  mov     x21, x0
    add     w19, w19, #1
    cmp     w19, #3
    b.lt    1b
    mov     x0, x21                     // XP: voce no nivel 1 e no 10
    LA      x1, s_ant5
    bl      strcat_cur
    mov     x21, x0
    ldr     w9, [x28, #G_LEVEL]
    str     w9, [sp, #40]
    mov     w9, #1
    str     w9, [x28, #G_LEVEL]
    mov     w19, #0
3:  LA      x9, xptests                 // nivel, posto, perigoso, seu nivel
    add     x9, x9, x19, lsl #2
    ldrb    w0, [x9]
    ldrb    w1, [x9, #1]
    ldrb    w2, [x9, #2]
    ldrb    w10, [x9, #3]
    str     w10, [x28, #G_LEVEL]
    bl      F(an_xp)
    mov     w1, w0
    mov     x0, x21
    bl      numcat
    mov     w9, #47
    strb    w9, [x0], #1
    strb    wzr, [x0]
    mov     x21, x0
    add     w19, w19, #1
    cmp     w19, #6
    b.lt    3b
    sub     x21, x21, #1
    strb    wzr, [x21]
    ldr     w9, [sp, #40]
    str     w9, [x28, #G_LEVEL]
    bl      elite_spawn                 // invasao: quantos, nivel, campeao
    mov     w19, w0
    mov     x0, x21
    LA      x1, s_ant6
    bl      strcat_cur
    mov     w1, w19
    bl      numcat
    mov     x21, x0
    LA      x9, animals                 // conta e some com eles
    mov     w10, #0
    mov     w11, #0                     // do seu nivel
    mov     w12, #0                     // campeoes
    mov     w13, #MAXANIM
    ldr     w14, [x28, #G_LEVEL]
1:  ldrb    w15, [x9, #AN_TYPE]
    cmp     w15, #A_WOLF
    b.ne    2f
    ldrb    w15, [x9, #18]
    cmp     w15, #1
    b.ne    2f
    ldrb    w15, [x9, #AN_RANK]
    add     w12, w12, w15
    ldrb    w15, [x9, #AN_LVL]
    cmp     w15, w14
    cinc    w11, w11, ge
    mov     w15, #255
    strb    w15, [x9, #AN_TYPE]
2:  add     x9, x9, #32
    subs    w13, w13, #1
    b.ne    1b
    mov     w19, w11                    // (numcat usa x9-x13)
    mov     w20, w12
    mov     x0, x21
    LA      x1, s_ant7
    bl      strcat_cur
    mov     w1, w19
    bl      numcat
    LA      x1, s_ant8
    bl      strcat_cur
    mov     w1, w20
    bl      numcat
    mov     x21, x0
9:  mov     x0, x21
    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
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
    mov     x0, x19                     // a manada foge junto
    bl      herd_alarm
    ldrb    w9, [x19, #AN_LVL]      // defesa: -1 a cada 4 niveis, min. 1
    sub     w9, w9, #1
    lsr     w9, w9, #2
    subs    w1, w1, w9
    mov     w9, #1
    csel    w1, w9, w1, lt
    cmp     w1, #1
    csel    w1, w9, w1, lt
    ldrh    w9, [x19, #AN_HP]
    subs    w9, w9, w1
    csel    w9, wzr, w9, lt
    strh    w9, [x19, #AN_HP]
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
1:  cmp     w20, #A_WOLF                // lobo e urso: o corpo cai
    b.eq    2f
    cmp     w20, #A_BEAR
    b.ne    3f
2:  LA      x9, corpses
    mov     w10, #MAXCORPSE
21: ldrh    w11, [x9, #CP_T]
    cbz     w11, 22f
    add     x9, x9, #16
    subs    w10, w10, #1
    b.ne    21b
    b       3f
22: ldr     w11, [x19, #AN_U]
    str     w11, [x9]
    ldr     w11, [x19, #AN_V]
    str     w11, [x9, #4]
    strb    w20, [x9, #CP_TYPE]
    ldrb    w11, [x19, #AN_DIR]
    strb    w11, [x9, #CP_DIR]
    mov     w11, #1
    strh    w11, [x9, #CP_T]
3:  mov     w9, #255
    strb    w9, [x19, #AN_TYPE]
    LA      x0, msgbuf                  // "Abateu: Cervo"
    LA      x1, s_killed
    bl      strcat_cur
    LA      x1, animnames
    add     x1, x1, x20, lsl #4
    bl      strcat_cur
    LA      x0, msgbuf
    bl      set_msg
    ldrb    w0, [x19, #AN_LVL]          // XP pelo nivel (etapa 2.3)
    ldrb    w1, [x19, #AN_RANK]
    LA      x9, atypes
    add     x9, x9, x20, lsl #4
    ldrb    w2, [x9, #AT_HOST]
    bl      F(an_xp)
    bl      xp_gain
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
    LA      x1, s_anv                   // " Nv 3"
    bl      strcat_cur
    ldrb    w1, [x19, #AN_LVL]
    bl      numcat
    LA      x1, s_avida
    bl      strcat_cur
    ldrh    w1, [x19, #AN_HP]
    bl      numcat
    mov     w9, #47
    strb    w9, [x0], #1
    mov     x22, x0
    mov     x0, x19
    bl      an_maxhp
    mov     w1, w0
    mov     x0, x22
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

// an_bar(w0 = animal): a barra do topo com "Lobo - Nv 7" e a vida
    .globl an_bar
an_bar:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    LA      x19, animals
    add     x19, x19, x0, lsl #5
    ldrb    w9, [x19, #AN_TYPE]
    cmp     w9, #255
    b.eq    9f
    ldrb    w10, [x19, #AN_RANK]
    LA      x0, barbuf
    LA      x1, animnames
    add     x1, x1, x9, lsl #4
    cmp     w10, #2                     // chefe: nome proprio
    b.ne    1f
    LA      x1, bossnames
    add     x1, x1, x9, lsl #4
1:  bl      strcat_cur
    ldrb    w10, [x19, #AN_RANK]
    cmp     w10, #1
    b.ne    2f
    LA      x1, s_champ
    bl      strcat_cur
2:  LA      x1, s_barnv
    bl      strcat_cur
    ldrb    w1, [x19, #AN_LVL]
    bl      numcat
    mov     x0, x19
    bl      an_maxhp
    mov     w2, w0
    ldrh    w1, [x19, #AN_HP]
    LA      x0, barbuf
    ldrb    w3, [x19, #AN_RANK]         // placa normal, campeao ou chefe
    cmp     w3, #2
    mov     w9, #0
    csel    w3, w9, w3, hi
    bl      enemy_bar
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
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
    cmp     w9, #(IT_AXE + 1)           // machado de ferro: 4
    b.ne    1f
    ldr     w10, [x28, #(G_INV + 4 * IT_IAXE)]
    cbz     w10, 1f
    mov     w1, #4
1:
    mov     w0, w19                     // acerto e dano pelos atributos
    mov     w2, #0                      // (golpe; c/combate.c)
    bl      F(player_hit)
                                        // (o numero sobe: c/numeros.c)
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
    ldr     w1, [x19, #24]              // dano da flecha (c/arco.c; 0 = 4)
    cbnz    w1, 21f
    mov     w1, #4
21: mov     w2, #1                      // (com a Destreza e o acerto:
                                        // c/combate.c)
    bl      F(player_hit)
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
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    mov     w23, w0
    LA      x19, animals
    mov     w20, #0
1:  ldrb    w21, [x19, #AN_TYPE]
    cmp     w21, #255
    b.eq    8f
    ldrb    w9, [x19, #AN_HURT]
    cmp     w21, #A_WOLF                // lobo e urso: ferido = animacao
    b.eq    11f
    cmp     w21, #A_BEAR
    b.eq    11f
    tbnz    w9, #1, 8f                  // os outros piscam
11: ldr     s0, [x19, #AN_U]
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
    cmp     w21, #A_WOLF                // lobo e urso: os do designer
    b.eq    51f
    cmp     w21, #A_BEAR
    b.ne    5f
51: mov     w24, w1
    mov     w25, w2
    mov     w26, w4
    ldr     s0, [x19, #AN_DU]           // virado para onde anda
    ldr     s1, [x19, #AN_DV]
    ldrb    w0, [x19, #AN_DIR]
    bl      char_dir                    // (heroi.S; so usa w0, w9, s0-s7)
    strb    w0, [x19, #AN_DIR]
    mov     w22, w0
    ldrb    w9, [x19, #AN_RANK]         // campeao / chefe: anel no chao
    cbz     w9, 55f
    cmp     w9, #2
    b.hi    55f
    sub     w9, w9, #1
    lsl     w9, w9, #3
    cmp     w21, #A_BEAR
    b.ne    54f
    add     w9, w9, #4
54: ldr     w10, [x28, #G_FRAME]
    lsr     w10, w10, #3
    and     w10, w10, #3
    add     w9, w9, w10
    LA      x10, pixmark
    ldr     x0, [x10, x9, lsl #3]
    mov     w1, w24
    mov     w2, w25
    ldr     w3, [x28, #G_Z256]
    lsr     w3, w3, #10
    cmp     w3, #1
    mov     w9, #1
    csel    w3, w9, w3, lt
    mov     w4, w26
    mov     w5, #0
    bl      blit
55: mov     w0, w21
    mov     w1, w24
    mov     w2, w25
    mov     w3, w26
    bl      an_shadow
    ldrb    w9, [x19, #AN_HURT]         // ferido: golpe (2 quadros)
    cbz     w9, 52f
    mov     w10, #16
    subs    w9, w10, w9
    csel    w9, wzr, w9, lt
    lsr     w9, w9, #3
    cmp     w9, #1
    mov     w10, #1
    csel    w9, w10, w9, gt
    add     w9, w9, #EN_GOLPE
    b       56f
52: ldrh    w9, [x19, #AN_CD]           // logo depois da mordida: atacar
    cmp     w9, #30
    b.le    53f
    mov     w10, #60
    subs    w9, w10, w9
    csel    w9, wzr, w9, lt
    mov     w10, #5
    udiv    w9, w9, w10
    cmp     w9, #5
    mov     w10, #5
    csel    w9, w10, w9, gt
    add     w9, w9, #EN_ATACAR
    b       56f
53: ldr     s0, [x19, #AN_DU]           // andando ou parado
    ldr     s1, [x19, #AN_DV]
    fabs    s0, s0
    fabs    s1, s1
    fadd    s0, s0, s1
    ldr     s1, an_still
    ldr     w9, [x28, #G_FRAME]
    fcmp    s0, s1
    b.le    54f
    mov     w10, #6                     // 10 quadros por segundo
    udiv    w9, w9, w10
    and     w9, w9, #7
    add     w9, w9, #EN_ANDAR
    b       56f
54: mov     w10, #10                    // 6 por segundo
    udiv    w9, w9, w10
    and     w9, w9, #3
    add     w9, w9, #EN_PARADO
56: mov     w10, #EN_NF
    madd    w9, w22, w10, w9
    mov     w0, w21
    mov     w1, w24
    mov     w2, w25
    mov     w3, w26
    bl      en_blit
    b       8f
5:  LA      x9, atypes
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
    // corpos: caem (morrer, 6 quadros) e ficam no chao
    LA      x19, corpses
    mov     w20, #0
61: ldrh    w9, [x19, #CP_T]
    cbz     w9, 68f
    ldr     s0, [x19]
    ldr     s1, [x19, #4]
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    csel    w0, w9, w0, lt
    ldr     s0, [x19]
    ldr     s1, [x19, #4]
    bl      proj
    add     w26, w2, #20
    mov     w24, w0
    mov     w25, w1
    ldrb    w21, [x19, #CP_TYPE]
    mov     w0, w21
    mov     w1, w24
    mov     w2, w25
    mov     w3, w26
    bl      an_shadow
    ldrh    w9, [x19, #CP_T]
    mov     w10, #6
    udiv    w9, w9, w10
    cmp     w9, #5
    mov     w10, #5
    csel    w9, w10, w9, gt
    add     w9, w9, #EN_MORRER
    ldrb    w10, [x19, #CP_DIR]
    mov     w11, #EN_NF
    madd    w9, w10, w11, w9
    mov     w0, w21
    mov     w1, w24
    mov     w2, w25
    mov     w3, w26
    bl      en_blit
68: add     x19, x19, #16
    add     w20, w20, #1
    cmp     w20, #MAXCORPSE
    b.lt    61b
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret
an_still: .float 0.001

// an_shadow(w0 = tipo, w1 x, w2 y, w3 profundidade): sombra no chao
an_shadow:
    LA      x9, pixshadow
    cmp     w0, #A_BEAR
    mov     w10, #1
    mov     w11, #2
    csel    w10, w11, w10, eq
    ldr     x0, [x9, x10, lsl #3]
    mov     w4, w3
    ldr     w3, [x28, #G_Z256]
    lsr     w3, w3, #10
    cmp     w3, #1
    mov     w9, #1
    csel    w3, w9, w3, lt
    mov     w5, #0
    b       blit

// en_blit(w0 = tipo, w1 x, w2 y, w3 profundidade, w9 = quadro): o lobo
// ou o urso do designer
en_blit:
    LA      x10, pixwolf
    cmp     w0, #A_BEAR
    b.ne    1f
    LA      x10, pixbear
1:  ldr     x0, [x10, x9, lsl #3]
    mov     w4, w3
    ldr     w3, [x28, #G_Z256]
    lsr     w3, w3, #10
    cmp     w3, #1
    mov     w9, #1
    csel    w3, w9, w3, lt
    mov     w5, #0
    b       blit

// an_first(w0 = tipo) -> w0 = o primeiro vivo desse tipo (-1)   folha
    .globl an_first
an_first:
    LA      x9, animals
    mov     w10, #0
1:  ldrb    w11, [x9, #AN_TYPE]
    cmp     w11, w0
    b.eq    2f
    add     x9, x9, #32
    add     w10, w10, #1
    cmp     w10, #MAXANIM
    b.lt    1b
    mov     w10, #-1
2:  mov     w0, w10
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
    .byte 5, 5, 255, 255, 255, 255, 255, 255 // praia: caranguejo
    .byte 0, 0, 255, 255, 255, 255, 255, 255 // campo seco: coelho
    .byte 0, 0, 1, 255, 255, 255, 255, 255   // campo: coelho, cervo (lobo so de noite)
    .byte 1, 1, 3, 4, 0, 255, 255, 255       // floresta: cervos, lobo, urso
    .byte 2, 2, 0, 255, 255, 255, 255, 255   // colinas: cabra, coelho
    .byte 2, 2, 4, 255, 255, 255, 255, 255   // rocha: cabra, urso
    .byte 2, 4, 4, 255, 255, 255, 255, 255   // neve: cabra, urso

// dano do golpe pelo que esta na mao (item + 1; 0 = maos vazias)
handdmg:
    .byte 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
    .byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 1
    .byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

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
    .globl m_noarrow
m_noarrow:  .asciz "Sem flechas (fabrique: Tab)"
p_bite:     .asciz "Mordida!"
p_hit:      .asciz "Pow!"
s_killed:   .asciz "Abateu: "
s_ant1:     .asciz " | lobo nv 1 vida="
s_ant2:     .asciz " nv 6 vida="
s_ant3:     .asciz " golpe de 6 tira "
s_ant4:     .asciz " | nivel da regiao (0/64/200 celulas)="
    .p2align 2
regdist:    .word 0, 64, 200
s_barnv:    .asciz " - Nv "
s_champ:    .asciz " campeao"
    .p2align 4
bossnames:  .asciz "Lebre Branca"
    .space 3
    .asciz "Galhada Antiga"
    .space 1
    .asciz "Chifre Torto"
    .space 3
    .asciz "Presa Cinzenta"
    .space 1
    .asciz "Garra Velha"
    .space 4
    .asciz "Pinca de Ferro"
    .space 1
    .p2align 2
grpofs:     .float 1.2, 0.4, -0.5, 1.1, 0.6, -1.2
s_ant5:     .asciz " | XP (lobo 1, lobo 6, campeao 3, chefe 8, cervo 2 / voce 1; lobo 3 / voce 10)="
xptests:    .byte 1, 0, 1, 1,   6, 0, 1, 1,   3, 1, 1, 1,   8, 2, 1, 1
            .byte 2, 0, 0, 1,   3, 0, 1, 10
s_ant6:     .asciz " | invasao de elite: lobos="
s_ant7:     .asciz " do seu nivel ou mais="
s_ant8:     .asciz " campeoes="
s_elite1:   .asciz "Invasao de elite! Lobos de nivel "
s_elite2:   .asciz " vem atras de voce"
s_anv:      .asciz " Nv "
s_avida:    .asciz " (vida "
s_danger:   .asciz " - perigoso!"

// ---- memoria ------------------------------------------------------------
GBSS animals, 1536                      // 48 animais x 32 bytes
GBSS arrows,  512                       // 16 flechas x 32 bytes
GBSS corpses, 256                       // 16 corpos x 16 bytes
GBSS barbuf, 48
