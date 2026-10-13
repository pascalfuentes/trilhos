# Ermo - RPG em assembly ARM64 e C (migrando para C aos poucos)
#   make        compila
#   make run    compila e roda
#   make clean  apaga o executavel e screenshots .bmp

CC ?= cc
UNAME := $(shell uname)
CSRCS := c/inimigos.c c/nivel.c c/movimento.c c/alvo.c c/teclas.c
CFLAGS ?= -O2
CFLAGS += -std=c11 -Wall -ffixed-x28   # x28 aponta para o estado G (assembly)
SRCS := ermo.S sobrevivencia.S clima.S animais.S cercas.S pesca.S plantacao.S ferro.S desafio.S salvar.S personagens.S heroi.S pilhas.S nivel.S estruturas.S pixel.S construcoes.S estradas.S

SDL_LIBS := $(shell pkg-config --libs sdl3 2>/dev/null)
ifeq ($(SDL_LIBS),)
  ifeq ($(UNAME),Darwin)
    SDL_LIBS := -L$(shell brew --prefix 2>/dev/null || echo /opt/homebrew)/lib -lSDL3
  else
    SDL_LIBS := -lSDL3
  endif
endif

ifeq ($(UNAME),Darwin)
  ARCH := -arch arm64
endif

ermo: $(SRCS) $(CSRCS) comum.h estruturas.h estrpal.inc pixel.h pixpal.inc c/ermo.h c/ermo_equ.h
	$(CC) $(ARCH) $(CFLAGS) -o $@ $(SRCS) $(CSRCS) $(SDL_LIBS)

# as constantes do assembly para o C (rode quando mudar comum.h ou pixel.h)
c/ermo_equ.h: comum.h pixel.h arte/equ2h.py
	python3 arte/equ2h.py comum.h pixel.h > $@

run: ermo
	./ermo

clean:
	rm -f ermo trilhos *.bmp

.PHONY: run clean
