// =====================================================================
//  ERMO - um jogo de sobrevivencia (estilo Factorio), todo escrito em
//  assembly ARM64 (AArch64). Roda no macOS (Apple Silicon) e no Linux ARM64.
//  (sprites 15-21: ferramentas, tocha, comida, cesto, bau e abrigo;
//  23-29: arco, flechas, carne, couro, roupa e mochila; 30-41: animais;
//  a enchente sobe o nivel da agua no desenho do terreno)
//
//  Terreno continuo (sem tiles): um mapa de altura 512x512 interpolado
//  e desenhado coluna por coluna (tecnica "voxel space" com projecao
//  isometrica), com y-buffer, z-buffer e iluminacao suave. Arvores,
//  pedras e arbustos ficam em posicoes livres e respeitam a profundidade.
//
//  Este arquivo cuida do mundo (geracao, terreno, objetos, camera e
//  interface basica). O personagem fica em sobrevivencia.S. A SDL3 so
//  abre a janela, le teclado/mouse e mostra o framebuffer.
//
//  Compilar:  make   (junta ermo.S + sobrevivencia.S e os outros, com comum.h)
//  Testar sem tela:  ./ermo --shot  (salva screenshots e mede o tempo)
// =====================================================================

#include "comum.h"

.equ SDL_INIT_VIDEO,        0x20
.equ SDL_EVENT_QUIT,        0x100
.equ SDL_EVENT_KEY_DOWN,    0x300
.equ SDL_EVENT_MOUSE_MOTION,0x400
.equ SDL_EVENT_MOUSE_WHEEL, 0x403
.equ SDL_EVENT_MOUSE_DOWN,  0x401
.equ SDL_EVENT_MOUSE_UP,    0x402

// =====================================================================
    .text
    .p2align 2
    .globl F(main)
