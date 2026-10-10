# Calentador HACEB de paso, gas natural

`autolavado.HacebGasHeater` es un sistema independiente con dos puertos de agua. En la planta se instancia como `plant.inletHeater`, antes de la hidrolavadora TRENT. El acumulador de alta presion no aporta calor. `enableHeating=true` habilita el gas por defecto; `enableHeating=false` deshabilita el gas, pero conserva el paso de agua y su perdida hidraulica; no representa un bypass fisico. `HeatingTest` habilita el equipo. `GasHeaterTest` permite ensayarlo sin la hidrolavadora.

## Datos e incertidumbres

Datos de la descripcion suministrada: gas natural, tiro natural, capacidad declarada de 8 L/min, potencia de 12 kW, control a 3 VDC, encendido al circular agua y protecciones de llama, ventilacion y temperatura. Dimensiones 49 x 30,5 x 18 cm y masa total 6,6 kg no determinan la capacidad termica del intercambiador. No se ha identificado referencia exacta ni placa: el catalogo oficial actual muestra un equipo de 7 L/min y 12 kW, lo que no permite atribuir su manual a este equipo usado.

Los 8 L/min NO son volumen almacenado, limite rigido de caudal ni una garantia de temperatura: falta el salto termico con el que se declara esa capacidad. Los 12 kW se interpretan por defecto como potencia de entrada de gas y se aplica eficiencia supuesta 0,85 (10,2 kW al intercambiador). `ratingIsUsefulPower=true` permite representar 12 kW utiles si la placa lo confirma. Los 3 VDC alimentan el encendido/control; no se convierten en potencia termica.

Parametros SUPUESTOS y calibrables: eficiencia 0,85; agua interna 0,3 L; capacidad termica metalica 1500 J/K; conductancia metal-agua 800 W/K; perdidas al ambiente 2 W/K; caida de presion 20 kPa a 8 L/min; encendido por encima de 2 L/min y apagado por debajo de 1,5 L/min; comprobacion de llama 1 s; temperatura de corte 60 C; PCI del gas 50 MJ/kg. Estos valores no son especificaciones confirmadas de HACEB. Tampoco se conocen presiones de suministro requeridas, modulacion minima, retrasos reales de sensores ni procedimiento de rearme.

## Balances y regulacion

El caudal lo determina el circuito. Se conserva masa exactamente y se usa una perdida de presion cuadratica regularizada y bidireccional. El gas se habilita solo para flujo directo suficiente. El agua y el metal tienen temperaturas independientes y almacenan energia. El gas aporta calor al metal, este intercambia con el agua y pierde calor al ambiente. Tras apagar el gas puede seguir transfiriendo calor residual: el corte no impone artificialmente una temperatura constante.

Por defecto `automaticTemperatureControl=false`: `gasSetting=1` representa la perilla manual al 100 % de potencia. La entrada y el estado inicial del agua se configuran a 13 C (286,15 K). El display se representa por `T`, temperatura del agua interna/salida en flujo directo. No se fuerza a 40 C: `Tset` se usa solamente si se habilita el control automatico opcional. Ese control usa anticipacion por caudal mas correccion proporcional, limitado por la potencia disponible; no se atribuye al equipo real sin confirmar modulacion.

Variables: `Q`, `inletTemperature`, `T`, `metalTemperature`, `gasPower` (potencia quimica consumida), `gasMassFlow` (gas equivalente segun PCI), `heaterPower` (calor util de combustion al metal), `heatToWater`, `ambientLoss`, `energyResidual`, `gasValveOpen`, `burnerLit` y `safetyLocked`. `plant.heatingPower` referencia ahora `heaterPower`, no consumo electrico ni calor instantaneo entregado al agua.

## Protecciones y limites de representacion

Fallos de ventilacion, temperatura o falta de llama tras el tiempo de encendido enclavan la seguridad y requieren `resetSafety`; un fallo activo prevalece sobre el rearme. Estas politicas de rearme son supuestos explicitos.

`ventilationOK`, `flameDetected`, `gasAvailable` y `controlPowerOK` son entradas booleanas externas. El modelo representa la respuesta a esos sensores, no calcula oxigeno, combustion, tiro, obstruccion del ducto, presion de gas o circuitos a 3 VDC. En el estado sano por defecto esas entradas son verdaderas. Durante el intervalo de encendido puede existir gas sin aporte termico; tras fallo comprobado se cierra la valvula. La inercia puede producir sobrepaso termico despues de un corte.

La fuente atmosferica original se conserva: con la perdida del calentador puede aparecer aspiracion a presion subatmosferica en la bomba. Esta hipotesis no confirma que el equipo real encienda o funcione con esa alimentacion; se debe parametrizar la presion real y comprobar la curva de suministro. La hidrolavadora conserva su comprobacion de entrada hasta 50 C, pero la ficha dice tambien no apta para agua caliente: el modelo no resuelve esa compatibilidad de hardware.

## Verificacion

Ejecutar `powershell -NoProfile -ExecutionPolicy Bypass -File verification/verify.ps1 -Script verification/haceb.mos`. Se ensayan planta y banco a plena potencia manual, fallo de llama, fallo de ventilacion, sobretemperatura, caudal insuficiente y saturacion de potencia. Los resultados usan prefijos `Haceb*`, con criterios e informe separados en `verification/results/haceb-validation.json`.

Las pruebas del calentador se ejecutan con el verificador y generan su informe en verification/results/haceb-validation.json. El reporte vigente de la planta completa es verification/results/injection-validation.json. Se conserva la inercia termica y el calor residual al apagar el gas.

Referencia consultada: [HACEB, calentador de paso tiro natural 7 L/min y 12 kW](https://www.haceb.com/calentador-de-agua-haceb-de-paso-a-gas-natural-tiro-natural-7-litros-blanco-7704353394979/p). No se han trasladado sus umbrales o prestaciones al equipo de 8 L/min suministrado por el usuario.




