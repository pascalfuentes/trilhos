# Ermo

Um jogo de sobrevivência no estilo Factorio, escrito em **assembly ARM64** (AArch64).

Você é uma espécie de profeta que não envelhece, e chega com **3 famílias** num mundo gerado aleatoriamente: terreno contínuo, mar, praias, florestas, montanhas com neve. Precisa coletar madeira, pedra e frutas, caçar com arco e flecha, pescar, plantar trigo, fabricar ferramentas e construções, comandar a vila (cada pessoa com fé, fome, sono e idade), fugir de lobos e ursos, não morrer de fome e passar a noite perto de uma fogueira (ou dormindo numa cabana), enfrentando as estações e o clima (chuva, tempestade, calorão, neve, granizo, enchente). Quanto mais você faz uma coisa, melhor fica nela, e para se curar precisa estar de barriga cheia.

![Dia](screenshots/jogo.png)
![Noite](screenshots/noite.png)

**Os personagens:** o profeta (capuz marrom, barba branca e o cajado com a pedra amarela) e os moradores (homem, mulher, menino e menina, com a roupa na cor da família) são desenhados em **8 direções**, com passos, virados para onde estão andando. O profeta guarda o cajado quando segura uma ferramenta ou a tocha. De perto o desenho tem o dobro de detalhe; no zoom mais afastado volta o boneco simples. O chão é desenhado **1,5x maior** que as coisas em cima dele (bonecos, árvores, casas, pilhas), para o mundo não ficar abarrotado.

**As construções** (desenho do designer, em `design/estruturas/estruturas.json`) estão em isométrica, com volume, na mesma resolução dos personagens: fogueira com chama animada (e as cinzas quando apaga, que somem em 1 dia), baú que abre, abrigo, cerca que liga nos vizinhos, portão que **abre quando alguém passa**, barraco e casa com o telhado na cor da família, casa com as **janelas acesas de noite**, fornalha que acende quando o ferreiro trabalha (ou você está do lado), lampião aceso de noite e as pilhas dos depósitos em 3 tamanhos (pouco, metade, cheia). De noite, chama, janelas e o vidro do lampião não escurecem.

![Construções de dia, com estradas](screenshots/estruturas.png)
![Construções de noite](screenshots/estruturas_noite.png)

## Como jogar

| Tecla / mouse | Ação |
|---|---|
| ENTER | entrar no mundo (na tela de título); se tiver jogo salvo daquele mundo, continua ele |
| C / N | na tela de título: continua o jogo salvo / começa um jogo novo no mundo mostrado |
| F5 | salva o jogo (em `ermo.sav`, na pasta do jogo) |
| F9 | carrega o jogo salvo (também na tela de título e depois de morrer) |
| WASD / setas | andar |
| Shift (segurando) | correr |
| segurar o botão esquerdo | coletar a árvore, pedra ou arbusto sob o mouse (até 3 células de distância) |
| E | comer (o que encher mais primeiro: carne assada, pão, frutas assadas, peixe assado...) |
| F | fabricar uma fogueira e escolher onde montar |
| Tab ou botão **Fabricar** | abre a janela de fabricar |
| clique no mapa (com uma construção na mão) | coloca a construção num quadrado da grade; botão direito ou ESC cancela |
| 1 / 2 / 3 | põe na mão o machado, a picareta ou o arco (de novo: mãos vazias) |
| 4 | põe ou tira a tocha da outra mão |
| 5 | põe na mão a vara de pesca |
| 6 / 7 | põe na mão a enxada / as sementes |
| 8 | põe na mão a espada |
| segurar o botão esquerdo com a enxada | ara a grama sob o mouse (passe por várias células) |
| segurar o botão esquerdo com sementes | planta na terra arada sob o mouse |
| arrastar com cercas na mão | prévia da fileira na grade (horizontal, vertical ou diagonal); soltar coloca |
| clique na água com a vara na mão | lança a linha; quando aparecer "Peixe! Clique!", clique para fisgar |
| clique com o arco na mão | atira uma flecha onde está o mouse |
| clique num animal perto | golpe (machado tira mais vida) |
| botão direito num baú ou num **depósito** (a até 4 células) | abre o baú ou tudo o que está nas pilhas do depósito em volta (clique num item passa de um lado para o outro) |
| botão direito no abrigo (depois das 18h) | dorme até amanhecer (qualquer tecla acorda) |
| botão direito numa fogueira | pôr lenha (+2 min de fogo; no máximo 12 min) |
| I ou botão **Mochila** | abre a mochila (clique num item: come, põe na mão, coloca ou guarda no baú ou depósito aberto) |
| C ou botão **Personagem** | abre as skills |
| botão direito num item da mochila | larga 1 no chão (com Shift: a pilha toda) |
| roda do mouse / `+` / `-` | zoom |
| espaço | pausa |
| P | painel da vila: clique na tarefa para trocar (botão direito volta); embaixo, abas Pessoas / Famílias (árvore genealógica) e páginas `<` `>` |
| Z | pintar zonas com um **pincel redondo**: 1 Floresta, 2 Plantação, 3 Moradia, 4 Pesca, 5 a 8 **depósitos** (comida, materiais, ferramentas e armas, geral), 0 apaga; segure o botão esquerdo para pintar e o direito para apagar; roda do mouse ou `[` `]` mudam o tamanho (1 a 12) (Z ou ESC sai) |
| botão direito numa pessoa | abre a **mochila** dela (clique num item dela: você pega; num item seu: você dá) |
| clique numa pessoa | seleciona (setinha e nome em cima) |
| botão direito no mapa (com alguém selecionado) | a pessoa vai até lá |
| F11 | tela cheia (liga/desliga); a janela também pode ser redimensionada |
| F10 | modo leve: desenha metade das colunas do terreno (para computadores lentos ou emulados) |
| G | liga/desliga a grade no chão |
| N | curvas de nível |
| ESC | sai das zonas, fecha janelas, tira a seleção ou volta ao menu |

