# WSJT-X FT2H

> Fork de [WSJT-X 2.7.0](https://physics.princeton.edu/pulsar/k1jt/wsjtx.html) con el nuevo modo digital **FT2H** — modo híbrido 8-GFSK de longitud variable para radioafición HF.

![versión](https://img.shields.io/badge/versión-beta%200.1-orange)
![plataforma](https://img.shields.io/badge/plataforma-Windows%20x64-blue)
![base](https://img.shields.io/badge/base-WSJT--X%202.7.0-green)
![licencia](https://img.shields.io/badge/licencia-GPL--3.0-lightgrey)

---

## ¿Qué es FT2H?

**FT2H** es un nuevo modo digital para HF diseñado como extensión del ecosistema WSJT-X. Combina modulación 8-GFSK con codificación LDPC en dos tipos de trama:

| Tipo | Código | Mensaje | Símbolos | Duración TX |
|------|--------|---------|----------|-------------|
| Estándar | LDPC(174,91) | 77 bits | 76 símbolos | 3.648 s |
| Corta | LDPC(64,32) | 16 bits (confirmación) | 32 símbolos | 1.536 s |

**Características técnicas:**
- Modulación: **8-GFSK** — 8 tonos, codificación Gray
- Velocidad de símbolo: **20.833 Bd** (576 muestras/símbolo a 12 kHz)
- Ancho de banda: ~**250 Hz**
- Sincronismo: arrays Costas de 8 tonos
- Ciclos T/R: 4 segundos (trama estándar) / 1.5 segundos (trama corta)
- Identificador interno: `nmode = 25`

---

## Instalación (Windows x64)

1. Descarga el ZIP desde [Releases](https://github.com/FxxMorgan/wsjtx-ft2h/releases)
2. Descomprime en cualquier carpeta
3. Ejecuta `wsjtx.exe`

> No requiere instalación. Todas las DLLs están incluidas.

---

## Compilar desde el código fuente

**Requisitos:**
- [MSYS2](https://www.msys2.org/) con entorno MinGW64
- GCC 15+ con gfortran
- Qt5 5.15+, CMake 4+, FFTW3, Hamlib 4, Boost, PortAudio

```bash
# Dentro de MSYS2 MinGW64:
mkdir build && cd build
/mingw64/bin/cmake.exe -G "MinGW Makefiles" \
  -DCMAKE_Fortran_FLAGS="-fallow-argument-mismatch -w" \
  -DCMAKE_BUILD_TYPE=Release \
  -DWSJT_SKIP_MANPAGES=ON \
  -DWSJT_GENERATE_DOCS=OFF ..
mingw32-make -j$(nproc)
```

Ver [build_ft2h.sh](build_ft2h.sh) para el script completo.

---

## Manual de uso

📖 Ver [MANUAL_FT2H.md](MANUAL_FT2H.md) para documentación completa en español.

---

## Archivos clave del modo FT2H

```
lib/ft2h/
├── ft2h_params.f90        # Parámetros globales (NSPS, NDOWN, NN2...)
├── genft2h.f90            # Codificador — genera tonos i4tone[]
├── ft2h_downsample.f90    # Decimación 12000→667 S/s (factor 18)
├── sync_ft2h.f90          # Sincronismo — busca arrays Costas
├── ft2h_getcandidates.f90 # Candidatos de decodificación
├── ft2h_get_bitmetrics.f90# Métricas de bit para LDPC
└── subtractft2h.f90       # Sustracción de señal decodificada
lib/ft2h_decode.f90        # Dispatcher principal del decodificador
MANUAL_FT2H.md             # Manual de usuario en español
```

---

## Diferencias con WSJT-X original

| Cambio | Detalle |
|--------|---------|
| Modo FT2H | `nmode=25`, integrado en decoder y GUI |
| Traducción ES | `translations/wsjtx_es.ts` |
| OmniRig opcional | `WSJT_SKIP_OMNIRIG` en CMake |
| FFTW3 threads fix | `FindFFTW3.cmake` corregido para MinGW64 |
| map65 desactivado | No requerido para uso en HF |

---

## Estado

> ⚠️ **Beta 0.1** — experimental, en desarrollo activo.

- [x] Codificador FT2H (estándar + corto)
- [x] Decodificador FT2H
- [x] Integración GUI en WSJT-X
- [x] Compilación Windows x64
- [ ] Calibración de rendimiento vs FT8
- [ ] Integración con PSKReporter
- [ ] Pruebas en banda real

---

## Licencia

GPL-3.0 — basado en [WSJT-X](https://physics.princeton.edu/pulsar/k1jt/wsjtx.html) de Joe Taylor K1JT.
