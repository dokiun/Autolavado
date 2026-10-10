# Inyeccion Venturi y presiones para seleccionar valvulas

## Referencia downstream vigente

Referencia comercial: [General Pump 100819](https://www.generalpump.com/product/100819/).
Rango publicado: 1-2 US GPM (3,785-7,571 L/min); orificio del inyector 1,5 mm;
entrada/salida 3/8 NPT macho; conexion quimica 1/4 de pulgada; rating de la pagina
actual 4250 psi. El rating del cuerpo no es contrapresion admisible para aspirar.
Boquillas de descarga: 1,15 mm para enjuague a alta presion y 4,6 mm para aplicar
prelavado, jabon y cera a baja presion. Los 4,6 mm y Cd=0,8 son supuestos de diseno.
La seleccion por programa representa el cambio de boquilla por el operador, no un
actuador automatico de la pistola. La boquilla de baja se selecciona durante la purga
de 2 s antes de abrir la electrovalvula. El gatillo conserva el cierre independiente.

El [manual del fabricante](https://www.generalpump.com/product/100819/?attachment_id=5240&download_file=3a213336bdea70fa57b841ef6b5c0d5d)
requiere reducir la presion en la boquilla para activar aspiracion. La ficha no aporta
curvas de perdida, recuperacion de presion ni dosificacion para calibrar el equivalente.
`dpLossNominal`, `recoveryNominal` y resistencias quimicas siguen siendo supuestos;
no son datos del 100819. La aspiracion se calcula por el diferencial y las resistencias;
el modelo usa la boquilla de baja para reducir contrapresion, sin imponer caudal quimico.

`plant.chemicalInjectionBlocked` identifica electrovalvula abierta y agua circulando,
pero sin diferencial para aspirar. No altera ni fuerza el caudal quimico.
Los resultados numericos y pruebas descritos mas abajo son historicos: corresponden
a la configuracion anterior con cambio de apertura de boquilla. Los resultados del
circuito actual estan en `verification/current/CurrentCycle_res.csv` y el Excel por equipo.

## Circuito implementado

Cada rama tiene componentes independientes en el orden solicitado:

```text
Tanque de quimico â†’ manguera de sifon â†’ NC 12 VDC â†’ check â†’ aguja manual â†’ manifold
                                                                            â†“
                                                          check HP del inyector â†’ garganta Venturi
```

Hay dos antirretornos con funciones distintas: el check del inyector separa el manifold de la garganta presurizada; el check de cada rama, despues de la NC, bloquea retorno hacia esa electrovÃ¡lvula/tanque. La aguja no es una barrera contra alta presion. El check HP se conserva del modelo anterior y debe existir fisicamente para que el aislamiento previsto corresponda a la instalacion.

`ChemicalBranch` contiene `tank`, `siphon`, `solenoid`, `beforeCheck`, `checkValve`, `afterCheck` y `needle`. Los pequenos volumenes antes/despues del check representan elasticidad e inventario de conexiones: permiten calcular presiones atrapadas cuando dos cierres estan en serie, sin asignarlas arbitrariamente. La manguera se considera llena y cebada: no se simula el llenado inicial ni entrada de aire.

## Como funciona el modelo del Venturi

`DownstreamInjector` conserva masa: caudal de mezcla = agua + quimico. La perdida de presion principal y la recuperacion desde garganta son coeficientes independientes, ambos supuestos de 1,8 bar a 7 L/min de agua en la configuracion actual:

```text
p_entrada - p_salida â‰ˆ 1,8 bar Ã— (Q_agua / 7 L/min)^2
p_garganta = p_salida - 1,8 bar Ã— (Q_agua / 7 L/min)^2
```

La boquilla y la manguera de descarga determinan `p_salida`. En alta presion, la garganta sigue a alta presion y no puede aspirar un tanque cercano a la atmosfera. Con boquilla LP, la contrapresion cae y la garganta puede quedar por debajo de la presion del quimico. El check HP solo deja pasar quimico cuando `p_manifold > p_garganta + pCrack`. La dosis surge de ese diferencial y de las perdidas en sifon, NC, check y aguja; no se impone un caudal quimico constante.

El modelo no deriva los coeficientes de geometria real de un Venturi: requiere curvas o ensayos de aspiracion frente a caudal y contrapresion. No modela cavitacion; el limite de garganta a 20 kPa absolutos es un limite de dominio y `throatLimited` debe permanecer falso para interpretar estas pruebas. Tampoco predice golpe de ariete ni fuga real de los checks.

## Datos confirmados y supuestos

Confirmado por el usuario: manguera de sifon de **12,7 mm de diametro interior**, electrovalvulas **NC a 12 VDC**, productos prelavado, jabon y cera. Los materiales PP del tanque y las juntas de valvula requieren verificar compatibilidad con la formulacion real; esos nombres genericos no permiten elegir un elastomero.

Supuestos ajustables: longitud de sifon 2 m; altura de NC/manifold 0,5 m sobre nivel inicial; tanque con 10 L de liquido, seccion 0,03 m2; presion atmosferica 101325 Pa; agua equivalente en todas las ramas; resistencia de NC 4 kPa a 0,20 L/min, aguja 42 kPa, apertura de check 1 kPa mas perdida nominal de 1 kPa. La rama de cera usa 0,10 L/min nominal. No son curvas de componentes comerciales. Los caudales nominales definen resistencias, no dosis garantizadas.

La longitud, altura real, nivel del tanque, viscosidad y presion atmosferica local pueden cambiar los resultados. La altura positiva resta aproximadamente 0,098 bar por metro de elevacion. La dimension de conexion de 1/2 pulgada no equivale al diametro del orificio de la electrovÃ¡lvula; puede emplearse una conexion adaptada si su Kv y compatibilidad son adecuados.

## Tanques con tapa y respiradero

El unico modelo disponible es tanque cerrado con tapa y **respiradero apropiado para el producto**. El aire permanece a la presion atmosferica configurada; el respiradero se representa idealmente, sin perdida de presion ni obstruccion. Al extraer producto disminuyen el volumen y el nivel del liquido, conservando el balance de masa y la carga hidrostatica. El tanque no debe quedar sin liquido. No se representan evaporacion, deformacion del recipiente ni diseño fisico del respiradero.

## Seleccion de componentes

La NC esta en aspiracion y necesita accion directa (o una tecnologia que garantice operacion sin diferencial minimo), servicio de liquido y aptitud declarada para vacio. Confirmar presion minima absoluta admisible, diferencial minimo de apertura, diferencial inverso permitido con la valvula cerrada, estanqueidad, Kv, materiales y bobina continua de 12 VDC. Una especificacion de 0-10 bar de sobrepresion no confirma por si sola servicio de vacio ni cierre con contrapresion.

La perdida supuesta de NC a 0,20 L/min implica un Kv equivalente de aproximadamente 0,060 m3/h: `Kv = 0,012 m3/h / sqrt(0,04 bar)`, para agua. Es un parametro del modelo, no un requisito universal de compra. Cambiar el Kv cambia la dosis; una aguja debera ajustarse con medidas reales.

La alta presion principal sigue siendo relevante: el cuerpo del inyector y el check HP deben soportar la maxima presion del circuito (130 bar declarados para la TRENT, mas los transitorios y requisitos que determine el fabricante). Si falla el check HP, manifold, aguja, manguera comun y lado aguas abajo de los checks de rama pueden quedar expuestos a alta presion. Un check de rama sano puede proteger la NC, pero entonces debe estar clasificado para ese diferencial inverso. Si tambien falla, la alta presion alcanza la salida de la NC. La presion normal baja no basta para certificar la instalacion o comprar valvulas de baja presion sin definir estas barreras.

El ensayo `ChemicalProtectionTest` impone 130 bar manometricos al manifold como escenario de perdida del aislamiento del inyector; no simula la averia interna del inyector ni prueba la resistencia mecanica. Compara un check de rama sano con uno trabado abierto y deja la NC cerrada. Su cierre es ideal: que la simulacion no tenga fuga no certifica el cierre real a contrapresion.

## Pruebas y variables

La configuracion vigente completo cuatro simulaciones y 38 comprobaciones, cero fallidas; el informe esta en verification/results/injection-validation.json. Ejemplo a los 33 s (jabon activo), en bar manometricos: entrada del Venturi 3,311; salida 1,511; garganta -0,289; manifold -0,265; entrada de NC -0,049; salida de NC -0,066. El diferencial de NC abierta es 0,0175 bar. El enjuague inicial a los 9 s tiene entrada 99,857; salida 98,057; garganta 96,257 y manifold 0 bar, con NC cerradas. Tras una dosificacion, el lado quimico puede conservar vacio al volver a HP.

En toda la secuencia, la entrada de NC ronda -0,049 bar; su salida va de -0,290 a 0 bar y su diferencial de -0,049 a +0,241 bar. Las NC cerradas pueden tener diferencial inverso pequeno o vacio atrapado; no debe asignarse su salida igual al manifold en todos los estados. La garganta con pistola cerrada a los 58 s conserva aproximadamente 117 bar y el manifold queda cerca de -0,295 bar gracias al check HP ideal. El cuerpo y el asiento HP no trabajan a baja presion por el hecho de que el manifold este en vacio.

Al final de 120 s de jabon continuo, el tanque con respiradero entrega aproximadamente 0,1321 L/min. En el banco de manifold presurizado a 130 bar, un check de rama sano mantiene la salida de NC en -0,403 bar; con ese check fallado abierto, la salida de NC alcanza 130 bar y el diferencial inverso alcanza aproximadamente 130,05 bar. Es un escenario de prueba con presion impuesta, no una prediccion de fuga o rotura real.

Las curvas estan en [verification/results/injection-pressure.png](verification/results/injection-pressure.png). Regenerar con `python verification/plot_injection.py`.

Ejecutar `verification/verify.ps1 -Script verification/injection.mos`. Los resultados actuales estan en `verification/results/injection-validation.json` con hash del codigo, envolventes y muestras de presion, tanques con respiradero y escenarios de check. Los informes HACEB anteriores corresponden al circuito quimico anterior.

Variables por rama, con prefijo `plant.prewash.`, `plant.soap.` o `plant.wax.`: `valveInletPressure`, `valveOutletPressure`, `valveDifferentialPressure`, `checkReversePressure`, `tank.gasPressure`, `tank.liquidVolume`, `tankDraw`, `checkValve.m_flow` y `needle.m_flow`. `m_flow` es entrega al manifold; `tankDraw` es extraccion del tanque y pueden diferir transitoriamente por inventario intermedio. La liberacion de liquido retenido aguas abajo de una NC cerrada no implica que esa NC este abierta. Los trazadores quimicos son equivalentes de mezcla y no validan pureza o composicion real de esos inventarios.

Las presiones de puerto estan en Pa absolutos. Para comparar con un manometro: `(p - plant.pAtmosphere)/1e5` da bar manometricos. Un resultado negativo indica vacio relativo. El diferencial de NC es `(p_entrada-p_salida)/1e5`: su signo informa si existe contrapresion.

Fuentes tecnicas: [Cat Pumps: funcionamiento del inyector y check en alta/baja presion](https://www.catpumps.com/pressure-washer-faqs), [BÃ¼rkert: accion directa frente a pilotaje](https://www.burkert.com/en/products/solenoid-valves), [BÃ¼rkert 6013: las tablas de presion se expresan como sobrepresion respecto a atmosfera](https://www.burkert.com/en/Media/plm/DTS/DS/ds6013-standard-eu-en.pdf?id=DTS0000000000000001000011032ENAN).