**Recursos**

- **Árvores e pinheiros:** 4 madeiras cada; somem quando acabam.
- **Pedreiras:** a pedra vem em manchas de 3 x 3 a 5 x 5 células (chão cinza), com 12 a 19 pedras em cada célula; muitas nas colinas e montanhas, raras no campo. Quando uma célula acaba, vira um **buraco de cascalho**. Fora delas há poucas pedras soltas (3 cada).
- **Arbustos:** poucos e espalhados, com 2 frutas; demoram uns **3 dias** para dar frutas de novo (com chuva, metade) e no inverno não dão.

**Fabricar (Tab)**

Como no Minecraft e no Factorio, uma grade de ícones mostra tudo o que dá para fazer.

- Ícone apagado: falta material. Borda verde: dá para fazer.
- Passando o mouse por cima de uma receita, aparecem o nome, o custo (verde ou vermelho) e o que ela faz.
- Fabricar é instantâneo.
- Construções vão para a mochila e entram direto no modo de colocar: aparece uma prévia no mouse (piscando onde não dá) e você clica no chão, até 5 células do personagem.

| Receita | Custo | O que faz |
|---|---|---|
| Machado | 3 madeira, 2 pedra | na mão: corta árvores 2x mais rápido; dura 40 madeiras |
| Picareta | 3 madeira, 3 pedra | na mão: quebra pedras 2x mais rápido; dura 40 pedras |
| Arco | 5 madeira | na mão: atira flechas |
| Flechas (4) | 1 madeira, 1 pedra | munição do arco (somem ao acertar) |
| Tocha | 2 madeira | na outra mão: acende sozinha quando escurece; luz forte e visão de 10 células por 4 minutos |
| Fogueira | 5 madeira, 3 pedra | luz e calor por 4 minutos (construção) |
| Baú | 8 madeira | guarda itens sem pesar na mochila (construção) |
| Abrigo | 12 madeira, 4 pedra | cabana: dentro dela não passa frio, e dá para dormir a noite toda (construção) |
| Frutas assadas | 3 frutas, perto de uma fogueira | enchem 50 de fome |
| Carne assada | 1 carne, perto de uma fogueira | enche 60 de fome (crua: só 10) |
| Cesto | 6 madeira | +10 kg no limite da mochila (só um conta) |
| Roupa de couro | 4 couro | metade do frio (noite, água e clima) |
| Mochila de couro | 3 couro, 2 madeira | +20 kg no limite (soma com o cesto) |
| Cercas (4) | 2 madeira | ninguém passa: nem animais, nem você (construção, arrasta em linha) |
| Portão | 4 madeira | você passa, os animais não (construção; pode trocar uma cerca) |
| Vara de pesca | 3 madeira, 2 frutas | na mão: pesca na água |
| Peixe assado | 1 peixe, perto de uma fogueira | enche 40 de fome (cru: só 8) |
| Enxada | 2 madeira, 1 pedra | na mão: ara a terra para plantar; dura 40 usos |
| Pão | 3 trigo, perto de uma fogueira | enche 45 de fome |
| Fornalha | 10 pedra, 4 madeira | perto dela (3 células) aparecem as receitas de ferro (construção) |
| Barra de ferro | 2 minério, 1 carvão, perto da fornalha | o material do ferro |
| Carvão | 3 madeira, perto da fornalha | carvão de madeira (o mineral sai dos veios) |
| Machado de ferro | 3 ferro, 2 madeira | o machado (1) fica **4x** mais rápido que sem; dura 120 árvores; golpe 4 |
| Picareta de ferro | 3 ferro, 2 madeira | pedras e veios 4x mais rápido; dura 120 |
| Enxada de ferro | 2 ferro, 2 madeira | dura 120 usos |
| Espada | 3 ferro, 1 madeira | na mão (8): golpe 6 nos bichos |
| Armadura de ferro | 6 ferro, 2 couro | na mochila: metade do dano das mordidas |
| Lampião | 1 ferro, 1 carvão, 2 madeira | luz a noite inteira (7 células) e visão em volta, sem lenha (construção) |
| Estrada | 1 pedra | piso de paralelepípedos: anda-se **50% mais rápido**. Arraste no mapa como a cerca; as junções (retas, curvas, T, cruz) se ajustam sozinhas. A enxada desfaz e devolve a pedra |

- O desgaste das ferramentas e o tempo da tocha acesa aparecem como uma barrinha embaixo do ícone na mochila. Quando o machado ou a picareta quebra, o próximo (se você tiver) entra novo.
- **Grade:** toda construção fica presa num quadrado da grade (o abrigo ocupa 2 x 2) e só vai num quadrado **livre**: sem nada em cima (árvore, pedra, arbusto, trigo, pilha, baú, fogueira), sem cerca, sem terra arada e fora da água. A grade aparece no chão sozinha quando você está com uma construção, a enxada ou as sementes na mão (mais forte até onde você alcança) e pode ficar sempre ligada com a tecla **G**. O quadrado sob o mouse fica verde (dá), vermelho (não dá) ou laranja (a enxada desfaz a terra).
- Para **desmontar** um baú ou um abrigo, segure o botão esquerdo nele: ele volta para a mochila. O baú precisa estar vazio.

**Dormir**

A cabana tem uma porta do tamanho do personagem.

- Com o **botão direito nela, a partir das 18h**, você entra e dorme.
- A tela escurece, aparece "Zzz..." e o relógio corre: a noite passa em uns 5 segundos.
- Você acorda às 06:00. Se a água subir, se ficar fraco (fome ou frio) ou se você apertar qualquer tecla, acorda antes.
- Dormindo, a fome continua caindo (uns 17 pontos por noite), mas a cabana protege do frio e dos lobos, e a tocha fica apagada.

![A cabana](screenshots/abrigo.png)
![Dormindo](screenshots/dormindo.png)

