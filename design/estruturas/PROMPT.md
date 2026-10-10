# Prompt para o designer: estruturas do Ermo

Cole o texto abaixo no designer junto com as imagens desta pasta
(`estruturas.png`, `estruturas_noite.png`, `detalhe_*.png`, `folha_estruturas.png`,
`paleta.png` e a pasta `sprites/`).

---

Quero redesenhar as **estruturas** do meu jogo **Ermo** (sobrevivência + vila, visão isométrica, pixel art). Você já desenhou o **profeta** e os **cidadãos** (homem, mulher, menino, menina) para ele, com sprites de 14 × 22 px, 8 direções, cores chapadas e sem contorno. As estruturas novas precisam combinar com esses personagens e com o chão do jogo.

## O que mando junto

- `estruturas.png` e `estruturas_noite.png`: todas as estruturas atuais lado a lado no jogo, ao meio-dia e às 22h (sem a interface, no zoom mais perto).
- `detalhe_esquerda.png`, `detalhe_direita.png`, `detalhe_frente.png`, `detalhe_noite.png`: os mesmos recortes ampliados 2×.
- `folha_estruturas.png`: cada sprite atual ampliado 8× sobre o losango da célula do chão que ele ocupa, com tamanho e âncora.
- `sprites/`: cada sprite atual em PNG 8×, fundo transparente (barraco e casa nas 4 cores de família).
- `paleta.png`: as cores que as estruturas usam hoje.

Os desenhos atuais são de frente, achatados, e não parecem estar no mesmo chão isométrico. Quero que pareçam construídos **em cima do losango** do chão, com volume (topo, lado esquerdo claro, lado direito na sombra), no mesmo estilo dos personagens.

## Regras do ambiente (para encaixar sem ajuste)

1. **Projeção:** isométrica 2:1. Uma célula do chão é um losango de **24 × 12 px** na mesma resolução dos personagens (o profeta tem 14 × 22; um adulto tem 18 px de altura). Uma construção 2 × 2 ocupa um losango de 48 × 24 px.
2. **Eixos:** andar +1 em **u** vai 12 px para a direita e 6 px para baixo na tela; +1 em **v** vai 12 px para a esquerda e 6 px para baixo. As construções não giram: são desenhadas sempre nesta mesma vista.
3. **Âncora:** em cada quadro, marque o **ponto do chão** (x, y): o centro do losango ocupado. O jogo põe esse ponto em cima da célula. A ordem de desenho usa a profundidade desse ponto, então tudo o que é da estrutura fica dentro de um quadro só.
4. **Tamanho:** a base deve caber no losango (24 × 12 ou 48 × 24); o que sobe (telhado, chaminé, chama, poste) pode passar para cima à vontade. Fique perto da proporção dos personagens: a porta do abrigo, do barraco e da casa tem que caber um adulto de 18 px.
5. **Luz:** de dia a luz vem de cima e da esquerda (como nos personagens: lado direito mais escuro). De noite o jogo escurece tudo e só ilumina em volta da fogueira, do lampião e do personagem. Se quiser pixels que **brilham** no escuro (chama, janela acesa, vidro do lampião), use a letra `L` (ou `L1`, `L2`… para tons diferentes) e diga a cor: eu faço o jogo não escurecer esses pixels.
6. **Cor da família:** barraco e casa têm o **telhado na cor da família** (4 famílias: vermelho `#B5443A`/`#8C3029`, marrom `#8A5A3A`/`#6A4228`, azul acinzentado `#5C6E86`/`#45546A`, laranja `#C8693A`/`#9C4E2A`). Desenhe com as letras `x` (tom claro) e `X` (tom escuro): o jogo troca pela cor de cada família. Se quiser mais tons para isso, me diga quais.
7. **Chão:** a grama vai de `#549234` / `#60A63C` / `#67B340` (verde) a `#83A247` / `#97BA52` (seca); a areia é clara. Evite que a base da estrutura suma na grama: um contorno de terra ou pedra na base ajuda.
8. **Zoom afastado:** no zoom mais longe o jogo desenha tudo com metade da resolução (1 pixel para cada 2 × 2). A estrutura precisa continuar reconhecível assim: evite detalhes que dependem de 1 pixel isolado.
9. **Sem contorno preto, cores chapadas, poucas cores por estrutura** (o jogo usa paleta indexada: até ~12 cores novas por estrutura é tranquilo).

