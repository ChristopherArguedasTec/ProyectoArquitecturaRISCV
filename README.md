# Microarquitectura RISC-V RV32I multiciclo

Proyecto Arquitectura del curso **MT-7003 Microprocesadores y microcontroladores**
Escuela de Ingeniería Mecatrónica, Instituto Tecnológico de Costa Rica (TEC), II Semestre 2026
Profesor: Dr.-Ing. Carlos Salazar García

## Integrantes

- Christopher Andrés Arguedas Maroto
- Ignacio Alberto Cascante Chinchilla
- Dylan Johel Miranda Granados
- Brayan Audiel Rodríguez López
- Bryam Samuel Rodríguez Mora

## Descripción del proyecto

El objetivo es diseñar e implementar en Verilog, con Vivado, una microarquitectura propia que
ejecute el subconjunto del ISA RISC-V RV32I que necesita el programa en C del enunciado.

El programa declara tres variables (`r`, `a`, `b`) y las modifica en un ciclo `for` de dos vueltas.
Al compilarlo para RV32I con el toolchain `riscv32-unknown-elf-gcc`, la función `main` queda en
36 instrucciones que usan 11 instrucciones reales en cinco formatos:

| Formato | Instrucciones |
|---|---|
| I | `addi`, `andi`, `slli`, `lw`, `jalr` |
| S | `sw`, `sb` |
| B | `bne`, `bge` |
| U | `lui` |
| J | `jal` |

No se usa ninguna instrucción tipo R.

### Arquitectura elegida: multiciclo

Cada instrucción se divide en varios ciclos de reloj y solo recorre los estados que necesita:

| Estado | Qué ocurre |
|---|---|
| S0 Fetch | El IR guarda la instrucción a la que apunta el PC |
| S1 Decode | Se leen los registros (A, B) y se arma el inmediato |
| S2 Execute | La ALU opera, calcula una dirección o compara registros |
| S3 Memory | Se lee o escribe la memoria de datos |
| S4 Writeback | Se escribe el registro destino y se actualiza el PC |
| HALT | Opcode no soportado: el procesador se detiene |

La ruta de datos tiene: PC, sumadores PC + 4 y PC + Imm, memoria de instrucciones, IR, banco de
registros, registros A y B, generador de inmediatos, ALU (con banderas Zero y Lt), ALUOut, memoria
de datos (con escritura por byte para `sb`), MDR y los multiplexores ALUSrc, PCSrc y ResultSrc.
La unidad de control es una máquina de estados que también decide los saltos condicionales.

### Requisitos del enunciado

- Implementación en Verilog con Vivado.
- Ruta de datos y unidad de control identificables.
- El módulo principal solo tiene dos entradas: `clk` y `reset`.
- Cada módulo documentado y con su propio testbench (objetivo, estímulos y resultados esperados).
- Dump de la memoria de datos a un archivo al terminar la simulación.
- Lo único que se cambia durante la evaluación es el archivo de la memoria de instrucciones.

## Plan de trabajo

El procesador se construye de abajo hacia arriba. Cada etapa agrega módulos probados con su
testbench antes de conectarlos:

1. **Módulos básicos:** registros, sumador y multiplexores. *(`ProyectoRISCV.1`)*
2. **ALU y generador de inmediatos.** *(`ProyectoRISCV.2`)*
3. **Banco de registros, memoria de instrucciones y memoria de datos.** *(`ProyectoRISCV.3`)*
4. **Unidad de control (máquina de estados).** *(`ProyectoRISCV.4`)*
5. **Módulo superior `riscv_top` y simulación del programa completo con el dump de memoria.** *(`ProyectoRISCV.5`)*

## Etapa 1: módulos básicos

Esta primera parte implementa las piezas más simples de la ruta de datos. Son los bloques que
guardan valores entre ciclos (lo que hace que el diseño sea multiciclo), los que calculan la
siguiente dirección del PC y los que deciden por dónde viajan los datos.

