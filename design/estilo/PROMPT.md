# Pedido 0.0 ao designer: guia de estilo do Ermo (RPG em pixel art)

Cole o texto abaixo no designer junto com `mockup.png` e `gabarito.png` desta pasta.

---

O **Ermo** mudou. Deixou de ser um jogo de vila e virou um **RPG de ação** no estilo do Diablo 2: um herói, clique para andar e atacar, itens que caem no chão e uma árvore de skills. O mundo é um **planeta** com faixas de clima: neve nos polos, depois tundra, floresta, savana e deserto no equador, além de mar e ilhas.

A visão continua **isométrica** (como nos personagens e estruturas que você já fez), mas o visual passa a ser **pixel art no estilo do Terraria**.

Este primeiro pedido é o **guia de estilo**: as regras e algumas peças de amostra que valem para todos os pedidos seguintes (personagem com equipamento, inimigos, itens, interface, cidades, biomas…). Não precisa desenhar o jogo todo agora.

## O que mando junto

- `mockup.png`: um rascunho nosso de uma cena (400 × 225 px, ampliado 4×). É só a direção: refaça melhor, não precisa copiar.
- `gabarito.png`: os tamanhos e âncoras em que o jogo espera cada coisa, ampliados 8× (cada quadradinho = 1 px).

## Direção de arte

- Pixel art como no Terraria: formas fortes e legíveis, cores saturadas e **contorno de 1 px** em personagens, inimigos, itens e objetos. O contorno usa o tom mais escuro do próprio material, não preto puro. O chão não tem contorno.
- **3 a 4 tons por material**, com luz de cima e da esquerda (lado direito mais escuro). Sem degradê suave, sem anti-aliasing contra o fundo transparente e sem dithering pesado.
- Cada bioma com uma cara de cor bem distinta, como neve, selva e deserto no Terraria, mas todos da mesma família.
- **Leitura em primeiro lugar:** o herói, o inimigo e o item no chão precisam se destacar do chão mesmo a 2×.
- Desenhe tudo **de dia**. A noite e as tochas o jogo faz sozinho: escurece bloco a bloco e acende em volta das fontes de luz. Pixels que brilham no escuro (fogo, olhos, magia, janela acesa) usam cores marcadas como **brilho**, que o jogo não escurece.
- **Desenhos originais:** nada de personagens, monstros ou itens do Terraria nem de outro jogo. Só o estilo é a referência.

## Regras técnicas (para encaixar sem ajuste)

1. **Resolução:** tudo em 1×, ou seja, 1 pixel do desenho = 1 pixel do arquivo. O jogo amplia 2×, 3× ou 4× sem suavizar.
2. **Chão:** losango isométrico 2:1 de **32 × 16 px**. Andar +1 em **u** vai 16 px para a direita e 8 px para baixo; +1 em **v** vai 16 px para a esquerda e 8 px para baixo.
3. **Degraus:** um degrau de terreno (penhasco) tem **16 px** de altura. Um bloco inteiro é o topo 32 × 16 mais as faces de 16 px. Face esquerda clara, face direita na sombra.
4. **Personagens e inimigos de tamanho humano:** quadro de **32 × 48 px**, com o herói ocupando uns 24 × 40. A **âncora fica nos pés, em (16, 45)**. Inimigos maiores podem usar quadros maiores, sempre com a âncora nos pés.
5. **Direções:** desenhe **5** (S de frente, SE, L de lado, NE, N de costas). O jogo espelha SE → SO, L → O e NE → NO. No espelho a arma troca de mão, e tudo bem.
6. **Equipamento em camadas:** o corpo vem com roupa de baixo, e cada peça vai num desenho separado, **no mesmo quadro e com a mesma âncora**:
   - botas;
   - calça;
   - peito;
   - luvas;
   - capacete;
   - arma na mão;
   - segunda mão (escudo ou outra arma).

   Diga, para cada direção, a ordem de desenho. Por exemplo: de costas, a arma vai atrás do corpo.
7. **Pele e tintura:** o corpo usa uma rampa fixa de **4 tons de pele** com os caracteres `1 2 3 4` (do claro ao escuro). O jogo troca essa rampa por 6 tons de pele. Roupa tingível usa outra rampa fixa, `5 6 7 8`.
8. **Animações:** o tamanho do trabalho todo, por direção, é parado 4 quadros, andar 8, atacar 6, levar golpe 2 e morrer 6. **Neste pedido, só "parado".**
9. **Itens:** cada item tem dois desenhos:
   - **ícone de mochila**, numa grade de células de **16 × 16 px**: anel e poção 1 × 1 (16 × 16), espada 1 × 3 (16 × 48), armadura 2 × 3 (32 × 48);
   - **no chão**, uma versão pequena e deitada de até **16 × 12 px**, com a âncora no meio da base.
