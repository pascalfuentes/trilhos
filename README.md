# Trilhos

Um jogo de sobrevivência no estilo Factorio, escrito em **assembly ARM64** (AArch64).

Você aparece sozinho num mundo gerado aleatoriamente: terreno contínuo, mar, praias, florestas, montanhas com neve. Precisa coletar madeira, pedra e frutas, não morrer de fome e passar a noite perto de uma fogueira. Quanto mais você faz uma coisa, melhor fica nela.

![Dia](screenshots/jogo.png)
![Noite](screenshots/noite.png)

## Como jogar

| Tecla / mouse | Ação |
|---|---|
| ENTER | entrar no mundo (na tela de título) |
| WASD / setas | andar |
| Shift (segurando) | correr |
| segurar o botão esquerdo | coletar a árvore, pedra ou arbusto sob o mouse (até 3 células de distância) |
| E | comer uma fruta (+15 de fome) |
| F | montar uma fogueira (5 madeiras + 3 pedras) |
| botão direito numa fogueira | pôr lenha (+30 s de fogo) |
| I ou botão **Mochila** | abre a mochila |
| C ou botão **Personagem** | abre as skills |
| botão direito num item da mochila | larga 1 no chão (com Shift: a pilha toda) |
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

**Stamina e corrida**

- Correr deixa o personagem ~1,7x mais rápido e gasta **stamina** (de cheia a vazia em uns 5 s).
- Nadar também gasta a mesma stamina.
- Ela volta parado em terra (rápido), andando (devagar) e na água rasa (mais devagar).
- Se a stamina zerar, só dá para correr de novo quando ela voltar a 25.

**Mochila e peso**

| Item | Peso |
|---|---|
| Madeira | 1,5 kg |
| Pedra | 2,0 kg |
| Fruta | 0,1 kg |

- O limite começa em **30 kg** e aumenta com a skill Força (até 60 kg).
- Acima do limite: **anda bem mais devagar**, não corre, e nadar cansa o dobro.
- Com 1,5x o limite, não consegue pegar mais nada.
- O que você larga vira uma **pilha no chão**; dá para coletar de volta com o botão esquerdo.

**Skills**

Cada skill vai de nível 0 a 10.

- Sobe treinando, mais devagar quanto mais alta.
- Depois de **30 s sem treinar**, começa a cair devagarzinho (~1 nível a cada 10 minutos).
- Na janela do personagem, `+` verde = treinando agora e `-` laranja = caindo.

| Skill | Treina | Efeito no máximo |
|---|---|---|
| Natação | nadando | nada quase 2x mais rápido e cansa 60% menos |
| Corrida | correndo | corre 2,2x mais rápido e cansa 50% menos |
| Lenhador | cortando árvores | corta 2x mais rápido |
| Mineração | quebrando pedras | quebra 2x mais rápido |
| Força | andando com mais de 60% do limite de peso | carrega até 60 kg |

![Mochila e skills](screenshots/mochila.png)

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

## Como funciona

| Arquivo | O que tem |
|---|---|
| `comum.h` | macros e constantes compartilhadas |
| `trilhos.S` | janela, entrada, geração do mundo, terreno, árvores |
| `sobrevivencia.S` | personagem, coleta, mochila, skills, fome, calor, fogueiras, água, noite e interface |

- **Geração:** ruído fractal num mapa de altura de 512x512, só com aritmética inteira. A mesma semente sempre gera o mesmo mundo.
- **Terreno contínuo ("voxel space" isométrico):** cada coluna da tela anda pelo mundo de frente para trás e pinta só o que fica visível. As 1280 colunas são divididas entre **8 threads**, uma para cada núcleo.
- **Objetos com z-buffer:** árvores, pedras, arbustos, fogueiras e o personagem respeitam a profundidade do terreno.
- **Visão:** a cada quadro saem 360 raios do personagem e de cada fogueira. Cada raio perde transparência ao passar por células com árvores. O resultado vai para dois mapas: "vendo agora" e "já visto". Cada objeto guarda também o estado em que foi visto por último.
- **Neblina e noite:** depois de desenhar o mundo, cada pixel descobre a que ponto do mapa pertence (pelo z-buffer), lê os dois mapas com interpolação suave e escurece/descolore o que não está à vista; de noite multiplica pela luz ambiente mais a luz das fogueiras. Essa passada também roda nas 8 threads.
- **Interface:** botões, janelas e ícones são desenhados com retângulos pelo SDL; os ícones da mochila são os mesmos sprites das pilhas no chão.
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

`./trilhos --shot` roda sem interação: tira screenshots, mede o tempo de cada quadro e faz um teste automático (coleta duas árvores, uma pedra e um arbusto, monta uma fogueira, come e passa a noite; corre, anda carregado, larga e recolhe uma pilha de pedras, vê a skill cair sem treino; depois nada num lago e vai para o mar aberto até o tubarão atacar).

## Próximos passos

- [ ] Mesa de trabalho e receitas (machado, picareta, baú)
- [ ] Minérios (ferro, carvão) e fornalha
- [ ] Animais e caça
- [ ] Inimigos de noite
- [ ] Salvar e carregar o jogo