| Módulo | Qué hace | Dónde se usa en el procesador |
|---|---|---|
| `reg_en.v` | Registro de 32 bits con enable y reset síncrono | PC (enable = PCWrite) e IR (enable = IRWrite) |
| `reg_noen.v` | Registro de 32 bits que captura en cada flanco | A, B, ALUOut y MDR |
| `sumador.v` | Suma de 32 bits | PC + 4 y PC + Imm |
| `mux2.v` | Multiplexor de 2 entradas | ALUSrc: segundo operando de la ALU (rs2 o inmediato) |
| `mux3.v` | Multiplexor de 3 entradas (sel = 11 entrega d0) | PCSrc: PC + 4, PC + Imm o destino de `jalr` |
| `mux4.v` | Multiplexor de 4 entradas | ResultSrc: dato que se escribe en rd (ALUOut, MDR, PC + 4 o inmediato) |

Por qué se necesitan:

- **Registros.** En el multiciclo, lo que se calcula en un ciclo se guarda para usarlo en el
  siguiente. El PC y el IR llevan enable porque deben mantener su valor durante toda la
  instrucción y cambiar solo en un estado específico.
- **Sumadores.** Calculan las dos posibles direcciones siguientes sin ocupar la ALU.
- **Multiplexores.** Son las decisiones de la ruta de datos que controla la unidad de control.

### Testbenches de esta etapa

Cada testbench instancia el módulo, aplica estímulos, compara cada salida con el valor esperado e
imprime `OK` o `ERROR`. Al final indica si todas las pruebas pasaron.

| Testbench | Qué prueba |
|---|---|
| `tb_reg_en.v` | Captura solo con `en = 1`, mantiene el valor con `en = 0`, prioridad del reset |
| `tb_reg_noen.v` | Captura en cada flanco, no cambia entre flancos, reset |
| `tb_sumador.v` | PC + 4 y PC + Imm con saltos reales del programa (`j +60`, `bge -64`, `bnez +16`) y desborde |
| `tb_mux.v` | Todas las combinaciones de `sel` en los tres multiplexores, incluido el valor por defecto de `mux3` |

## Etapa 2: ALU y generador de inmediatos

Esta etapa agrega los dos bloques combinacionales que hacen el trabajo de cálculo de la ruta de
datos: la ALU, que opera sobre los registros, y el generador de inmediatos, que convierte el campo
inmediato de la instrucción en un número de 32 bits. El proyecto `ProyectoRISCV.2` contiene los
módulos de la etapa 1 sin cambios más los nuevos.

| Módulo | Qué hace | Dónde se usa en el procesador |
|---|---|---|
| `alu.v` | Suma, resta, AND y desplazamiento a la izquierda según `ALUControl`; entrega las banderas `zero` y `lt` | Estado Execute: resultado hacia ALUOut, banderas hacia la unidad de control |
| `imm_gen.v` | Arma el inmediato de los formatos I, S, B, U y J según `ImmSrc` y lo extiende con signo | Entrada del mux ALUSrc, del sumador PC + Imm y del mux de resultado (`lui`) |

Operaciones de la ALU y qué instrucciones las usan:

| `ALUControl` | Operación | Instrucciones |
|---|---|---|
| `000` | `a + b` | `addi` y direcciones rs1 + imm de `lw`, `sw`, `sb` y `jalr` |
| `001` | `a - b` | Comparación de `bne` y `bge` |
| `010` | `a & b` | `andi` |
| `011` | `a << b[4:0]` | `slli` |
| `100`-`111` | Resultado 0 | Códigos reservados |

Por qué se necesitan:

- **ALU.** Es el único bloque que opera sobre los datos. Las banderas permiten que la unidad de
  control decida los saltos: `bne` salta si `zero = 0` y `bge` salta si `lt = 0`. La bandera `lt`
  compara con signo (`$signed`), porque el programa usa números negativos.
- **Generador de inmediatos.** En los formatos S, B y J el inmediato viene repartido en varias
  partes de la instrucción para que rs1, rs2 y rd queden siempre en la misma posición. Este bloque
  lo reordena y copia el bit 31 para extender el signo, por ejemplo el −32 de `addi sp,sp,-32` o
  el −64 de `bge`.

Con esta etapa la ruta de datos ya soporta los cinco formatos que usa el programa (I, S, B, U y J).

### Testbenches de esta etapa