F(main):
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]

    LA      x28, G
    mov     w20, #0
    cmp     w0, #1
    cset    w9, gt
    str     w9, [x28, #G_SHOT]

    mov     w0, #SDL_INIT_VIDEO
    bl      F(SDL_Init)
    tst     w0, #0xff
    b.eq    main_fail

    LA      x0, s_wintitle
    mov     w1, #SCRW
    mov     w2, #SCRH
    mov     x3, #0x20                   // SDL_WINDOW_RESIZABLE
    bl      F(SDL_CreateWindow)
    cbz     x0, main_fail
    str     x0, [x28, #G_WIN]
    mov     x1, #0
    bl      F(SDL_CreateRenderer)
    cbz     x0, main_fail
    str     x0, [x28, #G_REN]
    mov     w1, #1
    bl      F(SDL_SetRenderVSync)
    ldr     x0, [x28, #G_REN]
    mov     w1, #1                      // SDL_BLENDMODE_BLEND
    bl      F(SDL_SetRenderDrawBlendMode)
    ldr     x0, [x28, #G_REN]           // tela cheia / janela maior: a imagem
    mov     w1, #SCRW                   // continua 1280 x 720, com faixas
    mov     w2, #SCRH
    mov     w3, #2                      // SDL_LOGICAL_PRESENTATION_LETTERBOX
    mov     w4, #0
    bl      F(SDL_SetRenderLogicalPresentation)

    ldr     x0, [x28, #G_REN]
    MOVI32  w1, 0x16362004              // SDL_PIXELFORMAT_ARGB8888
    mov     w2, #1                      // SDL_TEXTUREACCESS_STREAMING
    mov     w3, #SCRW
    mov     w4, #SCRH
    bl      F(SDL_CreateTexture)
    cbz     x0, main_fail
    str     x0, [x28, #G_TEX]
    mov     w1, #0
    bl      F(SDL_SetTextureScaleMode)

    mov     x0, #0
    bl      F(SDL_GetKeyboardState)
    str     x0, [x28, #G_KEYS]

    bl      F(SDL_GetPerformanceCounter)
    mov     x19, x0
    mov     x0, #0
    bl      F(time)
    eor     x0, x0, x19
    eor     x0, x0, x0, lsr #32
    orr     w0, w0, #1
    str     w0, [x28, #G_RNG]

    // tabela de ruido 256x256 (usada para texturizar o terreno)
    mov     w19, #0
7:  mov     w0, w19
    mov     w1, #0
    mov     w2, #1234
    bl      hash3
    LA      x9, noisetab
    strb    w0, [x9, w19, uxtw]
    add     w19, w19, #1
    cmp     w19, #16, lsl #12
    b.lo    7b

    mov     w9, #1
    str     w9, [x28, #G_RUNNING]
    str     wzr, [x28, #G_STATE]
    mov     w0, #0
    bl      set_zoom
    bl      new_world

    ldr     w9, [x28, #G_SHOT]
    cbnz    w9, shot_mode

main_loop:
    bl      handle_events
    bl      update
    bl      draw_all
    ldr     w9, [x28, #G_WANTSHOT]
    cbz     w9, 2f
    str     wzr, [x28, #G_WANTSHOT]
    LA      x0, s_shot_f12
    bl      save_bmp
2:  ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    ldr     w9, [x28, #G_FRAME]
    add     w9, w9, #1
    str     w9, [x28, #G_FRAME]
    ldr     w9, [x28, #G_RUNNING]
    cbnz    w9, main_loop

main_exit:
    ldr     x0, [x28, #G_TEX]
    cbz     x0, 4f
    bl      F(SDL_DestroyTexture)
4:  ldr     x0, [x28, #G_REN]
    cbz     x0, 5f
    bl      F(SDL_DestroyRenderer)
5:  ldr     x0, [x28, #G_WIN]
    cbz     x0, main_quit
    bl      F(SDL_DestroyWindow)
main_quit:
    bl      F(SDL_Quit)
    mov     w0, w20
    ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

main_fail:
    bl      F(SDL_GetError)
    mov     x19, x0
    bl      mystrlen
    mov     x2, x0
    mov     x1, x19
    mov     w0, #2
    bl      F(write)
    LA      x1, s_nl
    mov     w0, #2
    mov     x2, #1
    bl      F(write)
    mov     w20, #1
    b       main_exit

// ---- modo screenshot / benchmark (para testar sem tela) -------------
shot_mode:
    bl      update
    bl      draw_all
    LA      x0, s_shot_title
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)

    bl      start_game
    mov     w0, #W_SUN                  // teste: sol fixo (resultados iguais
    MOVI32  w1, 1000000                 // em toda rodada)
    MOVI32  w2, 500000
    bl      weather_set
    mov     w9, #1                      // e animais so quando o teste pedir
    str     w9, [x28, #G_NOSPAWN]
    mov     w9, #700
    scvtf   s0, w9
    str     s0, [x28, #G_MX]
    mov     w9, #400
    scvtf   s0, w9
    str     s0, [x28, #G_MY]
    bl      update
    bl      draw_all
    LA      x0, s_shot_game
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)

    // tempo medio por quadro (30 quadros)
    bl      F(SDL_GetTicksNS)
    mov     x19, x0
    mov     w21, #30
6:  bl      draw_terrain
    bl      draw_objects
    bl      surv_draw
    bl      surv_light                  // neblina (e luz, se for noite)
    subs    w21, w21, #1
    b.ne    6b
    bl      F(SDL_GetTicksNS)
    sub     x0, x0, x19
    mov     x9, #30000
    udiv    x21, x0, x9                 // microssegundos por quadro
    LA      x0, txt
    LA      x1, s_bench
    bl      strcat_cur
    mov     w1, w21
    bl      numcat
    LA      x1, s_bench2
    bl      strcat_cur
    LA      x9, txt
    sub     x2, x0, x9
    mov     x1, x9
    mov     w0, #1
    bl      F(write)

    mov     w0, #0
    bl      set_zoom
    bl      draw_all
    LA      x0, s_shot_far
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)

    // sobrevivencia: coleta, fogueira e noite (teste automatico)
    bl      surv_selftest
    mov     w0, #2
    bl      set_zoom
    bl      draw_all
    LA      x0, s_shot_near
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #3
    bl      set_zoom
    bl      draw_all
    LA      x0, s_shot_night
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)

    // skills, peso e mochila (foto com as duas janelas abertas)
    mov     w0, #0
    bl      surv_selftest_skills
    bl      draw_all
    LA      x0, s_shot_bag
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #1
    bl      surv_selftest_skills

    // fabricar: ferramentas, bau, abrigo, tocha (fotos de dia e de noite)
    mov     w0, #0
    bl      surv_selftest_craft
    bl      draw_all
    LA      x0, s_shot_craft
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #1
    bl      surv_selftest_craft
    bl      draw_all
    LA      x0, s_shot_torch
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #2
    bl      surv_selftest_craft
    bl      draw_all                    // a cabana, de dia
    LA      x0, s_shot_hut
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #3                      // deita as 22h
    bl      surv_selftest_craft
    bl      draw_all
    LA      x0, s_shot_sleep
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #4                      // dorme ate acordar
    bl      surv_selftest_craft

    // clima: cada um dos 8, com foto (shot_clima0.bmp ... shot_clima7.bmp)
    mov     w23, #0
71: mov     w0, w23
    bl      surv_selftest_weather
    bl      draw_all
    LA      x0, s_shot_clima
    add     w9, w23, #48
    strb    w9, [x0, #10]
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    add     w23, w23, #1
    cmp     w23, #NWEATHER
    b.lt    71b
    mov     w0, #W_SUN                  // de volta ao sol fixo
    MOVI32  w1, 1000000
    MOVI32  w2, 500000
    bl      weather_set

    // animais: um de cada perto (foto), depois a caca e o lobo
    mov     w0, #0
    bl      surv_selftest_hunt
    bl      draw_all
    LA      x0, s_shot_anim
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #1
    bl      surv_selftest_hunt

    // cercas (foto) e pesca (foto)
    mov     w0, #0
    bl      surv_selftest_build
    bl      draw_all
    LA      x0, s_shot_fence
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #1
    bl      surv_selftest_build
    mov     w0, #2
    bl      surv_selftest_build
    bl      draw_all
    LA      x0, s_shot_fish
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #3
    bl      surv_selftest_build

    // plantacao: ara, planta (foto de perto), colhe, pao, crescimento, coelho
    mov     w0, #0
    bl      farm_selftest
    ldr     w19, [x28, #G_ZOOM]
    mov     w0, #3
    bl      set_zoom
    bl      draw_all
    LA      x0, s_shot_farm
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, w19
    bl      set_zoom
    mov     w0, #1
    bl      farm_selftest

    // pessoas: a vila trabalhando 1 hora (foto pintando zonas), o painel
    // (foto), mais 2 horas, a noite, 12 dias e um lobo
    mov     w0, #0
    bl      people_selftest
    ldr     w19, [x28, #G_ZOOM]
    mov     w0, #3
    bl      set_zoom
    bl      draw_all
    LA      x0, s_shot_people
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #2
    bl      people_selftest
    bl      draw_all
    LA      x0, s_shot_panel
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, w19
    bl      set_zoom
    mov     w0, #1
    bl      people_selftest
    ldr     w19, [x28, #G_ZOOM]         // a vila depois das obras
    mov     w0, #3
    bl      set_zoom
    bl      draw_all
    LA      x0, s_shot_village
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #3                      // arvore genealogica
    bl      people_selftest
    bl      draw_all
    LA      x0, s_shot_family
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    str     wzr, [x28, #G_PEOPLEOPEN]
    mov     w0, #0                      // ferro: voce (foto de noite na fornalha)
    bl      iron_selftest
    bl      draw_all
    LA      x0, s_shot_iron
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #1                      // ferro: a vila
    bl      iron_selftest
    mov     w0, w19
    bl      set_zoom
    mov     w9, #1                      // o resto do teste sem a vila
    str     w9, [x28, #G_NOPEOPLE]

    // agua: nadando, tubarao chegando e o fim
    mov     w0, #0
    bl      surv_selftest_water
    bl      draw_all
    LA      x0, s_shot_swim
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #1
    bl      surv_selftest_water
    bl      draw_all
    LA      x0, s_shot_shark
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)
    mov     w0, #2
    bl      surv_selftest_water
    bl      draw_all
    LA      x0, s_shot_dead
    bl      save_bmp
    b       main_exit

// =====================================================================
//  Utilitarios
// =====================================================================

// set_zoom(w0 = 0..3): 0 = longe (0.5x) ... 3 = perto (4x)
    .globl set_zoom
set_zoom:
    str     w0, [x28, #G_ZOOM]
    mov     w9, #128
    lsl     w9, w9, w0
    str     w9, [x28, #G_Z256]
    mov     w10, #2000
    mul     w10, w10, w9
    lsr     w10, w10, #12
    str     w10, [x28, #G_EMAXZ]
    mov     w10, #32
    lsr     w10, w10, w0
    str     w10, [x28, #G_K]
    ret

zoom_in:
    ldr     w0, [x28, #G_ZOOM]
    cmp     w0, #3
    b.ge    1f
    add     w0, w0, #1
    b       set_zoom
1:  ret

zoom_out:
    ldr     w0, [x28, #G_ZOOM]
    cbz     w0, 1f
    sub     w0, w0, #1
    b       set_zoom
1:  ret

// rng() -> w0   (xorshift32)
    .globl rng
rng:
    ldr     w0, [x28, #G_RNG]
    eor     w0, w0, w0, lsl #13
    eor     w0, w0, w0, lsr #17
    eor     w0, w0, w0, lsl #5
    str     w0, [x28, #G_RNG]
    ret

// rng_mod(w0 = n) -> [0, n)   (usa w0, w9, w10)
    .globl rng_mod
rng_mod:
    mov     w10, w0
    ldr     w0, [x28, #G_RNG]
    eor     w0, w0, w0, lsl #13
    eor     w0, w0, w0, lsr #17
    eor     w0, w0, w0, lsl #5
    str     w0, [x28, #G_RNG]
    udiv    w9, w0, w10
    msub    w0, w9, w10, w0
    ret

// hash3(w0 = x, w1 = y, w2 = sal) -> w0   (usa SO w0 e w9)
    .globl hash3
hash3:
    MOVI32  w9, 0x27d4eb2d
    mul     w0, w0, w9
    MOVI32  w9, 0x165667b1
    madd    w0, w1, w9, w0
    MOVI32  w9, 0x9E3779B1
    madd    w0, w2, w9, w0
    eor     w0, w0, w0, lsr #15
    MOVI32  w9, 0x85ebca6b
    mul     w0, w0, w9
    eor     w0, w0, w0, lsr #13
    MOVI32  w9, 0xc2b2ae35
    mul     w0, w0, w9
    eor     w0, w0, w0, lsr #16
    ret

// mystrlen(x0) -> x0   (usa x9, x10)
    .globl mystrlen
mystrlen:
    mov     x9, x0
1:  ldrb    w10, [x9], #1
    cbnz    w10, 1b
    sub     x0, x9, x0
    sub     x0, x0, #1
    ret

// strcat_cur(x0 = destino, x1 = origem) -> x0 no '\0'  (usa w9)
    .globl strcat_cur
strcat_cur:
1:  ldrb    w9, [x1], #1
    strb    w9, [x0], #1
    cbnz    w9, 1b
    sub     x0, x0, #1
    ret

// numcat(x0 = destino, w1 = numero) -> x0 no '\0'  (usa x9-x13)
    .globl numcat
numcat:
    sub     sp, sp, #16
    mov     w10, #10
    mov     x11, #0
1:  udiv    w12, w1, w10
    msub    w13, w12, w10, w1
    add     w13, w13, #48
    strb    w13, [sp, x11]
    add     x11, x11, #1
    mov     w1, w12
    cbnz    w1, 1b
2:  sub     x11, x11, #1
    ldrb    w13, [sp, x11]
    strb    w13, [x0], #1
    cbnz    x11, 2b
    strb    wzr, [x0]
    add     sp, sp, #16
    ret

// save_bmp(x0 = nome)
    .globl save_bmp
save_bmp:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     x19, x0
    ldr     x0, [x28, #G_REN]
    mov     x1, #0
    bl      F(SDL_RenderReadPixels)
    cbz     x0, 1f
    mov     x20, x0
    mov     x1, x19
    bl      F(SDL_SaveBMP)
    mov     x0, x20
    bl      F(SDL_DestroySurface)
1:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// sample_elev(w0 = u, w1 = v em 1/64 de celula) -> w0 = elevacao
// interpolacao bilinear   (usa x0-x7)
    .globl sample_elev
sample_elev:
    lsr     w2, w0, #6
    lsr     w3, w1, #6
    and     w4, w0, #63
    lsl     w4, w4, #2
    and     w5, w1, #63
    lsl     w5, w5, #2
    mov     w6, #510
    cmp     w2, w6
    csel    w2, w2, w6, lo
    cmp     w3, w6
    csel    w3, w3, w6, lo
    add     w6, w2, w3, lsl #9
    LA      x7, elev
    add     x7, x7, w6, uxtw #1
    ldrsh   w0, [x7]
    ldrsh   w6, [x7, #2]
    sub     w6, w6, w0
    mul     w6, w6, w4
    add     w0, w0, w6, asr #8
    ldrsh   w2, [x7, #1024]
    ldrsh   w6, [x7, #1026]
    sub     w6, w6, w2
    mul     w6, w6, w4
    add     w2, w2, w6, asr #8
    sub     w2, w2, w0
    mul     w2, w2, w5
    add     w0, w0, w2, asr #8
    ret

// add_obj(w0 = u, w1 = v, w2 = e, w3 = tipo, w4 = variante)  (usa x9, x10)
    .globl add_obj
add_obj:
    ldr     w9, [x28, #G_NOBJ]
    MOVI32  w10, MAXOBJ
    cmp     w9, w10
    b.hs    1f
    LA      x10, objs
    add     x10, x10, w9, uxtw #3
    strh    w0, [x10]
    strh    w1, [x10, #2]
    strh    w2, [x10, #4]
    strb    w3, [x10, #6]
    strb    w4, [x10, #7]
    add     w9, w9, #1
    str     w9, [x28, #G_NOBJ]
1:  ret

// =====================================================================
//  Geracao do mundo
// =====================================================================

new_world:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    bl      F(SDL_GetTicksNS)
    mov     x19, x0
    bl      rng
    eor     w0, w0, w19
    MOVI32  w9, 100000
    udiv    w10, w0, w9
    msub    w0, w10, w9, w0
    add     w0, w0, #1
    str     w0, [x28, #G_SEED]
    str     wzr, [x28, #G_INGAME]
    bl      generate_map
    str     wzr, [x28, #G_CX]
    mov     w9, #16384                  // centro do mapa: 1024 px * 16
    str     w9, [x28, #G_CY]
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

generate_map:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    ldr     w19, [x28, #G_SEED]
    mov     w0, w19
    mov     w1, #77
    mov     w2, #99
    bl      hash3
    orr     w0, w0, #1
    str     w0, [x28, #G_RNG]
    str     wzr, [x28, #G_NOBJ]

    // relevo: 6 oitavas (128, 64, 32, 16, 8, 4 celulas)
    LA      x0, accum
    mov     w1, w19
    mov     w2, #6
    mov     w3, #7
    bl      gen_noise
    LA      x0, accum
    LA      x1, hmap
    bl      normalize
    bl      edge_falloff

    // umidade
    LA      x0, accum
    MOVI32  w1, 0x5bd1e995
    eor     w1, w1, w19
    mov     w2, #5
    mov     w3, #6
    bl      gen_noise
    LA      x0, accum
    LA      x1, moist
    bl      normalize

    bl      gen_elev
    bl      gen_light

    LA      x9, overlay                 // limpa ruas/areas urbanas
    mov     w10, #16384
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b

    bl      gen_trees
    bl      gen_resources               // pedras e arbustos (sobrevivencia.S)
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// gen_noise(x0 = acc[int32], w1 = sal, w2 = oitavas, w3 = shift inicial)
// ruido de valor com interpolacao suave; shift <= 8
gen_noise:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     x27, [sp, #80]
    str     w2, [sp, #88]
    str     w3, [sp, #92]
    mov     x19, x0
    mov     w20, w1

    mov     x9, x19
    mov     w10, #65536
1:  stp     xzr, xzr, [x9], #16
    subs    w10, w10, #1
    b.ne    1b

    mov     w21, #0
gn_oct:
    ldr     w9, [sp, #88]
    cmp     w21, w9
    b.ge    gn_done
    ldr     w22, [sp, #92]
    sub     w22, w22, w21
    cmp     w22, #1
    b.lt    gn_done
    mov     w9, #1013
    madd    w27, w21, w9, w20

    mov     w23, #0
gn_y:
    lsr     w26, w23, w22
    mov     w9, #1
    lsl     w9, w9, w22
    sub     w9, w9, #1
    and     w10, w23, w9
    mov     w9, #8
    sub     w9, w9, w22
    lsl     w10, w10, w9
    mul     w11, w10, w10
    mov     w12, #768
    sub     w12, w12, w10, lsl #1
    mul     w11, w11, w12
    lsr     w25, w11, #16

    mov     w24, #0
gn_x:
    lsr     w15, w24, w22
    mov     w9, #1
    lsl     w9, w9, w22
    sub     w9, w9, #1
    and     w10, w24, w9
    mov     w9, #8
    sub     w9, w9, w22
    lsl     w10, w10, w9
    mul     w11, w10, w10
    mov     w12, #768
    sub     w12, w12, w10, lsl #1
    mul     w11, w11, w12
    lsr     w14, w11, #16

    mov     w0, w15
    mov     w1, w26
    mov     w2, w27
    bl      hash3
    and     w10, w0, #0xFFFF
    add     w0, w15, #1
    mov     w1, w26
    bl      hash3
    and     w11, w0, #0xFFFF
    mov     w0, w15
    add     w1, w26, #1
    bl      hash3
    and     w12, w0, #0xFFFF
    add     w0, w15, #1
    add     w1, w26, #1
    bl      hash3
    and     w13, w0, #0xFFFF

    sub     w11, w11, w10
    mul     w11, w11, w14
    asr     w11, w11, #8
    add     w10, w10, w11
    sub     w13, w13, w12
    mul     w13, w13, w14
    asr     w13, w13, #8
    add     w12, w12, w13
    sub     w12, w12, w10
    mul     w12, w12, w25
    asr     w12, w12, #8
    add     w10, w10, w12
    asr     w10, w10, w21

    add     w11, w24, w23, lsl #9
    ldr     w12, [x19, w11, uxtw #2]
    add     w12, w12, w10
    str     w12, [x19, w11, uxtw #2]

    add     w24, w24, #1
    cmp     w24, #MAPN
    b.lt    gn_x
    add     w23, w23, #1
    cmp     w23, #MAPN
    b.lt    gn_y
    add     w21, w21, #1
    b       gn_oct
gn_done:
    ldr     x27, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// normalize(x0 = acc[int32], x1 = destino[u8])
normalize:
    mov     w9, #0x7fffffff
    mov     w10, #0x80000000
    mov     x12, #0
    mov     x14, #262144
1:  ldr     w11, [x0, x12, lsl #2]
    cmp     w11, w9
    csel    w9, w11, w9, lt
    cmp     w11, w10
    csel    w10, w11, w10, gt
    add     x12, x12, #1
    cmp     x12, x14
    b.lo    1b
    sub     w10, w10, w9
    cbnz    w10, 2f
    mov     w10, #1
2:  mov     x12, #0
    mov     w13, #255
3:  ldr     w11, [x0, x12, lsl #2]
    sub     w11, w11, w9
    mul     w11, w11, w13
    udiv    w11, w11, w10
    strb    w11, [x1, x12]
    add     x12, x12, #1
    cmp     x12, x14
    b.lo    3b
    ret

// edge_falloff: perto das bordas o terreno afunda no mar
edge_falloff:
    LA      x0, hmap
    mov     w1, #0
    mov     w10, #262144
1:  and     w2, w1, #511
    lsr     w3, w1, #9
    mov     w4, #511
    sub     w5, w4, w2
    sub     w6, w4, w3
    cmp     w2, w3
    csel    w7, w2, w3, lt
    cmp     w7, w5
    csel    w7, w7, w5, lt
    cmp     w7, w6
    csel    w7, w7, w6, lt
    cmp     w7, #80
    b.ge    2f
    ldrb    w8, [x0, w1, uxtw]
    mul     w8, w8, w7
    mov     w9, #80
    udiv    w8, w8, w9
    strb    w8, [x0, w1, uxtw]
2:  add     w1, w1, #1
    cmp     w1, w10
    b.lo    1b
    ret

// gen_elev: altura (0..255) -> elevacao em 1/16 px
//   terra: 8d + d*d/32 (planicies suaves, montanhas ingremes)
//   agua:  24d (negativo = profundidade)
gen_elev:
    LA      x0, hmap
    LA      x1, elev
    mov     w2, #0
    mov     w10, #262144
1:  ldrb    w3, [x0, w2, uxtw]
    subs    w3, w3, #SEA
    b.lt    2f
    mul     w4, w3, w3
    lsr     w4, w4, #5
    add     w4, w4, w3, lsl #3
    b       3f
2:  mov     w4, #24
    mul     w4, w3, w4
3:  strh    w4, [x1, w2, uxtw #1]
    add     w2, w2, #1
    cmp     w2, w10
    b.lo    1b
    ret

// gen_light: luz vinda de cima/esquerda, pela inclinacao do terreno
gen_light:
    LA      x0, elev
    LA      x1, light
    mov     w2, #0
    mov     w10, #262144
1:  mov     w8, #128
    and     w3, w2, #511
    lsr     w4, w2, #9
    cmp     w3, #2                      // usa vizinhos a 2 celulas: luz suave
    b.lo    5f
    cmp     w4, #2
    b.lo    5f
    cmp     w3, #509
    b.hi    5f
    cmp     w4, #509
    b.hi    5f
    add     x5, x0, w2, uxtw #1
    ldrsh   w6, [x5]
    tbnz    w6, #31, 5f                 // agua: luz neutra
    ldrsh   w6, [x5, #4]                // e(u+2)
    ldrsh   w7, [x5, #-4]               // e(u-2)
    cmp     w6, #0
    csel    w6, w6, wzr, gt
    cmp     w7, #0
    csel    w7, w7, wzr, gt
    sub     w6, w6, w7
    add     w6, w6, w6, lsl #1          // * 3/8
    add     w8, w8, w6, asr #3
    mov     x7, #2048
    ldrsh   w6, [x5, x7]                // e(v+2)
    sub     x7, x5, #2048
    ldrsh   w7, [x7]                    // e(v-2)
    cmp     w6, #0
    csel    w6, w6, wzr, gt
    cmp     w7, #0
    csel    w7, w7, wzr, gt
    sub     w6, w6, w7
    add     w6, w6, w6, lsl #1          // * 3/16
    add     w8, w8, w6, asr #4
    mov     w9, #45
    cmp     w8, w9
    csel    w8, w9, w8, lt
    mov     w9, #235
    cmp     w8, w9
    csel    w8, w9, w8, gt
5:  strb    w8, [x1, w2, uxtw]
    add     w2, w2, #1
    cmp     w2, w10
    b.lo    1b
    ret

// gen_trees: florestas onde e umido, arvores soltas no campo
gen_trees:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
    ldr     w20, [x28, #G_SEED]
    add     w20, w20, #31
    mov     w19, #513
gt_loop:
    and     w22, w19, #511
    lsr     w23, w19, #9
    cmp     w23, #510
    b.ge    gt_done
    cbz     w22, gt_next
    cmp     w22, #510
    b.ge    gt_next
    LA      x9, elev
    ldrsh   w25, [x9, w19, uxtw #1]
    cmp     w25, #E_SAND
    b.lt    gt_next
    mov     w9, #1240
    cmp     w25, w9
    b.ge    gt_next
    LA      x9, overlay
    ldrb    w9, [x9, w19, uxtw]
    cbnz    w9, gt_next
    LA      x9, moist
    ldrb    w24, [x9, w19, uxtw]
    mov     w0, w22
    mov     w1, w23
    mov     w2, w20
    bl      hash3
    mov     w21, w0
    mov     w9, #150
    cmp     w25, #E_GRASS
    b.lt    1f
    mov     w9, #140
1:  cmp     w24, w9
    b.ge    gt_forest
    and     w9, w21, #127               // arvore solta (1 em 128)
    cbnz    w9, gt_next
    b       gt_one
gt_forest:
    and     w9, w21, #3
    cbz     w9, gt_next                 // 75% das celulas da floresta
    add     w9, w9, #170
    cmp     w24, w9
    b.lo    gt_one
    // floresta densa: segunda arvore
    mov     w0, w22
    mov     w1, w23
    lsr     w2, w21, #2
    and     w2, w2, #63
    lsr     w3, w21, #26
    lsr     w4, w21, #30
    and     w4, w4, #1
    bl      plant_tree
gt_one:
    mov     w0, w22
    mov     w1, w23
    lsr     w2, w21, #8
    and     w2, w2, #63
    lsr     w3, w21, #14
    and     w3, w3, #63
    lsr     w4, w21, #20
    and     w4, w4, #3
    cmp     w4, #0
    cset    w4, eq
    bl      plant_tree
gt_next:
    add     w19, w19, #1
    b       gt_loop
gt_done:
    ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// plant_tree(w0 = cu, w1 = cv, w2 = ou, w3 = ov, w4 = pinheiro?)
plant_tree:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    lsl     w19, w0, #6
    add     w19, w19, w2
    lsl     w20, w1, #6
    add     w20, w20, w3
    mov     w21, w4
    mov     w0, w19
    mov     w1, w20
    bl      sample_elev
    mov     w2, w0
    cmp     w2, #E_GRASS
    cset    w3, ge                      // nas colinas: pinheiros
    orr     w3, w3, w21
    mov     w0, w19
    mov     w1, w20
    mov     w4, #4                      // 4 madeiras por arvore
    bl      add_obj
    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// =====================================================================
//  Entrada
// =====================================================================
handle_events:
    stp     x29, x30, [sp, #-160]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    add     x19, sp, #32
he_loop:
    mov     x0, x19
    bl      F(SDL_PollEvent)
    tst     w0, #0xff
    b.eq    he_done
    ldr     x0, [x28, #G_REN]           // mouse: para as coordenadas da imagem
    mov     x1, x19
    bl      F(SDL_ConvertEventToRenderCoordinates)
    ldr     w9, [x19]
    cmp     w9, #SDL_EVENT_QUIT
    b.eq    he_quit
    cmp     w9, #SDL_EVENT_KEY_DOWN
    b.eq    he_key
    mov     w10, #SDL_EVENT_MOUSE_MOTION
    cmp     w9, w10
    b.eq    he_motion
    mov     w10, #SDL_EVENT_MOUSE_DOWN
    cmp     w9, w10
    b.eq    he_mdown
    mov     w10, #SDL_EVENT_MOUSE_UP
    cmp     w9, w10
    b.eq    he_mup
    mov     w10, #SDL_EVENT_MOUSE_WHEEL
    cmp     w9, w10
    b.eq    he_wheel
    b       he_loop

he_quit:
    str     wzr, [x28, #G_RUNNING]
    b       he_loop

he_key:
    ldrb    w9, [x19, #37]              // ignora repeticao
    cbnz    w9, he_loop
    ldr     w20, [x19, #24]             // scancode
    cmp     w20, #68                    // F11: tela cheia
    b.ne    1f
    ldr     w9, [x28, #G_FULL]
    eor     w9, w9, #1
    str     w9, [x28, #G_FULL]
    ldr     x0, [x28, #G_WIN]
    mov     w1, w9
    bl      F(SDL_SetWindowFullscreen)
    b       he_loop
1:  ldr     w9, [x28, #G_STATE]
    cbnz    w9, he_key_game
    // --- tela de titulo ---
    cmp     w20, #41                    // ESC
    b.eq    he_quit
    cmp     w20, #40                    // ENTER
    b.eq    he_start
    cmp     w20, #88
    b.eq    he_start
    cmp     w20, #44                    // ESPACO
    b.eq    he_start
    cmp     w20, #21                    // R: outro mundo
    b.ne    he_loop
    bl      new_world
    b       he_loop
he_start:
    bl      start_game
    b       he_loop

he_key_game:
    cmp     w20, #41                    // ESC: cancela/fecha janelas, ou
    b.ne    1f                          // volta ao titulo
    bl      surv_esc
    cbnz    w0, he_loop
    str     wzr, [x28, #G_STATE]
    mov     w0, #0
    bl      set_zoom
    b       he_loop
1:  ldr     w9, [x28, #G_DEAD]
    cbz     w9, 2f
    cmp     w20, #40                    // morto: ENTER = mundo novo
    b.eq    11f
    cmp     w20, #88
    b.ne    he_loop
11: bl      new_world
    bl      start_game
    b       he_loop
2:  cmp     w20, #10                    // G: grade liga/desliga
    b.ne    21f
    ldr     w9, [x28, #G_GRIDON]
    eor     w9, w9, #1
    str     w9, [x28, #G_GRIDON]
    LA      x0, m_gridoff
    cbz     w9, 20f
    LA      x0, m_gridon
20: bl      set_msg
    b       he_loop
21: cmp     w20, #17                    // N: curvas de nivel
    b.ne    3f
    ldr     w9, [x28, #G_CONTOUR]
    eor     w9, w9, #1
    str     w9, [x28, #G_CONTOUR]
    b       he_loop
3:  cmp     w20, #46                    // = / +
    b.eq    4f
    cmp     w20, #87
    b.ne    5f
4:  bl      zoom_in
    b       he_loop
5:  cmp     w20, #45                    // -
    b.eq    6f
    cmp     w20, #86
    b.ne    7f
6:  bl      zoom_out
    b       he_loop
7:  cmp     w20, #69                    // F12: screenshot
    b.ne    8f
    mov     w9, #1
    str     w9, [x28, #G_WANTSHOT]
    b       he_loop
8:  cmp     w20, #44                    // espaco: pausa
    b.ne    9f
    ldr     w9, [x28, #G_PAUSE]
    eor     w9, w9, #1
    str     w9, [x28, #G_PAUSE]
    b       he_loop
9:  mov     w0, w20                     // E, F...: sobrevivencia
    bl      surv_key
    b       he_loop

he_mdown:
    ldr     w9, [x28, #G_STATE]
    cbz     w9, he_loop
    ldrb    w0, [x19, #24]              // botao
    mov     w1, #1
    bl      surv_mouse
    b       he_loop
he_mup:
    ldr     w9, [x28, #G_STATE]
    cbz     w9, he_loop
    ldrb    w0, [x19, #24]
    mov     w1, #0
    bl      surv_mouse
    b       he_loop

he_motion:
    ldr     s0, [x19, #28]
    str     s0, [x28, #G_MX]
    ldr     s0, [x19, #32]
    str     s0, [x28, #G_MY]
    b       he_loop

he_wheel:
    ldr     s0, [x19, #28]
    ldr     w9, [x19, #32]
    cmp     w9, #1
    b.ne    1f
    fneg    s0, s0
1:  ldr     w9, [x28, #G_STATE]
    cbz     w9, he_loop
    ldr     s1, [x28, #G_WHEEL]
    fadd    s1, s1, s0
    fmov    s2, #1.0
    fcmp    s1, s2
    b.ge    2f
    fmov    s2, #-1.0
    fcmp    s1, s2
    b.le    3f
    str     s1, [x28, #G_WHEEL]
    b       he_loop
2:  str     wzr, [x28, #G_WHEEL]
    bl      zoom_in
    b       he_loop
3:  str     wzr, [x28, #G_WHEEL]
    bl      zoom_out
    b       he_loop

he_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #160
    ret

// start_game: entra no mundo (continua a partida, se ja existe uma)
start_game:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w9, #1
    str     w9, [x28, #G_STATE]
    mov     w0, #3                      // camera perto do personagem
    bl      set_zoom
    ldr     w9, [x28, #G_INGAME]
    cbnz    w9, 1f
    mov     w9, #1
    str     w9, [x28, #G_INGAME]
    bl      surv_reset
1:  ldp     x29, x30, [sp], #16
    ret

// =====================================================================
//  Atualizacao
// =====================================================================
update:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    ldr     w9, [x28, #G_STATE]
    cbnz    w9, 3f
    // titulo: a camera passeia
    ldr     w9, [x28, #G_FRAME]
    mov     w10, #2400
    udiv    w11, w9, w10
    msub    w9, w11, w10, w9
    cmp     w9, #1200
    b.ge    1f
    sub     w9, w9, #600
    b       2f
1:  mov     w10, #1800
    sub     w9, w10, w9
2:  lsl     w9, w9, #4
    str     w9, [x28, #G_CX]
    mov     w9, #16384
    str     w9, [x28, #G_CY]
    b       4f
3:  mov     w19, #SLEEPSPEED            // dormindo: a noite passa depressa
31: bl      surv_update                 // personagem, tempo, fome...
    ldr     w9, [x28, #G_SLEEP]
    cbz     w9, 4f
    subs    w19, w19, #1
    b.ne    31b
4:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// calc_hover: usa o z-buffer para achar o ponto do mundo sob o mouse
calc_hover:
    str     wzr, [x28, #G_HOVOK]
    ldr     s0, [x28, #G_MX]
    fcvtzs  w0, s0
    ldr     s0, [x28, #G_MY]
    fcvtzs  w1, s0
    cmp     w0, #SCRW
    b.hs    9f
    cmp     w1, #SCRH
    b.hs    9f
    mov     w2, #SCRW
    madd    w2, w1, w2, w0
    LA      x3, zb
    ldrh    w2, [x3, w2, uxtw #1]       // profundidade = (u+v) em 1/64
    ldr     w3, [x28, #G_K]
    sub     w4, w0, #640
    mul     w4, w4, w3
    ldr     w5, [x28, #G_CX]
    add     w4, w4, w5                  // (u-v) em 1/64
    add     w5, w2, w4
    asr     w5, w5, #1                  // u
    sub     w6, w2, w4
    asr     w6, w6, #1                  // v
    MOVI32  w7, 32640                   // 510 * 64
    cmp     w5, w7
    b.hs    9f
    cmp     w6, w7
    b.hs    9f
    str     w5, [x28, #G_HOVU]
    str     w6, [x28, #G_HOVV]
    mov     w7, #1
    str     w7, [x28, #G_HOVOK]
9:  ret

// =====================================================================
//  Renderizacao do terreno (voxel space isometrico)
//
//  Para cada coluna da tela andamos no mundo de frente para tras.
//  Cada amostra projeta sua altura; se ficar acima de tudo o que ja foi
//  desenhado naquela coluna (y-buffer), pintamos o trecho e guardamos a
//  profundidade (z-buffer) para os objetos e para o mouse.
//
//  Como cada coluna e independente, a tela e dividida em 8 faixas de
//  160 colunas, desenhadas ao mesmo tempo por 8 threads (nucleos).
// =====================================================================
.equ NTHREADS, 8

// par_cols(x0 = funcao): roda funcao(w0 = col inicial, w1 = col final)
// em 8 threads, cada uma com uma faixa de 160 colunas da tela
    .globl par_cols
par_cols:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    LA      x9, parfunc
    str     x0, [x9]
    LA      x19, trange
    mov     w20, #0
1:  mov     w9, #(SCRW / NTHREADS)      // faixa i: colunas [160*i, 160*(i+1))
    mul     w10, w20, w9
    add     x11, x19, x20, lsl #3
    str     w10, [x11]
    add     w10, w10, w9
    str     w10, [x11, #4]
    add     w20, w20, #1
    cmp     w20, #NTHREADS
    b.lt    1b
    mov     w20, #1                     // threads 1..7
2:  LA      x21, tids
    add     x0, x21, x20, lsl #3
    mov     x1, #0
    LA      x2, par_thread
    add     x3, x19, x20, lsl #3
    bl      F(pthread_create)
    cbz     w0, 3f
    str     xzr, [x21, x20, lsl #3]     // nao criou: faz aqui mesmo
    add     x9, x19, x20, lsl #3
    ldr     w0, [x9]
    ldr     w1, [x9, #4]
    LA      x9, parfunc
    ldr     x9, [x9]
    blr     x9
3:  add     w20, w20, #1
    cmp     w20, #NTHREADS
    b.lt    2b
    ldr     w0, [x19]                   // a faixa 0 fica com esta thread
    ldr     w1, [x19, #4]
    LA      x9, parfunc
    ldr     x9, [x9]
    blr     x9
    mov     w20, #1                     // espera as outras terminarem
4:  LA      x21, tids
    ldr     x0, [x21, x20, lsl #3]
    cbz     x0, 5f
    mov     x1, #0
    bl      F(pthread_join)
5:  add     w20, w20, #1
    cmp     w20, #NTHREADS
    b.lt    4b
    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// par_thread(x0 = faixa): ponto de entrada de cada thread
par_thread:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x28, [sp, #16]
    LA      x28, G                      // cada thread tem seus registradores
    ldr     w1, [x0, #4]
    ldr     w0, [x0]
    LA      x9, parfunc
    ldr     x9, [x9]
    blr     x9
    ldr     x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    mov     x0, #0
    ret

draw_terrain:
    LA      x0, draw_cols
    b       par_cols

// draw_cols(w0 = primeira coluna, w1 = coluna final exclusiva)
draw_cols:
    stp     x29, x30, [sp, #-128]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     x27, [sp, #80]
    mov     w26, w0                     // sx
    str     w1, [sp, #108]
    ldr     w9, [x28, #G_K]
    str     w9, [sp, #88]
    ldr     w20, [x28, #G_Z256]
    ldr     w27, [x28, #G_EMAXZ]
    add     w10, w27, #360
    mul     w10, w10, w9
    ldr     w11, [x28, #G_CY]
    add     w10, w10, w11
    str     w10, [sp, #92]              // Y do mundo na linha de partida
    neg     w27, w27
    sub     w27, w27, #2                // yb final
    ldr     w9, [x28, #G_CONTOUR]
    str     w9, [sp, #104]
    ldr     w9, [x28, #G_FLOOD]         // enchente: nivel da agua
    str     w9, [sp, #112]
dt_col:
    ldr     w9, [sp, #88]
    sub     w10, w26, #640
    mul     w10, w10, w9
    ldr     w11, [x28, #G_CX]
    add     w10, w10, w11               // X (1/16 px) = u - v (1/64 cel)
    ldr     w11, [sp, #92]
    lsl     w12, w11, #10
    lsl     w13, w10, #9
    add     w21, w12, w13               // u (16.16)
    sub     w22, w12, w13               // v (16.16)
    lsl     w23, w9, #10                // passo
    ldr     w24, [x28, #G_EMAXZ]
    add     w24, w24, #SCRH             // yb
    mov     w25, #SCRH                  // y-buffer
    str     wzr, [sp, #100]
dt_row:
    asr     w9, w21, #16
    asr     w10, w22, #16
    cmp     w9, #511
    b.hs    dt_ocean
    cmp     w10, #511
    b.hs    dt_ocean
    ubfx    w11, w21, #8, #8
    ubfx    w12, w22, #8, #8
    add     w13, w9, w10, lsl #9
    LA      x14, elev
    add     x14, x14, w13, uxtw #1
    ldrsh   w0, [x14]
    ldrsh   w1, [x14, #2]
    ldrsh   w2, [x14, #1024]
    ldrsh   w3, [x14, #1026]
    sub     w1, w1, w0
    mul     w1, w1, w11
    add     w0, w0, w1, asr #8
    sub     w3, w3, w2
    mul     w3, w3, w11
    add     w2, w2, w3, asr #8
    sub     w2, w2, w0
    mul     w2, w2, w12
    add     w15, w0, w2, asr #8         // elevacao interpolada
    b       dt_proj
dt_ocean:
    mov     w15, #-2000                 // fora do mapa: oceano
dt_proj:
    ldr     w9, [sp, #112]              // abaixo do nivel da agua (mar ou
    subs    w10, w15, w9                // enchente): desenha agua na superficie
    csel    w0, w15, w9, ge             // altura: o chao, ou a superficie
    csel    w15, w15, w10, ge           // cor: o chao, ou a profundidade
    mul     w0, w0, w20
    asr     w0, w0, #12
    sub     w0, w24, w0                 // y na tela
    ldr     w1, [sp, #100]
    str     w15, [sp, #100]
    cmp     w0, w25
    b.ge    dt_next
    str     w0, [sp, #96]
    mov     w3, #0
    ldr     w2, [sp, #104]
    cbz     w2, 1f
    asr     w1, w1, #8
    asr     w2, w15, #8
    cmp     w1, w2
    cset    w3, ne
1:  mov     w0, w21
    mov     w1, w22
    mov     w2, w15
    bl      terrain_color
    ldr     w1, [sp, #96]
    cmp     w1, #0
    csel    w1, wzr, w1, lt
    add     w2, w21, w22
    asr     w2, w2, #10
    cmp     w2, #0
    csel    w2, wzr, w2, lt
    mov     w3, #65535
    cmp     w2, w3
    csel    w2, w3, w2, gt
    mov     w4, #SCRW
    madd    w5, w1, w4, w26
    LA      x6, fb
    LA      x7, zb
    sub     w8, w25, w1
2:  str     w0, [x6, w5, uxtw #2]
    strh    w2, [x7, w5, uxtw #1]
    add     w5, w5, w4
    subs    w8, w8, #1
    b.ne    2b
    mov     w25, w1
    cbz     w25, dt_coldone
dt_next:
    sub     w21, w21, w23
    sub     w22, w22, w23
    sub     w24, w24, #1
    cmp     w24, w27
    b.gt    dt_row
dt_coldone:
    add     w26, w26, #1
    ldr     w9, [sp, #108]
    cmp     w26, w9
    b.lt    dt_col
    ldr     x27, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #128
    ret

// terrain_color(w0 = u, w1 = v (16.16), w2 = elevacao, w3 = curva?)
// -> w0 = cor ARGB   (usa x0-x15)
terrain_color:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w10, w0
    mov     w11, w1
    mov     w12, w2
    mov     w13, w3
    cmp     w12, #0
    b.lt    tc_water
    // ruido fino (tabela 256x256) deixa as transicoes de cor naturais
    ubfx    w0, w10, #13, #8
    ubfx    w1, w11, #13, #8
    add     w0, w0, w1, lsl #8
    LA      x9, noisetab
    ldrb    w0, [x9, w0, uxtw]
    lsl     w7, w0, #4                  // bits 8..11 = ruido da umidade
    and     w0, w0, #31
    sub     w0, w0, #16
    add     w14, w12, w0
    asr     w1, w10, #16
    asr     w2, w11, #16
    add     w15, w1, w2, lsl #9         // celula
    LA      x9, overlay
    ldrb    w9, [x9, w15, uxtw]
    cbz     w9, 1f
    cmp     w9, #1
    b.ne    11f
    MOVI32  w0, 0xFF9A7A52              // caminho de terra batida
    ubfx    w1, w10, #14, #2
    cbnz    w1, tc_light
    MOVI32  w0, 0xFF8C6E48
    b       tc_light
11: ubfx    w1, w10, #13, #2            // terra arada: com sulcos
    cmp     w9, #3
    b.eq    12f
    MOVI32  w0, 0xFF8E6438              // seca
    cbnz    w1, tc_light
    MOVI32  w0, 0xFF6E4A28
    b       tc_light
12: MOVI32  w0, 0xFF5C3C20              // molhada (agua a ate 4 quadrados)
    cbnz    w1, tc_light
    MOVI32  w0, 0xFF46301A
    b       tc_light
1:  LA      x9, moist                   // umidade interpolada + ruido
    add     x9, x9, w15, uxtw
    ldrb    w3, [x9]
    ldrb    w4, [x9, #1]
    ldrb    w5, [x9, #512]
    ldrb    w6, [x9, #513]
    ubfx    w1, w10, #8, #8
    ubfx    w2, w11, #8, #8
    sub     w4, w4, w3
    mul     w4, w4, w1
    add     w3, w3, w4, asr #8
    sub     w6, w6, w5
    mul     w6, w6, w1
    add     w5, w5, w6, asr #8
    sub     w5, w5, w3
    mul     w5, w5, w2
    add     w3, w3, w5, asr #8
    ubfx    w9, w7, #8, #4
    add     w9, w9, w3
    sub     w9, w9, #8
    cmp     w14, #E_SAND
    b.ge    2f
    MOVI32  w0, 0xFFDCC88A              // praia
    b       tc_light
2:  cmp     w14, #E_GRASS
    b.ge    3f
    cmp     w9, #150
    b.ge    tc_forest
    cmp     w9, #95
    b.ge    21f
    MOVI32  w0, 0xFF8DAE4E              // campo seco
    b       tc_light
21: MOVI32  w0, 0xFF62A83E              // campo
    b       tc_light
3:  cmp     w14, #E_HILL
    b.ge    4f
    cmp     w9, #140
    b.ge    tc_forest
    MOVI32  w0, 0xFF7E9A4A              // colinas
    b       tc_light
4:  mov     w9, #E_ROCK
    cmp     w14, w9
    b.ge    5f
    MOVI32  w0, 0xFF8E877E              // rocha
    b       tc_light
5:  MOVI32  w0, 0xFFEEF2F6              // neve
    b       tc_light
tc_forest:
    MOVI32  w0, 0xFF3F7A2E              // chao de floresta
tc_light:
    ubfx    w1, w10, #8, #8
    ubfx    w2, w11, #8, #8
    LA      x9, light
    add     x9, x9, w15, uxtw
    ldrb    w3, [x9]
    ldrb    w4, [x9, #1]
    ldrb    w5, [x9, #512]
    ldrb    w6, [x9, #513]
    sub     w4, w4, w3
    mul     w4, w4, w1
    add     w3, w3, w4, asr #8
    sub     w6, w6, w5
    mul     w6, w6, w1
    add     w5, w5, w6, asr #8
    sub     w5, w5, w3
    mul     w5, w5, w2
    add     w3, w3, w5, asr #8          // luz interpolada (128 = normal)
    cbz     w13, 6f
    sub     w3, w3, w3, lsr #2          // curva de nivel: 25% mais escuro
6:  mov     w7, #255
    ubfx    w4, w0, #16, #8
    mul     w4, w4, w3
    lsr     w4, w4, #7
    cmp     w4, w7
    csel    w4, w4, w7, lo
    ubfx    w5, w0, #8, #8
    mul     w5, w5, w3
    lsr     w5, w5, #7
    cmp     w5, w7
    csel    w5, w5, w7, lo
    and     w6, w0, #255
    mul     w6, w6, w3
    lsr     w6, w6, #7
    cmp     w6, w7
    csel    w6, w6, w7, lo
    orr     w0, w6, w5, lsl #8
    orr     w0, w0, w4, lsl #16
    orr     w0, w0, #0xFF000000
    // zonas de trabalho (pintando, ou com o painel de pessoas aberto):
    // cor de cada tipo; o retangulo sendo arrastado aparece mais forte
    ldr     w9, [x28, #G_ZONESHOW]
    cbz     w9, 69f
    LA      x9, zonegrid
    ldrb    w1, [x9, w15, uxtw]
    mov     w4, #110
    ldr     w9, [x28, #G_ZDRAG]
    cbz     w9, 62f
    asr     w2, w10, #16
    asr     w3, w11, #16
    ldr     w5, [x28, #G_ZAU]
    ldr     w6, [x28, #G_ZBU]
    cmp     w5, w6
    csel    w7, w5, w6, lt
    csel    w6, w6, w5, lt
    cmp     w2, w7
    b.lt    62f
    cmp     w2, w6
    b.gt    62f
    ldr     w5, [x28, #G_ZAV]
    ldr     w6, [x28, #G_ZBV]
    cmp     w5, w6
    csel    w7, w5, w6, lt
    csel    w6, w6, w5, lt
    cmp     w3, w7
    b.lt    62f
    cmp     w3, w6
    b.gt    62f
    ldr     w1, [x28, #G_ZONEMODE]
    mov     w4, #170
62: cbz     w1, 69f
    LA      x9, zonecolors
    ldr     w9, [x9, w1, uxtw #2]
    ubfx    w5, w0, #16, #8
    ubfx    w6, w9, #16, #8
    sub     w6, w6, w5
    mul     w6, w6, w4
    add     w5, w5, w6, asr #8
    ubfx    w2, w0, #8, #8
    ubfx    w6, w9, #8, #8
    sub     w6, w6, w2
    mul     w6, w6, w4
    add     w2, w2, w6, asr #8
    and     w3, w0, #255
    and     w6, w9, #255
    sub     w6, w6, w3
    mul     w6, w6, w4
    add     w3, w3, w6, asr #8
    orr     w0, w3, w2, lsl #8
    orr     w0, w0, w5, lsl #16
    orr     w0, w0, #0xFF000000
69:
    // grade: linha clara na borda de cada quadrado perto do personagem
    // (mais forte no alcance; some aos poucos ate 20 celulas)
    ldr     w9, [x28, #G_GRIDSHOW]
    cbz     w9, 79f
    ldr     w9, [x28, #G_GRIDW]
    and     w1, w10, #0xFFFF
    cmp     w1, w9
    b.lo    71f
    and     w1, w11, #0xFFFF
    cmp     w1, w9
    b.hs    79f
71: asr     w1, w10, #16
    ldr     w2, [x28, #G_GRIDPU]
    sub     w1, w1, w2
    asr     w2, w11, #16
    ldr     w3, [x28, #G_GRIDPV]
    sub     w2, w2, w3
    mul     w1, w1, w1
    madd    w1, w2, w2, w1              // distancia^2
    mov     w2, #GRIDR2
    cmp     w1, w2
    b.hs    79f
    ldr     w3, [x28, #G_GRIDREACH]
    mov     w4, #110
    cmp     w1, w3
    b.le    72f
    sub     w4, w2, w1                  // fora do alcance: 70 -> 0
    mov     w5, #70
    mul     w4, w4, w5
    udiv    w4, w4, w2
72: mov     w7, #255                    // mistura com branco (w4 / 256)
    ubfx    w5, w0, #16, #8
    sub     w6, w7, w5
    mul     w6, w6, w4
    add     w5, w5, w6, lsr #8
    ubfx    w1, w0, #8, #8
    sub     w6, w7, w1
    mul     w6, w6, w4
    add     w1, w1, w6, lsr #8
    and     w2, w0, #255
    sub     w6, w7, w2
    mul     w6, w6, w4
    add     w2, w2, w6, lsr #8
    orr     w0, w2, w1, lsl #8
    orr     w0, w0, w5, lsl #16
    orr     w0, w0, #0xFF000000
79: ldp     x29, x30, [sp], #16
    ret

tc_water:
    neg     w12, w12                    // profundidade
    cmp     w12, #20
    b.ge    1f
    MOVI32  w5, 0xFF8CC3E4              // espuma na beira
    b       3f
1:  lsr     w14, w12, #2
    mov     w9, #256
    cmp     w14, w9
    csel    w14, w14, w9, lo
    mov     w1, #-40                    // raso (3D86C6) -> fundo (15386A)
    mul     w1, w1, w14
    mov     w2, #0x3D
    add     w2, w2, w1, asr #8
    mov     w1, #-78
    mul     w1, w1, w14
    mov     w3, #0x86
    add     w3, w3, w1, asr #8
    mov     w1, #-92
    mul     w1, w1, w14
    mov     w4, #0xC6
    add     w4, w4, w1, asr #8
    orr     w5, w4, w3, lsl #8
    orr     w5, w5, w2, lsl #16
    orr     w5, w5, #0xFF000000
3:  ubfx    w0, w10, #15, #8            // brilhos que piscam na agua
    asr     w1, w11, #15
    ldr     w2, [x28, #G_FRAME]
    lsr     w2, w2, #3
    mov     w3, #7
    madd    w1, w2, w3, w1
    and     w1, w1, #255
    add     w0, w0, w1, lsl #8
    LA      x9, noisetab
    ldrb    w0, [x9, w0, uxtw]
    cbnz    w0, 4f
    MOVI32  w0, 0x00202020
    add     w5, w5, w0
4:  mov     w0, w5
    ldp     x29, x30, [sp], #16
    ret

// =====================================================================
//  Objetos (sprites com teste de profundidade)
// =====================================================================
draw_objects:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    str     x25, [sp, #64]
    ldr     w19, [x28, #G_NOBJ]
    LA      x20, objs
    ldr     w21, [x28, #G_Z256]
    ldr     w22, [x28, #G_CX]
    ldr     w23, [x28, #G_CY]
    lsr     w24, w21, #8
    mov     w9, #1
    cmp     w24, #1
    csel    w24, w24, w9, ge            // escala dos sprites
    mov     w25, #0
do_loop:
    cmp     w25, w19
    b.ge    do_done
    add     x9, x20, w25, uxtw #3
    ldrh    w10, [x9]
    ldrh    w11, [x9, #2]
    ldrsh   w12, [x9, #4]
    ldrb    w13, [x9, #6]
    ldrb    w14, [x9, #7]
    ldr     w15, [x28, #G_STATE]
    cbz     w15, 2f                     // titulo: sem neblina
    lsr     w15, w10, #6                // celula do objeto
    lsr     w16, w11, #6
    add     w15, w15, w16, lsl #9
    LA      x16, vis
    ldrb    w15, [x16, w15, uxtw]
    LA      x16, memtype
    cmp     w15, #VIS_MIN
    b.lo    1f
    strb    w13, [x16, x25]             // a vista: lembra como esta agora
    b       2f
1:  ldrb    w13, [x16, x25]             // na neblina: desenha o que lembra
2:  cmp     w13, #(O_LAST + 1)          // removido ou nunca visto
    b.hs    do_skip
    sub     w0, w10, w11
    sub     w0, w0, w22
    mul     w0, w0, w21
    asr     w0, w0, #12
    add     w1, w0, #640                // x na tela
    add     w0, w10, w11
    lsr     w0, w0, #1
    sub     w0, w0, w12
    sub     w0, w0, w23
    mul     w0, w0, w21
    asr     w0, w0, #12
    add     w2, w0, #360                // y na tela (base)
    cmn     w1, #64
    b.lt    do_skip
    mov     w9, #1344
    cmp     w1, w9
    b.gt    do_skip
    cmp     w2, #0
    b.lt    do_skip
    mov     w9, #800
    cmp     w2, w9
    b.gt    do_skip
    add     w4, w10, w11                // profundidade
    LA      x9, objsprite               // sprite do tipo de objeto
    ldrb    w15, [x9, x13]
    cmp     w13, #O_CROP                // trigo plantado: estagio 0..3
    b.ne    60f
    lsr     w16, w14, #6
    mov     w9, #3
    cmp     w16, #3
    csel    w16, w16, w9, lo
    add     w15, w15, w16
    b       63f
60: cmp     w13, #O_FENCE               // cerca: trilhos para os vizinhos
    b.eq    61f
    cmp     w13, #O_GATE
    b.ne    63f
61: lsr     w16, w10, #6
    lsr     w9, w11, #6
    add     w16, w16, w9, lsl #9
    LA      x9, fencegrid
    add     x9, x9, w16, uxtw
    cmp     w13, #O_GATE
    b.eq    62f
    ldrb    w16, [x9, #1]               // vizinho em +u
    cmp     w16, #0
    cinc    w15, w15, ne
    ldrb    w16, [x9, #512]             // vizinho em +v
    cbz     w16, 63f
    add     w15, w15, #2
    b       63f
62: ldurb   w16, [x9, #-1]              // portao: na fileira de u ou de v?
    ldrb    w9, [x9, #1]
    orr     w16, w16, w9
    cmp     w16, #0
    cinc    w15, w15, eq
63: LA      x0, sprites
    add     x0, x0, x15, lsl #7
    mov     w3, w24
    mov     w5, w14
    bl      blit
do_skip:
    add     w25, w25, #1
    b       do_loop
do_done:
    ldr     x25, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// blit(x0 = sprite, w1 = x, w2 = y base, w3 = escala, w4 = profundidade,
//      w5 = variante)   folha; usa x0-x17
    .globl blit
blit:
    sub     sp, sp, #16
    ldrb    w6, [x0]                    // largura
    ldrb    w7, [x0, #1]                // altura
    str     w7, [sp]
    ldrb    w8, [x0, #2]                // ancora x
    add     x0, x0, #4
    mul     w9, w8, w3
    sub     w1, w1, w9
    lsr     w9, w3, #1
    sub     w1, w1, w9                  // esquerda
    mul     w9, w7, w3
    sub     w2, w2, w9                  // topo
    LA      x16, fb
    LA      x17, zb
    mov     w10, #0
b_row:
    mov     w11, #0
b_col:
    ldrb    w12, [x0], #1
    cbz     w12, b_next
    cmp     w12, #8
    b.lo    1f
    cmp     w12, #9
    b.hi    2f
    and     w13, w5, #3                 // telhado: cor da variante
    LA      x14, roofc
    add     x14, x14, w13, uxtw #3
    sub     w15, w12, #8
    ldr     w8, [x14, w15, uxtw #2]
    b       3f
2:  cmp     w12, #15
    b.ne    1f
    and     w13, w10, #7                // janela acesa ou apagada
    lsr     w13, w5, w13
    tst     w13, #1
    MOVI32  w8, 0xFF3C4656
    MOVI32  w13, 0xFFFFE38A
    csel    w8, w13, w8, ne
    b       3f
1:  LA      x14, palette
    ldr     w8, [x14, w12, uxtw #2]
3:  madd    w13, w10, w3, w2            // y do bloco
    mov     w14, #0
4:  add     w15, w13, w14
    cmp     w15, #SCRH
    b.hs    7f
    mov     w9, #0
5:  madd    w12, w11, w3, w1
    add     w12, w12, w9
    cmp     w12, #SCRW
    b.hs    6f
    add     w12, w12, w15, lsl #10
    add     w12, w12, w15, lsl #8       // y*1280 + x
    ldrh    w7, [x17, w12, uxtw #1]
    sub     w7, w7, w4
    cmp     w7, #16
    b.gt    6f                          // terreno na frente
    str     w8, [x16, w12, uxtw #2]
    strh    w4, [x17, w12, uxtw #1]
6:  add     w9, w9, #1
    cmp     w9, w3
    b.lt    5b
7:  add     w14, w14, #1
    cmp     w14, w3
    b.lt    4b
b_next:
    add     w11, w11, #1
    cmp     w11, w6
    b.lt    b_col
    add     w10, w10, #1
    ldr     w7, [sp]
    cmp     w10, w7
    b.lt    b_row
    add     sp, sp, #16
    ret

// =====================================================================
//  Composicao final + interface
// =====================================================================
draw_all:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      grid_prep                   // grade no chao? (cercas.S)
    bl      draw_terrain
    bl      draw_objects
    ldr     w9, [x28, #G_STATE]
    cbz     w9, 1f
    bl      surv_draw                   // personagem e fogueiras
1:  bl      calc_hover
    ldr     w9, [x28, #G_STATE]
    cbz     w9, 2f
    bl      surv_light                  // escuridao da noite
    bl      weather_tint                // cor do clima (so no mundo)
    bl      weather_fx                  // chuva, neve, granizo
    bl      fence_overlay               // grade e previa das cercas
2:  ldr     x0, [x28, #G_TEX]
    mov     x1, #0
    LA      x2, fb
    mov     w3, #(SCRW * 4)
    bl      F(SDL_UpdateTexture)
    mov     w0, #0
    mov     w1, #0
    mov     w2, #0
    mov     w3, #255
    bl      setcolor
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderClear)
    ldr     x0, [x28, #G_REN]
    ldr     x1, [x28, #G_TEX]
    mov     x2, #0
    mov     x3, #0
    bl      F(SDL_RenderTexture)
    ldr     w9, [x28, #G_STATE]
    cbnz    w9, 3f
    bl      draw_title
    b       4f
3:  bl      draw_ui
4:  mov     w0, #1
    bl      setscale
    ldp     x29, x30, [sp], #16
    ret

    .globl setcolor
setcolor:
    mov     w4, w3
    mov     w3, w2
    mov     w2, w1
    mov     w1, w0
    ldr     x0, [x28, #G_REN]
    b       F(SDL_SetRenderDrawColor)

    .globl setscale
setscale:
    scvtf   s0, w0
    fmov    s1, s0
    ldr     x0, [x28, #G_REN]
    b       F(SDL_SetRenderScale)

    .globl fillrect
fillrect:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    scvtf   s0, w0
    str     s0, [sp, #16]
    scvtf   s0, w1
    str     s0, [sp, #20]
    scvtf   s0, w2
    str     s0, [sp, #24]
    scvtf   s0, w3
    str     s0, [sp, #28]
    ldr     x0, [x28, #G_REN]
    add     x1, sp, #16
    bl      F(SDL_RenderFillRect)
    ldp     x29, x30, [sp], #32
    ret

    .globl text
text:
    scvtf   s0, w0
    scvtf   s1, w1
    mov     x1, x2
    ldr     x0, [x28, #G_REN]
    b       F(SDL_RenderDebugText)

    .globl text_center
text_center:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     x21, x2
    mov     w22, w3
    mov     x0, x21
    bl      mystrlen
    lsl     w0, w0, #3
    sub     w0, w19, w0
    asr     w0, w0, #1
    add     w0, w0, w22
    add     w1, w20, w22
    mov     x2, x21
    bl      text
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

draw_title:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w0, #2
    bl      setscale
    mov     w0, #0
    mov     w1, #0
    mov     w2, #10
    mov     w3, #110
    bl      setcolor
    mov     w0, #0
    mov     w1, #0
    mov     w2, #640
    mov     w3, #360
    bl      fillrect
    mov     w0, #8
    bl      setscale
    mov     w0, #30
    mov     w1, #20
    mov     w2, #10
    mov     w3, #255
    bl      setcolor
    mov     w0, #160
    mov     w1, #20
    LA      x2, s_title
    mov     w3, #1
    bl      text_center
    mov     w0, #255
    mov     w1, #200
    mov     w2, #60
    mov     w3, #255
    bl      setcolor
    mov     w0, #160
    mov     w1, #20
    LA      x2, s_title
    mov     w3, #0
    bl      text_center
    mov     w0, #2
    bl      setscale
    mov     w0, #220
    mov     w1, #230
    mov     w2, #240
    mov     w3, #255
    bl      setcolor
    mov     w0, #640
    mov     w1, #120
    LA      x2, s_sub
    mov     w3, #0
    bl      text_center
    LA      x0, txt
    LA      x1, s_world
    bl      strcat_cur
    ldr     w1, [x28, #G_SEED]
    bl      numcat
    mov     w0, #150
    mov     w1, #180
    mov     w2, #210
    mov     w3, #255
    bl      setcolor
    mov     w0, #640
    mov     w1, #140
    LA      x2, txt
    mov     w3, #0
    bl      text_center
    ldr     w9, [x28, #G_FRAME]
    tbnz    w9, #5, 1f
    mov     w0, #255
    mov     w1, #255
    mov     w2, #255
    mov     w3, #255
    bl      setcolor
    mov     w0, #640
    mov     w1, #250
    LA      x2, s_enter
    mov     w3, #0
    bl      text_center
1:  mov     w0, #170
    mov     w1, #170
    mov     w2, #170
    mov     w3, #255
    bl      setcolor
    mov     w0, #640
    mov     w1, #270
    LA      x2, s_title_help
    mov     w3, #0
    bl      text_center
    mov     w0, #110
    mov     w1, #120
    mov     w2, #130
    mov     w3, #255
    bl      setcolor
    mov     w0, #640
    mov     w1, #340
    LA      x2, s_credit
    mov     w3, #0
    bl      text_center
    ldp     x29, x30, [sp], #16
    ret

draw_ui:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w0, #2
    bl      setscale                    // espaco de texto 640x360
    mov     w0, #0
    mov     w1, #0
    mov     w2, #0
    mov     w3, #180
    bl      setcolor
    mov     w0, #0
    mov     w1, #0
    mov     w2, #640
    mov     w3, #12
    bl      fillrect
    LA      x0, txt
    LA      x1, s_world
    bl      strcat_cur
    ldr     w1, [x28, #G_SEED]
    bl      numcat
    bl      surv_status                 // dia e hora
    mov     w0, #255
    mov     w1, #255
    mov     w2, #255
    mov     w3, #255
    bl      setcolor
    mov     w0, #4
    mov     w1, #2
    LA      x2, txt
    bl      text
    bl      surv_ui                     // inventario, barras, dicas
    ldp     x29, x30, [sp], #16
    ret

// =====================================================================
//  Dados
// =====================================================================
    .data
    .p2align 4
    .globl G
G:  .space GSIZE

// 16 direcoes (cos, sin) * 64
    .p2align 2
dirtab:
    .hword 64, 0,    59, 24,   45, 45,   24, 59
    .hword 0, 64,   -24, 59,  -45, 45,  -59, 24
    .hword -64, 0,  -59, -24, -45, -45, -24, -59
    .hword 0, -64,   24, -59,  45, -45,  59, -24

// paleta dos sprites (indice 0 = transparente; 8, 9 e 15 sao especiais)
    .p2align 2
    .globl palette
palette:
    .word 0, 0xFF5B3A1E, 0xFF2E6B2E, 0xFF4E9A45          //  0-3  tronco, folhas
    .word 0xFF1F5530, 0xFF2F7440, 0xFFE8DDC6, 0xFFBFAF92  //  4-7  pinheiro
    .word 0, 0, 0xFF4A3524, 0xFF9FC4E0                    //  8-11 (8, 9 especiais)
    .word 0xFFA9B6C6, 0xFF7D8999, 0xFF4F5866, 0           // 12-15 (15 especial)
    .word 0xFF3CE04A, 0xFFE8382E, 0xFF2A2A2E, 0           // 16-19 escuro
    .word 0xFFA7A39B, 0xFF85817A, 0xFF5F5C57, 0xFFD8263A  // 20-23 pedra, fruta
    .word 0xFFFFE066, 0xFFFF8A1F, 0xFFD8401A, 0xFFE8B48A  // 24-27 fogo, pele
    .word 0xFF2F6FB5, 0xFF4A3A2A, 0xFF3A2A1A, 0xFF7A4A24  // 28-31 roupa, cabelo, lenha
    .word 0xFFCDEBF7, 0xFF6E7C86, 0xFF4A555D, 0xFFB07A48  // 32-35 espuma, tubarao, cervo
    .word 0xFF8C5A30, 0xFFF2F2F2, 0xFFE05030, 0xFF6A6A70  // 36-39 couro, branco, caranguejo, lobo
    .word 0xFFD8B040, 0xFFA8862A, 0xFF9CC04A, 0xFFC8904A  // 40-43 trigo, trigo escuro, broto, pao
    .word 0xFFD07A3A, 0xFF8A4A2A, 0xFFA0503C, 0xFFFFF0A0  // 44-47 minerio, ferrugem, tijolo, luz

roofc:
    .word 0xFFB5443A, 0xFF8C3029
    .word 0xFF8A5A3A, 0xFF6A4228
    .word 0xFF5C6E86, 0xFF45546A
    .word 0xFFC8693A, 0xFF9C4E2A

// sprites: largura, altura, ancora, 0, pixels (128 bytes por sprite)
    .p2align 7
    .globl sprites
sprites:
// 0: arvore
    .byte 7, 8, 3, 0
    .byte 0,0,3,3,2,0,0
    .byte 0,3,3,2,2,2,0
    .byte 3,3,2,2,2,2,2
    .byte 3,2,2,2,2,2,2
    .byte 0,3,2,2,2,2,0
    .byte 0,0,2,2,2,0,0
    .byte 0,0,0,1,0,0,0
    .byte 0,0,0,1,0,0,0
    .p2align 7
// 1: pinheiro
    .byte 5, 9, 2, 0
    .byte 0,0,5,0,0
    .byte 0,0,5,4,0
    .byte 0,5,5,4,0
    .byte 0,5,4,4,0
    .byte 5,5,4,4,4
    .byte 0,5,4,4,0
    .byte 5,5,4,4,4
    .byte 0,0,1,0,0
    .byte 0,0,1,0,0
    .p2align 7
// 2: pedra
    .byte 8, 6, 4, 0
    .byte 0,0,20,20,20,0,0,0
    .byte 0,20,20,21,21,21,0,0
    .byte 20,20,21,21,21,22,22,0
    .byte 20,21,21,21,22,22,22,22
    .byte 21,21,21,22,22,22,22,22
    .byte 0,22,22,22,22,22,22,0
    .p2align 7
// 3: arbusto com frutas
    .byte 7, 6, 3, 0
    .byte 0,0,3,3,3,0,0
    .byte 0,3,23,2,3,2,0
    .byte 3,2,2,2,23,2,2
    .byte 2,23,2,2,2,2,23
    .byte 2,2,2,23,2,2,2
    .byte 0,2,2,2,2,2,0
    .p2align 7
// 4: arbusto sem frutas
    .byte 7, 6, 3, 0
    .byte 0,0,3,3,3,0,0
    .byte 0,3,3,2,3,2,0
    .byte 3,2,2,2,2,2,2
    .byte 2,2,2,2,2,2,2
    .byte 2,2,2,2,2,2,2
    .byte 0,2,2,2,2,2,0
    .p2align 7
// 5: fogueira (quadro 1)
    .byte 7, 8, 3, 0
    .byte 0,0,0,24,0,0,0
    .byte 0,0,24,25,0,0,0
    .byte 0,0,25,24,25,0,0
    .byte 0,25,24,24,25,26,0
    .byte 0,26,25,24,25,26,0
    .byte 0,0,26,25,26,0,0
    .byte 31,31,22,31,22,31,31
    .byte 0,22,31,31,31,22,0
    .p2align 7
// 6: fogueira (quadro 2)
    .byte 7, 8, 3, 0
    .byte 0,0,0,0,24,0,0
    .byte 0,0,0,25,24,0,0
    .byte 0,0,25,24,25,0,0
    .byte 0,26,25,24,24,25,0
    .byte 0,26,25,24,25,26,0
    .byte 0,0,26,25,26,0,0
    .byte 31,31,22,31,22,31,31
    .byte 0,22,31,31,31,22,0
    .p2align 7
// 7: personagem parado / passo 1
    .byte 5, 9, 2, 0
    .byte 0,30,30,30,0
    .byte 0,27,27,27,0
    .byte 0,28,28,28,0
    .byte 28,28,28,28,28
    .byte 27,28,28,28,27
    .byte 0,29,29,29,0
    .byte 0,29,0,29,0
    .byte 0,29,0,29,0
    .byte 0,18,0,18,0
    .p2align 7
// 8: personagem passo 2
    .byte 5, 9, 2, 0
    .byte 0,30,30,30,0
    .byte 0,27,27,27,0
    .byte 0,28,28,28,0
    .byte 28,28,28,28,28
    .byte 27,28,28,28,27
    .byte 0,29,29,29,0
    .byte 0,29,0,29,0
    .byte 29,0,0,0,29
    .byte 18,0,0,0,18
    .p2align 7
// 9: nadando (quadro 1)
    .byte 5, 5, 2, 0
    .byte 0,30,30,30,0
    .byte 0,27,27,27,0
    .byte 27,28,28,28,0
    .byte 32,32,32,32,32
    .byte 0,32,0,32,0
    .p2align 7
// 10: nadando (quadro 2)
    .byte 5, 5, 2, 0
    .byte 0,30,30,30,0
    .byte 0,27,27,27,0
    .byte 0,28,28,28,27
    .byte 32,32,32,32,32
    .byte 32,0,32,0,32
    .p2align 7
// 11: barbatana do tubarao (em volta de quem nada no mar aberto)
    .byte 5, 5, 2, 0
    .byte 0,0,33,0,0
    .byte 0,33,33,0,0
    .byte 0,33,33,34,0
    .byte 33,33,34,34,0
    .byte 32,32,32,32,32
    .p2align 7
// 12: toras largadas no chao (tambem e o icone da madeira na mochila)
    .byte 9, 6, 4, 0
    .byte 0,0,6,31,31,31,31,0,0
    .byte 0,0,7,1,1,1,1,0,0
    .byte 0,6,31,31,31,31,31,31,0
    .byte 0,7,1,1,1,1,1,1,0
    .byte 6,31,31,31,31,31,31,31,31
    .byte 7,1,1,1,1,1,1,1,1
    .p2align 7
// 13: pedras largadas
    .byte 8, 5, 4, 0
    .byte 0,0,0,20,20,0,0,0
    .byte 0,20,20,21,21,20,0,0
    .byte 20,21,21,22,20,21,21,0
    .byte 21,21,22,22,21,21,22,22
    .byte 0,22,22,0,22,22,22,0
    .p2align 7
// 14: frutas largadas
    .byte 6, 5, 3, 0
    .byte 0,0,0,3,3,0
    .byte 0,23,23,3,23,0
    .byte 23,32,23,23,32,23
    .byte 23,23,23,23,23,23
    .byte 0,23,23,0,23,0
    .p2align 7
// 15: machado
    .byte 7, 7, 3, 0
    .byte 0,0,0,0,13,13,0
    .byte 0,0,0,13,12,12,13
    .byte 0,0,0,31,13,12,13
    .byte 0,0,31,0,0,13,0
    .byte 0,31,0,0,0,0,0
    .byte 31,0,0,0,0,0,0
    .byte 1,0,0,0,0,0,0
    .p2align 7
// 16: picareta
    .byte 7, 6, 3, 0
    .byte 0,13,13,13,13,13,0
    .byte 13,12,0,31,0,12,13
    .byte 13,0,0,31,0,0,13
    .byte 0,0,0,31,0,0,0
    .byte 0,0,0,31,0,0,0
    .byte 0,0,0,1,0,0,0
    .p2align 7
// 17: tocha (na mochila e na mao do personagem)
    .byte 3, 7, 1, 0
    .byte 0,24,0
    .byte 25,24,25
    .byte 26,25,26
    .byte 0,31,0
    .byte 0,31,0
    .byte 0,31,0
    .byte 0,1,0
    .p2align 7
// 18: frutas assadas (no espeto)
    .byte 9, 3, 4, 0
    .byte 0,26,26,0,26,26,0,26,26
    .byte 31,25,26,31,25,26,31,25,26
    .byte 0,26,10,0,26,10,0,26,10
    .p2align 7
// 19: cesto
    .byte 7, 5, 3, 0
    .byte 0,0,31,31,31,0,0
    .byte 0,31,0,0,0,31,0
    .byte 31,1,31,1,31,1,31
    .byte 1,31,1,31,1,31,1
    .byte 0,1,31,1,31,1,0
    .p2align 7
// 20: bau
    .byte 8, 6, 4, 0
    .byte 0,10,10,10,10,10,10,0
    .byte 10,31,31,31,31,31,31,10
    .byte 1,1,1,24,24,1,1,1
    .byte 31,31,31,24,24,31,31,31
    .byte 31,31,31,31,31,31,31,31
    .byte 1,1,1,1,1,1,1,1
    .p2align 7
// 21: abrigo (cabana; 18 x 14 = 252 pixels: ocupa as vagas 21 e 22)
// a porta tem 6 x 10 pixels: o personagem (5 x 9) cabe de pe
    .byte 18, 14, 9, 0
    .byte 0,0,0,0,0,0,0,10,31,31,10,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,10,31,31,10,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,10,1,1,1,1,10,0,0,0,0,0,0
    .byte 0,0,0,0,0,10,36,36,36,36,36,36,10,0,0,0,0,0
    .byte 0,0,0,0,10,36,36,18,18,18,18,36,36,10,0,0,0,0
    .byte 0,0,0,10,1,36,18,18,18,18,18,18,36,1,10,0,0,0
    .byte 0,0,0,10,31,36,18,18,18,18,18,18,36,31,10,0,0,0
    .byte 0,0,10,31,31,36,18,18,18,18,18,18,36,31,31,10,0,0
    .byte 0,10,1,1,1,36,18,18,18,18,18,18,36,1,1,1,10,0
    .byte 10,31,31,31,31,36,18,18,18,18,18,18,36,31,31,31,31,10
    .byte 10,31,31,31,31,36,18,18,18,18,18,18,36,31,31,31,31,10
    .byte 10,1,1,1,1,36,18,18,18,18,18,18,36,1,1,1,1,10
    .byte 10,31,31,31,31,36,18,18,18,18,18,18,36,31,31,31,31,10
    .byte 10,1,1,1,1,36,18,18,18,18,18,18,36,1,1,1,1,10
    .p2align 7
// 23: arco
    .byte 4, 8, 2, 0
    .byte 0,0,31,6
    .byte 0,31,0,6
    .byte 31,0,0,6
    .byte 31,0,0,6
    .byte 31,0,0,6
    .byte 31,0,0,6
    .byte 0,31,0,6
    .byte 0,0,31,6
    .p2align 7
// 24: flechas
    .byte 8, 7, 4, 0
    .byte 6,0,0,0,0,0,21,0
    .byte 0,6,31,31,31,31,21,21
    .byte 6,0,0,0,0,0,21,0
    .byte 0,0,0,0,0,0,0,0
    .byte 6,0,0,0,0,0,21,0
    .byte 0,6,31,31,31,31,21,21
    .byte 6,0,0,0,0,0,21,0
    .p2align 7
// 25: carne crua
    .byte 6, 5, 3, 0
    .byte 0,23,23,23,0,0
    .byte 23,17,17,23,23,0
    .byte 23,17,17,17,23,6
    .byte 0,23,23,23,6,6
    .byte 0,0,0,0,6,0
    .p2align 7
// 26: carne assada
    .byte 6, 5, 3, 0
    .byte 0,36,36,36,0,0
    .byte 36,35,35,36,36,0
    .byte 36,35,25,35,36,6
    .byte 0,36,36,36,6,6
    .byte 0,0,0,0,6,0
    .p2align 7
// 27: couro
    .byte 6, 5, 3, 0
    .byte 35,0,35,35,0,35
    .byte 0,35,35,35,35,0
    .byte 0,35,36,35,35,0
    .byte 0,35,35,35,35,0
    .byte 35,0,35,35,0,35
    .p2align 7
// 28: roupa de couro
    .byte 7, 7, 3, 0
    .byte 0,35,35,0,35,35,0
    .byte 35,35,36,35,36,35,35
    .byte 35,0,35,36,35,0,35
    .byte 35,0,35,36,35,0,35
    .byte 0,0,35,36,35,0,0
    .byte 0,0,35,36,35,0,0
    .byte 0,0,36,36,36,0,0
    .p2align 7
// 29: mochila de couro
    .byte 6, 7, 3, 0
    .byte 0,36,36,36,36,0
    .byte 0,36,0,0,36,0
    .byte 35,35,35,35,35,35
    .byte 35,36,36,36,36,35
    .byte 35,35,24,24,35,35
    .byte 35,35,35,35,35,35
    .byte 36,36,36,36,36,36
    .p2align 7
// 30: coelho A
    .byte 6, 5, 3, 0
    .byte 0,0,0,20,0,20
    .byte 0,0,0,20,20,20
    .byte 37,20,20,20,18,20
    .byte 20,20,20,20,20,0
    .byte 0,21,0,0,21,0
    .p2align 7
// 31: coelho B
    .byte 6, 5, 3, 0
    .byte 0,0,0,20,0,20
    .byte 0,0,0,20,20,20
    .byte 37,20,20,20,18,20
    .byte 20,20,20,20,20,0
    .byte 21,0,0,21,0,0
    .p2align 7
// 32: cervo A
    .byte 9, 8, 4, 0
    .byte 0,0,0,0,0,0,36,0,36
    .byte 0,0,0,0,0,0,0,36,0
    .byte 0,0,0,0,0,0,35,35,0
    .byte 0,0,0,0,0,0,35,18,35
    .byte 0,35,35,35,35,35,35,0,0
    .byte 6,35,35,35,35,35,35,0,0
    .byte 0,36,0,36,0,36,0,36,0
    .byte 0,36,0,36,0,36,0,36,0
    .p2align 7
// 33: cervo B
    .byte 9, 8, 4, 0
    .byte 0,0,0,0,0,0,36,0,36
    .byte 0,0,0,0,0,0,0,36,0
    .byte 0,0,0,0,0,0,35,35,0
    .byte 0,0,0,0,0,0,35,18,35
    .byte 0,35,35,35,35,35,35,0,0
    .byte 6,35,35,35,35,35,35,0,0
    .byte 0,0,36,0,36,0,36,0,0
    .byte 0,36,0,0,0,0,0,36,0
    .p2align 7
// 34: cabra A
    .byte 8, 7, 4, 0
    .byte 0,0,0,0,0,0,21,21
    .byte 0,0,0,0,0,37,37,21
    .byte 0,0,0,0,0,37,18,37
    .byte 37,37,37,37,37,37,37,0
    .byte 37,37,37,37,37,37,0,0
    .byte 0,22,0,0,22,0,0,0
    .byte 0,22,0,0,22,0,0,0
    .p2align 7
// 35: cabra B
    .byte 8, 7, 4, 0
    .byte 0,0,0,0,0,0,21,21
    .byte 0,0,0,0,0,37,37,21
    .byte 0,0,0,0,0,37,18,37
    .byte 37,37,37,37,37,37,37,0
    .byte 37,37,37,37,37,37,0,0
    .byte 22,0,0,0,0,22,0,0
    .byte 22,0,0,0,0,22,0,0
    .p2align 7
// 36: lobo A
    .byte 9, 6, 4, 0
    .byte 0,0,0,0,0,0,0,39,39
    .byte 0,0,0,0,0,0,39,39,39
    .byte 39,0,0,0,0,39,39,17,39
    .byte 0,39,39,39,39,39,39,39,22
    .byte 0,39,39,39,39,39,0,0,0
    .byte 0,22,0,22,0,22,0,0,0
    .p2align 7
// 37: lobo B
    .byte 9, 6, 4, 0
    .byte 0,0,0,0,0,0,0,39,39
    .byte 0,0,0,0,0,0,39,39,39
    .byte 39,0,0,0,0,39,39,17,39
    .byte 0,39,39,39,39,39,39,39,22
    .byte 0,39,39,39,39,39,0,0,0
    .byte 22,0,22,0,22,0,0,0,0
    .p2align 7
// 38: urso A
    .byte 10, 8, 5, 0
    .byte 0,0,0,0,0,0,0,10,0,10
    .byte 0,0,0,0,0,0,10,10,10,10
    .byte 0,10,10,10,10,10,10,10,18,10
    .byte 10,10,10,10,10,10,10,10,10,29
    .byte 10,10,10,10,10,10,10,10,0,0
    .byte 10,10,10,10,10,10,10,0,0,0
    .byte 0,30,30,0,0,30,30,0,0,0
    .byte 0,30,30,0,0,30,30,0,0,0
    .p2align 7
// 39: urso B
    .byte 10, 8, 5, 0
    .byte 0,0,0,0,0,0,0,10,0,10
    .byte 0,0,0,0,0,0,10,10,10,10
    .byte 0,10,10,10,10,10,10,10,18,10
    .byte 10,10,10,10,10,10,10,10,10,29
    .byte 10,10,10,10,10,10,10,10,0,0
    .byte 10,10,10,10,10,10,10,0,0,0
    .byte 30,30,0,0,0,0,30,30,0,0
    .byte 30,30,0,0,0,0,30,30,0,0
    .p2align 7
// 40: caranguejo A
    .byte 7, 4, 3, 0
    .byte 38,0,0,0,0,0,38
    .byte 38,0,18,0,18,0,38
    .byte 0,38,38,38,38,38,0
    .byte 38,0,38,0,38,0,38
    .p2align 7
// 41: caranguejo B
    .byte 7, 4, 3, 0
    .byte 38,0,0,0,0,0,38
    .byte 38,0,18,0,18,0,38
    .byte 0,38,38,38,38,38,0
    .byte 0,38,0,38,0,38,0
    .p2align 7
// 42: vara de pesca
    .byte 7, 8, 3, 0
    .byte 0,0,0,0,0,0,31
    .byte 0,0,0,0,0,31,32
    .byte 0,0,0,0,31,0,32
    .byte 0,0,0,31,0,0,32
    .byte 0,0,31,0,0,0,32
    .byte 0,31,0,0,0,0,17
    .byte 31,0,0,0,0,0,0
    .byte 1,0,0,0,0,0,0
    .p2align 7
// 43: peixe
    .byte 8, 4, 4, 0
    .byte 0,0,13,13,13,0,0,13
    .byte 0,13,12,12,13,13,13,13
    .byte 13,18,12,12,12,13,13,0
    .byte 0,13,13,13,13,0,0,13
    .p2align 7
// 44: peixe assado
    .byte 8, 4, 4, 0
    .byte 0,0,36,36,36,0,0,36
    .byte 0,36,35,35,36,36,36,36
    .byte 36,18,35,25,35,36,36,0
    .byte 0,36,36,36,36,0,0,36
    .p2align 7
// 45: cerca: poste
    .byte 9, 7, 4, 0
    .byte 0,0,0,0,10,0,0,0,0
    .byte 0,0,0,0,31,0,0,0,0
    .byte 0,0,0,0,31,0,0,0,0
    .byte 0,0,0,0,31,0,0,0,0
    .byte 0,0,0,0,31,0,0,0,0
    .byte 0,0,0,0,31,0,0,0,0
    .byte 0,0,0,0,1,0,0,0,0
    .p2align 7
// 46: cerca: trilho em +u
    .byte 9, 7, 4, 0
    .byte 0,0,0,0,10,0,0,0,0
    .byte 0,0,0,0,31,0,0,0,0
    .byte 0,0,0,0,31,36,0,0,0
    .byte 0,0,0,0,31,0,36,36,0
    .byte 0,0,0,0,31,36,0,0,0
    .byte 0,0,0,0,31,0,36,36,0
    .byte 0,0,0,0,1,0,0,0,0
    .p2align 7
// 47: cerca: trilho em +v
    .byte 9, 7, 4, 0
    .byte 0,0,0,0,10,0,0,0,0
    .byte 0,0,0,0,31,0,0,0,0
    .byte 0,0,0,36,31,0,0,0,0
    .byte 0,36,36,0,31,0,0,0,0
    .byte 0,0,0,36,31,0,0,0,0
    .byte 0,36,36,0,31,0,0,0,0
    .byte 0,0,0,0,1,0,0,0,0
    .p2align 7
// 48: cerca: os dois
    .byte 9, 7, 4, 0
    .byte 0,0,0,0,10,0,0,0,0
    .byte 0,0,0,0,31,0,0,0,0
    .byte 0,0,0,36,31,36,0,0,0
    .byte 0,36,36,0,31,0,36,36,0
    .byte 0,0,0,36,31,36,0,0,0
    .byte 0,36,36,0,31,0,36,36,0
    .byte 0,0,0,0,1,0,0,0,0
    .p2align 7
// 49: portao ao longo de u
    .byte 9, 7, 4, 0
    .byte 0,0,0,0,10,0,0,0,0
    .byte 0,0,0,0,31,35,0,0,0
    .byte 0,0,0,0,31,36,35,35,0
    .byte 0,0,0,0,31,35,36,36,0
    .byte 0,0,0,0,31,35,35,35,0
    .byte 0,0,0,0,31,0,35,35,0
    .byte 0,0,0,0,1,0,0,0,0
    .p2align 7
// 50: portao ao longo de v
    .byte 9, 7, 4, 0
    .byte 0,0,0,0,10,0,0,0,0
    .byte 0,0,0,35,31,0,0,0,0
    .byte 0,35,35,36,31,0,0,0,0
    .byte 0,36,36,35,31,0,0,0,0
    .byte 0,35,35,35,31,0,0,0,0
    .byte 0,35,35,0,31,0,0,0,0
    .byte 0,0,0,0,1,0,0,0,0
    .p2align 7
// 51: boia
    .byte 3, 4, 1, 0
    .byte 0,17,0
    .byte 17,17,17
    .byte 37,37,37
    .byte 0,37,0
    .p2align 7
// 52: trigo selvagem
    .byte 7, 8, 3, 0
    .byte 0,40,0,0,0,40,0
    .byte 40,41,0,40,0,41,40
    .byte 0,40,0,41,0,40,0
    .byte 0,41,40,40,40,41,0
    .byte 0,0,41,42,41,0,0
    .byte 0,42,0,42,0,42,0
    .byte 0,42,0,42,0,42,0
    .byte 0,0,42,42,42,0,0
    .p2align 7
// 53: trigo plantado: broto
    .byte 7, 2, 3, 0
    .byte 0,16,0,0,0,16,0
    .byte 0,3,0,16,0,3,0
    .p2align 7
// 54: trigo plantado: crescendo
    .byte 7, 4, 3, 0
    .byte 0,16,0,0,0,16,0
    .byte 16,3,0,16,0,3,16
    .byte 0,3,0,3,0,3,0
    .byte 0,3,0,3,0,3,0
    .p2align 7
// 55: trigo plantado: quase
    .byte 7, 6, 3, 0
    .byte 0,42,0,0,0,42,0
    .byte 0,3,0,42,0,3,0
    .byte 42,3,0,3,0,3,42
    .byte 3,0,3,3,3,0,3
    .byte 0,3,2,0,2,3,0
    .byte 0,3,0,3,0,3,0
    .p2align 7
// 56: trigo plantado: maduro
    .byte 7, 8, 3, 0
    .byte 0,40,0,0,0,40,0
    .byte 40,41,0,40,0,41,40
    .byte 0,40,0,41,0,40,0
    .byte 0,41,40,40,40,41,0
    .byte 40,0,41,41,41,0,40
    .byte 0,42,0,42,0,42,0
    .byte 0,42,0,42,0,42,0
    .byte 0,0,42,42,42,0,0
    .p2align 7
// 57: enxada
    .byte 7, 8, 3, 0
    .byte 0,12,12,12,0,0,0
    .byte 0,13,13,31,0,0,0
    .byte 0,0,0,31,0,0,0
    .byte 0,0,0,0,31,0,0
    .byte 0,0,0,0,31,0,0
    .byte 0,0,0,0,0,31,0
    .byte 0,0,0,0,0,31,0
    .byte 0,0,0,0,0,0,1
    .p2align 7
// 58: sementes
    .byte 6, 4, 3, 0
    .byte 0,7,0,0,35,0
    .byte 35,0,0,7,0,0
    .byte 0,0,7,0,0,35
    .byte 0,35,0,0,7,0
    .p2align 7
// 59: trigo (feixe)
    .byte 7, 8, 3, 0
    .byte 0,40,0,40,0,40,0
    .byte 40,41,40,41,40,41,40
    .byte 0,40,41,40,41,40,0
    .byte 0,0,40,40,40,0,0
    .byte 0,0,31,31,31,0,0
    .byte 0,0,42,40,42,0,0
    .byte 0,42,0,40,0,42,0
    .byte 42,0,0,40,0,0,42
    .p2align 7
// 60: pao
    .byte 7, 4, 3, 0
    .byte 0,0,43,43,43,0,0
    .byte 0,43,6,43,6,43,0
    .byte 43,43,43,43,43,43,43
    .byte 0,36,36,36,36,36,0
    .p2align 7
// 61: muda
    .byte 3, 4, 1, 0
    .byte 0,42,0
    .byte 42,3,42
    .byte 0,3,0
    .byte 0,1,0
    .p2align 7
// 62: setinha (pessoa selecionada)
    .byte 5, 3, 2, 0
    .byte 24,24,24,24,24
    .byte 0,24,24,24,0
    .byte 0,0,24,0,0
    .p2align 7
// 63: homem (roupa: cor da familia)
    .byte 5, 9, 2, 0
    .byte 0,30,30,30,0
    .byte 0,27,27,27,0
    .byte 0,8,8,8,0
    .byte 8,8,8,8,8
    .byte 27,8,8,8,27
    .byte 0,9,9,9,0
    .byte 0,29,0,29,0
    .byte 0,29,0,29,0
    .byte 0,18,0,18,0
    .p2align 7
// 64: homem passo 2
    .byte 5, 9, 2, 0
    .byte 0,30,30,30,0
    .byte 0,27,27,27,0
    .byte 0,8,8,8,0
    .byte 8,8,8,8,8
    .byte 27,8,8,8,27
    .byte 0,9,9,9,0
    .byte 0,29,0,29,0
    .byte 29,0,0,0,29
    .byte 18,0,0,0,18
    .p2align 7
// 65: crianca
    .byte 5, 6, 2, 0
    .byte 0,30,30,30,0
    .byte 0,27,27,27,0
    .byte 27,8,8,8,27
    .byte 0,8,8,8,0
    .byte 0,29,0,29,0
    .byte 0,18,0,18,0
    .p2align 7
// 66: crianca passo 2
    .byte 5, 6, 2, 0
    .byte 0,30,30,30,0
    .byte 0,27,27,27,0
    .byte 27,8,8,8,27
    .byte 0,8,8,8,0
    .byte 29,0,0,0,29
    .byte 18,0,0,0,18
    .p2align 7
// 67: mulher (cabelo comprido, vestido)
    .byte 5, 9, 2, 0
    .byte 0,30,30,30,0
    .byte 30,27,27,27,30
    .byte 30,8,8,8,30
    .byte 8,8,8,8,8
    .byte 27,8,8,8,27
    .byte 0,8,8,8,0
    .byte 8,9,9,9,8
    .byte 0,27,0,27,0
    .byte 0,18,0,18,0
    .p2align 7
// 68: mulher passo 2
    .byte 5, 9, 2, 0
    .byte 0,30,30,30,0
    .byte 30,27,27,27,30
    .byte 30,8,8,8,30
    .byte 8,8,8,8,8
    .byte 27,8,8,8,27
    .byte 0,8,8,8,0
    .byte 8,9,9,9,8
    .byte 27,0,0,0,27
    .byte 18,0,0,0,18
    .p2align 7
// 69: arvore jovem
    .byte 5, 6, 2, 0
    .byte 0,3,3,3,0
    .byte 3,3,2,3,3
    .byte 3,2,2,2,3
    .byte 0,3,2,3,0
    .byte 0,0,1,0,0
    .byte 0,0,1,0,0
    .p2align 7
// 70: barraco (14 x 11; ocupa as vagas 70 e 71; telhado na cor da familia)
    .byte 14, 11, 7, 0
    .byte 0,0,0,0,0,0,9,9,0,0,0,0,0,0
    .byte 0,0,0,0,0,9,8,8,9,0,0,0,0,0
    .byte 0,0,0,0,9,8,8,8,8,9,0,0,0,0
    .byte 0,0,0,9,8,8,8,8,8,8,9,0,0,0
    .byte 0,0,9,8,8,8,8,8,8,8,8,9,0,0
    .byte 0,9,8,8,8,8,8,8,8,8,8,8,9,0
    .byte 9,9,9,9,9,9,9,9,9,9,9,9,9,9
    .byte 0,31,1,31,1,31,18,18,31,1,31,1,31,0
    .byte 0,31,1,31,1,31,18,18,31,1,31,1,31,0
    .byte 0,31,1,31,1,31,18,18,31,1,31,1,31,0
    .byte 0,1,1,1,1,1,18,18,1,1,1,1,1,0
    .p2align 7
// 72: casa (20 x 16; vagas 72 a 74; paredes claras, janelas, chamine)
    .byte 20, 16, 10, 0
    .byte 0,0,0,0,0,0,0,0,0,9,9,0,0,0,22,22,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,9,8,8,9,0,0,22,22,0,0,0,0
    .byte 0,0,0,0,0,0,0,9,8,8,8,8,9,0,22,22,0,0,0,0
    .byte 0,0,0,0,0,0,9,8,8,8,8,8,8,9,22,22,0,0,0,0
    .byte 0,0,0,0,0,9,8,8,8,8,8,8,8,8,9,22,0,0,0,0
    .byte 0,0,0,0,9,8,8,8,8,8,8,8,8,8,8,9,0,0,0,0
    .byte 0,0,0,9,8,8,8,8,8,8,8,8,8,8,8,8,9,0,0,0
    .byte 0,0,9,8,8,8,8,8,8,8,8,8,8,8,8,8,8,9,0,0
    .byte 0,9,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,9,0
    .byte 9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9
    .byte 0,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,0
    .byte 0,6,11,11,6,6,6,6,1,1,1,1,6,6,6,6,11,11,6,0
    .byte 0,6,11,11,6,6,6,6,1,1,1,1,6,6,6,6,11,11,6,0
    .byte 0,6,6,6,6,6,6,6,1,1,1,1,6,6,6,6,6,6,6,0
    .byte 0,6,6,6,6,6,6,6,1,1,1,1,6,6,6,6,6,6,6,0
    .byte 0,7,7,7,7,7,7,7,1,1,1,1,7,7,7,7,7,7,7,0
    .p2align 7
// 75: minerio de ferro
    .byte 6, 5, 3, 0
    .byte 0,21,44,21,0,0
    .byte 21,44,45,21,44,0
    .byte 21,21,44,45,21,21
    .byte 0,45,21,21,44,21
    .byte 0,0,21,21,21,0
    .p2align 7
// 76: carvao
    .byte 6, 5, 3, 0
    .byte 0,18,18,39,0,0
    .byte 18,39,18,18,18,0
    .byte 18,18,18,39,18,18
    .byte 0,18,39,18,18,18
    .byte 0,0,18,18,18,0
    .p2align 7
// 77: barra de ferro
    .byte 7, 4, 3, 0
    .byte 0,0,12,12,12,12,0
    .byte 0,12,12,12,12,13,0
    .byte 12,13,13,13,13,14,0
    .byte 14,14,14,14,14,0,0
    .p2align 7
// 78: fornalha (12 x 13; vagas 78 e 79)
    .byte 12, 13, 6, 0
    .byte 0,0,0,0,0,0,0,0,22,22,0,0
    .byte 0,0,0,0,0,0,0,0,22,22,0,0
    .byte 0,0,20,20,20,20,20,20,22,22,20,0
    .byte 0,20,20,21,20,20,21,20,20,21,20,20
    .byte 20,21,21,21,21,21,21,21,21,21,21,20
    .byte 20,21,22,22,22,22,22,22,22,22,21,20
    .byte 20,21,22,18,18,18,18,18,18,22,21,20
    .byte 21,21,22,18,25,24,24,25,18,22,21,21
    .byte 21,22,22,18,26,25,25,26,18,22,22,21
    .byte 21,22,22,18,26,26,26,26,18,22,22,21
    .byte 22,22,22,22,22,22,22,22,22,22,22,22
    .byte 21,21,21,21,21,21,21,21,21,21,21,21
    .byte 22,22,22,22,22,22,22,22,22,22,22,22
    .p2align 7
// 80: machado de ferro
    .byte 7, 7, 3, 0
    .byte 0,0,0,0,33,33,0
    .byte 0,0,0,33,32,32,33
    .byte 0,0,0,31,33,32,33
    .byte 0,0,31,0,0,33,0
    .byte 0,31,0,0,0,0,0
    .byte 31,0,0,0,0,0,0
    .byte 1,0,0,0,0,0,0
    .p2align 7
// 81: picareta de ferro
    .byte 7, 6, 3, 0
    .byte 0,33,33,33,33,33,0
    .byte 33,32,0,31,0,32,33
    .byte 33,0,0,31,0,0,33
    .byte 0,0,0,31,0,0,0
    .byte 0,0,0,31,0,0,0
    .byte 0,0,0,1,0,0,0
    .p2align 7
// 82: enxada de ferro
    .byte 7, 8, 3, 0
    .byte 0,32,32,32,0,0,0
    .byte 0,33,33,31,0,0,0
    .byte 0,0,0,31,0,0,0
    .byte 0,0,0,0,31,0,0
    .byte 0,0,0,0,31,0,0
    .byte 0,0,0,0,0,31,0
    .byte 0,0,0,0,0,31,0
    .byte 0,0,0,0,0,0,1
    .p2align 7
// 83: espada
    .byte 7, 7, 3, 0
    .byte 0,0,0,0,0,32,32
    .byte 0,0,0,0,32,37,32
    .byte 0,0,0,32,37,32,0
    .byte 24,0,32,37,32,0,0
    .byte 0,24,37,32,0,0,0
    .byte 0,1,24,0,0,0,0
    .byte 1,0,0,24,0,0,0
    .p2align 7
// 84: armadura de ferro
    .byte 7, 7, 3, 0
    .byte 33,33,0,0,0,33,33
    .byte 33,32,33,33,33,32,33
    .byte 0,33,32,32,32,33,0
    .byte 0,33,32,33,32,33,0
    .byte 0,33,32,32,32,33,0
    .byte 0,33,33,33,33,33,0
    .byte 0,34,0,0,0,34,0
    .p2align 7
// 85: lampiao
    .byte 5, 12, 2, 0
    .byte 0,34,34,34,0
    .byte 34,24,24,24,34
    .byte 34,24,47,24,34
    .byte 34,24,24,24,34
    .byte 0,34,34,34,0
    .byte 0,0,34,0,0
    .byte 0,0,34,0,0
    .byte 0,0,34,0,0
    .byte 0,0,34,0,0
    .byte 0,0,34,0,0
    .byte 0,0,34,0,0
    .byte 0,34,34,34,0
    .p2align 7
// 86: veio de ferro
    .byte 8, 6, 4, 0
    .byte 0,0,20,20,20,0,0,0
    .byte 0,20,44,21,21,21,0,0
    .byte 20,20,21,21,44,22,22,0
    .byte 20,44,21,21,22,22,44,22
    .byte 21,21,21,44,22,22,22,22
    .byte 0,22,22,22,22,22,22,0
    .p2align 7
// 87: veio de carvao
    .byte 8, 6, 4, 0
    .byte 0,0,20,20,20,0,0,0
    .byte 0,20,18,21,21,21,0,0
    .byte 20,20,21,21,18,22,22,0
    .byte 20,18,18,21,22,22,18,22
    .byte 21,21,21,18,22,18,22,22
    .byte 0,22,22,22,22,22,22,0
    .p2align 7

m_gridon:       .asciz "Grade ligada (G desliga)"
m_gridoff:      .asciz "Grade desligada"
s_wintitle:     .asciz "Ermo - sobrevivencia em Assembly ARM64"
s_title:        .asciz "ERMO"
s_sub:          .asciz "um jogo de sobrevivencia escrito em assembly ARM64"
s_world:        .asciz "Mundo #"
s_enter:        .asciz "Pressione ENTER para jogar"
s_title_help:   .asciz "R: gerar outro mundo     F11: tela cheia     ESC: sair"
s_credit:       .asciz "feito por Andre + Claude"
s_sep_paren:    .asciz "   -   ("
s_comma:        .asciz ","
s_paren_sp:     .asciz ")  "
s_alt:          .asciz ", "
s_m:            .asciz " m"
s_sep:          .asciz "   -   "
s_dash:         .asciz ", "
s_hab:          .asciz " hab."
s_nl:           .asciz "\n"
s_bench:        .asciz "tempo por quadro: "
s_bench2:       .asciz " us\n"
s_shot_f12:     .asciz "ermo.bmp"
s_shot_title:   .asciz "shot_titulo.bmp"
s_shot_game:    .asciz "shot_jogo.bmp"
s_shot_far:     .asciz "shot_longe.bmp"
s_shot_near:    .asciz "shot_perto.bmp"
s_shot_contour: .asciz "shot_curvas.bmp"
s_shot_night:   .asciz "shot_noite.bmp"
s_shot_swim:    .asciz "shot_nado.bmp"
s_shot_bag:     .asciz "shot_mochila.bmp"
s_shot_craft:   .asciz "shot_fabricar.bmp"
s_shot_torch:   .asciz "shot_tocha.bmp"
s_shot_clima:   .asciz "shot_clima0.bmp"
s_shot_anim:    .asciz "shot_animais.bmp"
s_shot_fence:   .asciz "shot_cerca.bmp"
s_shot_farm:    .asciz "shot_plantacao.bmp"
s_shot_people:  .asciz "shot_pessoas.bmp"
s_shot_panel:   .asciz "shot_painel.bmp"
s_shot_village: .asciz "shot_vila.bmp"
s_shot_family:  .asciz "shot_familias.bmp"
s_shot_iron:    .asciz "shot_ferro.bmp"
s_shot_fish:    .asciz "shot_pesca.bmp"
s_shot_hut:     .asciz "shot_abrigo.bmp"
s_shot_sleep:   .asciz "shot_dormindo.bmp"
s_shot_shark:   .asciz "shot_tubarao.bmp"
s_shot_dead:    .asciz "shot_fim.bmp"

// ---- memoria zerada (bss) -------------------------------------------
GBSS hmap, 262144
GBSS moist, 262144
GBSS light, 262144
GBSS overlay, 262144
GBSS elev, 524288
GBSS accum, 1048576
GBSS objs, 1600000
GBSS txt, 256
GBSS noisetab, 65536
GBSS trange, 64
GBSS tids, 64
GBSS parfunc, 16
GBSS zb, 1843200
GBSS fb, 3686400
