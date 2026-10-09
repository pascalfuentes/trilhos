# Trilhos

Um jogo de sobrevivência no estilo Factorio, escrito em **assembly ARM64** (AArch64).

Você aparece sozinho num mundo gerado aleatoriamente: terreno contínuo, mar, praias, florestas, montanhas com neve. Precisa coletar madeira, pedra e frutas, não morrer de fome e passar a noite perto de uma fogueira.

![Dia](screenshots/jogo.png)
![Noite](screenshots/noite.png)

## Como jogar

| Tecla / mouse | Ação |
|---|---|
| ENTER | entrar no mundo (na tela de título) |
| WASD / setas | andar |
| segurar o botão esquerdo | coletar a árvore, pedra ou arbusto sob o mouse (até 3 células de distância) |
| E | comer uma fruta (+15 de fome) |
| F | montar uma fogueira (5 madeiras + 3 pedras) |
| botão direito numa fogueira | pôr lenha (+30 s de fogo) |
| roda do mouse / `+` / `-` | zoom |
| espaço | pausa |
| G | curvas de nível |
| ESC | volta ao menu |

**Recursos**

- **Árvores e pinheiros:** 4 madeiras cada; somem quando acabam.
- **Pedras:** 5 pedras cada; muitas nas montanhas, poucas no campo.
- **Arbustos:** 3 frutas; voltam a dar frutas com o tempo.

**Sobrevivência**

- **Fome:** cai sempre (de cheia a vazia em uns 6 minutos). Sem comida, a vida cai.
- **Calor:** de dia fica tudo bem. À noite esfria; perto de uma fogueira acesa (5 células), esquenta. Sem calor, a vida cai.
- **Vida:** volta devagar quando você está alimentado e aquecido.
- **Dia e noite:** um dia dura 3 minutos. A noite escurece a tela de verdade; só a fogueira e uma luz fraca em volta do personagem iluminam.

**Neblina de guerra**

- O mapa começa todo **preto**: você descobre andando.
- O personagem enxerga até **15 células de dia** e **5 de noite** (diminui aos poucos no entardecer). Fogueiras acesas também revelam em volta.
- **Árvores tapam a visão**: dentro da floresta você enxerga bem menos.
- O que você já viu mas não está vendo agora aparece **escurecido e sem cor**, do jeito que estava da última vez. Um arbusto que voltou a dar frutas longe dos seus olhos continua aparecendo vazio até você voltar lá.

## Como funciona

| Arquivo | O que tem |
|---|---|
| `comum.h` | macros e constantes compartilhadas |
| `trilhos.S` | janela, entrada, geração do mundo, terreno, árvores |
| `sobrevivencia.S` | personagem, coleta, inventário, fome, calor, fogueiras, noite e interface |

- **Geração:** ruído fractal num mapa de altura de 512x512, só com aritmética inteira. A mesma semente sempre gera o mesmo mundo.
- **Terreno contínuo ("voxel space" isométrico):** cada coluna da tela anda pelo mundo de frente para trás e pinta só o que fica visível. As 1280 colunas são divididas entre **8 threads**, uma para cada núcleo.
- **Objetos com z-buffer:** árvores, pedras, arbustos, fogueiras e o personagem respeitam a profundidade do terreno.
- **Visão:** a cada quadro saem 360 raios do personagem e de cada fogueira. Cada raio perde transparência ao passar por células com árvores. O resultado vai para dois mapas: "vendo agora" e "já visto". Cada objeto guarda também o estado em que foi visto por último.
- **Neblina e noite:** depois de desenhar o mundo, cada pixel descobre a que ponto do mapa pertence (pelo z-buffer), lê os dois mapas com interpolação suave e escurece/descolore o que não está à vista; de noite multiplica pela luz ambiente mais a luz das fogueiras. Essa passada também roda nas 8 threads.
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

`./trilhos --shot` roda sem interação: tira screenshots, mede o tempo de cada quadro e faz um teste automático (coleta duas árvores, uma pedra e um arbusto, monta uma fogueira, come e passa a noite).

## Próximos passos

- [ ] Mesa de trabalho e receitas (machado, picareta, baú)
- [ ] Minérios (ferro, carvão) e fornalha
- [ ] Animais e caça
- [ ] Inimigos de noite
- [ ] Salvar e carregar o jogo