## O que desenhar

Prioridade 1 (as que aparecem o tempo todo):

| Estrutura | Ocupa | Quadros e estados |
|---|---|---|
| Fogueira | 1 × 1 | chama animada (3 ou 4 quadros) e apagada (só a lenha e as pedras) |
| Baú | 1 × 1 | fechado (se quiser, aberto) |
| Abrigo (cabana onde o profeta dorme) | 2 × 2 | 1 quadro; porta onde cabe um adulto |
| Cerca | 1 × 1 | poste sozinho, trilho para +u, trilho para +v, os dois; o trilho tem que chegar no poste vizinho (12 px para o lado e 6 para baixo) |
| Portão | 1 × 1 | na fileira de u e na fileira de v (fechado; se quiser, aberto) |
| Barraco da família | 2 × 2 | 1 quadro; telhado com `x`/`X` |
| Casa da família (o barraco melhorado) | 2 × 2 | 1 quadro; telhado com `x`/`X`, chaminé, janelas acesas de noite com `L` |
| Fornalha | 1 × 1 | apagada e acesa (fogo animado, 2 ou 3 quadros) |
| Lampião | 1 × 1 | apagado (dia) e aceso (noite, vidro com `L`) |

Prioridade 2 (o depósito da vila guarda tudo em **pilhas no chão**, uma pilha por célula 1 × 1). Uma pilha por item, em **3 tamanhos** (pouco, metade, cheia): madeira (toras), pedra, frutas, carne, peixe, trigo (feixes), sementes (saco), pão, minério de ferro, carvão, barras de ferro, couro e "ferramentas" (uma caixa ou um suporte genérico).

## Formato da entrega (como nos personagens)

Para cada estrutura, um artboard mostrando:
- o desenho em 8× sobre o losango da célula, com o profeta (14 × 22) ao lado para escala;
- uma prévia no tamanho do jogo (2× e 1×), de dia e de noite;
- todos os quadros e estados.

E, num bloco de dados (como o `dset` do protótipo dos cidadãos), cada quadro como **linhas de texto**, uma letra por pixel, `.` = transparente:

```js
{
  "barraco": {
    "ocupa": [2, 2],
    "ancora": [24, 31],          // x, y do ponto do chao dentro do quadro
    "quadros": {
      "normal": ["........xx........", "...", "..."]
    },
    "cores": { "x": "familia claro", "X": "familia escuro", "w": "#8A5A3A", "L": "#FFE38A" }
  }
}
```

Todos os quadros de uma estrutura com a mesma largura e altura, e a âncora no mesmo lugar. Use as mesmas letras de pele/madeira/pedra entre as estruturas sempre que for a mesma cor.

---

## Para mim (integração)

Quando o designer devolver, me mande o link do canvas (ou o bloco de dados). Eu:
1. escrevo um gerador como o `arte/personagens.py` (letras → `estruturas.S`);
2. desenho as estruturas com metade da escala (o dobro de detalhe), como os personagens, e reduzo sozinho no zoom mais longe;
3. acrescento a âncora vertical, os quadros animados, os estados (apagada/acesa, aberto/fechado), as pilhas em 3 tamanhos e os pixels `L` que brilham de noite;
4. tiro de novo as fotos da vitrine (`./ermo --shot` gera `shot_estruturas.bmp` e `shot_estruturas_noite.bmp`) para comparar.
