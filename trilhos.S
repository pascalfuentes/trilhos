// =====================================================================
//  TRILHOS - um jogo de trens no estilo OpenTTD, escrito em assembly
//  ARM64 (AArch64). Roda no macOS (Apple Silicon) e no Linux ARM64.
//
//  Toda a logica e todo o desenho (renderizacao isometrica por software)
//  sao feitos aqui em assembly. A biblioteca SDL3 so e usada para abrir
//  a janela, ler teclado/mouse e mostrar o framebuffer na tela.
//
//  Compilar:  make        (ou: clang trilhos.S -o trilhos -lSDL3)
// =====================================================================

// ---- diferencas entre macOS (Mach-O) e Linux (ELF) ------------------
#ifdef __APPLE__
#define F(x) _##x
#define BSS(name, size) .zerofill __DATA,__bss,name,size,4
#else
#define F(x) x
#define BSS(name, size) .section .bss ; .balign 16 ; name: .space size
#endif

// carrega o endereco de um simbolo num registrador
.macro LA reg, sym
#ifdef __APPLE__
    adrp    \reg, \sym@PAGE
    add     \reg, \reg, \sym@PAGEOFF
#else
    adrp    \reg, \sym
    add     \reg, \reg, :lo12:\sym
#endif
.endm

// carrega uma constante de 32 bits
.macro MOVI32 reg, val
    movz    \reg, #((\val) & 0xFFFF)
    movk    \reg, #(((\val) >> 16) & 0xFFFF), lsl #16
.endm

// ---- constantes -----------------------------------------------------
.equ MAPN,      128          // mapa 128 x 128 tiles
.equ HSTEP,     4            // pixels por nivel de altura
.equ MAXTOWNS,  16
.equ TOWNSZ,    48           // x(4) y(4) pop(4) nome(32) pad(4)
.equ NSYL,      32

// terrenos
.equ T_DEEP,    0
.equ T_SHALLOW, 1
.equ T_SAND,    2
.equ T_GRASS,   3
.equ T_FOREST,  4
.equ T_HILL,    5
.equ T_ROCK,    6
.equ T_SNOW,    7
.equ T_ROAD,    8
.equ T_HOUSE,   9
.equ T_TOWER,   10

// estado global: x28 aponta sempre para G
.equ G_REN,      0
.equ G_WIN,      8
.equ G_TEX0,     16
.equ G_TEX,      40
.equ G_KEYS,     48
.equ G_CAMX,     56
.equ G_CAMY,     60
.equ G_ZOOM,     64
.equ G_FBW,      68
.equ G_FBH,      72
.equ G_SEED,     76
.equ G_RNG,      80
.equ G_STATE,    84
.equ G_RUNNING,  88
.equ G_FRAME,    92
.equ G_MX,       96
.equ G_MY,       100
.equ G_HOV,      104
.equ G_GRID,     108
.equ G_DAX,      112
.equ G_DAY,      116
.equ G_WHEEL,    120
.equ G_NTOWNS,   124
.equ G_SHOT,     128
.equ G_WANTSHOT, 132