| Testbench | Qué prueba |
|---|---|
| `tb_alu.v` | 14 casos: las cuatro operaciones con valores del programa (`i++`, `b & 0xF`, `b << 1`), las comparaciones de `bne` (i = 0 y 1) y `bge` (i = 1 y 2), `lt` con signo (−1 contra 1), el uso de solo `b[4:0]` en el desplazamiento y un código reservado |
| `tb_imm_gen.v` | 15 casos: 14 instrucciones reales de `main` en los cinco formatos (−32 de `addi sp`, −29 de `sb`, +16 de `bnez`, −64 de `bge`, 0xC000 de `lui`, +60 de `j`, entre otras) y un `ImmSrc` no usado |

Se simularon en Vivado: los dos testbenches indican `TODAS LAS PRUEBAS PASARON`, igual que los
cuatro de la etapa 1, que siguen incluidos en este proyecto.

## Etapa 3: banco de registros y memorias

Esta etapa agrega los tres bloques que guardan información: el banco de registros, donde viven los
valores con los que trabaja el programa, y las dos memorias, una con el programa y otra con los
datos. También se agrega `programa.hex`, que es el programa en C ya compilado. El proyecto
`ProyectoRISCV.3` contiene los módulos de las etapas 1 y 2 sin cambios más los nuevos.

| Módulo | Qué hace | Dónde se usa en el procesador |
|---|---|---|
| `regfile.v` | 32 registros de 32 bits con dos lecturas combinacionales (rs1, rs2) y una escritura síncrona (rd) habilitada por `RegWrite`; x0 siempre vale 0 y el reset pone todo en 0 | Estado Decode (lee rs1 y rs2 hacia A y B) y Writeback (escribe el resultado en rd) |
| `instr_mem.v` | Memoria de 256 palabras que se carga con `$readmemh` desde `programa.hex`; entrega la instrucción de la dirección del PC (índice `addr[9:2]`) | Estado Fetch: la instrucción va al IR |
| `data_mem.v` | Memoria de 1024 palabras iniciada en 0, lectura combinacional y escritura síncrona; con `StoreByte` = 1 solo escribe el byte que indica `addr[1:0]` | Estado Memory: `lw` lee hacia el MDR; `sw` y `sb` escriben el registro B |
| `programa.hex` | Las 36 instrucciones de `main` en hexadecimal, una por línea, tomadas de la salida de `riscv32-unknown-elf-gcc` | Contenido de la memoria de instrucciones; es lo único que se cambia al evaluar |

Por qué se necesitan:

- **Banco de registros.** Todas las instrucciones del programa leen o escriben registros. El reset en
  0 hace que `sp` arranque en 0, y el registro x0 fijo en 0 permite instrucciones como
  `sw zero,-24(s0)` (`i = 0`).
- **Memoria de instrucciones.** Guarda el programa. Se separa de la de datos para que el Fetch y el
  acceso a datos no compitan por la misma memoria.
- **Memoria de datos.** Las variables del programa (`r`, `a`, `i`, `b`) viven en la pila. La memoria
  usa los 12 bits bajos de la dirección, así que la pila que empieza en `sp = 0` y crece hacia abajo
  (0xFFFFFFE0…) cae en las direcciones 0xFE0 a 0xFFC. La escritura por byte es necesaria para `sb`,
  que guarda el `char a` en 0xFE3 sin modificar los otros tres bytes de la palabra.

### Testbenches de esta etapa

| Testbench | Qué prueba |
|---|---|
| `tb_regfile.v` | 11 casos: reset en 0, escritura y lectura por los dos puertos con valores del programa (b = 33, r = 0xC7DF, sp = −32), x0 siempre en 0, `we = 0` no escribe, la escritura no se ve antes del flanco y el reset borra |
| `tb_instr_mem.v` | 10 casos: compara direcciones del programa con el desensamblado (primera instrucción, `lui`, `sb`, `bnez`, `bge`, `ret` en 0x8C), una dirección después del programa (debe dar 0), la última palabra y una dirección no alineada |
| `tb_data_mem.v` | 11 casos: `sw` de `i` y de `r` con direcciones de la pila, `sb` de 'c' y luego 'b' en 0xFE3, `sb` en cada uno de los cuatro bytes de una palabra y escritura con `we = 0`; al final genera el dump completo en `dump_data_mem.txt` |

