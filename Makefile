# Trilhos - jogo de sobrevivencia em assembly ARM64
#   make        compila
#   make run    compila e roda
#   make clean  apaga o executavel e screenshots .bmp

CC ?= cc
UNAME := $(shell uname)
SRCS := trilhos.S sobrevivencia.S clima.S animais.S

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

trilhos: $(SRCS) comum.h
	$(CC) $(ARCH) -o $@ $(SRCS) $(SDL_LIBS)

run: trilhos
	./trilhos

clean:
	rm -f trilhos *.bmp

.PHONY: run clean
