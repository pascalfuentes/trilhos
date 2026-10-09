// =====================================================================
//  comum.h - macros e constantes compartilhadas por todos os modulos
//  (incluido com #include no topo de cada arquivo .S)
//  inclui itens, receitas, a interface de fabricar, o clima e os animais.
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
.equ SPR_SWIM,  9            // 9 e 10: personagem nadando
.equ SPR_FIN,   11           // barbatana do tubarao
.equ SPR_TORCH, 17           // tocha (icone e na mao)

// ---- sobrevivencia (60 quadros = 1 s; tempos 4x mais longos) ---------------
.equ MAXFIRE,   32           // fogueira: 16 bytes (u, v, e, lenha)
.equ DAYLEN,    43200        // quadros por dia (12 minutos)
.equ T_DUSK,    21600        // 18:00
.equ T_NIGHT,   25920        // 20:24
.equ T_DAWN,    38880        // 05:36

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
                             // 160-171: livre (o inventario foi para G_INV)
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
.equ G_NIGHTK,   272         // 0 = dia ... 256 = noite
.equ G_STAMINA,  276         // folego (float 0..100)
.equ G_WATER,    280         // 0 terra, 1 raso, 2 fundo, 3 muito fundo
.equ G_SHARK,    284         // tempo no mar aberto (o tubarao chega)
.equ G_DEATHMSG, 288         // causa da morte (ponteiro)
.equ G_RUN,      296         // correndo neste quadro (Shift)
.equ G_EXHAUST,  300         // stamina acabou: so corre de novo com 25
.equ G_INVOPEN,  304         // janela da mochila aberta
.equ G_CHAROPEN, 308         // janela do personagem aberta
.equ G_TESTKEYS, 312         // teclas simuladas pelo teste (W S A D Shift)
.equ G_WEIGHT,   316         // peso carregado (decimos de kg)
.equ G_CAP,      320         // peso maximo sem ficar lento (decimos de kg)
                             // 324-363: livre (as skills foram para 704)
.equ G_STAMAX,   364         // stamina maxima (float; cresce com corrida e natacao)
.equ G_SATED,    368         // quadros que a fome ainda fica cheia (vida so sobe assim)
.equ G_CRAFTOPEN, 372        // janela de fabricar aberta
.equ G_PLACE,    376         // colocando uma construcao: item + 1 (0 = nao)
.equ G_CHESTOPEN, 380        // bau aberto: numero do bau + 1 (0 = fechado)
.equ G_CHESTOBJ, 384         // objeto do bau aberto
.equ G_AXEDUR,   388         // usos que restam no machado em uso
.equ G_PICKDUR,  392         // ... e na picareta
.equ G_TORCHT,   396         // quadros que restam na tocha acesa
.equ G_TORCHLIT, 400         // tocha acesa agora
.equ G_HOVREC,   404         // receita sob o mouse (-1)
.equ G_INSHELTER, 408        // dentro de um abrigo
                             // 416-463: livre (a mochila foi para 576)
