# Autolavado en Modelica

Modelo hidr?ulico y t?rmico de un autolavado con calentador externo HACEB, hidrolavadora TRENT, inyector downstream y selecci?n de boquillas de alta y baja presi?n.

## Circuito actual

```text
Agua a 13 ?C ? HACEB ? TRENT ? acumulador y alivio ? Venturi
             ? manguera de 8 m ? pistola ? boquilla ? ambiente

Tanque con respiradero ? sif?n ? electrov?lvula NC ? check ? aguja
                     ? manifold com?n ? antirretorno del inyector
```

Hay tres ramas qu?micas independientes: prelavado, jab?n y cera. Las mangueras de sif?n tienen 12,7 mm de di?metro interior; las electrov?lvulas son normalmente cerradas, con alimentaci?n prevista de 12 VDC. El modelo supone selecci?n exclusiva de un producto y purga de 2 s con agua circulando antes de abrir su electrov?lvula.

| Elemento | Configuraci?n del modelo |
|---|---|
| Agua de entrada | 13 ?C; frontera a 101325 Pa absolutos |
| Calentador | HACEB de paso a gas natural, 8 L/min declarados; ajuste manual al m?ximo |
| Potencia de calentamiento | 12 kW interpretados como entrada de gas; eficiencia supuesta 0,85 |
| Hidrolavadora | TRENT HLT395-1800 equivalente: 1800 W, l?mite de 7 L/min y 130 bar declarados |
| Inyector de referencia | General Pump 100819; equivalente hidr?ulico pendiente de calibraci?n |
| Enjuague | Boquilla de alta presi?n de 1,15 mm |
| Prelavado, jab?n y cera | Boquilla de baja presi?n de 4,6 mm; di?metro provisional de dise?o |
| Coeficiente de descarga | Cd = 0,8 supuesto para ambas boquillas |
| Manguera de alta presi?n | 8 m; di?metro interior supuesto de 8 mm |
| Sifones | 2 m y elevaci?n inicial de 0,5 m supuestas; di?metro interior de 12,7 mm |

La selecci?n ideal de boquilla por programa representa que el operador coloca la boquilla correspondiente. El gatillo abre o cierra la pistola independientemente. La boquilla de baja se selecciona durante la purga previa; la aspiraci?n resulta de las presiones y resistencias, sin imponer un caudal qu?mico.

El calentador usa `gasSetting=1` y `automaticTemperatureControl=false`. Sus temperaturas resultan del caudal, la inercia t?rmica y el balance de energ?a. La bomba tiene una curva equivalente con l?mites de caudal y potencia; los 130 bar y 7 L/min no se imponen simult?neamente.

## Resultados de la ejecuci?n actual

Ciclo `autolavado.SelfServiceCarWashTest`, de 0 a 64 s, Modelica 4.1.0, DASSL y tolerancia 1e-6.

| Etapa | Instante | Boquilla | Aspiraci?n qu?mica | Presi?n de garganta |
|---|---:|---:|---:|---:|
| Prelavado | 18 s | 4,6 mm | 0,1369 L/min | ?0,3040 bar(g) |
| Jab?n | 33 s | 4,6 mm | 0,1369 L/min | ?0,3040 bar(g) |
| Cera | 48 s | 4,6 mm | 0,0738 L/min | ?0,3293 bar(g) |

En enjuague no hay aspiraci?n qu?mica. La validaci?n comprueba conservaci?n de masa y energ?a, selecci?n de boquilla, exclusividad de electrov?lvulas, aspiraci?n en las tres etapas y ausencia de descarga con la pistola cerrada. El registro con la identidad del modelo est? en [current-validation.json](verification/results/current-validation.json).

Estos valores son resultados de simulaci?n. El di?metro de baja, Cd, curva de bomba y coeficientes hidr?ulicos del Venturi y las v?lvulas son supuestos ajustables; no constituyen curvas comerciales calibradas ni dosis garantizadas del equipo f?sico. El l?mite de presi?n de garganta puede actuar durante cambios de boquilla: esos transitorios requieren un modelo adicional para estudiar cavitaci?n o golpe de ariete.

