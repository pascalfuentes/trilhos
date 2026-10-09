// =====================================================================
//  sobrevivencia.S - personagem, coleta, fome, frio, fogueiras e neblina
//
//  - WASD anda (na direcao da tela); a camera segue o personagem.
//  - Segurar o botao esquerdo sobre uma arvore, pedra ou arbusto perto
//    do personagem vai coletando: madeira, pedra e frutas.
//  - E come uma fruta. F monta uma fogueira (5 madeiras + 3 pedras).
//    Botao direito numa fogueira coloca mais lenha.
//  - Fome cai com o tempo. De noite esfria; perto do fogo esquenta.
//    Sem comida ou sem calor, a vida acaba.
//  - A noite e feita escurecendo o framebuffer e somando a luz das
//    fogueiras (e de uma lanterna fraca do personagem).
//  - Neblina de guerra: 360 raios saem do personagem (e das fogueiras);
//    arvores tapam a visao. O raio diminui de noite. O que nunca foi
//    visto fica preto; o que ja foi visto aparece como foi lembrado.
//  - Shift corre (gasta stamina, como nadar). 5 skills sobem com o uso
//    (natacao, corrida, lenhador, mineracao, forca) e caem devagar sem
//    treino. A mochila tem limite de peso: acima dele, anda devagar.
//    I abre a mochila, C abre o personagem (ou os botoes no canto).
//  - Um dia dura 12 minutos. O clima (clima.S) muda frio, fome, visao,
//    fogo, velocidade, stamina e o nivel da agua.
//  - A fome cheia segura 4 min antes de cair, e a vida so sobe com ela
//    cheia. A stamina maxima cresce com corrida e natacao.
//  - Tab abre a janela de fabricar: machado, picareta, tocha, fogueira,
//    bau, abrigo, frutas assadas e cesto. Construcoes sao colocadas com
//    um clique no mapa; ferramentas gastam.
//  - "Na mao" (teclas 1-3): machado, picareta ou arco; tecla 4 poe a
//    tocha na outra mao (acende sozinha quando escurece).
// =====================================================================

#include "comum.h"

// cor de desenho da interface (chama setcolor; usa x0-x3)
.macro RGBA r, g, b, a
    mov     w0, #\r
    mov     w1, #\g
    mov     w2, #\b
    mov     w3, #\a
    bl      setcolor
.endm

    .text
    .p2align 2

// =====================================================================
//  Auxiliares
// =====================================================================

// set_msg(x0 = texto): mensagem no meio da tela por 3 segundos
    .globl set_msg
