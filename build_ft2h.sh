#!/bin/bash
# ============================================================
# Script de compilación de WSJT-X con modo FT2H
# Para MSYS2 MinGW64 en Windows
# ============================================================
# Uso:
#   Abrir MSYS2 MinGW64 shell y ejecutar:
#   cd /d/Programacion/Radioaficion/wsjt-wsjtx
#   bash build_ft2h.sh [clean|release|debug|deps|check]
#
# Opciones:
#   (sin args)  - Compilación Release completa
#   clean       - Limpia el directorio de build
#   release     - Compilación Release (por defecto)
#   debug       - Compilación Debug con símbolos
#   deps        - Solo instala dependencias
#   check       - Verifica dependencias sin compilar
# ============================================================

set -e

# Configuración
MSYS2_ROOT="/a/msys64"
BUILD_DIR="build"
INSTALL_DIR="install"
JOBS=$(nproc 2>/dev/null || echo 4)
BUILD_TYPE="Release"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================
# Verificar dependencias
# ============================================================
check_deps() {
    log_info "Verificando dependencias..."
    local missing=0

    # Compiladores
    for tool in gfortran g++ gcc cmake make; do
        if command -v $tool &>/dev/null; then
            log_ok "$tool: $(command -v $tool)"
        else
            log_error "$tool: NO ENCONTRADO"
            missing=1
        fi
    done

    # Librerías Qt5
    if pkg-config --exists Qt5Core 2>/dev/null; then
        log_ok "Qt5Core: $(pkg-config --modversion Qt5Core)"
    else
        log_warn "Qt5Core: pkg-config no lo detecta (puede estar OK si cmake lo encuentra)"
    fi

    # FFTW3
    if pkg-config --exists fftw3 2>/dev/null; then
        log_ok "FFTW3: $(pkg-config --modversion fftw3)"
    elif [ -f /mingw64/lib/libfftw3.a ] || [ -f /mingw64/lib/libfftw3f.a ]; then
        log_ok "FFTW3: encontrado en /mingw64/lib"
    else
        log_error "FFTW3: NO ENCONTRADO"
        missing=1
    fi

    # Boost
    if [ -d /mingw64/include/boost ]; then
        log_ok "Boost: encontrado en /mingw64/include/boost"
    else
        log_error "Boost: NO ENCONTRADO"
        missing=1
    fi

    # Hamlib
    if [ -f /mingw64/lib/libhamlib.a ] || [ -f /mingw64/lib/libhamlib.dll.a ]; then
        log_ok "Hamlib: encontrado"
    else
        log_warn "Hamlib: NO ENCONTRADO (requerido para control de radio)"
    fi

    # PortAudio
    if [ -f /mingw64/lib/libportaudio.a ] || [ -f /mingw64/lib/libportaudio.dll.a ]; then
        log_ok "PortAudio: encontrado"
    else
        log_error "PortAudio: NO ENCONTRADO"
        missing=1
    fi

    # libsamplerate
    if pkg-config --exists samplerate 2>/dev/null; then
        log_ok "libsamplerate: $(pkg-config --modversion samplerate)"
    elif [ -f /mingw64/lib/libsamplerate.a ]; then
        log_ok "libsamplerate: encontrado"
    else
        log_error "libsamplerate: NO ENCONTRADO"
        missing=1
    fi

    # Verificar archivos FT2H
    log_info "Verificando archivos FT2H..."
    local ft2h_files=(
        "lib/ft2h/ft2h_params.f90"
        "lib/ft2h/genft2h.f90"
        "lib/ft2h/gen_ft2h_wave.f90"
        "lib/ft2h/ldpc_64_32.f90"
        "lib/ft2h/unpack_ft2h_short.f90"
        "lib/ft2h/subtractft2h.f90"
        "lib/ft2h/ft2h_getcandidates.f90"
        "lib/ft2h/ft2h_get_bitmetrics.f90"
        "lib/ft2h/ft2h_downsample.f90"
        "lib/ft2h/sync_ft2h.f90"
        "lib/ft2h_decode.f90"
    )

    for f in "${ft2h_files[@]}"; do
        if [ -f "$f" ]; then
            log_ok "  $f"
        else
            log_error "  $f: NO ENCONTRADO"
            missing=1
        fi
    done

    # Verificar include paths de Fortran
    log_info "Verificando include paths..."
    if grep -q "include 'ft2h_params.f90'" lib/ft2h/genft2h.f90 2>/dev/null; then
        log_ok "  Include paths relativos correctos en lib/ft2h/"
    else
        log_error "  Include paths incorrectos — verificar lib/ft2h/*.f90"
        missing=1
    fi

    if grep -q "include 'ft2h/ft2h_params.f90'" lib/ft2h_decode.f90 2>/dev/null; then
        log_ok "  Include path correcto en lib/ft2h_decode.f90"
    else
        log_error "  Include path incorrecto en lib/ft2h_decode.f90"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        log_error "Faltan dependencias. Ejecuta: bash build_ft2h.sh deps"
        return 1
    fi

    log_ok "Todas las dependencias están presentes"
    return 0
}