Los tres testbenches se simularon en Vivado y terminan en `TODAS LAS PRUEBAS PASARON`, igual que los
seis de las etapas 1 y 2, que siguen incluidos en este proyecto. Las capturas de la consola y el
dump generado están en [`resultados/etapa3/`](resultados/etapa3).

Si `tb_instr_mem` sale con todas las instrucciones en 0, Vivado no encontró `programa.hex`: hay que
copiarlo a `ProyectoRISCV.3.sim/sim_1/behav/xsim/` y volver a simular. La advertencia
*"Not enough words in the file"* es normal porque el programa ocupa 36 de las 256 posiciones.

## Etapa 4: unidad de control

Esta etapa agrega la unidad de control: el bloque que dirige a todos los demás. Mientras que la
ruta de datos (etapas 1 a 3) tiene los caminos por donde pueden viajar los datos, la unidad de
control decide en cada ciclo cuáles se usan. El proyecto `ProyectoRISCV.4` contiene los módulos de
las etapas 1 a 3 sin cambios más el nuevo.

| Módulo | Qué hace | Dónde se usa en el procesador |
|---|---|---|
| `control_unit.v` | Máquina de estados con un registro de estado de 3 bits; según el estado, el `opcode` y `funct3` genera todas las señales de control y decide los saltos condicionales | Controla todos los registros, multiplexores, la ALU y las memorias |

Estados de la máquina y qué instrucciones pasa por cada uno:

| Estado | Qué ocurre | Siguiente estado |
|---|---|---|
| S0 Fetch | El IR guarda la instrucción (`IRWrite` = 1) | S1 |
| S1 Decode | Se leen rs1 y rs2 hacia A y B y se arma el inmediato | S4 para `lui` y `jal`; S2 para el resto; HALT si el opcode no es válido |
| S2 Execute | La ALU calcula el resultado, la dirección o la comparación | Branch: escribe el PC y vuelve a S0. `lw`, `sw`, `sb`: S3. Resto: S4 |
| S3 Memory | Se lee o escribe la memoria de datos | `sw`, `sb`: escribe memoria y PC, vuelve a S0. `lw`: S4 |
| S4 Writeback | Se escribe rd y se actualiza el PC | S0 |
| HALT | Opcode no soportado: el procesador se detiene | HALT (sale solo con reset) |

Así, cada instrucción tarda solo los ciclos que necesita: 3 los saltos condicionales, 3 `lui` y
`jal`, 4 `sw`, `sb` y las aritméticas con inmediato, y 5 `lw`.

Señales que genera:

| Señal | Códigos |
|---|---|
| `PCWrite`, `IRWrite`, `RegWrite`, `MemWrite` | Habilitan la escritura del PC, IR, banco de registros y memoria de datos |
| `PCSrc` | 00 PC + 4 · 01 PC + Imm · 10 destino de `jalr` |
| `ResultSrc` | 00 ALUOut · 01 MDR · 10 PC + 4 · 11 ImmExt |
| `ImmSrc` | 000 I · 001 S · 010 B · 011 U · 100 J |
| `ALUSrc` | 0 registro B · 1 inmediato |
| `ALUControl` | 000 suma · 001 resta · 010 AND · 011 SLL |
| `StoreByte` | 1 si es `sb` (funct3 = 000) |

Por qué se necesita:

- **Es lo que hace multiciclo al procesador.** La ruta de datos sola no sabe en qué paso de la
  instrucción está; la máquina de estados reparte cada instrucción en varios ciclos y activa solo
  las escrituras que tocan en cada uno.
- **Decide los saltos.** La lógica de salto está dentro de la unidad de control: con la bandera
  `zero` de la ALU, `bne` salta si los registros son distintos (`zero` = 0); con la bandera `lt`,
  `bge` salta si rs1 ≥ rs2 (`lt` = 0). Si salta, elige PC + Imm; si no, PC + 4.
- **Protege contra instrucciones no soportadas.** Un opcode que no es de las 11 instrucciones lleva
  al estado HALT en lugar de ejecutar algo incorrecto.

### Testbench de esta etapa