![Fabricar](screenshots/fabricar.png)
![Tocha à noite](screenshots/tocha.png)

**Na mão**

- Embaixo da tela fica a barra **na mão**: 1 machado, 2 picareta, 3 arco, 4 tocha, 5 vara de pesca, 6 enxada e 7 sementes. O que você segura tem a borda amarela; o número no arco é quantas flechas sobram, e nas sementes, quantas você tem.
- Machado e picareta só ajudam (e só gastam) se estiverem na mão.
- A **tocha** vai na **outra mão**: dá para segurar o arco ou o machado e ainda ter luz à noite. Ela só se gasta quando queima até o fim.

**Animais e caça**

Os animais aparecem longe da vista, cada um no seu terreno, e somem quando ficam muito longe.

| Animal | Onde | Comportamento | Vida | Deixa |
|---|---|---|---|---|
| Coelho | campo | foge rápido | 2 | 1 carne |
| Cervo | floresta e campo úmido | anda em **manada** (3 ou 4) e foge junto | 6 | 2 carne, 2 couro |
| Cabra | colinas, rocha e neve | foge | 5 | 2 carne, 1 couro |
| Caranguejo | praia | anda devagar | 1 | 1 carne |
| Lobo | floresta (de noite, também campo e colinas) | **ataca**: mordida de 8 | 6 | 1 carne, 1 couro |
| Urso | floresta, rocha e neve | **ataca**: mordida de 15 | 14 | 4 carne, 3 couro |

- Os bichos são **poucos** (no máximo 10 por perto) e no **inverno** quase não aparecem bichos de caça.
- Bichos pacíficos fogem quando você chega perto ou quando são feridos. Ferir um cervo espanta a manada toda.
- Lobos e ursos perseguem: de dia só se você chegar perto, de noite de bem mais longe. Um animal ferido fica furioso.
- Correndo (Shift), você escapa de um lobo.
- Nenhum animal entra na água, e os perigosos têm medo de fogo: perto de uma fogueira acesa, ou dentro do abrigo, você está seguro.
- **Flecha** tira 4 de vida. Golpe com machado tira 3, com picareta 2 e com as mãos 1.
- O animal abatido deixa pilhas de **carne** e **couro** no chão; segure o botão esquerdo para recolher.

![Animais](screenshots/animais.png)

**Cercas e portão**

- Fabrique cercas (4 por 2 madeiras) e clique nelas na mochila para colocar.
- Com cerca ou portão na mão aparece uma **grade** com as células até onde você alcança (8 células), seguindo o relevo.
- **Aperte o botão esquerdo no começo da fileira e arraste.** A prévia trava em 8 direções da tela: horizontal, vertical e as duas diagonais. As células ficam **verdes** onde dá, **vermelhas** onde não dá (água, longe, em cima de você ou sem cerca suficiente) e **brancas** onde já tem cerca. Embaixo aparece quantas cercas a fileira gasta.
- **Solte para colocar** a fileira toda. O botão direito, durante o arraste, cancela só a fileira.
- Na horizontal e na vertical da tela a fileira vira uma **escadinha fechada** (uma célula a mais por degrau): nada passa pela quina.
- Cerca não deixa ninguém passar. O **portão** deixa você passar, mas os animais não. Coloque o portão em cima de uma cerca para trocar (a cerca volta para a mochila).
- Um cercado fechado com você dentro: os lobos ficam do lado de fora a noite toda.
- Para desmontar, segure o botão esquerdo nela, como numa árvore: volta para a mochila.

![Grade, prévia de uma fileira e um cercado com portão](screenshots/cerca.png)

**Pesca**

- Fabrique uma **vara de pesca** (3 madeira, 2 frutas) e aperte **5** para segurar.
- Clique na água (até ~5 células, parado em terra ou na água rasa) para lançar. A boia fica balançando.
- Depois de 4 a 10 segundos o peixe morde: a boia afunda e aparece **"Peixe! Clique!"**. Clique rápido para fisgar; se demorar, ele escapa.
- Clicar antes da mordida recolhe a linha. Andar longe da boia também.

| Água | Peixe | Quantos |
|---|---|---|
| lago | lambari | 1 |
| mar perto da praia | robalo | 1 a 2 |
| mar fundo | atum | 3 |

- Peixe cru enche 8 de fome; **assado** na fogueira, 40.

![Pescando](screenshots/pesca.png)

**Ferro**

- Nas **colinas, rocha e neve** algumas manchas são **minas** (chão avermelhado): de **ferro** (pontos laranja, 8 minérios por célula) ou de **carvão** (pontos pretos, 10 por célula). Só quebram com a **picareta na mão** (2). A célula que acaba vira **terra de mina**.
- Monte uma **fornalha** e fique perto dela: **2 minério + 1 carvão = 1 barra de ferro**; sem carvão mineral, **3 madeira = 1 carvão**.
- Com ferro: ferramentas de ferro (as de pedra continuam valendo; a de ferro é usada primeiro e gasta antes), espada, armadura e lampião (veja as receitas).

![Fornalha e lampião à noite](screenshots/ferro.png)

**Plantação** (como no Minecraft)

- No campo aberto nasce, raro, **trigo selvagem** (dourado). Segure o botão esquerdo nele: dá 1 trigo e 1 **semente**.
- Fabrique uma **enxada** (2 madeira, 1 pedra) e aperte **6**. Segure o botão esquerdo e passe o mouse pela grama: cada célula vira **terra arada**, com sulcos. Não dá para arar areia, rocha, neve, água nem onde tem algo em cima.
- Aperte **7** (sementes na mão) e passe pela terra arada para **plantar**.
- O trigo cresce em **4 estágios**, do broto verde até ficar dourado. A dica do mouse mostra quanto já cresceu.
- Colha segurando o botão esquerdo quando estiver **maduro**: 1 trigo e 1 ou 2 sementes. Com sementes na mão, colher e replantar sai num gesto só.
- Plantou, não tira mais: o trigo **verde** não sai, tem que esperar. Só a **enxada** desfaz: passada na terra arada, ela volta a ser grama e a planta verde que estiver ali se perde (com a semente). Numa mesma segurada do botão a enxada só ara ou só desfaz, conforme o que fez primeiro.
- **3 trigos** viram **pão** na fogueira (enche 45 de fome).

