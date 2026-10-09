// =====================================================================
//  comum.h - macros e constantes compartilhadas por todos os modulos
//  (incluido com #include no topo de cada arquivo .S)
// =====================================================================

// ---- diferencas entre macOS (Mach-O) e Linux (ELF) ------------------
#ifdef __APPLE__
#define F(x) _##x
#else
#define F(x) x
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

// carrega uma constante float da tabela fconsts (usa x16)
.macro FC sreg, off
    LA      x16, fconsts
    ldr     \sreg, [x16, #\off]
.endm

// memoria zerada, visivel para os outros modulos
.macro GBSS name, size
    .globl  \name
#ifdef __APPLE__
    .zerofill __DATA,__bss,\name,\size,4
#else
    .section .bss
    .balign 16
\name:
    .space  \size
#endif
.endm

// ---- mundo ------------------------------------------------------------
.equ MAPN,      512          // mapa de altura 512 x 512
.equ SCRW,      1280
.equ SCRH,      720
.equ MAXOBJ,    200000
.equ SEA,       104          // altura do nivel do mar (0..255)

// faixas de elevacao (1/16 de pixel do mundo)
.equ E_SAND,    30
.equ E_GRASS,   724
.equ E_HILL,    1056
.equ E_ROCK,    1424

// tipos de objeto (= numero do sprite)
.equ O_TREE,    0            // arvore: madeira
.equ O_PINE,    1            // pinheiro: madeira
.equ O_ROCK,    2            // pedra
.equ O_BUSH,    3            // arbusto com frutas
.equ O_BUSHE,   4            // arbusto sem frutas
.equ O_GONE,    255          // removido
.equ SPR_FIRE,  5            // 5 e 6: fogueira (2 quadros)
.equ SPR_PLAYER, 7           // 7 e 8: personagem (2 quadros)

// ---- sobrevivencia ---------------------------------------------------------
.equ MAXFIRE,   32           // fogueira: 16 bytes (u, v, e, lenha)
.equ DAYLEN,    10800        // quadros por dia (3 minutos)
.equ T_DUSK,    5400         // 18:00
.equ T_NIGHT,   6480         // 20:24
.equ T_DAWN,    9720         // 05:36

// ---- estado global: x28 aponta sempre para G ----------------------------
.equ G_REN,      0
.equ G_WIN,      8
.equ G_TEX,      16
.equ G_KEYS,     24
.equ G_CX,       32          // camera (1/16 px do mundo, zoom 1)
.equ G_CY,       36
.equ G_ZOOM,     40          // 0..3
.equ G_Z256,     44          // escala * 256 (128, 256, 512, 1024)
.equ G_SEED,     48
.equ G_RNG,      52
.equ G_STATE,    56          // 0 = titulo, 1 = jogo
.equ G_RUNNING,  60
.equ G_FRAME,    64
.equ G_MX,       68          // float
.equ G_MY,       72          // float
.equ G_HOVOK,    76
.equ G_HOVU,     80          // ponto do mundo sob o mouse (1/64 de celula)
.equ G_HOVV,     84
.equ G_CONTOUR,  88
.equ G_WHEEL,    100         // float
.equ G_SHOT,     108
.equ G_WANTSHOT, 112
.equ G_NOBJ,     116
.equ G_EMAXZ,    120         // altura maxima em pixels de tela
.equ G_K,        124         // 1/16 px do mundo por pixel de tela
.equ G_PU,       128         // personagem: posicao (float, celulas)
.equ G_PV,       132
.equ G_PE,       136         // elevacao sob o personagem
.equ G_PFRAME,   140         // contador de animacao
.equ G_PMOVING,  144
.equ G_HP,       148         // vida (float 0..100)
.equ G_FOOD,     152         // fome (float 0..100, 100 = satisfeito)
.equ G_WARM,     156         // calor (float 0..100)
.equ G_WOOD,     160         // inventario
.equ G_STONE,    164
.equ G_BERRY,    168
.equ G_TIME,     172         // quadro dentro do dia
.equ G_DAY,      176
.equ G_LMB,      180         // botao esquerdo apertado
.equ G_MINEOBJ,  184         // objeto sendo coletado (-1)
.equ G_MINEPROG, 188
.equ G_HOVOBJ,   192         // objeto sob o mouse (-1)
.equ G_NFIRE,    196
.equ G_DEAD,     200
.equ G_AMBR,     204         // luz ambiente (0..256 por canal)
.equ G_AMBG,     208
.equ G_AMBB,     212
.equ G_MSGT,     216         // tempo restante da mensagem
.equ G_MSG,      224         // ponteiro da mensagem
.equ G_PAUSE,    232
.equ G_NEARFIRE, 236
.equ G_MINENEED, 240
.equ G_HOVFIRE,  244         // fogueira sob o mouse (-1)
.equ G_POPT,     248         // texto flutuante: tempo
.equ G_POPMSG,   256         // texto flutuante: ponteiro
.equ G_WARNED,   264         // ja avisou que esta escurecendo hoje
.equ G_INGAME,   268         // existe uma partida em andamento
.equ GSIZE,      272

// ---- constantes float (offsets na tabela fconsts, em sobrevivencia.S) ---
.equ F_64,       0
.equ F_INV64,    4
.equ F_SPEED,    8
.equ F_REACH2,   12
.equ F_FOODRATE, 16
.equ F_COLD,     20
.equ F_HEAT,     24
.equ F_DAYWARM,  28
.equ F_STARVE,   32
.equ F_FREEZE,   36
.equ F_REGEN,    40
.equ F_HUNDRED,  44
.equ F_FIRE2,    48
.equ F_FORTY,    52
.equ F_EAT,      56