| Testbench | Qué prueba |
|---|---|
| `tb_control_unit.v` | 14 casos: para cada instrucción revisa ciclo a ciclo el estado y las escrituras (`PCWrite`, `IRWrite`, `RegWrite`, `MemWrite`) y en el último ciclo `PCSrc`, `ResultSrc`, `ImmSrc`, `ALUSrc`, `ALUControl` y `StoreByte`. Prueba `addi`, `andi`, `slli`, `lw`, `sw`, `sb`, `bne` y `bge` (saltando y sin saltar), `lui`, `jal`, `jalr` y un opcode inválido que lleva a HALT y sale con reset |

El testbench se simuló en Vivado y termina en `TODAS LAS PRUEBAS PASARON`, igual que los nueve de
las etapas anteriores, que siguen incluidos en este proyecto. La captura de la consola está en
[`resultados/etapa4/`](resultados/etapa4).

## Etapa 5: procesador completo

Esta etapa une todo. El módulo `riscv_top` instancia los doce módulos de las etapas anteriores y
los conecta según el diagrama multiciclo, y su testbench ejecuta el programa en C completo. El
proyecto `ProyectoRISCV.5` contiene los módulos de las etapas 1 a 4 sin cambios más los nuevos. La
versión definitiva para entregar es [`ProyectoRISCV.comentado`](#versión-definitiva-proyectoriscvcomentado).

| Módulo | Qué hace | Papel en el procesador |
|---|---|---|
| `riscv_top.v` | Instancia y conecta PC, sumadores, memorias, IR, banco de registros, A, B, generador de inmediatos, multiplexores, ALU, ALUOut, MDR y unidad de control | Módulo principal: es el procesador que se evalúa |

Entradas y salidas:

| Puerto | Dirección | Qué es |
|---|---|---|
| `clk`, `reset` | Entrada | Las únicas dos entradas, como pide el enunciado |
| `mem_we`, `mem_byte`, `mem_addr`, `mem_wdata` | Salida | Cada escritura en la memoria de datos (`sw` / `sb`): muestra cómo cambian las variables del programa |
| `reg_we`, `reg_wa`, `reg_wd` | Salida | Cada escritura en el banco de registros |
| `done` | Salida | Vale 1 en el ciclo en que se ejecuta el `ret` de `main` |

Por qué tiene salidas: la regla del enunciado limita solo las entradas. Las salidas permiten ver el
resultado en las formas de onda y detectar el fin del programa sin entrar a señales internas, y
evitan que la síntesis de Vivado elimine el procesador (un módulo sin salidas se optimiza hasta
quedar vacío).

Detalles de la conexión:

- El destino de `jalr` es `{ALUOut[31:1], 0}`, la tercera entrada del multiplexor del PC.
- `programa.hex` se pasa a la memoria de instrucciones con el parámetro `PROGRAMA`; para evaluar
  otro programa solo se cambia ese archivo.
- `done` se calcula como `PCWrite` y opcode de `jalr`: en `jalr` el PC solo se escribe en
  Writeback, que es el ciclo del `ret`. Como `ra` vale 0 desde el reset, después del `ret` el PC
  vuelve a 0 y `main` empieza de nuevo; por eso el dump se toma cuando `done` = 1.

### Testbench de esta etapa

| Testbench | Qué prueba |
|---|---|
| `tb_riscv_top.v` | Aplica reset, ejecuta el programa hasta que `done` = 1, imprime cada escritura a memoria, genera el dump de las 1024 palabras en `dump_memoria_datos.txt` y compara con el resultado esperado: memoria (`a`, `r`, `i`, `b`, `s0` y `ra` guardados), registros finales (`sp`, `s0`, `a4`, `a5`) y número de ciclos |

La simulación necesita 1930 ns, más que los 1000 ns que Vivado simula por defecto: al abrirse hay
que presionar **Run All** (o poner `xsim.simulate.runtime` en `all` en *Settings → Simulation*).

### Resultado

Se simuló en Vivado: el programa termina en **191 ciclos y 47 instrucciones** y el testbench indica
`EL PROGRAMA CORRIO CORRECTAMENTE`. Escrituras a memoria durante la ejecución:

| Ciclo | Instrucción | Dirección | Valor | Significado en C |
|---|---|---|---|---|
| 7 | `sw` | 0xFFC | 0x00000000 | Se guarda `ra` (prólogo) |
| 11 | `sw` | 0xFF8 | 0x00000000 | Se guarda `s0` (prólogo) |
| 27 | `sw` | 0xFE4 | 0x0000C7DF | `r = 0xC7DF` |
| 35 | `sb` | 0xFE3 | 0x63 | `a = 'c'` |
| 43 | `sw` | 0xFEC | 0x00000021 | `b = 33` |
| 47 | `sw` | 0xFE8 | 0x00000000 | `i = 0` |
| 77 | `sb` | 0xFE3 | 0x62 | `a = 'b'` (vuelta `i = 0`) |
| 93 | `sw` | 0xFE8 | 0x00000001 | `i = 1` |
| 127 | `sw` | 0xFEC | 0x00000042 | `b = b << 1 = 66` (vuelta `i = 1`) |
| 139 | `sw` | 0xFEC | 0x00000002 | `b = b & 0xF = 2` |
| 153 | `sw` | 0xFE8 | 0x00000002 | `i = 2`, termina el `for` |

Estado final de la memoria de datos (dump):

| Dirección | Valor | Variable |
|---|---|---|
| 0xFE0 | 0x62000000 | `a = 'b'` (byte 0xFE3) |
| 0xFE4 | 0x0000C7DF | `r` |
| 0xFE8 | 0x00000002 | `i` |
| 0xFEC | 0x00000002 | `b` |
| 0xFF8 | 0x00000000 | `s0` guardado |
| 0xFFC | 0x00000000 | `ra` guardado |

El resto de la memoria queda en 0. Los registros al terminar son `sp = 0`, `s0 = 0`, `a4 = 2` y
`a5 = 0`. Estos valores coinciden con lo que calcula el programa en C, así que el procesador ejecuta
correctamente el código del enunciado. La captura de la consola y el dump completo están en
[`resultados/etapa5/`](resultados/etapa5).

## Versión final: `ProyectoRISCV.Final`

`ProyectoRISCV.Final` fue la primera versión preparada para la entrega; la definitiva es
[`ProyectoRISCV.comentado`](#versión-definitiva-proyectoriscvcomentado), que solo reorganiza sus
comentarios. `ProyectoRISCV.Final` se creó directamente en
**Vivado 2019.2** (parte `xc7a35tcpg236-1`) y contiene el procesador completo: los 13 módulos, los
13 testbenches (uno por módulo) y `programa.hex`.

**La lógica del procesador es la misma de `ProyectoRISCV.5`:** ninguna línea de código Verilog
cambió en ningún módulo ni testbench. Los cambios son estos, en orden de importancia:

1. **Comentarios corregidos y completados.** Cada módulo explica su funcionalidad, entradas,
   salidas y por qué existe, y cada testbench su objetivo, estímulos y resultados esperados, como
   pide el enunciado. Correcciones puntuales:

   | Archivo | Corrección |
   |---|---|
   | `riscv_top` | El encabezado menciona el cable que pone en cero el bit 0 del destino de `jalr` y la señal `done` |
   | `mux4` | Se aclara que el `default` solo actúa en simulación, si `sel` vale x/z |
   | `reg_noen` | Se explica por qué A, B, ALUOut y MDR no necesitan habilitación |
   | `instr_mem` | Se corrige la nota sobre el final del programa (el `ret` de `main` salta a la dirección 0) |
   | `tb_riscv_top` | Se aclara que el número de ciclo puede variar en 1 entre simuladores |

   Además, todos los comentarios se escribieron **sin tildes ni caracteres especiales**, para que el
   editor de Vivado los muestre bien.

2. **Un testbench por multiplexor.** El `tb_mux.v` de las etapas anteriores, que probaba los tres
   multiplexores juntos, se separó en `tb_mux2.v`, `tb_mux3.v` y `tb_mux4.v`, para que cada módulo
   tenga su propio archivo de prueba como pide el enunciado. Las pruebas son las mismas: cada valor
   de `sel`, el valor por defecto de `mux3` (sel = 11 entrega d0) y que la salida sigue a la entrada.

3. **Proyecto creado en Vivado 2019.2.** El `.xpr` de `ProyectoRISCV.5` estaba hecho a mano y no
   abría en esta versión; el de `ProyectoRISCV.Final` sí.

4. **Configuración de simulación.** Tiempo de simulación en 3000 ns (`xsim.simulate.runtime`), para
   que `tb_riscv_top` termine sin presionar *Run All*, con Top de diseño `riscv_top` y Top de
   simulación `tb_riscv_top`.

Organización de los archivos dentro de `ProyectoRISCV.Final.srcs`:

```
sources_1/imports/RISCV_sin_tildes/
├── Etapas_1_y_2/design_sources/   reg_en, reg_noen, sumador, mux2, mux3, mux4, alu, imm_gen
├── Etapa3/design_sources/         regfile, instr_mem, data_mem
├── Etapa4/design_sources/         control_unit
└── Etapa5/design_sources/         riscv_top
sim_1/imports/RISCV_sin_tildes/
├── Etapas_1_y_2/simulation_sources/   tb_reg_en, tb_reg_noen, tb_sumador, tb_alu, tb_imm_gen
├── Etapa3/simulation_sources/         tb_regfile, tb_instr_mem, tb_data_mem
├── Etapa4/simulation_sources/         tb_control_unit
└── Etapa5/simulation_sources/         tb_riscv_top
sim_1/imports/simulation_sources/        tb_mux2, tb_mux3, tb_mux4 y programa.hex
```

Resultado en Vivado 2019.2: los 13 testbenches terminan en `TODAS LAS PRUEBAS PASARON` y
`tb_riscv_top` en `EL PROGRAMA CORRIO CORRECTAMENTE`, con 191 ciclos y 47 instrucciones. El dump
generado por esta versión está en [`resultados/final/dump_memoria_datos.txt`](resultados/final) y
coincide con el resultado del programa en C:

| Variable en C | Valor en C | Dirección | Valor en el dump |
|---|---|---|---|
| `a` | `'b'` (0x62) | 0xFE3 (palabra 0xFE0) | 0x62000000 |
| `r` | 0xC7DF | 0xFE4 | 0x0000C7DF |
| `i` | 2 | 0xFE8 | 0x00000002 |
| `b` | 2 | 0xFEC | 0x00000002 |

## Versión definitiva: `ProyectoRISCV.comentado`

`ProyectoRISCV.comentado` es el proyecto definitivo para la entrega. Tiene los mismos 13 módulos,
13 testbenches y `programa.hex` que `ProyectoRISCV.Final`, con la misma organización de carpetas y
la misma configuración de Vivado 2019.2 (Top `riscv_top`, simulación `tb_riscv_top`, 3000 ns).

**El código Verilog es exactamente el mismo de `ProyectoRISCV.Final`:** lo único que cambió son los
comentarios, que ahora están repartidos por secciones junto al código que explican, en lugar de
estar casi todos en el encabezado. Así es más fácil explicar qué hace cada parte:

- **Encabezado corto:** qué hace el archivo y por qué existe.
- **Puertos:** cada entrada y salida tiene al lado qué es y de dónde viene.
- **Bloques:** antes de cada `always`, cada `assign` importante, cada tarea y cada grupo de pruebas
  hay un comentario que dice qué hace.
- **Líneas que no son obvias:** llevan su propio comentario (el `default` de los multiplexores, el
  `+: 8` del `sb`, el `$signed` de `lt`, la escritura ignorada en x0, cada estado y opcode de la
  unidad de control).
- **Testbenches:** cada estímulo está numerado en el orden en que se aplica y tiene al lado el
  resultado que se espera.

Los comentarios siguen sin tildes. Resultado en Vivado 2019.2: igual que `ProyectoRISCV.Final`, los
13 testbenches pasan y `tb_riscv_top` termina en `EL PROGRAMA CORRIO CORRECTAMENTE` con 191 ciclos y
47 instrucciones. El dump generado por esta versión está en
[`resultados/comentado/dump_memoria_datos.txt`](resultados/comentado) y es idéntico al de
`ProyectoRISCV.Final`.

## Cómo abrir y simular

1. Abrir `ProyectoRISCV.comentado/ProyectoRISCV.comentado.xpr` con Vivado 2019.2 (parte `xc7a35tcpg236-1`).
   Para ver un avance intermedio, abrir el `.xpr` de la carpeta `ProyectoRISCV.N` de esa etapa.
2. En **Simulation Sources**, clic derecho sobre el testbench → **Set as Top**.
3. **Run Simulation → Run Behavioral Simulation**.
4. En la consola Tcl debe aparecer `TODAS LAS PRUEBAS PASARON` (o `EL PROGRAMA CORRIO CORRECTAMENTE`
   en `tb_riscv_top`). El dump queda en `ProyectoRISCV.comentado.sim/sim_1/behav/xsim/dump_memoria_datos.txt`.
5. Cerrar la simulación antes de cambiar el Top y correr el siguiente testbench.

## Diagramas

Las iteraciones del diagrama están en [`docs/diagramas/`](docs/diagramas/README.md), cada una con
su explicación. La primera iteración es una ruta de datos de un solo ciclo para los tipos I y S;
la segunda es el diseño multiciclo, que ejecuta los cinco formatos y es el que se implementó en
Verilog. La tercera iteración, `iteracion3_final.png`, es el diagrama final de la entrega: la misma
ruta de datos de la segunda con la leyenda del reloj corregida.

Sobre el diagrama final hay además un diagrama por decodificación (tipos I aritmética, I carga,
I salto, S, B, U y J) con el camino que usa cada formato resaltado, en
[`docs/diagramas/por_decodificacion/`](docs/diagramas/por_decodificacion).

## Estructura del repositorio

```
docs/diagramas/                             iteraciones del diagrama
ProyectoRISCV.1/                            etapa 1: módulos básicos
├── ProyectoRISCV.1.xpr                     proyecto de Vivado
└── ProyectoRISCV.1.srcs/
    ├── sources_1/imports/Desktop/          módulos de diseño (.v)
    └── sim_1/imports/Desktop/              testbenches (.v)
ProyectoRISCV.2/                            etapa 2: etapa 1 + ALU y generador de inmediatos
├── ProyectoRISCV.2.xpr
└── ProyectoRISCV.2.srcs/
    ├── sources_1/imports/Desktop/
    └── sim_1/imports/Desktop/
ProyectoRISCV.3/                            etapa 3: etapas 1 y 2 + banco de registros y memorias
├── ProyectoRISCV.3.xpr
└── ProyectoRISCV.3.srcs/
    ├── sources_1/imports/Desktop/
    └── sim_1/imports/Desktop/              testbenches y programa.hex
ProyectoRISCV.4/                            etapa 4: etapas 1 a 3 + unidad de control
├── ProyectoRISCV.4.xpr
└── ProyectoRISCV.4.srcs/
    ├── sources_1/imports/Desktop/
    └── sim_1/imports/Desktop/
ProyectoRISCV.5/                            etapa 5: procesador completo
├── ProyectoRISCV.5.xpr
└── ProyectoRISCV.5.srcs/
    ├── sources_1/imports/Desktop/          13 módulos, Top = riscv_top
    └── sim_1/imports/Desktop/              11 testbenches y programa.hex
resultados/
├── etapa3/                                 capturas de la consola de Vivado y dump de tb_data_mem
├── etapa4/                                 captura de la consola de Vivado de tb_control_unit
├── etapa5/                                 captura de tb_riscv_top y dump_memoria_datos.txt
├── final/                                  dump_memoria_datos.txt de ProyectoRISCV.Final
└── comentado/                              dump_memoria_datos.txt de ProyectoRISCV.comentado
ProyectoRISCV.Final/                        primera versión para la entrega (Vivado 2019.2)
├── ProyectoRISCV.Final.xpr                 Top: riscv_top; simulación: tb_riscv_top
└── ProyectoRISCV.Final.srcs/               13 módulos, 13 testbenches y programa.hex
ProyectoRISCV.comentado/                    versión definitiva: mismo código, comentarios por secciones
├── ProyectoRISCV.comentado.xpr
└── ProyectoRISCV.comentado.srcs/           13 módulos, 13 testbenches y programa.hex
```

Cada carpeta `ProyectoRISCV.N` es el proyecto completo hasta la etapa N, así se puede abrir y
simular cada avance por separado.

Las carpetas que Vivado genera al simular (`.cache`, `.sim`, `.hw`, `.ip_user_files`, logs) no se
guardan en el repositorio; Vivado las vuelve a crear.