| O que acontece | Efeito no crescimento |
|---|---|
| sem nada | maduro em ~1,5 dia de jogo (18 min) |
| água a até 4 quadrados | a terra fica molhada (mais escura) e cresce **2x** mais rápido |
| chuva ou tempestade | 1,5x |
| calorão | metade, se a terra estiver seca |
| outono, inverno ou neve | não cresce (só brota na primavera e no verão) |

- **Coelhos, cervos e cabras** enxergam trigo maduro a até 8 células e vão comer. Uma **cerca** em volta protege a plantação.
- Dormindo, a noite passa depressa e a plantação cresce junto.

![Plantação](screenshots/plantacao.png)

**Pessoas (a vila)**

- O jogo começa com **3 famílias** (Silva, Souza e Lima), cada uma com pai, mãe e 2 filhos, morando num **barraco**, e um **depósito geral** 5 x 5 com frutas, pão e sementes. A roupa e o telhado de cada família têm uma cor.
- Você **não envelhece**. Eles sim: **1 ano a cada 12 dias** (uma estação dura 4 dias). Com **14 anos** uma criança pode trabalhar; bem velhos (65+) podem morrer.
- **Fé:** quem fica a até 6 células de você ganha fé (rápido); longe, ela cai devagar. Fé alta = trabalha até **1,5x mais rápido**. Abaixo de 25 (nome em laranja) às vezes enrola e pode **recusar ordens**. Fé zerada: **vai embora**.
- **Fome:** cai mais rápido (de cheia a vazia em uns 14 minutos). Quando a fome passa de 60% comem primeiro o **lanche da mochila**; depois, do depósito (o que enche mais primeiro), e levam de lá um lanche novo; sem nada, colhem frutas nos arbustos. Sem comer, a vida cai até morrer.
- **Mochila de cada um:** cada pessoa carrega o que junta no trabalho (madeira, pedra, minério, carvão, trigo, peixe... várias coisas ao mesmo tempo), o **lanche** (até 2 de cada comida pronta: pão, frutas assadas, carne e peixe assados) e a **ferramenta** da tarefa. Quando a carga enche (ou não há mais o que fazer), leva tudo ao depósito mais perto que aceita cada coisa, menos o lanche, a ferramenta e as sementes de quem planta (fica com 10). Clique com o botão direito numa pessoa (ou na coluna **Agora** do painel P) para abrir a mochila dela: clique num item dela para pegar, num item seu para dar.
- **Sono:** às 21h vão dormir **em casa** (somem lá dentro). Quem não tem casa vai para a cabana mais perto ou em volta de uma **fogueira** acesa (até 30 células); senão, deita onde está. Em noite de inverno ou de neve, fora de casa e longe do fogo, passam **frio**.
- **Lobos e ursos** também atacam as pessoas (cabana e fogueira protegem). Elas fogem quando veem um.
- **Zonas:** aperte **Z** e pinte o chão com o pincel redondo (segure o botão; o direito apaga). A roda do mouse ou `[` `]` mudam o tamanho, de 1 a 12, e o círculo aparece no chão sob o mouse. Os terrenos das casas não mudam.
- **Tarefas** (painel **P**, só adultos): cada uma trabalha **só dentro das zonas** pintadas para ela (**Z**) e leva o que juntou para o depósito mais perto:

| Tarefa | O que faz na zona |
|---|---|
| Floresta | corta as árvores **adultas** (4 madeiras por viagem) e planta uma **muda** no lugar de cada uma que cai; sem árvore adulta, planta mudas no chão vazio (um quadrado sim, outro não). A madeira não acaba |
| Pedra | **sem zona**: procura sozinho as pedreiras (até 40 células) e, de mochila vazia, as minas de ferro e carvão primeiro (3 por viagem) |
| Plantar | colhe o trigo maduro e replanta, planta na terra arada vazia (pega sementes no depósito) e ara o resto |
| Obras | constrói para as famílias: barraco, casa e cerca (veja abaixo) |
| Ferreiro | na fornalha mais perto: pega 2 minério + 1 carvão no depósito e faz uma barra de ferro; sem minério, faz carvão de madeira (até ter 10 guardados) |
| Soldado | pega uma **espada** no depósito, patrulha em volta do depósito da vila e **não dorme** (fica de vigia). Quando um lobo ou urso chega a 16 células, corre atrás e luta (espada: 6 de dano; sem espada: 2). Com uma **armadura** na mochila, as mordidas tiram metade |
| Pescador | pinte uma zona de **Pesca** (Z, 4) na água: ele pega uma **vara de pesca** no depósito (sem vara, avisa), vai até a margem mais perto e pesca. O peixe depende da água: lago 1, mar 1 ou 2, mar fundo 3 por vez. Com 4 peixes, leva ao depósito |

- **Depósitos:** a vila não usa baú: guarda tudo em **pilhas no chão**, dentro das zonas de depósito que você pinta (Z, 5 a 8). Cada quadrado guarda **uma pilha de um item só** (até 20 madeiras, 15 pedras, 20 frutas, 40 sementes, 15 pães, 5 ferramentas...), então o tamanho da zona é quanto cabe: um depósito 4 x 4 tem 16 pilhas. O quadrado precisa estar **limpo** (sem árvore, pedra ou arbusto) e fora da água. Cada tipo aceita uma coisa:

