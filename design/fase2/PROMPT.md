# Pedido 2.0 ao designer: inimigos com nível

Cole o texto abaixo no designer. Ele continua o guia de estilo do pedido 0.0 e o pedido 1.0 (mesma paleta-mestra, mesmos caracteres, mesmas regras).

---

Obrigado pelo pedido 1.0: a janela do personagem, o botão +, os ícones, a barra de XP e a luz de subir de nível já estão no jogo. Este pedido é para a **fase 2 do RPG: inimigos com nível**.

## Como funciona no jogo

- O **lobo** e o **urso** viram inimigos de verdade, cada um com **nível**. Vida, dano e defesa crescem com o nível. Perto da primeira cidade eles têm nível 1 a 5, e o nível sobe conforme você se afasta.
- Eles andam em **grupos**. Às vezes um grupo tem um **campeão** (2 níveis acima do grupo) ou um **chefe** (4 a 5 níveis acima), como no Diablo 2.
- **De noite** os inimigos ficam 2 níveis mais fortes.
- Com o mouse em cima de um inimigo aparece, **no topo da tela**, uma barra com o **nome**, o **nível** e a **vida** dele, como no Diablo.

## Regras (as mesmas dos pedidos 0.0 e 1.0)

- Tudo a 1×. A interface tem **640 × 360 px** e é ampliada 2× (1280 × 720), sem suavizar.
- Paleta-mestra do 0.0 mais a rampa `luz_dourada` do 1.0. Se precisar de cor nova, adicione numa rampa nova em `_paleta_adicoes`, como no 1.0.
- Contorno de 1 px no tom mais escuro do próprio material. Cores de **brilho** marcadas (não escurecem de noite).
- **5 direções** (S, SE, L, NE, N); o jogo espelha SE → SO, L → O e NE → NO.
- O texto **não** precisa ser desenhado: o jogo escreve por cima com a fonte de 8 × 8. Deixe as áreas de texto vazias e diga onde ficam.

## O que desenhar

1. **Lobo inimigo**, no mesmo quadro do lobo do 0.0 (o mesmo desenho, agora animado), nas 5 direções:
   - **andar**: 8 quadros;
   - **atacar** (mordida, com o pulo para a frente): 6 quadros;
   - **levar golpe**: 2 quadros;
   - **morrer** (cai de lado e fica no chão): 6 quadros; o último quadro fica parado no chão por uns segundos.
2. **Urso inimigo**, nas 5 direções, com as mesmas animações do lobo e mais o **parado** (4 quadros). É maior que o lobo: escolha o quadro (sugestão: 48 × 40), com a **âncora nos pés**, no meio do losango.
3. **Marca de campeão e de chefe**, desenhada **embaixo** do inimigo, no chão:
   - um **anel** no losango de 32 × 16 (para o urso, 48 × 24), em cores de brilho: **azul** para o campeão e **dourado escuro** para o chefe;
   - 4 quadros girando devagar.
4. **Barra do inimigo no topo da tela** (aparece com o mouse em cima de um inimigo):
   - uma **placa** de 200 × 18 centrada no topo, em (220, 4), na moldura de interface `Á Â Ã` com fundo `Ê`;
   - dentro dela, uma barra de **vida** (vazia e cheia, 1 × N repetível, cheia em vermelho de sangue);
   - uma área de texto de 8 px de altura para "Lobo · Nv 7" por cima da barra;
   - uma variação da placa para **campeão** (detalhe azul) e para **chefe** (detalhe dourado e um pouco mais larga, se quiser).
5. **Opcional:** um respingo de **sangue** pequeno (16 × 8, 3 quadros) para quando um golpe acerta.

## Formato da entrega

Igual ao do 1.0:

- **um artboard por peça,** com a peça ampliada 8× e uma prévia a 1× e a 2×;
- **uma cena montada** a 2×: um grupo de lobos com um campeão, um urso chefe e a barra do topo com o mouse em cima do chefe, de dia e de noite;
- **um bloco de dados** (`ermo_fase2.json`) com cada quadro em linhas de texto, um caractere por pixel (`.` = transparente), no mesmo formato do lobo do 0.0:
  - `lobo_inimigo` e `urso_inimigo`: `quadro`, `ancora`, `direcoes` → `{"S": {"parado": […], "andar": […], "atacar": […], "golpe": […], "morrer": […]}, …}`;
  - `marca_campeao` e `marca_chefe`: `quadro`, `ancora`, `quadros`;
  - `barra_inimigo`: as peças da placa, a barra de vida e as `areas` (`nome`, `vida`) em `[x, y, largura, altura]`;
  - `cores` em cada peça, com as cores de brilho marcadas.

---

## Para mim (integração)

Quando voltar: estendo o `arte/pixel.py` para ler o `ermo_fase2.json`, troco o lobo parado pelas animações, coloco o urso, as marcas e a barra do topo (etapas 2.1 a 2.5).
