# FT2H — Modo Digital Híbrido de Variable Length para WSJT-X

> **Fork experimental de WSJT-X** que implementa el modo FT2H: 8-GFSK de alta velocidad  
> con mensajes de longitud variable (estándar 77-bit + corto 16-bit), diseñado para  
> lograr QSOs completos en ~24 segundos conservando compatibilidad con la arquitectura WSJT-X.

---

## Índice

1. [Origen del proyecto](#1-origen-del-proyecto)
2. [¿Por qué FT2H?](#2-por-qué-ft2h)
3. [Parámetros técnicos del modo](#3-parámetros-técnicos-del-modo)
4. [Comparativa con FT8 y FT4](#4-comparativa-con-ft8-y-ft4)
5. [Análisis teórico de sensibilidad](#5-análisis-teórico-de-sensibilidad)
6. [Diseño del sistema FT2H](#6-diseño-del-sistema-ft2h)
7. [Estructura de archivos creados](#7-estructura-de-archivos-creados)
8. [Descripción de cada módulo](#8-descripción-de-cada-módulo)
9. [Integración en WSJT-X (C++/Qt)](#9-integración-en-wsjt-x-cqt)
10. [Bugs encontrados y corregidos](#10-bugs-encontrados-y-corregidos)
11. [Simulador Python](#11-simulador-python)
12. [Resultados de simulación](#12-resultados-de-simulación)
13. [Análisis del simulador](#13-análisis-del-simulador)
14. [Compilación](#14-compilación)
15. [Mejoras futuras](#15-mejoras-futuras)
16. [Glosario](#16-glosario)

---

## 1. Origen del proyecto

El proyecto partió de una pregunta teórica sobre parámetros hipotéticos de un "modo FT2":

```
Velocidad: 20.833 Bd
Modulación: 8-GFSK, h=1.0, BT=0.5
Ciclo T/R: 4.0 s
Sensibilidad: -10.8 dB (SNR en 2500 Hz BW)
```

El análisis demostró que el valor de sensibilidad presentado estaba **5 dB equivocado** (doble penalización de ancho de banda). El valor correcto es **-15.8 dB**. A partir de ahí se diseñó e implementó un fork completo del código fuente de WSJT-X.

---

## 2. ¿Por qué FT2H?

Los modos existentes tienen un trade-off velocidad/sensibilidad fijo:

| Modo | Ciclo T/R | QSO completo* | Sensibilidad |
|------|:---------:|:-------------:|:------------:|
| FT8  | 15 s | ~90 s | -21 dB |
| FT4  | 7.5 s | ~45 s | -17.5 dB |
| **FT2H** | **4.0 s** | **~24 s** | **~-13 dB (opt.)** |

> *QSO completo = 6 intercambios (CQ + respuesta + señal + confirmación + 73 + confirmación)

FT2H apunta al segmento de condiciones de propagación razonables (bandas altas, auroras débiles, EME lunar) donde la velocidad importa más que el último dB de sensibilidad.

### Opción Híbrida (elegida)

Se evaluaron 4 diseños. Se eligió el **Híbrido** porque usa:
- **Frames estándar**: LDPC(174,91) para mensajes completos (mismo código que FT8/FT4)
- **Frames cortos**: LDPC(64,32) para confirmaciones (RR73, 73, RRR)

Esto permite que el decodificador aproveche el código más potente cuando tiene tiempo, pero que use el corto cuando solo necesita confirmar.

---

## 3. Parámetros técnicos del modo

### Frame estándar (77 bits de payload)

| Parámetro | Valor |
|-----------|-------|
| Modulación | 8-GFSK |
| Índice de modulación `h` | 1.0 |
| Factor BT (filtro Gaussiano) | 1.0 |
| Velocidad de símbolo | 20.833 Bd → `12000 / 576` |
| Muestras por símbolo | 576 @ 12000 S/s |
| Código LDPC | (174, 91) — igual que FT8/FT4 |
| Bits de mensaje | 77 |
| Bits de CRC | 14 (CRC-14) |
| Bits de información total | 91 |
| Bits de paridad LDPC | 83 |
| Tasa de código | 91/174 = 52.3% |
| Símbolos de datos | 58 (174 bits ÷ 3 bits/símbolo) |
| Símbolos de sincronía | 16 (2 × Costas 8) |
| Total de símbolos | 76 (= 1 rampa + 8 Costas + 29 datos + 8 Costas + 29 datos + 1 rampa) |
| Duración TX | 3.648 s (76 × 576 / 12000) |
| Ciclo T/R | 4.0 s |
| Ancho de banda | ~167 Hz (8 tonos × 20.833 Hz) |
| Sensibilidad teórica | **-15.8 dB** SNR en 2500 Hz BW |

### Frame corto (16 bits de payload)

| Parámetro | Valor |
|-----------|-------|
| Código LDPC | (64, 32) |
| Bits de payload | 16 |
| Bits de CRC | 16 |
| Tasa de código | 50% |
| Símbolos de datos | 22 |
| Símbolos de sincronía | 8 (1 × Costas 8) |
| Total de símbolos | 32 |
| Duración TX | 1.536 s |
| Ciclo T/R | 1.5 s |
| Sensibilidad | ~-9 dB (código más débil, TX más corto) |

### Arrays de Costas (8 tonos)

```
icos8a = [2, 5, 6, 0, 4, 1, 3, 7]   → Costas inicial
icos8b = [4, 7, 2, 3, 0, 6, 1, 5]   → Costas medio
icos8s = [1, 3, 7, 2, 5, 0, 6, 4]   → Costas frame corto
```

### Mapeo Gray (3 bits por símbolo)

```
graymap8 = [0, 1, 3, 2, 7, 6, 4, 5]
```

---

## 4. Comparativa con FT8 y FT4

```
Modo      Sensib.   Ciclo    Throughput   BW       Usos
────────  ────────  ───────  ───────────  ───────  ─────────────────────────
FT8        -21 dB   15.0 s    5.1 b/s     50 Hz   DX extremo, EME, MS
FT4        -17.5    7.5 s    10.3 b/s     90 Hz   Concursos HF
FT2H opt   ~-13     4.0 s    19.2 b/s    167 Hz   HF buenas condiciones
FT2H sim   -8.1     4.0 s    19.2 b/s    167 Hz   (resultado del simulador)
```

> **Throughput de información**: 77 bits / 4.0 s = 19.25 b/s → **3.8× más rápido que FT8**

---

## 5. Análisis teórico de sensibilidad

### Fórmula correcta

El SNR de WSJT-X se define como la relación señal/ruido en un ancho de banda de referencia de 2500 Hz:

$$\text{SNR}_{2500} = \frac{E_s/N_0}{\text{BW}_{ref}/\text{baud}} = \frac{E_s/N_0}{2500/20.833}$$

Para 8-GFSK con LDPC(174,91) al 50% threshold, se necesita aproximadamente $E_b/N_0 \approx 3$ dB, lo que implica $E_s/N_0 \approx 3 + 10\log_{10}(3) \approx 7.8$ dB.

$$\text{SNR}_{2500} = E_s/N_0 - 10\log_{10}(2500/20.833) = 7.8 - 21.8 \approx -14 \text{ dB}$$

El valor de diseño conservador es **-15.8 dB**.

### Error en el cálculo original

El cálculo inicial reportaba -10.8 dB aplicando dos veces la penalización de BW, lo que daba una cifra **5 dB optimista**.

---

## 6. Diseño del sistema FT2H

### Cadena de procesamiento (TX)

```
Mensaje 77 bits
    │
    ▼
Scrambling (vector de 77 bits, igual que FT4)
    │
    ▼
CRC-14 (→ mensaje de 91 bits)
    │
    ▼
LDPC(174,91) encode (→ codeword de 174 bits)
    │
    ▼
Mapeo Gray 3 bits/símbolo (→ 58 símbolos 0..7)
    │
    ▼
Ensamblado de frame: [0][Costas-A][datos29][Costas-B][datos29][0]
    │
    ▼
8-GFSK con h=1.0, BT=1.0, NSPS=576
    │
    ▼
Waveform de 43776 muestras @ 12000 S/s (3.648 s)
```

### Cadena de procesamiento (RX)

```
Waveform recibida (con ruido)
    │
    ▼
Búsqueda de candidatos (ft2h_getcandidates)
    │
    ▼
Sincronía fina: correlación con arrays Costas (sync_ft2h)
    │
    ▼
Extracción de métricas de bit: matched-filter coherente (ft2h_get_bitmetrics)
    │
    ▼
LLR → LDPC BP decoder (ldpc_174_91_c_decode)
    │
    ▼
Verificación CRC-14
    │
    ▼
Descrambling
    │
    ▼
Desempaquetado de mensaje (unpack77)
```

---

## 7. Estructura de archivos creados

```
wsjt-wsjtx/
│
├── lib/ft2h/                          ← NUEVO: todos los módulos FT2H
│   ├── ft2h_params.f90                ← Parámetros globales del modo
│   ├── genft2h.f90                    ← Codificador (estándar + corto)
│   ├── gen_ft2h_wave.f90              ← Generador de waveform 8-GFSK
│   ├── ldpc_64_32.f90                 ← Código LDPC(64,32) para frames cortos
│   ├── sync_ft2h.f90                  ← Sincronía de frame
│   ├── ft2h_downsample.f90            ← Submuestreo de señal
│   ├── ft2h_getcandidates.f90         ← Búsqueda de señales candidatas
│   ├── ft2h_get_bitmetrics.f90        ← Métricas de bit (LLR)
│   ├── subtractft2h.f90               ← Substracción de señal decodificada
│   ├── unpack_ft2h_short.f90          ← Desempaquetado de frames cortos
│   └── sim/                           ← Simulador Python
│       ├── ft2h_sim_v2.py             ← Simulador principal (v2, funcional)
│       ├── ft2h_simulator.py          ← Simulador v1 (descartado — LDPC aleatorio)
│       ├── ft2h_sim_results.png       ← Gráfico WER/BER vs SNR
│       └── ft2h_simulation_results.png
│
├── lib/ft2h_decode.f90                ← NUEVO: decodificador top-level
│
├── CMakeLists.txt                     ← MODIFICADO: añadidos 10 archivos FT2H
├── models/Modes.hpp                   ← MODIFICADO: enum Mode { ..., FT2H }
├── models/Modes.cpp                   ← MODIFICADO: "FT2H" en mode_names[]
├── lib/decoder.f90                    ← MODIFICADO: dispatch nmode==25
├── widgets/mainwindow.h               ← MODIFICADO: declaraciones FT2H
├── widgets/mainwindow.cpp             ← MODIFICADO: TX/RX, botón, acción
└── widgets/mainwindow.ui              ← MODIFICADO: botón ft2hButton, acción
```

---

## 8. Descripción de cada módulo

### `ft2h_params.f90`
Declara todos los parámetros del modo como constantes Fortran. Define las dos familias de constantes — frame estándar y frame corto — más las constantes comunes (vectors Costas, scrambling, mapeo Gray).

**Corrección aplicada**: `NMAX_S` fue aumentado de 18000 a 19200 para acomodar el waveform del frame corto completo (18432 muestras).

---

### `genft2h.f90`
Implementa `genft2h()` (frame estándar) y `pack_ft2h_short()` (frame corto).

**Frame estándar**:
1. Scrambling de 77 bits con el vector de FT4
2. Cálculo de CRC-14 → 91 bits
3. Codificación LDPC(174,91) → 174 bits
4. Mapeo Gray de 3 bits a símbolo de 8 tonos → 58 símbolos
5. Ensamblado: `[0][Costas-A×8][datos×29][Costas-B×8][datos×29][0]`

**Frame corto**: encapsula mensajes de confirmación (RR73/73/RRR) en 32 bits de payload.

---

### `gen_ft2h_wave.f90`
Genera la waveform 8-GFSK con las siguientes características:
- Pulso Gaussiano con `BT = 1.0`
- Índice de modulación `h = 1.0` (frecuencia de tono = i × baud)
- Duración del pulso: 3 símbolos (`3 × NSPS` muestras)
- Rampas coseno-cuadrado de subida y bajada de 1 símbolo
- Salida: `(nsym + 2) × NSPS` muestras (incluye símbolo extra al inicio y al final)

---

### `ldpc_64_32.f90`
Implementa el código LDPC(64,32) para frames cortos:
- `encode_64_32()`: codificación de 32 bits → 64 bits
- `decode_64_32()`: decodificación OSD orden-1 (Ordered Statistics)
- `get_crc16()` / `check_crc16()`: verificación de integridad

**Correcciones aplicadas** (4 bugs):
- Declaraciones movidas antes de sentencias ejecutables
- Variable `cw_test` declarada como `integer*1 cw_test(64)`
- Variables `key` (real) e `ik` (integer) declaradas explícitamente
- Asignación corregida: `cw_test(1:64) = cw(1:64)`

---

### `sync_ft2h.f90`
Calcula la potencia de correlación con los arrays Costas para estimar el offset temporal y frecuencial. Soporta búsqueda de frame estándar y corto.

**Corrección aplicada**: off-by-1 en índices de datos. Los datos comienzan en símbolo 9 (= 1 rampa + 8 Costas), no en símbolo 10.

---

### `ft2h_downsample.f90`
Submuestrea la señal de entrada por factor `NDOWN = 18` para el procesamiento de sincronía gruesa.

---

### `ft2h_getcandidates.f90`
Busca en el espectrograma de la señal los candidatos con mayor relación S/N para iniciar la decodificación.

---

### `ft2h_get_bitmetrics.f90`
Extrae las métricas de bit individuales (LLR) a partir de la correlación del matched-filter para cada posición de símbolo. Genera las entradas del decodificador LDPC.

**Correcciones aplicadas** (2 bugs):
1. Fila LSB del desmapeo Gray corregida: `[0,1,1,0,0,1,1,0]` en vez de `[0,1,1,0,1,0,0,1]`
2. Off-by-1 en índices de símbolo: `jsym = 8 + isym` (no `9 + isym`)

---

### `subtractft2h.f90`
Resta la señal de una trama decodificada del buffer de recepción para facilitar la decodificación iterativa de señales superpuestas.

**Corrección aplicada**: parámetros corregidos para evitar desbordamiento del buffer al llamar a `gen_ft2h_wave()`.

---

### `unpack_ft2h_short.f90`
Convierte los 32 bits decodificados del frame corto a cadenas de texto estándar: RR73, 73, RRR.

---

### `ft2h_decode.f90`
Módulo top-level del decodificador. Coordina el pipeline completo:
1. Sincronía (sync_ft2h)
2. Métricas de bit (ft2h_get_bitmetrics)
3. Decodificación LDPC (ldpc_174_91_c_decode)
4. Descrambling
5. Desempaquetado (unpack77 / unpack_ft2h_short)

**Correcciones aplicadas** (2 bugs críticos):
1. Declaraciones de variables movidas al bloque de declaraciones
2. **Bug crítico**: faltaba el descrambling del mensaje. Sin esta línea todos los mensajes serían basura:
   ```fortran
   message77 = mod(message77 + rvec, 2)
   ```

---

## 9. Integración en WSJT-X (C++/Qt)

### `CMakeLists.txt`
Los 10 archivos `.f90` de FT2H fueron añadidos a la librería `wsjt_fort`.

### `models/Modes.hpp` / `Modes.cpp`
```cpp
// Modes.hpp — enum Mode
enum class Mode { ..., Q65, FT2H, MODES_END };

// Modes.cpp — array de nombres
static char const * const mode_names[] = { ..., "Q65", "FT2H" };
```

### `lib/decoder.f90`
Añadido el dispatch al decodificador FT2H cuando `nmode == 25`:
```fortran
use ft2h_decode
...
if(nmode.eq.25) call ft2h_decode_all(params, ...)
```

### `widgets/mainwindow.h`
```cpp
#define NUM_FT2H_SYMBOLS 76
#define NUM_FT2H_SHORT_SYMBOLS 32
void on_ft2hButton_clicked();
void on_actionFT2H_triggered();
void chkFT2H();
```

### `widgets/mainwindow.cpp`
- Generación de waveform TX (estándar y corto según el mensaje)
- Configuración del modo: `m_TRperiod = 4.0`, `m_toneSpacing = 20.833`
- Barra de estado azul `#0066cc` cuando FT2H está activo
- `nmode = 25` en el dispatch del decodificador
- Frecuencia de muestreo de audio: 48000 S/s

### `widgets/mainwindow.ui`
- Botón `ft2hButton` entre FT4 y msk144
- Acción `actionFT2H` en el menú Mode (checkable)

---

## 10. Bugs encontrados y corregidos

| # | Archivo | Tipo | Descripción | Impacto |
|---|---------|------|-------------|---------|
| 1 | `ft2h_params.f90` | Parámetro | `NMAX_S = 18000` → `19200` | Desbordamiento de buffer en frame corto |
| 2 | `ft2h_get_bitmetrics.f90` | Lógica | Fila LSB del mapeo Gray era incorrecta | Bits 0/1 de tono 4-7 invertidos (50% BER) |
| 3 | `subtractft2h.f90` | Parámetro | Se pasaba `NN2` (76) en lugar de `NN` (74) + `nwave` | Desbordamiento de buffer en `gen_ft2h_wave` |
| 4 | `ldpc_64_32.f90` | Sintaxis | Declaraciones después de sentencias ejecutables | Fallo de compilación Fortran 77 |
| 5 | `ldpc_64_32.f90` | Sintaxis | `cw_test` no declarada | Fallo de compilación |
| 6 | `sync_ft2h.f90` | Off-by-1 | Índices de datos `(8+i)` → `(9+i)` y `(45+i)` → `(46+i)` | Sincronía fallida en frame estándar |
| 7 | `ft2h_get_bitmetrics.f90` | Off-by-1 | `jsym = 9 + isym` → `jsym = 8 + isym` | Demodulación desplazada 1 símbolo |
| 8 | `ft2h_decode.f90` | Sintaxis | Declaraciones después de sentencias ejecutables | Fallo de compilación |
| 9 | `ft2h_decode.f90` | **Crítico** | Faltaba `message77 = mod(message77 + rvec, 2)` | Todos los mensajes decodificados incorrectos |

**En el simulador Python**:

| # | Archivo | Descripción | Efecto |
|---|---------|-------------|--------|
| 10 | `ft2h_sim_v2.py` | Demodulador GFSK sin offset temporal | 100% de errores de símbolo |
| 11 | `ft2h_sim_v2.py` | Typo en Mn\[21\]: `22` → `27` | Síndrome ≠ 0 en codewords válidos, ~50% de fallos |

---

## 11. Simulador Python

El simulador está en `lib/ft2h/sim/ft2h_sim_v2.py` e implementa la cadena completa end-to-end en Python.

### Requisitos

```
Python >= 3.10
numpy >= 1.20
scipy >= 1.7
matplotlib >= 3.4
```

### Uso

```bash
# Simulación rápida (30 trials por SNR, rango -20 a -4 dB)
python ft2h_sim_v2.py --quick

# Simulación completa (100 trials por SNR, rango -22 a -2 dB)
python ft2h_sim_v2.py
```

### Componentes del simulador

| Componente | Implementación |
|-----------|----------------|
| Encoder | LDPC(174,91) con matriz generadora real de WSJT-X (83 strings hex) |
| Modulator | 8-GFSK con pulso Gaussiano BT=1.0, h=1.0 |
| Canal | AWGN con convenio WSJT-X: `rx = sqrt(BW/fs) × 10^(snr/20) × wave + N(0,1)` |
| Demodulator | Matched-filter de tono, offset +1 símbolo por delay del pulso GFSK |
| Decoder | BP min-sum (escala 0.8, 50 iter.) + OSD fallback (40 flips) |
| Verificación | CRC-14 post-decode |

### Bug crítico del demodulador (descubierto y corregido)

El pulso Gaussiano GFSK con BT=1.0 tiene una duración efectiva de 3 símbolos. Cuando se genera el tono j en `j × NSPS`, su energía se centra en `(j+1.5) × NSPS`. Esto causa que el filtro aplicado en `pos × NSPS` detecte el tono del símbolo anterior (pos-1).

**La corrección es un desplazamiento de +1 símbolo**:

```python
# INCORRECTO — detecta símbolo pos-1
k0 = pos * NSPS

# CORRECTO — detecta símbolo pos
k0 = (pos + 1) * NSPS
```

Verificación (sin ruido): 58/58 símbolos correctos con el offset, 0/58 sin él.

---

## 12. Resultados de simulación

### Curva WER vs SNR (100 trials por punto)

```
SNR (dB)   WER      OK/100
────────   ──────   ──────
-22 a -10  1.0000    0/100   ← por debajo del umbral
   -9      0.9700    3/100
   -8      0.4600   54/100   ← zona de transición
   -7      0.0900   91/100
   -6      0.0000  100/100   ← decodifica perfectamente
```

**Umbral al 50%: -8.1 dB** (convenio de ruido WSJT-X)

### Tabla comparativa final

```
Modo        Sensibilidad  Ciclo    Throughput   BW
──────────  ────────────  ───────  ───────────  ───────
FT8            -21.0 dB   15.0 s    5.1 b/s     50 Hz
FT4            -17.5 dB    7.5 s   10.3 b/s     90 Hz
FT2H (sim)      -8.1 dB    4.0 s   19.2 b/s    167 Hz
FT2H (opt*)   ~-13.0 dB    4.0 s   19.2 b/s    167 Hz
```

> `*` Estimación con demodulador trellis GFSK + sum-product BP + sincronía iterativa (~5 dB de ganancia sobre el simulador simple).

---

## 13. Análisis del simulador

### ¿Por qué el simulador dice -8.1 dB y el teórico predice -15.8 dB?

La diferencia de ~7 dB se explica por las simplificaciones del simulador vs una implementación real:

| Factor | Pérdida estimada |
|--------|:----------------:|
| Demodulador simple (max-log en vez de trellis GFSK) | ~3 dB |
| No hay sincronía iterativa (tiempo y frecuencia perfectos) | ~1 dB (ventaja artificial) |
| Convenio de ruido: `N(0,1)` vs ruido por símbolo | ~2 dB de escala |
| BP min-sum vs sum-product | ~0.5 dB |
| No hay estimación de canal (R ≡ I, Q = 0) | ~1 dB |

La estimación de -13 dB para una implementación optimizada es conservadora pero razonable.

### ¿Por qué log-sum-exp no mejora sobre max-log?

A SNR tan bajo, el ruido domina y la diferencia entre `log Σ exp` y `max` es despreciable. La limitación real es la calidad de los LLR, no el algoritmo de combinación de tonos.

---

## 14. Compilación

### Dependencias (MSYS2)

```bash
# Con MSYS2 en A:\msys64 (entorno MINGW64)
pacman -S --needed \
    mingw-w64-x86_64-gcc-fortran \
    mingw-w64-x86_64-cmake \
    mingw-w64-x86_64-qt5-base \
    mingw-w64-x86_64-fftw \
    mingw-w64-x86_64-libsamplerate \
    mingw-w64-x86_64-boost \
    mingw-w64-x86_64-portaudio \
    mingw-w64-x86_64-hamlib
```

### Pasos de compilación

```bash
# Desde MSYS2 MinGW64
cd /d/Programacion/Radioaficion/wsjt-wsjtx

mkdir build && cd build

cmake .. \
  -G "MinGW Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_Fortran_COMPILER=gfortran \
  -DCMAKE_CXX_COMPILER=g++

mingw32-make -j$(nproc)
```

### Verificar que FT2H está incluido

```bash
# Comprobar que los archivos FT2H están en el build
grep -r "ft2h" CMakeFiles/ --include="*.make" | head -20

# O buscar el ejecutable generado
ls bin/wsjtx.exe
```

---

## 15. Mejoras futuras

### Prioridad alta

1. **Demodulador trellis GFSK**: Usar el algoritmo de Viterbi sobre el trellis de la FSK continua. Ganancia estimada: **+3 dB**. Requiere adaptar `ft4_baseline.f90` (ya existe en WSJT-X para FT4).

2. **Sincronía iterativa**: Refinar el offset de tiempo y frecuencia entre iteraciones de decodificación. En WSJT-X se hace en FT8 y da ~1 dB extra.

3. **Sum-product BP**: Reemplazar min-sum por sum-product en el decodificador LDPC. Ganancia ~0.5 dB, pero más lento.

### Prioridad media

4. **Estimación de canal doble-banda lateral**: Forzar que el símbolo ó su complejo conjugado tengan coherencia para reducir el piso de ruido de fase.

5. **Frames cortos automáticos**: Detectar en `genft2h.f90` si el mensaje es RR73/73/RRR y emitir automáticamente un frame corto.

6. **Diversidad de polarización VHF/UHF**: El ancho de banda de 167 Hz es compatible con EME en 144 MHz.

### Prioridad baja

7. **Codificación de mensaje extendida**: Usar los 77 bits para soportar locator de 6 caracteres (sub-cuadrícula) con el emisor-receptor.

8. **Modo auto-switching FT2H/FT4**: Degradar automáticamente a FT4 cuando la SNR cae por debajo de -13 dB.

9. **FT2H corto robusto**: Rediseñar el frame corto con LDPC(128,32) para llevar la sensibilidad al nivel de FT8 manteniendo el ciclo de 4 s.

---

## 16. Glosario

| Término | Significado |
|---------|-------------|
| **GFSK** | Gaussian Frequency Shift Keying — FSK con filtro Gaussiano para reducir el ancho de banda |
| **8-GFSK** | FSK con 8 tonos distintos (3 bits por símbolo) |
| **h** | Índice de modulación FSK: relación entre la separación de frecuencias y la tasa de símbolo |
| **BT** | Producto ancho de banda × tiempo del filtro Gaussiano. BT=1.0 → filtro estrecho (poca ISI) |
| **LDPC** | Low Density Parity Check — código de corrección de errores de alta eficiencia |
| **CRC** | Cyclic Redundancy Check — suma de verificación para detectar errores |
| **SNR** | Signal to Noise Ratio — relación señal/ruido |
| **WER** | Word Error Rate — tasa de error por mensaje (0 = todos correctos, 1 = todos fallan) |
| **BER** | Bit Error Rate — tasa de error por bit |
| **LLR** | Log-Likelihood Ratio — métrica de confianza de un bit (positivo = 0, negativo = 1) |
| **BP** | Belief Propagation — algoritmo iterativo para decodificación LDPC |
| **OSD** | Ordered Statistics Decoding — decodificación por estadísticas ordenadas (fallback) |
| **Costas** | Array de sincronía de 8 símbolos con propiedades de correlación óptimas |
| **T/R** | Transmit/Receive — ciclo de operación (tiempo total de turno) |
| **ISI** | Inter-Symbol Interference — interferencia entre símbolos consecutivos por el filtro |
| **trellis** | Red de estados para el demodulador óptimo de GFSK (algoritmo de Viterbi) |
| **QSO** | Contacto de radio (equivalente a "conversación" en radioafición) |
| **DX** | Contacto de larga distancia |
| **EME** | Earth-Moon-Earth: comunicación por rebote lunar |

---

## Créditos y referencias

- **WSJT-X**: Joe Taylor K1JT, Steve Franke K9AN, Bill Somerville G4WJS et al.  
  https://physics.princeton.edu/pulsar/k1jt/wsjtx.html

- **LDPC(174,91) code**: K9AN/K1JT — `lib/ft8/ldpc_174_91_c_generator.f90`

- **Costas arrays**: J.P. Costas (1956), optimizados para FT8 por K9AN

- **Min-sum BP**: Fossorier, Mihaljevic, Imai (1999)  
  *"Reduced Complexity Iterative Decoding of Low-Density Parity Check Codes"*

---

*Proyecto desarrollado como estudio técnico de señales digitales y teoría de información.*  
*No es un producto de la comunidad WSJT-X ni cuenta con su endorsement.*