10. **Árvores, pedras e objetos:** a base fica dentro do losango e a âncora no centro do losango; o resto pode subir à vontade.
11. **Paleta:** indexada, com até ~200 cores no jogo inteiro, organizadas em **rampas de 3 a 5 tons** por material.

## O que entregar neste pedido

1. **Paleta-mestra** com o nome de cada rampa:
   - grama, terra, pedra/rocha, areia, neve/gelo;
   - água rasa e funda;
   - madeira, folhas (2 verdes e pinheiro);
   - ferro, aço, ouro, couro;
   - pano tingível (`5–8`), pele (`1–4` e os 6 tons de troca);
   - sangue, veneno;
   - **brilho**: fogo, magia, olhos;
   - interface: moldura, fundo de janela, texto.
2. **Chão de amostra:**
   - grama com 4 variações do losango;
   - areia, neve, água e estrada de pedra;
   - a transição de grama para areia;
   - um bloco de penhasco com topo de neve e faces de rocha.
3. **Herói base:** homem e mulher, parados nas 5 direções, com roupa de baixo simples.
4. **Um conjunto de equipamento em camadas** (capacete, peitoral, botas e espada) nas 5 direções, por cima do herói.
5. **Um inimigo:** lobo parado nas 5 direções.
6. **Três itens:** espada (ícone 1 × 3 e no chão), anel (1 × 1) e poção de vida (1 × 1).
7. **Objetos:** árvore de folha, pinheiro com neve, pedra e tocha (com a chama em cores de brilho).
8. **Uma cena montada** com essas peças, a 1× e a 4×, de dia e à noite com a tocha, como no `mockup.png`.
9. **Uma folha de regras** de uma página (o guia em si): contorno, tons, luz, brilho e tamanhos, para usar nos próximos pedidos.

## Formato da entrega

É o mesmo formato dos pedidos anteriores:

- **Um artboard por peça,** com:
  - o desenho ampliado 8× sobre o losango ou o quadro, com a âncora marcada;
  - uma prévia a 1× e a 2×.
- **Um bloco de dados** com cada quadro em **linhas de texto, um caractere por pixel** (`.` = transparente) e a tabela de cores de cada peça:

```js
{
  "heroi_homem": {
    "quadro": [32, 48],
    "ancora": [16, 45],
    "camada": "corpo",
    "direcoes": {
      "S":  { "parado": [["....linha 0....", "...linha 1...", "..."], ["quadro 2"], ["quadro 3"], ["quadro 4"]] },
      "SE": { "parado": [] }, "L": { "parado": [] }, "NE": { "parado": [] }, "N": { "parado": [] }
    },
    "cores": { "k": "#1C1424", "1": "pele 1", "2": "pele 2", "3": "pele 3", "4": "pele 4", "a": "#A0A8B8" }
  },
  "capacete_ferro": {
    "quadro": [32, 48], "ancora": [16, 45], "camada": "capacete",
    "ordem": { "S": "frente", "SE": "frente", "L": "frente", "NE": "frente", "N": "frente" },
    "direcoes": { },
    "cores": { }
  },
  "chao_grama": { "quadro": [32, 16], "variacoes": [["..."], ["..."], ["..."], ["..."]], "cores": { } },
  "espada_curta": { "icone": { "celulas": [1, 3], "linhas": ["..."] }, "chao": { "quadro": [16, 12], "linhas": ["..."] }, "cores": { } }
}
```

Use o mesmo caractere para a mesma cor da paleta-mestra em todas as peças. Marque no `cores` quais são de **brilho** (por exemplo `"F": "#FFB040 brilho"`).

---

## Para mim (integração)

Quando o designer devolver, me mande o link do canvas ou o bloco de dados. Eu:

1. escrevo o gerador `arte/pixel.py` (caracteres → sprites e paleta do jogo);
2. faço a etapa 0.6 (zoom em passos inteiros e sprites ampliados sem suavizar);
3. monto a mesma cena dentro do jogo e mando um screenshot para comparar com a cena do designer.
