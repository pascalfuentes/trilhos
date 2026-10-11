// =====================================================================
//  salvar.S - salvar e carregar o jogo (F5 / F9) num arquivo ermo.sav
//
//  O mundo (relevo, umidade, luz) sai da semente: ao carregar ele e
//  gerado de novo e depois o que muda e lido do arquivo: o estado G, os
//  objetos, as grades (terra arada, o que voce ja viu, cercas, zonas,
//  caminhos, buracos de pedreira), os animais, as fogueiras, os baus, as
//  pessoas da vila, as mochilas, o parentesco e as casas.
//
//  Arquivo: cabecalho de 32 bytes ("ERMOSAV1", versao, semente, dia,
//  objetos, tamanho de G) e os blocos na ordem da tabela savtab.
// =====================================================================

#include "comum.h"
#include "pessoas.h"

.equ SAVVER,    1
.equ HDRSIZE,   32

    .text
    .p2align 2

// sav_total(w0 = objetos) -> x0 = tamanho do arquivo   folha
sav_total:
    mov     x9, #(HDRSIZE + GSIZE)
    mov     x10, #9                     // 8 bytes do objeto + memtype
    madd    x9, x0, x10, x9
    LA      x10, savtab
1:  ldr     x11, [x10], #16
    cbz     x11, 2f
    ldur    x11, [x10, #-8]
    add     x9, x9, x11
    b       1b
2:  mov     x0, x9
    ret

// save_probe -> w0 = 1 se tem um jogo salvo (le semente e dia em savinfo)
    .globl save_probe
save_probe:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    LA      x9, savinfo
    str     wzr, [x9]
    LA      x0, savpath
    ldr     x0, [x0]
    LA      x1, s_rb
    bl      F(fopen)
    cbz     x0, 8f
    mov     x19, x0
    LA      x0, hdr
    mov     x1, #1
    mov     x2, #HDRSIZE
    mov     x3, x19
    bl      F(fread)
    mov     x9, x0
    mov     x0, x19
    str     x9, [sp, #24]
    bl      F(fclose)
    ldr     x9, [sp, #24]
    cmp     x9, #HDRSIZE
    b.ne    8f
    bl      hdr_ok
    cbz     w0, 8f
    LA      x9, hdr
    LA      x10, savinfo
    mov     w11, #1
    str     w11, [x10]
    ldr     w11, [x9, #12]              // semente
    str     w11, [x10, #4]
    ldr     w11, [x9, #16]              // dia
    str     w11, [x10, #8]
    mov     w0, #1
    b       9f
8:  mov     w0, #0
9:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// hdr_ok -> w0 = 1 se o cabecalho em hdr e deste jogo   folha
hdr_ok:
    LA      x9, hdr
    LA      x10, s_magic
    ldr     x11, [x9]
    ldr     x12, [x10]
    cmp     x11, x12
    b.ne    8f
    ldr     w11, [x9, #8]
    cmp     w11, #SAVVER
    b.ne    8f
    ldr     w11, [x9, #24]
    cmp     w11, #GSIZE
    b.ne    8f
    ldr     w11, [x9, #20]              // objetos
    MOVI32  w12, MAXOBJ
    cmp     w11, w12
    b.hi    8f
    mov     w0, #1
    ret
8:  mov     w0, #0
    ret

// save_title: na tela de titulo, se tem jogo salvo, mostra o mundo dele
    .globl save_title
save_title:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      save_probe
    cbz     w0, 9f
    LA      x9, savinfo
    ldr     w9, [x9, #4]
    str     w9, [x28, #G_SEED]
    str     wzr, [x28, #G_INGAME]
    bl      generate_map
    str     wzr, [x28, #G_CX]
    mov     w9, #16384
    str     w9, [x28, #G_CY]
9:  ldp     x29, x30, [sp], #16
    ret

// save_game: F5 (nao da morto nem dormindo) -> w0 = 1 se salvou
    .globl save_game
save_game:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    ldr     w9, [x28, #G_STATE]
    cbz     w9, 80f
    LA      x0, m_nodead
    ldr     w9, [x28, #G_DEAD]
    cbnz    w9, 70f
    LA      x0, m_nosleep
    ldr     w9, [x28, #G_SLEEP]
    cbnz    w9, 70f
    LA      x0, savpath
    ldr     x0, [x0]
    LA      x1, s_wb
    bl      F(fopen)
    LA      x9, m_savefail
    cbz     x0, 71f
    mov     x19, x0
    LA      x9, savbad
    str     wzr, [x9]
    // cabecalho
    LA      x20, hdr
    LA      x9, s_magic
    ldr     x9, [x9]
    str     x9, [x20]
    mov     w9, #SAVVER
    str     w9, [x20, #8]
    ldr     w9, [x28, #G_SEED]
    str     w9, [x20, #12]
    ldr     w9, [x28, #G_DAY]
    str     w9, [x20, #16]
    ldr     w9, [x28, #G_NOBJ]
    str     w9, [x20, #20]
    mov     w9, #GSIZE
    str     w9, [x20, #24]
    str     wzr, [x20, #28]
    mov     x0, x20
    mov     x1, #HDRSIZE
    bl      sav_write
    mov     x0, x28                     // o estado G
    mov     x1, #GSIZE
    bl      sav_write
    LA      x0, objs                    // objetos e como foram vistos
    ldr     w1, [x28, #G_NOBJ]
    lsl     x1, x1, #3
    bl      sav_write
    LA      x0, memtype
    ldr     w1, [x28, #G_NOBJ]
    bl      sav_write
    LA      x21, savtab                 // o resto
1:  ldp     x0, x1, [x21], #16
    cbz     x0, 2f
    bl      sav_write
    b       1b
2:  mov     x0, x19
    bl      F(fclose)
    LA      x9, savbad
    ldr     w9, [x9]
    LA      x0, m_savefail
    cbnz    w9, 70f
    bl      save_probe
    LA      x0, msgbuf2                 // "Jogo salvo (Dia 3)"
    LA      x1, m_saved
    bl      strcat_cur
    ldr     w1, [x28, #G_DAY]
    bl      numcat
    LA      x1, s_close
    bl      strcat_cur
    LA      x0, msgbuf2
    bl      set_msg
    mov     w0, #1
    b       90f
71: mov     x0, x9
70: bl      set_msg
80: mov     w0, #0
90: ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// sav_write(x0 = dados, x1 = bytes) no arquivo x19; erro marca savbad
sav_write:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x1, [sp, #16]
    cbz     x1, 9f
    mov     x2, x1
    mov     x1, #1
    mov     x3, x19
    bl      F(fwrite)
    ldr     x1, [sp, #16]
    cmp     x0, x1
    b.eq    9f
    LA      x9, savbad
    mov     w10, #1
    str     w10, [x9]
9:  ldp     x29, x30, [sp], #32
    ret

// sav_read(x0 = dados, x1 = bytes) do arquivo x19; erro marca savbad
sav_read:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x1, [sp, #16]
    cbz     x1, 9f
    mov     x2, x1
    mov     x1, #1
    mov     x3, x19
    bl      F(fread)
    ldr     x1, [sp, #16]
    cmp     x0, x1
    b.eq    9f
    LA      x9, savbad
    mov     w10, #1
    str     w10, [x9]
9:  ldp     x29, x30, [sp], #32
    ret

// load_game: F9 (ou C no titulo) -> w0 = 1 se carregou
    .globl load_game
load_game:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    LA      x9, savbad
    str     wzr, [x9]
    LA      x0, savpath
    ldr     x0, [x0]
    LA      x1, s_rb
    bl      F(fopen)
    LA      x9, m_nosave
    cbz     x0, 71f
    mov     x19, x0
    LA      x0, hdr                     // cabecalho e tamanho certos?
    mov     x1, #HDRSIZE
    bl      sav_read
    LA      x9, savbad
    ldr     w9, [x9]
    cbnz    w9, 60f
    bl      hdr_ok
    cbz     w0, 60f
    mov     x0, x19                     // tamanho do arquivo
    mov     x1, #0
    mov     w2, #2                      // SEEK_END
    bl      F(fseek)
    mov     x0, x19
    bl      F(ftell)
    mov     x20, x0
    LA      x9, hdr
    ldr     w0, [x9, #20]
    bl      sav_total
    cmp     x0, x20
    b.ne    60f
    mov     x0, x19
    mov     x1, #HDRSIZE
    mov     w2, #0                      // SEEK_SET
    bl      F(fseek)
    // o mundo da semente
    LA      x9, hdr
    ldr     w9, [x9, #12]
    str     w9, [x28, #G_SEED]
    bl      generate_map
    // o estado G (menos o que e desta execucao)
    ldr     x20, [x28, #G_REN]
    ldr     x21, [x28, #G_WIN]
    ldr     x22, [x28, #G_TEX]
    ldr     x23, [x28, #G_KEYS]
    LA      x24, gkeep
    ldr     w9, [x28, #G_FRAME]
    str     w9, [x24]
    ldr     x9, [x28, #G_MX]            // G_MX e G_MY
    str     x9, [x24, #8]
    ldr     w9, [x28, #G_SHOT]
    str     w9, [x24, #16]
    ldr     w9, [x28, #G_FULL]
    str     w9, [x24, #20]
    mov     x0, x28
    mov     x1, #GSIZE
    bl      sav_read
    str     x20, [x28, #G_REN]
    str     x21, [x28, #G_WIN]
    str     x22, [x28, #G_TEX]
    str     x23, [x28, #G_KEYS]
    ldr     w9, [x24]
    str     w9, [x28, #G_FRAME]
    ldr     x9, [x24, #8]
    str     x9, [x28, #G_MX]
    ldr     w9, [x24, #16]
    str     w9, [x28, #G_SHOT]
    ldr     w9, [x24, #20]
    str     w9, [x28, #G_FULL]
    mov     w9, #1
    str     w9, [x28, #G_RUNNING]
    str     w9, [x28, #G_STATE]
    str     w9, [x28, #G_INGAME]
    // textos sao ponteiros desta execucao: limpa
    str     wzr, [x28, #G_MSGT]
    str     xzr, [x28, #G_MSG]
    str     wzr, [x28, #G_POPT]
    str     xzr, [x28, #G_POPMSG]
    str     xzr, [x28, #G_DEATHMSG]
    str     xzr, [x28, #G_KILLER]
    str     wzr, [x28, #G_KILLT]
    str     wzr, [x28, #G_WANTSHOT]
    str     wzr, [x28, #G_TESTKEYS]
    str     wzr, [x28, #G_LMB]
    str     wzr, [x28, #G_HOVOK]
    str     wzr, [x28, #G_PAUSE]
    // objetos, memoria e o resto
    LA      x0, objs
    ldr     w1, [x28, #G_NOBJ]
    lsl     x1, x1, #3
    bl      sav_read
    LA      x0, memtype
    ldr     w1, [x28, #G_NOBJ]
    bl      sav_read
    LA      x21, savtab
1:  ldp     x0, x1, [x21], #16
    cbz     x0, 2f
    bl      sav_read
    b       1b
2:  mov     x0, x19
    bl      F(fclose)
    mov     w9, #-1                     // a ocupacao e refeita
    str     w9, [x28, #G_OCCFRAME]
    mov     w9, #1                      // e as listas dos depositos
    str     w9, [x28, #G_DEPDIRTY]
    bl      crowd_reset                 // as contas da colisao e as cinzas
    bl      ash_reset
    ldr     w0, [x28, #G_ZOOM]
    bl      set_zoom
    bl      follow_camera
    bl      calc_stats
    LA      x0, msgbuf2                 // "Jogo carregado (Dia 3)"
    LA      x1, m_loaded
    bl      strcat_cur
    ldr     w1, [x28, #G_DAY]
    bl      numcat
    LA      x1, s_close
    bl      strcat_cur
    LA      x0, msgbuf2
    bl      set_msg
    LA      x9, savbad                  // leu menos do que devia (nao
    ldr     w9, [x9]                    // deveria: o tamanho bateu)
    LA      x0, m_loadbad
    cbz     w9, 3f
    bl      set_msg
3:  mov     w0, #1
    b       90f
60: mov     x0, x19                     // nao e um jogo salvo deste jogo
    bl      F(fclose)
    LA      x9, m_badsave
71: mov     x0, x9
    bl      set_msg
    mov     w0, #0
90: ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// save_enter(x0 = cursor) -> x0: o texto do ENTER na tela de titulo
//   em jogo:           "ENTER: voltar ao jogo"
//   com jogo salvo do mundo mostrado: "ENTER ou C: continuar (Mundo #12, Dia 3)"
//   senao:             "Pressione ENTER para jogar"
    .globl save_enter
save_enter:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    LA      x1, s_back
    ldr     w9, [x28, #G_INGAME]
    cbnz    w9, 8f
    bl      save_here
    cbz     w0, 7f
    LA      x0, txt
    LA      x1, s_cont1
    bl      strcat_cur
    LA      x9, savinfo
    ldr     w1, [x9, #4]
    bl      numcat
    LA      x1, s_cont2
    bl      strcat_cur
    LA      x9, savinfo
    ldr     w1, [x9, #8]
    bl      numcat
    LA      x1, s_close
    b       9f
7:  LA      x0, txt
    LA      x1, s_play
    b       9f
8:  LA      x0, txt
9:  bl      strcat_cur
    ldp     x29, x30, [sp], #16
    ret

// save_here -> w0 = 1 se tem jogo salvo do mundo que o titulo mostra  folha
    .globl save_here
save_here:
    LA      x9, savinfo
    ldr     w10, [x9]
    cbz     w10, 8f
    ldr     w10, [x9, #4]
    ldr     w11, [x28, #G_SEED]
    cmp     w10, w11
    cset    w0, eq
    ret
8:  mov     w0, #0
    ret

// save_has -> w0 = 1 se tem jogo salvo   folha
    .globl save_has
save_has:
    LA      x9, savinfo
    ldr     w0, [x9]
    ret

// ---------------------------------------------------------------------
//  Teste automatico (--shot): salva, bagunca e carrega de volta
// ---------------------------------------------------------------------
    .globl save_selftest
save_selftest:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    LA      x9, savpath                 // um arquivo so do teste
    LA      x10, s_testfile
    str     x10, [x9]
    LA      x24, svres
    ldr     w9, [x28, #G_DAY]           // o que vai conferir
    str     w9, [x24]
    ldr     w9, [x28, #G_TIME]
    str     w9, [x24, #4]
    ldr     w9, [x28, #G_NOBJ]
    str     w9, [x24, #8]
    ldr     w9, [x28, #G_PEOPLEN]
    str     w9, [x24, #12]
    LA      x9, people
    ldr     w10, [x9, #P_U]
    str     w10, [x24, #16]
    LA      x9, chests
    ldr     w10, [x9, #(4 * IT_WOOD)]
    str     w10, [x24, #20]
    mov     w0, #1                      // buracos de pedreira
    bl      sv_count
    str     w0, [x24, #24]
    ldr     w9, [x28, #(G_INV + 4 * IT_STONE)]
    str     w9, [x24, #28]
    LA      x9, savbad
    str     wzr, [x9]
    bl      save_game
    str     w0, [x24, #32]
    mov     x0, #0                      // tamanho (KB)
    ldr     w0, [x28, #G_NOBJ]
    bl      sav_total
    lsr     x0, x0, #10
    str     w0, [x24, #36]
    // bagunca: outro dia, a pessoa longe, o bau cheio, o personagem sem
    // pedra e os objetos pela metade
    ldr     w9, [x28, #G_DAY]
    add     w9, w9, #7
    str     w9, [x28, #G_DAY]
    LA      x9, people
    mov     w10, #0x42c80000            // 100.0
    str     w10, [x9, #P_U]
    LA      x9, chests
    mov     w10, #999
    str     w10, [x9, #(4 * IT_WOOD)]
    str     wzr, [x28, #(G_INV + 4 * IT_STONE)]
    ldr     w9, [x28, #G_NOBJ]
    lsr     w9, w9, #1
    str     w9, [x28, #G_NOBJ]
    bl      load_game
    str     w0, [x24, #40]
    // conferir
    mov     w21, #0                     // quantos bateram
    ldr     w9, [x28, #G_DAY]
    ldr     w10, [x24]
    cmp     w9, w10
    cinc    w21, w21, eq
    ldr     w9, [x28, #G_TIME]
    ldr     w10, [x24, #4]
    cmp     w9, w10
    cinc    w21, w21, eq
    ldr     w9, [x28, #G_NOBJ]
    ldr     w10, [x24, #8]
    cmp     w9, w10
    cinc    w21, w21, eq
    ldr     w9, [x28, #G_PEOPLEN]
    ldr     w10, [x24, #12]
    cmp     w9, w10
    cinc    w21, w21, eq
    LA      x9, people
    ldr     w9, [x9, #P_U]
    ldr     w10, [x24, #16]
    cmp     w9, w10
    cinc    w21, w21, eq
    LA      x9, chests
    ldr     w9, [x9, #(4 * IT_WOOD)]
    ldr     w10, [x24, #20]
    cmp     w9, w10
    cinc    w21, w21, eq
    mov     w0, #1
    bl      sv_count
    ldr     w10, [x24, #24]
    cmp     w0, w10
    cinc    w21, w21, eq
    ldr     w9, [x28, #(G_INV + 4 * IT_STONE)]
    ldr     w10, [x24, #28]
    cmp     w9, w10
    cinc    w21, w21, eq
    LA      x0, s_testfile
    bl      F(remove)
    LA      x9, savpath
    LA      x10, s_savfile
    str     x10, [x9]
    bl      save_probe
    LA      x0, txt
    LA      x1, sv_t1
    ldr     w2, [x24, #32]
    bl      sv_num
    LA      x1, sv_t2
    ldr     w2, [x24, #36]
    bl      sv_num
    LA      x1, sv_t3
    ldr     w2, [x24, #40]
    bl      sv_num
    LA      x1, sv_t4
    mov     w2, w21
    bl      sv_num
    LA      x1, sv_t5
    ldr     w2, [x24]
    bl      sv_num
    LA      x1, sv_t6
    ldr     w2, [x24, #8]
    bl      sv_num
    LA      x1, sv_t7
    ldr     w2, [x24, #24]
    bl      sv_num
    LA      x1, sv_nl
    bl      strcat_cur
    bl      sk_write
    str     wzr, [x28, #G_MSGT]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// sv_count(w0 = valor) -> w0 = celulas de pitgrid com esse valor   folha
sv_count:
    LA      x9, pitgrid
    mov     w10, #0
    mov     w11, w0
    mov     w0, #0
1:  ldrb    w12, [x9, x10]
    cmp     w12, w11
    cinc    w0, w0, eq
    add     w10, w10, #1
    cmp     w10, #64, lsl #12
    b.lo    1b
    ret

// sv_num(x0 cursor, x1 rotulo, w2 numero) -> x0
sv_num:
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

// ---------------------------------------------------------------------
    .data
    .p2align 3
// o que vai no arquivo depois de G, dos objetos e do memtype
savtab:
    .quad overlay,   (MAPN * MAPN)      // terra arada e caminhos
    .quad seen,      (MAPN * MAPN)      // o que voce ja viu
    .quad treecnt,   (MAPN * MAPN)      // arvores por celula
    .quad fencegrid, (MAPN * MAPN)      // cercas e portoes
    .quad zonegrid,  (MAPN * MAPN)      // zonas
    .quad walkgrid,  (MAPN * MAPN)      // passadas
    .quad pitgrid,   (MAPN * MAPN)      // pedreiras e buracos
    .quad animals,   1536
    .quad arrows,    512
    .quad lamps,     (MAXLAMP * 4)
    .quad fires,     512
    .quad chests,    16384
    .quad chestused, 64
    .quad shelters,  128
    .quad croplist,  (MAXCROP * 4)
    .quad people,    (MAXPEOPLE * PSIZE)
    .quad pinv,      (MAXPEOPLE * 256)
    .quad kin,       (MAXPEOPLE * 8)
    .quad fams,      (MAXFAM * FSIZE)
    .quad vstat,     16
    .quad 0, 0
savpath:    .quad s_savfile
s_magic:    .ascii "ERMOSAV1"
s_savfile:  .asciz "ermo.sav"
s_testfile: .asciz "shot_teste.sav"
s_rb:       .asciz "rb"
s_wb:       .asciz "wb"
m_saved:    .asciz "Jogo salvo (Dia "
m_loaded:   .asciz "Jogo carregado (Dia "
s_close:    .asciz ")"
m_nodead:   .asciz "Morto nao da para salvar (F9 carrega o jogo salvo)"
m_nosleep:  .asciz "Dormindo nao da para salvar"
m_savefail: .asciz "Nao consegui salvar (ermo.sav)"
m_nosave:   .asciz "Nenhum jogo salvo (F5 salva)"
m_badsave:  .asciz "O ermo.sav nao e deste jogo (ou esta incompleto)"
m_loadbad:  .asciz "O jogo salvo veio incompleto"
s_back:     .asciz "ENTER: voltar ao jogo"
s_play:     .asciz "Pressione ENTER para jogar"
s_cont1:    .asciz "ENTER ou C: continuar o jogo salvo (Mundo #"
s_cont2:    .asciz ", Dia "
sv_t1:  .asciz "salvar: salvou="
sv_t2:  .asciz " arquivo (KB)="
sv_t3:  .asciz " | baguncou e carregou="
sv_t4:  .asciz " conferidos iguais (de 8)="
sv_t5:  .asciz " | dia="
sv_t6:  .asciz " objetos="
sv_t7:  .asciz " buracos="
sv_nl:  .asciz "\n"
    .p2align 3
hdr:        .space HDRSIZE
gkeep:      .space 32
savinfo:    .space 16                   // tem, semente, dia
savbad:     .space 8
svres:      .space 64
msgbuf2:    .space 64
