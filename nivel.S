// =====================================================================
//  nivel.S - nivel e experiencia (RPG, fase 1)
//
//  - Comeca no nivel 1. Para passar do nivel N para o N+1 sao precisos
//    round(1,5^(N-1)) pontos de XP: 1, 2, 2, 3, 5, 8, 11, 17, 26, 38...
//    Sem nivel maximo; XP e a conta guardados em 64 bits.
//  - Por enquanto o XP vem de abater bichos (animais.S): coelho, cervo,
//    cabra e caranguejo 1, lobo 2, urso 3. Na fase 2 o XP passa a ser o
//    nivel do inimigo.
//  - Ao subir: aviso "Voce subiu para o nivel N!" e um brilho dourado em
//    volta do numero do nivel por 3 s (G_LVLT).
//  - Atributos: Forca, Destreza, Vitalidade e Energia, comecando em 10.
//    Cada nivel da 5 pontos para distribuir no + da janela C (do lado da
//    janela do personagem). Forca: +1 kg de carga por ponto acima de 10
//    (calc_stats). Vitalidade: vida maxima = 50 + 5 por ponto (100 no
//    comeco); a vida fica guardada em % (G_HP), e a mordida dos bichos
//    tira pontos de vida de verdade (hp_scale). Energia: mana maxima =
//    5 por ponto (50 no comeco), enche sozinha em 30 s. Destreza: fase 3.
// =====================================================================

#include "comum.h"
#include "pixel.h"

.macro RGBA r, g, b, a
    mov     w0, #\r
    mov     w1, #\g
    mov     w2, #\b
    mov     w3, #\a
    bl      setcolor
.endm

    .text
    .p2align 2

// xp_need(w0 = nivel) -> x0 = XP para passar desse nivel ao proximo
//   round(1,5^(nivel-1))   folha
    .globl xp_need
xp_need:
    fmov    d0, #1.0
    fmov    d1, #1.5
    subs    w9, w0, #1
    b.le    2f
1:  fmul    d0, d0, d1
    subs    w9, w9, #1
    b.ne    1b
2:  frinta  d0, d0
    fcvtzu  x0, d0
    ret

// xp_reset: nivel 1, sem XP, atributos em 10
    .globl xp_reset