// SDL3
.equ SDL_INIT_VIDEO,        0x20
.equ SDL_EVENT_QUIT,        0x100
.equ SDL_EVENT_KEY_DOWN,    0x300
.equ SDL_EVENT_MOUSE_MOTION,0x400
.equ SDL_EVENT_MOUSE_WHEEL, 0x403

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
    mov     w20, #0                     // codigo de saida
    cmp     w0, #1                      // qualquer argumento = modo screenshot
    cset    w9, gt
    str     w9, [x28, #G_SHOT]

    mov     w0, #SDL_INIT_VIDEO
    bl      F(SDL_Init)
    tst     w0, #0xff
    b.eq    main_fail

    LA      x0, s_wintitle
    mov     w1, #1280
    mov     w2, #720
    mov     x3, #0
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

    // 3 texturas, uma por nivel de zoom: 320x180, 640x360, 1280x720
    mov     w19, #0
1:  ldr     x0, [x28, #G_REN]
    MOVI32  w1, 0x16362004              // SDL_PIXELFORMAT_ARGB8888
    mov     w2, #1                      // SDL_TEXTUREACCESS_STREAMING
    mov     w3, #320
    lsl     w3, w3, w19
    mov     w4, #180
    lsl     w4, w4, w19
    bl      F(SDL_CreateTexture)
    cbz     x0, main_fail
    add     x9, x28, #G_TEX0
    str     x0, [x9, w19, uxtw #3]
    mov     w1, #0                      // SDL_SCALEMODE_NEAREST (pixel art)
    bl      F(SDL_SetTextureScaleMode)
    add     w19, w19, #1
    cmp     w19, #3
    b.lt    1b

    mov     x0, #0
    bl      F(SDL_GetKeyboardState)
    str     x0, [x28, #G_KEYS]

    // semente aleatoria: relogio + contador de alta precisao
    bl      F(SDL_GetPerformanceCounter)
    mov     x19, x0
    mov     x0, #0
    bl      F(time)
    eor     x0, x0, x19
    eor     x0, x0, x0, lsr #32
    orr     w0, w0, #1
    str     w0, [x28, #G_RNG]

    mov     w9, #1
    str     w9, [x28, #G_RUNNING]
    str     w9, [x28, #G_GRID]
    mov     w9, #-1
    str     w9, [x28, #G_HOV]
    str     wzr, [x28, #G_STATE]
    mov     w0, #2
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
    mov     w19, #0
3:  add     x9, x28, #G_TEX0
    ldr     x0, [x9, w19, uxtw #3]
    cbz     x0, 4f
    bl      F(SDL_DestroyTexture)
4:  add     w19, w19, #1
    cmp     w19, #3
    b.lt    3b
    ldr     x0, [x28, #G_REN]
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

// ---- modo screenshot (usado para testar sem tela) -------------------
shot_mode:
    bl      update
    bl      draw_all
    LA      x0, s_shot_title
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)

    mov     w9, #1
    str     w9, [x28, #G_STATE]
    mov     w9, #640
    scvtf   s0, w9
    str     s0, [x28, #G_MX]
    mov     w9, #360
    scvtf   s0, w9
    str     s0, [x28, #G_MY]
    mov     w0, #1
    bl      set_zoom
    bl      update
    bl      draw_all
    LA      x0, s_shot_game
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)

    mov     w0, #2
    bl      set_zoom
    bl      update
    bl      draw_all
    LA      x0, s_shot_far
    bl      save_bmp
    ldr     x0, [x28, #G_REN]
    bl      F(SDL_RenderPresent)

    mov     w0, #0
    bl      set_zoom
    bl      update
    bl      draw_all
    LA      x0, s_shot_near
    bl      save_bmp
    b       main_exit

// =====================================================================
//  Utilitarios
// =====================================================================

// set_zoom(w0 = 0..2): escolhe tamanho do framebuffer e textura
set_zoom:
    str     w0, [x28, #G_ZOOM]
    mov     w9, #320
    lsl     w9, w9, w0
    str     w9, [x28, #G_FBW]
    mov     w9, #180
    lsl     w9, w9, w0
    str     w9, [x28, #G_FBH]
    add     x9, x28, #G_TEX0
    ldr     x9, [x9, w0, uxtw #3]
    str     x9, [x28, #G_TEX]
    ret

zoom_in:
    ldr     w0, [x28, #G_ZOOM]
    cbz     w0, 1f
    sub     w0, w0, #1
    b       set_zoom
1:  ret

zoom_out:
    ldr     w0, [x28, #G_ZOOM]
    cmp     w0, #2
    b.ge    1f
    add     w0, w0, #1
    b       set_zoom
1:  ret

// rng() -> w0   (xorshift32; usa so w0)
rng:
    ldr     w0, [x28, #G_RNG]
    eor     w0, w0, w0, lsl #13
    eor     w0, w0, w0, lsr #17
    eor     w0, w0, w0, lsl #5
    str     w0, [x28, #G_RNG]
    ret

// rng_mod(w0 = n) -> w0 = aleatorio em [0, n)   (usa w0, w9, w10)
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
mystrlen:
    mov     x9, x0
1:  ldrb    w10, [x9], #1
    cbnz    w10, 1b
    sub     x0, x9, x0
    sub     x0, x0, #1
    ret

// strcat_cur(x0 = destino, x1 = origem) -> x0 = posicao do '\0'  (usa w9)
strcat_cur:
1:  ldrb    w9, [x1], #1
    strb    w9, [x0], #1
    cbnz    w9, 1b
    sub     x0, x0, #1
    ret

// numcat(x0 = destino, w1 = numero) -> x0 = posicao do '\0'  (usa x9-x13)
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

// save_bmp(x0 = nome do arquivo): salva o que foi desenhado
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

// =====================================================================
//  Geracao do mundo
// =====================================================================

// new_world: sorteia uma semente nova e gera o mapa
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
    bl      generate_map
    str     wzr, [x28, #G_CAMX]
    mov     w9, #1024
    str     w9, [x28, #G_CAMY]
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// generate_map: tudo deriva de G_SEED (mesma semente = mesmo mundo)
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

    // relevo: ruido fractal com 5 oitavas (32, 16, 8, 4, 2 tiles)
    LA      x0, accum
    mov     w1, w19
    mov     w2, #5
    mov     w3, #5
    bl      gen_noise
    LA      x0, accum
    LA      x1, hmap
    bl      normalize
    bl      edge_falloff

    // umidade (decide onde nascem florestas)
    LA      x0, accum
    MOVI32  w1, 0x5bd1e995
    eor     w1, w1, w19
    mov     w2, #4
    mov     w3, #4
    bl      gen_noise
    LA      x0, accum
    LA      x1, moist
    bl      normalize

    bl      classify
    bl      place_towns

    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// gen_noise(x0 = acc[int32], w1 = sal, w2 = oitavas, w3 = shift inicial)
// ruido de valor com interpolacao suave (smoothstep), somando oitavas
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
    mov     w10, #16384
1:  str     wzr, [x9], #4
    subs    w10, w10, #1
    b.ne    1b

    mov     w21, #0                     // k = oitava
gn_oct:
    ldr     w9, [sp, #88]
    cmp     w21, w9
    b.ge    gn_done
    ldr     w22, [sp, #92]
    sub     w22, w22, w21               // s = shift (tamanho da celula = 1<<s)
    cmp     w22, #1
    b.lt    gn_done
    mov     w9, #1013
    madd    w27, w21, w9, w20           // sal desta oitava

    mov     w23, #0                     // y
gn_y:
    lsr     w26, w23, w22               // gy
    mov     w9, #1
    lsl     w9, w9, w22
    sub     w9, w9, #1
    and     w10, w23, w9
    mov     w9, #8
    sub     w9, w9, w22
    lsl     w10, w10, w9                // t em 0..255
    mul     w11, w10, w10
    mov     w12, #768
    sub     w12, w12, w10, lsl #1
    mul     w11, w11, w12
    lsr     w25, w11, #16               // ty suavizado

    mov     w24, #0                     // x
gn_x:
    lsr     w15, w24, w22               // gx
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
    lsr     w14, w11, #16               // tx suavizado

    mov     w0, w15
    mov     w1, w26
    mov     w2, w27
    bl      hash3
    and     w10, w0, #0xFFFF            // a
    add     w0, w15, #1
    mov     w1, w26
    bl      hash3
    and     w11, w0, #0xFFFF            // b
    mov     w0, w15
    add     w1, w26, #1
    bl      hash3
    and     w12, w0, #0xFFFF            // c
    add     w0, w15, #1
    add     w1, w26, #1
    bl      hash3
    and     w13, w0, #0xFFFF            // d

    sub     w11, w11, w10
    mul     w11, w11, w14
    asr     w11, w11, #8
    add     w10, w10, w11               // topo = lerp(a, b)
    sub     w13, w13, w12
    mul     w13, w13, w14
    asr     w13, w13, #8
    add     w12, w12, w13               // base = lerp(c, d)
    sub     w12, w12, w10
    mul     w12, w12, w25
    asr     w12, w12, #8
    add     w10, w10, w12               // v = lerp(topo, base)
    asr     w10, w10, w21               // amplitude cai pela metade a cada oitava

    add     w11, w24, w23, lsl #7
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

// normalize(x0 = acc[int32], x1 = destino[u8]): estica para 0..255
normalize:
    mov     w9, #0x7fffffff             // min
    mov     w10, #0x80000000            // max
    mov     x12, #0
1:  ldr     w11, [x0, x12, lsl #2]
    cmp     w11, w9
    csel    w9, w11, w9, lt
    cmp     w11, w10
    csel    w10, w11, w10, gt
    add     x12, x12, #1
    cmp     x12, #16384
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
    cmp     x12, #16384
    b.lo    3b
    ret

// edge_falloff: rebaixa o terreno perto das bordas (vira mar)
edge_falloff:
    LA      x0, hmap
    mov     w1, #0
1:  and     w2, w1, #127
    lsr     w3, w1, #7
    mov     w4, #127
    sub     w5, w4, w2
    sub     w6, w4, w3
    cmp     w2, w3
    csel    w7, w2, w3, lt
    cmp     w7, w5
    csel    w7, w7, w5, lt
    cmp     w7, w6
    csel    w7, w7, w6, lt
    cmp     w7, #20
    b.ge    2f
    ldrb    w8, [x0, w1, uxtw]
    mul     w8, w8, w7
    mov     w9, #20
    udiv    w8, w8, w9
    strb    w8, [x0, w1, uxtw]
2:  add     w1, w1, #1
    cmp     w1, #4, lsl #12
    b.lo    1b
    ret

// classify: altura + umidade -> tipo de terreno e nivel
classify:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    ldr     w20, [x28, #G_SEED]
    add     w20, w20, #7
    mov     w19, #0
cl_loop:
    and     w0, w19, #127
    lsr     w1, w19, #7
    mov     w2, w20
    bl      hash3
    and     w0, w0, #15
    LA      x10, jit
    strb    w0, [x10, w19, uxtw]
    LA      x10, townid
    strb    wzr, [x10, w19, uxtw]
    LA      x10, hmap
    ldrb    w11, [x10, w19, uxtw]       // h
    LA      x10, moist
    ldrb    w12, [x10, w19, uxtw]       // umidade
    mov     w13, #T_DEEP
    mov     w14, #0                     // nivel
    cmp     w11, #90
    b.lo    5f
    mov     w13, #T_SHALLOW
    cmp     w11, #104
    b.lo    5f
    sub     w15, w11, #104              // d = altura acima do mar
    lsr     w14, w15, #4                // nivel = d/16 + d*d/4096 + 1
    mul     w15, w15, w15               // (planicies suaves, montanhas ingremes)
    add     w14, w14, w15, lsr #12
    add     w14, w14, #1
    mov     w13, #T_SAND
    cmp     w11, #112
    b.lo    5f
    cmp     w11, #175
    b.hs    2f
    mov     w13, #T_GRASS
    cmp     w12, #150
    b.lo    5f
    mov     w13, #T_FOREST
    b       5f
2:  cmp     w11, #200
    b.hs    3f
    mov     w13, #T_HILL
    cmp     w12, #140
    b.lo    5f
    mov     w13, #T_FOREST
    b       5f
3:  mov     w13, #T_ROCK
    cmp     w11, #225
    b.lo    5f
    mov     w13, #T_SNOW
5:  LA      x10, terr
    strb    w13, [x10, w19, uxtw]
    LA      x10, level
    strb    w14, [x10, w19, uxtw]
    add     w19, w19, #1
    cmp     w19, #4, lsl #12
    b.lo    cl_loop
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// place_towns: espalha ate 12 cidades em campos abertos
place_towns:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     x27, [sp, #80]
    mov     w19, #0                     // cidades criadas
    mov     w20, #0                     // tentativas
pt_try:
    cmp     w19, #12
    b.ge    pt_done
    add     w20, w20, #1
    cmp     w20, #800
    b.gt    pt_done
    mov     w0, #112
    bl      rng_mod
    add     w21, w0, #8                 // cx
    mov     w0, #112
    bl      rng_mod
    add     w22, w0, #8                 // cy
    add     w9, w21, w22, lsl #7
    LA      x10, terr
    ldrb    w11, [x10, w9, uxtw]
    cmp     w11, #T_GRASS
    b.ne    pt_try

    // longe o bastante das outras?
    LA      x23, towns
    mov     w12, #0
1:  cmp     w12, w19
    b.ge    2f
    mov     w9, #TOWNSZ
    umaddl  x13, w12, w9, x23
    ldr     w14, [x13]
    sub     w14, w14, w21
    cmp     w14, #0
    cneg    w14, w14, lt
    ldr     w15, [x13, #4]
    sub     w15, w15, w22
    cmp     w15, #0
    cneg    w15, w15, lt
    add     w14, w14, w15
    cmp     w14, #22
    b.lt    pt_try
    add     w12, w12, #1
    b       1b

2:  mov     w9, #TOWNSZ
    umaddl  x23, w19, w9, x23           // registro da cidade
    str     w21, [x23]
    str     w22, [x23, #4]
    mov     w0, #2800
    bl      rng_mod
    add     w27, w0, #250               // populacao
    str     w27, [x23, #8]
    add     x0, x23, #12
    bl      gen_name
    mov     w9, #1100
    udiv    w24, w27, w9
    add     w24, w24, #2                // raio 2..4

    neg     w25, w24                    // dy
3:  neg     w26, w24                    // dx
4:  add     w9, w21, w26
    add     w10, w22, w25
    add     w11, w9, w10, lsl #7        // j
    LA      x12, terr
    ldrb    w13, [x12, w11, uxtw]
    cmp     w13, #T_SAND
    b.lo    6f
    cmp     w13, #T_HILL
    b.hi    6f
    cbz     w26, 5f                     // ruas em cruz no centro
    cbz     w25, 5f
    cmp     w26, #0
    cneg    w14, w26, lt
    cmp     w25, #0
    cneg    w15, w25, lt
    add     w14, w14, w15               // distancia ao centro
    mov     w0, #100
    bl      rng_mod
    mov     w9, #12
    mul     w9, w14, w9
    mov     w10, #95
    sub     w10, w10, w9
    cmp     w0, w10
    b.ge    6f
    mov     w13, #T_HOUSE
    cmp     w14, #2
    b.gt    7f
    mov     w9, #1400
    cmp     w27, w9
    b.le    7f
    mov     w13, #T_TOWER               // centro de cidade grande: predios
    b       7f
5:  mov     w13, #T_ROAD
7:  LA      x12, terr
    strb    w13, [x12, w11, uxtw]
    LA      x12, townid
    add     w9, w19, #1
    strb    w9, [x12, w11, uxtw]
6:  add     w26, w26, #1
    cmp     w26, w24
    b.le    4b
    add     w25, w25, #1
    cmp     w25, w24
    b.le    3b
    add     w19, w19, #1
    b       pt_try

pt_done:
    str     w19, [x28, #G_NTOWNS]
    ldr     x27, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// gen_name(x0 = destino): [prefixo] + 2-3 silabas + [sufixo]
gen_name:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    mov     x19, x0
    mov     w0, #8
    bl      rng_mod
    LA      x1, prefixes
    add     x1, x1, w0, uxtw #3
    mov     x0, x19
    bl      strcat_cur
    mov     x19, x0
    mov     x20, x0                     // inicio do nome (vira maiuscula)
    mov     w0, #2
    bl      rng_mod
    add     w21, w0, #2
1:  mov     w0, #NSYL
    bl      rng_mod
    LA      x1, syls
    add     x1, x1, w0, uxtw #2
    mov     x0, x19
    bl      strcat_cur
    mov     x19, x0
    subs    w21, w21, #1
    b.ne    1b
    ldrb    w9, [x20]
    sub     w9, w9, #32
    strb    w9, [x20]
    mov     w0, #8
    bl      rng_mod
    LA      x1, suffixes
    add     x1, x1, w0, uxtw #3
    mov     x0, x19
    bl      strcat_cur
    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// =====================================================================
//  Entrada (teclado e mouse)
// =====================================================================
handle_events:
    stp     x29, x30, [sp, #-160]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    add     x19, sp, #32                // SDL_Event (128 bytes)
he_loop:
    mov     x0, x19
    bl      F(SDL_PollEvent)
    tst     w0, #0xff
    b.eq    he_done
    ldr     w9, [x19]
    cmp     w9, #SDL_EVENT_QUIT
    b.eq    he_quit
    cmp     w9, #SDL_EVENT_KEY_DOWN
    b.eq    he_key
    mov     w10, #SDL_EVENT_MOUSE_MOTION
    cmp     w9, w10
    b.eq    he_motion
    mov     w10, #SDL_EVENT_MOUSE_WHEEL
    cmp     w9, w10
    b.eq    he_wheel
    b       he_loop

he_quit:
    str     wzr, [x28, #G_RUNNING]
    b       he_loop

he_key:
    ldrb    w9, [x19, #37]              // repeat
    cbnz    w9, he_loop
    ldr     w20, [x19, #24]             // scancode
    ldr     w9, [x28, #G_STATE]
    cbnz    w9, he_key_game
    // --- tela de titulo ---
    cmp     w20, #41                    // ESC
    b.eq    he_quit
    cmp     w20, #40                    // ENTER
    b.eq    he_enter
    cmp     w20, #88                    // ENTER do teclado numerico
    b.eq    he_enter
    cmp     w20, #44                    // ESPACO
    b.eq    he_enter
    cmp     w20, #21                    // R
    b.ne    he_loop
    bl      new_world
    b       he_loop
he_enter:
    mov     w9, #1
    str     w9, [x28, #G_STATE]
    mov     w0, #1
    bl      set_zoom
    str     wzr, [x28, #G_CAMX]
    mov     w9, #1024
    str     w9, [x28, #G_CAMY]
    b       he_loop

he_key_game:
    cmp     w20, #41                    // ESC -> volta ao titulo
    b.ne    1f
    str     wzr, [x28, #G_STATE]
    mov     w0, #2
    bl      set_zoom
    b       he_loop
1:  cmp     w20, #21                    // R -> novo mundo
    b.ne    2f
    bl      new_world
    b       he_loop
2:  cmp     w20, #10                    // G -> grade
    b.ne    3f
    ldr     w9, [x28, #G_GRID]
    eor     w9, w9, #1
    str     w9, [x28, #G_GRID]
    b       he_loop
3:  cmp     w20, #46                    // =/+
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
7:  cmp     w20, #69                    // F12 -> screenshot
    b.ne    he_loop
    mov     w9, #1
    str     w9, [x28, #G_WANTSHOT]
    b       he_loop

he_motion:
    ldr     s0, [x19, #28]
    str     s0, [x28, #G_MX]
    ldr     s0, [x19, #32]
    str     s0, [x28, #G_MY]
    ldr     w9, [x28, #G_STATE]
    cbz     w9, he_loop
    ldr     w9, [x19, #24]              // botoes apertados
    cbz     w9, he_loop
    // arrastar: move a camera (com acumulador de fracao)
    ldr     w9, [x28, #G_FBW]
    scvtf   s1, w9
    mov     w10, #1280
    scvtf   s2, w10
    fdiv    s1, s1, s2
    ldr     s0, [x19, #36]              // xrel
    fmul    s0, s0, s1
    ldr     s3, [x28, #G_DAX]
    fadd    s3, s3, s0
    fcvtzs  w11, s3
    scvtf   s4, w11
    fsub    s3, s3, s4
    str     s3, [x28, #G_DAX]
    ldr     w12, [x28, #G_CAMX]
    sub     w12, w12, w11
    str     w12, [x28, #G_CAMX]
    ldr     s0, [x19, #40]              // yrel
    fmul    s0, s0, s1
    ldr     s3, [x28, #G_DAY]
    fadd    s3, s3, s0
    fcvtzs  w11, s3
    scvtf   s4, w11
    fsub    s3, s3, s4
    str     s3, [x28, #G_DAY]
    ldr     w12, [x28, #G_CAMY]
    sub     w12, w12, w11
    str     w12, [x28, #G_CAMY]
    b       he_loop

he_wheel:
    ldr     s0, [x19, #28]              // y
    ldr     w9, [x19, #32]              // direction
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

// =====================================================================
//  Atualizacao (camera, tile sob o mouse)
// =====================================================================
update:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    ldr     w9, [x28, #G_STATE]
    cbnz    w9, up_game

    // titulo: camera passeia devagar pelo mapa
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
2:  str     w9, [x28, #G_CAMX]
    mov     w9, #1024
    str     w9, [x28, #G_CAMY]
    b       up_done

up_game:
    ldr     x19, [x28, #G_KEYS]
    ldr     w20, [x28, #G_FBW]
    mov     w9, #160
    udiv    w20, w20, w9                // velocidade
    ldr     w10, [x28, #G_CAMX]
    ldr     w11, [x28, #G_CAMY]
    ldrb    w9, [x19, #26]              // W
    ldrb    w12, [x19, #82]             // seta cima
    orr     w9, w9, w12
    cbz     w9, 3f
    sub     w11, w11, w20
3:  ldrb    w9, [x19, #22]              // S
    ldrb    w12, [x19, #81]             // seta baixo
    orr     w9, w9, w12
    cbz     w9, 4f
    add     w11, w11, w20
4:  ldrb    w9, [x19, #4]               // A
    ldrb    w12, [x19, #80]             // seta esquerda
    orr     w9, w9, w12
    cbz     w9, 5f
    sub     w10, w10, w20
5:  ldrb    w9, [x19, #7]               // D
    ldrb    w12, [x19, #79]             // seta direita
    orr     w9, w9, w12
    cbz     w9, 6f
    add     w10, w10, w20
6:  mov     w9, #-2048
    cmp     w10, w9
    csel    w10, w9, w10, lt
    mov     w9, #2048
    cmp     w10, w9
    csel    w10, w9, w10, gt
    cmp     w11, #0
    csel    w11, wzr, w11, lt
    cmp     w11, w9
    csel    w11, w9, w11, gt
    str     w10, [x28, #G_CAMX]
    str     w11, [x28, #G_CAMY]
    bl      calc_hover
up_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// calc_hover: converte o mouse (tela) para o tile isometrico
calc_hover:
    ldr     w9, [x28, #G_FBW]
    ldr     w10, [x28, #G_FBH]
    ldr     s0, [x28, #G_MX]
    scvtf   s1, w9
    fmul    s0, s0, s1
    mov     w11, #1280
    scvtf   s1, w11
    fdiv    s0, s0, s1
    fcvtzs  w0, s0
    ldr     s0, [x28, #G_MY]
    scvtf   s1, w10
    fmul    s0, s0, s1
    mov     w11, #720
    scvtf   s1, w11
    fdiv    s0, s0, s1
    fcvtzs  w1, s0
    sub     w0, w0, w9, lsr #1
    ldr     w11, [x28, #G_CAMX]
    add     w0, w0, w11                 // wx
    sub     w1, w1, w10, lsr #1
    ldr     w11, [x28, #G_CAMY]
    add     w1, w1, w11                 // wy
    mov     w2, #0                      // altura estimada
    mov     w3, #4                      // iteracoes
    LA      x12, level
    mov     w4, #-1
1:  add     w5, w1, w2
    lsl     w6, w5, #1
    add     w7, w0, w6
    sub     w7, w7, #16
    asr     w7, w7, #5                  // tx
    sub     w8, w6, w0
    sub     w8, w8, #16
    asr     w8, w8, #5                  // ty
    cmp     w7, #MAPN
    b.hs    8f
    cmp     w8, #MAPN
    b.hs    8f
    add     w4, w7, w8, lsl #7
    ldrb    w2, [x12, w4, uxtw]
    lsl     w2, w2, #2
    subs    w3, w3, #1
    b.ne    1b
    b       9f
8:  mov     w4, #-1
9:  str     w4, [x28, #G_HOV]
    ret

// =====================================================================
//  Renderizacao por software (isometrica, estilo OpenTTD)
//  Durante o desenho: x27 = framebuffer, w26 = largura, w25 = altura
// =====================================================================

// hline(w0 = x0, w1 = x1 (exclusivo), w2 = y, w3 = cor)  usa x9, x10
hline:
    tbnz    w2, #31, 9f
    cmp     w2, w25
    b.ge    9f
    cmp     w0, #0
    csel    w0, wzr, w0, lt
    cmp     w1, w26
    csel    w1, w26, w1, gt
    cmp     w0, w1
    b.ge    9f
    madd    w9, w2, w26, w0
    add     x9, x27, w9, uxtw #2
    sub     w10, w1, w0
1:  str     w3, [x9], #4
    subs    w10, w10, #1
    b.ne    1b
9:  ret

// vline(w0 = x, w1 = y0, w2 = comprimento, w3 = cor)  usa x9-x11
vline:
    tbnz    w0, #31, 9f
    cmp     w0, w26
    b.ge    9f
    add     w2, w1, w2
    cmp     w1, #0
    csel    w1, wzr, w1, lt
    cmp     w2, w25
    csel    w2, w25, w2, gt
    cmp     w1, w2
    b.ge    9f
    madd    w9, w1, w26, w0
    add     x9, x27, w9, uxtw #2
    sub     w10, w2, w1
    lsl     w11, w26, #2
1:  str     w3, [x9]
    add     x9, x9, x11
    subs    w10, w10, #1
    b.ne    1b
9:  ret

// plot(w0 = x, w1 = y, w3 = cor)
plot:
    mov     w2, w1
    add     w1, w0, #1
    b       hline

// draw_map: limpa o framebuffer e desenha todos os tiles visiveis
draw_map:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     x27, [sp, #80]

    LA      x27, fb
    ldr     w26, [x28, #G_FBW]
    ldr     w25, [x28, #G_FBH]

    mul     w9, w26, w25
    lsr     w9, w9, #1
    MOVI32  w10, 0xFF0E1621             // fundo
    orr     x10, x10, x10, lsl #32
    mov     x11, x27
1:  str     x10, [x11], #8
    subs    w9, w9, #1
    b.ne    1b

    ldr     w9, [x28, #G_CAMX]
    lsr     w23, w26, #1
    sub     w23, w23, w9                // offx
    ldr     w9, [x28, #G_CAMY]
    lsr     w24, w25, #1
    sub     w24, w24, w9                // offy

    mov     w19, #0                     // ty
dm_ty:
    mov     w20, #0                     // tx
dm_tx:
    add     w21, w20, w19, lsl #7       // i
    LA      x9, level
    ldrb    w22, [x9, w21, uxtw]
    lsl     w22, w22, #2                // E = nivel * HSTEP
    sub     w1, w20, w19
    lsl     w1, w1, #4
    add     w1, w1, w23                 // sx
    add     w2, w20, w19
    lsl     w2, w2, #3
    sub     w2, w2, w22
    add     w2, w2, w24                 // sy (vertice de cima)
    cmn     w1, #16
    b.lt    dm_skip
    add     w9, w26, #16
    cmp     w1, w9
    b.gt    dm_skip
    cmp     w2, w25
    b.gt    dm_skip
    add     w9, w2, w22
    add     w9, w9, #30
    cmp     w9, #0
    b.lt    dm_skip
    mov     w0, w21
    mov     w3, w22
    bl      draw_tile
dm_skip:
    add     w20, w20, #1
    cmp     w20, #MAPN
    b.lt    dm_tx
    add     w19, w19, #1
    cmp     w19, #MAPN
    b.lt    dm_ty

    // contorno branco no tile sob o mouse (por cima de tudo)
    ldr     w9, [x28, #G_STATE]
    cbz     w9, dm_end
    ldr     w19, [x28, #G_HOV]
    tbnz    w19, #31, dm_end
    and     w20, w19, #127              // tx
    lsr     w21, w19, #7                // ty
    LA      x9, level
    ldrb    w22, [x9, w19, uxtw]
    lsl     w22, w22, #2
    sub     w9, w20, w21
    lsl     w9, w9, #4
    add     w10, w20, w21
    lsl     w10, w10, #3
    add     w20, w9, w23                // sx
    sub     w10, w10, w22
    add     w21, w10, w24               // sy
    mov     w22, #0
1:  cmp     w22, #8
    b.ge    2f
    lsl     w14, w22, #1
    add     w14, w14, #2
    b       3f
2:  mov     w14, #32
    sub     w14, w14, w22, lsl #1
3:  sub     w0, w20, w14
    add     w1, w21, w22
    mov     w3, #-1
    bl      plot
    add     w0, w20, w14
    sub     w0, w0, #1
    add     w1, w21, w22
    bl      plot
    add     w22, w22, #1
    cmp     w22, #16
    b.lt    1b
dm_end:
    ldr     x27, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// draw_tile(w0 = i, w1 = sx, w2 = sy, w3 = E)
// bloco isometrico: losango 32x16 no topo + duas faces laterais
draw_tile:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    mov     w22, w3
    LA      x9, terr
    ldrb    w23, [x9, w19, uxtw]        // tipo de terreno
    LA      x9, ctab
    add     x24, x9, x23, lsl #4        // cores: topo, esquerda, direita

    // cor do topo com uma leve variacao por tile (agua "brilha")
    LA      x9, jit
    ldrb    w10, [x9, w19, uxtw]
    cmp     w23, #T_SHALLOW
    b.hi    1f
    ldr     w11, [x28, #G_FRAME]
    add     w10, w10, w11, lsr #4
    and     w10, w10, #15
1:  ldr     w9, [x24]
    MOVI32  w11, 0x00080808
    sub     w9, w9, w11
    MOVI32  w11, 0x00010101
    madd    w9, w10, w11, w9
    str     w9, [sp, #64]

    // faces laterais
    add     w15, w22, #6
    mov     w14, #0
2:  sub     w0, w20, #16
    add     w0, w0, w14
    add     w1, w21, #9
    add     w1, w1, w14, lsr #1
    mov     w2, w15
    ldr     w3, [x24, #4]
    bl      vline
    add     w14, w14, #1
    cmp     w14, #16
    b.lt    2b
    mov     w14, #0
3:  add     w0, w20, w14
    add     w1, w21, #16
    sub     w1, w1, w14, lsr #1
    mov     w2, w15
    ldr     w3, [x24, #8]
    bl      vline
    add     w14, w14, #1
    cmp     w14, #16
    b.lt    3b

    // topo (losango)
    mov     w14, #0
4:  cmp     w14, #8
    b.ge    41f
    lsl     w9, w14, #1
    add     w9, w9, #2
    b       42f
41: mov     w9, #32
    sub     w9, w9, w14, lsl #1
42: str     w9, [sp, #68]
    sub     w0, w20, w9
    add     w1, w20, w9
    add     w2, w21, w14
    ldr     w3, [sp, #64]
    bl      hline
    cmp     w14, #8
    b.ge    45f
    ldr     w9, [x28, #G_GRID]
    cbz     w9, 45f
    ldr     w3, [sp, #64]               // grade: borda 25% mais escura
    lsr     w9, w3, #2
    and     w9, w9, #0x3F3F3F3F
    sub     w3, w3, w9
    orr     w3, w3, #0xFF000000
    ldr     w9, [sp, #68]
    sub     w0, w20, w9
    add     w1, w21, w14
    bl      plot
    ldr     w9, [sp, #68]
    add     w0, w20, w9
    sub     w0, w0, #1
    add     w1, w21, w14
    bl      plot
45: add     w14, w14, #1
    cmp     w14, #16
    b.lt    4b

    // enfeites
    cmp     w23, #T_FOREST
    b.eq    dt_trees
    cmp     w23, #T_HOUSE
    b.eq    dt_house
    cmp     w23, #T_TOWER
    b.eq    dt_tower
    b       dt_done

dt_trees:
    mov     w22, #0
5:  mov     w0, w19
    mov     w1, w22
    mov     w2, #0x777
    bl      hash3
    lsr     w10, w0, #4
    and     w10, w10, #1
    mov     w11, #3
    madd    w10, w22, w11, w10
    add     w10, w10, #4                // dy
    and     w9, w0, #15
    sub     w9, w9, #8                  // dx
    add     w0, w20, w9
    add     w1, w21, w10
    bl      draw_tree
    add     w22, w22, #1
    cmp     w22, #3
    b.lt    5b
    b       dt_done

dt_house:
    mov     w0, w19
    mov     w1, #5
    mov     w2, #0x333
    bl      hash3
    mov     w2, w0
    mov     w0, w20
    mov     w1, w21
    bl      draw_house
    b       dt_done

dt_tower:
    mov     w0, w19
    mov     w1, #9
    mov     w2, #0x555
    bl      hash3
    mov     w2, w0
    mov     w0, w20
    mov     w1, w21
    bl      draw_tower

dt_done:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// draw_tree(w0 = x da base, w1 = y da base)
draw_tree:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    sub     w1, w20, #2
    mov     w2, #3
    MOVI32  w3, 0xFF5B3A1E              // tronco
    bl      vline
    mov     w21, #0
1:  LA      x9, tree_w
    ldrb    w22, [x9, x21]
    lsr     w22, w22, #1
    sub     w0, w19, w22
    add     w1, w19, w22
    add     w1, w1, #1
    sub     w2, w20, #9
    add     w2, w2, w21
    MOVI32  w3, 0xFF2E6B2E              // copa
    bl      hline
    sub     w0, w19, w22
    sub     w1, w20, #9
    add     w1, w1, w21
    MOVI32  w3, 0xFF4E9A45              // luz do lado esquerdo
    bl      plot
    add     w21, w21, #1
    cmp     w21, #7
    b.lt    1b
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// draw_house(w0 = sx, w1 = sy, w2 = hash)
draw_house:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    mov     w22, #4                     // paredes
1:  sub     w0, w19, #6
    mov     w1, w19
    add     w2, w20, w22
    MOVI32  w3, 0xFFE8DDC6
    bl      hline
    mov     w0, w19
    add     w1, w19, #6
    add     w2, w20, w22
    MOVI32  w3, 0xFFBFAF92
    bl      hline
    add     w22, w22, #1
    cmp     w22, #12
    b.lt    1b
    and     w9, w21, #3                 // cor do telhado
    LA      x10, roofc
    add     x21, x10, x9, lsl #3
    mov     w22, #0
2:  add     w9, w22, #2
    sub     w0, w19, w9
    mov     w1, w19
    sub     w2, w20, #2
    add     w2, w2, w22
    ldr     w3, [x21]
    bl      hline
    add     w9, w22, #2
    mov     w0, w19
    add     w1, w19, w9
    sub     w2, w20, #2
    add     w2, w2, w22
    ldr     w3, [x21, #4]
    bl      hline
    add     w22, w22, #1
    cmp     w22, #6
    b.lt    2b
    mov     w22, #9                     // porta
3:  sub     w0, w19, #4
    sub     w1, w19, #2
    add     w2, w20, w22
    MOVI32  w3, 0xFF4A3524
    bl      hline
    add     w22, w22, #1
    cmp     w22, #12
    b.lt    3b
    add     w0, w19, #2                 // janela
    add     w1, w19, #4
    add     w2, w20, #7
    MOVI32  w3, 0xFF9FC4E0
    bl      hline
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// draw_tower(w0 = sx, w1 = sy, w2 = hash): predio com janelas acesas
draw_tower:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     w20, w1
    mov     w21, w2
    mov     w22, #-10
1:  sub     w0, w19, #6
    mov     w1, w19
    add     w2, w20, w22
    MOVI32  w3, 0xFFA9B6C6
    bl      hline
    mov     w0, w19
    add     w1, w19, #6
    add     w2, w20, w22
    MOVI32  w3, 0xFF7D8999
    bl      hline
    add     w22, w22, #1
    cmp     w22, #12
    b.lt    1b
    sub     w0, w19, #6
    add     w1, w19, #6
    sub     w2, w20, #11
    MOVI32  w3, 0xFF4F5866
    bl      hline
    mov     w22, #0
2:  lsr     w9, w21, w22
    tst     w9, #1
    MOVI32  w3, 0xFF3C4656
    MOVI32  w10, 0xFFFFE38A
    csel    w3, w10, w3, ne
    sub     w0, w19, #4
    add     w1, w22, w22, lsl #1
    add     w1, w1, w20
    sub     w1, w1, #8
    bl      plot
    sub     w0, w19, #2
    add     w1, w22, w22, lsl #1
    add     w1, w1, w20
    sub     w1, w1, #8
    bl      plot
    add     w9, w22, #8
    lsr     w9, w21, w9
    tst     w9, #1
    MOVI32  w3, 0xFF2E3746
    MOVI32  w10, 0xFFE8C870
    csel    w3, w10, w3, ne
    add     w0, w19, #2
    add     w1, w22, w22, lsl #1
    add     w1, w1, w20
    sub     w1, w1, #8
    bl      plot
    add     w0, w19, #4
    add     w1, w22, w22, lsl #1
    add     w1, w1, w20
    sub     w1, w1, #8
    bl      plot
    add     w22, w22, #1
    cmp     w22, #7
    b.lt    2b
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// =====================================================================
//  Composicao final + interface (texto via SDL_RenderDebugText)
// =====================================================================
draw_all:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      draw_map
    ldr     x0, [x28, #G_TEX]
    mov     x1, #0
    LA      x2, fb
    ldr     w3, [x28, #G_FBW]
    lsl     w3, w3, #2
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
    cbnz    w9, 1f
    bl      draw_title
    b       2f
1:  bl      draw_ui
2:  mov     w0, #1
    bl      setscale
    ldp     x29, x30, [sp], #16
    ret

// setcolor(w0 = r, w1 = g, w2 = b, w3 = a)
setcolor:
    mov     w4, w3
    mov     w3, w2
    mov     w2, w1
    mov     w1, w0
    ldr     x0, [x28, #G_REN]
    b       F(SDL_SetRenderDrawColor)

// setscale(w0 = escala inteira)
setscale:
    scvtf   s0, w0
    fmov    s1, s0
    ldr     x0, [x28, #G_REN]
    b       F(SDL_SetRenderScale)

// fillrect(w0 = x, w1 = y, w2 = w, w3 = h)
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

// text(w0 = x, w1 = y, x2 = texto)
text:
    scvtf   s0, w0
    scvtf   s1, w1
    mov     x1, x2
    ldr     x0, [x28, #G_REN]
    b       F(SDL_RenderDebugText)

// text_center(w0 = largura da area, w1 = y, x2 = texto, w3 = deslocamento)
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

// tela de titulo
draw_title:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w0, #2
    bl      setscale                    // espaco 640x360
    mov     w0, #0
    mov     w1, #0
    mov     w2, #10
    mov     w3, #120
    bl      setcolor
    mov     w0, #0
    mov     w1, #0
    mov     w2, #640
    mov     w3, #360
    bl      fillrect

    mov     w0, #8
    bl      setscale                    // espaco 160x90 (letras grandes)
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
    tbnz    w9, #5, 1f                  // pisca
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

// interface do jogo
draw_ui:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     w0, #2
    bl      setscale
    bl      draw_town_labels
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
    bl      build_status
    mov     w0, #255
    mov     w1, #255
    mov     w2, #255
    mov     w3, #255
    bl      setcolor
    mov     w0, #4
    mov     w1, #2
    LA      x2, txt
    bl      text
    mov     w0, #0
    mov     w1, #0
    mov     w2, #0
    mov     w3, #180
    bl      setcolor
    mov     w0, #0
    mov     w1, #348
    mov     w2, #640
    mov     w3, #12
    bl      fillrect
    mov     w0, #200
    mov     w1, #200
    mov     w2, #200
    mov     w3, #255
    bl      setcolor
    mov     w0, #4
    mov     w1, #350
    LA      x2, s_help
    bl      text
    ldp     x29, x30, [sp], #16
    ret

// build_status: monta a linha de cima em txt
build_status:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    LA      x0, txt
    LA      x1, s_world
    bl      strcat_cur
    ldr     w1, [x28, #G_SEED]
    bl      numcat
    ldr     w19, [x28, #G_HOV]
    tbnz    w19, #31, bs_done
    LA      x1, s_sep_paren
    bl      strcat_cur
    and     w1, w19, #127
    bl      numcat
    LA      x1, s_comma
    bl      strcat_cur
    lsr     w1, w19, #7
    bl      numcat
    LA      x1, s_paren_sp
    bl      strcat_cur
    LA      x9, terr
    ldrb    w9, [x9, w19, uxtw]
    LA      x1, tnames
    add     x1, x1, x9, lsl #4
    bl      strcat_cur
    LA      x1, s_alt
    bl      strcat_cur
    LA      x9, level
    ldrb    w1, [x9, w19, uxtw]
    bl      numcat
    LA      x9, townid
    ldrb    w20, [x9, w19, uxtw]
    cbz     w20, bs_done
    sub     w20, w20, #1
    LA      x9, towns
    mov     w10, #TOWNSZ
    umaddl  x20, w20, w10, x9
    LA      x1, s_sep
    bl      strcat_cur
    add     x1, x20, #12
    bl      strcat_cur
    LA      x1, s_dash
    bl      strcat_cur
    ldr     w1, [x20, #8]
    bl      numcat
    LA      x1, s_hab
    bl      strcat_cur
bs_done:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// draw_town_labels: placa com o nome em cima de cada cidade
draw_town_labels:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    ldr     w24, [x28, #G_NTOWNS]
    ldr     w25, [x28, #G_FBW]
    ldr     w26, [x28, #G_FBH]
    mov     w19, #0
1:  cmp     w19, w24
    b.ge    9f
    LA      x9, towns
    mov     w10, #TOWNSZ
    umaddl  x20, w19, w10, x9
    ldr     w9, [x20]                   // tx
    ldr     w10, [x20, #4]              // ty
    add     w11, w9, w10, lsl #7
    LA      x12, level
    ldrb    w11, [x12, w11, uxtw]
    lsl     w11, w11, #2                // E
    sub     w12, w9, w10
    lsl     w12, w12, #4
    add     w12, w12, w25, lsr #1
    ldr     w13, [x28, #G_CAMX]
    sub     w21, w12, w13               // sx no framebuffer
    add     w12, w9, w10
    lsl     w12, w12, #3
    sub     w12, w12, w11
    add     w12, w12, w26, lsr #1
    ldr     w13, [x28, #G_CAMY]
    sub     w22, w12, w13               // sy no framebuffer
    mov     w9, #640
    mul     w21, w21, w9
    sdiv    w21, w21, w25               // -> espaco de texto 640x360
    mov     w9, #360
    mul     w22, w22, w9
    sdiv    w22, w22, w26
    sub     w22, w22, #16
    add     x0, x20, #12
    bl      mystrlen
    lsl     w23, w0, #3                 // largura do texto
    mov     w0, #0
    mov     w1, #0
    mov     w2, #0
    mov     w3, #160
    bl      setcolor
    sub     w0, w21, w23, lsr #1
    sub     w0, w0, #3
    sub     w1, w22, #3
    add     w2, w23, #6
    mov     w3, #13
    bl      fillrect
    mov     w0, #255
    mov     w1, #255
    mov     w2, #255
    mov     w3, #255
    bl      setcolor
    sub     w0, w21, w23, lsr #1
    mov     w1, w22
    add     x2, x20, #12
    bl      text
    add     w19, w19, #1
    b       1b
9:  ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// =====================================================================
//  Dados
// =====================================================================
    .data
    .p2align 4
G:  .space 144

// cores por terreno: topo, face esquerda, face direita, (livre)  ARGB
    .p2align 4
ctab:
    .word 0xFF1F4F8F, 0xFF173B6B, 0xFF122F56, 0    // mar profundo
    .word 0xFF3274B5, 0xFF173B6B, 0xFF122F56, 0    // agua rasa
    .word 0xFFE0CC8A, 0xFFB59C5E, 0xFF957F4A, 0    // praia
    .word 0xFF62A83E, 0xFF8B6B42, 0xFF6E5233, 0    // campo
    .word 0xFF4C8C34, 0xFF8B6B42, 0xFF6E5233, 0    // floresta
    .word 0xFF7E9A4A, 0xFF8B6B42, 0xFF6E5233, 0    // colinas
    .word 0xFF8E877E, 0xFF6F6961, 0xFF55504A, 0    // rocha
    .word 0xFFEEF2F6, 0xFF6F6961, 0xFF55504A, 0    // neve
    .word 0xFF8A8A88, 0xFF8B6B42, 0xFF6E5233, 0    // rua
    .word 0xFF6FA548, 0xFF8B6B42, 0xFF6E5233, 0    // casas
    .word 0xFF9A9A96, 0xFF8B6B42, 0xFF6E5233, 0    // predios

// telhados: claro, escuro
roofc:
    .word 0xFFB5443A, 0xFF8C3029
    .word 0xFF8A5A3A, 0xFF6A4228
    .word 0xFF5C6E86, 0xFF45546A
    .word 0xFFC8693A, 0xFF9C4E2A

tree_w:
    .byte 1, 3, 3, 5, 5, 7, 5, 0

// nomes de terreno (16 bytes cada)
    .p2align 4
tnames:
    .asciz "Mar profundo"
    .p2align 4
    .asciz "Agua rasa"
    .p2align 4
    .asciz "Praia"
    .p2align 4
    .asciz "Campo"
    .p2align 4
    .asciz "Floresta"
    .p2align 4
    .asciz "Colinas"
    .p2align 4
    .asciz "Rocha"
    .p2align 4
    .asciz "Neve"
    .p2align 4
    .asciz "Rua"
    .p2align 4
    .asciz "Casas"
    .p2align 4
    .asciz "Predios"
    .p2align 4

// prefixos e sufixos de cidade (8 bytes cada)
prefixes:
    .asciz "Vila "
    .p2align 3
    .asciz "Porto "
    .p2align 3
    .asciz "Santa "
    .p2align 3
    .asciz "Sao "
    .p2align 3
    .asciz "Nova "
    .p2align 3
    .asciz ""
    .p2align 3
    .asciz ""
    .p2align 3
    .asciz ""
    .p2align 3
suffixes:
    .asciz ""
    .p2align 3
    .asciz ""
    .p2align 3
    .asciz ""
    .p2align 3
    .asciz " do Sul"
    .p2align 3
    .asciz " Alegre"
    .p2align 3
    .asciz "polis"
    .p2align 3
    .asciz ""
    .p2align 3
    .asciz " Velha"
    .p2align 3

// silabas (4 bytes cada)
syls:
    .asciz "ba"
    .p2align 2
    .asciz "ca"
    .p2align 2
    .asciz "da"
    .p2align 2
    .asciz "ga"
    .p2align 2
    .asciz "ja"
    .p2align 2
    .asciz "la"
    .p2align 2
    .asciz "ma"
    .p2align 2
    .asciz "na"
    .p2align 2
    .asciz "pa"
    .p2align 2
    .asciz "ra"
    .p2align 2
    .asciz "sa"
    .p2align 2
    .asciz "ta"
    .p2align 2
    .asciz "va"
    .p2align 2
    .asciz "ri"
    .p2align 2
    .asciz "to"
    .p2align 2
    .asciz "lu"
    .p2align 2
    .asciz "po"
    .p2align 2
    .asciz "ne"
    .p2align 2
    .asciz "mi"
    .p2align 2
    .asciz "bo"
    .p2align 2
    .asciz "cu"
    .p2align 2
    .asciz "ju"
    .p2align 2
    .asciz "te"
    .p2align 2
    .asciz "gua"
    .p2align 2
    .asciz "tin"
    .p2align 2
    .asciz "bor"
    .p2align 2
    .asciz "cam"
    .p2align 2
    .asciz "bel"
    .p2align 2
    .asciz "pir"
    .p2align 2
    .asciz "itu"
    .p2align 2
    .asciz "rio"
    .p2align 2
    .asciz "nho"
    .p2align 2

s_wintitle:   .asciz "Trilhos - jogo de trens em Assembly ARM64"
s_title:      .asciz "TRILHOS"
s_sub:        .asciz "um jogo de trens escrito em assembly ARM64"
s_world:      .asciz "Mundo #"
s_enter:      .asciz "Pressione ENTER para entrar neste mundo"
s_title_help: .asciz "R: gerar outro mundo     ESC: sair"
s_credit:     .asciz "feito por Andre + Claude"
s_help:       .asciz "WASD/setas/arrastar: mover   roda/+/-: zoom   G: grade   R: novo   ESC: menu"
s_sep_paren:  .asciz "   -   ("
s_comma:      .asciz ","
s_paren_sp:   .asciz ")  "
s_alt:        .asciz ", altura "
s_sep:        .asciz "   -   "
s_dash:       .asciz " - "
s_hab:        .asciz " hab."
s_nl:         .asciz "\n"
s_shot_f12:   .asciz "trilhos.bmp"
s_shot_title: .asciz "shot_titulo.bmp"
s_shot_game:  .asciz "shot_jogo.bmp"
s_shot_far:   .asciz "shot_longe.bmp"
s_shot_near:  .asciz "shot_perto.bmp"

// ---- memoria zerada (bss) -------------------------------------------
BSS(hmap,   16384)
BSS(moist,  16384)
BSS(level,  16384)
BSS(terr,   16384)
BSS(jit,    16384)
BSS(townid, 16384)
BSS(accum,  65536)
BSS(towns,  768)
BSS(txt,    256)
BSS(fb,     3686400)
