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
5. Módulo superior `riscv_top` y simulación del programa completo con el dump de memoria.

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

## Cómo abrir y simular

1. Abrir el `.xpr` de la etapa con Vivado 2019 (parte `xc7a35tcpg236-1`). La carpeta más reciente
   (`ProyectoRISCV.4/ProyectoRISCV.4.xpr`) incluye todos los módulos hasta esa etapa.
2. En **Simulation Sources**, clic derecho sobre el testbench → **Set as Top**.
3. **Run Simulation → Run Behavioral Simulation**.
4. En la consola Tcl debe aparecer `TODAS LAS PRUEBAS PASARON`.
5. Cerrar la simulación antes de cambiar el Top y correr el siguiente testbench.

## Diagramas

Las iteraciones del diagrama están en [`docs/diagramas/`](docs/diagramas/README.md), cada una con
su explicación. La primera iteración es una ruta de datos de un solo ciclo para los tipos I y S;
sus limitaciones se corrigen en el diseño multiciclo.

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
resultados/
├── etapa3/                                 capturas de la consola de Vivado y dump de tb_data_mem
└── etapa4/                                 captura de la consola de Vivado de tb_control_unit
```

Cada carpeta `ProyectoRISCV.N` es el proyecto completo hasta la etapa N, así se puede abrir y
simular cada avance por separado.

Las carpetas que Vivado genera al simular (`.cache`, `.sim`, `.hw`, `.ip_user_files`, logs) no se
guardan en el repositorio; Vivado las vuelve a crear.
