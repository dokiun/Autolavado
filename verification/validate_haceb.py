"""Validate independent gas heater at 13 C inlet, full manual gas and safety events."""
import csv
import hashlib
import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parent
build = root / 'build'
result_dir = root / 'results'
result_dir.mkdir(exist_ok=True)
checks = []
results = {}

def require(ok, label):
    checks.append({'passed': bool(ok), 'check': label})

def load(name, end, prefix='heater.'):
    variables = {v.get('name'): v for v in ET.parse(build / f'{name}_init.xml').findall('.//ScalarVariable')}
    class Row(dict):
        def __missing__(self, key):
            v = variables[key]
            if v.get('alias') in ('alias', 'negatedAlias'):
                value = self[v.get('aliasVariable')]
                return -value if v.get('alias') == 'negatedAlias' else value
            scalar = next(iter(v))
            if v.get('variability') in ('parameter', 'constant') and 'start' in scalar.attrib:
                return float({'true': '1', 'false': '0'}.get(scalar.get('start'), scalar.get('start')))
            raise KeyError(key)
    with (build / f'{name}_res.csv').open(encoding='utf-8-sig') as stream:
        rows = [Row({k: float(v) for k, v in r.items()}) for r in csv.DictReader(stream)]
    require(abs(rows[-1]['time'] - end) < 1e-6, f'{name}: completes {end}s')
    require(all(math.isfinite(v) for r in rows for v in r.values()), f'{name}: finite values')
    require(all(-1e-8 <= r[prefix+'gasPower'] <= 12000.00001 for r in rows), f'{name}: gas input bounded by 12 kW')
    require(all(-1e-8 <= r[prefix+'heaterPower'] <= 10200.00001 for r in rows), f'{name}: combustion heat bounded by assumed efficiency')
    require(all(abs(r[prefix+'gasPower']) < 1e-8 for r in rows if not r[prefix+'gasValveOpen']), f'{name}: closed valve stops gas')
    require(all(abs(r[prefix+'heaterPower']) < 1e-8 for r in rows if not r[prefix+'burnerLit']), f'{name}: no combustion heat without proved flame')
    residuals = []
    for r in rows:
        # Independent calorimetric balance for forward-flow tests; medium cp is constant.
        # Every test boundary fixes 13 C; OMC may eliminate the calculated inlet parameter.
        inlet = r.get(prefix+'inletTemperature', 286.15)
        advective = r[prefix+'m_flow']*4184*(inlet-r[prefix+'T'])
        stored = 1500*r['der('+prefix+'metalTemperature)'] + 995.586*0.0003*4184*r['der('+prefix+'T)']
        residuals.append(stored-r[prefix+'heaterPower']+r[prefix+'ambientLoss']-advective)
    require(max(map(abs, residuals)) < 0.1, f'{name}: independent water + metal energy balance < 0.1 W')
    require(all(abs(r[prefix+'port_a.m_flow']+r[prefix+'port_b.m_flow']) < 1e-9 for r in rows), f'{name}: conserves mass')
    results[name] = {'outletTemperature_C': rows[-1][prefix+'T']-273.15,
                     'maxOutletTemperature_C': max(r[prefix+'T'] for r in rows)-273.15}
    return rows

def at(rows, t):
    return min(rows, key=lambda r: abs(r['time']-t))

plant = load('HacebPlant', 30, 'plant.inletHeater.')
cycle = load('HacebCycle', 64, 'plant.inletHeater.')
require(any(r['plant.inletHeater.gasPower'] == 12000 for r in cycle), 'Cycle: manual heater reaches full rated gas input')
require(all(abs(r['plant.accumulator.heaterPower']) < 1e-8 for r in plant), 'Plant: high-pressure accumulator never heats')
require(max(r['plant.inletHeater.T'] for r in plant) <= 323.16, 'Plant: inlet stays within declared 50 C limit')
require(plant[-1]['plant.inletHeater.T'] > 286.15, 'Plant: gas heater raises inlet temperature')
require(plant[-1]['plant.inletHeater.gasPower'] == 12000, 'Plant: manual adjustment at full power')
full = load('HacebFull', 120)
require(full[-1]['heater.burnerLit'] == 1 and full[-1]['heater.gasPower'] == 12000, 'Full: steady operation at maximum manual gas setting')
for name in ['HacebFlame', 'HacebVent']:
    rows = load(name, 40)
    require(at(rows, 12)['heater.safetyLocked'] == 1 and at(rows, 12)['heater.gasPower'] == 0, f'{name}: fault closes gas and latches')
    require(at(rows, 22)['heater.gasPower'] == 0, f'{name}: fault clearance alone does not reopen gas')
    require(at(rows, 30)['heater.burnerLit'] == 1, f'{name}: explicit reset permits restart')
overheat = load('HacebOverheat', 120)
require(any(r['heater.safetyLocked'] for r in overheat), 'Overheat: trips temperature interlock')
require(overheat[-1]['heater.gasPower'] == 0, 'Overheat: gas remains isolated')
low = load('HacebLowFlow', 40)
require(all(r['heater.gasPower'] == 0 for r in low), 'Low flow: never ignites below threshold')
power = load('HacebPower', 120)
require(power[-1]['heater.T'] < 332.15, 'Power: cannot impose 60 C when available heat is insufficient')
require(abs(power[-1]['heater.gasPower'] - 12000) < 1e-6, 'Power: demand saturates at rated gas input')
report = {'source_sha256': hashlib.sha256((root.parent/'autolavado.mo').read_bytes()).hexdigest(),
          'passed': sum(c['passed'] for c in checks), 'failed': sum(not c['passed'] for c in checks), 'checks': checks, 'results': results}
(result_dir/'haceb-validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({k: report[k] for k in ['passed', 'failed', 'results']}, indent=2))
for c in checks:
    if not c['passed']:
        print('FAIL:', c['check'])
raise SystemExit(bool(report['failed']))