.equ G_WOOD,     (G_INV + 0)
.equ G_STONE,    (G_INV + 4)
.equ G_BERRY,    (G_INV + 8)
// clima (calculado por weather_update a cada quadro)
.equ G_WEATHER,  464         // clima atual (W_*)
.equ G_WTIME,    468         // quadros que faltam neste clima
.equ G_WDUR,     472         // duracao total deste clima
.equ G_WK,       476         // intensidade 0..256 (entra e sai devagar)
.equ G_FLOOD,    480         // nivel da enchente (1/16 px; 0 = normal)
.equ G_FLASH,    484         // relampago (quadros)
.equ G_WCOLD,    488         // frio extra por quadro (float; < 0 esquenta)
.equ G_WFOOD,    492         // multiplica a fome (float)
.equ G_WVIS,     496         // multiplica o raio de visao (float)
.equ G_WFIRE,    500         // lenha extra gasta por quadro nas fogueiras
.equ G_WHAIL,    504         // vida perdida por quadro fora do abrigo (float)
.equ G_WSPEED,   508         // multiplica a velocidade (float)
.equ G_WSTAM,    512         // multiplica o gasto de stamina (float)
.equ G_WRECOV,   516         // multiplica a recuperacao de stamina (float)
.equ G_WDARK,    520         // quanto escurece (0..256)
.equ G_SEASON,   524         // 0 primavera, 1 verao, 2 outono, 3 inverno
// equipamento e animais
.equ G_HAND,     528         // na mao: item + 1 (0 = maos vazias)
.equ G_ATKCD,    532         // espera ate o proximo golpe / flecha
.equ G_HOVANIM,  536         // animal sob o mouse (-1)
.equ G_NANIM,    540         // animais vivos
.equ G_KILLER,   544         // ultimo animal que mordeu (texto da morte, 8 bytes)
.equ G_KILLT,    552         // quadros desde a mordida (conta para baixo)
.equ G_SPAWNT,   556         // proxima tentativa de aparecer um animal
.equ G_OFFHAND,  560         // tocha na outra mao (1/0)
.equ G_NOSPAWN,  564         // teste: animais nao aparecem sozinhos
.equ G_SLEEP,    568         // dormindo na cabana (abrigo)
.equ G_SLEEPDAY, 572         // dia em que deitou (acorda quando virar)
.equ SLEEPSPEED, 60          // dormindo, cada quadro vale 60 (a noite passa em ~5 s)
// (576..703 livre: a mochila mudou para G_INV, 48 vagas)
.equ G_WOOD,     (G_INV + 0)
.equ G_STONE,    (G_INV + 4)
.equ G_BERRY,    (G_INV + 8)
.equ G_SKILL,    704         // 7 skills (float 0..100)
.equ G_SKIDLE,   800         // 7 x u16: quadros sem treinar cada skill
.equ G_SKLAST,   816         // 7 x u8: ultimo nivel anunciado
// cercas e pesca
.equ G_FDRAG,    748         // arrastando uma fileira de cercas
.equ G_FLASTU,   752         // ultima celula com cerca na fileira
.equ G_FLASTV,   756
.equ G_FISH,     760         // pesca: 0 nada, 1 esperando, 2 mordeu!
.equ G_FISHT,    764         // quadros ate morder / para fisgar
.equ G_BOBU,     768         // boia (float, celulas)
.equ G_BOBV,     772
.equ G_FTGU,     776         // celula sob o mouse (colocando cerca/portao)
.equ G_FTGV,     780
.equ G_FTGOK,    784
.equ G_FPLANN,   788         // celulas na previa da fileira
// plantacao
.equ G_FARMLAST, 824         // celula + 1 onde a enxada/semente ja agiu
.equ G_HOEDUR,   828         // usos que restam na enxada
.equ G_CROPT,    832         // conta quadros ate o proximo passo das plantas
.equ G_NCROP,    836         // plantas na lista
.equ G_GRIDON,   844         // grade ligada pela tecla G
.equ G_GRIDSHOW, 848         // grade no chao neste quadro (calculado em grid_prep)
.equ G_GRIDPU,   852         // celula do personagem (centro da grade)
.equ G_GRIDPV,   856
.equ G_GRIDW,    860         // largura da linha (16.16 = um passo do terreno)
.equ G_GRIDREACH, 864        // alcance^2 (linhas mais fortes); -1 = so a grade
.equ GRIDR2,     400         // a grade aparece ate 20 celulas (some aos poucos)
.equ G_FARMMODE, 840         // nesta segurada a enxada: 0 nada, 1 ara, 2 desfaz, 3 colhe
// pessoas (pessoas.S)
.equ G_HOVPERS,  868         // pessoa sob o mouse (-1)
.equ G_SELPERS,  872         // pessoa selecionada (-1)
.equ G_PEOPLEOPEN, 876       // painel de pessoas aberto (P)
.equ G_ZONEMODE, 880         // pintando zonas (Z): tipo 1..4, 5 apaga; 0 = nao
.equ G_ZDRAG,    884         // arrastando o retangulo da zona
.equ G_ZAU,      888         // retangulo: celula onde comecou
.equ G_ZAV,      892
.equ G_ZBU,      896         // ... e onde esta o mouse
.equ G_ZBV,      900
.equ G_PLASTDAY, 904         // ultimo dia contado (aniversarios)
.equ G_NOPEOPLE, 908         // teste: sem a vila
.equ G_OCCFRAME, 912         // quadro em que a ocupacao foi refeita
.equ G_PPLFRAME, 916         // quadros da vila
.equ G_SAPT,     920         // conta quadros ate as mudas crescerem
.equ G_PNOCHEST, 924         // quando avisou que falta bau
.equ G_PEOPLEN,  928         // pessoas vivas
.equ G_ZONESHOW, 932         // zonas no chao neste quadro (grid_prep)
.equ G_PLCELL,   936         // celula do personagem (caminho)
.equ G_PTAB,     940         // painel P: 0 Pessoas, 1 Familias
.equ G_PPAGE,    944         // painel P: pagina
.equ G_NOLOTT,   948         // quando avisou que falta zona de Moradia
.equ G_NEARFURN, 952         // perto de uma fornalha (receitas de ferro)
.equ G_FULL,     956         // tela cheia
.equ G_INV,      960         // mochila: um contador (u32) por item, 48 vagas
.equ G_IRONDUR,  1152        // usos que restam: machado, picareta, enxada de ferro
.equ G_NLAMP,    1164        // lampioes
.equ G_FURNT,    1168        // conta quadros ate olhar a fornalha de novo
.equ GSIZE,      1184