set_msg:
    str     x0, [x28, #G_MSG]
    mov     w9, #180
    str     w9, [x28, #G_MSGT]
    ret

// popup(x0 = texto): texto curto que sobe da cabeca do personagem
    .globl popup
popup:
    str     x0, [x28, #G_POPMSG]
    mov     w9, #45
    str     w9, [x28, #G_POPT]
    ret

// proj(s0 = u, s1 = v em celulas, w0 = elevacao) -> w0 = x, w1 = y, w2 = prof.
// folha: usa x9-x12, x16, s0-s3
    .globl proj
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

// elev_at(s0 = u, s1 = v) -> w0 elevacao (fora do mapa: -2000)
// usa x0-x7, x16, s2, s3
    .globl elev_at
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

// sprite_scale() -> w0 = escala dos sprites (1 ou mais)
sprite_scale:
    ldr     w0, [x28, #G_Z256]
    lsr     w0, w0, #8
    cmp     w0, #1
    mov     w9, #1
    csel    w0, w9, w0, lt
    ret

// follow_camera: centraliza a camera no personagem
follow_camera:
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    fsub    s2, s0, s1
    fadd    s3, s0, s1
    FC      s4, F_64
    fmul    s2, s2, s4
    fcvtzs  w9, s2
    str     w9, [x28, #G_CX]
    fmul    s3, s3, s4
    fcvtzs  w9, s3
    asr     w9, w9, #1
    ldr     w10, [x28, #G_PE]
    sub     w9, w9, w10
    str     w9, [x28, #G_CY]
    ret

// obj_dist2(w0 = objeto) -> s0 = distancia^2 ate o personagem (celulas)
// folha: usa x9-x10, x16, s0-s3
obj_dist2:
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrh    w10, [x9]
    scvtf   s0, w10
    ldrh    w10, [x9, #2]
    scvtf   s1, w10
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    ldr     s2, [x28, #G_PU]
    ldr     s3, [x28, #G_PV]
    fsub    s0, s0, s2
    fsub    s1, s1, s3
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    ret

// fire_dist2(w0 = fogueira) -> s0 = distancia^2 ate o personagem
fire_dist2:
    LA      x9, fires
    add     x9, x9, x0, lsl #4
    ldr     s0, [x9]
    ldr     s1, [x9, #4]
    ldr     s2, [x28, #G_PU]
    ldr     s3, [x28, #G_PV]
    fsub    s0, s0, s2
    fsub    s1, s1, s3
    fmul    s0, s0, s0
    fmadd   s0, s1, s1, s0
    ret

// =====================================================================
//  Geracao dos recursos (chamada por generate_map, depois das arvores)
//  pedras: muitas nas montanhas, poucas no campo seco
//  arbustos com frutas: no campo umido e na beira das florestas
// =====================================================================
    .globl gen_resources
gen_resources:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
    ldr     w20, [x28, #G_SEED]
    add     w20, w20, #77
    mov     w19, #513
gr_loop:
    and     w22, w19, #511
    lsr     w23, w19, #9
    cmp     w23, #510
    b.ge    gr_done
    cbz     w22, gr_next
    cmp     w22, #510
    b.ge    gr_next
    LA      x9, elev
    ldrsh   w25, [x9, w19, uxtw #1]
    cmp     w25, #(E_SAND + 20)
    b.lt    gr_next                     // agua e praia
    LA      x9, moist
    ldrb    w24, [x9, w19, uxtw]
    mov     w0, w22
    mov     w1, w23
    mov     w2, w20
    bl      hash3
    mov     w21, w0
    // chance de pedra (em 1024)
    mov     w9, #2
    cmp     w24, #110
    b.hs    1f
    mov     w9, #6                      // campo seco
1:  cmp     w25, #E_HILL
    b.lt    2f
    mov     w9, #70                     // colinas
    mov     w10, #E_ROCK
    cmp     w25, w10
    b.lt    2f
    mov     w9, #130                    // montanha
2:  and     w10, w21, #1023
    cmp     w10, w9
    b.hs    gr_bush
    lsr     w0, w21, #10
    and     w0, w0, #63
    lsr     w1, w21, #16
    and     w1, w1, #63
    mov     w2, #O_ROCK
    mov     w3, #5                      // 5 pedras
    b       gr_place
gr_bush:
    cmp     w25, #E_HILL
    b.ge    gr_next
    mov     w9, #3
    cmp     w24, #105
    b.lo    3f
    mov     w9, #14                     // campo umido
    cmp     w24, #150
    b.lo    3f
    mov     w9, #6                      // dentro da floresta
3:  lsr     w10, w21, #22
    cmp     w10, w9
    b.hs    gr_next
    lsr     w0, w21, #4
    and     w0, w0, #63
    lsr     w1, w21, #12
    and     w1, w1, #63
    mov     w2, #O_BUSH
    mov     w3, #3                      // 3 frutas
gr_place:
    lsl     w9, w22, #6
    add     w0, w0, w9
    lsl     w9, w23, #6
    add     w1, w1, w9
    stp     w0, w1, [sp, #72]
    stp     w2, w3, [sp, #-16]!
    bl      sample_elev
    mov     w2, w0
    ldp     w3, w4, [sp], #16
    ldp     w0, w1, [sp, #72]
    bl      add_obj
gr_next:
    add     w19, w19, #1
    b       gr_loop
gr_done:
    bl      build_treegrid
    ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// =====================================================================
//  Inicio da partida
// =====================================================================
    .globl surv_reset
surv_reset:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     d8, d9, [sp, #32]
    stp     d10, d11, [sp, #48]
    FC      s0, F_HUNDRED
    str     s0, [x28, #G_HP]
    str     s0, [x28, #G_FOOD]
    str     s0, [x28, #G_WARM]
    str     s0, [x28, #G_STAMINA]
    str     wzr, [x28, #G_WATER]
    str     wzr, [x28, #G_SHARK]
    str     xzr, [x28, #G_DEATHMSG]
    mov     w9, #3600                   // 08:00
    str     w9, [x28, #G_TIME]
    mov     w9, #1
    str     w9, [x28, #G_DAY]
    str     wzr, [x28, #G_LMB]
    mov     w9, #-1
    str     w9, [x28, #G_MINEOBJ]
    str     w9, [x28, #G_HOVOBJ]
    str     w9, [x28, #G_HOVFIRE]
    str     wzr, [x28, #G_MINEPROG]
    str     wzr, [x28, #G_NFIRE]
    str     wzr, [x28, #G_DEAD]
    str     wzr, [x28, #G_PAUSE]
    str     wzr, [x28, #G_POPT]
    str     wzr, [x28, #G_WARNED]
    str     wzr, [x28, #G_PMOVING]
    str     wzr, [x28, #G_RUN]
    str     wzr, [x28, #G_EXHAUST]
    str     wzr, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CHAROPEN]
    str     wzr, [x28, #G_TESTKEYS]
    add     x9, x28, #G_SKILL           // skills, tempo sem treino e niveis
    stp     xzr, xzr, [x9]
    stp     xzr, xzr, [x9, #16]
    stp     xzr, xzr, [x9, #32]
    add     x9, x28, #G_STAMAX          // de G_STAMAX ate o fim: fabricar,
    mov     w10, #((GSIZE - G_STAMAX) / 16) // bau, tocha, mochila...
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    mov     w9, #-1
    str     w9, [x28, #G_HOVREC]
    str     w9, [x28, #G_HOVANIM]
    bl      animals_reset               // sem animais nem flechas
    LA      x9, chestused               // nenhum bau no mundo
    stp     xzr, xzr, [x9]
    stp     xzr, xzr, [x9, #16]
    stp     xzr, xzr, [x9, #32]
    stp     xzr, xzr, [x9, #48]
    LA      x9, shelters
    mov     w10, #-1                    // nenhum abrigo
    mov     w11, #MAXSHELTER
2:  str     w10, [x9], #4
    subs    w11, w11, #1
    b.ne    2b
    mov     w9, #SATTIME                // comeca de barriga cheia
    str     w9, [x28, #G_SATED]
    bl      weather_reset               // primavera, com sol
    bl      calc_stats
    LA      x9, seen                   // nada foi descoberto ainda
    mov     w10, #(MAPN * MAPN / 16)
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    // procura terra firme em espiral a partir do centro do mapa
    mov     w19, #0                     // raio
sr_r:
    mov     w20, #0                     // direcao
sr_d:
    LA      x9, dirtab
    add     x9, x9, x20, lsl #2
    ldrsh   w10, [x9]
    scvtf   s0, w10
    ldrsh   w10, [x9, #2]
    scvtf   s1, w10
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    scvtf   s2, w19
    mov     w9, #256
    scvtf   s3, w9
    fmadd   s8, s0, s2, s3
    fmadd   s9, s1, s2, s3
    fmov    s0, s8
    fmov    s1, s9
    bl      elev_at
    cmp     w0, #60
    b.lt    1f
    cmp     w0, #E_HILL
    b.ge    1f
    fcvtzs  w9, s8                      // fora da floresta (umidade baixa)
    fcvtzs  w10, s9
    add     w9, w9, w10, lsl #9
    LA      x10, moist
    ldrb    w9, [x10, w9, uxtw]
    cmp     w9, #135
    b.lo    sr_found
1:  add     w20, w20, #1
    cmp     w20, #16
    b.lt    sr_d
    add     w19, w19, #2
    cmp     w19, #240
    b.lt    sr_r
    mov     w9, #256                    // nao achou: centro mesmo
    scvtf   s8, w9
    fmov    s9, s8
    mov     w0, #0
sr_found:
    str     s8, [x28, #G_PU]
    str     s9, [x28, #G_PV]
    str     w0, [x28, #G_PE]
    bl      follow_camera
    LA      x0, m_start
    bl      set_msg
    ldp     d10, d11, [sp, #48]
    ldp     d8, d9, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// =====================================================================
//  Atualizacao (um quadro)
// =====================================================================

// update_ambient: cor da luz ambiente pela hora do dia
update_ambient:
    ldr     w9, [x28, #G_TIME]
    mov     w10, #0                     // k: 0 = dia ... 256 = noite
    mov     w11, #T_DUSK
    cmp     w9, w11
    b.lt    2f
    mov     w11, #T_NIGHT
    cmp     w9, w11
    b.ge    1f
    mov     w11, #T_DUSK                // anoitecendo
    sub     w10, w9, w11
    lsl     w10, w10, #8
    mov     w11, #(T_NIGHT - T_DUSK)
    udiv    w10, w10, w11
    b       2f
1:  mov     w10, #256
    MOVI32  w11, T_DAWN
    cmp     w9, w11
    b.lt    2f
    MOVI32  w11, DAYLEN                 // amanhecendo
    sub     w10, w11, w9
    lsl     w10, w10, #8
    mov     w11, #(DAYLEN - T_DAWN)
    udiv    w10, w10, w11
2:  str     w10, [x28, #G_NIGHTK]
    // canal = 256 + (noite - 256) * k / 256
    mov     w11, #(60 - 256)
    mul     w11, w11, w10
    asr     w11, w11, #8
    add     w11, w11, #256
    str     w11, [x28, #G_AMBR]
    mov     w11, #(72 - 256)
    mul     w11, w11, w10
    asr     w11, w11, #8
    add     w11, w11, #256
    str     w11, [x28, #G_AMBG]
    mov     w11, #(118 - 256)
    mul     w11, w11, w10
    asr     w11, w11, #8
    add     w11, w11, #256
    str     w11, [x28, #G_AMBB]
    // clima: as nuvens escurecem; o relampago clareia tudo
    mov     w13, #256
    ldr     w12, [x28, #G_FLASH]
    cbnz    w12, 3f
    ldr     w12, [x28, #G_WDARK]
    sub     w13, w13, w12
    ldr     w11, [x28, #G_AMBR]
    mul     w11, w11, w13
    lsr     w11, w11, #8
    str     w11, [x28, #G_AMBR]
    ldr     w11, [x28, #G_AMBG]
    mul     w11, w11, w13
    lsr     w11, w11, #8
    str     w11, [x28, #G_AMBG]
    ldr     w11, [x28, #G_AMBB]
    mul     w11, w11, w13
    lsr     w11, w11, #8
    str     w11, [x28, #G_AMBB]
    ret
3:  str     w13, [x28, #G_AMBR]
    str     w13, [x28, #G_AMBG]
    str     w13, [x28, #G_AMBB]
    ret

// find_obj_near(w0 = u, w1 = v em 1/64) -> w0 objeto coletavel (-1)
// folha: usa x0-x15
find_obj_near:
    mov     w2, w0
    mov     w3, w1
    mov     w0, #-1
    mov     w4, #6400                   // raio^2 (1.25 celula)
    ldr     w5, [x28, #G_NOBJ]
    LA      x6, objs
    mov     w7, #0
1:  cmp     w7, w5
    b.ge    9f
    ldrb    w8, [x6, #6]
    cmp     w8, #O_BUSHE                // arvore, pedra, arbusto...
    b.ls    11f
    sub     w8, w8, #O_LOGS             // ... ou pilha largada
    cmp     w8, #(O_LAST - O_LOGS)
    b.hi    2f
11: ldrh    w9, [x6]
    sub     w9, w9, w2
    cmp     w9, #80
    b.gt    2f
    cmn     w9, #80
    b.lt    2f
    ldrh    w10, [x6, #2]
    sub     w10, w10, w3
    cmp     w10, #80
    b.gt    2f
    cmn     w10, #80
    b.lt    2f
    mul     w9, w9, w9
    madd    w9, w10, w10, w9
    cmp     w9, w4
    b.ge    2f
    mov     w4, w9
    mov     w0, w7
2:  add     x6, x6, #8
    add     w7, w7, #1
    b       1b
9:  ret

// find_fire_near(w0 = u, w1 = v em 1/64) -> w0 fogueira (-1)
find_fire_near:
    scvtf   s0, w0
    scvtf   s1, w1
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    fmov    s4, #2.0                    // raio^2
    mov     w0, #-1
    ldr     w9, [x28, #G_NFIRE]
    LA      x10, fires
    mov     w11, #0
1:  cmp     w11, w9
    b.ge    9f
    ldr     s2, [x10]
    fsub    s2, s2, s0
    ldr     s3, [x10, #4]
    fsub    s3, s3, s1
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    fcmp    s2, s4
    b.ge    2f
    fmov    s4, s2
    mov     w0, w11
2:  add     x10, x10, #16
    add     w11, w11, #1
    b       1b
9:  ret

// harvest(w0 = objeto): da 1 recurso e gasta o objeto
harvest:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    LA      x19, objs
    add     x19, x19, x0, lsl #3
    ldrb    w20, [x19, #6]              // tipo
    // bau e abrigo: desmonta e volta para a mochila
    mov     w21, #IT_SHELTER
    cmp     w20, #O_SHELTER
    b.eq    43f
    cmp     w20, #O_CHEST
    b.ne    0f
    ldrb    w0, [x19, #7]               // bau so desmonta vazio
    bl      chest_count
    cbz     w0, 42f
    LA      x0, m_chestfull
    bl      set_msg
    b       6f
42: ldrb    w9, [x19, #7]
    LA      x10, chestused
    strb    wzr, [x10, x9]
    mov     w21, #IT_CHEST
43: mov     w0, w21
    mov     w1, #1
    bl      inv_add
    mov     w9, #O_GONE
    strb    w9, [x19, #6]
    LA      x0, p_pickup
    bl      popup
    b       6f
    // qual item: pilha largada, pedra, arbusto ou arvore
0:  sub     w9, w20, #O_LOGS
    cmp     w20, #O_LOGS
    b.hs    1f
    mov     w9, #1
    cmp     w20, #O_ROCK
    b.eq    1f
    mov     w9, #2
    cmp     w20, #O_BUSH
    b.eq    1f
    mov     w9, #0
1:  mov     w21, w9
    mov     w0, w9
    mov     w1, #1
    bl      inv_add
    LA      x10, popitem
    ldr     x0, [x10, x21, lsl #3]
    bl      popup
    // treino: arvores (lenhador) e pedras (mineracao)
    cmp     w20, #O_PINE
    b.hi    2f
    mov     w0, #SK_CHOP
    FC      s0, F_XPCHOP
    bl      skill_train
    mov     w0, #IT_AXE                 // o machado gasta
    bl      tool_use
    b       3f
2:  cmp     w20, #O_ROCK
    b.ne    3f
    mov     w0, #SK_MINE
    FC      s0, F_XPMINE
    bl      skill_train
    mov     w0, #IT_PICK                // a picareta gasta
    bl      tool_use
3:  mov     x9, x19
    mov     w10, w20
    ldrb    w11, [x9, #7]               // quanto ainda tem
    subs    w11, w11, #1
    csel    w11, wzr, w11, lt
    strb    w11, [x9, #7]
    cbnz    w11, 6f
    mov     w12, #O_GONE
    cmp     w10, #O_BUSH
    b.ne    5f
    mov     w12, #O_BUSHE               // arbusto fica sem frutas
5:  strb    w12, [x9, #6]
    cmp     w10, #O_PINE                // arvore caiu: deixa de tapar a visao
    b.hi    6f
    ldrh    w11, [x9]
    lsr     w11, w11, #6
    ldrh    w12, [x9, #2]
    lsr     w12, w12, #6
    add     w11, w11, w12, lsl #9
    LA      x12, treecnt
    ldrb    w13, [x12, w11, uxtw]
    cbz     w13, 6f
    sub     w13, w13, #1
    strb    w13, [x12, w11, uxtw]
6:  ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// inv_add(w0 = item, w1 = quantos): poe na mochila. Uma ferramenta que
// voce nao tinha chega nova (durabilidade cheia).   folha
inv_add:
    add     x9, x28, #G_INV
    ldr     w10, [x9, x0, lsl #2]
    add     w11, w10, w1
    str     w11, [x9, x0, lsl #2]
    cbnz    w10, 9f
    mov     w12, #TOOLDUR
    cmp     w0, #IT_AXE
    b.ne    1f
    str     w12, [x28, #G_AXEDUR]
1:  cmp     w0, #IT_PICK
    b.ne    9f
    str     w12, [x28, #G_PICKDUR]
9:  ret

// tool_use(w0 = IT_AXE ou IT_PICK): gasta 1 uso; quando acaba, quebra
// e a proxima (se tiver) entra nova
tool_use:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #G_HAND]          // so gasta se estiver na mao
    add     w10, w0, #1
    cmp     w9, w10
    b.ne    9f
    add     x9, x28, #G_INV
    ldr     w10, [x9, x0, lsl #2]
    cbz     w10, 9f
    add     x11, x28, #G_AXEDUR
    LA      x13, m_axebroke
    cmp     w0, #IT_AXE
    b.eq    1f
    add     x11, x28, #G_PICKDUR
    LA      x13, m_pickbroke
1:  ldr     w12, [x11]
    subs    w12, w12, #1
    b.gt    2f
    sub     w10, w10, #1                // quebrou
    str     w10, [x9, x0, lsl #2]
    mov     w12, #TOOLDUR
    cmp     w10, #0
    csel    w12, w12, wzr, ne
    str     w12, [x11]
    mov     x0, x13
    bl      set_msg
    b       9f
2:  str     w12, [x11]
9:  ldp     x29, x30, [sp], #16
    ret

    .globl surv_update
surv_update:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    stp     d10, d11, [sp, #64]
    ldr     w9, [x28, #G_MSGT]
    cbz     w9, 1f
    sub     w9, w9, #1
    str     w9, [x28, #G_MSGT]
1:  ldr     w9, [x28, #G_POPT]
    cbz     w9, 2f
    sub     w9, w9, #1
    str     w9, [x28, #G_POPT]
2:  bl      update_ambient
    bl      calc_stats
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, su_cam
    ldr     w9, [x28, #G_PAUSE]
    cbnz    w9, su_cam
    bl      skills_tick                 // skills sem treino caem devagar
    ldr     w9, [x28, #G_PLACE]         // a construcao saiu da mochila?
    cbz     w9, 197f
    sub     w9, w9, #1
    add     x10, x28, #G_INV
    ldr     w10, [x10, x9, lsl #2]
    cbnz    w10, 197f
    str     wzr, [x28, #G_PLACE]
197: ldr    w9, [x28, #G_HAND]          // o que esta na mao acabou (quebrou,
    cbz     w9, 198f                    // largou, guardou)? maos vazias
    sub     w9, w9, #1
    add     x10, x28, #G_INV
    ldr     w10, [x10, x9, lsl #2]
    cbnz    w10, 198f
    str     wzr, [x28, #G_HAND]
198: ldr    w9, [x28, #(G_INV + 4 * IT_TORCH)] // sem tochas: outra mao vazia
    cbnz    w9, 199f
    str     wzr, [x28, #G_OFFHAND]
199: ldr    w9, [x28, #G_ATKCD]         // espera entre golpes
    subs    w9, w9, #1
    csel    w9, wzr, w9, lt
    str     w9, [x28, #G_ATKCD]
    ldr     w9, [x28, #G_KILLT]
    subs    w9, w9, #1
    csel    w9, wzr, w9, lt
    str     w9, [x28, #G_KILLT]

    // ---- relogio ----
    ldr     w9, [x28, #G_TIME]
    add     w9, w9, #1
    MOVI32  w10, DAYLEN
    cmp     w9, w10
    b.lo    3f
    mov     w9, #0
    ldr     w10, [x28, #G_DAY]
    add     w10, w10, #1
    str     w10, [x28, #G_DAY]
    str     wzr, [x28, #G_WARNED]
3:  str     w9, [x28, #G_TIME]
    mov     w10, #(T_DUSK - 1600)       // aviso: vai escurecer
    cmp     w9, w10
    b.lt    4f
    ldr     w10, [x28, #G_WARNED]
    cbnz    w10, 4f
    mov     w10, #1
    str     w10, [x28, #G_WARNED]
    LA      x0, m_dusk
    bl      set_msg

    // ---- movimento (WASD / setas, na direcao da tela) ----
    // teclas -> w22: bit 0 W, 1 S, 2 A, 3 D, 4 Shift (o teste soma as suas)
4:  bl      weather_update              // estacao e clima
    bl      sleep_check                 // dormindo: hora de acordar?
    ldr     x19, [x28, #G_KEYS]
    ldr     w22, [x28, #G_TESTKEYS]
    ldrb    w9, [x19, #26]              // W ou seta para cima
    ldrb    w10, [x19, #82]
    orr     w9, w9, w10
    cbz     w9, 41f
    orr     w22, w22, #1
41: ldrb    w9, [x19, #22]              // S
    ldrb    w10, [x19, #81]
    orr     w9, w9, w10
    cbz     w9, 42f
    orr     w22, w22, #2
42: ldrb    w9, [x19, #4]               // A
    ldrb    w10, [x19, #80]
    orr     w9, w9, w10
    cbz     w9, 43f
    orr     w22, w22, #4
43: ldrb    w9, [x19, #7]               // D
    ldrb    w10, [x19, #79]
    orr     w9, w9, w10
    cbz     w9, 44f
    orr     w22, w22, #8
44: ldrb    w9, [x19, #225]             // Shift esquerdo ou direito
    ldrb    w10, [x19, #229]
    orr     w9, w9, w10
    cbz     w9, 45f
    orr     w22, w22, #16
45: ldr     w9, [x28, #G_SLEEP]         // dormindo: nao anda
    cbz     w9, 451f
    mov     w22, #0
451: fmov   s8, wzr                     // du
    fmov    s9, wzr                     // dv
    fmov    s0, #1.0
    tbz     w22, #0, 5f                 // W: sobe na tela = -u -v
    fsub    s8, s8, s0
    fsub    s9, s9, s0
5:  tbz     w22, #1, 6f                 // S: +u +v
    fadd    s8, s8, s0
    fadd    s9, s9, s0
6:  tbz     w22, #2, 7f                 // A: esquerda = -u +v
    fsub    s8, s8, s0
    fadd    s9, s9, s0
7:  tbz     w22, #3, 8f                 // D: direita = +u -v
    fadd    s8, s8, s0
    fsub    s9, s9, s0
8:  str     wzr, [x28, #G_RUN]
    fmul    s10, s8, s8
    fmadd   s10, s9, s9, s10
    fcmp    s10, #0.0
    b.ne    9f
    str     wzr, [x28, #G_PMOVING]
    b       su_after_move
9:  fsqrt   s10, s10
    FC      s11, F_SPEED
    fdiv    s11, s11, s10
    ldr     w9, [x28, #G_WATER]
    cmp     w9, #2
    b.lt    92f
    // nadando: mais rapido com a skill; sem stamina, quase parado
    ldr     s1, [x28, #G_STAMINA]
    fcmp    s1, #0.0
    b.gt    91f
    FC      s0, F_TIRED
    b       94f
91: ldr     s1, [x28, #G_SKSWIM]
    FC      s2, F_SWIMSK
    FC      s0, F_SWIMBASE
    fmadd   s0, s1, s2, s0              // 0.45 .. 0.80
    b       94f
92: LA      x10, waterspeed             // terra 1.0, agua rasa 0.6
    ldr     s0, [x10, x9, lsl #2]
    // correr (Shift): precisa de stamina e de nao estar sobrecarregado
    tbz     w22, #4, 94f
    ldr     w9, [x28, #G_EXHAUST]
    cbnz    w9, 94f
    ldr     w9, [x28, #G_WEIGHT]
    ldr     w10, [x28, #G_CAP]
    cmp     w9, w10
    b.gt    94f
    ldr     s1, [x28, #G_STAMINA]
    fcmp    s1, #0.0
    b.le    94f
    mov     w9, #1
    str     w9, [x28, #G_RUN]
    ldr     s1, [x28, #G_SKRUN]
    FC      s2, F_RUNSK
    FC      s3, F_RUNBASE
    fmadd   s1, s1, s2, s3              // 1.7 .. 2.2
    fmul    s0, s0, s1
94: ldr     s1, [x28, #G_WSPEED]        // neve e vento: mais devagar
    fmul    s0, s0, s1
    ldr     w9, [x28, #G_WEIGHT]        // sobrecarregado: bem mais lento
    ldr     w10, [x28, #G_CAP]
    cmp     w9, w10
    b.le    95f
    FC      s1, F_HEAVY
    fmul    s0, s0, s1
95: fmul    s11, s11, s0
    fmul    s8, s8, s11
    fmul    s9, s9, s11
    mov     w9, #1
    str     w9, [x28, #G_PMOVING]
    ldr     w9, [x28, #G_PFRAME]
    ldr     w10, [x28, #G_RUN]
    add     w9, w9, #1
    add     w9, w9, w10                 // correndo: pernas mais rapidas
    str     w9, [x28, #G_PFRAME]
    // anda em u e em v (so nao pode sair do mapa)
    mov     w9, #509
    scvtf   s2, w9
    fmov    s1, #2.0
    ldr     s0, [x28, #G_PU]
    fadd    s10, s0, s8
    fcmp    s10, s1
    b.lt    10f
    fcmp    s10, s2
    b.gt    10f
    str     s10, [x28, #G_PU]
10: ldr     s0, [x28, #G_PV]
    fadd    s10, s0, s9
    fcmp    s10, s1
    b.lt    su_after_move
    fcmp    s10, s2
    b.gt    su_after_move
    str     s10, [x28, #G_PV]
su_after_move:
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]         // enchente: a agua esta mais alta
    sub     w19, w0, w9                 // elevacao acima da agua (< 0 = agua)
    cmp     w0, w9
    csel    w0, w9, w0, lt              // na agua: fica na superficie
    str     w0, [x28, #G_PE]
    // nivel da agua: 0 terra, 1 raso, 2 fundo, 3 mar aberto (perto da borda)
    mov     w20, #0
    tbz     w19, #31, 202f
    mov     w20, #1
    cmn     w19, #W_SHALLOW
    b.ge    202f
    mov     w20, #2
    mov     w9, #-W_OCEAN
    cmp     w19, w9
    b.gt    202f
    ldr     s0, [x28, #G_PU]
    fcvtzs  w9, s0
    ldr     s0, [x28, #G_PV]
    fcvtzs  w10, s0
    mov     w11, #511
    sub     w12, w11, w9
    sub     w13, w11, w10
    cmp     w9, w10
    csel    w9, w9, w10, lt
    cmp     w9, w12
    csel    w9, w9, w12, lt
    cmp     w9, w13
    csel    w9, w9, w13, lt             // distancia ate a borda
    cmp     w9, #W_BORDER
    b.ge    202f
    mov     w20, #3
202: str    w20, [x28, #G_WATER]

    // ---- o que esta sob o mouse ----
    mov     w9, #-1
    str     w9, [x28, #G_HOVOBJ]
    str     w9, [x28, #G_HOVFIRE]
    str     w9, [x28, #G_HOVANIM]
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 11f
    bl      mouse_ui                    // mouse em cima de botao ou janela?
    bl      ui_hit
    cbnz    w0, 11f
    ldr     w0, [x28, #G_HOVU]          // um animal (a vista)?
    ldr     w1, [x28, #G_HOVV]
    bl      animal_at
    str     w0, [x28, #G_HOVANIM]
    ldr     w0, [x28, #G_HOVU]
    ldr     w1, [x28, #G_HOVV]
    bl      find_obj_near
    tbnz    w0, #31, 101f
    LA      x9, objs                    // so vale se estiver a vista
    add     x9, x9, x0, lsl #3
    ldrh    w10, [x9]
    lsr     w10, w10, #6
    ldrh    w11, [x9, #2]
    lsr     w11, w11, #6
    add     w10, w10, w11, lsl #9
    LA      x9, vis
    ldrb    w10, [x9, w10, uxtw]
    cmp     w10, #VIS_MIN
    b.hs    101f
    mov     w0, #-1
101: str    w0, [x28, #G_HOVOBJ]
    ldr     w0, [x28, #G_HOVU]
    ldr     w1, [x28, #G_HOVV]
    bl      find_fire_near
    str     w0, [x28, #G_HOVFIRE]

    // ---- coleta (segurando o botao esquerdo) ----
11: ldr     w9, [x28, #G_LMB]
    cbz     w9, su_nomine
    ldr     w19, [x28, #G_HOVOBJ]
    tbnz    w19, #31, su_nomine
    LA      x9, objs
    add     x9, x9, x19, lsl #3
    ldrb    w20, [x9, #6]
    cmp     w20, #O_BUSHE
    b.eq    su_nomine
    mov     w0, w19
    bl      obj_dist2
    FC      s1, F_REACH2
    fcmp    s0, s1
    b.gt    su_nomine
    ldr     w9, [x28, #G_WEIGHT]        // peso demais: nao pega mais nada
    ldr     w10, [x28, #G_CAP]
    add     w10, w10, w10, lsr #1
    cmp     w9, w10
    b.lt    111f
    LA      x0, m_toheavy
    bl      set_msg
    b       su_nomine
111: ldr    w9, [x28, #G_MINEOBJ]
    cmp     w9, w19
    b.eq    12f
    str     w19, [x28, #G_MINEOBJ]
    str     wzr, [x28, #G_MINEPROG]
12: LA      x9, minetime
    ldrb    w10, [x9, x20]
    fmov    s1, wzr                     // lenhador / mineracao: ate 2x mais rapido
    cmp     w20, #O_PINE
    b.hi    121f
    ldr     s1, [x28, #G_SKCHOP]
    b       122f
121: cmp    w20, #O_ROCK
    b.ne    122f
    ldr     s1, [x28, #G_SKMINE]
122: FC     s2, F_SK5
    fmul    s1, s1, s2
    fmov    s2, #1.0
    fsub    s1, s2, s1
    scvtf   s2, w10
    fmul    s2, s2, s1
    fcvtzs  w10, s2
    // machado (na mao) nas arvores e picareta nas pedras: metade do tempo
    ldr     w9, [x28, #G_HAND]
    cmp     w20, #O_PINE
    b.hi    123f
    cmp     w9, #(IT_AXE + 1)
    b       124f
123: cmp    w20, #O_ROCK
    b.ne    125f
    cmp     w9, #(IT_PICK + 1)
124: b.ne   125f
    lsr     w10, w10, #1
125: str    w10, [x28, #G_MINENEED]
    ldr     w9, [x28, #G_MINEPROG]
    add     w9, w9, #1
    str     w9, [x28, #G_MINEPROG]
    cmp     w9, w10
    b.lt    su_food
    str     wzr, [x28, #G_MINEPROG]
    mov     w0, w19
    bl      harvest
    b       su_food
su_nomine:
    mov     w9, #-1
    str     w9, [x28, #G_MINEOBJ]
    str     wzr, [x28, #G_MINEPROG]

    // ---- fome ----
su_food:
    ldr     w9, [x28, #G_SATED]         // cheio: segura um tempo antes de cair
    cbz     w9, 213f
    sub     w9, w9, #1
    str     w9, [x28, #G_SATED]
    b       214f
213: ldr    s0, [x28, #G_FOOD]
    FC      s1, F_FOODRATE
    ldr     s2, [x28, #G_WFOOD]         // calorao e neve: mais fome
    fmul    s1, s1, s2
    fsub    s0, s0, s1
    fmov    s1, wzr
    fmax    s0, s0, s1
    str     s0, [x28, #G_FOOD]
214:

    // ---- stamina: nadar e correr gastam; parado em terra volta rapido ----
    ldr     w9, [x28, #G_WATER]
    ldr     s0, [x28, #G_STAMINA]
    cmp     w9, #2
    b.lt    210f
    ldr     s2, [x28, #G_SKSWIM]        // nadando: custo * (1 - 0.6 * natacao)
    FC      s3, F_SK6
    fmul    s2, s2, s3
    fmov    s3, #1.0
    fsub    s2, s3, s2
    FC      s1, F_SWIMCOST
    fmul    s1, s1, s2
    ldr     s2, [x28, #G_WSTAM]         // clima: cansa mais
    fmul    s1, s1, s2
    ldr     w10, [x28, #G_WEIGHT]       // com peso demais afunda: o dobro
    ldr     w11, [x28, #G_CAP]
    cmp     w10, w11
    b.le    209f
    fadd    s1, s1, s1
209: fsub   s0, s0, s1
    b       212f
210: ldr    w10, [x28, #G_RUN]
    cbz     w10, 2101f
    ldr     s2, [x28, #G_SKRUN]         // correndo: custo * (1 - 0.5 * corrida)
    FC      s3, F_SK5
    fmul    s2, s2, s3
    fmov    s3, #1.0
    fsub    s2, s3, s2
    FC      s1, F_RUNCOST
    fmul    s1, s1, s2
    ldr     s2, [x28, #G_WSTAM]
    fmul    s1, s1, s2
    fsub    s0, s0, s1
    b       212f
2101: cbz   w9, 211f
    FC      s1, F_RECOVSH               // no raso: recupera devagar
    b       2111f
211: FC     s1, F_RECOV                 // em terra andando
    ldr     w10, [x28, #G_PMOVING]
    cbnz    w10, 2111f
    FC      s1, F_RECOVREST             // parado: mais rapido
2111: ldr   s2, [x28, #G_WRECOV]        // calorao: recupera devagar
    fmul    s1, s1, s2
    fadd    s0, s0, s1
212: fmov   s1, wzr
    fmax    s0, s0, s1
    ldr     s1, [x28, #G_STAMAX]        // o maximo cresce com corrida e natacao
    fmin    s0, s0, s1
    str     s0, [x28, #G_STAMINA]
    fcmp    s0, #0.0                    // acabou: so corre de novo com 25
    b.gt    2121f
    mov     w9, #1
    str     w9, [x28, #G_EXHAUST]
    b       2122f
2121: FC    s1, F_25
    fcmp    s0, s1
    b.lt    2122f
    str     wzr, [x28, #G_EXHAUST]
2122:

    // ---- treino: nadar, correr e andar carregado ----
    ldr     w9, [x28, #G_PMOVING]
    cbz     w9, 219f
    ldr     w9, [x28, #G_WATER]
    cmp     w9, #2
    b.lt    217f
    mov     w0, #SK_SWIM
    FC      s0, F_XPSWIM
    bl      skill_train
217: ldr    w9, [x28, #G_RUN]
    cbz     w9, 218f
    mov     w0, #SK_RUN
    FC      s0, F_XPRUN
    bl      skill_train
218: ldr    w9, [x28, #G_WEIGHT]        // forca: andando com mais de 60% da carga
    ldr     w10, [x28, #G_CAP]
    mov     w11, #10
    mul     w12, w9, w11
    mov     w11, #6
    mul     w13, w10, w11
    cmp     w12, w13
    b.lt    219f
    FC      s0, F_XPSTR
    cmp     w9, w10
    b.le    2181f
    fadd    s0, s0, s0                  // sobrecarregado treina o dobro
2181: mov   w0, #SK_STR
    bl      skill_train
219:
    ldr     w9, [x28, #G_WATER]
    cmp     w9, #3
    b.ne    215f
    ldr     w10, [x28, #G_SHARK]        // mar aberto: o tubarao vem chegando
    add     w10, w10, #1
    str     w10, [x28, #G_SHARK]
    cmp     w10, #1
    b.ne    213f
    LA      x0, m_shark1
    bl      set_msg
    ldr     w10, [x28, #G_SHARK]
213: mov    w9, #SHARKTIME
    cmp     w10, w9
    b.lt    216f
    LA      x9, m_eaten                 // tarde demais
    str     x9, [x28, #G_DEATHMSG]
    str     wzr, [x28, #G_HP]
    mov     w9, #1
    str     w9, [x28, #G_DEAD]
    str     wzr, [x28, #G_LMB]
    LA      x0, m_eaten
    bl      set_msg
    b       su_cam
215: ldr    w10, [x28, #G_SHARK]        // longe do mar aberto: ele vai embora
    subs    w10, w10, #2
    csel    w10, wzr, w10, lt
    str     w10, [x28, #G_SHARK]
216:

    // ---- animais e flechas ----
    bl      animals_update
    bl      arrows_update
    ldr     w9, [x28, #G_DEAD]          // um animal pode ter matado
    cbnz    w9, su_cam
    // ---- tocha: na mao, acende sozinha quando escurece ----
    str     wzr, [x28, #G_TORCHLIT]
    ldr     w9, [x28, #G_OFFHAND]       // tocha na outra mao?
    cbz     w9, 229f
    ldr     w9, [x28, #G_SLEEP]         // dormindo: a tocha fica apagada
    cbnz    w9, 229f
    ldr     w9, [x28, #G_NIGHTK]
    cmp     w9, #96
    b.lt    229f
    ldr     w10, [x28, #G_TORCHT]
    cbnz    w10, 228f
    MOVI32  w10, TORCHTIME              // acende a tocha da mao
228: subs   w10, w10, #1
    b.gt    2281f
    ldr     w11, [x28, #(G_INV + 4 * IT_TORCH)] // queimou toda: gasta
    sub     w11, w11, #1
    str     w11, [x28, #(G_INV + 4 * IT_TORCH)]
    mov     w10, #0
2281: str   w10, [x28, #G_TORCHT]
    mov     w9, #1
    str     w9, [x28, #G_TORCHLIT]
229:
    // ---- bau aberto: fecha se voce se afastar ----
    ldr     w9, [x28, #G_CHESTOPEN]
    cbz     w9, 231f
    ldr     w0, [x28, #G_CHESTOBJ]
    bl      obj_dist2
    FC      s1, F_FIRE2
    fcmp    s0, s1
    b.le    231f
    str     wzr, [x28, #G_CHESTOPEN]
231:
    // ---- calor ----
    bl      in_shelter                  // dentro de um abrigo?
    str     w0, [x28, #G_INSHELTER]
    mov     w21, #0                     // perto de uma fogueira?
    ldr     w19, [x28, #G_NFIRE]
    mov     w20, #0
13: cmp     w20, w19
    b.ge    14f
    mov     w0, w20
    bl      fire_dist2
    FC      s1, F_FIRE2
    fcmp    s0, s1
    b.gt    131f
    mov     w21, #1
131: add    w20, w20, #1
    b       13b
14: str     w21, [x28, #G_NEARFIRE]
    fmov    s3, #1.0                    // roupa de couro: metade do frio
    ldr     w9, [x28, #(G_INV + 4 * IT_COAT)]
    cbz     w9, 141f
    fmov    s3, #0.5
141: ldr    s0, [x28, #G_WARM]
    cbz     w21, 15f
    FC      s1, F_HEAT
    fadd    s0, s0, s1
    b       17f
15: ldr     w9, [x28, #G_AMBR]
    cmp     w9, #170
    b.ge    16f
    ldr     w9, [x28, #G_INSHELTER]     // abrigado: nao passa frio
    cbnz    w9, 16f
    FC      s1, F_COLD                  // escuro: esfria
    fmul    s1, s1, s3
    fsub    s0, s0, s1
    b       17f
16: FC      s1, F_DAYWARM
    fadd    s0, s0, s1
17: ldr     w9, [x28, #G_WATER]         // nadando: a agua esfria
    cmp     w9, #2
    b.lt    171f
    FC      s1, F_WETCOLD
    fmul    s1, s1, s3
    fsub    s0, s0, s1
171: ldr    w9, [x28, #G_INSHELTER]     // clima: chuva, neve... esfriam
    cbnz    w9, 172f                    // (no calorao, esquenta); o abrigo
    ldr     s1, [x28, #G_WCOLD]         // protege
    fcmp    s1, #0.0
    b.le    1711f
    fmul    s1, s1, s3
1711: fsub  s0, s0, s1
172: fmov   s1, wzr
    fmax    s0, s0, s1
    FC      s1, F_HUNDRED
    fmin    s0, s0, s1
    str     s0, [x28, #G_WARM]

    // ---- vida ----
    ldr     s8, [x28, #G_HP]
    ldr     s0, [x28, #G_FOOD]
    fcmp    s0, #0.0
    b.gt    18f
    FC      s1, F_STARVE
    fsub    s8, s8, s1
18: ldr     s0, [x28, #G_WARM]
    fcmp    s0, #0.0
    b.gt    19f
    FC      s1, F_FREEZE
    fsub    s8, s8, s1
19: ldr     w9, [x28, #G_WATER]         // sem folego na agua funda: afoga
    cmp     w9, #2
    b.lt    191f
    ldr     s0, [x28, #G_STAMINA]
    fcmp    s0, #0.0
    b.gt    191f
    FC      s1, F_DROWN
    fsub    s8, s8, s1
191: ldr    w9, [x28, #G_INSHELTER]     // granizo machuca fora do abrigo
    cbnz    w9, 192f
    ldr     s1, [x28, #G_WHAIL]
    fsub    s8, s8, s1
192: FC     s2, F_HUNDRED               // vida so sobe com a fome cheia
    ldr     s0, [x28, #G_FOOD]
    fcmp    s0, s2
    b.lt    20f
    FC      s2, F_FORTY                 // ... e sem passar frio
    ldr     s0, [x28, #G_WARM]
    fcmp    s0, s2
    b.le    20f
    FC      s1, F_REGEN
    fadd    s8, s8, s1
20: FC      s1, F_HUNDRED
    fmin    s8, s8, s1
    fcmp    s8, #0.0
    b.gt    21f
    fmov    s8, wzr
    mov     w9, #1
    str     w9, [x28, #G_DEAD]
    str     wzr, [x28, #G_LMB]
    LA      x0, m_froze                 // causa da morte
    ldr     s0, [x28, #G_FOOD]
    fcmp    s0, #0.0
    b.gt    201f
    LA      x0, m_starved
201: ldr    w9, [x28, #G_WATER]
    cmp     w9, #2
    b.lt    203f
    ldr     s0, [x28, #G_STAMINA]
    fcmp    s0, #0.0
    b.gt    203f
    LA      x0, m_drowned
203: ldr    s0, [x28, #G_WHAIL]         // granizo (sem fome, frio ou agua)
    fcmp    s0, #0.0
    b.le    204f
    ldr     w9, [x28, #G_INSHELTER]
    cbnz    w9, 204f
    ldr     s0, [x28, #G_WARM]
    fcmp    s0, #0.0
    b.le    204f
    ldr     s0, [x28, #G_FOOD]
    fcmp    s0, #0.0
    b.le    204f
    LA      x0, m_hailed
204: ldr    w9, [x28, #G_KILLT]         // mordida de um animal agora ha pouco
    cbz     w9, 205f
    ldr     x0, [x28, #G_KILLER]
205: str    x0, [x28, #G_DEATHMSG]
    bl      set_msg
21: str     s8, [x28, #G_HP]

    // ---- fogueiras gastam lenha ----
    ldr     w19, [x28, #G_NFIRE]
    LA      x20, fires
    mov     w9, #0
22: cmp     w9, w19
    b.ge    24f
    add     x10, x20, x9, lsl #4
    ldr     w11, [x10, #12]
    ldr     w12, [x28, #G_WFIRE]        // chuva/neve: queima mais rapido
    sub     w11, w11, w12
    ldr     w12, [x10, #8]              // debaixo da enchente: apaga
    ldr     w13, [x28, #G_FLOOD]
    cmp     w12, w13
    csel    w11, wzr, w11, lt
    subs    w11, w11, #1
    str     w11, [x10, #12]
    b.gt    23f
    sub     w19, w19, #1                // apagou: tira da lista
    add     x12, x20, x19, lsl #4
    ldp     x13, x14, [x12]
    stp     x13, x14, [x10]
    b       22b
23: add     w9, w9, #1
    b       22b
24: str     w19, [x28, #G_NFIRE]

    // ---- arbustos voltam a dar frutas (a cada 40 s, chance de 1/6) ----
    ldr     w9, [x28, #G_TIME]
    mov     w10, #2400
    udiv    w11, w9, w10
    msub    w11, w11, w10, w9
    cbnz    w11, su_cam
    ldr     w19, [x28, #G_NOBJ]
    LA      x20, objs
25: cbz     w19, su_cam
    ldrb    w9, [x20, #6]
    cmp     w9, #O_BUSHE
    b.ne    26f
    bl      rng
    mov     w9, #6
    ldr     w10, [x28, #G_WEATHER]      // chuva: frutas voltam 2x mais rapido
    ldr     w11, [x28, #G_WK]
    cmp     w11, #128
    b.lt    251f
    cmp     w10, #W_RAIN
    b.eq    250f
    cmp     w10, #W_STORM
    b.eq    250f
    cmp     w10, #W_FLOOD
    b.ne    251f
250: mov    w9, #3
251: udiv   w10, w0, w9
    msub    w10, w10, w9, w0
    cbnz    w10, 26f
    mov     w9, #O_BUSH
    strb    w9, [x20, #6]
    mov     w9, #3
    strb    w9, [x20, #7]
26: add     x20, x20, #8
    sub     w19, w19, #1
    b       25b

su_cam:
    bl      follow_camera
    ldr     w9, [x28, #G_SLEEP]         // dormindo: tela escura, sem visao
    cbnz    w9, 1f
    bl      update_vision
1:
    ldp     d10, d11, [sp, #64]
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// =====================================================================
//  Teclas e mouse
// =====================================================================

// surv_key(w0 = scancode): E come, F fogueira, I mochila, C personagem,
// Tab fabricar
    .globl surv_key
surv_key:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, 9f
    ldr     w9, [x28, #G_SLEEP]         // dormindo: qualquer tecla acorda
    cbz     w9, 0f
    str     wzr, [x28, #G_SLEEP]
    LA      x0, m_wokeup
    bl      set_msg
    b       9f
0:
    cmp     w0, #8                      // E
    b.ne    1f
    bl      eat_best
    b       9f
1:  cmp     w0, #9                      // F
    b.ne    2f
    bl      fire_key
    b       9f
2:  cmp     w0, #12                     // I: mochila (fechar fecha o bau)
    b.ne    3f
    ldr     w9, [x28, #G_INVOPEN]
    eor     w9, w9, #1
    str     w9, [x28, #G_INVOPEN]
    cbnz    w9, 9f
    str     wzr, [x28, #G_CHESTOPEN]
    b       9f
3:  cmp     w0, #6                      // C: personagem
    b.ne    4f
    ldr     w9, [x28, #G_CHAROPEN]
    eor     w9, w9, #1
    str     w9, [x28, #G_CHAROPEN]
    b       9f
4:  sub     w9, w0, #30                 // 1-4: machado, picareta, arco, tocha
    cmp     w9, #4
    b.hs    5f
    LA      x10, hotbar
    ldrb    w0, [x10, x9]
    bl      equip
    b       9f
5:  cmp     w0, #43                     // Tab: fabricar
    b.ne    9f
    ldr     w9, [x28, #G_CRAFTOPEN]
    eor     w9, w9, #1
    str     w9, [x28, #G_CRAFTOPEN]
    cbz     w9, 9f
    str     wzr, [x28, #G_CHESTOPEN]
9:  ldp     x29, x30, [sp], #16
    ret

// surv_esc -> w0 = 1 se o ESC foi usado aqui (cancela a construcao ou
// fecha as janelas); 0 = pode voltar ao menu
    .globl surv_esc
surv_esc:
    ldr     w9, [x28, #G_PLACE]
    cbz     w9, 1f
    str     wzr, [x28, #G_PLACE]
    mov     w0, #1
    ret
1:  ldr     w9, [x28, #G_INVOPEN]
    ldr     w10, [x28, #G_CHAROPEN]
    orr     w9, w9, w10
    ldr     w10, [x28, #G_CRAFTOPEN]
    orr     w9, w9, w10
    ldr     w10, [x28, #G_CHESTOPEN]
    orr     w9, w9, w10
    mov     w0, #0
    cbz     w9, 2f
    str     wzr, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CHAROPEN]
    str     wzr, [x28, #G_CRAFTOPEN]
    str     wzr, [x28, #G_CHESTOPEN]
    mov     w0, #1
2:  ret

// eat_best (E): come o que enche mais primeiro (carne assada, frutas
// assadas, frutas e, por ultimo, carne crua)
eat_best:
    LA      x9, eatorder
    add     x10, x28, #G_INV
    mov     x11, #0
1:  ldrb    w0, [x9, x11]
    ldr     w12, [x10, x0, lsl #2]
    cbnz    w12, eat_item
    add     x11, x11, #1
    cmp     x11, #4
    b.lt    1b
    LA      x0, m_noberry
    b       set_msg

// eat_item(w0 = item de comer)
eat_item:
    LA      x9, eatvalue
    ldr     s1, [x9, x0, lsl #2]
    fcmp    s1, #0.0
    b.le    9f
    add     x9, x28, #G_INV
    ldr     w10, [x9, x0, lsl #2]
    cbz     w10, 9f
    sub     w10, w10, #1
    str     w10, [x9, x0, lsl #2]
    LA      x10, eatpop
    ldr     x10, [x10, x0, lsl #3]
    ldr     s0, [x28, #G_FOOD]
    fadd    s0, s0, s1
    FC      s1, F_HUNDRED
    fmin    s0, s0, s1
    str     s0, [x28, #G_FOOD]
    mov     x0, x10
    fcmp    s0, s1
    b.lt    popup
    mov     w9, #SATTIME                // encheu: fica cheio 4 min (comer de
    str     w9, [x28, #G_SATED]         // novo cheio renova o tempo)
    LA      x0, p_full
    b       popup
9:  ret

// equip(w0 = item): poe na mao (de novo a mesma coisa: maos vazias).
// A tocha vai para a outra mao: da para segurar arco e tocha juntos.
    .globl equip
equip:
    cmp     w0, #IT_TORCH
    b.ne    0f
    ldr     w9, [x28, #G_OFFHAND]
    cbz     w9, 01f
    str     wzr, [x28, #G_OFFHAND]
    LA      x0, p_torchoff
    b       popup
01: ldr     w11, [x28, #(G_INV + 4 * IT_TORCH)]
    cbnz    w11, 02f
    LA      x0, m_notorch
    b       set_msg
02: mov     w9, #1
    str     w9, [x28, #G_OFFHAND]
    LA      x0, p_torchon
    b       popup
0:  ldr     w9, [x28, #G_HAND]
    add     w10, w0, #1
    cmp     w9, w10
    b.ne    1f
    str     wzr, [x28, #G_HAND]
    LA      x0, p_handempty
    b       popup
1:  add     x9, x28, #G_INV
    ldr     w11, [x9, x0, lsl #2]
    cbnz    w11, 2f
    LA      x9, nohave                  // "Voce nao tem um arco"
    ldr     x0, [x9, x0, lsl #3]
    b       set_msg
2:  str     w10, [x28, #G_HAND]
    str     wzr, [x28, #G_LMB]
    LA      x9, handpop
    ldr     x0, [x9, x0, lsl #3]
    b       popup

// fire_key (F): usa uma fogueira da mochila; se nao tiver, fabrica uma
fire_key:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #(G_INV + 4 * IT_FIRE)]
    cbnz    w9, 1f
    mov     w0, #5                      // receita da fogueira
    bl      craft
    b       9f
1:  mov     w0, #IT_FIRE
    bl      start_place
9:  ldp     x29, x30, [sp], #16
    ret

// start_place(w0 = item): proximo clique no mapa coloca a construcao.
// Fecha fabricar/bau (ficam no meio da tela, onde se clica para colocar).
start_place:
    add     w9, w0, #1
    str     w9, [x28, #G_PLACE]
    str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_CRAFTOPEN]
    str     wzr, [x28, #G_CHESTOPEN]
    LA      x0, m_place
    b       set_msg

// can_craft(w0 = receita) -> w0 = 1 se tem tudo   folha
// receita (16 bytes): resultado, quantos, precisa de fogo, 0,
// e ate 4 pares (item, quantos)
can_craft:
    LA      x9, recipes
    add     x9, x9, x0, lsl #4
    mov     w0, #0
    ldrb    w10, [x9, #2]
    cbz     w10, 1f
    ldr     w10, [x28, #G_NEARFIRE]
    cbz     w10, 9f
1:  add     x11, x28, #G_INV
    mov     x12, #0
2:  add     x13, x9, x12, lsl #1
    ldrb    w14, [x13, #4]              // item
    ldrb    w10, [x13, #5]              // quantos
    cbz     w10, 3f
    ldr     w14, [x11, x14, lsl #2]
    cmp     w14, w10
    b.lo    9f
3:  add     x12, x12, #1
    cmp     x12, #4
    b.lt    2b
    mov     w0, #1
9:  ret

// craft(w0 = receita) -> w0 = 1 fabricou / 0 faltou algo (com mensagem).
// Construcoes ja entram no modo de colocar.
craft:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    LA      x19, recipes
    add     x19, x19, x0, lsl #4
    ldrb    w9, [x19, #2]               // precisa de fogo?
    cbz     w9, 1f
    ldr     w9, [x28, #G_NEARFIRE]
    cbnz    w9, 1f
    LA      x0, m_needfire
    bl      set_msg
    mov     w0, #0
    b       9f
1:  LA      x0, msgbuf                  // "Falta: 2 madeira 1 couro"
    LA      x1, s_falta
    bl      strcat_cur
    mov     x20, x0
    mov     x21, x0
    mov     x22, #0
2:  add     x9, x19, x22, lsl #1
    ldrb    w10, [x9, #5]               // quantos
    cbz     w10, 3f
    ldrb    w13, [x9, #4]               // item
    add     x12, x28, #G_INV
    ldr     w11, [x12, x13, lsl #2]
    subs    w1, w10, w11
    b.le    3f
    mov     x0, x21
    mov     w9, #32
    strb    w9, [x0], #1
    bl      numcat
    mov     w9, #32
    strb    w9, [x0], #1
    add     x9, x19, x22, lsl #1
    ldrb    w13, [x9, #4]
    LA      x1, costnames
    add     x1, x1, x13, lsl #4
    bl      strcat_cur
    mov     x21, x0
3:  add     x22, x22, #1
    cmp     x22, #4
    b.lt    2b
    cmp     x21, x20
    b.eq    4f
    LA      x0, msgbuf
    bl      set_msg
    mov     w0, #0
    b       9f
4:  mov     x22, #0                     // gasta
5:  add     x9, x19, x22, lsl #1
    ldrb    w10, [x9, #5]
    ldrb    w13, [x9, #4]
    add     x12, x28, #G_INV
    ldr     w11, [x12, x13, lsl #2]
    sub     w11, w11, w10
    str     w11, [x12, x13, lsl #2]
    add     x22, x22, #1
    cmp     x22, #4
    b.lt    5b
    ldrb    w0, [x19]
    ldrb    w1, [x19, #1]
    bl      inv_add
    bl      calc_stats
    LA      x0, popbuf                  // "+1 Machado"
    LA      x1, s_plus
    bl      strcat_cur
    ldrb    w1, [x19, #1]
    bl      numcat
    mov     w9, #32
    strb    w9, [x0], #1
    ldrb    w9, [x19]
    LA      x1, itemnames
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    LA      x0, popbuf
    bl      popup
    ldrb    w0, [x19]
    cmp     w0, #IT_FIRSTBUILD
    b.lo    6f
    cmp     w0, #IT_LASTBUILD
    b.hi    6f
    bl      start_place
6:  mov     w0, #1
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// cost_str(x0 = cursor, w1 = receita) -> x0   ("3 madeira, 2 pedra")
cost_str:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    LA      x19, recipes
    add     x19, x19, x1, lsl #4
    mov     x20, #0
    mov     w21, #0
1:  add     x9, x19, x20, lsl #1
    ldrb    w22, [x9, #5]
    cbz     w22, 3f
    cbz     w21, 2f
    mov     w9, #44
    strb    w9, [x0], #1
    mov     w9, #32
    strb    w9, [x0], #1
2:  mov     w1, w22
    bl      numcat
    mov     w9, #32
    strb    w9, [x0], #1
    add     x9, x19, x20, lsl #1
    ldrb    w9, [x9, #4]
    LA      x1, costnames
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    mov     w21, #1
3:  add     x20, x20, #1
    cmp     x20, #4
    b.lt    1b
    ldrb    w9, [x19, #2]
    cbz     w9, 4f
    LA      x1, s_plusfire
    bl      strcat_cur
4:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// place_check -> x0 = 0 se pode colocar ali (senao o motivo),
// s0/s1 = ponto (celulas), w1 = elevacao
place_check:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     d8, d9, [sp, #16]
    fmov    s8, wzr
    fmov    s9, wzr
    LA      x0, m_nopoint
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 9f
    ldr     w9, [x28, #G_HOVU]
    scvtf   s8, w9
    ldr     w9, [x28, #G_HOVV]
    scvtf   s9, w9
    FC      s2, F_INV64
    fmul    s8, s8, s2
    fmul    s9, s9, s2
    ldr     s2, [x28, #G_PU]            // ate 5 celulas do personagem
    ldr     s3, [x28, #G_PV]
    fsub    s2, s8, s2
    fsub    s3, s9, s3
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    FC      s3, F_FIRE2
    LA      x0, m_far
    fcmp    s2, s3
    b.gt    9f
    fmov    s0, s8
    fmov    s1, s9
    bl      elev_at
    mov     w1, w0
    LA      x0, m_water
    ldr     w9, [x28, #G_FLOOD]         // agua (ou enchente)
    cmp     w1, w9
    b.lt    9f
    ldr     w9, [x28, #G_PLACE]
    sub     w9, w9, #1
    cmp     w9, #IT_FIRE
    b.ne    1f
    ldr     w10, [x28, #G_NFIRE]
    LA      x0, m_toomanyfires
    cmp     w10, #MAXFIRE
    b.hs    9f
1:  mov     x0, #0
9:  fmov    s0, s8
    fmov    s1, s9
    ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// place_try: clique no mapa com uma construcao na mao
place_try:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    bl      place_check
    cbz     x0, 1f
    bl      set_msg
    b       9f
1:  fmov    s8, s0
    fmov    s9, s1
    mov     w19, w1                     // elevacao
    ldr     w20, [x28, #G_PLACE]
    sub     w20, w20, #1                // item
    cmp     w20, #IT_FIRE
    b.ne    2f
    ldr     w9, [x28, #G_NFIRE]         // fogueira: 4 min de fogo
    LA      x10, fires
    add     x10, x10, x9, lsl #4
    str     s8, [x10]
    str     s9, [x10, #4]
    str     w19, [x10, #8]
    MOVI32  w11, FIRETIME
    str     w11, [x10, #12]
    add     w9, w9, #1
    str     w9, [x28, #G_NFIRE]
    LA      x21, m_fire
    b       8f
2:  FC      s2, F_64
    fmul    s0, s8, s2
    fcvtzs  w21, s0
    fmul    s0, s9, s2
    fcvtzs  w22, s0
    cmp     w20, #IT_CHEST
    b.ne    4f
    LA      x9, chestused               // bau: pega um numero livre
    mov     x10, #0
3:  ldrb    w11, [x9, x10]
    cbz     w11, 31f
    add     x10, x10, #1
    cmp     x10, #MAXCHEST
    b.lt    3b
    LA      x0, m_toomanychests
    bl      set_msg
    b       9f
31: mov     w11, #1
    strb    w11, [x9, x10]
    LA      x11, chests
    add     x11, x11, x10, lsl #7
    stp     xzr, xzr, [x11]
    stp     xzr, xzr, [x11, #16]
    stp     xzr, xzr, [x11, #32]
    stp     xzr, xzr, [x11, #48]
    stp     xzr, xzr, [x11, #64]
    stp     xzr, xzr, [x11, #80]
    stp     xzr, xzr, [x11, #96]
    stp     xzr, xzr, [x11, #112]
    mov     w0, w21
    mov     w1, w22
    mov     w2, w19
    mov     w3, #O_CHEST
    mov     w4, w10
    bl      add_obj
    LA      x21, m_chestok
    b       7f
4:  mov     w0, w21                     // abrigo
    mov     w1, w22
    mov     w2, w19
    mov     w3, #O_SHELTER
    mov     w4, #0
    bl      add_obj
    ldr     w9, [x28, #G_NOBJ]
    sub     w9, w9, #1
    LA      x10, shelters               // guarda na lista (vaga livre)
    mov     x11, #0
5:  ldr     w12, [x10, x11, lsl #2]
    tbnz    w12, #31, 51f
    LA      x13, objs
    add     x13, x13, x12, lsl #3
    ldrb    w13, [x13, #6]
    cmp     w13, #O_SHELTER
    b.ne    51f
    add     x11, x11, #1
    cmp     x11, #MAXSHELTER
    b.lt    5b
    b       52f
51: str     w9, [x10, x11, lsl #2]
52: LA      x21, m_shelterok
7:  ldr     w9, [x28, #G_NOBJ]          // ja aparece (a vista)
    sub     w9, w9, #1
    LA      x11, objs
    add     x11, x11, x9, lsl #3
    ldrb    w12, [x11, #6]
    LA      x10, memtype
    strb    w12, [x10, x9]
8:  add     x9, x28, #G_INV             // gasta o item
    ldr     w10, [x9, x20, lsl #2]
    sub     w10, w10, #1
    str     w10, [x9, x20, lsl #2]
    cbnz    w10, 81f
    str     wzr, [x28, #G_PLACE]
81: bl      calc_stats
    mov     x0, x21
    bl      set_msg
9:  ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// in_shelter -> w0 = 1 se o personagem esta dentro de um abrigo
in_shelter:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     x19, #0
1:  LA      x9, shelters
    ldr     w20, [x9, x19, lsl #2]
    tbnz    w20, #31, 2f
    LA      x9, objs
    add     x9, x9, x20, lsl #3
    ldrb    w10, [x9, #6]
    cmp     w10, #O_SHELTER
    b.ne    2f
    mov     w0, w20
    bl      obj_dist2
    fmov    s1, #4.0                    // 2 celulas (a cabana e grande)
    fcmp    s0, s1
    b.gt    2f
    mov     w0, #1
    b       9f
2:  add     x19, x19, #1
    cmp     x19, #MAXSHELTER
    b.lt    1b
    mov     w0, #0
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// try_sleep(w0 = abrigo): deita na cabana (so a partir das 18h) e dorme
// ate amanhecer; a noite passa depressa (veja update em trilhos.S)
try_sleep:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w0
    bl      obj_dist2
    fmov    s1, #16.0                   // ate 4 celulas
    fcmp    s0, s1
    b.le    1f
    LA      x0, m_far
    bl      set_msg
    b       9f
1:  ldr     w9, [x28, #G_TIME]
    mov     w10, #T_DUSK
    cmp     w9, w10
    b.ge    2f
    LA      x0, m_notnight
    bl      set_msg
    b       9f
2:  LA      x9, objs                    // entra: fica no meio da cabana
    add     x9, x9, x19, lsl #3
    ldrh    w10, [x9]
    scvtf   s0, w10
    ldrh    w10, [x9, #2]
    scvtf   s1, w10
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    str     s0, [x28, #G_PU]
    str     s1, [x28, #G_PV]
    ldr     w9, [x28, #G_DAY]
    str     w9, [x28, #G_SLEEPDAY]
    mov     w9, #1
    str     w9, [x28, #G_SLEEP]
    str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_PLACE]
    str     wzr, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CRAFTOPEN]
    str     wzr, [x28, #G_CHESTOPEN]
    str     wzr, [x28, #G_CHAROPEN]
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// sleep_check: acorda quando o dia vira (06:00); antes, so se a agua
// subir ou se ficar fraco (fome, frio)
sleep_check:
    ldr     w9, [x28, #G_SLEEP]
    cbz     w9, 9f
    ldr     w10, [x28, #G_DAY]
    ldr     w11, [x28, #G_SLEEPDAY]
    LA      x0, m_morning
    cmp     w10, w11
    b.ne    1f
    LA      x0, m_wetwake
    ldr     w9, [x28, #G_WATER]
    cmp     w9, #2
    b.ge    1f
    LA      x0, m_weakwake
    ldr     s0, [x28, #G_HP]
    FC      s1, F_25
    fcmp    s0, s1
    b.lt    1f
9:  ret
1:  str     wzr, [x28, #G_SLEEP]
    b       set_msg

// chest_count(w0 = bau) -> w0 = itens dentro   folha
chest_count:
    LA      x9, chests
    add     x9, x9, x0, lsl #7
    mov     w0, #0
    mov     x10, #0
1:  ldr     w11, [x9, x10, lsl #2]
    add     w0, w0, w11
    add     x10, x10, #1
    cmp     x10, #NITEMS
    b.lt    1b
    ret

// chest_move(w0 = item, w1 = 0 mochila -> bau, 1 bau -> mochila): tudo
chest_move:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    ldr     w9, [x28, #G_CHESTOPEN]
    cbz     w9, 9f
    sub     w9, w9, #1
    LA      x19, chests
    add     x19, x19, x9, lsl #7
    mov     w20, w0
    cbnz    w1, 1f
    add     x9, x28, #G_INV
    ldr     w10, [x9, x20, lsl #2]
    str     wzr, [x9, x20, lsl #2]
    ldr     w11, [x19, x20, lsl #2]
    add     w11, w11, w10
    str     w11, [x19, x20, lsl #2]
    LA      x0, p_stored
    b       2f
1:  ldr     w1, [x19, x20, lsl #2]
    str     wzr, [x19, x20, lsl #2]
    mov     w0, w20
    bl      inv_add
    LA      x0, p_taken
2:  bl      popup
    bl      calc_stats
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// surv_mouse(w0 = botao, w1 = 1 apertou / 0 soltou)
    .globl surv_mouse
surv_mouse:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, sm_ret
    ldr     w9, [x28, #G_SLEEP]
    cbnz    w9, sm_ret
    mov     w19, w0
    mov     w20, w1
    cbnz    w20, 1f
    cmp     w19, #1                     // soltou o esquerdo: para de coletar
    b.ne    sm_ret
    str     wzr, [x28, #G_LMB]
    b       sm_ret
    // apertou: primeiro os botoes e janelas da interface
1:  bl      mouse_ui
    bl      ui_hit
    mov     w21, w1                     // quadrado / receita
    cmp     w0, #1                      // botao Mochila
    b.ne    2f
    ldr     w9, [x28, #G_INVOPEN]
    eor     w9, w9, #1
    str     w9, [x28, #G_INVOPEN]
    cbnz    w9, sm_ret
    str     wzr, [x28, #G_CHESTOPEN]
    b       sm_ret
2:  cmp     w0, #2                      // botao Personagem
    b.ne    21f
    ldr     w9, [x28, #G_CHAROPEN]
    eor     w9, w9, #1
    str     w9, [x28, #G_CHAROPEN]
    b       sm_ret
21: cmp     w0, #5                      // botao Fabricar
    b.ne    3f
    ldr     w9, [x28, #G_CRAFTOPEN]
    eor     w9, w9, #1
    str     w9, [x28, #G_CRAFTOPEN]
    cbz     w9, sm_ret
    str     wzr, [x28, #G_CHESTOPEN]
    b       sm_ret
3:  cmp     w0, #3                      // mochila
    b.ne    4f
    tbnz    w21, #31, sm_ret
    mov     w0, w21
    bl      inv_slot_item
    tbnz    w0, #31, sm_ret
    mov     w22, w0
    cmp     w19, #3
    b.eq    33f
    cmp     w19, #1
    b.ne    sm_ret
    ldr     w9, [x28, #G_CHESTOPEN]     // esquerdo: guarda no bau aberto,
    cbz     w9, 31f
    mov     w0, w22
    mov     w1, #0
    bl      chest_move
    b       sm_ret
31: cmp     w22, #IT_FIRSTBUILD         // ... coloca uma construcao
    b.lo    32f
    mov     w0, w22
    bl      start_place
    b       sm_ret
32: LA      x9, eatvalue            // ... come
    ldr     s0, [x9, x22, lsl #2]
    fcmp    s0, #0.0
    b.le    322f
    mov     w0, w22
    bl      eat_item
    b       sm_ret
322: LA     x9, hotbar                  // ... ou poe na mao
    mov     x10, #0
323: ldrb   w11, [x9, x10]
    cmp     w11, w22
    b.eq    324f
    add     x10, x10, #1
    cmp     x10, #4
    b.lt    323b
    b       sm_ret
324: mov    w0, w22
    bl      equip
    b       sm_ret
33: cmp     w22, #IT_FIRSTBUILD         // direito: larga 1 (Shift: tudo)
    b.lo    34f
    cmp     w22, #IT_LASTBUILD          // (construcoes nao)
    b.hi    34f
    LA      x0, m_nodrop
    bl      set_msg
    b       sm_ret
34: mov     w1, #1
    ldr     x9, [x28, #G_KEYS]
    ldrb    w10, [x9, #225]
    ldrb    w11, [x9, #229]
    orr     w10, w10, w11
    cbz     w10, 35f
    mov     w1, #255
35: mov     w0, w22
    bl      drop_item
    b       sm_ret
4:  cmp     w0, #6                      // fabricar: clique numa receita
    b.ne    5f
    cmp     w19, #1
    b.ne    sm_ret
    tbnz    w21, #31, sm_ret
    mov     w0, w21
    bl      craft
    b       sm_ret
5:  cmp     w0, #7                      // bau: clique pega tudo daquele item
    b.ne    6f
    cmp     w19, #1
    b.ne    sm_ret
    tbnz    w21, #31, sm_ret
    ldr     w9, [x28, #G_CHESTOPEN]
    sub     w9, w9, #1
    LA      x0, chests
    add     x0, x0, x9, lsl #7
    mov     w1, w21
    bl      slot_item
    tbnz    w0, #31, sm_ret
    mov     w1, #1
    bl      chest_move
    b       sm_ret
6:  cmp     w0, #8                      // barra "na mao"
    b.ne    62f
    tbnz    w21, #31, sm_ret
    LA      x9, hotbar
    ldrb    w0, [x9, x21]
    bl      equip
    b       sm_ret
62: cbnz    w0, sm_ret                  // janela do personagem: nada
    // ---- no mundo ----
    ldr     w9, [x28, #G_PLACE]         // colocando uma construcao?
    cbz     w9, 7f
    cmp     w19, #1
    b.ne    61f
    bl      place_try
    b       sm_ret
61: cmp     w19, #3
    b.ne    sm_ret
    str     wzr, [x28, #G_PLACE]
    LA      x0, m_placecancel
    bl      set_msg
    b       sm_ret
7:  cmp     w19, #1
    b.ne    8f
    ldr     w9, [x28, #G_HAND]          // arco na mao: atira
    cmp     w9, #(IT_BOW + 1)
    b.ne    71f
    bl      shoot_arrow
    b       sm_ret
71: ldr     w0, [x28, #G_HOVANIM]       // animal ao alcance: golpe
    tbnz    w0, #31, 72f
    bl      melee_attack
    cbnz    w0, sm_ret
72: mov     w9, #1                      // senao: coletar
    str     w9, [x28, #G_LMB]
    b       sm_ret
8:  cmp     w19, #3
    b.ne    sm_ret
    ldr     w21, [x28, #G_HOVOBJ]       // direito num bau: abre
    tbnz    w21, #31, 81f
    LA      x9, objs
    add     x9, x9, x21, lsl #3
    ldrb    w10, [x9, #6]
    cmp     w10, #O_SHELTER             // direito no abrigo: dorme
    b.ne    80f
    mov     w0, w21
    bl      try_sleep
    b       sm_ret
80: cmp     w10, #O_CHEST
    b.ne    81f
    mov     w0, w21
    bl      obj_dist2
    FC      s1, F_REACH2
    fcmp    s0, s1
    b.le    82f
    LA      x0, m_far
    bl      set_msg
    b       sm_ret
82: LA      x9, objs
    add     x9, x9, x21, lsl #3
    ldrb    w10, [x9, #7]
    add     w10, w10, #1
    str     w10, [x28, #G_CHESTOPEN]
    str     w21, [x28, #G_CHESTOBJ]
    mov     w9, #1
    str     w9, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CRAFTOPEN]
    b       sm_ret
81: ldr     w19, [x28, #G_HOVFIRE]      // direito numa fogueira: lenha
    tbnz    w19, #31, sm_ret
    mov     w0, w19
    bl      fire_dist2
    FC      s1, F_REACH2
    fcmp    s0, s1
    b.le    83f
    LA      x0, m_far
    bl      set_msg
    b       sm_ret
83: ldr     w9, [x28, #G_WOOD]
    cbnz    w9, 84f
    LA      x0, m_nowood
    bl      set_msg
    b       sm_ret
84: sub     w9, w9, #1
    str     w9, [x28, #G_WOOD]
    bl      calc_stats
    LA      x10, fires
    add     x10, x10, x19, lsl #4
    ldr     w11, [x10, #12]
    mov     w12, #FIREWOOD              // +2 min
    add     w11, w11, w12
    MOVI32  w12, FIREMAX
    cmp     w11, w12
    csel    w11, w12, w11, gt
    str     w11, [x10, #12]
    LA      x0, p_log
    bl      popup
sm_ret:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// =====================================================================
//  Desenho do personagem e das fogueiras (com z-buffer)
// =====================================================================
    .globl surv_draw
surv_draw:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    bl      sprite_scale
    mov     w21, w0
    // fogueiras
    mov     w19, #0
1:  ldr     w9, [x28, #G_NFIRE]
    cmp     w19, w9
    b.ge    2f
    LA      x20, fires
    add     x20, x20, x19, lsl #4
    ldr     s0, [x20]
    ldr     s1, [x20, #4]
    ldr     w0, [x20, #8]
    bl      proj
    mov     w4, w2
    add     w4, w4, #16
    mov     w2, w1
    mov     w1, w0
    ldr     w9, [x28, #G_FRAME]
    lsr     w9, w9, #3
    add     w9, w9, w19
    and     w9, w9, #1
    add     w9, w9, #SPR_FIRE
    LA      x0, sprites
    add     x0, x0, x9, lsl #7
    mov     w3, w21
    mov     w5, #0
    bl      blit
    add     w19, w19, #1
    b       1b
    // animais e flechas
2:  mov     w0, w21
    bl      animals_draw
    bl      arrows_draw
    ldr     w9, [x28, #G_SLEEP]         // dormindo: esta dentro da cabana
    cbnz    w9, 50f
    // personagem
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    ldr     w0, [x28, #G_PE]
    bl      proj
    mov     w4, w2
    add     w4, w4, #24
    mov     w2, w1
    mov     w1, w0
    mov     w9, #SPR_PLAYER
    ldr     w11, [x28, #G_WATER]
    cmp     w11, #2
    b.lt    21f
    mov     w9, #SPR_SWIM               // nadando (sempre batendo os bracos)
    ldr     w10, [x28, #G_FRAME]
    lsr     w10, w10, #4
    and     w10, w10, #1
    add     w9, w9, w10
    b       3f
21: ldr     w10, [x28, #G_PMOVING]
    cbz     w10, 3f
    ldr     w10, [x28, #G_PFRAME]
    lsr     w10, w10, #3
    and     w10, w10, #1
    add     w9, w9, w10
3:  LA      x0, sprites
    add     x0, x0, x9, lsl #7
    mov     w3, w21
    mov     w5, #0
    bl      blit
    // barbatana do tubarao rondando, cada vez mais perto
    ldr     w19, [x28, #G_SHARK]
    cmp     w19, #60
    b.lt    4f
    ldr     w9, [x28, #G_FRAME]
    lsr     w10, w9, #3
    and     w10, w10, #15               // direcao atual (16 direcoes)
    and     w11, w9, #7                 // fracao ate a proxima
    add     w12, w10, #1
    and     w12, w12, #15
    LA      x13, dirtab
    add     x14, x13, x10, lsl #2
    add     x15, x13, x12, lsl #2
    ldrsh   w0, [x14]
    ldrsh   w1, [x15]
    sub     w1, w1, w0
    mul     w1, w1, w11
    add     w0, w0, w1, asr #3          // cos * 64
    ldrsh   w2, [x14, #2]
    ldrsh   w3, [x15, #2]
    sub     w3, w3, w2
    mul     w3, w3, w11
    add     w2, w2, w3, asr #3          // sen * 64
    scvtf   s2, w0
    scvtf   s3, w2
    FC      s4, F_INV64
    fmul    s2, s2, s4
    fmul    s3, s3, s4
    scvtf   s4, w19                     // raio: 3 celulas -> 0.75
    mov     w9, #SHARKTIME
    scvtf   s5, w9
    fdiv    s4, s4, s5
    fmov    s5, #0.75
    fmul    s4, s4, s5
    fmov    s5, #1.0
    fsub    s4, s5, s4
    FC      s5, F_SHARKR
    fmul    s4, s4, s5
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    fmadd   s0, s2, s4, s0
    fmadd   s1, s3, s4, s1
    mov     w0, #0
    bl      proj
    mov     w4, w2
    add     w4, w4, #16
    mov     w2, w1
    mov     w1, w0
    LA      x0, sprites
    add     x0, x0, #(SPR_FIN * 128)
    mov     w3, w21
    mov     w5, #0
    bl      blit
    // tocha acesa na mao
4:  ldr     w9, [x28, #G_TORCHLIT]
    cbz     w9, 5f
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    ldr     w0, [x28, #G_PE]
    bl      proj
    mov     w4, w2
    add     w4, w4, #26
    sub     w2, w1, w21                 // um pouco acima e ao lado
    mov     w9, #3
    madd    w1, w21, w9, w0
    LA      x0, sprites
    add     x0, x0, #(SPR_TORCH * 128)
    mov     w3, w21
    mov     w5, #0
    bl      blit
    // o que esta na mao principal (machado, picareta, arco), do outro lado
5:  ldr     w19, [x28, #G_HAND]
    cbz     w19, 50f
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    ldr     w0, [x28, #G_PE]
    bl      proj
    mov     w4, w2
    add     w4, w4, #26
    mov     w2, w1
    mov     w9, #3
    msub    w1, w21, w9, w0
    sub     w9, w19, #1
    LA      x10, itemicon
    ldrb    w9, [x10, x9]
    LA      x0, sprites
    add     x0, x0, x9, lsl #7
    mov     w3, w21
    mov     w5, #0
    bl      blit
    // previa da construcao no mouse (pisca se nao der para colocar)
50: ldr     w19, [x28, #G_PLACE]
    cbz     w19, 6f
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 6f
    bl      place_check
    cbz     x0, 51f
    ldr     w9, [x28, #G_FRAME]
    tbnz    w9, #3, 6f
51: cmp     w1, #0
    csel    w0, w1, wzr, ge
    bl      proj
    mov     w4, w2
    add     w4, w4, #16
    mov     w2, w1
    mov     w1, w0
    sub     w9, w19, #1
    LA      x10, itemicon
    ldrb    w9, [x10, x9]
    LA      x0, sprites
    add     x0, x0, x9, lsl #7
    mov     w3, w21
    mov     w5, #0
    bl      blit
6:  ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// =====================================================================
//  Noite: escurece a imagem e soma a luz do fogo
// =====================================================================

// add_light(w0 cx, w1 cy, w2 raio x, w3 intensidade): elipse de luz
// no buffer de luz (o raio vertical e a metade, como no chao isometrico)
// folha: usa x0-x15
add_light:
    cmp     w2, #2
    b.lt    9f
    lsr     w4, w2, #1                  // raio y
    sub     w5, w0, w2
    cmp     w5, #0
    csel    w5, wzr, w5, lt             // x0
    add     w6, w0, w2
    mov     w7, #(SCRW - 1)
    cmp     w6, w7
    csel    w6, w7, w6, gt              // x1
    sub     w7, w1, w4
    cmp     w7, #0
    csel    w7, wzr, w7, lt             // y0
    add     w8, w1, w4
    mov     w9, #(SCRH - 1)
    cmp     w8, w9
    csel    w8, w9, w8, gt              // y1
    cmp     w5, w6
    b.gt    9f
    cmp     w7, w8
    b.gt    9f
    mul     w2, w2, w2                  // R^2
    LA      x15, lightbuf
1:  sub     w9, w7, w1
    lsl     w9, w9, #1
    mul     w9, w9, w9                  // (2*dy)^2
    mov     w10, w5
2:  sub     w11, w10, w0
    madd    w11, w11, w11, w9           // d^2
    cmp     w11, w2
    b.ge    3f
    sub     w11, w2, w11
    mul     w11, w11, w3
    udiv    w11, w11, w2                // intensidade * (1 - d^2/R^2)
    add     w12, w10, w7, lsl #10
    add     w12, w12, w7, lsl #8
    ldrb    w13, [x15, w12, uxtw]
    cmp     w11, w13
    b.ls    3f
    strb    w11, [x15, w12, uxtw]
3:  add     w10, w10, #1
    cmp     w10, w6
    b.le    2b
    add     w7, w7, #1
    cmp     w7, w8
    b.le    1b
9:  ret

    .globl surv_light
surv_light:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    ldr     w9, [x28, #G_AMBR]
    cmp     w9, #255
    b.lt    1f
    ldr     w9, [x28, #G_AMBB]
    cmp     w9, #255
    b.ge    sl_post                     // de dia: so a neblina
1:  LA      x9, lightbuf                // zera o buffer de luz
    mov     w10, #(SCRW * SCRH / 16)
2:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    2b
    ldr     w21, [x28, #G_Z256]
    // luz das fogueiras (9 celulas, tremulando)
    mov     w19, #0
3:  ldr     w9, [x28, #G_NFIRE]
    cmp     w19, w9
    b.ge    4f
    LA      x20, fires
    add     x20, x20, x19, lsl #4
    ldr     s0, [x20]
    ldr     s1, [x20, #4]
    ldr     w0, [x20, #8]
    bl      proj
    mov     w22, #36                    // 9 celulas
    mul     w22, w22, w21
    lsr     w22, w22, #8                // raio base
    ldr     w9, [x28, #G_FRAME]
    lsr     w9, w9, #2
    mov     w10, #29
    madd    w9, w19, w10, w9
    and     w9, w9, #0xFFFF
    LA      x10, noisetab
    ldrb    w9, [x10, w9, uxtw]
    and     w9, w9, #7
    sub     w9, w9, #3
    mul     w9, w9, w21
    asr     w9, w9, #8
    add     w2, w22, w9
    mov     w9, #4
    mul     w9, w9, w21
    asr     w9, w9, #8
    sub     w1, w1, w9                  // centro um pouco acima do chao
    mov     w3, #255
    bl      add_light
    add     w19, w19, #1
    b       3b
    // lanterna fraca do personagem (com tocha: bem mais forte)
4:  ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    ldr     w0, [x28, #G_PE]
    bl      proj
    mov     w2, #10
    mov     w3, #110
    ldr     w9, [x28, #G_TORCHLIT]
    cbz     w9, 41f
    ldr     w9, [x28, #G_FRAME]         // tremula um pouco
    lsr     w9, w9, #2
    and     w9, w9, #0xFFFF
    LA      x10, noisetab
    ldrb    w9, [x10, w9, uxtw]
    and     w9, w9, #3
    add     w2, w9, #26                 // ~7 celulas
    mov     w3, #235
41: mul     w2, w2, w21
    lsr     w2, w2, #8
    mov     w9, #4
    mul     w9, w9, w21
    asr     w9, w9, #8
    sub     w1, w1, w9
    bl      add_light
    // passada final (neblina + luz) dividida entre as threads
sl_post:
    LA      x0, post_cols
    bl      par_cols
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// post_cols(w0 = primeira coluna, w1 = coluna final exclusiva)
// Para cada pixel: acha o ponto do mundo pelo z-buffer, le a visao e a
// memoria (interpolados) e aplica a neblina; de noite aplica a luz.
//   nunca visto  -> preto
//   ja visto     -> mais escuro e sem cor (o que a gente lembra)
//   a vista      -> normal
// folha: usa x0-x17
    .globl post_cols
post_cols:
    sub     sp, sp, #64
    str     w0, [sp]
    str     w1, [sp, #4]
    ldr     w9, [x28, #G_K]
    str     w9, [sp, #8]
    mov     w10, #640
    mul     w10, w10, w9
    ldr     w11, [x28, #G_CX]
    sub     w11, w11, w10
    str     w11, [sp, #12]              // (u-v) da coluna 0
    ldr     w9, [x28, #G_AMBR]
    str     w9, [sp, #16]
    ldr     w9, [x28, #G_AMBG]
    str     w9, [sp, #20]
    ldr     w9, [x28, #G_AMBB]
    str     w9, [sp, #24]
    mov     w10, #0                     // tem luz de noite?
    ldr     w9, [x28, #G_AMBR]
    cmp     w9, #255
    cset    w10, lt
    ldr     w9, [x28, #G_AMBB]
    cmp     w9, #255
    cinc    w10, w10, lt
    str     w10, [sp, #28]
    LA      x16, fb
    LA      x17, zb
    LA      x15, lightbuf
    LA      x14, vis
    LA      x13, seen
    mov     w12, #0                     // y
pc_row:
    ldr     w11, [sp]                   // x
pc_px:
    add     w10, w11, w12, lsl #10
    add     w10, w10, w12, lsl #8       // indice do pixel
    ldrh    w0, [x17, w10, uxtw #1]     // profundidade = (u+v)
    ldr     w1, [sp, #8]
    ldr     w2, [sp, #12]
    madd    w1, w11, w1, w2             // (u-v) desta coluna
    add     w2, w0, w1
    asr     w2, w2, #1                  // u (1/64 de celula)
    sub     w3, w0, w1
    asr     w3, w3, #1                  // v
    mov     w4, #32640
    cmp     w2, w4
    b.hs    pc_black
    cmp     w3, w4
    b.hs    pc_black
    lsr     w4, w2, #6
    lsr     w5, w3, #6
    add     w4, w4, w5, lsl #9          // celula
    and     w2, w2, #63
    lsl     w2, w2, #2                  // fracao u (0..252)
    and     w3, w3, #63
    lsl     w3, w3, #2                  // fracao v
    add     x5, x13, w4, uxtw           // memoria (bilinear)
    ldrb    w6, [x5]
    ldrb    w7, [x5, #1]
    sub     w7, w7, w6
    mul     w7, w7, w2
    add     w6, w6, w7, asr #8
    ldrb    w7, [x5, #512]
    ldrb    w8, [x5, #513]
    sub     w8, w8, w7
    mul     w8, w8, w2
    add     w7, w7, w8, asr #8
    sub     w7, w7, w6
    mul     w7, w7, w3
    add     w6, w6, w7, asr #8          // S
    cbz     w6, pc_black
    add     x5, x14, w4, uxtw           // visao agora (bilinear)
    ldrb    w9, [x5]
    ldrb    w7, [x5, #1]
    sub     w7, w7, w9
    mul     w7, w7, w2
    add     w9, w9, w7, asr #8
    ldrb    w7, [x5, #512]
    ldrb    w8, [x5, #513]
    sub     w8, w8, w7
    mul     w8, w8, w2
    add     w7, w7, w8, asr #8
    sub     w7, w7, w9
    mul     w7, w7, w3
    add     w9, w9, w7, asr #8          // V
    ldr     w0, [x16, w10, uxtw #2]
    ubfx    w1, w0, #16, #8             // r
    ubfx    w2, w0, #8, #8              // g
    and     w3, w0, #255                // b
    mov     w4, #77                     // cinza
    mul     w4, w1, w4
    mov     w5, #151
    madd    w4, w2, w5, w4
    mov     w5, #28
    madd    w4, w3, w5, w4
    lsr     w4, w4, #8
    // lembrado = (cor + cinza) / 4 ; final = lembrado + (cor - lembrado) * V
    add     w5, w1, w4
    lsr     w5, w5, #2
    sub     w7, w1, w5
    mul     w7, w7, w9
    add     w1, w5, w7, asr #8
    mul     w1, w1, w6
    lsr     w1, w1, #8
    add     w5, w2, w4
    lsr     w5, w5, #2
    sub     w7, w2, w5
    mul     w7, w7, w9
    add     w2, w5, w7, asr #8
    mul     w2, w2, w6
    lsr     w2, w2, #8
    add     w5, w3, w4
    lsr     w5, w5, #2
    add     w5, w5, #6                  // um pouco azulado
    sub     w7, w3, w5
    mul     w7, w7, w9
    add     w3, w5, w7, asr #8
    mul     w3, w3, w6
    lsr     w3, w3, #8
    // luz da noite
    ldr     w5, [sp, #28]
    cbz     w5, pc_store
    ldrb    w5, [x15, w10, uxtw]        // luz das fogueiras
    mov     w8, #255
    ldr     w7, [sp, #16]
    mov     w4, #294
    mul     w4, w5, w4
    add     w7, w7, w4, lsr #8
    mul     w1, w1, w7
    lsr     w1, w1, #8
    cmp     w1, w8
    csel    w1, w1, w8, ls
    ldr     w7, [sp, #20]
    mov     w4, #225
    mul     w4, w5, w4
    add     w7, w7, w4, lsr #8
    mul     w2, w2, w7
    lsr     w2, w2, #8
    cmp     w2, w8
    csel    w2, w2, w8, ls
    ldr     w7, [sp, #24]
    mov     w4, #150
    mul     w4, w5, w4
    add     w7, w7, w4, lsr #8
    mul     w3, w3, w7
    lsr     w3, w3, #8
    cmp     w3, w8
    csel    w3, w3, w8, ls
pc_store:
    orr     w0, w3, w2, lsl #8
    orr     w0, w0, w1, lsl #16
    orr     w0, w0, #0xFF000000
    str     w0, [x16, w10, uxtw #2]
    b       pc_next
pc_black:
    mov     w0, #0xFF000000
    str     w0, [x16, w10, uxtw #2]
pc_next:
    add     w11, w11, #1
    ldr     w4, [sp, #4]
    cmp     w11, w4
    b.lt    pc_px
    add     w12, w12, #1
    cmp     w12, #SCRH
    b.lt    pc_row
    add     sp, sp, #64
    ret

// =====================================================================
//  Visao (neblina de guerra)
// =====================================================================

// build_treegrid: conta as arvores de cada celula e esquece tudo
    .globl build_treegrid
build_treegrid:
    LA      x9, treecnt
    mov     w10, #(MAPN * MAPN / 16)
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    LA      x9, treecnt
    LA      x10, objs
    LA      x11, memtype
    mov     w15, #254                   // 254 = nunca visto
    ldr     w12, [x28, #G_NOBJ]
2:  cbz     w12, 9f
    strb    w15, [x11], #1
    ldrb    w13, [x10, #6]
    cmp     w13, #O_PINE
    b.hi    3f
    ldrh    w13, [x10]
    lsr     w13, w13, #6
    ldrh    w14, [x10, #2]
    lsr     w14, w14, #6
    add     w13, w13, w14, lsl #9
    ldrb    w14, [x9, w13, uxtw]
    cmp     w14, #255
    cinc    w14, w14, lo
    strb    w14, [x9, w13, uxtw]
3:  add     x10, x10, #8
    sub     w12, w12, #1
    b       2b
9:  ret

// cast_vision(s0 = u, s1 = v, s2 = raio): 360 raios a partir do ponto.
// Cada arvore no caminho tapa um pouco; o raio para quando fica opaco.
// Marca a visao agora (vis) e a memoria (seen). folha: x0-x15, s0-s3, s16-s31
cast_vision:
    fmov    s16, s0
    fmov    s17, s1
    fmov    s18, s2
    FC      s19, F_COS1
    FC      s20, F_SIN1
    fmov    s21, #1.0                   // direcao do raio
    fmov    s22, wzr
    FC      s23, F_RAYSTEP
    FC      s24, F_P7
    fmul    s24, s24, s18               // ate 70% do raio: visao cheia
    FC      s25, F_TREEBLK
    FC      s26, F_P3
    fmul    s26, s26, s18
    fmov    s27, #1.0
    fdiv    s26, s27, s26               // 1 / (30% do raio)
    FC      s30, F_255
    FC      s31, F_P8
    LA      x10, vis
    LA      x11, seen
    LA      x12, treecnt
    mov     w13, #360
cv_ray:
    fmov    s28, wzr                    // distancia
    fmov    s29, #1.0                   // transparencia
    mov     w14, #-1                    // ultima celula
cv_step:
    fmadd   s0, s21, s28, s16
    fmadd   s1, s22, s28, s17
    fcvtzs  w0, s0
    fcvtzs  w1, s1
    cmp     w0, #511
    b.hs    cv_end
    cmp     w1, #511
    b.hs    cv_end
    add     w2, w0, w1, lsl #9
    cmp     w2, w14
    b.eq    cv_next
    mov     w14, w2
    fmov    s2, #1.0
    fcmp    s28, s24
    b.le    1f
    fsub    s2, s18, s28                // borda suave
    fmul    s2, s2, s26
1:  fmul    s2, s2, s29
    fmul    s2, s2, s30
    fcvtzs  w3, s2
    cmp     w3, #0
    csel    w3, wzr, w3, lt
    ldrb    w4, [x10, x2]
    cmp     w3, w4
    b.ls    2f
    strb    w3, [x10, x2]
2:  ldrb    w4, [x11, x2]
    cmp     w3, w4
    b.ls    3f
    strb    w3, [x11, x2]
3:  fcmp    s28, s31                    // a propria celula nao tapa
    b.lt    cv_next
    ldrb    w4, [x12, x2]
    cbz     w4, cv_next
    scvtf   s3, w4
    fmsub   s29, s3, s25, s29           // cada arvore tapa um pouco
    fcmp    s29, #0.0
    b.le    cv_end
cv_next:
    fadd    s28, s28, s23
    fcmp    s28, s18
    b.lt    cv_step
cv_end:
    fmul    s0, s21, s19                // gira 1 grau
    fmsub   s0, s22, s20, s0
    fmul    s1, s21, s20
    fmadd   s1, s22, s19, s1
    fmov    s21, s0
    fmov    s22, s1
    subs    w13, w13, #1
    b.ne    cv_ray
    ret

// update_vision: recalcula o que esta a vista (personagem + fogueiras)
update_vision:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    LA      x9, vis
    mov     w10, #(MAPN * MAPN / 16)
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b
    // raio: 15 celulas de dia, 5 de noite (gradual no entardecer)
    ldr     w9, [x28, #G_NIGHTK]
    scvtf   s0, w9
    FC      s1, F_VISDAY
    FC      s2, F_VISNIGHT
    fsub    s3, s2, s1
    fmul    s3, s3, s0
    FC      s4, F_INV256
    fmul    s3, s3, s4
    fadd    s2, s1, s3
    ldr     s3, [x28, #G_WVIS]          // chuva, tempestade, neve: menos visao
    fmul    s2, s2, s3
    ldr     w9, [x28, #G_TORCHLIT]      // tocha: enxerga 10 celulas de noite
    cbz     w9, 1f
    FC      s3, F_TORCHVIS
    fmax    s2, s2, s3
1:  ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    bl      cast_vision
    // fogueiras iluminam em volta
    mov     w19, #0
2:  ldr     w9, [x28, #G_NFIRE]
    cmp     w19, w9
    b.ge    3f
    LA      x20, fires
    add     x20, x20, x19, lsl #4
    ldr     s0, [x20]
    ldr     s1, [x20, #4]
    FC      s2, F_FIREVIS
    bl      cast_vision
    add     w19, w19, #1
    b       2b
3:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// =====================================================================
//  Interface (espaco de texto 640x360, escala 2)
// =====================================================================

// surv_clock(x0 = cursor): "   -   Dia 2   03:20   Primavera, Sol"
surv_clock:
    b       surv_status

// surv_status(x0 = cursor em txt): acrescenta dia e hora
    .globl surv_status
surv_status:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    LA      x1, s_dia
    bl      strcat_cur
    ldr     w1, [x28, #G_DAY]
    bl      numcat
    LA      x1, s_sp3
    bl      strcat_cur
    ldr     w9, [x28, #G_TIME]          // minutos = tempo * 1440 / DAYLEN + 6h
    mov     w10, #1440
    mul     w9, w9, w10
    MOVI32  w10, DAYLEN
    udiv    w9, w9, w10
    add     w9, w9, #360
    mov     w10, #60
    udiv    w19, w9, w10                // horas
    msub    w20, w19, w10, w9           // minutos
    mov     w10, #24
    udiv    w11, w19, w10
    msub    w19, w11, w10, w19
    cmp     w19, #10
    b.ge    1f
    mov     w9, #48
    strb    w9, [x0], #1
1:  mov     w1, w19
    bl      numcat
    mov     w9, #58                     // ':'
    strb    w9, [x0], #1
    cmp     w20, #10
    b.ge    2f
    mov     w9, #48
    strb    w9, [x0], #1
2:  mov     w1, w20
    bl      numcat
    bl      weather_status              // "   Primavera, Chuva"
    ldr     w9, [x28, #G_PAUSE]
    cbz     w9, 3f
    LA      x1, s_paused
    bl      strcat_cur
3:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// bar(w0 = y, x1 = rotulo, s0 = valor 0..100, w2/w3/w4 = cor)
// o rotulo fica em x = 10 e a barra (120 de largura) em x = 70
bar:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     d8, [sp, #48]
    mov     w19, w0
    mov     x20, x1
    fmov    s8, s0
    mov     w21, w2
    mov     w22, w3
    str     w4, [sp, #56]
    mov     w0, #220
    mov     w1, #220
    mov     w2, #220
    mov     w3, #255
    bl      setcolor
    mov     w0, #10
    mov     w1, w19
    mov     x2, x20
    bl      text
    mov     w0, #40
    mov     w1, #40
    mov     w2, #40
    mov     w3, #255
    bl      setcolor
    mov     w0, #70
    sub     w1, w19, #1
    mov     w2, #120
    mov     w3, #9
    bl      fillrect
    mov     w0, w21
    mov     w1, w22
    ldr     w2, [sp, #56]
    mov     w3, #255
    bl      setcolor
    mov     w9, #120                    // largura = valor * 1.2
    scvtf   s1, w9
    fmul    s0, s8, s1
    FC      s1, F_HUNDRED
    fdiv    s0, s0, s1
    fcvtzs  w2, s0
    cbz     w2, 1f
    mov     w0, #70
    sub     w1, w19, #1
    mov     w3, #9
    bl      fillrect
1:  ldr     d8, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

    .globl surv_ui
surv_ui:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    bl      weather_overlay             // cor do clima e relampago
    // ---- painel: inventario e barras ----
    mov     w0, #0
    mov     w1, #0
    mov     w2, #0
    mov     w3, #150
    bl      setcolor
    mov     w0, #4
    mov     w1, #16
    mov     w2, #252
    mov     w3, #73
    bl      fillrect
    LA      x0, lbuf
    LA      x1, s_wood
    bl      strcat_cur
    ldr     w1, [x28, #G_WOOD]
    bl      numcat
    LA      x1, s_stone
    bl      strcat_cur
    ldr     w1, [x28, #G_STONE]
    bl      numcat
    LA      x1, s_berry
    bl      strcat_cur
    ldr     w1, [x28, #G_BERRY]
    bl      numcat
    mov     w0, #255
    mov     w1, #235
    mov     w2, #180
    mov     w3, #255
    bl      setcolor
    mov     w0, #10
    mov     w1, #21
    LA      x2, lbuf
    bl      text
    mov     w0, #36
    LA      x1, s_hp
    ldr     s0, [x28, #G_HP]
    mov     w2, #215
    mov     w3, #60
    mov     w4, #50
    bl      bar
    mov     w0, #49
    LA      x1, s_food
    ldr     s0, [x28, #G_FOOD]
    mov     w2, #235
    mov     w3, #150
    mov     w4, #40
    bl      bar
    // fome cheia: "cheia" e um filete com o tempo que ainda segura
    ldr     w19, [x28, #G_SATED]
    cbz     w19, 2f
    RGBA    70, 40, 10, 255             // "cheia" escrito dentro da barra
    mov     w0, #(190 - 5 * 8 - 2)
    mov     w1, #49
    LA      x2, s_full
    bl      text
    RGBA    255, 240, 170, 255
    mov     w9, #120
    mul     w2, w19, w9
    mov     w9, #SATTIME
    udiv    w2, w2, w9
    cbz     w2, 2f
    mov     w0, #70
    mov     w1, #57
    mov     w3, #2
    bl      fillrect
2:  mov     w0, #62
    LA      x1, s_warm
    ldr     s0, [x28, #G_WARM]
    mov     w2, #80
    mov     w3, #160
    mov     w4, #240
    bl      bar
    mov     w0, #75                     // stamina: barra = atual / maximo
    LA      x1, s_stamina
    ldr     s0, [x28, #G_STAMINA]
    ldr     s1, [x28, #G_STAMAX]
    fdiv    s0, s0, s1
    FC      s1, F_HUNDRED
    fmul    s0, s0, s1
    mov     w2, #120
    mov     w3, #225
    mov     w4, #210
    bl      bar
    LA      x0, lbuf                    // "85/140"
    ldr     s0, [x28, #G_STAMINA]
    fcvtzs  w1, s0
    bl      numcat
    mov     w9, #47
    strb    w9, [x0], #1
    ldr     s0, [x28, #G_STAMAX]
    fcvtzs  w1, s0
    bl      numcat
    LA      x0, lbuf                    // dentro da barra, a direita
    bl      mystrlen
    lsl     w19, w0, #3
    RGBA    20, 50, 50, 255
    mov     w0, #188
    sub     w0, w0, w19
    mov     w1, #75
    LA      x2, lbuf
    bl      text
    // ---- avisos embaixo das barras (empilhados a partir de y = 94) ----
    mov     w20, #94
    ldr     w9, [x28, #G_WATER]         // na agua?
    cbz     w9, ui_heavy
    LA      x10, waternames
    add     x19, x10, x9, lsl #5
    mov     w0, #150                    // raso / nadando: azul claro
    mov     w1, #210
    mov     w2, #255
    mov     w3, #255
    cmp     w9, #3
    b.ne    1f
    mov     w0, #255                    // mar aberto: vermelho piscando
    mov     w1, #70
    mov     w2, #60
    ldr     w10, [x28, #G_FRAME]
    tbz     w10, #4, 1f
    mov     w1, #200
    mov     w2, #190
1:  bl      setcolor
    mov     w0, #8
    mov     w1, w20
    mov     x2, x19
    bl      text
    add     w20, w20, #10
ui_heavy:
    ldr     w9, [x28, #G_WEIGHT]        // sobrecarregado?
    ldr     w10, [x28, #G_CAP]
    cmp     w9, w10
    b.le    ui_torch
    RGBA    255, 150, 70, 255
    mov     w0, #8
    mov     w1, w20
    LA      x2, s_heavy
    bl      text
    add     w20, w20, #10
ui_torch:
    ldr     w9, [x28, #G_TORCHLIT]      // tocha acesa: quanto ainda dura
    cbz     w9, ui_shelter
    LA      x0, lbuf
    LA      x1, s_torchlbl
    bl      strcat_cur
    ldr     w1, [x28, #G_TORCHT]
    mov     w9, #60
    udiv    w1, w1, w9
    bl      numcat
    LA      x1, s_sec
    bl      strcat_cur
    ldr     w1, [x28, #(G_INV + 4 * IT_TORCH)]
    subs    w1, w1, #1                  // (a acesa conta na mochila)
    b.le    1f
    mov     w19, w1
    LA      x1, s_torchmore
    bl      strcat_cur
    mov     w1, w19
    bl      numcat
    LA      x1, s_paren2
    bl      strcat_cur
1:  RGBA    255, 210, 110, 255
    mov     w0, #8
    mov     w1, w20
    LA      x2, lbuf
    bl      text
    add     w20, w20, #10
ui_shelter:
    ldr     w9, [x28, #G_INSHELTER]     // dentro do abrigo
    cbnz    w9, 2f
    ldr     s0, [x28, #G_WHAIL]         // granizo e voce fora do abrigo
    fcmp    s0, #0.0
    b.le    ui_tip
    RGBA    255, 110, 100, 255
    mov     w0, #8
    mov     w1, w20
    LA      x2, s_hailbl
    bl      text
    b       ui_tip
2:
    RGBA    170, 230, 160, 255
    mov     w0, #8
    mov     w1, w20
    LA      x2, s_shelterlbl
    bl      text
ui_tip:
    bl      ui_windows                  // botoes, mochila e personagem
    ldr     w9, [x28, #G_PLACE]         // colocando uma construcao: so a
    cbz     w9, ui_tip2                 // dica dela
    bl      place_tip
    b       ui_pop
ui_tip2:
    ldr     w1, [x28, #G_HOVANIM]       // um animal sob o mouse
    tbnz    w1, #31, ui_tip3
    LA      x0, lbuf
    bl      animal_desc
    mov     w22, #1
    cbz     w1, 1f
    mov     w22, #2                     // perigoso: vermelho
1:  bl      mouse_ui
    add     w19, w0, #10
    add     w20, w1, #6
    bl      tooltip_box
    b       ui_pop
ui_tip3:

    // ---- dica sobre o que esta sob o mouse ----
    ldr     s0, [x28, #G_MX]
    fcvtzs  w19, s0
    asr     w19, w19, #1
    add     w19, w19, #10
    ldr     s0, [x28, #G_MY]
    fcvtzs  w20, s0
    asr     w20, w20, #1
    add     w20, w20, #6
    ldr     w21, [x28, #G_HOVOBJ]
    tbnz    w21, #31, ui_fire
    LA      x9, objs
    add     x9, x9, x21, lsl #3
    ldrb    w10, [x9, #6]
    ldrb    w11, [x9, #7]
    LA      x0, lbuf
    LA      x1, objnames
    add     x1, x1, x10, lsl #5
    bl      strcat_cur
    LA      x9, objs
    add     x9, x9, x21, lsl #3
    ldrb    w10, [x9, #6]
    cmp     w10, #O_BUSHE
    b.eq    1f
    cmp     w10, #O_CHEST               // bau e abrigo: sem quantidade
    b.hs    1f
    LA      x1, s_paren
    bl      strcat_cur
    LA      x9, objs
    add     x9, x9, x21, lsl #3
    ldrb    w1, [x9, #7]
    bl      numcat
    LA      x1, s_paren2
    bl      strcat_cur
1:  mov     w0, w21
    bl      obj_dist2
    FC      s1, F_REACH2
    fcmp    s0, s1
    cset    w22, le                     // 1 = ao alcance
    b.le    2f
    LA      x1, s_far
    LA      x0, lbuf
3:  ldrb    w9, [x0]
    cbz     w9, 4f
    add     x0, x0, #1
    b       3b
4:  bl      strcat_cur
2:  bl      tooltip_box
    // barra de progresso da coleta
    ldr     w9, [x28, #G_MINEOBJ]
    cmp     w9, w21
    b.ne    ui_pop
    ldr     w9, [x28, #G_MINEPROG]
    cbz     w9, ui_pop
    mov     w0, #40
    mov     w1, #40
    mov     w2, #40
    mov     w3, #230
    bl      setcolor
    mov     w0, w19
    add     w1, w20, #13
    mov     w2, #60
    mov     w3, #5
    bl      fillrect
    mov     w0, #250
    mov     w1, #210
    mov     w2, #60
    mov     w3, #255
    bl      setcolor
    ldr     w9, [x28, #G_MINEPROG]
    mov     w10, #60
    mul     w9, w9, w10
    ldr     w10, [x28, #G_MINENEED]
    cmp     w10, #1
    csinc   w10, w10, wzr, ge
    udiv    w2, w9, w10
    mov     w0, w19
    add     w1, w20, #13
    mov     w3, #5
    bl      fillrect
    b       ui_pop
ui_fire:
    ldr     w21, [x28, #G_HOVFIRE]
    tbnz    w21, #31, ui_pop
    LA      x0, lbuf
    LA      x1, s_fire
    bl      strcat_cur
    LA      x9, fires
    add     x9, x9, x21, lsl #4
    ldr     w1, [x9, #12]
    mov     w9, #60
    udiv    w1, w1, w9
    bl      numcat
    LA      x1, s_firehint
    bl      strcat_cur
    mov     w22, #1
    bl      tooltip_box

    // ---- texto que sobe da cabeca do personagem ----
ui_pop:
    ldr     w9, [x28, #G_POPT]
    cbz     w9, ui_hint
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    ldr     w0, [x28, #G_PE]
    bl      proj
    asr     w19, w0, #1
    asr     w20, w1, #1
    ldr     w9, [x28, #G_POPT]
    mov     w10, #45
    sub     w9, w10, w9
    lsr     w9, w9, #1
    sub     w20, w20, w9
    sub     w20, w20, #30
    ldr     x0, [x28, #G_POPMSG]
    bl      mystrlen
    lsl     w0, w0, #2
    sub     w19, w19, w0
    mov     w0, #20
    mov     w1, #20
    mov     w2, #20
    mov     w3, #255
    bl      setcolor
    add     w0, w19, #1
    add     w1, w20, #1
    ldr     x2, [x28, #G_POPMSG]
    bl      text
    mov     w0, #255
    mov     w1, #230
    mov     w2, #90
    mov     w3, #255
    bl      setcolor
    mov     w0, w19
    mov     w1, w20
    ldr     x2, [x28, #G_POPMSG]
    bl      text

    // ---- barra de dicas embaixo ----
ui_hint:
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
    mov     w0, #200
    mov     w1, #200
    mov     w2, #200
    mov     w3, #255
    bl      setcolor
    mov     w0, #4
    mov     w1, #349
    LA      x2, s_hint
    bl      text

    // ---- mensagem ----
    ldr     w9, [x28, #G_MSGT]
    cbz     w9, ui_sleep
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
    mov     w1, #282
    add     w2, w19, #12
    mov     w3, #16
    bl      fillrect
    mov     w0, #255
    mov     w1, #230
    mov     w2, #140
    mov     w3, #255
    bl      setcolor
    mov     w0, #640
    mov     w1, #286
    ldr     x2, [x28, #G_MSG]
    mov     w3, #0
    bl      text_center

    // ---- dormindo: tela escura, Zzz e o relogio ----
ui_sleep:
    ldr     w9, [x28, #G_SLEEP]
    cbz     w9, ui_dead
    RGBA    5, 6, 16, 225
    mov     w0, #0
    mov     w1, #0
    mov     w2, #640
    mov     w3, #360
    bl      fillrect
    mov     w0, #4
    bl      setscale
    RGBA    170, 190, 255, 255
    mov     w0, #320
    mov     w1, #60
    LA      x2, s_sleep1
    mov     w3, #0
    bl      text_center
    mov     w0, #2
    bl      setscale
    LA      x0, txt                     // "Dia 2   03:20"
    bl      surv_clock
    RGBA    235, 235, 245, 255
    mov     w0, #640
    mov     w1, #170
    LA      x2, txt
    add     x2, x2, #7                  // sem o "   -   " do comeco
    mov     w3, #0
    bl      text_center
    RGBA    150, 150, 170, 255
    mov     w0, #640
    mov     w1, #210
    LA      x2, s_sleep2
    mov     w3, #0
    bl      text_center
    // ---- tela de morte ----
ui_dead:
    ldr     w9, [x28, #G_DEAD]
    cbz     w9, ui_ret
    mov     w0, #20
    mov     w1, #0
    mov     w2, #0
    mov     w3, #170
    bl      setcolor
    mov     w0, #0
    mov     w1, #0
    mov     w2, #640
    mov     w3, #360
    bl      fillrect
    mov     w0, #4
    bl      setscale
    mov     w0, #255
    mov     w1, #90
    mov     w2, #70
    mov     w3, #255
    bl      setcolor
    mov     w0, #320
    mov     w1, #50
    LA      x2, s_dead1
    mov     w3, #0
    bl      text_center
    mov     w0, #2
    bl      setscale
    ldr     x2, [x28, #G_DEATHMSG]      // causa da morte
    cbz     x2, 1f
    mov     w0, #255
    mov     w1, #200
    mov     w2, #140
    mov     w3, #255
    bl      setcolor
    mov     w0, #640
    mov     w1, #160
    ldr     x2, [x28, #G_DEATHMSG]
    mov     w3, #0
    bl      text_center
1:  LA      x0, lbuf
    LA      x1, s_dead2
    bl      strcat_cur
    ldr     w1, [x28, #G_DAY]
    sub     w1, w1, #1
    bl      numcat
    LA      x1, s_dead3
    bl      strcat_cur
    mov     w0, #240
    mov     w1, #240
    mov     w2, #240
    mov     w3, #255
    bl      setcolor
    mov     w0, #640
    mov     w1, #180
    LA      x2, lbuf
    mov     w3, #0
    bl      text_center
    mov     w0, #640
    mov     w1, #210
    LA      x2, s_dead4
    mov     w3, #0
    bl      text_center
ui_ret:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// =====================================================================
//  Skills, peso e mochila
// =====================================================================

// calc_stats: peso carregado, limite de peso (cresce com a forca) e
// stamina maxima (cresce com corrida e natacao)   folha
    .globl calc_stats
calc_stats:
    ldr     s0, [x28, #G_SKRUN]         // 100 + 0.4 * (corrida + natacao)
    ldr     s1, [x28, #G_SKSWIM]
    fadd    s0, s0, s1
    FC      s1, F_STAMSK
    FC      s2, F_HUNDRED
    fmadd   s0, s0, s1, s2
    str     s0, [x28, #G_STAMAX]
    ldr     s1, [x28, #G_STAMINA]       // a skill caiu: a stamina nao passa do maximo
    fmin    s1, s1, s0
    str     s1, [x28, #G_STAMINA]
    add     x9, x28, #G_WOOD
    LA      x10, itemweight
    mov     w11, #0
    mov     x12, #0
1:  ldr     w13, [x9, x12, lsl #2]
    ldrh    w14, [x10, x12, lsl #1]
    madd    w11, w13, w14, w11
    add     x12, x12, #1
    cmp     x12, #NITEMS
    b.lt    1b
    str     w11, [x28, #G_WEIGHT]
    ldr     s0, [x28, #G_SKSTR]         // 30 kg + 0.3 kg por ponto de forca
    fmov    s1, #3.0
    fmul    s0, s0, s1
    fcvtzs  w9, s0
    add     w9, w9, #300
    ldr     w10, [x28, #(G_INV + 4 * IT_BASKET)]
    cbz     w10, 2f
    add     w9, w9, #100                // cesto: +10 kg (so um conta)
2:  ldr     w10, [x28, #(G_INV + 4 * IT_LBAG)]
    cbz     w10, 3f
    add     w9, w9, #200                // mochila de couro: +20 kg
3:  str     w9, [x28, #G_CAP]
    ret

// skills_tick: cada skill sem treino ha mais de 2 min cai devagar   folha
skills_tick:
    mov     x9, #0
1:  add     x10, x28, #G_SKIDLE
    ldrh    w11, [x10, x9, lsl #1]
    mov     w12, #65535
    cmp     w11, w12
    cinc    w11, w11, lo
    strh    w11, [x10, x9, lsl #1]
    mov     w12, #SKREST
    cmp     w11, w12
    b.ls    2f
    add     x10, x28, #G_SKILL
    ldr     s0, [x10, x9, lsl #2]
    FC      s1, F_SKDECAY
    fsub    s0, s0, s1
    fmov    s1, wzr
    fmax    s0, s0, s1
    str     s0, [x10, x9, lsl #2]
    FC      s1, F_TENTH                 // caiu de nivel: anuncia de novo
    fmul    s0, s0, s1                  // quando subir outra vez
    fcvtzs  w11, s0
    add     x10, x28, #G_SKLAST
    ldrb    w12, [x10, x9]
    cmp     w11, w12
    b.ge    2f
    strb    w11, [x10, x9]
2:  add     x9, x9, #1
    cmp     x9, #NSKILL
    b.lt    1b
    ret

// skill_train(w0 = skill, s0 = treino): sobe mais devagar perto do maximo
skill_train:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, w0
    add     x9, x28, #G_SKILL
    ldr     s1, [x9, x19, lsl #2]
    FC      s2, F_INV100
    FC      s3, F_P105
    fmsub   s2, s1, s2, s3              // 1.05 - v/100
    fmadd   s1, s0, s2, s1              // v += treino * (1.05 - v/100)
    FC      s2, F_HUNDRED
    fmin    s1, s1, s2
    str     s1, [x9, x19, lsl #2]
    add     x10, x28, #G_SKIDLE
    strh    wzr, [x10, x19, lsl #1]
    FC      s2, F_TENTH
    fmul    s1, s1, s2
    fcvtzs  w20, s1                     // nivel 0..10
    add     x10, x28, #G_SKLAST
    ldrb    w11, [x10, x19]
    cmp     w20, w11
    b.le    9f
    strb    w20, [x10, x19]
    LA      x0, msgbuf                  // "Natacao subiu para o nivel 3!"
    LA      x1, skillnames
    add     x1, x1, x19, lsl #4
    bl      strcat_cur
    LA      x1, s_lvlup
    bl      strcat_cur
    mov     w1, w20
    bl      numcat
    LA      x1, s_excl
    bl      strcat_cur
    LA      x0, msgbuf
    bl      set_msg
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// kgcat(x0 = cursor, w1 = decimos de kg) -> x0   ("12.5")
kgcat:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w1
    mov     w9, #10
    udiv    w1, w19, w9
    bl      numcat
    mov     w9, #46
    strb    w9, [x0], #1
    mov     w9, #10
    udiv    w10, w19, w9
    msub    w10, w10, w9, w19
    add     w10, w10, #48
    strb    w10, [x0], #1
    strb    wzr, [x0]
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// mouse_ui -> w0 = x, w1 = y no espaco da interface (640 x 360)   folha
mouse_ui:
    ldr     s0, [x28, #G_MX]
    fcvtzs  w0, s0
    asr     w0, w0, #1
    ldr     s0, [x28, #G_MY]
    fcvtzs  w1, s0
    asr     w1, w1, #1
    ret

// ui_hit(w0 = x, w1 = y) -> w0: 0 mundo, 1 botao mochila, 2 botao
// personagem, 5 botao fabricar, 3 janela da mochila (w1 = quadrado),
// 4 janela do personagem, 6 janela de fabricar (w1 = receita),
// 7 janela do bau (w1 = quadrado).  w1 = -1 fora de um quadrado/receita.
// usa x0-x5, x9-x15 (chama so grid_hit, que e folha)
ui_hit:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w2, w0
    mov     w3, w1
    mov     w1, #-1
    sub     w9, w3, #BTN_Y
    cmp     w9, #BTN_H
    b.hs    1f
    sub     w9, w2, #BTNI_X
    cmp     w9, #BTNI_W
    mov     w0, #1
    b.lo    9f
    sub     w9, w2, #BTNC_X
    cmp     w9, #BTNC_W
    mov     w0, #2
    b.lo    9f
    sub     w9, w2, #BTNF_X
    cmp     w9, #BTNF_W
    mov     w0, #5
    b.lo    9f
1:  ldr     w9, [x28, #G_INVOPEN]       // mochila (4 x 3)
    cbz     w9, 3f
    sub     w9, w2, #INV_X
    cmp     w9, #INV_W
    b.hs    3f
    sub     w10, w3, #INV_Y
    cmp     w10, #INV_H
    b.hs    3f
    sub     w9, w2, #SLOT_X
    sub     w10, w3, #SLOT_Y
    mov     w4, #5
    mov     w5, #4
    bl      grid_hit
    mov     w0, #3
    b       9f
3:  sub     w9, w2, #CRF_X              // bau ou fabricar (mesmo lugar)
    cmp     w9, #CRF_W
    b.hs    5f
    sub     w10, w3, #CRF_Y
    cmp     w10, #CRF_H
    b.hs    5f
    ldr     w9, [x28, #G_CHESTOPEN]
    cbz     w9, 4f
    sub     w9, w2, #CHS_SLOTX          // bau (4 x 5)
    sub     w10, w3, #CHS_SLOTY
    mov     w4, #4
    mov     w5, #5
    bl      grid_hit
    mov     w0, #7
    b       9f
4:  ldr     w9, [x28, #G_CRAFTOPEN]
    cbz     w9, 5f
    sub     w9, w2, #CRF_GX             // fabricar: icones 4 x 4
    sub     w10, w3, #CRF_GY
    mov     w4, #4
    mov     w5, #4
    bl      grid_hit
    mov     w0, #6
    cmp     w1, #NRECIPES
    b.lt    9f
    mov     w1, #-1
    b       9f
5:  sub     w9, w2, #HB_X               // barra "na mao" (4 x 1)
    sub     w10, w3, #HB_Y
    mov     w4, #4
    mov     w5, #1
    bl      grid_hit
    mov     w0, #8
    tbz     w1, #31, 9f
    mov     w0, #0
    ldr     w9, [x28, #G_CHAROPEN]
    cbz     w9, 9f
    sub     w9, w2, #CHR_X
    cmp     w9, #CHR_W
    b.hs    9f
    sub     w10, w3, #CHR_Y
    cmp     w10, #CHR_H
    b.hs    9f
    mov     w0, #4
9:  ldp     x29, x30, [sp], #16
    ret

// grid_hit(w9 = x - x0, w10 = y - y0, w4 = colunas, w5 = linhas)
// -> w1 = quadrado ou -1   folha
grid_hit:
    mov     w1, #-1
    tbnz    w9, #31, 9f
    tbnz    w10, #31, 9f
    mov     w11, #SLOTSTEP
    udiv    w12, w9, w11
    msub    w9, w12, w11, w9
    cmp     w9, #SLOT
    b.hs    9f
    cmp     w12, w4
    b.hs    9f
    udiv    w13, w10, w11
    msub    w10, w13, w11, w10
    cmp     w10, #SLOT
    b.hs    9f
    cmp     w13, w5
    b.hs    9f
    madd    w1, w13, w4, w12
9:  ret

// slot_item(x0 = contadores, w1 = quadrado) -> w0 = item (-1 = vazio)
// os itens que existem ocupam os quadrados em ordem   folha
slot_item:
    mov     x9, x0
    mov     w0, w1
    mov     w10, #0
1:  cmp     w10, #NITEMS
    b.ge    8f
    ldr     w11, [x9, x10, lsl #2]
    cbz     w11, 2f
    cbz     w0, 9f
    sub     w0, w0, #1
2:  add     w10, w10, #1
    b       1b
8:  mov     w10, #-1
9:  mov     w0, w10
    ret

// inv_slot_item(w0 = quadrado) -> w0 = item da mochila   folha
inv_slot_item:
    mov     w1, w0
    add     x0, x28, #G_INV
    b       slot_item

// drop_item(w0 = item, w1 = quantos): larga no chao, numa pilha que
// pode ser coletada de volta (junta com uma pilha igual ali do lado)
drop_item:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     d8, d9, [sp, #64]
    mov     w19, w0
    add     x9, x28, #G_WOOD
    ldr     w10, [x9, x19, lsl #2]
    cmp     w1, w10
    csel    w20, w1, w10, lt            // nao larga mais do que tem
    cbz     w20, 9f
    ldr     s8, [x28, #G_PU]            // no chao, na frente do personagem
    ldr     s9, [x28, #G_PV]
    fmov    s0, #0.75
    fadd    s8, s8, s0
    fadd    s9, s9, s0
    fmov    s0, s8
    fmov    s1, s9
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    b.ge    1f
    LA      x0, m_dropwater
    bl      set_msg
    b       9f
1:  mov     w21, w0
    FC      s2, F_64
    fmul    s0, s8, s2
    fcvtzs  w22, s0
    fmul    s0, s9, s2
    fcvtzs  w23, s0
    add     w24, w19, #O_LOGS
    ldr     w9, [x28, #G_NOBJ]
    LA      x10, objs
    mov     w11, #0
2:  cmp     w11, w9
    b.ge    5f
    ldrb    w12, [x10, #6]
    cmp     w12, w24
    b.ne    4f
    ldrh    w12, [x10]
    sub     w12, w12, w22
    cmp     w12, #96
    b.gt    4f
    cmn     w12, #96
    b.lt    4f
    ldrh    w12, [x10, #2]
    sub     w12, w12, w23
    cmp     w12, #96
    b.gt    4f
    cmn     w12, #96
    b.lt    4f
    ldrb    w12, [x10, #7]
    add     w12, w12, w20
    cmp     w12, #255
    b.gt    4f
    strb    w12, [x10, #7]
    b       6f
4:  add     x10, x10, #8
    add     w11, w11, #1
    b       2b
5:  mov     w0, w22                     // pilha nova
    mov     w1, w23
    mov     w2, w21
    mov     w3, w24
    mov     w4, w20
    bl      add_obj
    ldr     w9, [x28, #G_NOBJ]
    sub     w9, w9, #1
    LA      x10, memtype
    strb    w24, [x10, x9]
6:  add     x9, x28, #G_WOOD
    ldr     w10, [x9, x19, lsl #2]
    sub     w10, w10, w20
    str     w10, [x9, x19, lsl #2]
    bl      calc_stats
    LA      x0, p_drop
    bl      popup
9:  ldp     d8, d9, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// pile_at(w0 = item, w1 = quantos, s0 = u, s1 = v): pilha no chao nesse
// ponto (junta com uma igual do lado); a carne e o couro dos animais
    .globl pile_at
pile_at:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     d8, d9, [sp, #64]
    mov     w19, w0
    mov     w20, w1
    cbz     w20, 9f
    fmov    s8, s0
    fmov    s9, s1
    bl      elev_at
    ldr     w9, [x28, #G_FLOOD]
    cmp     w0, w9
    csel    w21, w9, w0, lt
    FC      s2, F_64
    fmul    s0, s8, s2
    fcvtzs  w22, s0
    fmul    s0, s9, s2
    fcvtzs  w23, s0
    add     w24, w19, #O_LOGS
    ldr     w9, [x28, #G_NOBJ]
    LA      x10, objs
    mov     w11, #0
1:  cmp     w11, w9
    b.ge    5f
    ldrb    w12, [x10, #6]
    cmp     w12, w24
    b.ne    4f
    ldrh    w12, [x10]
    sub     w12, w12, w22
    cmp     w12, #96
    b.gt    4f
    cmn     w12, #96
    b.lt    4f
    ldrh    w12, [x10, #2]
    sub     w12, w12, w23
    cmp     w12, #96
    b.gt    4f
    cmn     w12, #96
    b.lt    4f
    ldrb    w12, [x10, #7]
    add     w12, w12, w20
    cmp     w12, #255
    b.gt    4f
    strb    w12, [x10, #7]
    b       9f
4:  add     x10, x10, #8
    add     w11, w11, #1
    b       1b
5:  mov     w0, w22
    mov     w1, w23
    mov     w2, w21
    mov     w3, w24
    mov     w4, w20
    bl      add_obj
    ldr     w9, [x28, #G_NOBJ]
    sub     w9, w9, #1
    LA      x10, memtype
    strb    w24, [x10, x9]
9:  ldp     d8, d9, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ---- pecas da interface ----------------------------------------------------

// ui_frame(w0 x, w1 y, w2 largura, w3 altura): contorno de 1 pixel
ui_frame:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    mov     w22, w3
    mov     w3, #1
    bl      fillrect
    mov     w0, w19
    add     w1, w20, w22
    sub     w1, w1, #1
    mov     w2, w21
    mov     w3, #1
    bl      fillrect
    mov     w0, w19
    mov     w1, w20
    mov     w2, #1
    mov     w3, w22
    bl      fillrect
    add     w0, w19, w21
    sub     w0, w0, #1
    mov     w1, w20
    mov     w2, #1
    mov     w3, w22
    bl      fillrect
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ui_panel(w0 x, w1 y, w2 larg., w3 alt., x4 titulo): janela com titulo
ui_panel:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     x23, [sp, #48]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    mov     w22, w3
    mov     x23, x4
    RGBA    12, 14, 22, 228
    mov     w0, w19
    mov     w1, w20
    mov     w2, w21
    mov     w3, w22
    bl      fillrect
    RGBA    45, 58, 88, 240
    mov     w0, w19
    mov     w1, w20
    mov     w2, w21
    mov     w3, #14
    bl      fillrect
    RGBA    130, 140, 165, 255
    mov     w0, w19
    mov     w1, w20
    mov     w2, w21
    mov     w3, w22
    bl      ui_frame
    RGBA    255, 235, 180, 255
    add     w0, w19, #6
    add     w1, w20, #3
    mov     x2, x23
    bl      text
    ldr     x23, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ui_button(w0 x, w1 largura, x2 texto, w3 1 = janela aberta)
ui_button:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     x21, x2
    mov     w22, w3
    bl      mouse_ui                    // mouse em cima?
    sub     w0, w0, w19
    cmp     w0, w20
    b.hs    1f
    sub     w1, w1, #BTN_Y
    cmp     w1, #BTN_H
    b.hs    1f
    orr     w22, w22, #2
1:  tbz     w22, #0, 2f
    RGBA    50, 90, 150, 235            // aberta
    b       4f
2:  tbz     w22, #1, 3f
    RGBA    70, 72, 86, 230             // mouse em cima
    b       4f
3:  RGBA    0, 0, 0, 170
4:  mov     w0, w19
    mov     w1, #BTN_Y
    mov     w2, w20
    mov     w3, #BTN_H
    bl      fillrect
    RGBA    150, 160, 180, 255
    mov     w0, w19
    mov     w1, #BTN_Y
    mov     w2, w20
    mov     w3, #BTN_H
    bl      ui_frame
    RGBA    255, 255, 255, 255
    mov     x0, x21
    bl      mystrlen
    lsl     w0, w0, #3
    sub     w0, w20, w0
    asr     w0, w0, #1
    add     w0, w0, w19
    mov     w1, #(BTN_Y + 3)
    mov     x2, x21
    bl      text
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ui_icon(x0 sprite, w1 x, w2 y, w3 tamanho do pixel): sprite na interface
ui_icon:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
    ldrb    w19, [x0]                   // largura
    ldrb    w20, [x0, #1]               // altura
    add     x21, x0, #4
    mov     w22, w1
    mov     w23, w2
    mov     w24, w3
    mov     w25, #0
1:  mul     w9, w19, w20
    cmp     w25, w9
    b.ge    9f
    ldrb    w9, [x21, x25]
    cbz     w9, 2f
    LA      x10, palette
    ldr     w9, [x10, w9, uxtw #2]
    ubfx    w0, w9, #16, #8
    ubfx    w1, w9, #8, #8
    and     w2, w9, #255
    mov     w3, #255
    bl      setcolor
    udiv    w9, w25, w19                // linha
    msub    w10, w9, w19, w25           // coluna
    madd    w0, w10, w24, w22
    madd    w1, w9, w24, w23
    mov     w2, w24
    mov     w3, w24
    bl      fillrect
2:  add     w25, w25, #1
    b       1b
9:  ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ui_windows: botoes no canto e as janelas abertas
ui_windows:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w0, #BTNF_X
    mov     w1, #BTNF_W
    LA      x2, s_btncraft
    ldr     w3, [x28, #G_CRAFTOPEN]
    bl      ui_button
    mov     w0, #BTNI_X
    mov     w1, #BTNI_W
    LA      x2, s_btninv
    ldr     w3, [x28, #G_INVOPEN]
    bl      ui_button
    mov     w0, #BTNC_X
    mov     w1, #BTNC_W
    LA      x2, s_btnchar
    ldr     w3, [x28, #G_CHAROPEN]
    bl      ui_button
    ldr     w9, [x28, #G_CHAROPEN]
    cbz     w9, 1f
    bl      draw_char
1:  ldr     w9, [x28, #G_CHESTOPEN]
    cbz     w9, 11f
    bl      draw_chest
    b       12f
11: ldr     w9, [x28, #G_CRAFTOPEN]
    cbz     w9, 12f
    bl      draw_craft
12: bl      draw_hotbar
    ldr     w9, [x28, #G_INVOPEN]
    cbz     w9, 2f
    bl      draw_inv
2:  ldp     x29, x30, [sp], #16
    ret

// icon_fit(x0 sprite, w1 y, w2 x, w3 lado do quadrado): desenha o icone
// centrado (pixel 3 se couber, senao 2), um pouco acima do meio
icon_fit:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x4, x0
    mov     w5, w1
    mov     w6, w2
    ldrb    w9, [x4]                    // largura e altura
    ldrb    w10, [x4, #1]
    mov     w11, #3
    mul     w12, w9, w11
    sub     w13, w3, #4
    cmp     w12, w13
    b.gt    1f
    mul     w12, w10, w11
    sub     w13, w3, #10
    cmp     w12, w13
    b.le    2f
1:  mov     w11, #2
    lsl     w12, w9, #1                 // nem com pixel 2? pixel 1
    sub     w13, w3, #2
    cmp     w12, w13
    b.le    2f
    mov     w11, #1
2:  mul     w9, w9, w11
    mul     w10, w10, w11
    sub     w9, w3, w9
    asr     w9, w9, #1
    add     w1, w6, w9
    sub     w10, w3, w10
    asr     w10, w10, #1
    add     w2, w5, w10
    sub     w2, w2, #4
    mov     x0, x4
    mov     w3, w11
    bl      ui_icon
    ldp     x29, x30, [sp], #16
    ret

// draw_grid(x0 contadores, w1 x, w2 y, w3 colunas, w4 quadrados,
//           w5 quadrado sob o mouse, w6 1 = mochila: mostra o desgaste)
draw_grid:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     x27, [sp, #80]
    mov     x19, x0
    mov     w20, w1
    mov     w21, w2
    mov     w22, w3
    mov     w23, w4
    mov     w24, w5
    mov     w25, w6
    mov     w26, #0
1:  cmp     w26, w23
    b.ge    9f
    udiv    w9, w26, w22                // linha
    msub    w10, w9, w22, w26           // coluna
    mov     w11, #SLOTSTEP
    madd    w27, w10, w11, w20          // x do quadrado
    madd    w12, w9, w11, w21
    str     w12, [sp, #96]              // y
    cmp     w26, w24
    b.ne    2f
    RGBA    70, 72, 92, 240
    b       3f
2:  RGBA    28, 30, 38, 235
3:  mov     w0, w27
    ldr     w1, [sp, #96]
    mov     w2, #SLOT
    mov     w3, #SLOT
    bl      fillrect
    RGBA    85, 90, 108, 255
    mov     w0, w27
    ldr     w1, [sp, #96]
    mov     w2, #SLOT
    mov     w3, #SLOT
    bl      ui_frame
    mov     x0, x19                     // tem item aqui?
    mov     w1, w26
    bl      slot_item
    tbnz    w0, #31, 8f
    str     w0, [sp, #100]
    LA      x9, itemicon                // icone centrado
    ldrb    w9, [x9, x0]
    LA      x0, sprites
    add     x0, x0, x9, lsl #7
    ldr     w1, [sp, #96]
    mov     w2, w27
    mov     w3, #SLOT
    bl      icon_fit
    LA      x0, lbuf                    // quantidade no canto
    ldr     w9, [sp, #100]
    ldr     w1, [x19, x9, lsl #2]
    bl      numcat
    LA      x0, lbuf
    bl      mystrlen
    lsl     w0, w0, #3
    str     w0, [sp, #104]
    RGBA    0, 0, 0, 255
    add     w0, w27, #(SLOT - 1)
    ldr     w9, [sp, #104]
    sub     w0, w0, w9
    ldr     w1, [sp, #96]
    add     w1, w1, #(SLOT - 9)
    LA      x2, lbuf
    bl      text
    RGBA    255, 255, 255, 255
    add     w0, w27, #(SLOT - 2)
    ldr     w9, [sp, #104]
    sub     w0, w0, w9
    ldr     w1, [sp, #96]
    add     w1, w1, #(SLOT - 10)
    LA      x2, lbuf
    bl      text
    // desgaste: machado, picareta e a tocha acesa
    cbz     w25, 8f
    ldr     w9, [sp, #100]
    mov     w11, #TOOLDUR
    ldr     w10, [x28, #G_AXEDUR]
    cmp     w9, #IT_AXE
    b.eq    4f
    ldr     w10, [x28, #G_PICKDUR]
    cmp     w9, #IT_PICK
    b.eq    4f
    cmp     w9, #IT_TORCH
    b.ne    8f
    ldr     w10, [x28, #G_TORCHT]
    cbz     w10, 8f
    mov     w11, #TORCHTIME
4:  mov     w12, #(SLOT - 8)
    mul     w10, w10, w12
    udiv    w10, w10, w11
    str     w10, [sp, #104]             // largura
    RGBA    20, 20, 24, 255
    add     w0, w27, #4
    ldr     w1, [sp, #96]
    add     w1, w1, #(SLOT - 5)
    mov     w2, #(SLOT - 8)
    mov     w3, #3
    bl      fillrect
    ldr     w9, [sp, #104]
    cmp     w9, #((SLOT - 8) / 2)
    b.lt    5f
    RGBA    100, 220, 90, 255
    b       7f
5:  cmp     w9, #((SLOT - 8) / 4)
    b.lt    6f
    RGBA    235, 190, 60, 255
    b       7f
6:  RGBA    230, 70, 50, 255
7:  ldr     w2, [sp, #104]
    cbz     w2, 8f
    add     w0, w27, #4
    ldr     w1, [sp, #96]
    add     w1, w1, #(SLOT - 5)
    mov     w3, #3
    bl      fillrect
8:  add     w26, w26, #1
    b       1b
9:  ldr     x27, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #112
    ret

// grid_tip(x0 contadores, w1 quadrado): dica "Madeira x12 (18.0 kg)"
// perto do mouse
grid_tip:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x21, x0
    tbnz    w1, #31, 9f
    bl      slot_item
    tbnz    w0, #31, 9f
    mov     w19, w0
    LA      x0, lbuf
    LA      x1, itemnames
    add     x1, x1, x19, lsl #4
    bl      strcat_cur
    LA      x1, s_x
    bl      strcat_cur
    ldr     w1, [x21, x19, lsl #2]
    mov     w20, w1
    bl      numcat
    LA      x1, s_paren
    bl      strcat_cur
    LA      x9, itemweight
    ldrh    w9, [x9, x19, lsl #1]
    mul     w1, w20, w9
    bl      kgcat
    LA      x1, s_kgparen
    bl      strcat_cur
    LA      x0, lbuf
    bl      mystrlen
    lsl     w21, w0, #3
    bl      mouse_ui
    add     w19, w0, #10
    add     w20, w1, #6
    mov     w10, #636                   // nao deixa sair da tela
    sub     w10, w10, w21
    cmp     w19, w10
    csel    w19, w10, w19, gt
    mov     w22, #1
    bl      tooltip_box
9:  ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// draw_inv: mochila em grade (4 x 3), com o peso em cima
draw_inv:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w0, #INV_X
    mov     w1, #INV_Y
    mov     w2, #INV_W
    mov     w3, #INV_H
    LA      x4, s_invtitle
    bl      ui_panel
    // "Peso 12.5 / 30.0 kg"
    LA      x0, lbuf
    LA      x1, s_peso
    bl      strcat_cur
    ldr     w1, [x28, #G_WEIGHT]
    bl      kgcat
    LA      x1, s_slash
    bl      strcat_cur
    ldr     w1, [x28, #G_CAP]
    bl      kgcat
    LA      x1, s_kg
    bl      strcat_cur
    ldr     w9, [x28, #G_WEIGHT]
    ldr     w10, [x28, #G_CAP]
    cmp     w9, w10
    b.gt    1f
    RGBA    220, 220, 220, 255
    b       2f
1:  RGBA    255, 130, 90, 255
2:  mov     w0, #(INV_X + 8)
    mov     w1, #(INV_Y + 20)
    LA      x2, lbuf
    bl      text
    // barra de peso: verde ate 75%, amarela ate 100%, vermelha acima
    RGBA    40, 40, 46, 255
    mov     w0, #(INV_X + 8)
    mov     w1, #(INV_Y + 32)
    mov     w2, #(INV_W - 16)
    mov     w3, #6
    bl      fillrect
    ldr     w9, [x28, #G_WEIGHT]
    ldr     w10, [x28, #G_CAP]
    mov     w11, #(INV_W - 16)
    mul     w19, w9, w11
    cmp     w10, #1
    csinc   w10, w10, wzr, ge
    udiv    w19, w19, w10
    cmp     w19, w11
    csel    w19, w11, w19, gt
    lsl     w12, w9, #2
    add     w13, w10, w10, lsl #1
    cmp     w12, w13
    b.gt    3f
    RGBA    110, 200, 90, 255
    b       5f
3:  cmp     w9, w10
    b.gt    4f
    RGBA    235, 200, 60, 255
    b       5f
4:  RGBA    235, 75, 55, 255
5:  cbz     w19, 6f
    mov     w0, #(INV_X + 8)
    mov     w1, #(INV_Y + 32)
    mov     w2, w19
    mov     w3, #6
    bl      fillrect
6:  bl      mouse_ui                    // quadrado sob o mouse
    bl      ui_hit
    mov     w20, #-1
    cmp     w0, #3
    b.ne    7f
    mov     w20, w1
7:  add     x0, x28, #G_INV
    mov     w1, #SLOT_X
    mov     w2, #SLOT_Y
    mov     w3, #5
    mov     w4, #20
    mov     w5, w20
    mov     w6, #1
    bl      draw_grid
    RGBA    160, 160, 170, 255
    LA      x2, s_invhint
    ldr     w9, [x28, #G_CHESTOPEN]
    cbz     w9, 8f
    LA      x2, s_invhint2
8:  mov     w0, #(INV_X + 8)
    mov     w1, #(INV_Y + INV_H - 14)
    bl      text
    add     x0, x28, #G_INV
    mov     w1, w20
    bl      grid_tip
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// draw_chest: o bau aberto (grade 3 x 4), no lugar da janela de fabricar
draw_chest:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w0, #CRF_X
    mov     w1, #CRF_Y
    mov     w2, #CRF_W
    mov     w3, #CRF_H
    LA      x4, s_chesttitle
    bl      ui_panel
    ldr     w9, [x28, #G_CHESTOPEN]
    sub     w9, w9, #1
    LA      x19, chests
    add     x19, x19, x9, lsl #7
    bl      mouse_ui
    bl      ui_hit
    mov     w20, #-1
    cmp     w0, #7
    b.ne    1f
    mov     w20, w1
1:  mov     x0, x19
    mov     w1, #CHS_SLOTX
    mov     w2, #CHS_SLOTY
    mov     w3, #4
    mov     w4, #20
    mov     w5, w20
    mov     w6, #0
    bl      draw_grid
    RGBA    160, 160, 170, 255
    mov     w0, #(CRF_X + 8)
    mov     w1, #(CRF_Y + CRF_H - 14)
    LA      x2, s_chesthint
    bl      text
    mov     x0, x19
    mov     w1, w20
    bl      grid_tip
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// draw_craft: grade de icones das receitas (cinza = falta material);
// embaixo, a receita sob o mouse: nome, custo e o que faz
draw_craft:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     w0, #CRF_X
    mov     w1, #CRF_Y
    mov     w2, #CRF_W
    mov     w3, #CRF_H
    LA      x4, s_crafttitle
    bl      ui_panel
    bl      mouse_ui
    bl      ui_hit
    mov     w23, #-1
    cmp     w0, #6
    b.ne    1f
    mov     w23, w1
1:  str     w23, [x28, #G_HOVREC]
    mov     w19, #0
2:  cmp     w19, #NRECIPES
    b.ge    7f
    and     w9, w19, #3
    mov     w10, #SLOTSTEP
    mov     w11, #CRF_GX
    madd    w20, w9, w10, w11           // x
    lsr     w9, w19, #2
    mov     w11, #CRF_GY
    madd    w21, w9, w10, w11           // y
    mov     w0, w19
    bl      can_craft
    mov     w22, w0
    cmp     w19, w23
    b.ne    3f
    RGBA    70, 72, 92, 240
    b       4f
3:  RGBA    28, 30, 38, 235
4:  mov     w0, w20
    mov     w1, w21
    mov     w2, #SLOT
    mov     w3, #SLOT
    bl      fillrect
    RGBA    85, 90, 108, 255            // borda: verde se da para fazer
    cbz     w22, 41f
    RGBA    110, 190, 100, 255
41: mov     w0, w20
    mov     w1, w21
    mov     w2, #SLOT
    mov     w3, #SLOT
    bl      ui_frame
    LA      x24, recipes
    add     x24, x24, x19, lsl #4
    ldrb    w9, [x24]
    LA      x10, itemicon
    ldrb    w9, [x10, x9]
    LA      x0, sprites
    add     x0, x0, x9, lsl #7
    mov     w1, w21
    mov     w2, w20
    mov     w3, #SLOT
    bl      icon_fit
    ldrb    w1, [x24, #1]               // fabrica mais de 1: mostra quantos
    cmp     w1, #1
    b.ls    5f
    LA      x0, lbuf
    bl      numcat
    RGBA    255, 255, 255, 255
    add     w0, w20, #(SLOT - 10)
    add     w1, w21, #(SLOT - 10)
    LA      x2, lbuf
    bl      text
5:  cbnz    w22, 6f                     // falta material: escurece
    RGBA    10, 10, 14, 150
    add     w0, w20, #1
    add     w1, w21, #1
    mov     w2, #(SLOT - 2)
    mov     w3, #(SLOT - 2)
    bl      fillrect
6:  add     w19, w19, #1
    b       2b
    // ---- detalhes da receita sob o mouse ----
7:  RGBA    85, 90, 108, 255
    mov     w0, #(CRF_X + 6)
    mov     w1, #(CRF_Y + 180)
    mov     w2, #(CRF_W - 12)
    mov     w3, #1
    bl      fillrect
    tbnz    w23, #31, 8f
    LA      x24, recipes
    add     x24, x24, x23, lsl #4
    mov     w0, w23
    bl      can_craft
    mov     w22, w0
    RGBA    255, 235, 180, 255          // nome
    ldrb    w9, [x24]
    LA      x2, itemnames
    add     x2, x2, x9, lsl #4
    mov     w0, #(CRF_X + 8)
    mov     w1, #(CRF_Y + 186)
    bl      text
    LA      x0, lbuf                    // custo
    mov     w1, w23
    bl      cost_str
    RGBA    140, 220, 120, 255
    cbnz    w22, 71f
    RGBA    230, 110, 90, 255
71: mov     w0, #(CRF_X + 8)
    mov     w1, #(CRF_Y + 198)
    LA      x2, lbuf
    bl      text
    RGBA    205, 205, 215, 255          // o que faz
    LA      x24, recdesc
    add     x24, x24, x23, lsl #6
    mov     w0, #(CRF_X + 8)
    mov     w1, #(CRF_Y + 210)
    mov     x2, x24
    bl      text
    mov     w0, #(CRF_X + 8)
    mov     w1, #(CRF_Y + 222)
    add     x2, x24, #32
    bl      text
    b       9f
8:  RGBA    160, 160, 170, 255
    mov     w0, #(CRF_X + 8)
    mov     w1, #(CRF_Y + 200)
    LA      x2, s_crafthint
    bl      text
9:  ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// draw_hotbar: "na mao" - 4 quadrados (1 machado, 2 picareta, 3 arco na
// mao principal; 4 tocha na outra mao); o que esta na mao tem borda amarela
draw_hotbar:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    bl      mouse_ui
    bl      ui_hit
    mov     w23, #-1
    cmp     w0, #8
    b.ne    1f
    mov     w23, w1
1:  mov     w19, #0
2:  cmp     w19, #4
    b.ge    9f
    mov     w9, #SLOTSTEP
    mov     w10, #HB_X
    madd    w20, w19, w9, w10           // x
    LA      x9, hotbar
    ldrb    w21, [x9, x19]              // item
    add     x9, x28, #G_INV
    ldr     w22, [x9, x21, lsl #2]      // quantos tem
    ldr     w24, [x28, #G_HAND]
    sub     w24, w24, #1
    cmp     w24, w21                    // 1 = na mao
    cset    w24, eq
    cmp     w21, #IT_TORCH              // tocha: na outra mao
    b.ne    11f
    ldr     w24, [x28, #G_OFFHAND]
11:
    cmp     w19, w23
    b.ne    3f
    RGBA    70, 72, 92, 230
    b       4f
3:  RGBA    0, 0, 0, 170
4:  mov     w0, w20
    mov     w1, #HB_Y
    mov     w2, #SLOT
    mov     w3, #SLOT
    bl      fillrect
    RGBA    120, 125, 140, 255
    cbz     w24, 41f
    RGBA    255, 215, 80, 255
41: mov     w0, w20
    mov     w1, #HB_Y
    mov     w2, #SLOT
    mov     w3, #SLOT
    bl      ui_frame
    cbz     w24, 42f                    // borda dupla
    add     w0, w20, #1
    mov     w1, #(HB_Y + 1)
    mov     w2, #(SLOT - 2)
    mov     w3, #(SLOT - 2)
    bl      ui_frame
42: LA      x9, itemicon
    ldrb    w9, [x9, x21]
    LA      x0, sprites
    add     x0, x0, x9, lsl #7
    mov     w1, #HB_Y
    mov     w2, w20
    mov     w3, #SLOT
    bl      icon_fit
    cbnz    w22, 5f                     // nao tem: escurece
    RGBA    0, 0, 0, 160
    add     w0, w20, #1
    mov     w1, #(HB_Y + 1)
    mov     w2, #(SLOT - 2)
    mov     w3, #(SLOT - 2)
    bl      fillrect
5:  RGBA    230, 230, 230, 255          // tecla
    add     w0, w20, #3
    mov     w1, #(HB_Y + 3)
    LA      x2, hbkeys
    add     x2, x2, x19, lsl #1
    bl      text
    cmp     w21, #IT_BOW                // arco: quantas flechas
    b.ne    6f
    LA      x0, lbuf
    ldr     w1, [x28, #(G_INV + 4 * IT_ARROW)]
    bl      numcat
    LA      x0, lbuf
    bl      mystrlen
    lsl     w22, w0, #3
    RGBA    255, 255, 255, 255
    add     w0, w20, #(SLOT - 2)
    sub     w0, w0, w22
    mov     w1, #(HB_Y + SLOT - 10)
    LA      x2, lbuf
    bl      text
6:  add     w19, w19, #1
    b       2b
9:  ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// draw_char: janela do personagem com as skills
draw_char:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     d8, [sp, #48]
    mov     w0, #CHR_X
    mov     w1, #CHR_Y
    mov     w2, #CHR_W
    mov     w3, #CHR_H
    LA      x4, s_chartitle
    bl      ui_panel
    mov     w19, #0
1:  cmp     w19, #NSKILL
    b.ge    5f
    mov     w9, #26
    mov     w10, #(CHR_Y + 22)
    madd    w20, w19, w9, w10           // y da linha
    add     x9, x28, #G_SKILL
    ldr     s8, [x9, x19, lsl #2]
    RGBA    230, 230, 235, 255          // nome
    mov     w0, #(CHR_X + 8)
    mov     w1, w20
    LA      x2, skillnames
    add     x2, x2, x19, lsl #4
    bl      text
    LA      x0, lbuf                    // "Nv 3"
    LA      x1, s_nv
    bl      strcat_cur
    FC      s0, F_TENTH
    fmul    s0, s8, s0
    fcvtzs  w1, s0
    bl      numcat
    RGBA    255, 220, 120, 255
    mov     w0, #(CHR_X + 120)
    mov     w1, w20
    LA      x2, lbuf
    bl      text
    // treinando agora (+) ou caindo (-)
    add     x9, x28, #G_SKIDLE
    ldrh    w21, [x9, x19, lsl #1]
    cmp     w21, #90
    b.hs    2f
    RGBA    120, 235, 120, 255
    LA      x22, s_up
    b       3f
2:  mov     w9, #SKREST
    cmp     w21, w9
    b.ls    4f
    fcmp    s8, #0.0
    b.le    4f
    RGBA    240, 150, 80, 255
    LA      x22, s_down
3:  mov     w0, #(CHR_X + CHR_W - 16)
    mov     w1, w20
    mov     x2, x22
    bl      text
    // barra 0..100 com marcas a cada nivel
4:  RGBA    40, 40, 46, 255
    mov     w0, #(CHR_X + 8)
    add     w1, w20, #11
    mov     w2, #(CHR_W - 16)
    mov     w3, #6
    bl      fillrect
    LA      x9, skcolors
    ldr     w9, [x9, x19, lsl #2]
    ubfx    w0, w9, #16, #8
    ubfx    w1, w9, #8, #8
    and     w2, w9, #255
    mov     w3, #255
    bl      setcolor
    fmov    s0, #2.0
    fmul    s0, s8, s0
    fcvtzs  w2, s0
    cbz     w2, 41f
    mov     w0, #(CHR_X + 8)
    add     w1, w20, #11
    mov     w3, #6
    bl      fillrect
41: RGBA    12, 12, 16, 255
    mov     w21, #1
42: mov     w9, #20
    mov     w0, #(CHR_X + 8)
    madd    w0, w21, w9, w0
    add     w1, w20, #11
    mov     w2, #1
    mov     w3, #6
    bl      fillrect
    add     w21, w21, #1
    cmp     w21, #10
    b.lt    42b
    add     w19, w19, #1
    b       1b
5:  LA      x0, lbuf                    // "Carga maxima: 33.0 kg"
    LA      x1, s_carga
    bl      strcat_cur
    ldr     w1, [x28, #G_CAP]
    bl      kgcat
    LA      x1, s_kg
    bl      strcat_cur
    RGBA    220, 220, 220, 255
    mov     w0, #(CHR_X + 8)
    mov     w1, #(CHR_Y + CHR_H - 30)
    LA      x2, lbuf
    bl      text
    RGBA    150, 150, 160, 255
    mov     w0, #(CHR_X + 8)
    mov     w1, #(CHR_Y + CHR_H - 16)
    LA      x2, s_legend
    bl      text
    ldr     d8, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// place_tip: perto do mouse, diz se da para colocar a construcao ali
place_tip:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    bl      place_check
    mov     w22, #2
    cbnz    x0, 1f
    mov     w22, #3                     // "Clique: colocar Bau (dir.: cancela)"
    LA      x0, lbuf
    LA      x1, s_place1
    bl      strcat_cur
    ldr     w9, [x28, #G_PLACE]
    sub     w9, w9, #1
    LA      x1, itemnames
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    LA      x1, s_place2
    bl      strcat_cur
    b       2f
1:  mov     x1, x0                      // o motivo
    LA      x0, lbuf
    bl      strcat_cur
2:  LA      x0, lbuf
    bl      mystrlen
    lsl     w21, w0, #3
    bl      mouse_ui
    add     w19, w0, #12
    add     w20, w1, #8
    mov     w10, #636
    sub     w10, w10, w21
    cmp     w19, w10
    csel    w19, w10, w19, gt
    bl      tooltip_box
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// tooltip_box: desenha lbuf em (w19, w20) com fundo
// w22: 0 cinza, 1 branco, 2 vermelho, 3 verde
tooltip_box:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x0, lbuf
    bl      mystrlen
    lsl     w9, w0, #3
    str     w9, [sp, #-16]!
    mov     w0, #0
    mov     w1, #0
    mov     w2, #0
    mov     w3, #190
    bl      setcolor
    ldr     w9, [sp]
    sub     w0, w19, #3
    sub     w1, w20, #3
    add     w2, w9, #6
    mov     w3, #14
    bl      fillrect
    mov     w0, #255                    // 1 = branco
    mov     w1, #255
    mov     w2, #255
    mov     w3, #255
    cmp     w22, #1
    b.eq    1f
    mov     w0, #170                    // 0 = cinza (longe)
    mov     w1, #170
    mov     w2, #170
    cbz     w22, 1f
    mov     w0, #255                    // 2 = vermelho (nao da)
    mov     w1, #120
    mov     w2, #100
    cmp     w22, #2
    b.eq    1f
    mov     w0, #150                    // 3 = verde (pode)
    mov     w1, #235
    mov     w2, #130
1:  bl      setcolor
    mov     w0, w19
    mov     w1, w20
    LA      x2, lbuf
    bl      text
    add     sp, sp, #16
    ldp     x29, x30, [sp], #16
    ret

// =====================================================================
//  Teste automatico (./trilhos --shot): coleta, fogueira e noite
// =====================================================================

// nearest_obj(w0 = tipo a, w1 = tipo b) -> w0 objeto mais perto (-1)
nearest_obj:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     d8, [sp, #48]
    mov     w19, w0
    mov     w20, w1
    mov     w21, #-1
    FC      s8, F_HUNDRED
    fmul    s8, s8, s8                  // ate 100 celulas
    mov     w22, #0
1:  ldr     w9, [x28, #G_NOBJ]
    cmp     w22, w9
    b.ge    9f
    LA      x9, objs
    add     x9, x9, x22, lsl #3
    ldrb    w10, [x9, #6]
    cmp     w10, w19
    b.eq    2f
    cmp     w10, w20
    b.ne    3f
2:  mov     w0, w22
    bl      obj_dist2
    fcmp    s0, s8
    b.ge    3f
    fmov    s8, s0
    mov     w21, w22
3:  add     w22, w22, #1
    b       1b
9:  mov     w0, w21
    ldr     d8, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// mine_test(w0 = tipo a, w1 = tipo b): vai ate o objeto e coleta tudo
mine_test:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    bl      nearest_obj
    tbnz    w0, #31, 9f
    mov     w19, w0
    LA      x20, objs
    add     x20, x20, x19, lsl #3
    ldrh    w9, [x20]                   // personagem ao lado do objeto
    scvtf   s0, w9
    ldrh    w9, [x20, #2]
    scvtf   s1, w9
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    fmov    s2, #1.0
    fsub    s0, s0, s2
    str     s0, [x28, #G_PU]
    str     s1, [x28, #G_PV]
    mov     w9, #1                      // mouse em cima do objeto, apertado
    str     w9, [x28, #G_HOVOK]
    ldrh    w9, [x20]
    str     w9, [x28, #G_HOVU]
    ldrh    w9, [x20, #2]
    str     w9, [x28, #G_HOVV]
    mov     w9, #1
    str     w9, [x28, #G_LMB]
    mov     w21, #0
1:  bl      surv_update
    ldrb    w9, [x20, #6]
    cmp     w9, #O_BUSHE                // acabou (sem frutas ou removido)
    b.eq    2f
    cmp     w9, #O_GONE
    b.eq    2f
    add     w21, w21, #1
    cmp     w21, #800
    b.lt    1b
2:  str     wzr, [x28, #G_LMB]
9:  ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

    .globl surv_selftest
surv_selftest:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w0, #O_TREE                 // duas arvores
    mov     w1, #O_PINE
    bl      mine_test
    mov     w0, #O_TREE
    mov     w1, #O_PINE
    bl      mine_test
    mov     w0, #O_ROCK                 // uma pedra
    mov     w1, #O_ROCK
    bl      mine_test
    mov     w0, #O_BUSH                 // um arbusto
    mov     w1, #O_BUSH
    bl      mine_test
    // fogueira ao lado (mouse num ponto perto)
    ldr     s0, [x28, #G_PU]
    fmov    s1, #1.0
    fadd    s0, s0, s1
    FC      s1, F_64
    fmul    s0, s0, s1
    fcvtzs  w9, s0
    str     w9, [x28, #G_HOVU]
    ldr     s0, [x28, #G_PV]
    fmul    s0, s0, s1
    fcvtzs  w9, s0
    str     w9, [x28, #G_HOVV]
    mov     w9, #1
    str     w9, [x28, #G_HOVOK]
    mov     w0, #9                      // F: fabrica a fogueira...
    bl      surv_key
    mov     w0, #1                      // ... e clica no mapa para montar
    mov     w1, #1
    bl      surv_mouse
    mov     w0, #1
    mov     w1, #0
    bl      surv_mouse
    mov     w0, #8                      // E
    bl      surv_key
    // vai para a noite e deixa o tempo passar
    mov     w9, #28800
    str     w9, [x28, #G_TIME]
    str     wzr, [x28, #G_HOVOK]
    mov     w19, #0
1:  bl      surv_update
    add     w19, w19, #1
    cmp     w19, #120
    b.lt    1b
    // imprime o resultado
    LA      x0, txt
    LA      x1, t_1
    bl      strcat_cur
    ldr     w1, [x28, #G_WOOD]
    bl      numcat
    LA      x1, t_2
    bl      strcat_cur
    ldr     w1, [x28, #G_STONE]
    bl      numcat
    LA      x1, t_3
    bl      strcat_cur
    ldr     w1, [x28, #G_BERRY]
    bl      numcat
    LA      x1, t_4
    bl      strcat_cur
    ldr     w1, [x28, #G_NFIRE]
    bl      numcat
    LA      x1, t_5
    bl      strcat_cur
    ldr     s0, [x28, #G_HP]
    fcvtzs  w1, s0
    bl      numcat
    LA      x1, t_6
    bl      strcat_cur
    ldr     s0, [x28, #G_FOOD]
    fcvtzs  w1, s0
    bl      numcat
    LA      x1, t_7
    bl      strcat_cur
    ldr     s0, [x28, #G_WARM]
    fcvtzs  w1, s0
    bl      numcat
    LA      x1, t_8
    bl      strcat_cur
    ldr     w1, [x28, #G_AMBR]
    bl      numcat
    LA      x1, s_nl
    bl      strcat_cur
    LA      x9, txt
    sub     x2, x0, x9
    mov     x1, x9
    mov     w0, #1
    bl      F(write)
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// surv_selftest_skills(w0 = etapa): teste da corrida, peso e mochila
//   0: corre, anda carregado, larga pedras e abre as janelas (para a foto)
//   1: deixa a corrida sem treino (ela cai), recolhe a pilha e fecha tudo
    .globl surv_selftest_skills
surv_selftest_skills:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    str     wzr, [x28, #G_HOVOK]
    str     wzr, [x28, #G_LMB]
    mov     w9, #6000                   // de dia
    str     w9, [x28, #G_TIME]
    cbnz    w0, sk_stage1
    FC      s0, F_HUNDRED
    str     s0, [x28, #G_STAMINA]
    str     wzr, [x28, #G_EXHAUST]
    // corre 2 s para cima e 2 s de volta (W/S + Shift)
    mov     w20, #0                     // quadros correndo de verdade
    mov     w19, #0
1:  mov     w9, #17
    cmp     w19, #120
    b.lt    11f
    mov     w9, #18
11: str     w9, [x28, #G_TESTKEYS]
    bl      surv_update
    ldr     w9, [x28, #G_RUN]
    add     w20, w20, w9
    add     w19, w19, #1
    cmp     w19, #240
    b.lt    1b
    // pega 40 pedras e anda 3 s (forca)
    ldr     w9, [x28, #G_STONE]
    add     w9, w9, #40
    str     w9, [x28, #G_STONE]
    mov     w19, #0
2:  mov     w9, #4
    cmp     w19, #90
    b.lt    21f
    mov     w9, #8
21: str     w9, [x28, #G_TESTKEYS]
    bl      surv_update
    add     w19, w19, #1
    cmp     w19, #180
    b.lt    2b
    str     wzr, [x28, #G_TESTKEYS]
    // larga 10 pedras
    mov     w0, #1
    mov     w1, #10
    bl      drop_item
    mov     w21, #0
    ldr     w9, [x28, #G_NOBJ]
    sub     w9, w9, #1
    LA      x10, objs
    add     x10, x10, x9, lsl #3
    ldrb    w11, [x10, #6]
    cmp     w11, #O_STONES
    b.ne    22f
    ldrb    w21, [x10, #7]
22: LA      x0, txt
    LA      x1, t_13
    bl      strcat_cur
    mov     w1, w20
    bl      numcat
    LA      x1, t_14
    bl      strcat_cur
    ldr     s0, [x28, #G_STAMINA]
    fcvtzs  w1, s0
    bl      numcat
    LA      x1, t_15
    bl      strcat_cur
    ldr     w1, [x28, #G_WEIGHT]
    bl      kgcat
    LA      x1, s_slash
    bl      strcat_cur
    ldr     w1, [x28, #G_CAP]
    bl      kgcat
    LA      x1, t_16
    bl      strcat_cur
    mov     w1, w21
    bl      numcat
    LA      x1, t_17
    bl      strcat_cur
    mov     w19, #0                     // as 5 skills (0..100)
3:  add     x9, x28, #G_SKILL
    ldr     s0, [x9, x19, lsl #2]
    fcvtzs  w1, s0
    bl      numcat
    add     w19, w19, #1
    cmp     w19, #NSKILL
    b.ge    31f
    mov     w9, #47                     // '/'
    strb    w9, [x0], #1
    b       3b
31: LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
    // abre as janelas, com o mouse no primeiro quadrado da mochila
    mov     w9, #1
    str     w9, [x28, #G_INVOPEN]
    str     w9, [x28, #G_CHAROPEN]
    mov     w9, #((SLOT_X + 22) * 2)
    scvtf   s0, w9
    str     s0, [x28, #G_MX]
    mov     w9, #((SLOT_Y + 22) * 2)
    scvtf   s0, w9
    str     s0, [x28, #G_MY]
    b       sk_ret

sk_stage1:
    str     wzr, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CHAROPEN]
    str     wzr, [x28, #G_MX]
    str     wzr, [x28, #G_MY]
    str     wzr, [x28, #G_TESTKEYS]
    // corrida sem treino ha 2 min: 40 s parado e ela cai um pouco
    mov     w9, #SKREST
    strh    w9, [x28, #(G_SKIDLE + 2 * SK_RUN)]
    ldr     s0, [x28, #G_SKRUN]
    FC      s1, F_HUNDRED
    fmul    s0, s0, s1
    fcvtzs  w20, s0                     // antes (x100)
    mov     w19, #0
4:  bl      surv_update
    add     w19, w19, #1
    cmp     w19, #2400
    b.lt    4b
    ldr     s0, [x28, #G_SKRUN]
    FC      s1, F_HUNDRED
    fmul    s0, s0, s1
    fcvtzs  w21, s0                     // depois
    // devolve 30 pedras e recolhe a pilha de 10
    ldr     w9, [x28, #G_STONE]
    subs    w9, w9, #30
    csel    w9, wzr, w9, lt
    str     w9, [x28, #G_STONE]
    mov     w22, w9
    mov     w0, #O_STONES
    mov     w1, #O_STONES
    bl      mine_test
    ldr     w9, [x28, #G_STONE]
    sub     w22, w9, w22                // quantas voltaram
    sub     w9, w9, w22
    str     w9, [x28, #G_STONE]         // tira de novo (o teste da agua vem a seguir)
    str     wzr, [x28, #G_HOVOK]
    LA      x0, txt
    LA      x1, t_18
    bl      strcat_cur
    mov     w1, w20
    bl      numcat
    LA      x1, t_19
    bl      strcat_cur
    mov     w1, w21
    bl      numcat
    LA      x1, t_20
    bl      strcat_cur
    mov     w1, w22
    bl      numcat
    LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
    // fome: com 80 a vida nao sobe; depois de comer ate encher, sobe
    mov     w9, #50
    scvtf   s0, w9
    str     s0, [x28, #G_HP]
    mov     w9, #80
    scvtf   s0, w9
    str     s0, [x28, #G_FOOD]
    str     wzr, [x28, #G_SATED]
    mov     w19, #0
5:  bl      surv_update
    add     w19, w19, #1
    cmp     w19, #120
    b.lt    5b
    ldr     s0, [x28, #G_HP]
    fcvtzs  w20, s0                     // vida sem a fome cheia
    ldr     w9, [x28, #G_BERRY]
    add     w9, w9, #2
    str     w9, [x28, #G_BERRY]
    bl      eat_best
    bl      eat_best
    mov     w19, #0
6:  bl      surv_update
    add     w19, w19, #1
    cmp     w19, #1200
    b.lt    6b
    ldr     s0, [x28, #G_HP]
    fcvtzs  w21, s0                     // vida com a fome cheia
    ldr     s0, [x28, #G_FOOD]
    fcvtzs  w22, s0                     // continua cheia?
    // stamina maxima com corrida 50 e natacao 50
    ldr     s8, [x28, #G_SKRUN]
    ldr     s9, [x28, #G_SKSWIM]
    mov     w9, #50
    scvtf   s0, w9
    str     s0, [x28, #G_SKRUN]
    str     s0, [x28, #G_SKSWIM]
    bl      calc_stats
    ldr     s0, [x28, #G_STAMAX]
    fcvtzs  w19, s0
    str     s8, [x28, #G_SKRUN]
    str     s9, [x28, #G_SKSWIM]
    bl      calc_stats
    LA      x0, txt
    LA      x1, t_21
    bl      strcat_cur
    mov     w1, w20
    bl      numcat
    LA      x1, t_22
    bl      strcat_cur
    mov     w1, w21
    bl      numcat
    LA      x1, t_23
    bl      strcat_cur
    mov     w1, w22
    bl      numcat
    LA      x1, t_24
    bl      strcat_cur
    mov     w1, w19
    bl      numcat
    LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
sk_ret:
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// sk_write(x0 = fim do texto em txt): imprime txt
sk_write:
    LA      x9, txt
    sub     x2, x0, x9
    mov     x1, x9
    mov     w0, #1
    b       F(write)

// ct_click(s0 = u, s1 = v): clique esquerdo nesse ponto do mapa (teste)
ct_click:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    FC      s2, F_64
    fmul    s0, s0, s2
    fcvtzs  w9, s0
    str     w9, [x28, #G_HOVU]
    fmul    s1, s1, s2
    fcvtzs  w9, s1
    str     w9, [x28, #G_HOVV]
    mov     w9, #1
    str     w9, [x28, #G_HOVOK]
    mov     w0, #1
    mov     w1, #1
    bl      surv_mouse
    mov     w0, #1
    mov     w1, #0
    bl      surv_mouse
    str     wzr, [x28, #G_HOVOK]
    ldp     x29, x30, [sp], #16
    ret

// ct_count(w0 = tipo) -> w0 = quantos objetos desse tipo existem
ct_count:
    ldr     w9, [x28, #G_NOBJ]
    LA      x10, objs
    mov     w11, w0
    mov     w0, #0
1:  cbz     w9, 9f
    ldrb    w12, [x10, #6]
    cmp     w12, w11
    cinc    w0, w0, eq
    add     x10, x10, #8
    sub     w9, w9, #1
    b       1b
9:  ret

// ct_num(x0 = cursor, x1 = rotulo, w2 = numero) -> x0
ct_num:
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

// surv_selftest_craft(w0 = etapa): teste de fabricar
//   0: fabrica tudo, monta bau e abrigo, guarda madeira no bau; abre a
//      janela de fabricar e a mochila (foto)
//   1: corta uma arvore com o machado e espera a noite (foto com a tocha)
//   2: noite dentro do abrigo; come frutas assadas
    .globl surv_selftest_craft
surv_selftest_craft:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    cmp     w0, #4                      // a etapa 4 continua a noite (nao
    b.eq    ct_stage4                   // mexe no relogio)
    str     wzr, [x28, #G_HOVOK]
    str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_MX]
    str     wzr, [x28, #G_MY]
    str     wzr, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CRAFTOPEN]
    str     wzr, [x28, #G_CHESTOPEN]
    str     wzr, [x28, #G_CHAROPEN]
    mov     w9, #6000                   // de dia
    str     w9, [x28, #G_TIME]
    cmp     w0, #1
    b.eq    ct_stage1
    cmp     w0, #3
    b.eq    ct_stage3
    cmp     w0, #2
    b.eq    ct_stage2
    // ---- etapa 0 ----
    LA      x9, fires                   // do lado da fogueira (para assar)
    ldr     s8, [x9]
    ldr     s9, [x9, #4]
    fmov    s0, #1.5
    fsub    s0, s8, s0
    str     s0, [x28, #G_PU]
    str     s9, [x28, #G_PV]
    ldr     w9, [x28, #G_WOOD]
    add     w9, w9, #40
    str     w9, [x28, #G_WOOD]
    ldr     w9, [x28, #G_STONE]
    add     w9, w9, #20
    str     w9, [x28, #G_STONE]
    ldr     w9, [x28, #G_BERRY]
    add     w9, w9, #6
    str     w9, [x28, #G_BERRY]
    bl      surv_update
    mov     w0, #0                      // machado
    bl      craft
    mov     w0, #1                      // picareta
    bl      craft
    mov     w0, #4                      // 2 tochas
    bl      craft
    mov     w0, #4
    bl      craft
    mov     w0, #10                     // cesto
    bl      craft
    mov     w0, #8                      // frutas assadas (perto do fogo)
    bl      craft
    mov     w0, #8
    bl      craft
    mov     w0, #6                      // bau: 2 celulas ao lado
    bl      craft
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    fmov    s2, #2.0
    fadd    s1, s1, s2
    bl      ct_click
    // abrigo longe da fogueira (8 celulas) para o teste do frio
    fmov    s0, #8.0
    fsub    s0, s8, s0
    str     s0, [x28, #G_PU]
    str     s9, [x28, #G_PV]
    bl      surv_update
    mov     w0, #7                      // abrigo
    bl      craft
    ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    fmov    s2, #1.5
    fadd    s1, s1, s2
    bl      ct_click
    // volta para perto da fogueira e guarda a madeira no bau
    fmov    s0, #1.5
    fsub    s0, s8, s0
    str     s0, [x28, #G_PU]
    str     s9, [x28, #G_PV]
    mov     w0, #O_CHEST
    mov     w1, #O_CHEST
    bl      nearest_obj
    mov     w20, #0
    tbnz    w0, #31, 1f
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrb    w10, [x9, #7]
    add     w10, w10, #1
    str     w10, [x28, #G_CHESTOPEN]
    str     w0, [x28, #G_CHESTOBJ]
    mov     w0, #IT_WOOD
    mov     w1, #0
    bl      chest_move
    ldr     w9, [x28, #G_CHESTOPEN]
    sub     w9, w9, #1
    LA      x10, chests
    add     x10, x10, x9, lsl #7
    ldr     w20, [x10]                  // madeira no bau
    str     wzr, [x28, #G_CHESTOPEN]
1:  bl      surv_update
    LA      x0, txt
    LA      x1, t_c1
    ldr     w2, [x28, #(G_INV + 4 * IT_AXE)]
    bl      ct_num
    LA      x1, t_c2
    ldr     w2, [x28, #(G_INV + 4 * IT_PICK)]
    bl      ct_num
    LA      x1, t_c3
    ldr     w2, [x28, #(G_INV + 4 * IT_TORCH)]
    bl      ct_num
    LA      x1, t_c4
    ldr     w2, [x28, #(G_INV + 4 * IT_BASKET)]
    bl      ct_num
    LA      x1, t_c5
    ldr     w2, [x28, #(G_INV + 4 * IT_COOKED)]
    bl      ct_num
    LA      x1, t_c6
    bl      strcat_cur
    ldr     w1, [x28, #G_CAP]
    bl      kgcat
    mov     x19, x0
    mov     w0, #O_CHEST
    bl      ct_count
    mov     w2, w0
    mov     x0, x19
    LA      x1, t_c7
    bl      ct_num
    LA      x1, t_c8
    mov     w2, w20
    bl      ct_num
    mov     x19, x0
    mov     w0, #O_SHELTER
    bl      ct_count
    mov     w2, w0
    mov     x0, x19
    LA      x1, t_c9
    bl      ct_num
    LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
    // janelas para a foto: fabricar + mochila, mouse no machado
    mov     w9, #1
    str     w9, [x28, #G_CRAFTOPEN]
    str     w9, [x28, #G_INVOPEN]
    mov     w9, #((CRF_GX + 18) * 2)   // mouse no icone do machado
    scvtf   s0, w9
    str     s0, [x28, #G_MX]
    mov     w9, #((CRF_GY + 18) * 2)
    scvtf   s0, w9
    str     s0, [x28, #G_MY]
    b       ct_ret

ct_stage1:
    mov     w0, #IT_AXE                 // machado na mao
    bl      equip
    mov     w0, #O_TREE                 // corta uma arvore com o machado
    mov     w1, #O_PINE
    bl      mine_test
    ldr     w19, [x28, #G_AXEDUR]
    mov     w0, #IT_TORCH               // tocha na outra mao
    bl      equip
    mov     w9, #28000                  // noite
    str     w9, [x28, #G_TIME]
    mov     w20, #0
2:  bl      surv_update
    add     w20, w20, #1
    cmp     w20, #60
    b.lt    2b
    LA      x0, txt
    LA      x1, t_c10
    mov     w2, w19
    bl      ct_num
    LA      x1, t_c11
    ldr     w2, [x28, #G_TORCHLIT]
    bl      ct_num
    LA      x1, t_c12
    ldr     w2, [x28, #(G_INV + 4 * IT_TORCH)]
    bl      ct_num
    LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
    mov     w9, #28000
    str     w9, [x28, #G_TIME]
    b       ct_ret

ct_stage2:
    mov     w0, #O_SHELTER              // noite dentro do abrigo
    mov     w1, #O_SHELTER
    bl      nearest_obj
    mov     w19, #0
    mov     w20, #0
    tbnz    w0, #31, 4f
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrh    w10, [x9]
    scvtf   s0, w10
    ldrh    w10, [x9, #2]
    scvtf   s1, w10
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    str     s0, [x28, #G_PU]
    str     s1, [x28, #G_PV]
    mov     w9, #50
    scvtf   s0, w9
    str     s0, [x28, #G_WARM]
    mov     w9, #28000
    str     w9, [x28, #G_TIME]
    mov     w21, #0
3:  bl      surv_update
    add     w21, w21, #1
    cmp     w21, #480
    b.lt    3b
    ldr     s0, [x28, #G_WARM]
    fcvtzs  w19, s0
    ldr     w20, [x28, #G_INSHELTER]
4:  mov     w9, #40                     // frutas assadas: +50
    scvtf   s0, w9
    str     s0, [x28, #G_FOOD]
    str     wzr, [x28, #G_SATED]
    bl      eat_best
    ldr     s0, [x28, #G_FOOD]
    fcvtzs  w21, s0
    LA      x0, txt
    LA      x1, t_c13
    mov     w2, w19
    bl      ct_num
    LA      x1, t_c14
    mov     w2, w20
    bl      ct_num
    LA      x1, t_c15
    mov     w2, w21
    bl      ct_num
    LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
    // foto: de dia, o personagem do lado da cabana
    mov     w9, #6000
    str     w9, [x28, #G_TIME]
    mov     w0, #O_SHELTER
    mov     w1, #O_SHELTER
    bl      nearest_obj
    tbnz    w0, #31, 1f
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrh    w10, [x9]
    scvtf   s0, w10
    ldrh    w10, [x9, #2]
    scvtf   s1, w10
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    fmov    s2, #2.0
    fadd    s0, s0, s2
    fmov    s2, #1.0
    fadd    s1, s1, s2
    str     s0, [x28, #G_PU]
    str     s1, [x28, #G_PV]
1:  bl      surv_update
    b       ct_ret

    // ---- etapa 3: deita na cabana as 22h (foto dormindo) ----
ct_stage3:
    mov     w9, #28800                  // 22:00
    str     w9, [x28, #G_TIME]
    FC      s0, F_HUNDRED
    str     s0, [x28, #G_HP]
    str     s0, [x28, #G_FOOD]
    str     s0, [x28, #G_WARM]
    str     wzr, [x28, #G_SATED]
    mov     w0, #O_SHELTER
    mov     w1, #O_SHELTER
    bl      nearest_obj
    tbnz    w0, #31, ct_ret
    bl      try_sleep
    mov     w19, #0
1:  bl      surv_update
    add     w19, w19, #1
    cmp     w19, #3000
    b.lt    1b
    b       ct_ret

    // ---- etapa 4: dorme ate acordar e imprime ----
ct_stage4:                              // dorme ate acordar
    ldr     w9, [x28, #G_DAY]
    mov     w20, w9                     // dia em que deitou
    MOVI32  w19, 30000                  // (limite)
1:  ldr     w9, [x28, #G_SLEEP]
    cbz     w9, 2f
    bl      surv_update
    subs    w19, w19, #1
    b.ne    1b
2:  LA      x0, lbuf                    // hora em que acordou
    bl      surv_clock
    LA      x0, txt
    LA      x1, t_s1
    ldr     w2, [x28, #G_SLEEP]
    bl      ct_num
    LA      x1, t_s2
    bl      strcat_cur
    LA      x1, lbuf
    add     x1, x1, #6                  // sem o "   -  "
    bl      strcat_cur
    LA      x1, t_s3
    ldr     s0, [x28, #G_FOOD]
    fcvtzs  w2, s0
    bl      ct_num
    LA      x1, t_s4
    ldr     s0, [x28, #G_WARM]
    fcvtzs  w2, s0
    bl      ct_num
    LA      x1, t_s5
    ldr     s0, [x28, #G_HP]
    fcvtzs  w2, s0
    bl      ct_num
    LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
    mov     w9, #6000
    str     w9, [x28, #G_TIME]
ct_ret:
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// surv_selftest_weather(w0 = clima): 10 s nesse clima, em terra longe da
// fogueira (na enchente: numa praia baixa); imprime calor, vida e agua
    .globl surv_selftest_weather
surv_selftest_weather:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     d8, d9, [sp, #48]
    mov     w19, w0
    str     wzr, [x28, #G_HOVOK]
    str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_TESTKEYS]
    mov     w9, #6000                   // de dia
    str     w9, [x28, #G_TIME]
    mov     w21, #60                    // elevacao: campo
    mov     w22, #E_HILL
    cmp     w19, #W_FLOOD
    b.ne    1f
    mov     w21, #10                    // enchente: praia / campo baixo
    mov     w22, #90
1:  mov     w20, #10                    // espiral a partir da fogueira
2:  mov     w9, #0
    str     w9, [sp, #64]
3:  LA      x9, dirtab
    ldr     w10, [sp, #64]
    add     x9, x9, x10, lsl #2
    ldrsh   w10, [x9]
    scvtf   s0, w10
    ldrsh   w10, [x9, #2]
    scvtf   s1, w10
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    scvtf   s2, w20
    LA      x9, fires
    ldr     s3, [x9]
    fmadd   s8, s0, s2, s3
    ldr     s3, [x9, #4]
    fmadd   s9, s1, s2, s3
    fmov    s0, s8
    fmov    s1, s9
    bl      elev_at
    cmp     w0, w21
    b.lt    4f
    cmp     w0, w22
    b.lt    5f
4:  ldr     w9, [sp, #64]
    add     w9, w9, #1
    str     w9, [sp, #64]
    cmp     w9, #16
    b.lt    3b
    add     w20, w20, #2
    cmp     w20, #200
    b.lt    2b
5:  str     s8, [x28, #G_PU]
    str     s9, [x28, #G_PV]
    mov     w0, w19                     // o clima, ja forte
    MOVI32  w1, 100000
    MOVI32  w2, 50000
    bl      weather_set
    mov     w9, #50
    scvtf   s0, w9
    str     s0, [x28, #G_WARM]
    FC      s0, F_HUNDRED
    str     s0, [x28, #G_HP]
    mov     w9, #90                     // fome 90: sem cura (so com ela cheia)
    scvtf   s0, w9
    str     s0, [x28, #G_FOOD]
    str     wzr, [x28, #G_SATED]
    mov     w20, #0
6:  bl      surv_update
    add     w20, w20, #1
    cmp     w20, #600
    b.lt    6b
    LA      x0, txt
    LA      x1, t_w1
    bl      strcat_cur
    LA      x1, wnames
    add     x1, x1, x19, lsl #4
    bl      strcat_cur
    ldr     s0, [x28, #G_WARM]
    fcvtzs  w2, s0
    LA      x1, t_w2
    bl      ct_num
    ldr     s0, [x28, #G_HP]
    fcvtzs  w2, s0
    LA      x1, t_w3
    bl      ct_num
    LA      x1, t_w4
    ldr     w2, [x28, #G_FLOOD]
    bl      ct_num
    LA      x1, t_w5
    ldr     w2, [x28, #G_WATER]
    bl      ct_num
    LA      x1, t_w6
    ldr     w2, [x28, #G_AMBR]
    bl      ct_num
    LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ht_click_at(w0 = animal): mira nele e clica (arco atira, perto golpeia)
ht_click_at:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x9, animals
    add     x9, x9, x0, lsl #5
    ldr     s0, [x9]
    ldr     s1, [x9, #4]
    FC      s2, F_64
    fmul    s0, s0, s2
    fcvtzs  w10, s0
    str     w10, [x28, #G_HOVU]
    fmul    s1, s1, s2
    fcvtzs  w10, s1
    str     w10, [x28, #G_HOVV]
    mov     w10, #1
    str     w10, [x28, #G_HOVOK]
    bl      surv_update                 // (acha o animal sob o mouse)
    mov     w0, #1
    mov     w1, #1
    bl      surv_mouse
    mov     w0, #1
    mov     w1, #0
    bl      surv_mouse
    ldp     x29, x30, [sp], #16
    ret

// ht_alive(w0 = animal, w1 = tipo) -> w0 = 1 se ainda vivo
ht_alive:
    LA      x9, animals
    add     x9, x9, x0, lsl #5
    ldrb    w9, [x9, #16]
    cmp     w9, w1
    cset    w0, eq
    ret

// ht_spawn_near(w0 = tipo, s0 = du, s1 = dv) -> w0 animal perto do personagem (teste)
// (se o ponto for agua, gira 90 graus ate achar terra)
ht_spawn_near:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     d8, d9, [sp, #32]
    stp     d10, d11, [sp, #48]
    mov     w19, w0
    fmov    s8, s0
    fmov    s9, s1
    mov     w20, #4
1:  ldr     s10, [x28, #G_PU]
    fadd    s10, s10, s8
    ldr     s11, [x28, #G_PV]
    fadd    s11, s11, s9
    fmov    s0, s10
    fmov    s1, s11
    bl      terrain_class
    tbz     w0, #31, 2f
    fneg    s2, s9                      // gira (du, dv) -> (-dv, du)
    fmov    s9, s8
    fmov    s8, s2
    subs    w20, w20, #1
    b.ne    1b
2:  mov     w0, w19
    fmov    s0, s10
    fmov    s1, s11
    bl      animal_spawn
    ldp     d10, d11, [sp, #48]
    ldp     d8, d9, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// surv_selftest_hunt(w0 = etapa)
//   0: arco na mao, tocha na outra; um animal de cada perto (foto)
//   1: caca um cervo com o arco, recolhe a carne; um lobo de noite;
//      machado contra o lobo; animais aparecendo sozinhos
    .globl surv_selftest_hunt
surv_selftest_hunt:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     wzr, [x28, #G_HOVOK]
    str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_MX]
    str     wzr, [x28, #G_MY]
    str     wzr, [x28, #G_INVOPEN]
    str     wzr, [x28, #G_CRAFTOPEN]
    str     wzr, [x28, #G_CHESTOPEN]
    str     wzr, [x28, #G_CHAROPEN]
    mov     w9, #6000
    str     w9, [x28, #G_TIME]
    str     wzr, [x28, #G_PLACE]
    str     wzr, [x28, #G_SLEEP]
    bl      animals_reset
    cbnz    w0, ht_stage1
    // ---- etapa 0: foto ----
    mov     w9, #1
    str     w9, [x28, #(G_INV + 4 * IT_BOW)]
    mov     w9, #12
    str     w9, [x28, #(G_INV + 4 * IT_ARROW)]
    mov     w0, #IT_BOW
    bl      equip
    ldr     w9, [x28, #G_OFFHAND]
    cbnz    w9, 1f
    mov     w0, #IT_TORCH
    bl      equip
1:  mov     w0, #A_RABBIT
    fmov    s0, #3.0
    fmov    s1, #-1.0
    bl      ht_spawn_near
    mov     w0, #A_DEER
    fmov    s0, #4.0
    fmov    s1, #2.0
    bl      ht_spawn_near
    mov     w0, #A_GOAT
    fmov    s0, #-3.0
    fmov    s1, #3.0
    bl      ht_spawn_near
    mov     w0, #A_WOLF
    fmov    s0, #5.0
    fmov    s1, #3.0
    bl      ht_spawn_near
    mov     w0, #A_BEAR
    fmov    s0, #-4.0
    fmov    s1, #-2.0
    bl      ht_spawn_near
    mov     w0, #A_CRAB
    fmov    s0, #1.0
    fmov    s1, #-4.0
    bl      ht_spawn_near
    mov     w19, #0
2:  bl      surv_update
    add     w19, w19, #1
    cmp     w19, #20
    b.lt    2b
    b       ht_ret
ht_stage1:
    ldr     w9, [x28, #G_DEAD]          // (diagnostico: ja morreu antes?)
    cbz     w9, 0f
    LA      x0, txt
    LA      x1, t_hdead
    bl      strcat_cur
    ldr     x1, [x28, #G_DEATHMSG]
    cbz     x1, 01f
    bl      strcat_cur
01: LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
0:
    // ---- caca: cervo a 5 celulas (ele foge); flechas a cada 31 quadros ----
    mov     w9, #12
    str     w9, [x28, #(G_INV + 4 * IT_ARROW)]
    mov     w0, #IT_BOW
    ldr     w9, [x28, #G_HAND]
    cmp     w9, #(IT_BOW + 1)
    b.eq    1f
    bl      equip
1:  mov     w0, #(O_LOGS + IT_MEAT)
    bl      ct_count
    mov     w23, w0                     // pilhas de carne antes
    mov     w0, #A_DEER
    fmov    s0, #5.0
    fmov    s1, wzr
    bl      ht_spawn_near
    mov     w19, w0                     // o cervo
    mov     w20, #0
2:  mov     w0, w19
    mov     w1, #A_DEER
    bl      ht_alive
    cbz     w0, 4f
    mov     w0, w19
    bl      ht_click_at
    mov     w21, #0
3:  bl      surv_update
    add     w21, w21, #1
    cmp     w21, #30
    b.lt    3b
    add     w20, w20, #1
    cmp     w20, #10
    b.lt    2b
4:  mov     w9, #12
    ldr     w10, [x28, #(G_INV + 4 * IT_ARROW)]
    sub     w20, w9, w10                // flechas usadas
    mov     w0, #(O_LOGS + IT_MEAT)
    bl      ct_count
    sub     w21, w0, w23                // pilhas de carne novas (abatido)
    str     wzr, [x28, #G_HAND]         // maos vazias para recolher
    mov     w0, #(O_LOGS + IT_MEAT)
    mov     w1, #(O_LOGS + IT_MEAT)
    bl      mine_test
    mov     w0, #(O_LOGS + IT_HIDE)
    mov     w1, #(O_LOGS + IT_HIDE)
    bl      mine_test
    LA      x0, txt
    LA      x1, t_h1
    mov     w2, w21
    bl      ct_num
    LA      x1, t_h2
    mov     w2, w20
    bl      ct_num
    LA      x1, t_h3
    ldr     w2, [x28, #(G_INV + 4 * IT_MEAT)]
    bl      ct_num
    LA      x1, t_h4
    ldr     w2, [x28, #(G_INV + 4 * IT_HIDE)]
    bl      ct_num
    LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
    // ---- lobo de noite, sem fogo nem tocha ----
    str     wzr, [x28, #G_OFFHAND]
    mov     w9, #28800
    str     w9, [x28, #G_TIME]
    FC      s0, F_HUNDRED
    str     s0, [x28, #G_HP]
    mov     w0, #A_WOLF
    fmov    s0, #3.0
    fmov    s1, wzr
    bl      ht_spawn_near
    mov     w19, w0
    mov     w21, #0
5:  bl      surv_update
    add     w21, w21, #1
    cmp     w21, #150
    b.lt    5b
    ldr     s0, [x28, #G_HP]
    fcvtzs  w20, s0                     // vida depois das mordidas
    ldr     w9, [x28, #G_NEARFIRE]
    mov     w22, w9
    // machado na mao: golpes no lobo
    mov     w9, #1
    str     w9, [x28, #(G_INV + 4 * IT_AXE)]
    mov     w9, #TOOLDUR
    str     w9, [x28, #G_AXEDUR]
    mov     w0, #IT_AXE
    bl      equip
    mov     w23, #0
6:  mov     w0, w19
    mov     w1, #A_WOLF
    bl      ht_alive
    cbz     w0, 7f
    mov     w0, w19
    bl      ht_click_at
    mov     w21, #0
61: bl      surv_update
    add     w21, w21, #1
    cmp     w21, #31
    b.lt    61b
    add     w23, w23, #1
    cmp     w23, #8
    b.lt    6b
7:  mov     w0, w19
    mov     w1, #A_WOLF
    bl      ht_alive
    eor     w24, w0, #1                 // 1 = abatido
    LA      x0, txt
    LA      x1, t_h5
    mov     w2, w20
    bl      ct_num
    LA      x1, t_h6
    mov     w2, w22
    bl      ct_num
    LA      x1, t_h7
    mov     w2, w24
    bl      ct_num
    LA      x1, t_h8
    mov     w2, w23
    bl      ct_num
    LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
    // ---- 15 s de dia: animais aparecem sozinhos pelo terreno ----
    FC      s0, F_HUNDRED
    str     s0, [x28, #G_HP]
    mov     w9, #6000
    str     w9, [x28, #G_TIME]
    bl      animals_reset
    str     wzr, [x28, #G_NOSPAWN]      // agora sim: aparecem sozinhos
    mov     w21, #0
8:  bl      surv_update
    add     w21, w21, #1
    cmp     w21, #900
    b.lt    8b
    LA      x0, txt
    LA      x1, t_h9
    bl      strcat_cur
    mov     w19, #0
9:  LA      x1, animnames
    add     x1, x1, x19, lsl #4
    bl      strcat_cur
    mov     w9, #61                     // '='
    strb    w9, [x0], #1
    mov     x20, x0
    mov     w0, w19
    bl      ct_animals
    mov     w1, w0
    mov     x0, x20
    bl      numcat
    mov     w9, #32
    strb    w9, [x0], #1
    strb    wzr, [x0]
    add     w19, w19, #1
    cmp     w19, #NATYPES
    b.lt    9b
    LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
    mov     w9, #1
    str     w9, [x28, #G_NOSPAWN]
    bl      animals_reset
ht_ret:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// surv_selftest_water(w0 = etapa): teste automatico da agua
//   0: coloca o personagem em agua funda longe da borda e deixa nadar
//   1: coloca no mar aberto (perto da borda); o tubarao vem chegando
//   2: espera o tubarao atacar e imprime o resultado
    .globl surv_selftest_water
surv_selftest_water:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     d8, d9, [sp, #32]
    str     x21, [sp, #48]
    mov     w21, w0
    str     wzr, [x28, #G_HOVOK]
    str     wzr, [x28, #G_LMB]
    mov     w9, #6000                   // de dia, para a foto
    str     w9, [x28, #G_TIME]
    cmp     w21, #1
    b.eq    sw_ocean
    b.gt    sw_wait
    // etapa 0: agua funda longe da borda (espiral a partir do centro)
    mov     w19, #0
1:  mov     w20, #0
2:  LA      x9, dirtab
    add     x9, x9, x20, lsl #2
    ldrsh   w10, [x9]
    scvtf   s0, w10
    ldrsh   w10, [x9, #2]
    scvtf   s1, w10
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    scvtf   s2, w19
    mov     w9, #256
    scvtf   s3, w9
    fmadd   s8, s0, s2, s3
    fmadd   s9, s1, s2, s3
    fmov    s0, s8
    fmov    s1, s9
    bl      elev_at
    mov     w9, #-300
    cmp     w0, w9
    b.ge    3f
    fcvtzs  w9, s8                      // longe da borda
    fcvtzs  w10, s9
    mov     w11, #(W_BORDER + 10)
    cmp     w9, w11
    b.lt    3f
    cmp     w10, w11
    b.lt    3f
    mov     w12, #(511 - W_BORDER - 10)
    cmp     w9, w12
    b.gt    3f
    cmp     w10, w12
    b.le    sw_found
3:  add     w20, w20, #1
    cmp     w20, #16
    b.lt    2b
    add     w19, w19, #2
    cmp     w19, #200
    b.lt    1b
    b       sw_print0                   // nenhum lago fundo neste mundo
sw_found:
    str     s8, [x28, #G_PU]
    str     s9, [x28, #G_PV]
    mov     w19, #0
4:  bl      surv_update
    add     w19, w19, #1
    cmp     w19, #240
    b.lt    4b
sw_print0:
    LA      x0, txt
    LA      x1, t_9
    bl      strcat_cur
    ldr     w1, [x28, #G_WATER]
    bl      numcat
    LA      x1, t_10
    bl      strcat_cur
    ldr     s0, [x28, #G_STAMINA]
    fcvtzs  w1, s0
    bl      numcat
    b       sw_write
    // etapa 1: mar aberto, perto da borda oeste
sw_ocean:
    mov     w19, #100
5:  mov     w9, #24
    scvtf   s8, w9
    scvtf   s9, w19
    fmov    s0, s8
    fmov    s1, s9
    bl      elev_at
    mov     w9, #-W_OCEAN
    cmp     w0, w9
    b.lt    6f
    add     w19, w19, #10
    cmp     w19, #412
    b.lt    5b
6:  str     s8, [x28, #G_PU]
    str     s9, [x28, #G_PV]
    mov     w19, #0
7:  bl      surv_update
    add     w19, w19, #1
    cmp     w19, #300
    b.lt    7b
    b       sw_ret
    // etapa 2: espera o ataque
sw_wait:
    mov     w19, #0
8:  bl      surv_update
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, 9f
    add     w19, w19, #1
    cmp     w19, #400
    b.lt    8b
9:  LA      x0, txt
    LA      x1, t_11
    bl      strcat_cur
    ldr     w1, [x28, #G_SHARK]
    bl      numcat
    LA      x1, t_12
    bl      strcat_cur
    ldr     w1, [x28, #G_DEAD]
    bl      numcat
    LA      x1, s_nl
    bl      strcat_cur
sw_write:
    LA      x9, txt
    sub     x2, x0, x9
    mov     x1, x9
    mov     w0, #1
    bl      F(write)
sw_ret:
    ldr     x21, [sp, #48]
    ldp     d8, d9, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// =====================================================================
//  Dados
// =====================================================================
    .data
    .p2align 2
fconsts:
    .float 64.0             // F_64
    .float 0.015625         // F_INV64
    .float 0.075            // F_SPEED (celulas por quadro)
    .float 9.0              // F_REACH2 (alcance de 3 celulas)
    .float 0.00115          // F_FOODRATE (100 -> 0 em ~24 min)
    .float 0.0075           // F_COLD
    .float 0.05             // F_HEAT
    .float 0.0125           // F_DAYWARM
    .float 0.00625          // F_STARVE
    .float 0.01             // F_FREEZE
    .float 0.003            // F_REGEN
    .float 100.0            // F_HUNDRED
    .float 25.0             // F_FIRE2 (calor ate 5 celulas)
    .float 40.0             // F_FORTY
    .float 15.0             // F_EAT
    .float 15.0             // F_VISDAY (raio de visao de dia, celulas)
    .float 5.0              // F_VISNIGHT (de noite)
    .float 0.00390625       // F_INV256
    .float 6.5              // F_FIREVIS (fogueira ilumina em volta)
    .float 0.99984770       // F_COS1 (cos 1 grau)
    .float 0.01745241       // F_SIN1 (sen 1 grau)
    .float 0.35             // F_RAYSTEP
    .float 0.7              // F_P7
    .float 0.3              // F_P3
    .float 0.8              // F_P8
    .float 255.0            // F_255
    .float 0.3              // F_TREEBLK (quanto cada arvore tapa)
    .float 0.22             // F_TIRED (velocidade sem folego)
    .float 0.12             // F_SWIMCOST (100 -> 0 em ~14 s nadando)
    .float 0.2              // F_RECOV (stamina volta andando em terra)
    .float 0.2              // F_RECOVSH (no raso)
    .float 0.25             // F_DROWN (vida perdida afogando)
    .float 0.01             // F_WETCOLD (a agua esfria)
    .float 3.0              // F_SHARKR (raio inicial da barbatana)
    .float 0.3              // F_RUNCOST (100 -> 0 em ~5.5 s correndo)
    .float 0.4              // F_RECOVREST (parado em terra)
    .float 1.7              // F_RUNBASE (velocidade correndo, skill 0)
    .float 0.005            // F_RUNSK (+0.5 com skill 100)
    .float 0.45             // F_SWIMBASE (velocidade nadando, skill 0)
    .float 0.0035           // F_SWIMSK (+0.35 com skill 100)
    .float 0.006            // F_SK6 (skill 100 corta 60%)
    .float 0.005            // F_SK5 (skill 100 corta 50%)
    .float 0.55             // F_HEAVY (velocidade sobrecarregado)
    .float 25.0             // F_25
    .float 0.003            // F_XPSWIM (por quadro nadando)
    .float 0.0025           // F_XPRUN (por quadro correndo)
    .float 0.3              // F_XPCHOP (por madeira)
    .float 0.375            // F_XPMINE (por pedra)
    .float 0.0015           // F_XPSTR (por quadro andando carregado)
    .float 0.0000625        // F_SKDECAY (~1 ponto a cada 4 min sem treino)
    .float 1.05             // F_P105
    .float 0.01             // F_INV100
    .float 0.1              // F_TENTH
    .float 0.4              // F_STAMSK (stamina max: +0.4 por ponto de corrida e de natacao)
    .float 10.0             // F_TORCHVIS (com tocha enxerga 10 celulas de noite)
    .float 50.0             // F_EATCOOKED (frutas assadas)

// velocidade em cada nivel de agua: terra, raso, fundo, mar aberto
waterspeed:
    .float 1.0, 0.6, 0.45, 0.45

// nomes dos niveis de agua (32 bytes cada)
    .p2align 5
waternames:
    .asciz ""
    .p2align 5
    .asciz "Agua rasa"
    .p2align 5
    .asciz "Nadando"
    .p2align 5
    .asciz "MAR ABERTO - TUBARAO!"
    .p2align 5

    .p2align 2
dirtab:
    .hword 64, 0,    59, 24,   45, 45,   24, 59
    .hword 0, 64,   -24, 59,  -45, 45,  -59, 24
    .hword -64, 0,  -59, -24, -45, -45, -24, -59
    .hword 0, -64,   24, -59,  45, -45,  59, -24

// quadros para coletar 1 unidade: arvore, pinheiro, pedra, arbusto, ...
// as pilhas largadas (12..29), bau (20) e abrigo (21)
minetime:
    .byte 45, 45, 70, 25, 0, 0, 0, 0
    .byte 0, 0, 0, 0, 6, 6, 6, 6
    .byte 6, 6, 6, 6, 40, 40, 6, 6
    .byte 6, 6, 6, 6, 6, 6, 0, 0

// peso de cada item (decimos de kg)
    .p2align 1
itemweight:
    .hword 15, 20, 1, 20, 25, 5, 3, 10, 100, 120, 200   // ... abrigo
    .hword 15, 1, 5, 4, 10, 30, 20                     // arco ... mochila de couro

// texto que sobe ao coletar cada item
    .p2align 3
popitem:
    .quad p_wood, p_stone, p_berry, p_axe, p_pick, p_torch, p_cooked, p_basket
    .quad p_wood, p_wood, p_wood, p_bow, p_arrow, p_meat, p_cmeat, p_hide
    .quad p_coat, p_lbag

// sprite de cada item (icone na mochila; 12 + item tambem e a pilha)
itemicon:
    .byte 12, 13, 14, 15, 16, 17, 18, 19, SPR_FIRE, 20, 21
    .byte 23, 24, 25, 26, 27, 28, 29

// barra "na mao": teclas 1-4
hotbar:
    .byte IT_AXE, IT_PICK, IT_BOW, IT_TORCH
hbkeys:
    .asciz "1", "2", "3", "4"

// comida: quanto enche (0 = nao se come) e a ordem do E
    .p2align 2
eatvalue:
    .float 0, 0, 15, 0, 0, 0, 50, 0, 0, 0, 0, 0, 0, 10, 60, 0, 0, 0
eatorder:
    .byte IT_CMEAT, IT_COOKED, IT_BERRY, IT_MEAT
    .p2align 3
eatpop:
    .quad 0, 0, p_eat, 0, 0, 0, p_eatc, 0, 0, 0, 0, 0, 0, p_eatraw, p_eatm, 0, 0, 0
handpop:
    .quad 0, 0, 0, p_haxe, p_hpick, 0, 0, 0, 0, 0, 0, p_hbow, 0, 0, 0, 0, 0, 0
nohave:
    .quad 0, 0, 0, m_noaxe, m_nopick, 0, 0, 0, 0, 0, 0, m_nobow, 0, 0, 0, 0, 0, 0

// receitas (16 bytes): resultado, quantos, precisa de fogo, 0, e ate 4
// pares (item, quantos)
    .p2align 4
recipes:
    .byte IT_AXE,     1, 0, 0, IT_WOOD, 3, IT_STONE, 2, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_PICK,    1, 0, 0, IT_WOOD, 3, IT_STONE, 3, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_BOW,     1, 0, 0, IT_WOOD, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_ARROW,   4, 0, 0, IT_WOOD, 1, IT_STONE, 1, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_TORCH,   1, 0, 0, IT_WOOD, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_FIRE,    1, 0, 0, IT_WOOD, 5, IT_STONE, 3, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_CHEST,   1, 0, 0, IT_WOOD, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_SHELTER, 1, 0, 0, IT_WOOD, 12, IT_STONE, 4, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_COOKED,  1, 1, 0, IT_BERRY, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_CMEAT,   1, 1, 0, IT_MEAT, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_BASKET,  1, 0, 0, IT_WOOD, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_COAT,    1, 0, 0, IT_HIDE, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .byte IT_LBAG,    1, 0, 0, IT_HIDE, 3, IT_WOOD, 2, 0, 0, 0, 0, 0, 0, 0, 0

// o que cada receita faz (2 linhas de 32 bytes)
    .p2align 5
recdesc:
    .asciz "Na mao: corta arvores"
    .p2align 5
    .asciz "2x. Dura 40 usos. [1]"
    .p2align 5
    .asciz "Na mao: quebra pedras"
    .p2align 5
    .asciz "2x. Dura 40 usos. [2]"
    .p2align 5
    .asciz "Na mao: clique atira"
    .p2align 5
    .asciz "flechas na mira. [3]"
    .p2align 5
    .asciz "4 flechas para o arco."
    .p2align 5
    .asciz "Somem ao acertar."
    .p2align 5
    .asciz "Outra mao: acende a"
    .p2align 5
    .asciz "noite por 4 min. [4]"
    .p2align 5
    .asciz "Luz e calor. Clique"
    .p2align 5
    .asciz "no mapa para montar."
    .p2align 5
    .asciz "Guarda itens sem peso."
    .p2align 5
    .asciz "Botao direito abre."
    .p2align 5
    .asciz "Dentro dele voce nao"
    .p2align 5
    .asciz "passa frio a noite."
    .p2align 5
    .asciz "Enchem 50 de fome."
    .p2align 5
    .asciz "Perto de uma fogueira."
    .p2align 5
    .asciz "Enche 60 de fome."
    .p2align 5
    .asciz "Perto de uma fogueira."
    .p2align 5
    .asciz "+10 kg na mochila"
    .p2align 5
    .asciz "(so um cesto conta)."
    .p2align 5
    .asciz "Metade do frio da"
    .p2align 5
    .asciz "noite, agua e clima."
    .p2align 5
    .asciz "+20 kg na mochila"
    .p2align 5
    .asciz "(soma com o cesto)."
    .p2align 5

// nomes curtos para o custo (16 bytes)
    .p2align 4
costnames:
    .asciz "madeira"
    .p2align 4
    .asciz "pedra"
    .p2align 4
    .asciz "frutas"
    .p2align 4
    .asciz "machado"
    .p2align 4
    .asciz "picareta"
    .p2align 4
    .asciz "tocha"
    .p2align 4
    .asciz "frutas ass."
    .p2align 4
    .asciz "cesto"
    .p2align 4
    .asciz "fogueira"
    .p2align 4
    .asciz "bau"
    .p2align 4
    .asciz "abrigo"
    .p2align 4
    .asciz "arco"
    .p2align 4
    .asciz "flechas"
    .p2align 4
    .asciz "carne"
    .p2align 4
    .asciz "carne ass."
    .p2align 4
    .asciz "couro"
    .p2align 4
    .asciz "roupa"
    .p2align 4
    .asciz "mochila"
    .p2align 4

// nomes (16 bytes cada)
    .p2align 4
itemnames:
    .asciz "Madeira"
    .p2align 4
    .asciz "Pedra"
    .p2align 4
    .asciz "Frutas"
    .p2align 4
    .asciz "Machado"
    .p2align 4
    .asciz "Picareta"
    .p2align 4
    .asciz "Tocha"
    .p2align 4
    .asciz "Frutas assadas"
    .p2align 4
    .asciz "Cesto"
    .p2align 4
    .asciz "Fogueira"
    .p2align 4
    .asciz "Bau"
    .p2align 4
    .asciz "Abrigo"
    .p2align 4
    .asciz "Arco"
    .p2align 4
    .asciz "Flechas"
    .p2align 4
    .asciz "Carne crua"
    .p2align 4
    .asciz "Carne assada"
    .p2align 4
    .asciz "Couro"
    .p2align 4
    .asciz "Roupa de couro"
    .p2align 4
    .asciz "Mochila couro"
    .p2align 4
skillnames:
    .asciz "Natacao"
    .p2align 4
    .asciz "Corrida"
    .p2align 4
    .asciz "Lenhador"
    .p2align 4
    .asciz "Mineracao"
    .p2align 4
    .asciz "Forca"
    .p2align 4

// cor da barra de cada skill (0x00RRGGBB)
skcolors:
    .word 0x0050B4F0, 0x00F0D050, 0x00B47A44, 0x00A8B0BC, 0x00E05A46

// nomes dos objetos (32 bytes cada)
    .p2align 5
objnames:
    .asciz "Arvore"
    .p2align 5
    .asciz "Pinheiro"
    .p2align 5
    .asciz "Pedra"
    .p2align 5
    .asciz "Arbusto com frutas"
    .p2align 5
    .asciz "Arbusto (sem frutas)"
    .p2align 5
    .asciz ""                           // 5-11: nao sao objetos do mapa
    .p2align 5
    .asciz ""
    .p2align 5
    .asciz ""
    .p2align 5
    .asciz ""
    .p2align 5
    .asciz ""
    .p2align 5
    .asciz ""
    .p2align 5
    .asciz ""
    .p2align 5
    .asciz "Toras largadas"
    .p2align 5
    .asciz "Pedras largadas"
    .p2align 5
    .asciz "Frutas largadas"
    .p2align 5
    .asciz "Machado largado"
    .p2align 5
    .asciz "Picareta largada"
    .p2align 5
    .asciz "Tochas largadas"
    .p2align 5
    .asciz "Frutas assadas"
    .p2align 5
    .asciz "Cesto largado"
    .p2align 5
    .asciz "Bau (botao dir.: abrir)"
    .p2align 5
    .asciz "Abrigo (botao dir.: dormir)"
    .p2align 5
    .asciz ""
    .p2align 5
    .asciz "Arco largado"
    .p2align 5
    .asciz "Flechas largadas"
    .p2align 5
    .asciz "Carne crua"
    .p2align 5
    .asciz "Carne assada"
    .p2align 5
    .asciz "Couro"
    .p2align 5
    .asciz "Roupa de couro"
    .p2align 5
    .asciz "Mochila de couro"
    .p2align 5

m_start:        .asciz "Colete madeira e pedra. Faca uma fogueira (F) antes da noite!"
m_dusk:         .asciz "Esta escurecendo... prepare uma fogueira (F)"
m_dead:         .asciz "Voce nao sobreviveu"
m_noberry:      .asciz "Sem frutas. Colete nos arbustos"
m_needres:      .asciz "Fogueira precisa de 5 madeiras e 3 pedras"
m_toomanyfires: .asciz "Fogueiras demais"
m_water:        .asciz "Nao da para acender fogo na agua"
m_fire:         .asciz "Fogueira acesa! Botao direito nela para por lenha"
m_far:          .asciz "Chegue mais perto"
m_nowood:       .asciz "Sem madeira"
p_wood:         .asciz "+1 madeira"
p_stone:        .asciz "+1 pedra"
p_berry:        .asciz "+1 fruta"
p_eat:          .asciz "Nham! +15"
p_log:          .asciz "+2 min de fogo"
s_dia:          .asciz "   -   Dia "
s_sp3:          .asciz "   "
s_paused:       .asciz "   PAUSADO"
s_wood:         .asciz "Madeira "
s_stone:        .asciz "   Pedra "
s_berry:        .asciz "   Frutas "
s_hp:           .asciz "Vida"
s_food:         .asciz "Fome"
s_warm:         .asciz "Calor"
s_stamina:      .asciz "Stamina"
m_shark1:       .asciz "Agua muito funda! Um tubarao esta vindo... volte!"
m_eaten:        .asciz "Um tubarao comeu voce!"
m_drowned:      .asciz "Voce se afogou"
m_starved:      .asciz "Voce morreu de fome"
m_hailed:       .asciz "O granizo acabou com voce"
s_hailbl:       .asciz "Granizo: perdendo vida!"
m_froze:        .asciz "Voce morreu de frio"
t_9:            .asciz "agua: nadando nivel="
t_10:           .asciz " stamina="
t_11:           .asciz " | mar aberto: tubarao="
t_12:           .asciz " morto="
s_paren:        .asciz " ("
s_paren2:       .asciz ")"
s_far:          .asciz " - longe"
s_fire:         .asciz "Fogueira: "
s_firehint:     .asciz " s (botao direito: +lenha)"
s_hint:         .asciz "WASD: andar  Shift: correr  E: comer  F: fogo  Tab: fabricar  I/C: janelas"
s_dead1:        .asciz "FIM DE JOGO"
s_dead2:        .asciz "Voce sobreviveu "
s_dead3:        .asciz " noite(s)"
s_dead4:        .asciz "ENTER: novo mundo     ESC: menu"
s_nl:           .asciz "\n"
p_axe:          .asciz "+1 machado"
p_pick:         .asciz "+1 picareta"
p_torch:        .asciz "+1 tocha"
p_cooked:       .asciz "+1 fruta assada"
p_basket:       .asciz "+1 cesto"
p_eatc:         .asciz "Nham! +50"
p_pickup:       .asciz "Desmontado"
p_stored:       .asciz "Guardado"
p_taken:        .asciz "Pegou"
m_needfire:     .asciz "Precisa estar perto de uma fogueira acesa"
m_place:        .asciz "Clique no mapa para colocar (botao direito cancela)"
m_nopoint:      .asciz "Aponte para o chao"
m_toomanychests: .asciz "Baus demais"
m_chestok:      .asciz "Bau pronto! Botao direito nele para abrir"
m_shelterok:    .asciz "Abrigo pronto! Dentro dele nao passa frio"
m_placecancel:  .asciz "Cancelado"
m_nodrop:       .asciz "Construcoes nao se largam: clique nelas para colocar"
m_chestfull:    .asciz "Esvazie o bau antes de desmontar"
m_axebroke:     .asciz "O machado quebrou!"
m_pickbroke:    .asciz "A picareta quebrou!"
s_falta:        .asciz "Falta:"
s_plus1:        .asciz "+1 "
s_plusfire:     .asciz " + fogo"
s_btncraft:     .asciz "Fabricar [Tab]"
s_crafttitle:   .asciz "Fabricar"
s_chesttitle:   .asciz "Bau"
s_crafthint:    .asciz "Clique numa receita"
s_invhint2:     .asciz "Clique: guardar no bau"
s_chesthint:    .asciz "Clique: pegar"
s_place1:       .asciz "Clique: colocar "
s_place2:       .asciz " (dir.: cancela)"
s_torchlbl:     .asciz "Tocha acesa: "
s_torchmore:    .asciz " (+"
s_sec:          .asciz " s"
s_shelterlbl:   .asciz "Abrigado: sem frio"
p_bow:          .asciz "+1 arco"
p_arrow:        .asciz "+1 flecha"
p_meat:         .asciz "+1 carne"
p_cmeat:        .asciz "+1 carne assada"
p_hide:         .asciz "+1 couro"
p_coat:         .asciz "+1 roupa de couro"
p_lbag:         .asciz "+1 mochila de couro"
p_eatraw:       .asciz "Carne crua... +10"
p_eatm:         .asciz "Delicia! +60"
p_haxe:         .asciz "Machado na mao"
p_hpick:        .asciz "Picareta na mao"
p_hbow:         .asciz "Arco na mao"
p_handempty:    .asciz "Maos vazias"
p_torchon:      .asciz "Tocha na outra mao"
p_torchoff:     .asciz "Tocha guardada"
m_noaxe:        .asciz "Voce nao tem machado (fabrique: Tab)"
m_nopick:       .asciz "Voce nao tem picareta (fabrique: Tab)"
m_nobow:        .asciz "Voce nao tem arco (fabrique: Tab)"
m_notorch:      .asciz "Voce nao tem tocha (fabrique: Tab)"
s_plus:         .asciz "+"
m_notnight:     .asciz "Ainda e dia: so da para dormir depois das 18h"
m_morning:      .asciz "Bom dia! Voce dormiu a noite toda"
m_wetwake:      .asciz "Acordou: a agua subiu!"
m_weakwake:     .asciz "Acordou fraco: esta com fome ou frio"
m_wokeup:       .asciz "Acordou"
s_sleep1:       .asciz "Zzz..."
s_sleep2:       .asciz "Dormindo ate amanhecer (qualquer tecla acorda)"
m_toheavy:      .asciz "Pesado demais! Largue algo na mochila (I)"
m_dropwater:    .asciz "Nao da para largar na agua"
p_drop:         .asciz "Largou"
s_heavy:        .asciz "Pesado: anda devagar"
s_lvlup:        .asciz " subiu para o nivel "
s_excl:         .asciz "!"
s_btninv:       .asciz "Mochila [I]"
s_btnchar:      .asciz "Personagem [C]"
s_invtitle:     .asciz "Mochila"
s_chartitle:    .asciz "Personagem - skills"
s_peso:         .asciz "Peso "
s_slash:        .asciz " / "
s_kg:           .asciz " kg"
s_kgparen:      .asciz " kg)"
s_x:            .asciz " x"
s_invhint:      .asciz "Clique usa, dir. larga"
s_nv:           .asciz "Nv "
s_up:           .asciz "+"
s_down:         .asciz "-"
s_carga:        .asciz "Carga maxima: "
s_legend:       .asciz "+ subindo   - caindo"
t_13:           .asciz "skills: correu="
t_14:           .asciz " stamina="
t_15:           .asciz " peso="
t_16:           .asciz " kg pilha="
t_17:           .asciz " | nado/corrida/lenha/minerio/forca="
t_18:           .asciz "skills: corrida sem treino "
t_19:           .asciz " -> "
t_20:           .asciz " | recolheu pedras="
t_s1:           .asciz "dormir: deitou 22:00, dormindo="
t_s2:           .asciz " | acordou"
t_s3:           .asciz " | fome 100 -> "
t_s4:           .asciz " calor 100 -> "
t_s5:           .asciz " vida 100 -> "
t_c1:           .asciz "fabricar: machado="
t_c2:           .asciz " picareta="
t_c3:           .asciz " tochas="
t_c4:           .asciz " cesto="
t_c5:           .asciz " assadas="
t_c6:           .asciz " | carga max="
t_c7:           .asciz " kg | baus="
t_c8:           .asciz " (madeira guardada="
t_c9:           .asciz ") abrigos="
t_c10:          .asciz "fabricar: machado depois de 1 arvore, usos="
t_c11:          .asciz " | noite: tocha acesa="
t_c12:          .asciz " tochas na mochila="
t_c13:          .asciz "fabricar: noite no abrigo, calor 50 -> "
t_c14:          .asciz " (abrigado="
t_c15:          .asciz ") | frutas assadas: fome 40 -> "
t_w1:           .asciz "clima "
t_w2:           .asciz ": em 10 s calor 50 -> "
t_w3:           .asciz " vida 100 -> "
t_w4:           .asciz " | enchente="
t_w5:           .asciz " agua="
t_w6:           .asciz " luz="
t_hdead:        .asciz "caca: ja estava morto: "
t_h1:           .asciz "caca: cervo abatido="
t_h2:           .asciz " flechas usadas="
t_h3:           .asciz " | recolheu carne="
t_h4:           .asciz " couro="
t_h5:           .asciz "lobo de noite: vida 100 -> "
t_h6:           .asciz " (perto do fogo="
t_h7:           .asciz ") | machado: lobo abatido="
t_h8:           .asciz " em golpes="
t_h9:           .asciz "animais que apareceram em 15 s: "
t_21:           .asciz "fome: vida com fome 80 = 50 -> "
t_22:           .asciz " | depois de encher -> "
t_23:           .asciz " fome="
t_24:           .asciz " | stamina max (corrida 50, natacao 50) = "
s_full:         .asciz "cheia"
p_full:         .asciz "Cheio! A vida vai subir"
t_1:            .asciz "sobrevivencia: madeira="
t_2:            .asciz " pedra="
t_3:            .asciz " frutas="
t_4:            .asciz " fogueiras="
t_5:            .asciz " vida="
t_6:            .asciz " fome="
t_7:            .asciz " calor="
t_8:            .asciz " luz="

// ---- memoria ------------------------------------------------------------
GBSS fires,    512
GBSS lightbuf, 921600
GBSS lbuf,     128
GBSS msgbuf,   64
GBSS popbuf,   64
GBSS chests,   8192                     // 64 baus x 32 contadores
GBSS chestused, 64
GBSS shelters, 128                      // 32 abrigos (objeto; -1 = vaga)
GBSS vis,      262144                   // visao agora (0..255 por celula)
GBSS seen,     262144                   // memoria: o que ja foi visto
GBSS treecnt,  262144                   // arvores por celula (tapam a visao)
GBSS memtype,  200000                   // como cada objeto foi visto por ultimo