| Depósito | Guarda |
|---|---|
| 5 Comida | frutas, carne, peixe, trigo, pão, sementes e assados |
| 6 Materiais | madeira, pedra, couro, minério, carvão, barras de ferro |
| 7 Ferramentas e armas | machados, picaretas, enxadas, vara, cesto, arco, flechas, espada, armadura, roupa e mochila de couro, tochas |
| 8 Geral | qualquer coisa (menos construções: fogueira, baú, cerca...) |

  Quem leva carga procura o depósito mais perto **com lugar** para aquele item (sem lugar, avisa: "A vila precisa de depósito com lugar"). Comida nas pilhas estraga **como no chão**, e mais rápido na chuva. Seu baú continua seu: os moradores não mexem nele. Botão direito num quadrado do depósito (a até 4 células) abre tudo o que está nas pilhas em volta (5 células): pegar e guardar mexe direto nas pilhas.

![Um depósito de materiais 3 x 3: madeira e pedra em pilhas](screenshots/deposito.png)

- **Árvores crescem por ano:** muda → **jovem** com 1 ano (12 dias) → **adulta** com 2 anos, que dá madeira. Jovem não se corta. No inverno não crescem.

- **Caminhos:** onde se anda muito (pessoas e você) o mato vira **terra batida**, e nela se anda 25-30% mais rápido. Caminho pouco usado volta a ser mato aos poucos.
- **Estradas:** quem tem a tarefa **Obras**, quando não tem casa nem cerca para fazer, **pavimenta os caminhos mais usados** (de preferência emendando nas estradas que já existem). Cada quadrado gasta 1 pedra do depósito; o construtor busca até 4 por viagem e deixa sempre 12 no depósito para as casas. Na estrada se anda 50% mais rápido.
- **Ninguém atravessa ninguém:** cabem no máximo **2 pessoas por quadrado** (você conta). Quem vê alguém no quadrado da frente vai pela sua direita, então dois se cruzam sem bater; quem fica esperando demais (uns 2 s; você 1 s) passa assim mesmo, para ninguém ficar trancado.
- **Ferramentas de ferro da vila:** ponha machado, picareta ou enxada de ferro num depósito: quem trabalha na Floresta, na Pedra ou na Plantação vai lá pegar a sua e trabalha **2x mais rápido**.
- **Cada morador enxerga em volta** (7 células de dia, 3 de noite): o mapa vai se revelando por onde a vila anda, e você vê o que acontece longe de você.
- No painel **P**, a coluna **Agora** mostra o que cada um está fazendo (cortando, quebrando, construindo, na fornalha, vai comer, dormindo...). Passe o mouse numa pessoa: nome, idade, tarefa, fé e o que está fazendo.
- As pessoas da vila passam pelas cercas (abrem o portão); os bichos não.

![A vila trabalhando, com as zonas pintadas](screenshots/pessoas.png)
![Painel das pessoas](screenshots/painel.png)
![O pincel de zonas: uma zona de Pesca na água e a pescadora na margem](screenshots/pincel.png)
![A mochila da pescadora: lanche, vara e peixes](screenshots/morador.png)

**Casas e a vila crescendo**

- Cada família tem um **terreno 5 x 5** com a casa no meio. Quem tem a tarefa **Obras** pega o material no depósito e constrói, nesta ordem:

| Obra | Material | O que muda |
|---|---|---|
| Barraco | 10 madeira | para família nova (sem casa); cabem **4** |
| Casa | 25 madeira, 10 pedra | o barraco vira casa; cabem **8** |
| Cerca | 12 madeira | cerca em volta do terreno, com portão na frente |

- Família nova constrói numa **zona de Moradia** (Z, 4): pinte onde a vila pode crescer. Cada terreno ocupado aparece com uma cor mais escura e não muda com outras zonas. Sem lugar, as Obras avisam.
- **Casamentos:** rapaz e moça solteiros (16 anos ou mais, até 20 anos de diferença) de **sobrenomes diferentes** se casam e formam uma **família nova**, que precisa de barraco.
- **Nascimentos:** casal com casa e lugar sobrando tem filhos de vez em quando (no máximo um a cada ano e meio; a mãe até 45 anos). O filho leva o **sobrenome do pai**.
- **Árvore genealógica:** no painel **P**, aba **Famílias**: cada sobrenome com os pais, os filhos embaixo (com recuo) e o cônjuge ao lado. Quem morreu ou foi embora fica, em cinza.

![A vila com casa, barracos e cerca](screenshots/vila.png)
![Árvore genealógica](screenshots/familias.png)

**Sobrevivência**

- **Fome:** quando enche (comendo), fica **cheia por 4 minutos** antes de começar a cair. Comer de novo com ela cheia renova esse tempo. Depois cai de cheia a vazia em uns 16 minutos. Sem comida, a vida cai.
- **Calor:** de dia fica tudo bem. À noite esfria; perto de uma fogueira acesa (5 células), esquenta. Sem calor, a vida cai.
- **Vida:** só volta com a **fome cheia** (e sem passar frio). O HUD mostra "cheia" e um filete amarelo com o tempo que ainda falta.
- **Dia e noite:** um dia dura **12 minutos** (a noite, uns 3). A noite escurece a tela de verdade; só a fogueira e uma luz fraca em volta do personagem iluminam.

**Stamina e corrida**

- Correr deixa o personagem ~1,7x mais rápido e gasta **stamina** (de cheia a vazia em uns 5 s, no começo).
- A **stamina máxima** começa em 100 e cresce com as skills Corrida e Natação: +0,4 por ponto de cada uma, até 180. O HUD mostra atual/máximo.
- Nadar também gasta a mesma stamina.
- Ela volta parado em terra (rápido), andando (devagar) e na água rasa (mais devagar).
- Se a stamina zerar, só dá para correr de novo quando ela voltar a 25.

**Mochila e peso**

| Item | Peso |
|---|---|
| Madeira | 1,5 kg |
| Pedra | 2,0 kg |
| Fruta | 0,1 kg |
| Cerca | 1,0 kg |
| Portão | 3,0 kg |
| Estrada | 2,0 kg |
| Peixe | 0,5 kg |
| Enxada | 1,5 kg |
| Semente | 0,1 kg |
| Trigo | 0,3 kg |
| Pão | 0,4 kg |

