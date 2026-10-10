package autolavado "Autolavado self-service: agua equivalente, aspiracion y descarga"
  extends Modelica.Icons.Package;
  import SI = Modelica.Units.SI;
  package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater;
  constant SI.Density rho = Medium.d_const;
  constant SI.SpecificHeatCapacity cp = Medium.cp_const;
  constant Real PaPerPsi(unit = "Pa") = 6894.757293168;
  type VolumeFlowRate_L_min = Real(final quantity = "VolumeFlowRate", final unit = "l/min");

  function toLMin "Conversion SI a litros por minuto"
    input SI.VolumeFlowRate q;
    output VolumeFlowRate_L_min y;
  algorithm
    y := q*60000;
    annotation(
      Inline = true);
  end toLMin;

  function toPsi "Conversion de pascales a psi"
    input SI.Pressure p;
    output Real y(unit = "psi");
  algorithm
    y := p/6894.757293168;
    annotation(
      Inline = true);
  end toPsi;

  function positiveRoot "Raiz unilateral C1: exactamente cero para x <= 0"
    input Real x;
    input Real delta(min = Modelica.Constants.small) = 0.001;
    output Real y;
  algorithm
    y := if x <= 0 then 0 else if x < delta then sqrt(delta)*(2.5*(x/delta)^2 - 1.5*(x/delta)^3) else sqrt(x);
    annotation(
      smoothOrder = 1,
      Documentation(info = "<html><p>Argumentos adimensionales. Regularizacion polinomica C1 de sqrt(max(x,0)); no crea caudal inverso ni fuga bajo el umbral.</p></html>"));
  end positiveRoot;

  partial model TwoPort "Conectores MSL, masa conservada y transporte de entalpia"
    Modelica.Fluid.Interfaces.FluidPort_a port_a(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Fluid.Interfaces.FluidPort_b port_b(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    SI.MassFlowRate m_flow(start = 0, nominal = 0.1) = port_a.m_flow;
    SI.PressureDifference dp = port_a.p - port_b.p;
  equation
    port_a.m_flow + port_b.m_flow = 0;
    port_b.h_outflow = inStream(port_a.h_outflow);
    port_a.h_outflow = inStream(port_b.h_outflow);
    port_b.Xi_outflow = inStream(port_a.Xi_outflow);
    port_a.Xi_outflow = inStream(port_b.Xi_outflow);
    port_b.C_outflow = inStream(port_a.C_outflow);
    port_a.C_outflow = inStream(port_b.C_outflow);
    annotation(
      Icon(graphics = {Rectangle(extent = {{-90, 50}, {90, -50}}, lineColor = {0, 90, 170}, fillColor = {220, 240, 255}, fillPattern = FillPattern.Solid), Text(extent = {{-100, 90}, {100, 55}}, textString = "%name", textColor = {0, 0, 127})}));
  end TwoPort;

  model PressureWasherPump "Bomba de desplazamiento positivo con deslizamiento: CALIBRAR"
    extends TwoPort;
    parameter SI.PressureDifference pReference = 1500*PaPerPsi "Presion manometrica de referencia";
    parameter SI.VolumeFlowRate QReference = 5.9/60000 "Caudal por bomba a pReference";
    parameter Real slipFraction(min = 0.001, max = 0.5) = 0.08 "CALIBRAR pendiente de Q(dp)";
    parameter Integer nParallel(min = 1) = 1;
    parameter SI.Time motorTime = 0.2;
    parameter SI.Power ratedElectricalPower = 1800 "TRENT HLT395-1800: potencia de placa";
    parameter Real hydraulicEfficiency(min = 0.01, max = 1) = 0.70 "Supuesto, calibrar con curva real";
    parameter SI.VolumeFlowRate maximumFlow = 7/60000 "Caudal declarado; no garantiza 130 bar simultaneos";
    Modelica.Blocks.Interfaces.RealInput runCommand annotation(
      Placement(transformation(origin = {0, 100}, extent = {{-10, -10}, {10, 10}}, rotation = -90)));
    Real speed(start = 0, fixed = true);
    SI.VolumeFlowRate Q;
    SI.Power hydraulicPower;
  equation
    motorTime*der(speed) = noEvent(min(1, max(0, runCommand))) - speed;
    Q = noEvent(min(nParallel*maximumFlow, min(nParallel*QReference*max(0, (1 + slipFraction)*min(1, max(0, speed)) - slipFraction*max(0, -dp)/pReference), nParallel*hydraulicEfficiency*ratedElectricalPower*min(1, max(0, speed))/max(1, -dp))));
    m_flow = rho*Q;
    hydraulicPower = max(0, -dp)*Q;
    annotation(
      Icon(graphics = {Ellipse(extent = {{-60, 60}, {60, -60}}, lineColor = {0, 90, 170}), Polygon(points = {{-20, 35}, {40, 0}, {-20, -35}, {-20, 35}}, fillColor = {0, 90, 170}, fillPattern = FillPattern.Solid)}),
      Documentation(info = "<html><p>Q = nParallel * QReference * max(0, (1+s)*speed - s*DeltaP/pReference). Aproximacion de desplazamiento positivo con fuga interna lineal y antirretorno de salida ideal. No impone simultaneamente presion y caudal. No es curva comercial. Sin pulsaciones, cavitacion ni balance mecanico; Caudal limitado por maximumFlow y potencia hidraulica por hydraulicEfficiency*ratedElectricalPower. Calentamiento por perdidas mecanicas omitido.</p></html>"));
  end PressureWasherPump;

  model CompliantVolume "Volumen elastico, conservacion de masa y mezcla termica"
    parameter Integer nPorts(min = 1) = 3;
    parameter SI.Volume V0 = 0.0005;
    parameter Real compliance(unit = "m3/Pa", min = 1e-14) = 2e-12 "CALIBRAR elasticidad equivalente";
    parameter SI.AbsolutePressure p0 = 101325;
    parameter SI.Temperature T0 = 286.15;
    parameter Boolean enableHeating = false;
    parameter SI.Temperature Tset = 313.15;
    parameter SI.Power Pmax = 3000;
    parameter Real Kp(unit = "W/K") = 600;
    Modelica.Fluid.Interfaces.FluidPorts_b ports[nPorts](redeclare each package Medium = Medium) annotation(
      Placement(transformation(extent = {{-40, -10}, {40, 10}})));
    SI.AbsolutePressure p(start = p0, fixed = true);
    SI.Temperature T(start = T0, fixed = true);
    SI.Volume V;
    SI.Mass mass;
    SI.SpecificEnthalpy h;
    SI.Power heaterPower;
    SI.Power flowHeatingDemand;
    SI.MassFlowRate storageRate;
  equation
    V = V0 + compliance*(p - p0);
    mass = rho*V;
    h = Medium.specificEnthalpy_pTX(p, T, Medium.X_default);
    storageRate = rho*compliance*der(p);
    storageRate = sum(ports.m_flow);
    flowHeatingDemand = sum(noEvent(max(0, ports[j].m_flow))*(Medium.specificEnthalpy_pTX(p, Tset, Medium.X_default) - inStream(ports[j].h_outflow)) for j in 1:nPorts);
    heaterPower = if enableHeating then noEvent(min(Pmax, max(0, flowHeatingDemand + Kp*(Tset - T)))) else 0;
    mass*cp*der(T) = sum(ports[j].m_flow*(actualStream(ports[j].h_outflow) - h) for j in 1:nPorts) + heaterPower;
    for j in 1:nPorts loop
      ports[j].p = p;
      ports[j].h_outflow = h;
      ports[j].Xi_outflow = Medium.X_default[1:Medium.nXi];
      ports[j].C_outflow = fill(0, Medium.nC);
    end for;
    assert(V > 0, "Volumen elastico negativo: revisar V0/compliance");
    assert(p > 10000, "Presion fuera del dominio liquido monofasico");
    annotation(
      Icon(graphics = {Ellipse(extent = {{-80, 80}, {80, -80}}, lineColor = {0, 90, 170}, fillColor = {220, 240, 255}, fillPattern = FillPattern.Solid), Text(extent = {{-100, 120}, {100, 85}}, textString = "%name"), Text(extent = {{-60, 50}, {60, 15}}, textString = "V / T")}),
      Documentation(info = "<html><p>Elasticidad mecanica equivalente V=V0+C*(p-p0), con agua de densidad constante. Balance de masa exacto rho*C*der(p)=sum(m_flow). Mezcla termica concentrada; omite trabajo de compresion, disipacion viscosa y perdidas al ambiente. Calentador con anticipacion de demanda de flujo y correccion proporcional, limitado y desactivable. No es un deposito abierto ni un modelo de golpe de ariete.</p></html>"));
  end CompliantVolume;

  model HacebGasHeater "Calentador de paso GN, 8 L/min declarados; parametros no identificados calibrables"
    parameter SI.Power ratedPower = 12000 "Ficha: no especifica si potencia de gas o util";
    parameter Boolean ratingIsUsefulPower = false "Supuesto: 12 kW de entrada de gas";
    parameter Real efficiency(min = 0.01, max = 1) = 0.85 "SUPUESTO de conversion gas-agua";
    parameter SI.VolumeFlowRate ratedFlow = 8/60000 "Capacidad de paso, NO volumen de deposito ni caudal impuesto";
    parameter SI.PressureDifference nominalPressureDrop = 20000 "SUPUESTO; medir curva hidraulica";
    parameter SI.Volume waterVolume = 0.0003 "SUPUESTO inventario interno, no 8 litros";
    parameter SI.HeatCapacity exchangerHeatCapacity = 1500 "SUPUESTO inercia metalica J/K";
    parameter SI.ThermalConductance waterConductance = 800 "SUPUESTO intercambio metal-agua";
    parameter SI.ThermalConductance ambientConductance = 2 "SUPUESTO perdidas a ambiente";
    parameter SI.Temperature ambientTemperature = 293.15;
    parameter SI.Temperature initialTemperature = 286.15;
    parameter SI.Temperature maximumTemperature = 333.15 "SUPUESTO corte 60 C; falta manual exacto";
    parameter SI.VolumeFlowRate ignitionFlow = 2/60000 "SUPUESTO umbral de encendido";
    parameter SI.VolumeFlowRate extinctionFlow = 1.5/60000 "SUPUESTO umbral de apagado, histeresis";
    parameter SI.Time ignitionDelay = 1 "SUPUESTO tiempo de comprobacion de llama";
    parameter Boolean enabled = true;
    parameter Boolean automaticTemperatureControl = false "Ficha indica ajuste; no confirma modulacion automatica";
    parameter Real gasSetting(min = 0, max = 1) = 1 "Perilla manual al maximo";
    parameter SI.Temperature Tset = 313.15 "Solo usado en control automatico opcional";
    parameter Real temperatureGain(unit = "W/K") = 600;
    parameter SI.SpecificEnergy gasLowerHeatingValue = 50e6 "SUPUESTO PCI GN; parametrizable";
    input Boolean ventilationOK = true "Senal externa: oxigeno/evacuacion correctos";
    input Boolean flameDetected = true "Senal externa del sensor, no simulacion de combustion";
    input Boolean gasAvailable = true;
    input Boolean controlPowerOK = true "Disponibilidad alimentacion 3 VDC, sin circuito electrico";
    input Boolean resetSafety = false "Rearme manual equivalente; confirmar procedimiento real";
    Modelica.Fluid.Interfaces.FluidPort_a port_a(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Fluid.Interfaces.FluidPort_b port_b(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    SI.MassFlowRate m_flow;
    SI.VolumeFlowRate Q;
    SI.Temperature T(start = initialTemperature, fixed = true) "Agua interna / display de salida para flujo directo";
    SI.Temperature metalTemperature(start = initialTemperature, fixed = true);
    SI.Temperature inletTemperature;
    SI.Power gasPower;
    SI.Power heaterPower "Potencia util de combustion al metal";
    SI.Power heatToWater;
    SI.Power ambientLoss;
    SI.Power requestedGasPower;
    SI.Power energyResidual;
    SI.MassFlowRate gasMassFlow;
    SI.Time ignitionClock(start = 0, fixed = true);
    discrete Boolean flowing(start = false, fixed = true);
    discrete Boolean safetyLocked(start = false, fixed = true);
    Boolean overTemperature;
    Boolean safetyFault;
    Boolean gasValveOpen;
    Boolean burnerLit;
  equation
    m_flow = port_a.m_flow;
    port_a.m_flow + port_b.m_flow = 0;
    Q = m_flow/rho;
    port_a.p - port_b.p = nominalPressureDrop*(Q/ratedFlow)*sqrt((Q/ratedFlow)^2 + 1e-8);
    inletTemperature = Medium.temperature(Medium.setState_phX(port_a.p, inStream(port_a.h_outflow)));
    port_a.h_outflow = Medium.specificEnthalpy_pTX(port_a.p, T, Medium.X_default);
    port_b.h_outflow = Medium.specificEnthalpy_pTX(port_b.p, T, Medium.X_default);
    port_a.Xi_outflow = inStream(port_b.Xi_outflow);
    port_b.Xi_outflow = inStream(port_a.Xi_outflow);
    port_a.C_outflow = inStream(port_b.C_outflow);
    port_b.C_outflow = inStream(port_a.C_outflow);
    when {initial(), Q > ignitionFlow, Q < extinctionFlow} then
      flowing = Q > ignitionFlow;
    end when;
    overTemperature = T >= maximumTemperature;
    safetyFault = not ventilationOK or overTemperature or (enabled and flowing and gasAvailable and controlPowerOK and ignitionClock >= ignitionDelay and not flameDetected);
    when {safetyFault, resetSafety} then
      safetyLocked = if safetyFault then true else if resetSafety then false else pre(safetyLocked);
    end when;
    gasValveOpen = enabled and flowing and gasAvailable and controlPowerOK and not safetyLocked and ventilationOK and not overTemperature;
    burnerLit = gasValveOpen and flameDetected and ignitionClock >= ignitionDelay;
    der(ignitionClock) = if gasValveOpen then 1 else 0;
    when not gasValveOpen then
      reinit(ignitionClock, 0);
    end when;
    requestedGasPower = if automaticTemperatureControl then noEvent(max(0, (max(0, m_flow)*cp*(Tset - inletTemperature) + temperatureGain*(Tset - T))/efficiency)) else gasSetting*(if ratingIsUsefulPower then ratedPower/efficiency else ratedPower);
    gasPower = if gasValveOpen then noEvent(min(if ratingIsUsefulPower then ratedPower/efficiency else ratedPower, requestedGasPower)) else 0;
    gasMassFlow = gasPower/gasLowerHeatingValue;
    heaterPower = if burnerLit then efficiency*gasPower else 0;
    heatToWater = waterConductance*(metalTemperature - T);
    ambientLoss = ambientConductance*(metalTemperature - ambientTemperature);
    exchangerHeatCapacity*der(metalTemperature) = heaterPower - heatToWater - ambientLoss;
    rho*waterVolume*cp*der(T) = port_a.m_flow*(actualStream(port_a.h_outflow) - port_a.h_outflow) + port_b.m_flow*(actualStream(port_b.h_outflow) - port_b.h_outflow) + heatToWater;
    energyResidual = exchangerHeatCapacity*der(metalTemperature) + rho*waterVolume*cp*der(T) - heaterPower + ambientLoss - port_a.m_flow*(actualStream(port_a.h_outflow) - port_a.h_outflow) - port_b.m_flow*(actualStream(port_b.h_outflow) - port_b.h_outflow);
    assert(ignitionFlow > extinctionFlow and extinctionFlow > 0, "Umbrales de caudal invalidos");
    annotation(
      Icon(graphics = {Rectangle(extent = {{-80, 80}, {80, -80}}, lineColor = {170, 80, 0}, fillColor = {255, 240, 220}, fillPattern = FillPattern.Solid), Text(extent = {{-100, 115}, {100, 85}}, textString = "%name"), Text(extent = {{-75, 50}, {75, 0}}, textString = "HACEB GN"), Text(extent = {{-75, -5}, {75, -50}}, textString = "8 L/min | 12 kW")}),
      Documentation(info = "<html><p>Sistema independiente de paso con perdida hidraulica, inventario de agua e inercia metalica. Ajuste manual de gas por defecto; control automatico opcional no identificado en ficha. Sensores externos representan fallos de llama y ventilacion. Fallos de seguridad requieren resetSafety. Rearme, eficiencia, volumen, inercia, umbrales y perdidas son supuestos. La alimentacion 3 VDC es de control, no potencia de calentamiento. No simula combustion, tiro ni gas en tuberia.</p></html>"));
  end HacebGasHeater;

  model UnloaderValve "Descarga progresiva a deposito atmosferico"
    extends TwoPort;
    parameter SI.PressureDifference pSet = 1.05*1500*PaPerPsi;
    parameter SI.PressureDifference proportionalBand = 0.05*1500*PaPerPsi;
    parameter SI.MassFlowRate mNominal = rho*5.9/60000;
    Real opening;
  equation
    m_flow = mNominal*positiveRoot((dp - pSet)/proportionalBand);
    opening = noEvent(min(1, max(0, (dp - pSet)/proportionalBand)));
    annotation(
      Icon(graphics = {Text(extent = {{-80, 30}, {80, -30}}, textString = "UNLOAD")}),
      Documentation(info = "<html><p>Valvula de alivio equivalente, sin enclavamiento ni histéresis: Q crece con sqrt(dp-pSet). La banda incorpora resistencia de valvula y retorno. Descarga a frontera atmosferica para evitar un lazo termico cerrado. No representa un unloader comercial con descarga a baja presion enclavada.</p></html>"));
  end UnloaderValve;

  model ChemicalSolenoid "NC independiente, perdida bidireccional y cierre ideal"
    extends TwoPort;
    parameter SI.Voltage controlVoltage = 12 "Bobina 12 VDC; no modelo electromagnetico";
    parameter SI.MassFlowRate mNominal = rho*0.20/60000;
    parameter SI.PressureDifference dpNominal = 4000 "SUPUESTO de perdida a caudal nominal";
    Modelica.Blocks.Interfaces.RealInput opening annotation(
      Placement(transformation(origin = {0, 100}, extent = {{-10, -10}, {10, 10}}, rotation = -90)));
    Real u;
  equation
    u = noEvent(min(1, max(0, opening)));
    m_flow = mNominal*u*Modelica.Fluid.Utilities.regRoot(dp/dpNominal, 0.001);
    annotation(
      Icon(graphics = {Text(extent = {{-80, 30}, {80, -30}}, textString = "NC")}),
      Documentation(info = "<html><p>Electrovalvula normalmente cerrada en aspiracion. Sin presion diferencial minima impuesta: representa accion directa. Sin fuga cerrada; la aptitud para vacio y contrapresion debe verificarse en ficha comercial.</p></html>"));
  end ChemicalSolenoid;

  model ChemicalCheckValve "Antirretorno de rama despues de NC"
    extends TwoPort;
    parameter SI.MassFlowRate mNominal = rho*0.20/60000;
    parameter SI.PressureDifference pCrack = 1000 "SUPUESTO apertura 0.01 bar";
    parameter SI.PressureDifference dpNominal = 1000 "SUPUESTO perdida adicional abierta";
    parameter Boolean failedOpen = false "Ensayo de perdida de aislamiento, no comportamiento normal";
  equation
    m_flow = if failedOpen then mNominal*Modelica.Fluid.Utilities.regRoot(dp/dpNominal, 0.001) else mNominal*positiveRoot((dp - pCrack)/dpNominal);
    annotation(
      Icon(graphics = {Text(extent = {{-80, 30}, {80, -30}}, textString = "CHECK >|")}));
  end ChemicalCheckValve;

  model ChemicalNeedleValve "Aguja manual independiente"
    extends TwoPort;
    parameter SI.MassFlowRate mNominal = rho*0.20/60000;
    parameter SI.PressureDifference dpNominal = 42000 "SUPUESTO ajuste de dosificacion";
    parameter Real setting(min = 0, max = 1) = 1;
  equation
    m_flow = mNominal*setting*Modelica.Fluid.Utilities.regRoot(dp/dpNominal, 0.001);
    annotation(
      Icon(graphics = {Text(extent = {{-80, 30}, {80, -30}}, textString = "AGUJA")}));
  end ChemicalNeedleValve;

  model ChemicalTank "Tanque finito con tapa y respiradero a la atmosfera"
    parameter SI.AbsolutePressure atmosphericPressure = 101325;
    parameter SI.Temperature T = 286.15;
    parameter SI.Volume initialLiquidVolume = 0.010 "SUPUESTO 10 L";
    parameter SI.Area crossSection = 0.030 "SUPUESTO seccion constante";
    Modelica.Fluid.Interfaces.FluidPort_b outlet(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    SI.Volume drawnVolume(start = 0, fixed = true);
    SI.Volume liquidVolume;
    SI.AbsolutePressure gasPressure;
    SI.Height liquidHeight;
  equation
    der(drawnVolume) = -outlet.m_flow/rho;
    liquidVolume = initialLiquidVolume - drawnVolume;
    liquidHeight = liquidVolume/crossSection;
    gasPressure = atmosphericPressure;
    outlet.p = gasPressure + rho*Modelica.Constants.g_n*liquidHeight;
    outlet.h_outflow = Medium.specificEnthalpy_pTX(outlet.p, T, Medium.X_default);
    outlet.Xi_outflow = Medium.X_default[1:Medium.nXi];
    outlet.C_outflow = fill(0, Medium.nC);
    assert(liquidVolume > 0, "Tanque quimico agotado");
    annotation(
      Icon(graphics = {Rectangle(extent = {{-80, 80}, {80, -80}}, lineColor = {0, 120, 60}), Text(extent = {{-70, 35}, {70, -35}}, textString = "TANQUE")}));
  end ChemicalTank;

  model ChemicalBranch "Tanque > sifon > NC > check > aguja > manifold"
    parameter SI.AbsolutePressure pTank = 101325;
    parameter SI.Temperature T = 286.15;
    parameter SI.MassFlowRate mNominal = rho*0.20/60000;
    parameter SI.Length siphonLength = 2 "SUPUESTO pendiente de medida";
    parameter SI.Diameter siphonDiameter = 0.0127 "Media pulgada interior, pendiente de confirmar";
    parameter SI.Height suctionLift = 0.5 "SUPUESTO: NC y manifold sobre nivel inicial de quimico";
    parameter SI.Volume tankLiquidVolume = 0.010;
    parameter SI.Area tankCrossSection = 0.030;
    parameter Real needleSetting(min = 0, max = 1) = 1;
    parameter Boolean branchCheckFailedOpen = false;
    ChemicalTank tank(atmosphericPressure = pTank, T = T, initialLiquidVolume = tankLiquidVolume, crossSection = tankCrossSection) annotation(
      Placement(transformation(origin = {-245, 0}, extent = {{-20, -20}, {20, 20}})));
    Modelica.Fluid.Pipes.StaticPipe siphon(redeclare package Medium = Medium, length = siphonLength, diameter = siphonDiameter, roughness = 2.5e-6, height_ab = suctionLift + tankLiquidVolume/tankCrossSection) annotation(
      Placement(transformation(origin = {-180, 0}, extent = {{-20, -15}, {20, 15}})));
    ChemicalSolenoid solenoid(mNominal = mNominal) annotation(
      Placement(transformation(origin = {-110, 0}, extent = {{-20, -20}, {20, 20}})));
    CompliantVolume beforeCheck(nPorts = 2, V0 = 1e-6, compliance = 1e-12, p0 = pTank, T0 = T, enableHeating = false) "SUPUESTO volumen entre NC y check; define presion atrapada" annotation(
      Placement(transformation(origin = {-45, 0}, extent = {{-15, -15}, {15, 15}})));
    ChemicalCheckValve checkValve(mNominal = mNominal, failedOpen = branchCheckFailedOpen) annotation(
      Placement(transformation(origin = {20, 0}, extent = {{-20, -20}, {20, 20}})));
    CompliantVolume afterCheck(nPorts = 2, V0 = 1e-6, compliance = 1e-12, p0 = pTank, T0 = T, enableHeating = false) "SUPUESTO volumen entre check y aguja" annotation(
      Placement(transformation(origin = {85, 0}, extent = {{-15, -15}, {15, 15}})));
    ChemicalNeedleValve needle(mNominal = mNominal, setting = needleSetting) annotation(
      Placement(transformation(origin = {150, 0}, extent = {{-20, -20}, {20, 20}})));
    Modelica.Fluid.Interfaces.FluidPort_b outlet(redeclare package Medium = Medium) annotation(
      Placement(transformation(origin = {240, 0}, extent = {{-10, -10}, {10, 10}}), iconTransformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealInput opening annotation(
      Placement(transformation(origin = {-110, 90}, extent = {{-10, -10}, {10, 10}}, rotation = -90), iconTransformation(origin = {0, 100}, extent = {{-10, -10}, {10, 10}}, rotation = -90)));
    SI.MassFlowRate m_flow = needle.m_flow "Producto entregado al manifold, incluye almacenamiento intermedio";
    SI.MassFlowRate tankDraw = siphon.port_a.m_flow;
    SI.AbsolutePressure valveInletPressure = solenoid.port_a.p;
    SI.AbsolutePressure valveOutletPressure = solenoid.port_b.p;
    SI.PressureDifference valveDifferentialPressure = solenoid.dp;
    SI.PressureDifference checkReversePressure = checkValve.port_b.p - checkValve.port_a.p;
  equation
    connect(tank.outlet, siphon.port_a) annotation(
      Line(points = {{-225, 0}, {-200, 0}}, color = {0, 127, 255}));
    connect(siphon.port_b, solenoid.port_a) annotation(
      Line(points = {{-160, 0}, {-130, 0}}, color = {0, 127, 255}));
    connect(solenoid.port_b, beforeCheck.ports[1]) annotation(
      Line(points = {{-90, 0}, {-45, 0}}, color = {0, 127, 255}));
    connect(beforeCheck.ports[2], checkValve.port_a) annotation(
      Line(points = {{-45, 0}, {0, 0}}, color = {0, 127, 255}));
    connect(checkValve.port_b, afterCheck.ports[1]) annotation(
      Line(points = {{40, 0}, {85, 0}}, color = {0, 127, 255}));
    connect(afterCheck.ports[2], needle.port_a) annotation(
      Line(points = {{85, 0}, {130, 0}}, color = {0, 127, 255}));
    connect(needle.port_b, outlet) annotation(
      Line(points = {{170, 0}, {240, 0}}, color = {0, 127, 255}));
    connect(opening, solenoid.opening) annotation(
      Line(points = {{-110, 90}, {-110, 20}}, color = {0, 0, 127}));
    annotation(
      Icon(graphics = {Rectangle(extent = {{-95, 60}, {95, -60}}, lineColor = {0, 120, 60}, fillColor = {220, 255, 220}, fillPattern = FillPattern.Solid), Text(extent = {{-100, 90}, {100, 65}}, textString = "%name"), Text(extent = {{-90, 35}, {90, 0}}, textString = "SIFON / NC >|"), Text(extent = {{-90, 0}, {90, -40}}, textString = "AGUJA")}),
      Diagram(coordinateSystem(extent = {{-280, -100}, {260, 120}})),
      Documentation(info = "<html><p>Orden fisico: tanque, manguera cebada, NC, check de rama, aguja y manifold. Presiones separadas y volumen atrapado a ambos lados del check. Media pulgada interior asumida. Longitud, desnivel, volumen de tanque y aire deben medirse. Agua equivalente: no calcula cebado, entrada de aire, viscosidad quimica ni colapso de manguera/tanque por vacio.</p></html>"));
  end ChemicalBranch;

  model DownstreamInjector "Venturi downstream y antirretorno de entrada quimica"
    parameter String commercialReference = "General Pump 100819" "Referencia comercial; el equivalente hidraulico no esta calibrado con una curva del fabricante";
    parameter String commercialDataSource = "https://www.generalpump.com/product/100819/";
    parameter SI.Diameter commercialOrificeDiameter = 0.0015 "Dato de catalogo del inyector; NO es la boquilla de descarga de 1.15 mm";
    parameter SI.VolumeFlowRate commercialMinimumFlow = 3.785411784/60000 "1 US GPM";
    parameter SI.VolumeFlowRate commercialMaximumFlow = 2*3.785411784/60000 "2 US GPM";
    parameter SI.PressureDifference commercialPressureRating = 4250*PaPerPsi "Rating publicado en pagina actual; NO es contrapresion admisible para aspirar";
    parameter SI.Temperature commercialMaximumTemperature = 273.15 + (190 - 32)*5/9 "190 F";
    parameter SI.MassFlowRate mNominal = rho*5.9/60000;
    parameter SI.PressureDifference dpLossNominal = 180000 "CALIBRAR perdida permanente";
    parameter SI.PressureDifference recoveryNominal = 180000 "CALIBRAR recuperacion garganta-salida";
    parameter SI.AbsolutePressure pFloor = 20000 "Limite monofasico aproximado; no modelo de cavitacion";
    parameter SI.MassFlowRate mChemicalNominal = rho*0.25/60000;
    parameter SI.PressureDifference dpCheckNominal = 5000;
    parameter SI.PressureDifference pCrack = 1000;
    parameter SI.MassFlowRate mRegularization = 1e-6;
    Modelica.Fluid.Interfaces.FluidPort_a water(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Fluid.Interfaces.FluidPort_b mixture(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Fluid.Interfaces.FluidPort_a chemical(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{-10, -110}, {10, -90}})));
    SI.AbsolutePressure pThroat;
    SI.Pressure pThroatRaw "Estimacion algebraica antes de aplicar pFloor; puede salir del dominio monofasico";
    SI.PressureDifference dp;
    SI.MassFlowRate mWater;
    SI.MassFlowRate mChemical;
    SI.MassFlowRate mMixture;
    Boolean suctionAvailable;
    Boolean throatLimited;
  equation
    mWater = water.m_flow;
    mChemical = chemical.m_flow;
    mMixture = -mixture.m_flow;
    mWater + mChemical = mMixture;
    dp = water.p - mixture.p;
    dp = dpLossNominal*(mWater/mNominal)*sqrt((mWater/mNominal)^2 + 0.001^2);
    pThroatRaw = mixture.p - recoveryNominal*(mWater/mNominal)^2;
    pThroat = noEvent(max(pFloor, pThroatRaw));
    throatLimited = noEvent(pThroatRaw < pFloor);
    suctionAvailable = chemical.p > pThroat + pCrack and mWater > mRegularization;
    mChemical = mChemicalNominal*positiveRoot((chemical.p - pThroat - pCrack)/dpCheckNominal)*noEvent(max(0, mWater))/sqrt(mWater*mWater + mRegularization*mRegularization);
    mixture.h_outflow = (noEvent(max(0, mWater))*inStream(water.h_outflow) + mChemical*inStream(chemical.h_outflow) + mRegularization*inStream(water.h_outflow))/(noEvent(max(0, mWater)) + mChemical + mRegularization);
    water.h_outflow = inStream(mixture.h_outflow);
    chemical.h_outflow = inStream(mixture.h_outflow);
    water.Xi_outflow = Medium.X_default[1:Medium.nXi];
    mixture.Xi_outflow = Medium.X_default[1:Medium.nXi];
    chemical.Xi_outflow = Medium.X_default[1:Medium.nXi];
    water.C_outflow = fill(0, Medium.nC);
    mixture.C_outflow = fill(0, Medium.nC);
    chemical.C_outflow = fill(0, Medium.nC);
    assert(mWater > -1e-7, "Inyector calibrado solo para flujo principal hacia delante");
    annotation(
      Icon(graphics = {Polygon(points = {{-100, 50}, {-25, 15}, {25, 15}, {100, 50}, {100, -50}, {25, -15}, {-25, -15}, {-100, -50}, {-100, 50}}, lineColor = {0, 90, 170}, fillColor = {220, 240, 255}, fillPattern = FillPattern.Solid), Line(points = {{0, -15}, {0, -100}}, color = {0, 120, 60}), Text(extent = {{-100, 95}, {100, 60}}, textString = "%name"), Text(extent = {{15, -50}, {90, -80}}, textString = "check >|")}),
      Documentation(info = "<html><p>Bernoulli equivalente: p_garganta=p_salida-recoveryNominal*(mWater/mNominal)^2, perdida permanente cuadratica. Dos coeficientes independientes a calibrar con curvas de inyector y contrapresion. El caudal quimico resulta del diferencial tanque-garganta y de las resistencias; no es una fuente de caudal.</p><p>Antirretorno HP entre colector quimico y garganta impide transmitir alta presion a las electrovalvulas de aspiracion. No elimina contrapresion de la linea principal. Recuperacion y perdida omiten dependencia fina de mezcla a dosis pequenas. pFloor limita el dominio monofasico; throatLimited avisa que se requiere modelo de cavitacion. Mezcla entalpica regularizada cerca de flujo cero.</p></html>"));
  end DownstreamInjector;

  model SprayGun "Pistola y seleccion de boquilla de alta o baja presion"
    parameter SI.MassFlowRate mNominal = rho*5.9/60000;
    parameter SI.Diameter nozzleDiameter(min = Modelica.Constants.small) = 0.00115 "Boquilla de alta presion: 1.15 mm";
    parameter SI.Diameter lowPressureNozzleDiameter(min = nozzleDiameter) = 0.0046 "SUPUESTO de diseno: boquilla de aplicacion quimica de 4.6 mm";
    parameter Real dischargeCoefficient(min = Modelica.Constants.small, max = 1) = 0.8 "SUPUESTO Cd; calibrar con boquilla real";
    final parameter SI.Area nozzleArea = Modelica.Constants.pi*lowPressureNozzleDiameter^2/4 "Area maxima de paso";
    final parameter SI.Area nozzleAv = sqrt(2)*dischargeCoefficient*nozzleArea "MSL: Q=Av*sqrt(dp/rho), equivalente a Cd*A*sqrt(2*dp/rho)";
    Modelica.Fluid.Interfaces.FluidPort_a port_a(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Fluid.Interfaces.FluidPort_b port_b(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealInput trigger annotation(
      Placement(transformation(origin = {-40, 100}, extent = {{-10, -10}, {10, 10}}, rotation = -90)));
    Modelica.Blocks.Interfaces.BooleanInput lowPressureMode "Seleccion ideal de boquilla de baja presion" annotation(Placement(transformation(origin = {40, 100}, extent = {{-10, -10}, {10, 10}}, rotation = -90)));
    SI.Diameter activeNozzleDiameter = if lowPressureMode then lowPressureNozzleDiameter else nozzleDiameter;
    SI.Area activeNozzleArea = Modelica.Constants.pi*activeNozzleDiameter^2/4;
    Modelica.Fluid.Valves.ValveIncompressible pistola(redeclare package Medium = Medium, CvData = Modelica.Fluid.Types.CvTypes.OpPoint, dp_nominal = 20000, m_flow_nominal = mNominal, opening_nominal = 1, m_flow_start = 0, checkValve = true, filteredOpening = false, use_Re = false) annotation(
      Placement(transformation(origin = {-40, 0}, extent = {{-15, -15}, {15, 15}})));
    Modelica.Fluid.Valves.ValveIncompressible nozzle(redeclare package Medium = Medium, CvData = Modelica.Fluid.Types.CvTypes.Av, Av = nozzleAv, dp_nominal = mNominal^2/(rho*nozzleAv^2), m_flow_nominal = mNominal, m_flow_start = 0, checkValve = false, filteredOpening = false, use_Re = false) annotation(
      Placement(transformation(origin = {40, 0}, extent = {{-15, -15}, {15, 15}})));
    Modelica.Blocks.Nonlinear.Limiter gunSignal(uMin = 0, uMax = 1) annotation(
      Placement(transformation(origin = {-50, 55}, extent = {{-20, -10}, {20, 10}})));
    SI.PressureDifference nozzleDrop = nozzle.dp;
  equation
    connect(port_a, pistola.port_a) annotation(
      Line(points = {{-100, 0}, {-55, 0}}, color = {0, 127, 255}));
    connect(pistola.port_b, nozzle.port_a) annotation(
      Line(points = {{-25, 0}, {25, 0}}, color = {0, 127, 255}));
    connect(nozzle.port_b, port_b) annotation(
      Line(points = {{55, 0}, {100, 0}}, color = {0, 127, 255}));
    connect(trigger, gunSignal.u) annotation(
      Line(points = {{-40, 100}, {-85, 100}, {-85, 55}, {-74, 55}}, color = {0, 0, 127}));
    connect(gunSignal.y, pistola.opening) annotation(
      Line(points = {{-28, 55}, {-15, 55}, {-15, 30}, {-40, 30}, {-40, 12}}, color = {0, 0, 127}));
    nozzle.opening = activeNozzleArea/nozzleArea "Seleccion del area fisica; el cierre lo hace la pistola";
    annotation(
      Icon(graphics = {Rectangle(extent = {{-90, 50}, {90, -40}}, lineColor = {0, 90, 170}, fillColor = {220, 240, 255}, fillPattern = FillPattern.Solid), Text(extent = {{-95, 85}, {95, 60}}, textString = "%name"), Text(extent = {{-80, 25}, {80, -15}}, textString = "GUN HP / LP")}),
      Documentation(info = "<html><p>Pistola y boquilla son resistencias separadas. Dos boquillas: alta 1.15 mm y baja 4.6 mm supuesta, Cd=0.8 supuesto. La seleccion ideal por programa representa el cambio de boquilla por el operador. Av=sqrt(2)*Cd*pi*d^2/4; la presion resulta del circuito, no se impone. El gatillo cierra la pistola independientemente de la seleccion de boquilla.</p></html>"));
  end SprayGun;

  block ProgramController "Seleccion exclusiva y purga temporizada con caudal real"
    parameter SI.Time purgeTime = 2;
    parameter SI.Time valveRise = 0.15;
    parameter SI.MassFlowRate minimumPurgeFlow = rho*2/60000;
    Modelica.Blocks.Interfaces.RealInput trigger annotation(
      Placement(transformation(origin = {-100, 60}, extent = {{-10, -10}, {10, 10}})));
    Modelica.Blocks.Interfaces.IntegerInput programSelect(start = 0, fixed = true) annotation(
      Placement(transformation(origin = {-100, 0}, extent = {{-10, -10}, {10, 10}})));
    Modelica.Blocks.Interfaces.RealInput waterFlow(unit = "kg/s") annotation(
      Placement(transformation(origin = {-100, -60}, extent = {{-10, -10}, {10, 10}})));
    Modelica.Blocks.Interfaces.RealOutput gunOpening annotation(
      Placement(transformation(origin = {100, 80}, extent = {{-10, -10}, {10, 10}})));
    Modelica.Blocks.Interfaces.RealOutput chemicalOpening[3] annotation(
      Placement(transformation(origin = {100, 0}, extent = {{-10, -10}, {10, 10}})));
    Modelica.Blocks.Interfaces.RealOutput pumpRun annotation(
      Placement(transformation(origin = {100, -40}, extent = {{-10, -10}, {10, 10}})));
    Modelica.Blocks.Interfaces.BooleanOutput nozzleLowPressure "Boquilla de baja para prelavado, jabon y cera";
    Modelica.Blocks.Interfaces.IntegerOutput activeProduct annotation(
      Placement(transformation(origin = {100, -80}, extent = {{-10, -10}, {10, 10}})));
    SI.Time purgeClock(start = 0, fixed = true);
    Integer selected;
    Boolean chemicalRequested;
    Boolean purgeActive;
  equation
    assert(programSelect >= 0 and programSelect <= 4, "Programas: 0 parado, 1 prelavado, 2 jabon, 3 enjuague, 4 cera");
    selected = if programSelect == 1 then 1 else if programSelect == 2 then 2 else if programSelect == 4 then 3 else 0;
    chemicalRequested = selected > 0;
    nozzleLowPressure = chemicalRequested;
    der(purgeClock) = if waterFlow > minimumPurgeFlow and gunOpening > 0.1 then 1 else 0;
    when change(programSelect) then
      reinit(purgeClock, 0);
    end when;
    purgeActive = chemicalRequested and purgeClock < purgeTime;
    gunOpening = noEvent(min(1, max(0, trigger)));
    pumpRun = if programSelect > 0 and gunOpening > 0.001 then 1 else 0 "Apagado automatico equivalente por gatillo; calibrar umbrales reales";
    for j in 1:3 loop
      chemicalOpening[j] = if selected == j and not purgeActive and gunOpening > 0.1 then noEvent(min(1, max(0, (purgeClock - purgeTime)/valveRise))) else 0;
    end for;
    activeProduct = if chemicalRequested and not purgeActive and gunOpening > 0.1 then selected else 0;
    annotation(
      Icon(graphics = {Rectangle(extent = {{-90, 90}, {90, -90}}, lineColor = {0, 0, 127}, fillColor = {245, 245, 220}, fillPattern = FillPattern.Solid), Text(extent = {{-85, 65}, {85, 20}}, textString = "PROGRAMA"), Text(extent = {{-85, 10}, {85, -30}}, textString = "PURGA"), Text(extent = {{-90, 120}, {90, 95}}, textString = "%name")}),
      Documentation(info = "<html><p>Entradas: trigger 0..1 y programa 0/1/2/3/4. Cada cambio reinicia purga: se cuenta solo tiempo con caudal de agua suficiente. Cierra inmediatamente el producto anterior y espera purga antes de abrir el nuevo. Boquilla de baja para programas quimicos, incluida la purga previa; alta para enjuague. No hay solape entre electrovalvulas. Apertura de electrovalvula no garantiza aspiracion: esta depende del diferencial de presion del inyector.</p></html>"));
  end ProgramController;

  model SelfServiceCarWash "Circuito reutilizable con entradas de usuario"
    parameter SI.AbsolutePressure pAtmosphere = 101325;
    parameter SI.Temperature supplyTemperature = 286.15;
    parameter SI.PressureDifference maximumPressure = 130e5 "TRENT: limite declarado, no punto nominal";
    parameter SI.PressureDifference workingPressure = 100e5 "Supuesto inicial de carga; calibrar";
    parameter SI.VolumeFlowRate referenceFlow = 7/60000 "Caudal declarado; curva real pendiente";
    parameter Boolean enableHeating = true;
    parameter SI.Temperature targetTemperature = 313.15;
    parameter SI.Power maximumHeatingPower = 12000 "Potencia de placa del calentador a gas; entrada asumida";
    parameter SI.Time purgeTime = 2;
    parameter SI.Length hoseLength = 8 "Manguera incluida TRENT";
    parameter SI.Diameter hoseDiameter = 0.008;
    parameter SI.Diameter nozzleDiameter(min = Modelica.Constants.small) = 0.00115 "Boquilla de enjuague de alta presion";
    parameter SI.Diameter lowPressureNozzleDiameter(min = nozzleDiameter) = 0.0046 "SUPUESTO de diseno, ajustar a boquilla real de baja presion";
    parameter Real nozzleDischargeCoefficient(min = Modelica.Constants.small, max = 1) = 0.8 "SUPUESTO Cd de ambas boquillas";
    parameter SI.Length chemicalSiphonLength = 2 "SUPUESTO pendiente de medir";
    parameter SI.Diameter chemicalSiphonDiameter = 0.0127;
    parameter SI.Height chemicalSuctionLift = 0.5 "SUPUESTO altura sobre nivel inicial";
    parameter SI.Volume tracerVolume = Modelica.Constants.pi*hoseDiameter^2*hoseLength/4 "Volumen de mezcla equivalente en manguera";
    final parameter SI.MassFlowRate mNominal = rho*referenceFlow;
    inner Modelica.Fluid.System system(p_ambient = pAtmosphere, T_ambient = supplyTemperature, p_start = pAtmosphere, T_start = supplyTemperature, m_flow_start = 0, allowFlowReversal = true) annotation(
      Placement(transformation(origin = {-300, 180}, extent = {{-15, -15}, {15, 15}})));
    Modelica.Blocks.Interfaces.RealInput trigger "Gatillo 0..1" annotation(
      Placement(transformation(origin = {-330, 275}, extent = {{-10, -10}, {10, 10}}), iconTransformation(origin = {-100, 40}, extent = {{-10, -10}, {10, 10}})));
    Modelica.Blocks.Interfaces.IntegerInput programSelect "0 parado, 1 pre, 2 jabon, 3 enjuague, 4 cera" annotation(
      Placement(transformation(origin = {-330, 230}, extent = {{-10, -10}, {10, 10}}), iconTransformation(origin = {-100, -40}, extent = {{-10, -10}, {10, 10}})));
    Modelica.Fluid.Sources.Boundary_pT fuente(redeclare package Medium = Medium, nPorts = 2, p = pAtmosphere, T = supplyTemperature) annotation(
      Placement(transformation(origin = {-322, 60}, extent = {{-15, -15}, {15, 15}})));
    PressureWasherPump bomba(pReference = workingPressure, QReference = referenceFlow, nParallel = 1) annotation(
      Placement(transformation(origin = {-176, 58}, extent = {{-20, -20}, {20, 20}})));
    HacebGasHeater inletHeater(initialTemperature = supplyTemperature, enabled = enableHeating, Tset = targetTemperature, ratedPower = maximumHeatingPower) "Sistema HACEB externo antes de hidrolavadora" annotation(
      Placement(transformation(origin = {-244, 61}, extent = {{-20, -20}, {20, 20}})));
  CompliantVolume accumulator(nPorts = 3, p0 = pAtmosphere, T0 = supplyTemperature, enableHeating = false) annotation(
      Placement(transformation(origin = {-108, 60}, extent = {{-20, -20}, {20, 20}})));
    UnloaderValve unloader(pSet = 0.90*maximumPressure, proportionalBand = 0.05*maximumPressure, mNominal = mNominal) annotation(
      Placement(transformation(origin = {-168, 127.5}, extent = {{38, -28.5}, {-38, 28.5}})));
    DownstreamInjector injector(mNominal = mNominal) annotation(
      Placement(transformation(origin = {20, 60}, extent = {{-25, -25}, {25, 25}})));
    Modelica.Fluid.Pipes.StaticPipe hose(redeclare package Medium = Medium, length = hoseLength, diameter = hoseDiameter, roughness = 2.5e-5, height_ab = 0) annotation(
      Placement(transformation(origin = {115, 60}, extent = {{-25, -15}, {25, 15}})));
    SprayGun gun(mNominal = mNominal, nozzleDiameter = nozzleDiameter, lowPressureNozzleDiameter = lowPressureNozzleDiameter, dischargeCoefficient = nozzleDischargeCoefficient) annotation(
      Placement(transformation(origin = {215, 60}, extent = {{-25, -25}, {25, 25}})));
    Modelica.Fluid.Sources.Boundary_pT salida(redeclare package Medium = Medium, nPorts = 1, p = pAtmosphere, T = supplyTemperature) annotation(
      Placement(transformation(origin = {300, 60}, extent = {{15, -15}, {-15, 15}})));
    ChemicalBranch prewash(pTank = pAtmosphere, T = supplyTemperature, siphonLength = chemicalSiphonLength, siphonDiameter = chemicalSiphonDiameter, suctionLift = chemicalSuctionLift) annotation(
      Placement(transformation(origin = {-115, -67.4444}, extent = {{-62, -34.4444}, {62, 34.4444}})));
    ChemicalBranch soap(pTank = pAtmosphere, T = supplyTemperature, siphonLength = chemicalSiphonLength, siphonDiameter = chemicalSiphonDiameter, suctionLift = chemicalSuctionLift) annotation(
      Placement(transformation(origin = {-110.6, -159.667}, extent = {{-62.4, -34.6667}, {62.4, 34.6667}})));
    ChemicalBranch wax(pTank = pAtmosphere, T = supplyTemperature, mNominal = rho*0.10/60000, siphonLength = chemicalSiphonLength, siphonDiameter = chemicalSiphonDiameter, suctionLift = chemicalSuctionLift) annotation(
      Placement(transformation(origin = {-110.2, -241}, extent = {{-61.2, -34}, {61.2, 34}})));
    CompliantVolume chemicalManifold(nPorts = 4, V0 = 20e-6, compliance = 1e-10, p0 = pAtmosphere, T0 = supplyTemperature) annotation(
      Placement(transformation(origin = {20, -160}, extent = {{-20, -20}, {20, 20}})));
    ProgramController controller(purgeTime = purgeTime) annotation(
      Placement(transformation(origin = {0, 230}, extent = {{-45, -45}, {45, 45}})));
    Modelica.Blocks.Sources.RealExpression flowFeedback(y = waterFlow_kg_s) annotation(
      Placement(transformation(origin = {-180, 189}, extent = {{-55, -16}, {55, 16}})));
    output SI.AbsolutePressure pumpInletPressure;
    output SI.AbsolutePressure pumpOutletPressure;
    output SI.AbsolutePressure injectorInletPressure;
    output SI.AbsolutePressure injectorOutletPressure;
    output SI.AbsolutePressure throatPressure;
    output SI.AbsolutePressure chemicalManifoldPressure;
    output Boolean chemicalInjectionBlocked "Electrovalvula solicitada con caudal de agua, pero sin diferencial disponible para aspirar";
    output SI.AbsolutePressure gunInletPressure;
    output SI.PressureDifference hosePressureDrop;
    output SI.PressureDifference injectorPressureDrop;
    output SI.PressureDifference nozzlePressureDrop;
    output Modelica.Units.NonSI.Pressure_bar pumpPressure_bar "Presion manometrica [bar]";
    output Real pumpPressure_psi(unit = "psi") "Presion manometrica [psi]";
    output SI.MassFlowRate waterFlow_kg_s;
    output SI.MassFlowRate outletFlow_kg_s;
    output SI.MassFlowRate productFlow_kg_s[3] "Prelavado, jabon, cera";
    output SI.MassFlowRate chemicalFlow_kg_s "Quimico equivalente extraido de tanques";
    output SI.MassFlowRate suctionFlow_kg_s "Flujo colector-inyector; incluye inventario del colector";
    output VolumeFlowRate_L_min waterFlow_L_min "[L/min]";
    output VolumeFlowRate_L_min outletFlow_L_min "[L/min]";
    output VolumeFlowRate_L_min productFlow_L_min[3] "[L/min]: prelavado, jabon, cera";
    output VolumeFlowRate_L_min chemicalFlow_L_min "[L/min]";
    output VolumeFlowRate_L_min bypassFlow_L_min "[L/min]";
    output VolumeFlowRate_L_min pumpFlow_L_min "[L/min]";
    output Real chemicalWaterRatio "Relacion de masa de productos/agua en inyector";
    output Real chemicalFractionAtInjector;
    output Real outletConcentration[3](each start = 0, each fixed = true) "Fracciones masicas equivalentes en salida; incluye purga";
    output Real outletChemicalFraction;
    output Real gunOpening;
    output Real solenoidOpening[3];
    output Boolean purgeActive;
    output Integer selectedProgram;
    output Integer activeProduct "0 ninguno, 1 pre, 2 jabon, 3 cera";
    output SI.Temperature waterTemperature;
    output SI.Temperature outletTemperature;
    output SI.Power heatingPower;
    output SI.MassFlowRate mainMassResidual;
    output SI.MassFlowRate chemicalMassResidual;
    output SI.MassFlowRate injectorMassResidual;
    output Boolean throatLimited;
    Real manifoldConcentration[3](each start = 0, each fixed = true);
    SI.MassFlowRate injectedProductFlow[3];
  equation
    connect(fuente.ports[1], inletHeater.port_a) annotation(
      Line(points = {{-307, 60}, {-300, 60}, {-300, 61}, {-264, 61}}, color = {0, 127, 255}, thickness = 0.5));
    connect(inletHeater.port_b, bomba.port_a) annotation(
      Line(points = {{-224, 61}, {-224, 58.5}, {-196, 58.5}, {-196, 58}}, color = {0, 127, 255}, thickness = 0.5));
    connect(bomba.port_b, accumulator.ports[1]) annotation(
      Line(points = {{-156, 58}, {-132, 58}, {-132, 60}, {-108, 60}}, color = {0, 127, 255}, thickness = 0.5));
    connect(accumulator.ports[2], injector.water) annotation(
      Line(points = {{-108, 60}, {-5, 60}}, color = {0, 127, 255}, thickness = 0.5));
    connect(accumulator.ports[3], unloader.port_a) annotation(
      Line(points = {{-108, 60}, {-65, 60}, {-65, 127.5}, {-130, 127.5}}, color = {0, 127, 255}, thickness = 0.5));
    connect(unloader.port_b, fuente.ports[2]) annotation(
      Line(points = {{-206, 127.5}, {-275, 127.5}, {-275, 60}, {-307, 60}}, color = {0, 127, 255}, thickness = 0.5));
    connect(injector.mixture, hose.port_a) annotation(
      Line(points = {{45, 60}, {90, 60}}, color = {0, 127, 255}, thickness = 0.5));
    connect(hose.port_b, gun.port_a) annotation(
      Line(points = {{140, 60}, {190, 60}}, color = {0, 127, 255}, thickness = 0.5));
    connect(gun.port_b, salida.ports[1]) annotation(
      Line(points = {{240, 60}, {285, 60}}, color = {0, 127, 255}, thickness = 0.5));
    connect(prewash.outlet, chemicalManifold.ports[1]) annotation(
      Line(points = {{-53, -67}, {-20, -67}, {-20, -160}, {20, -160}}, color = {0, 120, 60}, thickness = 0.5));
    connect(soap.outlet, chemicalManifold.ports[2]) annotation(
      Line(points = {{-48, -160}, {20, -160}}, color = {0, 120, 60}, thickness = 0.5));
    connect(wax.outlet, chemicalManifold.ports[3]) annotation(
      Line(points = {{-49, -241}, {-20, -241}, {-20, -160}, {20, -160}}, color = {0, 120, 60}, thickness = 0.5));
    connect(chemicalManifold.ports[4], injector.chemical) annotation(
      Line(points = {{20, -160}, {20, 35}}, color = {0, 120, 60}, thickness = 0.5));
    connect(trigger, controller.trigger) annotation(
      Line(points = {{-330, 275}, {-65, 275}, {-65, 257}, {-45, 257}}, color = {0, 0, 127}));
    connect(programSelect, controller.programSelect) annotation(
      Line(points = {{-330, 230}, {-45, 230}}, color = {255, 127, 0}));
    connect(flowFeedback.y, controller.waterFlow) annotation(
      Line(points = {{-119.5, 189}, {-65, 189}, {-65, 203}, {-45, 203}}, color = {0, 0, 127}));
    connect(controller.gunOpening, gun.trigger) annotation(
      Line(points = {{45, 266}, {205, 266}, {205, 85}}, color = {0, 0, 127}));
    connect(controller.nozzleLowPressure, gun.lowPressureMode);
    connect(controller.pumpRun, bomba.runCommand) annotation(
      Line(points = {{45, 212}, {65, 212}, {65, 170}, {-190, 170}, {-190, 96}, {-195, 96}, {-195, 78}, {-176, 78}}, color = {0, 0, 127}));
    connect(controller.chemicalOpening[1], prewash.opening) annotation(
      Line(points = {{45, 230}, {80, 230}, {80, -2}, {-100, -2}, {-100, -33}, {-115, -33}}, color = {120, 120, 0}));
    connect(controller.chemicalOpening[2], soap.opening) annotation(
      Line(points = {{45, 230}, {80, 230}, {80, -110}, {-100, -110}, {-100, -125}, {-111, -125}}, color = {120, 120, 0}));
    connect(controller.chemicalOpening[3], wax.opening) annotation(
      Line(points = {{45, 230}, {80, 230}, {80, -207}, {-110, -207}}, color = {120, 120, 0}));
    pumpInletPressure = bomba.port_a.p;
    pumpOutletPressure = bomba.port_b.p;
    injectorInletPressure = injector.water.p;
    injectorOutletPressure = injector.mixture.p;
    throatPressure = injector.pThroat;
    chemicalManifoldPressure = chemicalManifold.p;
    chemicalInjectionBlocked = max(controller.chemicalOpening) > 0.99 and injector.mWater > injector.mRegularization and not injector.suctionAvailable;
    gunInletPressure = gun.port_a.p;
    hosePressureDrop = hose.port_a.p - hose.port_b.p;
    injectorPressureDrop = injector.dp;
    nozzlePressureDrop = gun.nozzleDrop;
    pumpPressure_bar = Modelica.Units.Conversions.to_bar(pumpOutletPressure - pAtmosphere);
    pumpPressure_psi = toPsi(pumpOutletPressure - pAtmosphere);
    waterFlow_kg_s = injector.mWater;
    outletFlow_kg_s = injector.mMixture;
    productFlow_kg_s = {prewash.m_flow, soap.m_flow, wax.m_flow};
    chemicalFlow_kg_s = sum(productFlow_kg_s);
    suctionFlow_kg_s = injector.mChemical;
    waterFlow_L_min = toLMin(waterFlow_kg_s/rho);
    outletFlow_L_min = toLMin(outletFlow_kg_s/rho);
    productFlow_L_min = {toLMin(productFlow_kg_s[j]/rho) for j in 1:3};
    chemicalFlow_L_min = sum(productFlow_L_min);
    bypassFlow_L_min = toLMin(unloader.m_flow/rho);
    pumpFlow_L_min = toLMin(bomba.Q);
    for j in 1:3 loop
      chemicalManifold.mass*der(manifoldConcentration[j]) = productFlow_kg_s[j] - chemicalFlow_kg_s*manifoldConcentration[j];
      injectedProductFlow[j] = suctionFlow_kg_s*manifoldConcentration[j];
      rho*tracerVolume*der(outletConcentration[j]) = injectedProductFlow[j] - noEvent(max(0, outletFlow_kg_s))*outletConcentration[j];
    end for;
    chemicalWaterRatio = sum(injectedProductFlow)/noEvent(max(1e-8, waterFlow_kg_s));
    chemicalFractionAtInjector = sum(injectedProductFlow)/noEvent(max(1e-8, outletFlow_kg_s));
    outletChemicalFraction = sum(outletConcentration);
    gunOpening = controller.gunOpening;
    solenoidOpening = controller.chemicalOpening;
    purgeActive = controller.purgeActive;
    selectedProgram = programSelect;
    activeProduct = controller.activeProduct;
    waterTemperature = accumulator.T;
    outletTemperature = Medium.temperature(Medium.setState_phX(gun.port_b.p, actualStream(gun.port_b.h_outflow)));
    heatingPower = inletHeater.heaterPower;
    mainMassResidual = bomba.m_flow - unloader.m_flow - waterFlow_kg_s - accumulator.storageRate;
    chemicalMassResidual = chemicalFlow_kg_s - suctionFlow_kg_s - chemicalManifold.storageRate;
    injectorMassResidual = waterFlow_kg_s + suctionFlow_kg_s - outletFlow_kg_s;
    throatLimited = injector.throatLimited;
    assert(not enableHeating or targetTemperature <= 323.15, "Temperatura objetivo supera 50 C declarados en ficha TRENT");
    assert(inletHeater.T <= 323.15 + 0.01, "Entrada a hidrolavadora supera 50 C");
    assert(sum(solenoidOpening) <= 1.000001, "Mas de una electrovalvula activa");
    assert(chemicalManifoldPressure < pAtmosphere + 120*PaPerPsi, "Presion excesiva para NC de aspiracion");
    annotation(
      Icon(coordinateSystem(extent = {{-100, -100}, {100, 100}}), graphics = {Rectangle(extent = {{-90, 80}, {90, -80}}, lineColor = {0, 90, 170}, fillColor = {220, 240, 255}, fillPattern = FillPattern.Solid), Text(extent = {{-85, 55}, {85, 5}}, textString = "AUTOLAVADO"), Text(extent = {{-85, 0}, {85, -45}}, textString = "BOQUILLAS HP / LP"), Text(extent = {{-90, 115}, {90, 85}}, textString = "%name")}),
      Diagram(coordinateSystem(extent = {{-350, -300}, {350, 310}}, preserveAspectRatio = true), graphics = {Text(origin = {118, 10}, textColor = {0, 90, 170}, extent = {{-320, 30}, {-160, 5}}, textString = "Hidrolavadora"), Text(textColor = {0, 90, 170}, extent = {{100, 30}, {310, 5}}, textString = "MANGUERA / PISTOLA / AMBIENTE"), Text(origin = {-40, -122}, textColor = {0, 120, 60}, extent = {{-300, -20}, {-145, -45}}, textString = "ASPIRACION QUIMICA"), Text(origin = {-244, 22}, textColor = {255, 170, 0}, extent = {{-38, 16}, {38, -16}}, textString = "Calentador")}),
      Documentation(info = "<html><p>Arquitectura: frontera atmosferica - calentador externo de entrada - hidrolavadora equivalente - volumen elastico sin calefaccion y alivio - Venturi - manguera - pistola/boquilla - atmosfera. Tres ramas de aspiracion exclusivas llegan a colector elastico comun y antirretorno HP del inyector.</p><p>Medio unico ConstantPropertyLiquidWater. Productos como escalares pasivos, balance en colector variable y volumen de mezcla equivalente a manguera. No representa transporte piston, reaccion, viscosidad quimica, agotamiento, usuario ni impacto del chorro. El retorno se descarga a frontera, sin recirculacion termica externa.</p></html>"));
  end SelfServiceCarWash;

  block TestSequence "Experimentos reproducibles A, B, C y D"
    parameter Integer scenario(min = 1, max = 5) = 4;
    Modelica.Blocks.Interfaces.RealOutput trigger annotation(
      Placement(transformation(origin = {100, 40}, extent = {{-10, -10}, {10, 10}})));
    Modelica.Blocks.Interfaces.IntegerOutput programSelect annotation(
      Placement(transformation(origin = {100, -40}, extent = {{-10, -10}, {10, 10}})));
  equation
    if scenario == 1 then
      trigger = if time < 2 then 0 else if time < 4 then (time - 2)/2 else if time < 12 then 1 else if time < 14 then (14 - time)/2 else 0;
      programSelect = if time < 1 then 0 else 3;
    elseif scenario == 2 then
      trigger = 1;
      programSelect = 3;
    elseif scenario == 3 then
      trigger = 1;
      programSelect = 2;
    elseif scenario == 5 then
      trigger = if time < 1 then -0.2 else if time < 12 then 1.2 else if time < 17 then -0.2 else if time < 25 then 1.2 else 0;
      programSelect = if time < 6 then 1 else if time < 12 then 2 else if time < 25 then 4 else 3;
    else
      trigger = if time < 2 then 0 else if time < 4 then (time - 2)/2 else if time < 55 then 1 else if time < 57 then (57 - time)/2 else 0;
      programSelect = if time < 2 then 0 else if time < 10 then 3 else if time < 20 then 1 else if time < 25 then 3 else if time < 35 then 2 else if time < 40 then 3 else if time < 50 then 4 else if time < 60 then 3 else 0;
    end if;
    annotation(
      Icon(graphics = {Rectangle(extent = {{-90, 90}, {90, -90}}, lineColor = {0, 0, 127}), Text(extent = {{-85, 45}, {85, -45}}, textString = "TEST %scenario")}),
      Documentation(info = "<html><p>Boquilla de alta para enjuague y baja para aplicar quimicos. A: arranque, apertura 2..4 s, cierre 12..14 s y bypass. B: enjuague. C: seleccion de jabon tras purga; aspiracion condicionada al diferencial del inyector. D: parado 0..2, enjuague 2..10, prelavado 10..20, enjuague 20..25, jabon 25..35, enjuague 35..40, cera 40..50, enjuague 50..55, cierre 55..57, bypass hasta 60 y parada.</p></html>"));
  end TestSequence;

  model SelfServiceCarWashTest "D: secuencia completa; modelo principal para simular"
    parameter Integer scenario = 4;
    parameter Boolean enableHeating = true;
    TestSequence sequence(scenario = scenario) annotation(
      Placement(transformation(origin = {-160, 0}, extent = {{-30, -30}, {30, 30}})));
    SelfServiceCarWash plant(enableHeating = enableHeating) annotation(
      Placement(transformation(origin = {50, 0}, extent = {{-100, -100}, {100, 100}})));
  equation
    connect(sequence.trigger, plant.trigger) annotation(
      Line(points = {{-130, 12}, {-110, 12}, {-110, 40}, {-50, 40}}, color = {0, 0, 127}));
    connect(sequence.programSelect, plant.programSelect) annotation(
      Line(points = {{-130, -12}, {-110, -12}, {-110, -40}, {-50, -40}}, color = {255, 127, 0}));
    annotation(
      experiment(StartTime = 0, StopTime = 64, Tolerance = 1e-6, Interval = 0.02),
      Diagram(coordinateSystem(extent = {{-220, -140}, {220, 140}})),
      Documentation(info = "<html><p>Simular este modelo. Abrir plant para inspeccionar circuito en Diagram View. Graficar plant.pumpPressure_bar, plant.waterFlow_L_min, plant.productFlow_L_min, plant.throatPressure, plant.bypassFlow_L_min y plant.outletConcentration.</p></html>"));
  end SelfServiceCarWashTest;

  model ExperimentA "A: apertura/cierre gradual y descarga"
    extends SelfServiceCarWashTest(scenario = 1);
    annotation(
      experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.02));
  end ExperimentA;

  model ExperimentB "B: enjuague con boquilla fija"
    extends SelfServiceCarWashTest(scenario = 2);
    annotation(
      experiment(StartTime = 0, StopTime = 15, Tolerance = 1e-6, Interval = 0.02));
  end ExperimentB;

  model ExperimentC "C: jabon con boquilla de baja; aspiracion por diferencial"
    extends SelfServiceCarWashTest(scenario = 3);
    annotation(
      experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.02));
  end ExperimentC;

  model ExperimentD "D: secuencia de todos los programas"
    extends SelfServiceCarWashTest(scenario = 4);
    annotation(
      experiment(StartTime = 0, StopTime = 64, Tolerance = 1e-6, Interval = 0.02));
  end ExperimentD;

  model InterlockTest "Cambio directo, purga con pistola cerrada y saturacion del gatillo"
    extends SelfServiceCarWashTest(scenario = 5);
    annotation(
      experiment(StartTime = 0, StopTime = 30, Tolerance = 1e-6, Interval = 0.02));
  end InterlockTest;

  model InjectionTest "Seleccion sostenida de jabon con tanques con respiradero; aspiracion no impuesta"
    extends SelfServiceCarWashTest(scenario = 3);
    annotation(
      experiment(StopTime = 120, Tolerance = 1e-6, Interval = 0.02));
  end InjectionTest;

  model ChemicalProtectionTest "Manifold presurizado: check de rama sano o fallado"
    parameter Boolean failedCheck = false;
    inner Modelica.Fluid.System system;
    ChemicalBranch branch(branchCheckFailedOpen = failedCheck);
    Modelica.Fluid.Sources.Boundary_pT manifold(redeclare package Medium = Medium, nPorts = 1, T = 286.15, use_p_in = true);
    Modelica.Blocks.Sources.RealExpression imposedPressure(y = if time < 5 then 60000 else 101325 + 130e5);
    Modelica.Blocks.Sources.RealExpression valveCommand(y = if time < 2 then 1 else 0);
  equation
    connect(imposedPressure.y, manifold.p_in);
    connect(valveCommand.y, branch.opening);
    connect(branch.outlet, manifold.ports[1]);
    annotation(
      experiment(StopTime = 15, Tolerance = 1e-6, Interval = 0.01));
  end ChemicalProtectionTest;

  model GasHeaterTest "Banco independiente HACEB: plena potencia y fallos"
    parameter Integer scenario = 0 "0 plena potencia; 1 llama; 2 ventilacion; 3 sobretemperatura; 4 bajo caudal; 5 potencia insuficiente";
    inner Modelica.Fluid.System system;
    Modelica.Fluid.Sources.MassFlowSource_T supply(redeclare package Medium = Medium, nPorts = 1, T = 286.15, use_m_flow_in = true);
    Modelica.Fluid.Sources.Boundary_pT outlet(redeclare package Medium = Medium, nPorts = 1, p = 201325, T = 293.15);
    HacebGasHeater heater(initialTemperature = 286.15, gasSetting = 1, ventilationOK = not (scenario == 2 and time >= 10 and time < 20), flameDetected = not (scenario == 1 and time >= 10 and time < 20), resetSafety = (scenario == 1 or scenario == 2) and time >= 25 and time < 26, automaticTemperatureControl = scenario == 5, Tset = 333.15);
    Modelica.Blocks.Sources.RealExpression flowDemand(y = rho*(if scenario == 3 then 2.1/60000 else if scenario == 4 then 1/60000 else 8/60000));
  equation
    connect(flowDemand.y, supply.m_flow_in);
    connect(supply.ports[1], heater.port_a);
    connect(heater.port_b, outlet.ports[1]);
    annotation(
      experiment(StopTime = 120, Tolerance = 1e-6, Interval = 0.2));
  end GasHeaterTest;

  model HeatingTest "Calentador a gas externo activado, ajuste manual"
    extends SelfServiceCarWashTest(scenario = 2, enableHeating = true);
    annotation(
      experiment(StartTime = 0, StopTime = 30, Tolerance = 1e-6, Interval = 0.02));
  end HeatingTest;
  annotation(
    uses(Modelica(version = "4.1.0")),
    Documentation(info = "<html><p>Derivado del modelo original autolavado. Conserva fronteras MSL, medio y pistola ValveIncompressible. ControlledPump se sustituye por curva de desplazamiento positivo parametrizable; el original se conserva en verification/autolavado.original.mo.</p><p>Inicio: abrir SelfServiceCarWashTest y simular. Parametros iniciales ilustrativos, no caracterizacion ni certificacion de hardware.</p></html>"));
end autolavado;
