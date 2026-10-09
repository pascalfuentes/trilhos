// =====================================================================
//  pessoas.h - estruturas da vila (pessoas.S e vila.S)
// =====================================================================

.macro RGBA r, g, b, a
    mov     w0, #\r
    mov     w1, #\g
    mov     w2, #\b
    mov     w3, #\a
    bl      setcolor
.endm

// constante float da tabela pconst (pessoas.S; usa x16)
.macro PF sreg, off
    LA      x16, pconst
    ldr     \sreg, [x16, #\off]
.endm

// pessoa (64 bytes, vetor people)
.equ P_U,      0                // posicao (float, celulas)
.equ P_V,      4
.equ P_GU,     8                // para onde vai
.equ P_GV,     12
.equ P_ALIVE,  16               // 1 = viva
.equ P_SEX,    17               // 0 homem, 1 mulher
.equ P_FAM,    18               // casa (familia que mora junto) 0..MAXFAM-1
.equ P_JOB,    19               // tarefa (J_*)
.equ P_AGE,    20               // u16: idade em dias (12 dias = 1 ano)
.equ P_STATE,  22               // ST_*
.equ P_NEXT,   23               // o que fazer ao chegar (NX_*)
.equ P_TIMER,  24               // u16
.equ P_ANIM,   26               // u16
.equ P_TARGET, 28               // objeto, celula ou obra (0x10000 + casa) (-1)
.equ P_HP,     32               // vida (float 0..100)
.equ P_FOOD,   36               // fome (float 0..100; 100 = cheio)
.equ P_FAITH,  40               // fe (float 0..100)
.equ P_NAME,   44               // nome (0..23)
.equ P_CITEM,  45               // item carregado + 1
.equ P_CCOUNT, 46               // quantos
.equ P_SEEDS,  47               // sementes no bolso
.equ P_FLAGS,  48               // 1 dentro de casa, 2 perto do fogo, 4 desvia pela esquerda
.equ P_WKIND,  49               // tipo de trabalho (WK_*)
.equ P_SKIPK,  50               // tipo do trabalho que nao conseguiu alcancar
.equ P_BFAM,   51               // obras: para que casa
.equ P_BLOCK,  52               // u16: quadros travado
.equ P_THINK,  54               // u16: espera para pensar de novo
.equ P_SKIP,   56               // alvo que nao conseguiu alcancar (pula)
.equ P_DET,    60               // u16: quadros desviando
.equ P_BPROJ,  62               // obras: qual (B_*)

// parentesco (8 bytes por pessoa, vetor kin; fica depois que morre)
.equ K_FATHER, 0                // pai (255 = nao se sabe)
.equ K_MOTHER, 1                // mae
.equ K_SPOUSE, 2                // conjuge (255 = solteiro)
.equ K_REC,    3                // 0 vaga livre, 1 viva, 2 morreu, 3 foi embora
.equ K_SURN,   4                // sobrenome (do pai)
.equ K_CAUSE,  5                // causa da morte

// casa de uma familia (32 bytes, vetor fams)
.equ F_USED,   0                // 1 = existe
.equ F_LEVEL,  1                // 0 sem casa, 1 barraco, 2 casa
.equ F_FENCE,  2                // 1 = terreno cercado
.equ F_VAR,    3                // cor (telhado e roupa)
.equ F_HOUSE,  4                // objeto da casa (-1)
.equ F_LOT,    8                // celula do canto do terreno 5 x 5 (-1)
.equ F_PAID,   12               // obra paga (B_*; 0 nenhuma)
.equ F_PROG,   13               // passos feitos da obra
.equ F_SURN,   14               // sobrenome
.equ FSIZE,    32
.equ MAXFAM,   16
.equ LOTN,     5                // terreno 5 x 5 (casa 2 x 2 no meio, cerca na volta)

.equ B_HUT,    1                // obras: barraco, casa, cerca
.equ B_HOUSE,  2
.equ B_FENCE,  3

.equ ST_IDLE,  0
.equ ST_WALK,  1
.equ ST_WORK,  2
.equ ST_SLEEP, 3
.equ ST_WAIT,  4
.equ ST_FLEE,  5

.equ NX_NONE,    0
.equ NX_WORK,    1
.equ NX_DEPOSIT, 2
.equ NX_EAT,     3
.equ NX_SEEDS,   4
.equ NX_SLEEP,   5
.equ NX_ORDER,   6
.equ NX_PAY,     7              // obras: pega o material no bau

.equ WK_CHOP,    1
.equ WK_MINE,    2
.equ WK_HARV,    3
.equ WK_PLANT,   4
.equ WK_TILL,    5
.equ WK_SAPLING, 6
.equ WK_FORAGE,  7
.equ WK_BUILD,   8

.equ CAUSE_FOME,  1
.equ CAUSE_FRIO,  2
.equ CAUSE_BICHO, 3
.equ CAUSE_VELHO, 4
.equ CAUSE_FE,    5

.equ ADULTDAYS,  168            // 14 anos: trabalha
.equ BEDTIME,    27000          // 21:00: hora de ir dormir
.equ MARRYDAYS,  192            // 16 anos: pode casar
.equ FERTEND,    540            // 45 anos
.equ TREEYEAR,   12             // dias para a muda virar jovem e a jovem, adulta
.equ NSURN,      3              // sobrenomes (linhagens)
