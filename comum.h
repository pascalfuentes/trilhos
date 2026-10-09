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
.equ MAXTOWNS,  16
.equ TOWNSZ,    64           // x y pop nome[32] R e
.equ NSYL,      32
.equ MAXOBJ,    200000
.equ SEA,       104          // altura do nivel do mar (0..255)

// faixas de elevacao (1/16 de pixel do mundo)
.equ E_SAND,    30
.equ E_GRASS,   724
.equ E_HILL,    1056
.equ E_ROCK,    1424

// tipos de objeto / sprites
.equ O_TREE,    0
.equ O_PINE,    1
.equ O_HOUSE,   2
.equ O_TOWER,   3
.equ SPR_STATION, 4
.equ SPR_SIG_GREEN, 5
.equ SPR_SIG_RED,   6

// ---- ferrovia -----------------------------------------------------------
.equ MAXNODE,   2048         // no:       64 bytes
.equ MAXSEG,    2048         // trilho:  128 bytes
.equ MAXSAMP,   131072       // amostra:  32 bytes
.equ MAXST,     32           // estacao:  64 bytes
.equ MAXSIG,    256          // sinal:    16 bytes
.equ MAXTRAIN,  64           // trem:    128 bytes
.equ MAXPIECE,  10240

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
.equ G_HOVU,     80          // 1/64 de celula
.equ G_HOVV,     84
.equ G_CONTOUR,  88
.equ G_DAX,      92          // float
.equ G_DAY,      96          // float
.equ G_WHEEL,    100         // float
.equ G_NTOWNS,   104
.equ G_SHOT,     108
.equ G_WANTSHOT, 112
.equ G_NOBJ,     116
.equ G_EMAXZ,    120         // altura maxima em pixels de tela
.equ G_K,        124         // 1/16 px do mundo por pixel de tela
.equ G_TOOL,     128         // 0 nenhuma, 1 trilho, 2 estacao, 3 sinal, 4 trem, 5 demolir
.equ G_DOWNX,    136         // float: onde o botao foi apertado
.equ G_DOWNY,    140
.equ G_DRAGGED,  144
.equ G_CHAIN,    148         // no onde o proximo trilho comeca (-1)
.equ G_MSGT,     152         // tempo restante da mensagem
.equ G_MSG,      160         // ponteiro da mensagem
.equ G_NNODE,    168
.equ G_NSEG,     172
.equ G_NST,      176
.equ G_NSIG,     180
.equ G_NTRAIN,   184
.equ G_PAX,      188         // passageiros entregues
.equ G_TRSEL,    192         // trem recebendo paradas (-1)
.equ G_NETDIRTY, 196
.equ G_PAUSE,    200
.equ G_NSAMP,    204
.equ G_NPIECE,   208
.equ G_SIMFRAME, 212
.equ GSIZE,      256

// ---- constantes float (offsets na tabela fconsts, em ferrovia.S) --------
.equ F_64,       0
.equ F_INV64,    4
.equ F_STEP,     8
.equ F_BALLAST,  12
.equ F_RAIL,     16
.equ F_SLEEPER,  20
.equ F_PIN,      24
.equ F_POUT,     28
.equ F_THIRD,    32
.equ F_SNAP2,    36
.equ F_SEGHIT2,  40
.equ F_VMAX,     44
.equ F_ACC,      48
.equ F_DEC,      52
.equ F_HL,       56
.equ F_HW,       60
.equ F_VSP,      64
.equ F_TLEN,     68
.equ F_STHALF,   72
.equ F_LOOK,     76
.equ F_SIGM,     80
.equ F_INF,      84
.equ F_MINDOT,   88
.equ F_MINLEN,   92
.equ F_MAXLEN,   96
.equ F_SIGOFF,   100
.equ F_STOFF,    104
.equ F_HALF,     108
.equ F_M005,     112
.equ F_TENTH,    116
.equ F_STLEN,    120
.equ F_EDGE,     124
.equ F_STHIT2,   128
.equ F_TRHIT2,   132
.equ F_HUGE,     136
.equ F_STOPEPS,  140
.equ F_STMIN,    144
.equ F_CLEAR2,   148
.equ F_SIGHIT2,  152
