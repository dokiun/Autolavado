"""Validate the current two-nozzle simulation without legacy reference values."""
import csv
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESULT = ROOT / 'verification/current/CurrentCycle_res.csv'
samples = {}
mass_error = energy_error = 0.0
maximum_overlap = 0
end = 0
with RESULT.open(newline='') as stream:
    for row in csv.DictReader(stream):
        time = float(row['time'])
        assert all(math.isfinite(float(v)) for v in row.values()), 'Nonfinite result'
        end = max(end, time)
        mass_error = max(mass_error, abs(float(row['plant.mainMassResidual'])), abs(float(row['plant.chemicalMassResidual'])))
        energy_error = max(energy_error, abs(float(row['plant.inletHeater.energyResidual'])))
        openings = [float(row[f'plant.controller.chemicalOpening[{i}]']) for i in (1, 2, 3)]
        assert all(0 <= opening <= 1 for opening in openings)
        maximum_overlap = max(maximum_overlap, sum(opening > 1e-6 for opening in openings))
        if time in (9, 18, 33, 48, 55, 58, 64):
            samples[time] = row
assert end == 64 and len(samples) == 7, 'Incomplete cycle'
assert mass_error < 1e-6 and energy_error < 1e-4, 'Conservation residual'
assert maximum_overlap <= 1, 'Simultaneous chemical valves'
results = {}
for time, branch in ((18, 'prewash'), (33, 'soap'), (48, 'wax')):
    row = samples[time]
    flow = float(row['plant.injector.mChemical']) * 60000 / 995.586
    assert flow > 0.01, 'No chemical aspiration'
    assert float(row[f'plant.{branch}.solenoid.opening']) > 0.99
    assert float(row['plant.gun.activeNozzleDiameter']) == 0.0046
    assert float(row['plant.chemicalInjectionBlocked']) == 0
    assert float(row['plant.injector.throatLimited']) == 0
    assert float(row[f'plant.{branch}.tankDraw']) > 0
    results[branch] = {'time_s': time, 'chemical_L_min': flow, 'throat_bar_g': (float(row['plant.throatPressure'])-101325)/1e5}
for time in (9, 55):
    assert float(samples[time]['plant.gun.activeNozzleDiameter']) == 0.00115
    assert abs(float(samples[time]['plant.injector.mChemical'])) < 1e-9
assert abs(float(samples[58]['plant.outletFlow_L_min'])) < 1e-6
report = {
    'model_sha256': hashlib.sha256((ROOT/'autolavado.mo').read_bytes()).hexdigest(),
    'results': results,
    'mass_residual_max_kg_s': mass_error,
    'heater_energy_residual_max_W': energy_error,
    'maximum_simultaneous_open_branches': maximum_overlap,
    'status': 'passed',
    'limitations': 'Low nozzle diameter, Cd and injector hydraulic coefficients are design assumptions, not a calibrated commercial curve.',
}
destination = ROOT/'verification/results/current-validation.json'
destination.parent.mkdir(exist_ok=True)
destination.write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