.equ W_SUN,      0
.equ W_CLOUDY,   1
.equ W_RAIN,     2
.equ W_STORM,    3
.equ W_HEAT,     4
.equ W_SNOW,     5
.equ W_HAIL,     6
.equ W_FLOOD,    7
.equ NWEATHER,   8
.equ SEASONDAYS, 4           // cada estacao dura 4 dias (48 min)
.equ FLOODMAX,   120         // a enchente sobe ate 120 (cobre praias e campos baixos)
.equ WFADE,      1200        // o clima entra e sai em 20 s

// skills
.equ SK_SWIM,    0           // natacao
.equ SK_RUN,     1           // corrida
.equ SK_CHOP,    2           // lenhador
.equ SK_MINE,    3           // mineracao
.equ SK_STR,     4           // forca
.equ SK_FISH,    5           // pesca
.equ SK_FARM,    6           // agricultura
.equ NSKILL,     7
.equ SATTIME,    14400       // fome cheia segura 4 min antes de cair
.equ SKREST,     7200        // 2 min sem treinar: a skill comeca a cair
.equ G_SKSWIM,   (G_SKILL + 4 * SK_SWIM)
.equ G_SKRUN,    (G_SKILL + 4 * SK_RUN)
.equ G_SKCHOP,   (G_SKILL + 4 * SK_CHOP)
.equ G_SKMINE,   (G_SKILL + 4 * SK_MINE)
.equ G_SKSTR,    (G_SKILL + 4 * SK_STR)
.equ G_SKFISH,   (G_SKILL + 4 * SK_FISH)
.equ G_SKFARM,   (G_SKILL + 4 * SK_FARM)

// itens da mochila (vetor em G_INV)
.equ IT_WOOD,    0
.equ IT_STONE,   1
.equ IT_BERRY,   2
.equ IT_AXE,     3           // machado
.equ IT_PICK,    4           // picareta
.equ IT_TORCH,   5           // tocha
.equ IT_COOKED,  6           // frutas assadas
.equ IT_BASKET,  7           // cesto (+10 kg)
.equ IT_FIRE,    8           // fogueira (construcao)
.equ IT_CHEST,   9           // bau (construcao)
.equ IT_SHELTER, 10          // abrigo (construcao)
.equ IT_BOW,     11          // arco
.equ IT_ARROW,   12          // flechas
.equ IT_MEAT,    13          // carne crua
.equ IT_CMEAT,   14          // carne assada
.equ IT_HIDE,    15          // couro
.equ IT_COAT,    16          // roupa de couro (metade do frio)
.equ IT_LBAG,    17          // mochila de couro (+20 kg)
.equ IT_FENCE,   18          // cerca (construcao, arrasta em fileira)
.equ IT_GATE,    19          // portao (construcao)
.equ IT_ROD,     20          // vara de pesca
.equ IT_FISH,    21          // peixe cru
.equ IT_CFISH,   22          // peixe assado
.equ IT_HOE,     23          // enxada (ara a terra)
.equ IT_SEED,    24          // sementes de trigo
.equ IT_WHEAT,   25          // trigo
.equ IT_BREAD,   26          // pao
.equ IT_ORE,     27          // minerio de ferro
.equ IT_COAL,    28          // carvao
.equ IT_IRON,    29          // barra de ferro
.equ IT_FURNACE, 30          // fornalha (construcao)
.equ IT_IAXE,    31          // machado de ferro
.equ IT_IPICK,   32          // picareta de ferro
.equ IT_IHOE,    33          // enxada de ferro
.equ IT_SWORD,   34          // espada
.equ IT_ARMOR,   35          // armadura de ferro
.equ IT_LAMP,    36          // lampiao (construcao)
.equ NITEMS,     37
.equ MAXITEMS,   48          // vagas na mochila e em cada bau
.equ CHESTSHIFT, 8           // cada bau: 48 contadores (256 bytes)
.equ IRONDUR,    120         // usos de uma ferramenta de ferro
// construcoes (vao para o mapa, nao se largam): fogueira, bau, abrigo,
// cerca e portao -> tabela itembuild

