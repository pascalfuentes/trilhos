# Pedido 4.0 ao designer: itens em grade

Cole o texto abaixo no designer. Desenhe **no estilo 2** se ele já tiver voltado (células de 32 × 32); senão, no estilo do 0.0 (células de 16 × 16).

---

Este pedido é para a **fase 4 do RPG: itens em grade**, como no Diablo 2. A mochila vira uma grade de **10 × 4** células; cada item ocupa um retângulo dela (anel 1 × 1, espada 1 × 3, armadura 2 × 3…). Os itens caem no chão quando o inimigo morre, e segurar **Alt** mostra o nome de todos, na cor da raridade.

## O que desenhar

1. **Janela da mochila**:
   - a grade de 10 × 4 células, com fundo afundado;
   - o espaço do **ouro**, embaixo;
   - na mesma moldura de pedra e couro da janela do personagem.
2. **Janela do equipamento** (do lado da do personagem), com uma **silhueta** apagada em cada lugar vazio:
   - cabeça 2 × 2;
   - amuleto 1 × 1;
   - peito 2 × 3;
   - mão direita e mão esquerda 2 × 4 cada;
   - luvas 2 × 2;
   - cinto 2 × 1;
   - botas 2 × 2;
   - 2 anéis 1 × 1.
3. **Ícones na grade** (no tamanho das células):
   - espada curta 1 × 3, espada longa 1 × 4, machado 2 × 3, arco 2 × 3, cajado 1 × 4, varinha 1 × 2;
   - escudo 2 × 2;
   - capacete 2 × 2, chapéu 2 × 2;
   - peitoral 2 × 3, túnica 2 × 3;
   - luvas 2 × 2, botas 2 × 2, cinto 2 × 1;
   - anel 1 × 1, amuleto 1 × 1;
   - poção de vida e de mana 1 × 1;
   - pergaminho 1 × 1;
   - ouro (pilhinha 1 × 1).
4. **Itens no chão**: uma versão pequena e deitada de cada um, até 32 × 24 no estilo 2 (ou 16 × 12 no 0.0), com a âncora no meio da base. O ouro no chão em 3 tamanhos: pouco, médio e muito.
5. **Cores das raridades**, para o nome e um brilho fraco no chão:
   - normal: branco;
   - mágico: azul;
   - raro: amarelo;
   - único: dourado escuro.
6. **Cinto de poções**: 4 casas embaixo da tela, ao lado da barra de vida, com as teclas 1 a 4.
7. **Placa do nome do item** (com Alt e com o mouse em cima): fundo escuro translúcido, texto na cor da raridade.

## Formato

Igual aos anteriores: um artboard por peça e um bloco `ermo_fase4.json`. Cada ícone traz:

- `celulas` (largura × altura);
- `linhas`;
- a versão `chao`;
- as `areas` das janelas (cada célula da grade e cada lugar do equipamento, em `[x, y, largura, altura]`).