- O limite começa em **30 kg** e aumenta com a skill Força (até 60 kg).
- Acima do limite: **anda bem mais devagar**, não corre, e nadar cansa o dobro.
- Com 1,5x o limite, não consegue pegar mais nada.
- O que você larga vira uma **pilha no chão**; dá para coletar de volta com o botão esquerdo.

**Skills**

Cada skill vai de nível 0 a 10.

- Sobe treinando, mais devagar quanto mais alta. Para chegar perto do máximo são uns 20 minutos só nadando (ou correndo), ou umas 650 madeiras cortadas.
- Depois de **2 minutos sem treinar**, começa a cair devagarzinho (~1 nível a cada 40 minutos).
- Na janela do personagem, `+` verde = treinando agora e `-` laranja = caindo.

| Skill | Treina | Efeito no máximo |
|---|---|---|
| Natação | nadando | nada quase 2x mais rápido, cansa 60% menos e +40 de stamina máxima |
| Corrida | correndo | corre 2,2x mais rápido, cansa 50% menos e +40 de stamina máxima |
| Lenhador | cortando árvores | corta 2x mais rápido |
| Mineração | quebrando pedras | quebra 2x mais rápido |
| Força | andando com mais de 60% do limite de peso | carrega até 60 kg |
| Pesca | pegando peixes | o peixe morde na metade do tempo, mais tempo para fisgar e chance de um peixe a mais |
| Agricultura | arando e colhendo trigo | 50% de chance de 1 trigo a mais e 1 semente a mais em cada colheita |

![Mochila e skills](screenshots/mochila.png)

**Estações e clima**

O ano tem 4 estações de 4 dias cada (48 minutos), e o jogo começa na primavera. Dentro de cada estação, o clima muda a cada poucos minutos, sorteado do que é comum naquela época:

| Estação | Clima comum |
|---|---|
| Primavera | sol, nublado, chuva, às vezes tempestade |
| Verão | sol e calorão, às vezes tempestade |
| Outono | chuva, nublado, tempestades |
| Inverno | neve, nublado, granizo |

Depois de uma tempestade (fora do inverno), metade das vezes vem uma **enchente**. Cada clima entra e sai devagar, em uns 20 s. O nome da estação e do clima fica na barra de cima.

| Clima | Efeito |
|---|---|
| Sol | normal |
| Nublado | um pouco mais escuro |
| Chuva | esfria, a fogueira queima 2x mais rápido, enxerga menos; frutas voltam 2x mais rápido |
| Tempestade | escuro, relâmpagos, esfria bastante, fogueira queima 4x mais rápido, enxerga bem menos, mais lento e cansa mais |
| Calorão | esquenta (até de noite), 2x mais fome, cansa 50% mais e recupera a stamina pela metade |
| Neve | frio forte até de dia, anda 20% mais devagar, mais fome |
| Granizo | machuca fora do abrigo ("Granizo: perdendo vida!") |
| Enchente | a água sobe até 120: praias e campos baixos viram água rasa ou funda por uns 4 minutos e depois baixam; fogueiras alagadas apagam |

O **abrigo** protege do frio do clima e do granizo.

![Os 8 climas](screenshots/clima.png)

**Água**

| Nível | Onde | O que acontece |
|---|---|---|
| **Rasa** | beira de lagos e praias | anda um pouco mais devagar |
| **Funda** | meio dos lagos e do mar | nada (mais devagar ainda), gasta **stamina** e esfria. Sem stamina, quase não sai do lugar e começa a se afogar |
| **Mar aberto** | água muito funda perto das bordas do mapa | aviso de tubarão; uma barbatana começa a rodear e chega mais perto. Em 7 segundos ele ataca |

![Nadando](screenshots/nado.png)
![Tubarão](screenshots/tubarao.png)

**Neblina de guerra**

- O mapa começa todo **preto**: você descobre andando.
- O personagem enxerga até **15 células de dia** e **5 de noite** (diminui aos poucos no entardecer). Fogueiras acesas também revelam em volta.
- **Árvores tapam a visão**: dentro da floresta você enxerga bem menos.
- O que você já viu mas não está vendo agora aparece **escurecido e sem cor**, do jeito que estava da última vez. Um arbusto que voltou a dar frutas longe dos seus olhos continua aparecendo vazio até você voltar lá.

## Salvar e carregar

- **F5** salva tudo num arquivo só, `ermo.sav`, na pasta de onde o jogo foi aberto: você (vida, fome, mochila, skills, ferramentas), a hora, o dia e o clima, o que mudou no mundo (árvores cortadas, pedreiras, terra arada, plantas, cercas, construções, baús e pilhas dos depósitos), o que você já viu, os animais e a vila inteira (pessoas, mochilas, tarefas, zonas, casas e a árvore genealógica). Não dá para salvar morto nem dormindo.
- **F9** carrega o último jogo salvo, a qualquer hora (e depois de morrer).
- Ao abrir o jogo, se tiver um `ermo.sav`, a tela de título já mostra o mundo dele: **ENTER** (ou **C**) continua. **N** começa um jogo novo nesse mundo e **R** sorteia outro mundo.
- O relevo sai da semente do mundo, então o arquivo guarda só o que muda (uns 2 MB).

## Desafio

O mundo é difícil de propósito: comida é pouca e estraga, o inverno pesa e as noites são perigosas.