// objetos que voce cria
.equ O_LOGS,     12          // pilhas largadas: 12 + item (sprites 12..19)
.equ O_STONES,   13
.equ O_BERRIES,  14
.equ O_CHEST,    20          // bau (sprite 20)
.equ O_SHELTER,  21          // abrigo (sprite 21)
.equ O_FENCE,    36          // cerca (sprites 45..48 conforme os vizinhos)
.equ O_GATE,     37          // portao (sprites 49..50)
.equ O_WHEAT,    38          // trigo selvagem (da sementes)
.equ O_CROP,     39          // trigo plantado (variante = quanto cresceu)
.equ O_PILE2,    40          // pilhas dos itens 24.. (sementes, trigo, pao)
.equ O_SAPLING,  43          // muda de arvore (variante = dias)
.equ O_YTREE,    44          // arvore jovem (variante = dias; nao se corta)
.equ O_HUT,      45          // barraco de uma familia (bloco 2 x 2; variante = cor)
.equ O_HOUSE,    46          // casa de uma familia
.equ O_IRONV,    47          // veio de ferro (so com picareta)
.equ O_COALV,    48          // veio de carvao
.equ O_FURNACE,  49          // fornalha
.equ O_LAMP,     50          // lampiao
.equ O_PILE3,    51          // pilhas dos itens 27.. (51 + item - 27)
.equ O_LAST,     60          // ultimo tipo de objeto
.equ SPR_FENCE,  45
.equ SPR_GATE,   49
.equ SPR_BOBBER, 51
.equ SPR_WILD,   52          // trigo selvagem
.equ SPR_CROP,   53          // 53..56: trigo plantado (4 estagios)
.equ SPR_HOE,    57
.equ SPR_SEED,   58
.equ SPR_WHEAT,  59
.equ SPR_BREAD,  60
.equ SPR_SAPLING, 61         // muda
.equ SPR_MARK,   62          // setinha em cima de quem esta selecionado
.equ SPR_MAN,    63          // 63, 64: homem (2 quadros); roupa = cor da familia
.equ SPR_KID,    65          // 65, 66: crianca
.equ SPR_WOMAN,  67          // 67, 68: mulher
.equ SPR_YTREE,  69          // arvore jovem
.equ SPR_HUT,    70          // barraco (ocupa as vagas 70 e 71)
.equ SPR_HOUSE,  72          // casa (vagas 72 a 74)
.equ SPR_ORE,    75          // minerio
.equ SPR_COAL,   76
.equ SPR_IRON,   77          // barra de ferro
.equ SPR_FURNACE, 78         // fornalha (vagas 78 e 79)
.equ SPR_IAXE,   80
.equ SPR_IPICK,  81
.equ SPR_IHOE,   82
.equ SPR_SWORD,  83
.equ SPR_ARMOR,  84
.equ SPR_LAMP,   85
.equ SPR_IRONV,  86          // veios
.equ SPR_COALV,  87
.equ MAXLAMP,    64
// pessoas
.equ MAXPEOPLE,  64          // vagas (quem morreu fica, para a arvore genealogica)
.equ PSIZE,      64
.equ J_FOREST,   1           // tarefas (e tipos de zona)
.equ J_STONE,    2
.equ J_FARM,     3
.equ J_BUILD,    4           // obras: barracos, casas e cercas
.equ J_SMITH,    5           // ferreiro: barras de ferro e carvao na fornalha
.equ NJOBS,      6
.equ Z_FOREST,   1
.equ Z_STONE,    2
.equ Z_FARM,     3
.equ Z_HOME,     4           // moradia: onde as familias novas constroem
.equ Z_ERASE,    5
.equ Z_LOT,      6           // terreno de uma casa (5 x 5)
.equ MAXCROP,    512         // plantas
.equ CROPRIPE,   192         // maduro (a variante vai de 0 a 192)
.equ CROPP,      71          // chance de crescer por passo (em 1000)
.equ FENCEREACH, 64          // cercas ate 8 celulas do personagem (8^2)
.equ FENCEMAXSTEP, 24        // passos numa fileira

