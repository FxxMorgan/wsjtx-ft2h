#!/bin/bash
# Script para publicar WSJT-X FT2H en GitHub
# Prerequisito: tener git instalado en Windows y una cuenta GitHub
# Uso: bash publish_github.sh <usuario_github>

GITHUB_USER="${1:-TU_USUARIO}"
REPO_NAME="wsjt-wsjtx-ft2h"
VERSION="2.7.0-ft2h"

echo "========================================"
echo "  Publicando en GitHub"
echo "  Como: ${GITHUB_USER}/${REPO_NAME}"
echo "========================================"

# Configurar remote de GitHub (aparte del original de SourceForge)
if git remote get-url github 2>/dev/null; then
    echo "Remote 'github' ya existe."
else
    echo "Añadiendo remote de GitHub..."
    git remote add github "https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
fi

# Ver archivos modificados
echo ""
echo "Archivos modificados (FT2H):"
git status --short

# Agregar todos los cambios FT2H
echo ""
echo "Preparando commit..."
git add CMakeLists.txt
git add CMake/Modules/FindFFTW3.cmake
git add Transceiver/TransceiverFactory.cpp
git add translations/wsjtx_es.ts
git add lib/ft2h/
git add lib/decoder.f90
git add lib/ft2h_decode.f90
git add models/Modes.cpp models/Modes.hpp
git add widgets/mainwindow.cpp widgets/mainwindow.h widgets/mainwindow.ui
git add make_release.sh publish_github.sh
git add .gitignore 2>/dev/null || true

# Commit con mensaje descriptivo
git commit -m "feat: Add FT2H hybrid digital mode (8-GFSK variable-length)

FT2H is a new hybrid digital mode for HF amateur radio:
- 8-GFSK modulation at 20.833 Baud (576 samples/symbol @ 12kHz)
- Standard frame: LDPC(174,91) + 77-bit message, 76 symbols, 3.648s TX
- Short frame: LDPC(64,32) + 16-bit confirmation, 32 symbols, 1.536s TX
- Costas 8-tone array sync + Grey code mapping
- nmode=25 in decoder

Changes:
- lib/ft2h/: Complete FT2H implementation (encode, decode, sync, downsample)
- models/Modes.{cpp,hpp}: Register FT2H mode
- widgets/mainwindow.{cpp,h,ui}: UI integration  
- lib/decoder.f90: FT2H decode dispatch
- translations/wsjtx_es.ts: Spanish translation
- CMakeLists.txt: Build integration + optional OmniRig + map65 disabled
- CMake/Modules/FindFFTW3.cmake: Fix threads on MinGW64
- Transceiver/TransceiverFactory.cpp: Guard against OmniRig.h when skipped

Compiled with: GCC 15.2.0 (MinGW64), Qt5 5.15.18, MSYS2
Target: Windows x86-64"

# Crear tag de versión
echo ""
echo "Creando tag v${VERSION}..."
git tag -a "v${VERSION}" -m "WSJT-X ${VERSION} - FT2H digital mode

Release of WSJT-X fork with FT2H hybrid 8-GFSK mode.
See lib/ft2h/MANUAL_USUARIO_FT2H.md for documentation."

# Push a GitHub
echo ""
echo "Subiendo a GitHub..."
git push github master
git push github "v${VERSION}"

echo ""
echo "========================================"
echo "  ¡Código publicado!"
echo "  https://github.com/${GITHUB_USER}/${REPO_NAME}"
echo "========================================"
echo ""
echo "PASO SIGUIENTE: Crear el Release en GitHub:"
echo "  1. Ve a: https://github.com/${GITHUB_USER}/${REPO_NAME}/releases/new"
echo "  2. Tag: v${VERSION}"
echo "  3. Título: WSJT-X ${VERSION} - FT2H Mode"
echo "  4. Sube el ZIP: release/wsjtx-${VERSION}-win64.zip"
echo "  5. Publica"
