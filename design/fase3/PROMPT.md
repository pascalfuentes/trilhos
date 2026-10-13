# Pedido 3.0 ao designer: combate (herói animado, armas e arco)

Cole o texto abaixo no designer. Se o pedido 0.7 (estilo 2) já tiver voltado, desenhe tudo **no estilo 2** (dobro de detalhe, quadro do herói 64 × 96); senão, no estilo do 0.0 (quadro 32 × 48).

---

Este pedido é para a **fase 3 do RPG: combate estilo Diablo**. O jogo já tem clicar para andar, clicar no inimigo para ir até ele e atacar, segurar para continuar atacando, Shift para atacar parado, números de dano subindo e puxar a corda do arco segurando o botão. Agora falta o herói se mexer de verdade.

## Regras

As mesmas dos pedidos anteriores:

- 5 direções desenhadas (S, SE, L, NE, N), com o espelho para as outras 3;
- tudo **em todas as camadas** do equipamento, no mesmo quadro e com a mesma âncora: corpo, cabelo, chapéu/capacete, túnica/peitoral, calça, botas, arma e segunda mão;
- contorno de 1 px no tom mais escuro do material;
- cores de **brilho** marcadas.

## O que desenhar

1. **Andar:** 8 quadros.
2. **Correr:** 6 quadros (corpo mais inclinado, passos mais largos).
3. **Ataque corpo a corpo** (espada e machado): 6 quadros, golpe de cima para baixo na direção do inimigo; o quadro 4 é o do impacto.
4. **Ataque com arco:** puxar a corda (4 quadros, o último segura enquanto o jogador segura o botão) e soltar (2 quadros).
5. **Ataque mágico** (cajado e varinha): conjurar, 6 quadros, com a mão da frente para o inimigo e um brilho no quadro 4.
6. **Levar golpe:** 2 quadros. **Morrer:** 6 quadros, termina caído.
7. **Arco, aljava e flecha novos:**
   - o arco na mão em cada direção;
   - a aljava nas costas;
   - a flecha voando em 8 direções (pode ser 1 quadro por direção);
   - a flecha cravada no chão;
   - o ícone do arco e da flecha na mochila.
8. **Projétil mágico:** bola de energia voando (4 quadros) e o impacto (4 quadros), em cores de brilho.
9. **Faísca de acerto** no inimigo (4 quadros, brilho) e **cursor de ataque** (uma espada pequena, 16 × 16) para quando o mouse está em cima de um inimigo.

## Formato

Igual aos anteriores:

- um artboard por peça;
- uma cena montada com o herói atacando um lobo, de dia e de noite;
- um bloco `ermo_fase3.json` com, para cada camada, `direcoes → {"S": {"andar": [...], "correr": [...], "atacar": [...], "arco_puxar": [...], "arco_soltar": [...], "conjurar": [...], "golpe": [...], "morrer": [...]}, ...}`, mais as peças soltas (flecha, projétil, faísca, cursor).
