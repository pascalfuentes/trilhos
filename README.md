# Trilhos

Um jogo de trens no estilo OpenTTD, escrito em **assembly ARM64** (AArch64).

Cada vez que você entra, um mundo novo é gerado aleatoriamente: um terreno contínuo, sem tiles, com relevo, mar, praias, florestas, montanhas com neve e cidades com nome e ruas sinuosas.

![Mapa](screenshots/jogo.png)
![Tela de título](screenshots/titulo.png)

## Como funciona

Toda a lógica e todo o desenho estão em assembly, no arquivo `trilhos.S`:

- **Geração do mundo:** ruído fractal (value noise com 6 oitavas e interpolação suave) num mapa de altura de 512x512, calculado só com aritmética inteira. A mesma semente sempre gera o mesmo mundo.
- **Terreno contínuo ("voxel space" isométrico):** para cada coluna da tela, o programa anda pelo mundo de frente para trás, interpola a altura (bilinear) e pinta só o que fica visível (y-buffer). A linha da costa, as praias e a neve são calculadas pixel a pixel, por isso formam curvas naturais.
- **Iluminação suave:** a luz vem de cima à esquerda e depende da inclinação do terreno, interpolada entre os pontos do mapa.
- **Objetos livres:** árvores, casas e prédios ficam em posições contínuas e são desenhados com z-buffer, então um morro na frente esconde corretamente o que está atrás.
- **Cidades:** ruas que fazem curvas a partir do centro, casas dos dois lados e prédios no centro das cidades grandes.
- **SDL3** só abre a janela, lê teclado e mouse e mostra o framebuffer na tela.

## Controles

| Tecla | Ação |
|---|---|
| ENTER | entrar no mundo (na tela de título) |
| WASD / setas / arrastar com o mouse | mover a câmera |
| roda do mouse / `+` / `-` | zoom (4 níveis) |
| G | liga/desliga as curvas de nível |
| R | gera outro mundo |
| F12 | salva uma screenshot (`trilhos.bmp`) |
| ESC | volta ao menu / sai |

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

O mesmo arquivo `trilhos.S` compila nos dois sistemas: as diferenças entre Mach-O (macOS) e ELF (Linux) ficam em duas macros no topo do arquivo.

`./trilhos --shot` roda sem interação: salva screenshots `.bmp` e mostra quanto tempo leva cada quadro.

## Próximos passos

- [ ] Construir trilhos com curvas livres usando o mouse
- [ ] Estações e trens andando nos trilhos
- [ ] Indústrias, carga e dinheiro
- [ ] Cidades que crescem
- [ ] Rios
- [ ] Desenhar o terreno em vários núcleos ao mesmo tempo
