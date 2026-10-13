# Pedido 0.7 ao designer: estilo 2 (mais detalhe, personagens maiores)

Cole o texto abaixo no designer junto com as duas imagens de `referencias/` (`personagem_chapeu.png` e `casa.png`). Elas são só **referência de estilo**, não para copiar.

---

Queremos levar o visual do Ermo um passo adiante. As duas imagens anexas mostram a direção: **personagens maiores e mais expressivos**, como o rapaz de chapéu, e **cenário mais rico e colorido**, como a casa de pedra com telhado vermelho, a grama cheia de flores e as montanhas. Use-as só como referência de estilo: nada de copiar o desenho, as roupas ou a casa delas. O jogo continua um RPG medieval de fantasia, com a mesma visão isométrica.

## O que muda em relação ao guia 0.0

1. **O dobro de detalhe.** Tudo passa a ser desenhado com o dobro de pixels, mas ocupa o mesmo lugar na tela, porque o jogo deixa de ampliar 2× e desenha a 1×:
   - chão: losango de **64 × 32** (era 32 × 16); +1 em u vai 32 px para a direita e 16 para baixo;
   - degrau de penhasco: **32 px** de altura;
   - personagem: quadro de **64 × 96**, âncora nos pés em **(32, 90)**; o herói ocupa uns 48 × 84;
   - itens: células de mochila de **32 × 32**; no chão, até 32 × 24.
2. **Proporções dos personagens** como na referência: cabeça grande (umas 3,5 cabeças de altura no total), olhos que dão expressão, mãos e pés bem marcados, roupas com dobras e volume. Contorno de 1 px no tom mais escuro do material (não preto puro).
3. **Cor e luz** como na casa: cores vivas e saturadas, 4 a 5 tons por material, luz de cima e da esquerda, detalhes pequenos (flores na grama, musgo na pedra, telhas uma a uma). Continua sem degradê suave e sem anti-aliasing contra o fundo transparente.
4. O resto vale igual ao 0.0:
   - 5 direções, com o espelho para as outras 3;
   - equipamento em camadas no mesmo quadro;
   - pele `1 2 3 4` e pano tingível `5 6 7 8`;
   - cores de **brilho** marcadas;
   - desenhar tudo de dia.

## O que desenhar neste pedido

1. **Guia de estilo 2**: a paleta-mestra revisada (pode crescer até ~200 cores) e uma folha de regras de uma página com os tamanhos novos.
2. **Herói** homem e mulher, parado (4 quadros) nas 5 direções, com roupa de baixo simples.
3. **Equipamento em camadas** nas 5 direções:
   - chapéu de pano (o equipamento inicial, no espírito da referência);
   - capacete de ferro;
   - túnica de pano;
   - peitoral de aço;
   - calça;
   - botas;
   - espada curta na mão.
4. **Lobo e urso** no tamanho novo (sugestão: lobo 96 × 80, urso 128 × 96, âncora nos pés), parado nas 5 direções. As outras animações vêm num pedido depois.
5. **Chão** em losangos de 64 × 32:
   - grama com 4 variações, com flores e capim;
   - terra, areia, neve, água rasa e funda, e estrada de pedra;
   - a transição de grama para areia;
   - um bloco de penhasco com topo de neve.
6. **Objetos:** árvore de folha, pinheiro com neve, arbusto com flores, pedra e tocha (chama em brilho).
7. **Uma casa** para as cidades: pedra com telhado de telhas vermelhas, chaminé, porta e janelas, em losango isométrico de 3 × 3 células, no espírito da referência.
8. **Uma cena montada** com tudo isso, a 1× (1280 × 720), de dia e de noite com a tocha.

## Formato da entrega

Igual aos anteriores:

- um artboard por peça, com a peça ampliada 4× e uma prévia a 1×;
- um bloco de dados `ermo_estilo2.json`, com cada quadro em linhas de texto, um caractere por pixel (`.` = transparente), as rampas da paleta e, no topo, `"densidade": 2` (para o jogo saber que é a arte com o dobro de detalhe).

---

## Para mim (integração)

O motor já aceita a arte com o dobro de detalhe (etapa 0.7, código): `densidade: 2` faz o jogo desenhar a 1× o que hoje desenha a 2×, sem mudar o tamanho do mundo na tela. Quando o 0.7 voltar, troco as peças uma a uma pelo `arte/pixel.py`.