// animais (sprites 30..41, dois quadros cada)
.equ A_RABBIT,   0
.equ A_DEER,     1
.equ A_GOAT,     2
.equ A_WOLF,     3
.equ A_BEAR,     4
.equ A_CRAB,     5
.equ NATYPES,    6
.equ MAXANIM,    48          // vagas na lista
.equ MAXALIVE,   18          // no maximo vivos ao mesmo tempo
.equ MAXARROW,   16
.equ HB_X,       228         // barra "na mao" (7 quadrados) embaixo, ao lado da janela do personagem
.equ NHOTBAR,    8
.equ HB_Y,       306

.equ TOOLDUR,    40          // usos de um machado ou picareta
.equ TORCHTIME,  14400       // uma tocha queima 4 min
.equ FIRETIME,   14400       // fogueira nova: 4 min de fogo
.equ FIREWOOD,   7200        // cada lenha: +2 min
.equ FIREMAX,    43200       // no maximo 12 min
.equ MAXCHEST,   64          // cada bau: 32 contadores (128 bytes)
.equ MAXSHELTER, 32
.equ NRECIPES,   28

// interface (coordenadas do espaco de texto 640 x 360)
.equ BTN_Y,      16
.equ BTN_H,      14
.equ BTNI_X,     404         // botao "Mochila"
.equ BTNI_W,     104
.equ BTNC_X,     512         // botao "Personagem"
.equ BTNC_W,     124
.equ INV_X,      416         // janela da mochila
.equ INV_Y,      36
.equ INV_W,      220
.equ INV_H,      266
.equ SLOT_X,     (INV_X + 12) // mochila: grade 5 x 4
.equ SLOT_Y,     (INV_Y + 48)
.equ SLOT,       36          // lado do quadrado
.equ SLOTSTEP,   40
.equ CHR_X,      4           // janela do personagem (embaixo do status)
.equ CHR_Y,      118
.equ CHR_W,      216
.equ CHR_H,      220
.equ BTNF_X,     284         // botao "Fabricar"
.equ BTNF_W,     116
.equ CRF_X,      224         // janela de fabricar (e do bau, no mesmo lugar)
.equ CRF_Y,      32
.equ CRF_W,      188
.equ CRF_H,      272
.equ CRF_GX,     (CRF_X + 9)  // fabricar: grade de icones 5 x 6 (30 x 30, passo 34)
.equ CSLOT,      30
.equ CSTEP,      34
.equ CRF_GY,     (CRF_Y + 20)
.equ CHS_SLOTX,  (CRF_X + 16) // bau: grade 4 x 5
.equ CHS_SLOTY,  (CRF_Y + 20)

// agua: 3 niveis (raso, fundo, mar aberto)
.equ W_SHALLOW,  150         // ate esta profundidade (1/16 px) e raso
.equ W_OCEAN,    700         // mais fundo que isto perto da borda: mar aberto
.equ W_BORDER,   90          // "perto da borda" = a menos de 90 celulas
.equ SHARKTIME,  420         // 7 s no mar aberto e o tubarao ataca

// neblina: celula visivel se vis >= VIS_MIN
.equ VIS_MIN,    40

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
.equ F_VISDAY,   60
.equ F_VISNIGHT, 64
.equ F_INV256,   68
.equ F_FIREVIS,  72
.equ F_COS1,     76
.equ F_SIN1,     80
.equ F_RAYSTEP,  84
.equ F_P7,       88
.equ F_P3,       92
.equ F_P8,       96
.equ F_255,      100
.equ F_TREEBLK,  104
.equ F_TIRED,    108
.equ F_SWIMCOST, 112
.equ F_RECOV,    116
.equ F_RECOVSH,  120
.equ F_DROWN,    124
.equ F_WETCOLD,  128
.equ F_SHARKR,   132
.equ F_RUNCOST,  136
.equ F_RECOVREST, 140
.equ F_RUNBASE,  144
.equ F_RUNSK,    148
.equ F_SWIMBASE, 152
.equ F_SWIMSK,   156
.equ F_SK6,      160
.equ F_SK5,      164
.equ F_HEAVY,    168
.equ F_25,       172
.equ F_XPSWIM,   176
.equ F_XPRUN,    180
.equ F_XPCHOP,   184
.equ F_XPMINE,   188
.equ F_XPSTR,    192
.equ F_SKDECAY,  196
.equ F_P105,     200
.equ F_INV100,   204
.equ F_TENTH,    208
.equ F_STAMSK,   212
.equ F_TORCHVIS, 216
.equ F_EATCOOKED, 220