- **Comida estraga:** carne e peixe crus perdem um quarto a cada 6 horas de jogo (em 1 dia, de 8 sobram 3), frutas a cada 12 horas, assados a cada 18 horas. No seu **baú** estraga na metade da velocidade; nas pilhas dos depósitos, como no chão (mais rápido na chuva). Pão, trigo e sementes não estragam. Quando algo estraga na sua mochila, aparece "Estragou: ...".
- **Fome mais rápida**, para você e para a vila; no inverno, 25% mais.
- **Pouca comida no mundo:** poucos arbustos (que demoram dias para voltar e não dão no inverno), pouco trigo selvagem, o trigo plantado cresce mais devagar e só na primavera e no verão. É preciso guardar comida (pão dura) antes do outono.
- **Inverno duro:** mesmo de sol, fora do abrigo e longe do fogo o calor cai devagar (de noite, depressa); a roupa de couro corta pela metade. Quase não aparecem bichos de caça.
- **Noites perigosas:** a partir do 2º dia, ao escurecer (20:24), pode vir uma **alcateia** atrás da vila: chance de 25% + 10% por dia (+30% no inverno), com 2 lobos + 1 a cada 3 dias (até 6; +1 no inverno). Ela aparece a 22 células do depósito da vila e vai direto para lá. Casas, fogueiras e o **soldado** protegem; às 06:00 os lobos que sobraram vão embora.
- **Pedreiras e minas** em manchas de várias células; cada célula que acaba vira buraco.

![Pedreira: o chão cinza, as pedras e o buraco das células esgotadas](screenshots/pedreira.png)
![De noite, a alcateia chega e o soldado defende a vila](screenshots/soldado.png)

## Como funciona

| Arquivo | O que tem |
|---|---|
| `comum.h` | macros e constantes compartilhadas |
| `ermo.S` | janela, entrada, geração do mundo, terreno (e a terra arada), árvores |
| `sobrevivencia.S` | personagem, coleta, mochila, skills, fabricar, baús, abrigos, fome, calor, fogueiras, água, noite e interface |
| `clima.S` | estações, sorteio do clima, efeitos, chuva/neve/granizo, cor do clima e relâmpago |
| `animais.S` | animais (aparecer pelo terreno, fugir, perseguir, morder), flechas e golpes |
| `cercas.S` | cercas e portões: grade de colisão, fileira travada em 8 direções, grade e prévia na tela, trocar cerca por portão |
| `pesca.S` | vara de pesca: lançar, boia, mordida, fisgar, tipo de peixe pela água |
| `plantacao.S` | trigo selvagem, enxada, sementes, crescimento (água, clima, estação), colheita e bichos que comem a plantação |
| `pessoas.S` | as pessoas: idade, fé, fome e sono, tarefas e zonas, painel, ordens, floresta e caminhos de terra batida |
| `ferro.S` | fornalha, lampiões, ferreiro, ferramentas de ferro da vila e a visão dos moradores |
| `desafio.S` | pedreiras e minas, comida que estraga, manadas, alcateias da noite e o soldado |
| `salvar.S` | salvar e carregar o jogo (F5 / F9) e o "continuar" da tela de título |
| `deposito.S` | os depósitos da vila: zonas, pilhas no chão, o que cada um aceita, pegar e guardar |
| `personagens.S` | os desenhos do profeta e dos moradores em 8 direções e 3 poses (gerado por `arte/personagens.py`) |
| `construcoes.S` | escolhe o desenho de cada construção (aberto/fechado, aceso/apagado, vizinhos, tamanho da pilha) e as cinzas da fogueira |
| `estruturas.S` | os desenhos das construções, pilhas e estrada (gerado por `arte/estruturas.py` a partir do `design/estruturas/estruturas.json`) |
| `estradas.S` | estradas: colocar, desfazer, e a vila pavimentando os caminhos |
| `colisao.S` | no máximo 2 pessoas por quadrado, mão direita e ninguém trancado |
| `vitrine.S` | a vitrine do `--shot`: todas as construções lado a lado, de dia e de noite, para comparar desenhos |
| `mochila.S` | a mochila de cada morador (carga, lanche, ferramenta, dar e pegar), o pescador e o pincel de zonas |
| `intel/instalar.sh` | prepara um Ubuntu x86-64 para rodar o jogo emulado (QEMU) |
| `vila.S` | casas e terrenos, obras (barraco, casa, cerca), casamentos, nascimentos, árvores que crescem por ano e a árvore genealógica |
| `pessoas.h` | estruturas da pessoa, do parentesco e da casa |

- **Geração:** ruído fractal num mapa de altura de 512x512, só com aritmética inteira. A mesma semente sempre gera o mesmo mundo.
- **Terreno contínuo ("voxel space" isométrico):** cada coluna da tela anda pelo mundo de frente para trás e pinta só o que fica visível. As 1280 colunas são divididas entre **8 threads**, uma para cada núcleo.
- **Objetos com z-buffer:** árvores, pedras, arbustos, fogueiras e o personagem respeitam a profundidade do terreno.
- **Visão:** a cada quadro saem 360 raios do personagem e de cada fogueira. Cada raio perde transparência ao passar por células com árvores. O resultado vai para dois mapas: "vendo agora" e "já visto". Cada objeto guarda também o estado em que foi visto por último.
- **Neblina e noite:** depois de desenhar o mundo, cada pixel descobre a que ponto do mapa pertence (pelo z-buffer), lê os dois mapas com interpolação suave e escurece/descolore o que não está à vista; de noite multiplica pela luz ambiente mais a luz das fogueiras. Essa passada também roda nas 8 threads.
- **Interface:** botões, janelas e ícones são desenhados com retângulos pelo SDL; os ícones da mochila são os mesmos sprites das pilhas no chão.
- **Clima:** a chuva, a neve e o granizo são partículas sem estado: a posição de cada uma sai de um hash do seu número e do quadro atual, então não precisa guardar nada. A cor do clima é misturada em cada pixel na proporção do brilho dele (a neblina preta continua preta), nas 8 threads. Na enchente, o terreno abaixo do nível da água é desenhado como água na superfície.
- **SDL3** só abre a janela, lê teclado e mouse e mostra o framebuffer na tela.

## Compilar e rodar (macOS com Apple Silicon)

```sh
xcode-select --install     # se ainda não tiver as ferramentas da Apple
brew install sdl3
make run
```

## Compilar e rodar (Linux ARM64)

