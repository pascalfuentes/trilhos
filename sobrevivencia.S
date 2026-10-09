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
// =====================================================================

#include "comum.h"

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
    LA      x9, seen                    // nada foi descoberto ainda
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
    cmp     w8, #O_BUSHE
    b.hi    2f
    ldrh    w9, [x6]
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
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x9, objs
    add     x9, x9, x0, lsl #3
    ldrb    w10, [x9, #6]               // tipo
    cmp     w10, #O_ROCK
    b.eq    2f
    cmp     w10, #O_BUSH
    b.eq    3f
    ldr     w11, [x28, #G_WOOD]         // arvore ou pinheiro
    add     w11, w11, #1
    str     w11, [x28, #G_WOOD]
    LA      x0, p_wood
    b       4f
2:  ldr     w11, [x28, #G_STONE]
    add     w11, w11, #1
    str     w11, [x28, #G_STONE]
    LA      x0, p_stone
    b       4f
3:  ldr     w11, [x28, #G_BERRY]
    add     w11, w11, #1
    str     w11, [x28, #G_BERRY]
    LA      x0, p_berry
4:  ldrb    w11, [x9, #7]               // quanto ainda tem
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
6:  bl      popup
    ldp     x29, x30, [sp], #16
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
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, su_cam
    ldr     w9, [x28, #G_PAUSE]
    cbnz    w9, su_cam

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
4:  ldr     x19, [x28, #G_KEYS]
    fmov    s8, wzr                     // du
    fmov    s9, wzr                     // dv
    fmov    s0, #1.0
    ldrb    w9, [x19, #26]              // W: sobe na tela = -u -v
    ldrb    w10, [x19, #82]
    orr     w9, w9, w10
    cbz     w9, 5f
    fsub    s8, s8, s0
    fsub    s9, s9, s0
5:  ldrb    w9, [x19, #22]              // S: +u +v
    ldrb    w10, [x19, #81]
    orr     w9, w9, w10
    cbz     w9, 6f
    fadd    s8, s8, s0
    fadd    s9, s9, s0
6:  ldrb    w9, [x19, #4]               // A: esquerda = -u +v
    ldrb    w10, [x19, #80]
    orr     w9, w9, w10
    cbz     w9, 7f
    fsub    s8, s8, s0
    fadd    s9, s9, s0
7:  ldrb    w9, [x19, #7]               // D: direita = +u -v
    ldrb    w10, [x19, #79]
    orr     w9, w9, w10
    cbz     w9, 8f
    fadd    s8, s8, s0
    fsub    s9, s9, s0
8:  fmul    s10, s8, s8
    fmadd   s10, s9, s9, s10
    fcmp    s10, #0.0
    b.ne    9f
    str     wzr, [x28, #G_PMOVING]
    b       su_after_move
9:  fsqrt   s10, s10
    FC      s11, F_SPEED
    fdiv    s11, s11, s10
    ldr     w9, [x28, #G_WATER]         // na agua anda mais devagar
    LA      x10, waterspeed
    ldr     s0, [x10, x9, lsl #2]
    cmp     w9, #2
    b.lt    91f
    ldr     s1, [x28, #G_STAMINA]
    fcmp    s1, #0.0
    b.gt    91f
    FC      s0, F_TIRED                 // sem folego: quase parado
91: fmul    s11, s11, s0
    fmul    s8, s8, s11
    fmul    s9, s9, s11
    mov     w9, #1
    str     w9, [x28, #G_PMOVING]
    ldr     w9, [x28, #G_PFRAME]
    add     w9, w9, #1
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
    ldr     w9, [x28, #G_MINEOBJ]
    cmp     w9, w19
    b.eq    12f
    str     w19, [x28, #G_MINEOBJ]
    str     wzr, [x28, #G_MINEPROG]
12: LA      x9, minetime
    ldrb    w10, [x9, x20]
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

    // ---- agua: folego e tubarao ----
    ldr     w9, [x28, #G_WATER]
    ldr     s0, [x28, #G_STAMINA]
    cmp     w9, #2
    b.lt    210f
    FC      s1, F_SWIMCOST              // nadando: cansa
    fsub    s0, s0, s1
    b       212f
210: cbz    w9, 211f
    FC      s1, F_RECOVSH               // no raso: recupera devagar
    fadd    s0, s0, s1
    b       212f
211: FC     s1, F_RECOV                 // em terra: recupera rapido
    fadd    s0, s0, s1
212: fmov   s1, wzr
    fmax    s0, s0, s1
    FC      s1, F_HUNDRED
    fmin    s0, s0, s1
    str     s0, [x28, #G_STAMINA]
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
    b.ne    9f
    bl      build_fire
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
    str     x19, [sp, #16]
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, sm_ret
    cmp     w0, #1
    b.ne    1f
    str     w1, [x28, #G_LMB]           // esquerdo: coletar
    b       sm_ret
1:  cmp     w0, #3
    b.ne    sm_ret
    cbz     w1, sm_ret
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
    ldr     x19, [sp, #16]
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
    mov     w0, #60
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
    mov     w0, #60
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
    cbz     w9, ui_tip
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
ui_tip:

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
    cmp     w9, #O_BUSHE
    b.hs    2f                          // acabou (sem frutas ou removido)
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
    .float 0.5              // F_RECOV (folego volta em terra)
    .float 0.2              // F_RECOVSH (no raso)
    .float 0.25             // F_DROWN (vida perdida afogando)
    .float 0.04             // F_WETCOLD (a agua esfria)
    .float 3.0              // F_SHARKR (raio inicial da barbatana)

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

// quadros para coletar 1 unidade: arvore, pinheiro, pedra, arbusto
minetime:
    .byte 45, 45, 70, 25, 0, 0, 0, 0

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
s_stamina:      .asciz "Folego"
m_shark1:       .asciz "Agua muito funda! Um tubarao esta vindo... volte!"
m_eaten:        .asciz "Um tubarao comeu voce!"
m_drowned:      .asciz "Voce se afogou"
m_starved:      .asciz "Voce morreu de fome"
m_froze:        .asciz "Voce morreu de frio"
t_9:            .asciz "agua: nadando nivel="
t_10:           .asciz " folego="
t_11:           .asciz " | mar aberto: tubarao="
t_12:           .asciz " morto="
s_paren:        .asciz " ("
s_paren2:       .asciz ")"
s_far:          .asciz " - longe"
s_fire:         .asciz "Fogueira: "
s_firehint:     .asciz " s (botao direito: +lenha)"
s_hint:         .asciz "WASD: andar  clique: coletar  E: comer  F: fogueira  espaco: pausa"
s_dead1:        .asciz "FIM DE JOGO"
s_dead2:        .asciz "Voce sobreviveu "
s_dead3:        .asciz " noite(s)"
s_dead4:        .asciz "ENTER: novo mundo     ESC: menu"
s_nl:           .asciz "\n"
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
GBSS vis,      262144                   // visao agora (0..255 por celula)
GBSS seen,     262144                   // memoria: o que ja foi visto
GBSS treecnt,  262144                   // arvores por celula (tapam a visao)
GBSS memtype,  200000                   // como cada objeto foi visto por ultimo
