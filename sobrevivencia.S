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
popup:
    str     x0, [x28, #G_POPMSG]
    mov     w9, #45
    str     w9, [x28, #G_POPT]
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
    str     wzr, [x28, #G_WOOD]
    str     wzr, [x28, #G_STONE]
    str     wzr, [x28, #G_BERRY]
    mov     w9, #900                    // 08:00
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
    bl      calc_weight
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
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    LA      x19, objs
    add     x19, x19, x0, lsl #3
    ldrb    w20, [x19, #6]              // tipo
    // qual item: pilha largada, pedra, arbusto ou arvore
    sub     w9, w20, #O_LOGS
    cmp     w20, #O_LOGS
    b.hs    1f
    mov     w9, #1
    cmp     w20, #O_ROCK
    b.eq    1f
    mov     w9, #2
    cmp     w20, #O_BUSH
    b.eq    1f
    mov     w9, #0
1:  add     x10, x28, #G_WOOD
    ldr     w11, [x10, x9, lsl #2]
    add     w11, w11, #1
    str     w11, [x10, x9, lsl #2]
    LA      x10, popitem
    ldr     x0, [x10, x9, lsl #3]
    bl      popup
    // treino: arvores (lenhador) e pedras (mineracao)
    cmp     w20, #O_PINE
    b.hi    2f
    mov     w0, #SK_CHOP
    FC      s0, F_XPCHOP
    bl      skill_train
    b       3f
2:  cmp     w20, #O_ROCK
    b.ne    3f
    mov     w0, #SK_MINE
    FC      s0, F_XPMINE
    bl      skill_train
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
6:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
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
    bl      calc_weight
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, su_cam
    ldr     w9, [x28, #G_PAUSE]
    cbnz    w9, su_cam
    bl      skills_tick                 // skills sem treino caem devagar

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
    mov     w10, #(T_DUSK - 400)        // aviso: vai escurecer
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
4:  ldr     x19, [x28, #G_KEYS]
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
45: fmov    s8, wzr                     // du
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
94: ldr     w9, [x28, #G_WEIGHT]        // sobrecarregado: bem mais lento
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
    mov     w19, w0                     // elevacao (negativa = agua)
    cmp     w0, #0
    csel    w0, wzr, w0, lt
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
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 11f
    bl      mouse_ui                    // mouse em cima de botao ou janela?
    bl      ui_hit
    cbnz    w0, 11f
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
    str     w10, [x28, #G_MINENEED]
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
    ldr     s0, [x28, #G_FOOD]
    FC      s1, F_FOODRATE
    fsub    s0, s0, s1
    fmov    s1, wzr
    fmax    s0, s0, s1
    str     s0, [x28, #G_FOOD]

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
    fsub    s0, s0, s1
    b       212f
2101: cbz   w9, 211f
    FC      s1, F_RECOVSH               // no raso: recupera devagar
    fadd    s0, s0, s1
    b       212f
211: FC     s1, F_RECOV                 // em terra andando
    ldr     w10, [x28, #G_PMOVING]
    cbnz    w10, 2111f
    FC      s1, F_RECOVREST             // parado: mais rapido
2111: fadd  s0, s0, s1
212: fmov   s1, wzr
    fmax    s0, s0, s1
    FC      s1, F_HUNDRED
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

    // ---- calor ----
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
    ldr     s0, [x28, #G_WARM]
    cbz     w21, 15f
    FC      s1, F_HEAT
    fadd    s0, s0, s1
    b       17f
15: ldr     w9, [x28, #G_AMBR]
    cmp     w9, #170
    b.ge    16f
    FC      s1, F_COLD                  // escuro: esfria
    fsub    s0, s0, s1
    b       17f
16: FC      s1, F_DAYWARM
    fadd    s0, s0, s1
17: ldr     w9, [x28, #G_WATER]         // nadando: a agua esfria
    cmp     w9, #2
    b.lt    171f
    FC      s1, F_WETCOLD
    fsub    s0, s0, s1
171: fmov   s1, wzr
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
191: FC     s2, F_FORTY
    ldr     s0, [x28, #G_FOOD]
    fcmp    s0, s2
    b.le    20f
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
203: str    x0, [x28, #G_DEATHMSG]
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

    // ---- arbustos voltam a dar frutas (a cada 10 s, chance de 1/6) ----
    ldr     w9, [x28, #G_TIME]
    mov     w10, #600
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
    udiv    w10, w0, w9
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
    bl      update_vision
    ldp     d10, d11, [sp, #64]
    ldp     d8, d9, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// =====================================================================
//  Teclas e mouse
// =====================================================================

// surv_key(w0 = scancode): E come, F faz fogueira
    .globl surv_key
surv_key:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, 9f
    cmp     w0, #8                      // E
    b.ne    1f
    bl      eat
    b       9f
1:  cmp     w0, #9                      // F
    b.ne    2f
    bl      build_fire
    b       9f
2:  cmp     w0, #12                     // I: mochila
    b.ne    3f
    ldr     w9, [x28, #G_INVOPEN]
    eor     w9, w9, #1
    str     w9, [x28, #G_INVOPEN]
    b       9f
3:  cmp     w0, #6                      // C: personagem
    b.ne    9f
    ldr     w9, [x28, #G_CHAROPEN]
    eor     w9, w9, #1
    str     w9, [x28, #G_CHAROPEN]
9:  ldp     x29, x30, [sp], #16
    ret

eat:
    ldr     w9, [x28, #G_BERRY]
    cbnz    w9, 1f
    LA      x0, m_noberry
    b       set_msg
1:  sub     w9, w9, #1
    str     w9, [x28, #G_BERRY]
    ldr     s0, [x28, #G_FOOD]
    FC      s1, F_EAT
    fadd    s0, s0, s1
    FC      s1, F_HUNDRED
    fmin    s0, s0, s1
    str     s0, [x28, #G_FOOD]
    LA      x0, p_eat
    b       popup

build_fire:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     d8, d9, [sp, #16]
    str     x19, [sp, #32]
    ldr     w9, [x28, #G_WOOD]
    cmp     w9, #5
    b.lt    1f
    ldr     w9, [x28, #G_STONE]
    cmp     w9, #3
    b.ge    2f
1:  LA      x0, m_needres
    bl      set_msg
    b       bf_ret
2:  ldr     w9, [x28, #G_NFIRE]
    cmp     w9, #MAXFIRE
    b.lo    3f
    LA      x0, m_toomanyfires
    bl      set_msg
    b       bf_ret
    // onde: no ponto do mouse, se estiver perto; senao do lado do personagem
3:  ldr     s8, [x28, #G_PU]
    ldr     s9, [x28, #G_PV]
    fmov    s0, #0.75
    fadd    s8, s8, s0
    fadd    s9, s9, s0
    ldr     w9, [x28, #G_HOVOK]
    cbz     w9, 4f
    ldr     w9, [x28, #G_HOVU]
    scvtf   s0, w9
    ldr     w9, [x28, #G_HOVV]
    scvtf   s1, w9
    FC      s2, F_INV64
    fmul    s0, s0, s2
    fmul    s1, s1, s2
    ldr     s2, [x28, #G_PU]
    ldr     s3, [x28, #G_PV]
    fsub    s2, s0, s2
    fsub    s3, s1, s3
    fmul    s2, s2, s2
    fmadd   s2, s3, s3, s2
    FC      s3, F_REACH2
    fcmp    s2, s3
    b.gt    4f
    fmov    s8, s0
    fmov    s9, s1
4:  fmov    s0, s8
    fmov    s1, s9
    bl      elev_at
    tbz     w0, #31, 5f
    LA      x0, m_water
    bl      set_msg
    b       bf_ret
5:  mov     w19, w0
    ldr     w9, [x28, #G_NFIRE]
    LA      x10, fires
    add     x10, x10, x9, lsl #4
    str     s8, [x10]
    str     s9, [x10, #4]
    str     w19, [x10, #8]
    mov     w11, #3600                  // 60 s de fogo
    str     w11, [x10, #12]
    add     w9, w9, #1
    str     w9, [x28, #G_NFIRE]
    ldr     w9, [x28, #G_WOOD]
    sub     w9, w9, #5
    str     w9, [x28, #G_WOOD]
    ldr     w9, [x28, #G_STONE]
    sub     w9, w9, #3
    str     w9, [x28, #G_STONE]
    LA      x0, m_fire
    bl      set_msg
bf_ret:
    ldr     x19, [sp, #32]
    ldp     d8, d9, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// surv_mouse(w0 = botao, w1 = 1 apertou / 0 soltou)
    .globl surv_mouse
surv_mouse:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    ldr     w9, [x28, #G_DEAD]
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
    cmp     w0, #1
    b.ne    2f
    ldr     w9, [x28, #G_INVOPEN]
    eor     w9, w9, #1
    str     w9, [x28, #G_INVOPEN]
    b       sm_ret
2:  cmp     w0, #2
    b.ne    3f
    ldr     w9, [x28, #G_CHAROPEN]
    eor     w9, w9, #1
    str     w9, [x28, #G_CHAROPEN]
    b       sm_ret
3:  cmp     w0, #3                      // mochila: direito larga o item
    b.ne    4f
    cmp     w19, #3
    b.ne    sm_ret
    tbnz    w1, #31, sm_ret
    mov     w0, w1
    bl      inv_slot_item
    tbnz    w0, #31, sm_ret
    mov     w1, #1                      // 1 (com Shift: a pilha toda)
    ldr     x9, [x28, #G_KEYS]
    ldrb    w10, [x9, #225]
    ldrb    w11, [x9, #229]
    orr     w10, w10, w11
    cbz     w10, 31f
    mov     w1, #255
31: bl      drop_item
    b       sm_ret
4:  cbnz    w0, sm_ret                  // janela do personagem: nada
    cmp     w19, #1
    b.ne    5f
    mov     w9, #1                      // esquerdo no mundo: coletar
    str     w9, [x28, #G_LMB]
    b       sm_ret
5:  cmp     w19, #3
    b.ne    sm_ret
    ldr     w19, [x28, #G_HOVFIRE]      // direito numa fogueira: lenha
    tbnz    w19, #31, sm_ret
    mov     w0, w19
    bl      fire_dist2
    FC      s1, F_REACH2
    fcmp    s0, s1
    b.le    2f
    LA      x0, m_far
    bl      set_msg
    b       sm_ret
2:  ldr     w9, [x28, #G_WOOD]
    cbnz    w9, 3f
    LA      x0, m_nowood
    bl      set_msg
    b       sm_ret
3:  sub     w9, w9, #1
    str     w9, [x28, #G_WOOD]
    LA      x10, fires
    add     x10, x10, x19, lsl #4
    ldr     w11, [x10, #12]
    add     w11, w11, #1800             // +30 s
    MOVI32  w12, 10800
    cmp     w11, w12
    csel    w11, w12, w11, gt
    str     w11, [x10, #12]
    LA      x0, p_log
    bl      popup
sm_ret:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
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
    // personagem
2:  ldr     s0, [x28, #G_PU]
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
4:  ldr     x21, [sp, #32]
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
    // lanterna fraca do personagem
4:  ldr     s0, [x28, #G_PU]
    ldr     s1, [x28, #G_PV]
    ldr     w0, [x28, #G_PE]
    bl      proj
    mov     w2, #10
    mul     w2, w2, w21
    lsr     w2, w2, #8
    mov     w9, #4
    mul     w9, w9, w21
    asr     w9, w9, #8
    sub     w1, w1, w9
    mov     w3, #110
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
    ldr     s0, [x28, #G_PU]
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
    mov     w0, #62
    LA      x1, s_warm
    ldr     s0, [x28, #G_WARM]
    mov     w2, #80
    mov     w3, #160
    mov     w4, #240
    bl      bar
    mov     w0, #75
    LA      x1, s_stamina
    ldr     s0, [x28, #G_STAMINA]
    mov     w2, #120
    mov     w3, #225
    mov     w4, #210
    bl      bar
    // ---- na agua? ----
    ldr     w9, [x28, #G_WATER]
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
    mov     w1, #94
    mov     x2, x19
    bl      text
    // ---- sobrecarregado? ----
ui_heavy:
    ldr     w9, [x28, #G_WEIGHT]
    ldr     w10, [x28, #G_CAP]
    cmp     w9, w10
    b.le    ui_tip
    mov     w0, #255
    mov     w1, #150
    mov     w2, #70
    mov     w3, #255
    bl      setcolor
    ldr     w9, [x28, #G_WATER]
    mov     w1, #94
    cbz     w9, 1f
    mov     w1, #104
1:  mov     w0, #8
    LA      x2, s_heavy
    bl      text
ui_tip:
    bl      ui_windows                  // botoes, mochila e personagem

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
    cbz     w9, ui_dead
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
    mov     w1, #314
    add     w2, w19, #12
    mov     w3, #16
    bl      fillrect
    mov     w0, #255
    mov     w1, #230
    mov     w2, #140
    mov     w3, #255
    bl      setcolor
    mov     w0, #640
    mov     w1, #318
    ldr     x2, [x28, #G_MSG]
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

// calc_weight: peso carregado e limite (que cresce com a forca)   folha
calc_weight:
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
    str     w9, [x28, #G_CAP]
    ret

// skills_tick: cada skill sem treino ha mais de 30 s cai devagar   folha
skills_tick:
    mov     x9, #0
1:  add     x10, x28, #G_SKIDLE
    ldrh    w11, [x10, x9, lsl #1]
    mov     w12, #65535
    cmp     w11, w12
    cinc    w11, w11, lo
    strh    w11, [x10, x9, lsl #1]
    cmp     w11, #SKREST
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
// personagem, 3 janela da mochila (w1 = quadrado ou -1), 4 janela do
// personagem.   folha: usa x0-x3, x9-x13
ui_hit:
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
1:  ldr     w9, [x28, #G_INVOPEN]
    cbz     w9, 3f
    sub     w9, w2, #INV_X
    cmp     w9, #INV_W
    b.hs    3f
    sub     w10, w3, #INV_Y
    cmp     w10, #INV_H
    b.hs    3f
    mov     w0, #3
    sub     w9, w2, #SLOT_X             // qual quadrado (4 x 3)?
    sub     w10, w3, #SLOT_Y
    tbnz    w9, #31, 9f
    tbnz    w10, #31, 9f
    mov     w11, #SLOTSTEP
    udiv    w12, w9, w11
    msub    w9, w12, w11, w9
    cmp     w9, #SLOT
    b.hs    9f
    cmp     w12, #4
    b.hs    9f
    udiv    w13, w10, w11
    msub    w10, w13, w11, w10
    cmp     w10, #SLOT
    b.hs    9f
    cmp     w13, #3
    b.hs    9f
    add     w1, w12, w13, lsl #2
    b       9f
3:  mov     w0, #0
    ldr     w9, [x28, #G_CHAROPEN]
    cbz     w9, 9f
    sub     w9, w2, #CHR_X
    cmp     w9, #CHR_W
    b.hs    9f
    sub     w10, w3, #CHR_Y
    cmp     w10, #CHR_H
    b.hs    9f
    mov     w0, #4
9:  ret

// inv_slot_item(w0 = quadrado) -> w0 = item (-1 = vazio)   folha
// os itens que voce tem ocupam os quadrados em ordem
inv_slot_item:
    add     x9, x28, #G_WOOD
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
    tbz     w0, #31, 1f
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
    bl      calc_weight
    LA      x0, p_drop
    bl      popup
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
1:  ldr     w9, [x28, #G_INVOPEN]
    cbz     w9, 2f
    bl      draw_inv
2:  ldp     x29, x30, [sp], #16
    ret

// draw_inv: mochila em grade (4 x 3), com o peso em cima
draw_inv:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
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
    // quadrados
6:  bl      mouse_ui
    bl      ui_hit
    mov     w23, #-1                    // quadrado sob o mouse
    cmp     w0, #3
    b.ne    7f
    mov     w23, w1
7:  mov     w20, #0
70: cmp     w20, #12
    b.ge    8f
    and     w9, w20, #3
    mov     w10, #SLOTSTEP
    mov     w11, #SLOT_X
    madd    w21, w9, w10, w11           // x do quadrado
    lsr     w9, w20, #2
    mov     w11, #SLOT_Y
    madd    w22, w9, w10, w11           // y
    cmp     w20, w23
    b.ne    71f
    RGBA    70, 72, 92, 240
    b       72f
71: RGBA    28, 30, 38, 235
72: mov     w0, w21
    mov     w1, w22
    mov     w2, #SLOT
    mov     w3, #SLOT
    bl      fillrect
    RGBA    85, 90, 108, 255
    mov     w0, w21
    mov     w1, w22
    mov     w2, #SLOT
    mov     w3, #SLOT
    bl      ui_frame
    mov     w0, w20                     // tem item aqui?
    bl      inv_slot_item
    tbnz    w0, #31, 79f
    mov     w24, w0
    LA      x25, sprites                // icone (sprite 12, 13 ou 14) centrado
    add     w9, w24, #O_LOGS
    add     x25, x25, x9, lsl #7
    ldrb    w9, [x25]
    ldrb    w10, [x25, #1]
    mov     w11, #3
    mul     w9, w9, w11
    mul     w10, w10, w11
    mov     w11, #SLOT
    sub     w9, w11, w9
    asr     w9, w9, #1
    add     w1, w21, w9
    sub     w10, w11, w10
    asr     w10, w10, #1
    add     w2, w22, w10
    sub     w2, w2, #4
    mov     x0, x25
    mov     w3, #3
    bl      ui_icon
    LA      x0, lbuf                    // quantidade no canto
    add     x9, x28, #G_WOOD
    ldr     w1, [x9, x24, lsl #2]
    bl      numcat
    LA      x0, lbuf
    bl      mystrlen
    lsl     w25, w0, #3
    RGBA    0, 0, 0, 255
    add     w0, w21, #(SLOT - 1)
    sub     w0, w0, w25
    add     w1, w22, #(SLOT - 9)
    LA      x2, lbuf
    bl      text
    RGBA    255, 255, 255, 255
    add     w0, w21, #(SLOT - 2)
    sub     w0, w0, w25
    add     w1, w22, #(SLOT - 10)
    LA      x2, lbuf
    bl      text
79: add     w20, w20, #1
    b       70b
8:  RGBA    160, 160, 170, 255
    mov     w0, #(INV_X + 8)
    mov     w1, #(INV_Y + INV_H - 14)
    LA      x2, s_invhint
    bl      text
    // dica do item sob o mouse: "Madeira x12 (18.0 kg)"
    tbnz    w23, #31, 9f
    mov     w0, w23
    bl      inv_slot_item
    tbnz    w0, #31, 9f
    mov     w24, w0
    LA      x0, lbuf
    LA      x1, itemnames
    add     x1, x1, x24, lsl #4
    bl      strcat_cur
    LA      x1, s_x
    bl      strcat_cur
    add     x9, x28, #G_WOOD
    ldr     w1, [x9, x24, lsl #2]
    mov     w25, w1
    bl      numcat
    LA      x1, s_paren
    bl      strcat_cur
    LA      x9, itemweight
    ldrh    w9, [x9, x24, lsl #1]
    mul     w1, w25, w9
    bl      kgcat
    LA      x1, s_kgparen
    bl      strcat_cur
    LA      x0, lbuf
    bl      mystrlen
    lsl     w9, w0, #3
    bl      mouse_ui
    add     w19, w0, #10
    add     w20, w1, #6
    mov     w10, #636                   // nao deixa sair da tela
    sub     w10, w10, w9
    cmp     w19, w10
    csel    w19, w10, w19, gt
    mov     w22, #1
    bl      tooltip_box
9:  ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
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
2:  cmp     w21, #SKREST
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

// tooltip_box: desenha lbuf em (w19, w20) com fundo; w22 = 1 ao alcance
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
    mov     w0, #255
    mov     w1, #255
    mov     w2, #255
    mov     w3, #255
    cbnz    w22, 1f
    mov     w0, #170
    mov     w1, #170
    mov     w2, #170
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
    mov     w0, #9                      // F
    bl      surv_key
    mov     w0, #8                      // E
    bl      surv_key
    // vai para a noite e deixa o tempo passar
    mov     w9, #7200
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
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     wzr, [x28, #G_HOVOK]
    str     wzr, [x28, #G_LMB]
    mov     w9, #1500                   // de dia
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
    // corrida sem treino ha 30 s: 10 s parado e ela cai um pouco
    mov     w9, #SKREST
    strh    w9, [x28, #(G_SKIDLE + 2 * SK_RUN)]
    ldr     s0, [x28, #G_SKRUN]
    FC      s1, F_HUNDRED
    fmul    s0, s0, s1
    fcvtzs  w20, s0                     // antes (x100)
    mov     w19, #0
4:  bl      surv_update
    add     w19, w19, #1
    cmp     w19, #600
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
sk_ret:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// sk_write(x0 = fim do texto em txt): imprime txt
sk_write:
    LA      x9, txt
    sub     x2, x0, x9
    mov     x1, x9
    mov     w0, #1
    b       F(write)

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
    mov     w9, #1500                   // de dia, para a foto
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
    .float 0.0046           // F_FOODRATE (100 -> 0 em ~6 min)
    .float 0.03             // F_COLD
    .float 0.2              // F_HEAT
    .float 0.05             // F_DAYWARM
    .float 0.025            // F_STARVE
    .float 0.04             // F_FREEZE
    .float 0.012            // F_REGEN
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
    .float 0.04             // F_WETCOLD (a agua esfria)
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
    .float 0.012            // F_XPSWIM (por quadro nadando)
    .float 0.01             // F_XPRUN (por quadro correndo)
    .float 1.2              // F_XPCHOP (por madeira)
    .float 1.5              // F_XPMINE (por pedra)
    .float 0.006            // F_XPSTR (por quadro andando carregado)
    .float 0.00025          // F_SKDECAY (~1 ponto por minuto sem treino)
    .float 1.05             // F_P105
    .float 0.01             // F_INV100
    .float 0.1              // F_TENTH

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

// quadros para coletar 1 unidade: arvore, pinheiro, pedra, arbusto,
// ... e as pilhas largadas no chao (tipos 12, 13, 14)
minetime:
    .byte 45, 45, 70, 25, 0, 0, 0, 0
    .byte 0, 0, 0, 0, 6, 6, 6, 0

// peso de cada item (decimos de kg): madeira, pedra, fruta
    .p2align 1
itemweight:
    .hword 15, 20, 1

// texto que sobe ao coletar cada item
    .p2align 3
popitem:
    .quad p_wood, p_stone, p_berry

// nomes (16 bytes cada)
    .p2align 4
itemnames:
    .asciz "Madeira"
    .p2align 4
    .asciz "Pedra"
    .p2align 4
    .asciz "Frutas"
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
p_log:          .asciz "+30 s de fogo"
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
s_hint:         .asciz "WASD: andar  Shift: correr  clique: coletar  E: comer  F: fogo  I/C: janelas"
s_dead1:        .asciz "FIM DE JOGO"
s_dead2:        .asciz "Voce sobreviveu "
s_dead3:        .asciz " noite(s)"
s_dead4:        .asciz "ENTER: novo mundo     ESC: menu"
s_nl:           .asciz "\n"
m_toheavy:      .asciz "Pesado demais! Largue algo na mochila (I)"
m_dropwater:    .asciz "Nao da para largar na agua"
p_drop:         .asciz "Largou"
s_heavy:        .asciz "Sobrecarregado: anda devagar"
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
s_invhint:      .asciz "Botao direito: largar"
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
GBSS vis,      262144                   // visao agora (0..255 por celula)
GBSS seen,     262144                   // memoria: o que ja foi visto
GBSS treecnt,  262144                   // arvores por celula (tapam a visao)
GBSS memtype,  200000                   // como cada objeto foi visto por ultimo
