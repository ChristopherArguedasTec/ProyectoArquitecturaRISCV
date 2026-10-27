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

1. **Módulos básicos:** registros, sumador y multiplexores. *(este commit)*
2. ALU y generador de inmediatos.
3. Banco de registros, memoria de instrucciones y memoria de datos.
4. Unidad de control (máquina de estados).
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

## Cómo abrir y simular

1. Abrir `ProyectoRISCV.1/ProyectoRISCV.1.xpr` con Vivado 2019 (parte `xc7a35tcpg236-1`).
2. En **Simulation Sources**, clic derecho sobre el testbench → **Set as Top**.
3. **Run Simulation → Run Behavioral Simulation**.
4. En la consola Tcl debe aparecer `TODAS LAS PRUEBAS PASARON`.

## Estructura del repositorio

```
ProyectoRISCV.1/
├── ProyectoRISCV.1.xpr                     proyecto de Vivado
└── ProyectoRISCV.1.srcs/
    ├── sources_1/imports/Desktop/          módulos de diseño (.v)
    └── sim_1/imports/Desktop/              testbenches (.v)
```

Las carpetas que Vivado genera al simular (`.cache`, `.sim`, `.hw`, `.ip_user_files`, logs) no se
guardan en el repositorio; Vivado las vuelve a crear.