# ============================================================
# Instalar dependencias
# ============================================================
install_deps() {
    log_info "Instalando dependencias con pacman..."

    pacman -S --needed --noconfirm \
        mingw-w64-x86_64-gcc-fortran \
        mingw-w64-x86_64-gcc \
        mingw-w64-x86_64-cmake \
        mingw-w64-x86_64-make \
        mingw-w64-x86_64-qt5-base \
        mingw-w64-x86_64-qt5-multimedia \
        mingw-w64-x86_64-qt5-serialport \
        mingw-w64-x86_64-qt5-tools \
        mingw-w64-x86_64-fftw \
        mingw-w64-x86_64-libsamplerate \
        mingw-w64-x86_64-boost \
        mingw-w64-x86_64-portaudio \
        mingw-w64-x86_64-hamlib \
        mingw-w64-x86_64-libusb \
        mingw-w64-x86_64-libtool \
        mingw-w64-x86_64-pkg-config

    log_ok "Dependencias instaladas"
}

# ============================================================
# Limpieza
# ============================================================
clean_build() {
    log_info "Limpiando directorio de build..."
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        log_ok "Directorio '$BUILD_DIR' eliminado"
    else
        log_warn "No existe directorio '$BUILD_DIR'"
    fi
}

# ============================================================
# Compilación
# ============================================================
build() {
    local build_type="${1:-Release}"

    log_info "============================================"
    log_info "  Compilación WSJT-X + FT2H ($build_type)"
    log_info "============================================"
    log_info "Build dir: $BUILD_DIR"
    log_info "Jobs: $JOBS"
    log_info ""

    # Verificar dependencias primero
    check_deps || exit 1

    # Crear directorio de build
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Configurar con CMake
    log_info "Ejecutando CMake..."
    cmake .. \
        -G "MinGW Makefiles" \
        -DCMAKE_BUILD_TYPE="$build_type" \
        -DCMAKE_Fortran_COMPILER=gfortran \
        -DCMAKE_CXX_COMPILER=g++ \
        -DCMAKE_C_COMPILER=gcc \
        -DCMAKE_PREFIX_PATH="/mingw64" \
        -DCMAKE_INSTALL_PREFIX="../$INSTALL_DIR" \
        -Wno-dev \
        2>&1 | tee cmake_output.log

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        log_error "CMake falló. Revisa cmake_output.log"
        exit 1
    fi
    log_ok "CMake completado"

    # Verificar que FT2H está en los makefiles
    log_info "Verificando integración FT2H en makefiles..."
    if grep -r "ft2h" CMakeFiles/ --include="*.make" -l 2>/dev/null | head -5; then
        log_ok "FT2H detectado en los makefiles generados"
    else
        log_warn "No se encontraron referencias a FT2H en makefiles (puede ser normal)"
    fi

    # Compilar
    log_info "Compilando con $JOBS hilos..."
    mingw32-make -j$JOBS 2>&1 | tee build_output.log

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        log_error "Compilación falló. Revisa build_output.log"
        log_info "Intentando compilar con 1 hilo para ver errores..."
        mingw32-make -j1 2>&1 | tail -50
        exit 1
    fi

    log_ok "¡Compilación exitosa!"

    # Verificar ejecutable
    if [ -f "wsjtx.exe" ]; then
        log_ok "Ejecutable: $(pwd)/wsjtx.exe"
        log_info "Tamaño: $(du -h wsjtx.exe | cut -f1)"
    elif [ -f "bin/wsjtx.exe" ]; then
        log_ok "Ejecutable: $(pwd)/bin/wsjtx.exe"
        log_info "Tamaño: $(du -h bin/wsjtx.exe | cut -f1)"
    else
        log_warn "No se encontró wsjtx.exe — puede estar en otro subdirectorio"
        find . -name "wsjtx.exe" -o -name "wsjtx" 2>/dev/null | while read f; do
            log_info "  Encontrado: $f"
        done
    fi

    cd ..

    log_info ""
    log_info "============================================"
    log_ok "  BUILD COMPLETADO: $build_type"
    log_info "============================================"
    log_info ""
    log_info "Para ejecutar:"
    log_info "  cd $BUILD_DIR && ./wsjtx.exe"
    log_info ""
    log_info "Para instalar:"
    log_info "  cd $BUILD_DIR && mingw32-make install"
    log_info ""
}

# ============================================================
# Main
# ============================================================
case "${1:-release}" in
    clean)
        clean_build
        ;;
    deps)
        install_deps
        ;;
    check)
        check_deps
        ;;
    debug)
        build "Debug"
        ;;
    release|"")
        build "Release"
        ;;
    *)
        echo "Uso: $0 [clean|release|debug|deps|check]"
        echo ""
        echo "  clean    - Limpia el directorio de build"
        echo "  release  - Compilación Release (por defecto)"
        echo "  debug    - Compilación Debug"
        echo "  deps     - Instala dependencias MSYS2"
        echo "  check    - Verifica dependencias"
        exit 1
        ;;
esac
