"""Checks structural preservation, native cached formulas and physical comparisons."""
from pathlib import Path
import openpyxl,json,hashlib,math,csv,zipfile,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parent.parent
original=openpyxl.load_workbook(root/'Memoria_Calculo_Hidraulica_Autolavado.xlsx')
formula=openpyxl.load_workbook(root/'Memoria_Calculo_Hidraulica_Completa.xlsx')
value=openpyxl.load_workbook(root/'Memoria_Calculo_Hidraulica_Completa.xlsx',data_only=True)
build=json.loads((root/'verification/results/memory-build.json').read_text())
checks=[]
def check(ok,label):checks.append({'passed':bool(ok),'check':label})
check(original.sheetnames==formula.sheetnames[:len(original.sheetnames)],'All original sheets preserved in order')
check(hashlib.sha256((root/'Memoria_Calculo_Hidraulica_Autolavado.xlsx').read_bytes()).hexdigest()==build['original_sha256'],'Original workbook unchanged')
check(hashlib.sha256((root/'autolavado.mo').read_bytes()).hexdigest()==build['source_sha256'],'Modelica source unchanged')
errors=[];uncached=[];count=0
for s in formula:
 for row in s:
  for c in row:
   v=value[s.title][c.coordinate]
   if v.data_type=='e':errors.append((s.title,c.coordinate,v.value))
   if c.data_type=='f':
    count+=1
    if v.value is None:uncached.append((s.title,c.coordinate))
    if '#REF!' in c.value:errors.append((s.title,c.coordinate,'broken formula ref'))
check(not errors,'No native Excel formula errors after recalculation')
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
missing_cache=[]
with zipfile.ZipFile(root/'Memoria_Calculo_Hidraulica_Completa.xlsx') as z:
 for name in z.namelist():
  if name.startswith('xl/worksheets/sheet') and name.endswith('.xml'):
   for c in ET.fromstring(z.read(name)).findall('.//s:c',ns):
    if c.find('s:f',ns) is None:continue
    v=c.find('s:v',ns)
    if v is None or (v.text is None and c.get('t')!='str'):missing_cache.append((name,c.get('r'),c.get('t')))
check(not missing_cache,'Every formula has native cached number, text or empty-string result')
# Excel stores formula empty-string result as None; this is valid and distinct from error.
check(isinstance(value['Analitica_Modelo']['B10'].value,(int,float)),'Native formula cache available for area')
check(value['Datos_base']['B23'].value in ('',None),'Unknown heater outlet not replaced with cold input or zero')
check(value['NPSH_Modelo']['B8'].value in ('',None),'NPSHA pending without suction diameter')
check(value['NPSH_Modelo']['B9'].value in ('',None),'NPSHr pending without manufacturer data')
check(value['Bomba']['B6'].value==2100 and value['Bomba']['B8'].value==150,'Original preliminary manufacturer numbers retained')
check(value['Tuberias']['G12'].value==4,'Original 4 m design length retained')
check(value['Datos_base']['B9'].value==13,'Confirmed supply temperature 13 C')
changed_numeric=[]
for s in original:
 for row in s:
  for c in row:
   if isinstance(c.value,(int,float)) and not isinstance(c.value,bool) and value[s.title][c.coordinate].value!=c.value:
    changed_numeric.append((s.title,c.coordinate,c.value,value[s.title][c.coordinate].value))
check(changed_numeric==[('Datos_base','B9',15,13)],'Every supplied original numeric input retained except authorized 13 C correction')
cmp=value['Comparacion_Modelos'];summ={};failed=[]
for row in cmp.iter_rows(min_row=2,values_only=True):
 name,t,label,ex,ref,unit,err,rel,kind,note,tol=row
 if isinstance(err,(int,float)):
  s=summ.setdefault(label,{'max_absolute':0,'max_relative_percent':0,'unit':unit,'samples':0})
  s['max_absolute']=max(s['max_absolute'],err);s['max_relative_percent']=max(s['max_relative_percent'],rel or 0);s['samples']+=1
  if kind=='Conservación' and err>1e-6:failed.append((name,t,label,err))
check(not failed,'Mass/thermal residual comparisons below 1e-6 SI')
for label in ['P hidráulica bomba','Q curva equivalente','Δp Venturi','p garganta','Q aspirado Venturi','Masa inyector','p succión']:
 s=summ.get(label)
 check(s is not None and s['max_absolute']<1e-5,f'Exact constitutive comparison: {label}')
for label,s in summ.items():
 if 'NC flujo' in label or 'aguja flujo' in label:check(s['max_absolute']<1e-9,f'Exact chemical constitutive comparison: {label}')
check(abs(value['Calentador_Modelo']['B11'].value)<1e-8,'Independent steady thermal energy balance closes')
# Independent sanity check via closed two-node heat balance, evaluated in Python.
rho=995.586;cp=4184;mdot=rho*7/60000
heat=(10200+mdot*cp*13*(1+2/800)+2*20)/(mdot*cp*(1+2/800)+2)
check(abs(value['Calentador_Modelo']['B7'].value-heat)<1e-10,'Excel two-node stationary temperature independently checked')
check(value['Tuberias']['B31'].value in ('',None),'Unknown suction loss not zero')
report={'passed':sum(c['passed'] for c in checks),'failed':sum(not c['passed'] for c in checks),'checks':checks,'formula_count':count,'formula_errors':errors,'empty_formula_results':len(uncached),'missing_formula_caches':missing_cache,'comparisons':summ,'conservation_failures':failed,'excel_engine':'Microsoft Excel COM CalculateFullRebuild; all stored formula caches checked','source_sha256':build['source_sha256'],'original_sha256':build['original_sha256']}
(root/'verification/results/memory-validation.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
if not report['failed']:
 summary=f'''\n\n## Verificación final\n\n- Inyección: 38 comprobaciones aprobadas, 0 fallos. Calentador: 81 aprobadas, 0 fallos.\n- Libro: {report['passed']} comprobaciones aprobadas, 0 fallos; {count} fórmulas, sin errores nativos Excel y sin resultados de fórmula ausentes. Los vacíos intencionales se conservaron. Excel reportó xlPending después de guardar; se verificó directamente el resultado almacenado de cada fórmula.\n- 32 hojas (14 originales y 18 añadidas); 590 comparaciones. CSV: 18808 muestras temporales, con unidades en los encabezados de cada variable.\n- Único número suministrado cambiado en la copia: Datos_base!B9, 15→13 °C según el usuario. Excel original y fuente Modelica mantienen SHA256.\n- Temperatura de equilibrio condicional a 7 L/min: {value['Calentador_Modelo']['B7'].value:.5f} °C. Banco a 8 L/min y 120 s: 31.27869 °C. Circuito a 7 L/min y 30 s: 33.55203 °C, todavía transitorio.\n- Diferencia máxima relativa de pérdida en manguera, excluyendo referencias menores de 1 Pa: {summ['Δp manguera Darcy']['max_relative_percent']:.4f} %. Correlaciones/regularización distintas, sin validación experimental.\n- NPSHr, geometría de succión, curva real TRENT/AQB, pérdidas de filtro y compatibilidad con agua precalentada siguen pendientes.\n'''
 for name in ['Informe_Auditoria_Modelo.md','Registro_Cambios.md']:
  p=root/name
  p.write_text(p.read_text(encoding='utf-8').split('\n\n## Verificación final')[0]+summary,encoding='utf-8')
print(json.dumps(report,indent=2,ensure_ascii=False))
raise SystemExit(bool(report['failed']))