## Abrir y ejecutar

1. Instalar OpenModelica con Modelica 4.1.0 y Python 3.
2. Abrir `autolavado.mo` en OMEdit.
3. Seleccionar `autolavado.SelfServiceCarWashTest` y simular.
4. Abrir `plant` para inspeccionar el circuito y sus equipos.

Para ejecutar simulaci?n, validaci?n y generaci?n del Excel desde PowerShell, en la ra?z del proyecto:

```powershell
py -3 -m pip install -r requirements.txt
powershell -NoProfile -ExecutionPolicy Bypass -File verification/run_current.ps1
```

El script busca `omc` en PATH o en una instalaci?n de OpenModelica bajo Program Files. Si hace falta, especificar ejecutables:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File verification/run_current.ps1 -Compiler 'C:\ruta\OpenModelica\bin\omc.exe' -Python 'C:\ruta\python.exe'
```

El comando se detiene si falla la simulaci?n, si no hay un CSV nuevo, si falla la validaci?n o si no se genera el Excel. Los archivos de compilaci?n y resultados brutos quedan en `verification/current/`, excluido de Git. El informe de validaci?n actual s? se versiona.

## Archivos principales

| Archivo | Contenido |
|---|---|
| [autolavado.mo](autolavado.mo) | Componentes, control y experimentos Modelica |
| [CALENTADOR.md](CALENTADOR.md) | Balance t?rmico, ajuste manual y par?metros HACEB |
| [INYECCION.md](INYECCION.md) | Circuito qu?mico, presiones y referencia downstream |
| [Memoria original](Memoria_Calculo_Hidraulica_Autolavado.xlsx) | Datos y plantilla de c?lculo suministrada |
| [Informe Modelica](Memoria_Calculo_Hidraulica_Modelica.xlsx) | Resultados por equipo, sin comparaciones ni f?rmulas de Excel |
| [current_memory.mos](verification/current_memory.mos) | Simulaci?n del ciclo actual |
| [validate_current.py](verification/validate_current.py) | Comprobaciones de la configuraci?n actual |
| [report_current.py](verification/report_current.py) | Generador del Excel con estilos compatibles |
| [run_current.ps1](verification/run_current.ps1) | Ejecuci?n completa desde PowerShell |

El Excel distingue resultados simulados y par?metros. La hoja del calentador incluye el final del ciclo a 64 s, con agua retenida y caudal nulo, y el valor a 55 s antes del cierre con agua circulando. Si Excel tiene abierto el informe, se guarda una copia con sufijo `_nuevo`.

Los scripts `injection.mos`, `haceb.mos`, `verify.ps1` y sus validadores se conservan como herramientas anteriores; sus expectativas y reportes hist?ricos no validan autom?ticamente la configuraci?n de dos boquillas. El punto de entrada actual es `run_current.ps1`.

## Variables para inspeccionar

- `plant.gun.activeNozzleDiameter`: di?metro de boquilla seleccionado.
- `plant.waterFlow_L_min`, `plant.outletFlow_L_min`: caudales de agua y descarga.
- `plant.injector.mChemical`: flujo m?sico aspirado por el inyector, en kg/s.
- `plant.productFlow_L_min`: entrega de cada rama al manifold.
- `plant.throatPressure`, `plant.chemicalManifoldPressure`: presiones absolutas del sistema qu?mico.
- `plant.chemicalInjectionBlocked`: electrov?lvula abierta sin diferencial disponible para aspirar.
- `plant.inletHeater.T`, `plant.outletTemperature`: temperaturas, en K.
- `plant.pumpPressure_bar`: presi?n manom?trica de descarga de bomba.

El medio es agua de propiedades constantes, tambi?n en las ramas qu?micas. Las formulaciones reales, compatibilidad de materiales, resistencia mec?nica de componentes y comportamiento t?rmico de la hidrolavadora deben confirmarse con sus datos f?sicos. No se modelan espuma, combusti?n detallada ni pulsaciones de pistones.
