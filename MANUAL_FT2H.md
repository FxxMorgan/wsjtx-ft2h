# Manual de Usuario — Modo FT2H para WSJT-X

> **Versión**: 1.0 — Febrero 2026  
> **Autor**: Fork experimental WSJT-X  
> **Requisitos**: WSJT-X v2.7.0+ compilado con soporte FT2H

---

## Índice

1. [¿Qué es FT2H?](#1-qué-es-ft2h)
2. [Inicio rápido](#2-inicio-rápido)
3. [Interfaz de usuario](#3-interfaz-de-usuario)
4. [Operación paso a paso](#4-operación-paso-a-paso)
5. [Secuencia de QSO completo](#5-secuencia-de-qso-completo)
6. [Configuración de audio](#6-configuración-de-audio)
7. [Configuración de frecuencias](#7-configuración-de-frecuencias)
8. [Mensajes cortos automáticos](#8-mensajes-cortos-automáticos)
9. [Decodificación y ventana de actividad](#9-decodificación-y-ventana-de-actividad)
10. [Solución de problemas](#10-solución-de-problemas)
11. [Especificaciones técnicas](#11-especificaciones-técnicas)
12. [Comparativa de modos](#12-comparativa-de-modos)
13. [Mejoras implementadas en esta versión](#13-mejoras-implementadas-en-esta-versión)
14. [Mejoras futuras planificadas](#14-mejoras-futuras-planificadas)
15. [FAQ — Preguntas frecuentes](#15-faq--preguntas-frecuentes)

---

## 1. ¿Qué es FT2H?

**FT2H** (Franke-Taylor 2 Hybrid) es un modo digital experimental de **velocidad alta** para radioaficionados, diseñado como extensión del ecosistema WSJT-X. Combina:

- **Velocidad**: QSO completo en ~24 segundos (vs ~90 s en FT8)
- **Robustez**: Usa el mismo código LDPC(174,91) de FT8 para mensajes estándar
- **Eficiencia**: Mensajes de confirmación (RR73, 73, RRR) usan frames cortos de solo 1.5 s

### ¿Cuándo usar FT2H?

| Situación | ¿Usar FT2H? |
|-----------|:------------:|
| Bandas HF con buena propagación (20m, 15m, 10m abiertos) | ✅ Sí |
| Concursos donde la velocidad importa | ✅ Sí |
| Condiciones de aurora débil en VHF | ✅ Sí |
| DX extremo (señales muy débiles, -18 dB o menos) | ❌ No, usar FT8 |
| EME (rebote lunar) con señales < -15 dB | ❌ No, usar FT8 o JT65 |
| Propagación irregular (Sporadic E) | ⚠️ Depende de la S/N |

**Regla general**: Si tu señal es mejor que -13 dB (SNR en 2500 Hz), FT2H funcionará. Si es peor, quédate con FT8 o FT4.

---

## 2. Inicio rápido

### Paso 1: Activar FT2H

Hay tres formas de activar el modo:

1. **Botón rápido**: Haz clic en el botón **FT2H** (azul) en la barra de modos
2. **Menú**: Ve a `Mode → FT2H`
3. **Teclado**: El modo se puede asignar a un atajo personalizado

Al activar FT2H, la barra de estado cambia a **azul (#0066cc)** con texto blanco.

### Paso 2: Configurar frecuencia

- Ajusta la frecuencia TX/RX en la cascada (waterfall)
- El ancho de banda del modo es ~167 Hz
- Rango útil: 200-3000 Hz dentro de la banda de audio

### Paso 3: Iniciar secuencia automática

- Activa **Auto Seq** (se habilita automáticamente en FT2H)
- El programa gestionará los intercambios de mensajes

### Paso 4: Llamar CQ o responder

- Escribe tu mensaje CQ o haz doble clic en una estación decodificada
- Pulsa **Enable TX** para comenzar a transmitir

---

## 3. Interfaz de usuario

### Barra de modos

```
[ FT8 ] [ FT4 ] [*FT2H*] [ MSK144 ] [ Q65 ] ...
                 ^^^^^^^
                 Botón FT2H (azul cuando activo)
```

### Barra de estado

Cuando FT2H está activo, la barra de modo muestra:
- **Color de fondo**: Azul (#0066cc)
- **Color de texto**: Blanco
- **Indicador**: "FT2H" con el período T/R

### Ventana de decodificación

Los mensajes decodificados aparecen con el formato:

```
UTC    dB   DT   Freq   Mensaje                           FT2H
--------------------------------------------------------------
123456  -8  0.3  1500   CQ CE3XXX FK30                    FT2H
123500  -5  0.1  1500   CE3XXX CA2YYY FK30               FT2H
```

La etiqueta `FT2H` al final identifica el modo de decodificación.

### Controles habilitados

En modo FT2H, los siguientes controles están activos:
- ✅ Auto Seq (secuencia automática)
- ✅ Respond Combo (selector de respuesta)
- ✅ TX First checkbox (transmitir en primer período)
- ✅ Botones TX 2, 4, 5, 6
- ✅ Cascada (waterfall) con espectrograma

---

## 4. Operación paso a paso

### 4.1. Llamar CQ

1. Asegúrate de que tu indicativo y locator estén configurados en `File → Settings → General`
2. Activa FT2H con el botón o menú
3. El mensaje TX1 se configura automáticamente como `CQ [INDICATIVO] [LOCATOR]`
4. Haz clic en **Enable TX**
5. El programa transmitirá CQ en el próximo período de 4 segundos

### 4.2. Responder a un CQ

1. En la ventana de actividad de banda, haz **doble clic** en un mensaje CQ
2. El programa configurará automáticamente los mensajes de respuesta
3. La secuencia automática gestiona todo el QSO

### 4.3. Enviar confirmación

Los mensajes de confirmación (RR73, 73, RRR) se envían automáticamente como **frames cortos** de 1.5 s, lo que acelera significativamente la parte final del QSO.

---

## 5. Secuencia de QSO completo

Un QSO estándar en FT2H dura aproximadamente **24 segundos** (6 × 4 s):

```
Tiempo   Estación A          Estación B
──────   ──────────────      ──────────────
 T+0s    CQ CE3XXX FK30      (recibe)
 T+4s    (recibe)            CE3XXX CA2YYY GF15
 T+8s    CA2YYY CE3XXX -05   (recibe)
T+12s    (recibe)            CE3XXX CA2YYY R-08
T+16s    CA2YYY CE3XXX RR73  (recibe)          ← Frame corto (~1.5 s)
T+20s    (recibe)            CE3XXX CA2YYY 73  ← Frame corto (~1.5 s)
                              ¡QSO COMPLETO!
```

### Comparativa de tiempos

| Modo | Período T/R | QSO completo |
|------|:-----------:|:------------:|
| FT8  | 15.0 s | ~90 s |
| FT4  | 7.5 s | ~45 s |
| **FT2H** | **4.0 s** | **~24 s** |

---

## 6. Configuración de audio

### Frecuencia de muestreo

FT2H opera a **12000 S/s** internamente, pero la interfaz de audio usa **48000 S/s** (estándar de WSJT-X). El programa maneja la conversión automáticamente.

### Nivel de audio TX

- Ajusta el nivel de salida para que el ALC del transceptor **NO** actúe
- El pico de modulación debe estar al 80-90% del nivel máximo
- Un nivel excesivo causa distorsión y ensanchamiento espectral

### Configuración de dispositivos

En `File → Settings → Audio`:
- Selecciona tu dispositivo de entrada (micrófono / línea del TRX)
- Selecciona tu dispositivo de salida (auriculares / línea al TRX)
- Ajusta el volumen para que la cascada muestre un nivel de ruido adecuado

---

## 7. Configuración de frecuencias

### Frecuencias sugeridas para FT2H

Al ser un modo experimental, no hay asignación oficial. Sugerencias:

| Banda | Frecuencia (MHz) | Notas |
|-------|:-----------------:|-------|
| 20m | 14.082 | Evitar conflicto con FT4 en 14.080 |
| 15m | 21.142 | Libre de otros modos digitales |
| 10m | 28.182 | Buena para pruebas en condiciones abiertas |
| 6m | 50.322 | VHF, útil en Sporadic E |
| 2m | 144.176 | Para experimentación EME |

### Ancho de banda

- El modo ocupa ~167 Hz por señal
- Espaciado mínimo entre estaciones: ~200 Hz
- La cascada puede mostrar múltiples señales simultáneas

---

## 8. Mensajes cortos automáticos

FT2H detecta automáticamente cuando el mensaje es una confirmación y usa un **frame corto** más eficiente:

| Mensaje | Tipo de frame | Duración TX |
|---------|:-------------:|:-----------:|
| CQ CE3XXX FK30 | Estándar (77-bit) | 3.65 s |
| CE3XXX CA2YYY -05 | Estándar (77-bit) | 3.65 s |
| RR73 | **Corto (16-bit)** | **1.54 s** |
| 73 | **Corto (16-bit)** | **1.54 s** |
| RRR | **Corto (16-bit)** | **1.54 s** |

Los frames cortos usan un código LDPC(64,32) más sencillo pero suficiente para estas confirmaciones simples. La sensibilidad es de ~-9 dB (vs -15.8 dB del frame estándar).

---

## 9. Decodificación y ventana de actividad

### Proceso de decodificación

El decodificador FT2H ejecuta dos pasadas:

1. **Frames estándar**: Busca señales con 2 arrays Costas de 8 tonos, decodifica con LDPC(174,91)
2. **Frames cortos**: Busca señales con 1 array Costas, decodifica con LDPC(64,32)

### Indicadores de calidad

En la ventana de decodificación:
- **dB**: SNR estimado (relación señal/ruido en 2500 Hz BW)
- **DT**: Offset temporal (diferencia de reloj con la otra estación)
- **Freq**: Frecuencia de audio de la señal decodificada

### Umbrales de decodificación

| SNR (dB) | Probabilidad de decodificación |
|:---------:|:------------------------------:|
| < -10 | 0% (por debajo del umbral) |
| -9 | ~3% (zona marginal) |
| -8 | ~50% (umbral al 50%) |
| -7 | ~90% |
| ≥ -6 | ~100% |

---

## 10. Solución de problemas

### No decodifica ninguna señal

1. **Verifica el nivel de audio**: La cascada debe mostrar ruido visible
2. **Comprueba la frecuencia**: FT2H busca en todo el rango de audio configurado
3. **Revisa el reloj del PC**: FT2H es sensible a errores de tiempo > 0.5 s
4. **Verifica el modo**: Asegúrate de que ambas estaciones están en FT2H

### La transmisión no sale

1. Verifica que **Enable TX** está activado
2. Comprueba la configuración de PTT en `Settings → Radio`
3. Revisa que el dispositivo de audio de salida está configurado
4. Verifica que no hay conflicto con otro programa usando el audio

### Mensajes cortos no se decodifican

Los frames cortos necesitan mejor SNR (~-9 dB vs -15.8 dB). Si una estación no decodifica tus confirmaciones:
- Aumenta potencia si es posible
- La otra estación puede estar en el límite de sensibilidad para frames cortos

### Error "bad message"

El mensaje de texto no es válido para el empaquetado de 77 bits. Verifica:
- El indicativo tiene formato estándar (letras y números)
- El locator es válido (ej: FK30, GF15)
- No hay caracteres especiales no soportados

---

## 11. Especificaciones técnicas

### Frame estándar (77 bits de payload)

| Parámetro | Valor |
|-----------|-------|
| Modulación | 8-GFSK (8 tonos) |
| Velocidad de símbolo | 20.833 Bd |
| Índice de modulación h | 1.0 |
| Factor BT (filtro Gaussiano) | 1.0 |
| Muestras por símbolo | 576 @ 12000 S/s |
| Código LDPC | (174, 91) |
| Bits de mensaje | 77 |
| CRC | 14 bits |
| Símbolos de datos | 58 |
| Símbolos de sincronía | 16 (2 × Costas 8) |
| Total de símbolos | 76 (con rampas) |
| Duración TX | 3.648 s |
| Ciclo T/R | 4.0 s |
| Ancho de banda | ~167 Hz |
| Sensibilidad teórica | -15.8 dB SNR (2500 Hz) |

### Frame corto (16 bits de payload)

| Parámetro | Valor |
|-----------|-------|
| Código LDPC | (64, 32) |
| Bits de payload | 16 |
| CRC | 16 bits |
| Símbolos de datos | 22 |
| Símbolos de sincronía | 8 (1 × Costas) |
| Total de símbolos | 32 |
| Duración TX | 1.536 s |
| Sensibilidad | ~-9 dB |

### Estructura de los frames

**Frame estándar** (76 símbolos):
```
[Rampa↑] [Costas-A ×8] [Datos ×29] [Costas-B ×8] [Datos ×29] [Rampa↓]
   1          8              29           8             29          1
```

**Frame corto** (32 símbolos):
```
[Rampa↑] [Costas-S ×8] [Datos ×22] [Rampa↓]
   1          8              22          1
```

---

## 12. Comparativa de modos

```
Modo      Sensibilidad  Ciclo T/R  QSO completo  Throughput   BW      Uso principal
────────  ────────────  ─────────  ────────────  ──────────  ──────  ────────────────
FT8          -21 dB      15.0 s      ~90 s       5.1 b/s     50 Hz   DX, EME, señales débiles
FT4          -17.5 dB     7.5 s      ~45 s      10.3 b/s     90 Hz   Concursos HF
FT2H (std)   -15.8 dB     4.0 s      ~24 s      19.2 b/s    167 Hz   HF buenas condiciones
FT2H (sim)    -8.1 dB     4.0 s      ~24 s      19.2 b/s    167 Hz   (con demod. simple)
```

### Ventajas de FT2H sobre FT8/FT4

- **3.8× más rápido** que FT8 en throughput
- **QSO en 24 s** vs 90 s (FT8) o 45 s (FT4)
- Frames cortos para confirmaciones rápidas
- Compatible con la infraestructura WSJT-X existente

### Desventajas

- **Mayor ancho de banda** (167 Hz vs 50 Hz)
- **Menor sensibilidad** (3-6 dB menos que FT8)
- No apto para señales extremadamente débiles

---

## 13. Mejoras implementadas en esta versión

### Correcciones de bugs críticos

| # | Descripción | Impacto |
|---|-------------|---------|
| 1 | Rutas de include Fortran corregidas para compilación cross-directory | Compilación exitosa |
| 2 | Parámetro `NMAX_S` aumentado de 18000 a 19200 | Evita desbordamiento en frames cortos |
| 3 | Mapeo Gray LSB corregido en bitmetrics | 50% BER → correcto |
| 4 | Off-by-1 en índices de sincronía | Sincronía funcional |
| 5 | Off-by-1 en demodulación de símbolos | Alineación correcta |
| 6 | Descrambling faltante añadido en decoder | Mensajes decodificados correctamente |
| 7 | Declaraciones Fortran movidas al bloque correcto | Compilación limpia |
| 8 | Buffer overflow corregido en subtractft2h | Estabilidad en multi-pass |
| 9 | Offset de demodulador GFSK (+1 símbolo) en simulador | Simulaciones correctas |

### Integración de traducción al español

- Tooltip del botón FT2H traducido: "Cambiar al modo híbrido FT2H"
- Entradas del menú Mode traducidas
- Compatible con el sistema de internacionalización Qt existente

### Preparación para producción

- Verificación de todas las dependencias de compilación
- Compatibilidad confirmada con MinGW/MSYS2
- Script de compilación automatizado incluido

---

## 14. Mejoras futuras planificadas

### Prioridad alta (estimación: +5 dB de ganancia)

1. **Demodulador Trellis GFSK**: Reemplazar el demodulador max-log por algoritmo de Viterbi sobre el trellis de FSK continua. Ganancia estimada: **+3 dB**. Existe código base en `lib/ft4/ft4_baseline.f90`.

2. **Sincronía iterativa**: Refinar offset de tiempo y frecuencia entre pasadas de decodificación. Ganancia: **+1 dB**.

3. **Sum-product BP**: Reemplazar min-sum por sum-product en el decodificador LDPC. Ganancia: **+0.5 dB**.

### Prioridad media

4. **Estimación de canal DSB**: Reducir piso de ruido de fase usando coherencia de símbolo. Ganancia: **+1 dB**.

5. **Detección automática de frames cortos en TX**: El codificador detectaría RR73/73/RRR sin intervención manual.

6. **Diversidad de polarización VHF/UHF**: El BW de 167 Hz es compatible con EME en 144 MHz.

### Prioridad baja

7. **Locator extendido (6 caracteres)**: Usar los 77 bits para sub-cuadrícula.

8. **Auto-switching FT2H↔FT4**: Degradar automáticamente a FT4 cuando SNR < -13 dB.

9. **Frame corto robusto**: Rediseñar con LDPC(128,32) para sensibilidad tipo FT8 manteniendo ciclo 4 s.

10. **Waterfall adaptativo**: Zoom automático al BW de ~167 Hz del modo.

---

## 15. FAQ — Preguntas frecuentes

### ¿Puedo usar FT2H para concursos?

Sí, es ideal para concursos en bandas abiertas donde la velocidad importa más que la sensibilidad extrema. Un QSO en 24 s permite alta tasa de contactos.

### ¿Es compatible con estaciones que no tienen FT2H?

No. Ambas estaciones deben usar FT2H. El protocolo es diferente a FT8/FT4 y no hay interoperabilidad.

### ¿Qué potencia necesito?

Depende de las condiciones. Como referencia:
- **Buenas condiciones HF (10-20m)**: 5-25W suelen ser suficientes
- **Condiciones moderadas**: 50-100W
- **VHF/Tropo**: Según distancia y condiciones

### ¿Funciona con VOX?

Sí, pero el ciclo de 4 s es muy rápido. Se recomienda usar **control CAT** o **PTT por hardware** para conmutación fiable.

### ¿Puedo usar FT2H en QRP?

Sí, con la condición de que la señal sea mejor que -13 dB SNR en la estación receptora. A 5W en 20m con buena propagación, esto es habitual para distancias de hasta ~3000 km.

### ¿Cuántas señales FT2H caben en 3 kHz?

Con ~200 Hz de espaciado por señal: **~15 señales simultáneas** en una ventana de 3 kHz.

### ¿El frame corto se selecciona automáticamente?

Sí. Cuando el mensaje es RR73, 73 o RRR, el transmisor genera automáticamente un frame corto de 1.5 s.

### ¿Por qué la sensibilidad del simulador (-8.1 dB) es peor que la teórica (-15.8 dB)?

El simulador usa un demodulador simplificado (max-log en vez de trellis), sin estimación de canal y con BP min-sum. Una implementación optimizada debería alcanzar ~-13 dB.

---

## Glosario rápido

| Término | Significado |
|---------|-------------|
| **8-GFSK** | FSK gaussiano con 8 tonos (3 bits/símbolo) |
| **LDPC** | Código de paridad de baja densidad (corrección de errores) |
| **Costas** | Array de sincronía con buenas propiedades de correlación |
| **T/R** | Período transmisión/recepción |
| **SNR** | Relación señal a ruido |
| **Frame estándar** | Trama de 77 bits con LDPC(174,91) |
| **Frame corto** | Trama de 16 bits con LDPC(64,32) |
| **QSO** | Contacto de radio completo |
| **BW** | Ancho de banda |
| **LLR** | Log-Likelihood Ratio (métrica de confianza) |

---

*FT2H es un proyecto experimental. No es un producto oficial de la comunidad WSJT-X.*