```sh
sudo apt install libsdl3-dev   # ou compile o SDL3 a partir do código-fonte
make run
```

## Jogar num Mac Intel (ou PC Intel/AMD)

O Ermo é assembly ARM64, então num processador Intel ele roda **emulado**: um Ubuntu numa máquina virtual e, dentro dele, o QEMU traduzindo o ARM64. Fica mais lento que no Mac com chip M; por isso começa no **modo leve** (F10 liga e desliga). Dê à máquina virtual o máximo de núcleos que puder: o jogo desenha em 8 threads.

1. Instale o [UTM](https://mac.getutm.app) (grátis) e baixe o **Ubuntu 24.04 Desktop** (amd64) em [ubuntu.com/download/desktop](https://ubuntu.com/download/desktop).
2. No UTM: **Create a New Virtual Machine → Virtualize → Linux**, escolha o ISO do Ubuntu, dê **4 GB** de memória ou mais, **todos os núcleos menos 1 ou 2** e uns **25 GB** de disco. Instale o Ubuntu normalmente.
3. No Ubuntu, abra o Terminal e rode:

```sh
sudo apt install -y git
git clone https://github.com/pascalfuentes/trilhos.git ~/trilhos
bash ~/trilhos/intel/instalar.sh
```

O script (`intel/instalar.sh`) liga os pacotes arm64 do Ubuntu, instala o QEMU e o compilador ARM64, compila o SDL3 para ARM64 (janela X11) e o jogo, e cria o `~/trilhos/jogar.sh` e o atalho **Ermo** nos aplicativos. Para jogar: `~/trilhos/jogar.sh`. Para atualizar depois: `bash ~/trilhos/intel/instalar.sh --so-jogo`.

O tempo do jogo anda por quadro: se a máquina virtual desenhar menos de 60 quadros por segundo, o dia passa mais devagar.

`./ermo --shot` roda sem interação: tira screenshots, mede o tempo de cada quadro e faz um teste automático (coleta duas árvores, uma pedra e um arbusto, monta uma fogueira, come e passa a noite; corre, anda carregado, larga e recolhe uma pilha de pedras, vê a skill cair sem treino, confere que a vida só sobe com a fome cheia; fabrica tudo, monta baú e abrigo, gasta o machado, acende a tocha à noite, passa a noite no abrigo e dorme das 22h às 06h; passa 10 s em cada um dos 8 climas (com foto); caça um cervo com o arco, enfrenta um lobo à noite com o machado e vê os animais aparecendo; faz um cercado e pesca; ara e planta 6 células perto da água, colhe o trigo maduro, confere que o verde não sai e que a enxada desfaz a terra (e perde a semente), faz pão, compara o crescimento com e sem água e no inverno, e solta um coelho perto do trigo sem cerca; monta a vila (3 barracos) com zonas de floresta, pedra, plantação e moradia e deixa trabalhar 3 horas (com foto pintando zonas e do painel), confere o depósito, a terra arada, o trigo, as mudas, os caminhos e as obras (casa e cerca), manda todos dormir, passa 24 dias (as mudas viram jovens e depois adultas, casamentos e nascimentos), deixa as obras fazerem o barraco do casal novo (foto da vila e da árvore genealógica) e solta um lobo perto de uma pessoa; tenta quebrar um veio sem picareta, minera ferro e carvão, monta a fornalha, faz 18 barras, carvão de madeira, ferramentas, espada, armadura e um lampião, compara o machado de pedra com o de ferro, deixa um lobo morder com armadura (foto de noite na fornalha) e põe um ferreiro, um veio e um machado de ferro na vila; pinta e apaga com o pincel, pinta uma zona de Pesca perto do depósito, põe uma vara no depósito e uma pescadora para trabalhar 2 horas, confere o lanche nas mochilas e dá e pega pão da mochila de uma pessoa (fotos do pincel e da mochila dela); conta pedreiras, minas, arbustos e trigo, esgota uma pedreira (foto), deixa 8 carnes cruas 1 dia na mochila e no depósito, passa 10 s de sol no inverno, solta uma manada de cervos e confere que fica junta e, de noite, solta uma alcateia de 4 lobos na vila com um soldado de espada (foto); salva o jogo, bagunça o dia, uma pessoa, um baú, a mochila e os objetos, carrega de volta e confere que tudo voltou; pinta um depósito de materiais 3 x 3, guarda 100 madeiras e 50 pedras, confere que frutas não entram, tira madeira, abre o depósito, pega e guarda pedras (foto); arrasta 6 estradas, desfaz uma com a enxada e põe um construtor sem obras num caminho de terra batida de 12 células (confere que ele pavimenta); cruza 4 pessoas num corredor e confere que todas chegam sem nunca ter 3 no mesmo quadrado; monta a vitrine com todas as construções e estradas num lugar plano e fotografa de dia, de noite e de longe, sem a interface (`shot_estruturas.bmp`, `shot_estruturas_noite.bmp` e `shot_estruturas_longe.bmp`); depois nada num lago e vai para o mar aberto até o tubarão atacar).

## Próximos passos

- [x] Fabricar: machado, picareta, tocha, baú, abrigo, cesto, frutas assadas
- [x] Minérios (ferro, carvão), fornalha, ferramentas de ferro, espada, armadura e lampião
- [x] Animais e caça (arco, flechas, carne, couro)
- [x] Pesca e plantação (trigo, enxada, sementes, pão)
- [x] Pessoas: famílias, fé, idade, tarefas e zonas
- [x] Casas que crescem (barraco, casa, cerca), casamentos, nascimentos e árvore genealógica
- [x] Pescador da vila, mochila de cada morador e pincel de zonas
- [x] Mundo mais difícil: pedreiras, comida que estraga, manadas, inverno duro, alcateias e soldados
- [ ] Pessoas caçando
- [x] Salvar e carregar o jogo
- [x] Construções novas do designer, estradas de pedra e colisão entre pessoas
