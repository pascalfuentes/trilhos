# Pedido 1.0 ao designer: janela do personagem e subir de nível

Cole o texto abaixo no designer. Ele continua o guia de estilo do pedido 0.0 (mesma paleta-mestra, mesmas regras).

---

Obrigado pelo guia de estilo: o herói, o lobo, as árvores, as pedras e o chão já estão no jogo, com a versão mais sombria. Este pedido é para a **fase 1 do RPG: nível e atributos**.

## Como funciona no jogo

- O herói começa no **nível 1** e ganha **XP** abatendo inimigos. Para subir do nível N para o N+1 são precisos round(1,5^(N−1)) pontos de XP (1, 2, 2, 3, 5, 8, 11…), sem nível máximo.
- A cada nível ganha **5 pontos de atributo** para distribuir entre:
  - **Força:** mais dano e mais peso carregado;
  - **Destreza:** acerta mais e ataca mais rápido;
  - **Vitalidade:** mais vida;
  - **Energia:** mais mana.
- A janela do personagem abre com a tecla **C**. Hoje ela é só texto; queremos a versão desenhada.

## Regras (as mesmas do pedido 0.0)

- Tudo a 1×. A interface do jogo tem **640 × 360 px** e é ampliada 2× na tela (1280 × 720), sem suavizar.
- Paleta-mestra do 0.0. Para a interface, use as rampas de interface: moldura `Á Â Ã`, fundo `É Ê`, texto `Í Î`. Use as outras rampas onde fizer sentido (ouro, couro, ferro, sangue…).
- Contorno de 1 px no tom mais escuro da própria rampa. Cores de **brilho** marcadas (não escurecem).
- O texto **não** precisa ser desenhado: o jogo escreve por cima com uma fonte de 8 × 8 px. Deixe as áreas de texto vazias e diga onde ficam (x, y, largura).

## O que desenhar

1. **Janela do personagem**, 216 × 232 px:
   - moldura de pedra e couro no estilo do mockup;
   - um lugar para o **retrato** do herói (o quadro de 32 × 48 do herói, de frente);
   - uma linha para o **nome** e o **nível**;
   - uma **barra de XP** (vazia e cheia, para o jogo encher pela porcentagem);
   - **4 linhas de atributo**, cada uma com ícone, nome, valor e um **botão +**;
   - uma linha "pontos para distribuir: N";
   - um bloco de **valores derivados** (vida, mana, dano, acerto, defesa), só a área.
2. **Botão +** de 11 × 11 em 4 estados: normal, mouse em cima, apertado e desligado (sem pontos).
3. **Ícones dos atributos**, 16 × 16 cada: Força, Destreza, Vitalidade e Energia.
4. **Barra de XP da tela** (a que fica sempre visível): 1 × 6 px repetível no meio, pontas esquerda e direita, e o preenchimento em roxo.
5. **Efeito de subir de nível** em volta do herói: quadro de **48 × 64**, âncora nos pés em (24, 61), **8 quadros**, com cores de brilho (luz dourada subindo). Ele é desenhado por cima do herói, que tem 32 × 48 com âncora em (16, 45).
6. **Opcional:** uma **fonte de pixel** de 8 × 8 com A–Z, a–z, 0–9, pontuação e os acentos do português (á à â ã é ê í ó ô õ ú ç e as maiúsculas). Se fizer, o jogo troca a fonte de hoje por ela.

## Formato da entrega

Igual ao do 0.0:

- **um artboard por peça,** com a peça ampliada 8× e uma prévia a 1× e a 2×, e a janela montada com textos de exemplo para mostrar onde vai cada coisa;
- **um bloco de dados** (`ermo_fase1.json`) com cada peça em linhas de texto, um caractere por pixel (`.` = transparente), mais:
  - `areas`: onde o jogo escreve ou desenha, como `{"nome": [x, y, largura, altura], "nivel": […], "xp": […], "forca_valor": […], "forca_mais": […], …}`;
  - `cores`: a tabela de cores de cada peça.

---

## Para mim (integração)

Quando voltar: estendo o `arte/pixel.py` para ler o `ermo_fase1.json`, desenho a janela C com as áreas dele e ligo os botões + (etapas 1.3 e 1.4).
