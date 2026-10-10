#!/bin/bash
# =====================================================================
#  instalar.sh - prepara o Ermo para rodar num computador Intel/AMD
#
#  O Ermo e assembly ARM64. Num Linux x86-64 (por exemplo uma maquina
#  virtual Ubuntu no UTM, num Mac Intel), o QEMU traduz o ARM64 na hora.
#  Este script:
#    1. liga os pacotes arm64 no apt (multiarch, do ports.ubuntu.com);
#    2. instala o QEMU, o compilador cruzado e as bibliotecas X11 arm64;
#    3. compila o SDL3 para arm64 (janela X11, desenho por software);
#    4. baixa (ou atualiza) o jogo e compila;
#    5. cria o ./jogar.sh e um atalho no menu de aplicativos.
#
#  Uso (no Ubuntu 24.04 x86-64):
#    bash instalar.sh            # instala tudo e compila
#    bash instalar.sh --so-jogo  # so atualiza e recompila o jogo
# =====================================================================
set -e

SDLVER=3.2.24
REPO=https://github.com/pascalfuentes/trilhos.git
JOGO="${ERMO_DIR:-$HOME/trilhos}"
SDLDIR="$HOME/.ermo-sdl3"
S=sudo
[ "$(id -u)" = 0 ] && S=

if [ "$(dpkg --print-architecture)" != amd64 ]; then
    echo "Este script e para Linux x86-64 (Intel/AMD)."
    echo "Num Mac com chip M o jogo roda direto: make && ./ermo"
    exit 1
fi
. /etc/os-release

if [ "$1" != "--so-jogo" ]; then
    echo "== 1/5 pacotes arm64 no apt"
    if ! dpkg --print-foreign-architectures | grep -qx arm64; then
        $S dpkg --add-architecture arm64
    fi
    # as fontes de sempre ficam so para amd64; o arm64 vem do ports
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ] && \
       ! grep -q "^Architectures:" /etc/apt/sources.list.d/ubuntu.sources; then
        $S sed -i '/^Types:/a Architectures: amd64' /etc/apt/sources.list.d/ubuntu.sources
    fi
    if [ ! -f /etc/apt/sources.list.d/ermo-arm64.sources ]; then
        $S tee /etc/apt/sources.list.d/ermo-arm64.sources >/dev/null <<EOF
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: $VERSION_CODENAME $VERSION_CODENAME-updates $VERSION_CODENAME-security
Components: main universe
Architectures: arm64
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    fi
    $S apt-get update

    echo "== 2/5 QEMU, compilador cruzado e bibliotecas arm64"
    $S apt-get install -y git make cmake curl pkg-config \
        qemu-user-static binfmt-support gcc-aarch64-linux-gnu \
        libc6:arm64 libx11-dev:arm64 libxext-dev:arm64 libxrandr-dev:arm64 \
        libxcursor-dev:arm64 libxi-dev:arm64 libxfixes-dev:arm64 \
        libxss-dev:arm64 libxtst-dev:arm64

    echo "== 3/5 SDL $SDLVER para arm64"
    if [ ! -f "$SDLDIR/lib/libSDL3.so" ]; then
        T=$(mktemp -d)
        curl -fsSL -o "$T/sdl.tgz" \
            "https://github.com/libsdl-org/SDL/releases/download/release-$SDLVER/SDL3-$SDLVER.tar.gz"
        tar xzf "$T/sdl.tgz" -C "$T"
        cat > "$T/tc.cmake" <<'EOF'
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_FIND_ROOT_PATH /usr/aarch64-linux-gnu /usr)
set(CMAKE_LIBRARY_ARCHITECTURE aarch64-linux-gnu)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF
        export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig
        cmake -S "$T/SDL3-$SDLVER" -B "$T/build" \
            -DCMAKE_TOOLCHAIN_FILE="$T/tc.cmake" \
            -DCMAKE_INSTALL_PREFIX="$SDLDIR" -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath-link,/usr/lib/aarch64-linux-gnu" \
            -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath-link,/usr/lib/aarch64-linux-gnu" \
            -DSDL_X11=ON -DSDL_WAYLAND=OFF -DSDL_KMSDRM=OFF \
            -DSDL_OPENGL=OFF -DSDL_OPENGLES=OFF -DSDL_VULKAN=OFF -DSDL_GPU=OFF \
            -DSDL_PULSEAUDIO=OFF -DSDL_PIPEWIRE=OFF -DSDL_ALSA=OFF -DSDL_JACK=OFF \
            -DSDL_SNDIO=OFF -DSDL_HIDAPI=OFF -DSDL_CAMERA=OFF -DSDL_TESTS=OFF \
            -DSDL_STATIC=OFF -DSDL_IBUS=OFF -DSDL_DBUS=OFF -DSDL_LIBUDEV=OFF
        cmake --build "$T/build" -j"$(nproc)"
        cmake --install "$T/build"
        rm -rf "$T"
    fi
fi

echo "== 4/5 o jogo"
if [ -d "$JOGO/.git" ]; then
    git -C "$JOGO" pull --ff-only || true
else
    git clone "$REPO" "$JOGO"
fi
cd "$JOGO"
rm -f ermo
make CC=aarch64-linux-gnu-gcc \
    SDL_LIBS="-L$SDLDIR/lib -lSDL3 -Wl,-rpath,$SDLDIR/lib -Wl,-rpath-link,/usr/lib/aarch64-linux-gnu"

echo "== 5/5 atalhos"
cat > "$JOGO/jogar.sh" <<EOF
#!/bin/bash
# roda o Ermo (ARM64) pelo QEMU, com janela X11 e renderizacao por software;
# comeca no modo leve (metade das colunas do terreno): F10 liga e desliga
cd "$JOGO"
export SDL_VIDEODRIVER=x11
export SDL_RENDER_DRIVER=software
export ERMO_LEVE=\${ERMO_LEVE:-1}
if [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    exec ./ermo "\$@"
else
    exec qemu-aarch64-static -L / ./ermo "\$@"
fi
EOF
chmod +x "$JOGO/jogar.sh"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/ermo.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ermo
Comment=Sobrevivencia e vila (ARM64 pelo QEMU)
Exec=$JOGO/jogar.sh
Path=$JOGO
Icon=applications-games
Terminal=false
Categories=Game;
EOF

echo
echo "Pronto. Para jogar: $JOGO/jogar.sh   (ou procure \"Ermo\" nos aplicativos)"
echo "Para atualizar depois: bash $JOGO/intel/instalar.sh --so-jogo"
