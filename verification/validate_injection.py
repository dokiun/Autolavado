"""Pressure envelopes for the actual NC > check > needle siphon architecture."""
import csv
import hashlib
import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parent
build = root / 'build'
results = root / 'results'
results.mkdir(exist_ok=True)
checks = []

def require(ok, message):
    checks.append({'passed': bool(ok), 'check': message})

def load(name, end):
    variables = {v.get('name'): v for v in ET.parse(build/f'{name}_init.xml').findall('.//ScalarVariable')}
    class Row(dict):
        def __missing__(self, key):
            v = variables[key]
            if v.get('alias') in ('alias','negatedAlias'):
                value = self[v.get('aliasVariable')]
                return -value if v.get('alias') == 'negatedAlias' else value
            scalar = next(iter(v))
            if v.get('variability') in ('parameter','constant') and 'start' in scalar.attrib:
                value = scalar.get('start')
                return float({'true':'1','false':'0'}.get(value,value))
            # OMC omits starts for these calculated parameters; resolve their explicit bindings.
            if key.endswith('.tank.atmosphericPressure'):
                return self[key.removesuffix('.tank.atmosphericPressure')+'.pTank']
            if key.startswith('plant.') and key.endswith('.pTank'):
                return self['plant.pAtmosphere']
            raise KeyError(key)
    with (build/f'{name}_res.csv').open(encoding='utf-8-sig') as stream:
        rows = [Row({k:float(v) for k,v in r.items()}) for r in csv.DictReader(stream)]
    require(abs(rows[-1]['time']-end)<1e-6, f'{name}: completes {end}s')
    require(all(math.isfinite(v) for r in rows for v in r.values()), f'{name}: finite values')
    return rows

def at(rows, t):
    return min(rows, key=lambda r: abs(r['time']-t))

def gauge(p):
    return (p-101325)/1e5

cycle = load('InjectionCycle',64)
vented = load('InjectionVented',120)
protected = load('InjectionProtected',15)
failed = load('InjectionFailed',15)
for name,rows in [('cycle',cycle),('vented',vented)]:
    require(max(abs(r['plant.'+k]) for r in rows for k in ['mainMassResidual','chemicalMassResidual','injectorMassResidual'])<1e-7, f'{name}: plant mass balances')
    require(all(sum(r[f'plant.solenoidOpening[{j}]']>1e-9 for j in [1,2,3])<=1 for r in rows), f'{name}: exclusive NC commands')
    for branch in ['prewash','soap','wax']:
        prefix = 'plant.'+branch+'.'
        require(all(r[prefix+'checkValve.m_flow']>=-1e-10 for r in rows), f'{name}/{branch}: check blocks reverse flow')
        require(max(abs(r[prefix+'tankDraw']-r[prefix+'m_flow']-r[prefix+'beforeCheck.storageRate']-r[prefix+'afterCheck.storageRate']) for r in rows)<1e-7, f'{name}/{branch}: branch storage conserves mass')
        require(all(abs(r[prefix+'solenoid.m_flow'])<1e-10 for r in rows if r[prefix+'solenoid.u']==0), f'{name}/{branch}: closed NC stops tank extraction')
    require(all(not r['plant.throatLimited'] for r in rows), f'{name}: throat floor never clips pressure')
    require(max(r['plant.inletHeater.T'] for r in rows)<323.16, f'{name}: washer inlet temperature within configured limit')

require(abs(vented[-1]['plant.soap.tank.gasPressure']-101325)<1e-4, 'Vented: headspace remains atmospheric')
require(max(r['branch.valveOutletPressure'] for r in protected) < 110000, 'Healthy branch check: imposed manifold HP does not reach NC')
require(at(failed,14)['branch.valveOutletPressure'] > 12e6, 'Failed branch check: manifold HP reaches closed NC outlet')
require(all(abs(r['branch.solenoid.m_flow'])<1e-10 for r in failed if r['time']>2.01), 'Failed-check test: NC stays closed while reverse differential rises')

samples = {}
for t,label in [(9,'HP rinse'),(18,'prewash LP'),(33,'soap LP'),(48,'wax LP'),(58,'closed gun')]:
    r = at(cycle,t)
    samples[label] = {'time':r['time'],
       'venturiInlet_bar_g':gauge(r['plant.injectorInletPressure']),
       'venturiOutlet_bar_g':gauge(r['plant.injectorOutletPressure']),
       'throat_bar_g':gauge(r['plant.throatPressure']),
       'manifold_bar_g':gauge(r['plant.chemicalManifoldPressure']),
       'water_L_min':r['plant.waterFlow_L_min'],
       'branches':{b:{'NC_inlet_bar_g':gauge(r['plant.'+b+'.valveInletPressure']),
                       'NC_outlet_bar_g':gauge(r['plant.'+b+'.valveOutletPressure']),
                       'NC_delta_bar':r['plant.'+b+'.valveDifferentialPressure']/1e5,
                       'tankDraw_L_min':r['plant.'+b+'.tankDraw']/995.586*60000}
                   for b in ['prewash','soap','wax']}}
envelopes = {b:{'inlet_bar_g':[min(gauge(r['plant.'+b+'.valveInletPressure']) for r in cycle),max(gauge(r['plant.'+b+'.valveInletPressure']) for r in cycle)],
                'outlet_bar_g':[min(gauge(r['plant.'+b+'.valveOutletPressure']) for r in cycle),max(gauge(r['plant.'+b+'.valveOutletPressure']) for r in cycle)],
                'delta_bar':[min(r['plant.'+b+'.valveDifferentialPressure']/1e5 for r in cycle),max(r['plant.'+b+'.valveDifferentialPressure']/1e5 for r in cycle)]}
             for b in ['prewash','soap','wax']}
vented_tank = {'gas_bar_g':gauge(vented[-1]['plant.soap.tank.gasPressure']),
               'dose_L_min':vented[-1]['plant.soap.tankDraw']/995.586*60000}
faults = {name:{'NC_outlet_bar_g':gauge(at(rows,14)['branch.valveOutletPressure']),
                'NC_delta_bar':at(rows,14)['branch.valveDifferentialPressure']/1e5}
          for name,rows in [('branch_check_healthy',protected),('branch_check_failed',failed)]}
report = {'source_sha256':hashlib.sha256((root.parent/'autolavado.mo').read_bytes()).hexdigest(),
          'passed':sum(c['passed'] for c in checks),'failed':sum(not c['passed'] for c in checks),
          'checks':checks,'samples':samples,'NC_envelopes':envelopes,'vented_tank':vented_tank,'faults':faults}
(results/'injection-validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:report[k] for k in ['passed','failed','NC_envelopes','vented_tank','faults']},indent=2))
for c in checks:
    if not c['passed']:
        print('FAIL:',c['check'])
raise SystemExit(bool(report['failed']))