xp_reset:
    mov     w9, #10
    str     w9, [x28, #G_STR]
    str     w9, [x28, #G_DEX]
    str     w9, [x28, #G_VIT]
    str     w9, [x28, #G_ENE]
    str     wzr, [x28, #G_APTS]
    FC      s0, F_HUNDRED               // mana cheia
    str     s0, [x28, #G_MP]
    mov     w9, #1
    str     w9, [x28, #G_LEVEL]
    str     xzr, [x28, #G_XP]
    mov     x9, #1
    str     x9, [x28, #G_XPNEED]
    str     wzr, [x28, #G_LVLT]
    ret

// xp_fix: jogo salvo antes da fase 1 (nivel 0): comeca no nivel 1
    .globl xp_fix
xp_fix:
    ldr     w9, [x28, #G_LEVEL]
    cbz     w9, xp_reset
    ldr     w9, [x28, #G_STR]           // salvo antes dos atributos
    cbnz    w9, 1f
    mov     w9, #10
    str     w9, [x28, #G_STR]
    str     w9, [x28, #G_DEX]
    str     w9, [x28, #G_VIT]
    str     w9, [x28, #G_ENE]
    ldr     w9, [x28, #G_LEVEL]         // 5 pontos por nivel que ja tinha
    sub     w9, w9, #1
    add     w9, w9, w9, lsl #2
    str     w9, [x28, #G_APTS]
1:  ret

// xp_gain(w0 = XP): soma, sobe quantos niveis der e avisa
    .globl xp_gain
xp_gain:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, w0
    cbz     w19, 9f
    ldr     x9, [x28, #G_XP]
    add     x9, x9, w19, uxtw
    str     x9, [x28, #G_XP]
    mov     w20, #0                     // subiu?
1:  ldr     x9, [x28, #G_XP]
    ldr     x10, [x28, #G_XPNEED]
    cmp     x9, x10
    b.lo    2f
    sub     x9, x9, x10
    str     x9, [x28, #G_XP]
    ldr     w9, [x28, #G_APTS]      // 5 pontos de atributo por nivel
    add     w9, w9, #5
    str     w9, [x28, #G_APTS]
    ldr     w0, [x28, #G_LEVEL]
    add     w0, w0, #1
    str     w0, [x28, #G_LEVEL]
    bl      xp_need
    str     x0, [x28, #G_XPNEED]
    mov     w20, #1
    b       1b
2:  LA      x0, xpbuf                   // "+2 XP"
    mov     w9, #'+'
    strb    w9, [x0], #1
    mov     w1, w19
    bl      numcat
    LA      x1, s_xp
    bl      strcat_cur
    LA      x0, xpbuf
    bl      popup
    cbz     w20, 9f
    mov     w9, #180                    // 3 s de brilho no nivel
    str     w9, [x28, #G_LVLT]
    LA      x0, lvlbuf                  // "Nivel 3! +5 pontos de atributo (C)"
    LA      x1, s_lvlup
    bl      strcat_cur
    ldr     w1, [x28, #G_LEVEL]
    bl      numcat
    LA      x1, s_excl
    bl      strcat_cur
    LA      x0, lvlbuf
    bl      set_msg
    bl      calc_stats
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// xp_tick: o brilho do nivel apaga   folha
    .globl xp_tick
xp_tick:
    ldr     s0, [x28, #G_MP]            // mana: de vazia a cheia em 30 s
    ldr     s1, mp_step
    fadd    s0, s0, s1
    FC      s1, F_HUNDRED
    fmin    s0, s0, s1
    str     s0, [x28, #G_MP]
    ldr     w9, [x28, #G_LVLT]
    cbz     w9, 1f
    sub     w9, w9, #1
    str     w9, [x28, #G_LVLT]
1:  ret

mp_step: .float 0.0555556                // 100 / (30 s * 60 quadros)

// hp_max -> w0 = vida maxima (50 + 5 x Vitalidade)   folha
    .globl hp_max
hp_max:
    ldr     w0, [x28, #G_VIT]
    add     w0, w0, w0, lsl #2
    add     w0, w0, #50
    ret

// mp_max -> w0 = mana maxima (5 x Energia)   folha
    .globl mp_max
mp_max:
    ldr     w0, [x28, #G_ENE]
    add     w0, w0, w0, lsl #2
    ret

// hp_scale(s2 = dano em pontos de vida) -> s2 = dano em % da vida (G_HP)
// folha; usa w9, w10, s3
    .globl hp_scale
hp_scale:
    ldr     w9, [x28, #G_VIT]
    add     w9, w9, w9, lsl #2
    add     w9, w9, #50
    scvtf   s3, w9                      // vida maxima
    fdiv    s2, s2, s3
    mov     w10, #100
    scvtf   s3, w10
    fmul    s2, s2, s3
    ret

// xp_pct -> s0 = quanto do nivel ja foi (0..100)   folha
    .globl xp_pct
xp_pct:
    ldr     x9, [x28, #G_XP]
    ldr     x10, [x28, #G_XPNEED]
    ucvtf   d0, x9
    ucvtf   d1, x10
    fdiv    d0, d0, d1
    mov     x9, #100
    ucvtf   d1, x9
    fmul    d0, d0, d1
    fcvt    s0, d0
    ret

// numcat64(x0 = cursor, x1 = numero de 64 bits) -> x0 depois do numero
    .globl numcat64
numcat64:
    sub     sp, sp, #32
    mov     x10, #10
    mov     x11, #0
1:  udiv    x12, x1, x10
    msub    x13, x12, x10, x1
    add     w13, w13, #48
    strb    w13, [sp, x11]
    add     x11, x11, #1
    mov     x1, x12
    cbnz    x1, 1b
2:  sub     x11, x11, #1
    ldrb    w13, [sp, x11]
    strb    w13, [x0], #1
    cbnz    x11, 2b
    strb    wzr, [x0]
    add     sp, sp, #32
    ret

// ---------------------------------------------------------------------
//  Atributos
// ---------------------------------------------------------------------

// attr_add(w0 = 0 Forca, 1 Destreza, 2 Vitalidade, 3 Energia): gasta um
// ponto nesse atributo
    .globl attr_add
attr_add:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     w19, w0
    ldr     w9, [x28, #G_APTS]
    cbz     w9, 8f
    sub     w9, w9, #1
    str     w9, [x28, #G_APTS]
    add     x10, x28, #G_STR
    ldr     w9, [x10, x19, lsl #2]
    add     w9, w9, #1
    str     w9, [x10, x19, lsl #2]
    bl      calc_stats
    LA      x0, xpbuf                   // "+1 Forca"
    LA      x1, s_plus1
    bl      strcat_cur
    LA      x1, attrnames
    add     x1, x1, x19, lsl #4
    bl      strcat_cur
    LA      x0, xpbuf
    bl      popup
    b       9f
8:  LA      x0, m_nopts
    bl      set_msg
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// char_window: a janela do personagem (C) desenhada pelo designer
// (pedido 1.0): retrato, nome, nivel, XP, os 4 atributos com o botao +,
// os pontos livres e os valores derivados. As posicoes sao as areas do
// ermo_fase1.json (UA_* no pixel.h), a partir do canto da janela.
    .equ WX, CHR_X
    .equ WY, CHR_Y
    .globl char_window
char_window:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    LA      x0, uiwin
    mov     w1, #WX
    mov     w2, #WY
    mov     w3, #0
    bl      ui_img
    mov     w0, #(WX + UA_TITULO_X + 4)        // "Personagem" (10 letras em 88)
    mov     w1, #(WY + UA_TITULO_Y)
    LA      x2, s_wtitle
    bl      wtext
    mov     w0, #(WX + UA_RETRATO_X)
    mov     w1, #(WY + UA_RETRATO_Y)
    bl      hero_portrait
    mov     w0, #(WX + UA_NOME_X)
    mov     w1, #(WY + UA_NOME_Y)
    LA      x2, s_heroname
    bl      wtext
    LA      x0, xpbuf                          // "Nivel 3"
    LA      x1, s_nivel
    bl      strcat_cur
    ldr     w1, [x28, #G_LEVEL]
    bl      numcat
    mov     w0, #(WX + UA_NIVEL_X)
    mov     w1, #(WY + UA_NIVEL_Y)
    LA      x2, xpbuf
    bl      wtext
    bl      xp_pct                             // barra: round(138 * xp / precisa)
    mov     w9, #UA_XP_W
    scvtf   s1, w9
    fmul    s0, s0, s1
    mov     w9, #100
    scvtf   s1, w9
    fdiv    s0, s0, s1
    fcvtns  w3, s0
    cmp     w3, #0
    b.le    1f
    LA      x0, uixp
    mov     w1, #(WX + UA_XP_X)
    mov     w2, #(WY + UA_XP_Y)
    bl      ui_img
1:  LA      x0, xpbuf                          // "XP 3 / 5"
    LA      x1, s_xptxt
    bl      strcat_cur
    ldr     x1, [x28, #G_XP]
    bl      numcat64
    LA      x1, s_slash
    bl      strcat_cur
    ldr     x1, [x28, #G_XPNEED]
    bl      numcat64
    mov     w0, #(WX + UA_XP_TEXTO_X)
    mov     w1, #(WY + UA_XP_TEXTO_Y)
    LA      x2, xpbuf
    bl      wtext
    // os 4 atributos
    ldr     w21, [x28, #G_APTS]
    bl      mouse_ui
    mov     w22, w0                            // mouse
    mov     w23, w1
    mov     x0, #0
    mov     x1, #0
    bl      F(SDL_GetMouseState)
    and     w24, w0, #1                        // botao esquerdo apertado
    mov     w19, #0
2:  cmp     w19, #4
    b.ge    6f
    mov     w9, #UA_PASSO
    mul     w20, w19, w9                       // descida da linha
    LA      x9, uiicons
    ldr     x0, [x9, x19, lsl #3]
    mov     w1, #(WX + UA_FORCA_ICONE_X)
    add     w2, w20, #(WY + UA_FORCA_ICONE_Y)
    mov     w3, #0
    bl      ui_img
    mov     w0, #(WX + UA_FORCA_NOME_X)
    add     w1, w20, #(WY + UA_FORCA_NOME_Y)
    LA      x2, attrnames
    add     x2, x2, x19, lsl #4
    bl      wtext
    LA      x0, xpbuf
    add     x9, x28, #G_STR
    ldr     w1, [x9, x19, lsl #2]
    bl      numcat
    mov     w0, #(WX + UA_FORCA_VALOR_X + UA_FORCA_VALOR_W)
    add     w1, w20, #(WY + UA_FORCA_VALOR_Y)
    LA      x2, xpbuf
    bl      wtext_r
    mov     w3, #3                             // desligado: sem pontos
    cbz     w21, 4f
    mov     w3, #0                             // normal
    sub     w9, w22, #(WX + UA_FORCA_MAIS_X)
    cmp     w9, #UA_FORCA_MAIS_W
    b.hs    4f
    sub     w9, w23, w20
    sub     w9, w9, #(WY + UA_FORCA_MAIS_Y)
    cmp     w9, #UA_FORCA_MAIS_H
    b.hs    4f
    mov     w3, #1                             // mouse em cima
    cbz     w24, 4f
    mov     w3, #2                             // apertado
4:  LA      x9, uibtns
    ldr     x0, [x9, x3, lsl #3]
    mov     w1, #(WX + UA_FORCA_MAIS_X)
    add     w2, w20, #(WY + UA_FORCA_MAIS_Y)
    mov     w3, #0
    bl      ui_img
    add     w19, w19, #1
    b       2b
6:  mov     w0, #(WX + UA_PONTOS_TEXTO_X)
    mov     w1, #(WY + UA_PONTOS_TEXTO_Y)
    LA      x2, s_pts
    bl      wtext
    LA      x0, xpbuf
    mov     w1, w21
    bl      numcat
    mov     w0, #(WX + UA_PONTOS_VALOR_X + UA_PONTOS_VALOR_W)
    mov     w1, #(WY + UA_PONTOS_VALOR_Y)
    LA      x2, xpbuf
    bl      wtext_r
    // derivados: vida e mana maximas e a carga (dano, acerto e
    // defesa vem na etapa 1.5 e na fase 3)
    LA      x0, xpbuf                          // "Vida 100" (maxima)
    LA      x1, s_vida
    bl      strcat_cur
    mov     x19, x0
    bl      hp_max
    mov     w1, w0
    mov     x0, x19
    bl      numcat
    mov     w0, #(WX + UA_VIDA_X)
    mov     w1, #(WY + UA_VIDA_Y)
    LA      x2, xpbuf
    bl      wtext
    LA      x0, xpbuf                          // "Mana 50" (maxima)
    LA      x1, s_mana
    bl      strcat_cur
    mov     x19, x0
    bl      mp_max
    mov     w1, w0
    mov     x0, x19
    bl      numcat
    mov     w0, #(WX + UA_MANA_X)
    mov     w1, #(WY + UA_MANA_Y)
    LA      x2, xpbuf
    bl      wtext
    LA      x0, xpbuf                          // "Carga 30.1"
    LA      x1, s_carga2
    bl      strcat_cur
    ldr     w1, [x28, #G_CAP]
    bl      kgcat
    mov     w0, #(WX + UA_ACERTO_X)
    mov     w1, #(WY + UA_ACERTO_Y)
    LA      x2, xpbuf
    bl      wtext
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// xp_hudbar: a barra de XP da tela (pedido 1.0), em cima da barra "na
// mao", sempre visivel: pontas e meio do designer, roxo pela porcentagem
    .equ XB_X, HB_X
    .equ XB_Y, (HB_Y - 9)
    .equ XB_W, (NHOTBAR * SLOTSTEP - 4)
    .globl xp_hudbar
xp_hudbar:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    LA      x0, uixpl
    mov     w1, #XB_X
    mov     w2, #XB_Y
    mov     w3, #0
    bl      ui_img
    LA      x0, uixpm
    mov     w1, #(XB_X + 5)
    mov     w2, #XB_Y
    mov     w3, #(XB_W - 10)
    bl      ui_stretch
    LA      x0, uixpr
    mov     w1, #(XB_X + XB_W - 5)
    mov     w2, #XB_Y
    mov     w3, #0
    bl      ui_img
    bl      xp_pct                      // colunas = round((W - 10) * pct)
    mov     w9, #(XB_W - 10)
    scvtf   s1, w9
    fmul    s0, s0, s1
    mov     w9, #100
    scvtf   s1, w9
    fdiv    s0, s0, s1
    fcvtns  w19, s0
    cmp     w19, #0
    b.le    9f
    LA      x0, uixpf
    mov     w1, #(XB_X + 5)
    mov     w2, #(XB_Y + 1)
    mov     w3, w19
    bl      ui_stretch
    LA      x0, uixpp                   // a ponta clara
    mov     w1, #(XB_X + 4)
    add     w1, w1, w19
    mov     w2, #(XB_Y + 1)
    mov     w3, #0
    bl      ui_img
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// hud_num(w0 y, s0 = %, w1 maximo): "152/152" dentro da barra do painel,
// a direita (como na stamina)
    .globl hud_num
hud_num:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     w19, w0
    scvtf   s1, w1
    fmul    s0, s0, s1
    FC      s1, F_HUNDRED
    fdiv    s0, s0, s1
    fcvtns  w9, s0
    cmp     w9, #0
    csel    w9, wzr, w9, lt
    mov     w20, w1
    LA      x0, hudbuf
    mov     w1, w9
    bl      numcat
    mov     w9, #47
    strb    w9, [x0], #1
    mov     w1, w20
    bl      numcat
    LA      x0, hudbuf
    bl      mystrlen
    lsl     w20, w0, #3
    RGBA    30, 16, 20, 255
    mov     w0, #188
    sub     w0, w0, w20
    mov     w1, w19
    LA      x2, hudbuf
    bl      text
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// wtext(w0 x, w1 y, x2 texto): texto da janela, cor Í com sombra Ê
// 1 px para baixo e para a direita (como pede o designer)
wtext:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     x21, x2
    RGBA    14, 12, 14, 255
    add     w0, w19, #1
    add     w1, w20, #1
    mov     x2, x21
    bl      text
    RGBA    216, 200, 164, 255
    mov     w0, w19
    mov     w1, w20
    mov     x2, x21
    bl      text
    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// wtext_r(w0 x da direita, w1 y, x2 texto): alinhado a direita
wtext_r:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     x21, x2
    mov     x0, x2
    bl      mystrlen
    sub     w0, w19, w0, lsl #3
    mov     w1, w20
    mov     x2, x21
    bl      wtext
    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
//  Teste automatico (--shot): a curva e subir varios niveis de uma vez
// ---------------------------------------------------------------------
    .globl xp_selftest
xp_selftest:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    ldr     w21, [x28, #G_LEVEL]        // guarda o que a caca deu
    ldr     x22, [x28, #G_XP]
    LA      x0, txt                     // "nivel: curva 1, 2, 2, 3, ..."
    LA      x1, s_t1
    bl      strcat_cur
    mov     w19, #1
1:  mov     x20, x0
    mov     w0, w19
    bl      xp_need
    mov     x1, x0
    mov     x0, x20
    bl      numcat64
    cmp     w19, #10
    b.eq    2f
    LA      x1, s_comma
    bl      strcat_cur
    add     w19, w19, #1
    b       1b
2:  LA      x1, s_t2                    // nivel 20 e 40
    bl      strcat_cur
    mov     x20, x0
    mov     w0, #20
    bl      xp_need
    mov     x1, x0
    mov     x0, x20
    bl      numcat64
    LA      x1, s_t3
    bl      strcat_cur
    mov     x20, x0
    mov     w0, #40
    bl      xp_need
    mov     x1, x0
    mov     x0, x20
    bl      numcat64
    mov     x20, x0
    LA      x1, s_t4                    // a caca do teste
    mov     x0, x20
    bl      strcat_cur
    mov     w1, w21
    bl      numcat
    LA      x1, s_t5
    bl      strcat_cur
    mov     x1, x22
    bl      numcat64
    mov     x20, x0
    bl      xp_reset                    // do nivel 1, 100 XP de uma vez
    mov     w0, #100
    bl      xp_gain
    LA      x1, s_t6
    mov     x0, x20
    bl      strcat_cur
    ldr     w1, [x28, #G_LEVEL]
    bl      numcat
    LA      x1, s_t7
    bl      strcat_cur
    ldr     x1, [x28, #G_XP]
    bl      numcat64
    LA      x1, s_t8
    bl      strcat_cur
    ldr     x1, [x28, #G_XPNEED]
    bl      numcat64
    LA      x1, s_t9                    // pontos e gastar 2 em Forca
    bl      strcat_cur
    ldr     w1, [x28, #G_APTS]
    bl      numcat
    mov     x20, x0
    mov     w0, #0
    bl      attr_add
    mov     w0, #0
    bl      attr_add
    mov     x0, x20
    LA      x1, s_t10
    bl      strcat_cur
    ldr     w1, [x28, #G_STR]
    bl      numcat
    LA      x1, s_t11
    bl      strcat_cur
    ldr     w1, [x28, #G_APTS]
    bl      numcat
    mov     x20, x0                     // Vitalidade e Energia 20
    mov     w9, #20
    str     w9, [x28, #G_VIT]
    str     w9, [x28, #G_ENE]
    LA      x1, s_t12
    mov     x0, x20
    bl      strcat_cur
    mov     x20, x0
    bl      hp_max
    mov     w1, w0
    mov     x0, x20
    bl      numcat
    LA      x1, s_t13
    bl      strcat_cur
    mov     x20, x0
    bl      mp_max
    mov     w1, w0
    mov     x0, x20
    bl      numcat
    LA      x1, s_t14
    bl      strcat_cur
    mov     x20, x0
    mov     w9, #30                     // mordida de 30 pontos
    scvtf   s2, w9
    bl      hp_scale
    fcvtns  w1, s2
    mov     x0, x20
    bl      numcat
    LA      x1, s_t15
    bl      strcat_cur
    bl      an_selftest                 // bichos com nivel (animais.S)
    mov     w9, #10
    str     w9, [x28, #G_VIT]
    str     w9, [x28, #G_ENE]
    LA      x1, s_nl
    bl      strcat_cur
    bl      sk_write
    str     wzr, [x28, #G_MSGT]
    str     wzr, [x28, #G_POPT]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

    .data
s_xp:       .asciz " XP"
s_lvlup:    .asciz "Voce subiu para o nivel "
s_excl:     .asciz "! Pontos de atributo na janela C"
s_comma:    .asciz ", "
s_t9:       .asciz " pontos="
s_t10:      .asciz " | +2 Forca -> forca="
s_t11:      .asciz " pontos="
s_t12:      .asciz " | vit/ene 20: vida max="
s_t13:      .asciz " mana max="
s_t14:      .asciz " mordida de 30 tira "
s_t15:      .asciz "%"
s_nl:       .asciz "\n"
s_t1:       .asciz "nivel: XP por nivel 1-10 = "
s_t2:       .asciz " | nivel 20 = "
s_t3:       .asciz " nivel 40 = "
s_t4:       .asciz " | depois da caca: nivel="
s_t5:       .asciz " xp="
s_t6:       .asciz " | 100 XP no nivel 1 -> nivel="
s_t7:       .asciz " xp="
s_t8:       .asciz "/"
s_plus1:    .asciz "+1 "
s_pts:      .asciz "Pontos livres:"
s_wtitle:   .asciz "Personagem"
s_heroname: .asciz "Andarilho"
s_nivel:    .asciz "Nivel "
s_xptxt:    .asciz "XP "
s_slash:    .asciz " / "
s_vida:     .asciz "Vida "
s_mana:     .asciz "Mana "
s_carga2:   .asciz "Carga "
m_nopts:    .asciz "Sem pontos de atributo: suba de nivel"
    .p2align 4
attrnames:
    .asciz "Forca"
    .space 10
    .asciz "Destreza"
    .space 7
    .asciz "Vitalidade"
    .space 5
    .asciz "Energia"
    .space 8
xpbuf:      .space 32
hudbuf:     .space 32
lvlbuf:     .space 96
