#!/bin/bash
# Script para crear paquete de release de WSJT-X con FT2H
# Uso: bash make_release.sh

set -e

VERSION="2.7.0-ft2h"
BUILD_DIR="/d/Programacion/Radioaficion/wsjt-wsjtx/build"
MINGW64="/mingw64/bin"
RELEASE_DIR="/d/Programacion/Radioaficion/wsjt-wsjtx/release/wsjtx-${VERSION}-win64"

echo "========================================"
echo "  Empaquetando WSJT-X ${VERSION}"
echo "========================================"

# 1. Crear directorio de release limpio
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# 2. Copiar ejecutables principales
echo "[1/6] Copiando ejecutables..."
cp "$BUILD_DIR/wsjtx.exe"               "$RELEASE_DIR/"
cp "$BUILD_DIR/jt9.exe"                 "$RELEASE_DIR/"
cp "$BUILD_DIR/message_aggregator.exe"  "$RELEASE_DIR/"
cp "$BUILD_DIR/record_time_signal.exe"  "$RELEASE_DIR/"
cp "$BUILD_DIR/wsjtx_app_version.exe"   "$RELEASE_DIR/"

# 3. Copiar DLLs de runtime necesarias
echo "[2/6] Copiando DLLs de runtime..."
DLL_LIST=(
    "libboost_filesystem-mt.dll"
    "libboost_log_setup-mt.dll"
    "libboost_log-mt.dll"
    "libboost_thread-mt.dll"
    "libfftw3f-3.dll"
    "libfftw3f_threads-3.dll"
    "libgcc_s_seh-1.dll"
    "libgfortran-5.dll"
    "libgomp-1.dll"
    "libhamlib-4.dll"
    "libstdc++-6.dll"
    "libwinpthread-1.dll"
    "libusb-1.0.dll"
    "libsamplerate-0.dll"
    "libportaudio-2.dll"
    "portaudio.dll"
)

for dll in "${DLL_LIST[@]}"; do
    if [ -f "${MINGW64}/${dll}" ]; then
        cp "${MINGW64}/${dll}" "$RELEASE_DIR/"
    else
        echo "  (omitida: $dll no encontrada)"
    fi
done

# 4. Copiar DLLs de Qt5
echo "[3/6] Copiando DLLs de Qt5..."
QT_DLLS=(
    "Qt5Core.dll"
    "Qt5Gui.dll"
    "Qt5Multimedia.dll"
    "Qt5MultimediaWidgets.dll"
    "Qt5Network.dll"
    "Qt5PrintSupport.dll"
    "Qt5SerialPort.dll"
    "Qt5Sql.dll"
    "Qt5Widgets.dll"
    "Qt5Xml.dll"
)

for dll in "${QT_DLLS[@]}"; do
    if [ -f "${MINGW64}/${dll}" ]; then
        cp "${MINGW64}/${dll}" "$RELEASE_DIR/"
    fi
done

# 5. Copiar plugins de Qt (imprescindibles)
echo "[4/6] Copiando plugins Qt..."
QT_PLUGINS="/mingw64/share/qt5/plugins"
mkdir -p "$RELEASE_DIR/platforms"
mkdir -p "$RELEASE_DIR/audio"
mkdir -p "$RELEASE_DIR/sqldrivers"
mkdir -p "$RELEASE_DIR/imageformats"
mkdir -p "$RELEASE_DIR/styles"

cp "${QT_PLUGINS}/platforms/qwindows.dll"         "$RELEASE_DIR/platforms/" 2>/dev/null || true
cp "${QT_PLUGINS}/audio/"*.dll                    "$RELEASE_DIR/audio/"     2>/dev/null || true
cp "${QT_PLUGINS}/sqldrivers/qsqlite.dll"         "$RELEASE_DIR/sqldrivers/" 2>/dev/null || true
cp "${QT_PLUGINS}/imageformats/"*.dll             "$RELEASE_DIR/imageformats/" 2>/dev/null || true
cp "${QT_PLUGINS}/styles/qwindowsvistastyle.dll"  "$RELEASE_DIR/styles/"    2>/dev/null || true

# 6. Copiar traducciones del proyecto
echo "[5/6] Copiando traducciones..."
mkdir -p "$RELEASE_DIR/translations"
if ls "${BUILD_DIR}/"*.qm &>/dev/null; then
    cp "${BUILD_DIR}/"*.qm "$RELEASE_DIR/translations/" 2>/dev/null || true
fi
# Traducciones Qt base
QT_TRANS="/mingw64/share/qt5/translations"
cp "${QT_TRANS}/qt_es.qm"   "$RELEASE_DIR/translations/" 2>/dev/null || true
cp "${QT_TRANS}/qtbase_es.qm" "$RELEASE_DIR/translations/" 2>/dev/null || true

# 7. Copiar recursos adicionales del build
echo "[6/6] Copiando recursos..."
if [ -d "$BUILD_DIR/hamlib-rigs" ]; then
    cp -r "$BUILD_DIR/hamlib-rigs" "$RELEASE_DIR/" 2>/dev/null || true
fi
# Samples si existen
if ls "${BUILD_DIR}/"*.wav &>/dev/null; then
    cp "${BUILD_DIR}/"*.wav "$RELEASE_DIR/" 2>/dev/null || true
fi

# 8. Copiar manual
cp "/d/Programacion/Radioaficion/wsjt-wsjtx/lib/ft2h/MANUAL_USUARIO_FT2H.md" "$RELEASE_DIR/MANUAL_FT2H_ES.md"

# 9. Crear qt.conf para que Qt encuentre los plugins
cat > "$RELEASE_DIR/qt.conf" << 'EOF'
[Paths]
Prefix = .
Plugins = .
EOF

# 10. Crear archivo de versión/info
cat > "$RELEASE_DIR/VERSION.txt" << EOF
WSJT-X ${VERSION}
Fecha de build: $(date '+%Y-%m-%d')
Añade modo digital FT2H (8-GFSK, modo híbrido variable)

Cambios vs WSJT-X 2.7.0 original:
- Nuevo modo FT2H: 8-GFSK, 20.833 Bd
  * Trama estándar: LDPC 174,91 - 76 símbolos - 3.648s
  * Trama corta: LDPC 64,32 - 32 símbolos - 1.536s
- Traducción al español (es_ES)
- Ver MANUAL_FT2H_ES.md para documentación completa

Compilado con: GCC $(gfortran --version | head -1), Qt5 $(qmake --version | tail -1)
EOF

echo ""
echo "========================================"
echo "  Release creado en:"
echo "  $(cygpath -w $RELEASE_DIR)"
echo "========================================"
echo ""
echo "Contenido:"
ls -lh "$RELEASE_DIR"

# 11. Crear ZIP
echo ""
echo "Creando ZIP..."
cd "$(dirname $RELEASE_DIR)"
ZIP_NAME="wsjtx-${VERSION}-win64.zip"
zip -r "${ZIP_NAME}" "$(basename $RELEASE_DIR)" -x "*.pdb"
echo ""
echo "ZIP: $(cygpath -w $(dirname $RELEASE_DIR)/${ZIP_NAME})"
echo "Tamaño: $(du -sh $(dirname $RELEASE_DIR)/${ZIP_NAME} | cut -f1)"
echo ""
echo "¡Listo para subir a GitHub Releases!"
