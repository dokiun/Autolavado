"""Export pressure and dose evidence with vented chemical tanks."""
import csv
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root = Path(__file__).resolve().parent

build = root / 'build'
results = root / 'results'
results.mkdir(exist_ok=True)

def load(name):
    with (build/f'{name}_res.csv').open(encoding='utf-8-sig') as stream:
        return [{k:float(v) for k,v in row.items()} for row in csv.DictReader(stream)]

cycle = load('InjectionCycle')
vented = load('InjectionVented')
fig, axes = plt.subplots(3,1,figsize=(11,10),layout='constrained')
time = [r['time'] for r in cycle]
for key,label in [('injectorInletPressure','Entrada Venturi'),('injectorOutletPressure','Salida Venturi'),('throatPressure','Garganta')]:
    axes[0].plot(time,[(r['plant.'+key]-101325)/1e5 for r in cycle],label=label)
axes[0].set(title='Circuito principal: alta presión y modo de dosificación',ylabel='Presión [bar manométricos]',xlabel='Tiempo [s]')
axes[0].legend(loc='upper right')
axes[1].plot(time,[(r['plant.chemicalManifoldPressure']-101325)/1e5 for r in cycle],label='Manifold',color='black')
axes[1].plot(time,[(r['plant.soap.valveInletPressure']-101325)/1e5 for r in cycle],label='Entrada NC (jabón)',linestyle='--')
for branch,label in [('prewash','Salida NC prelavado'),('soap','Salida NC jabón'),('wax','Salida NC cera')]:
    axes[1].plot(time,[(r['plant.'+branch+'.valveOutletPressure']-101325)/1e5 for r in cycle],label=label,alpha=0.85)
axes[1].axhline(0,color='gray',linewidth=0.7)
axes[1].set(title='Aspiración: vacío y presión atrapada con checks sanos',ylabel='Presión [bar manométricos]',xlabel='Tiempo [s]')
axes[1].legend(loc='lower right',fontsize=8)
for rows,label in [(vented,'Tapa con respiradero')]:
    axes[2].plot([r['time'] for r in rows],[r['plant.soap.tankDraw']/995.586*60000 for r in rows],label=label)
axes[2].set(title='Extracción de jabón con respiradero (10 L de líquido iniciales)',ylabel='Caudal de tanque [L/min]',xlabel='Tiempo [s]')
axes[2].legend()
for ax in axes:
    ax.grid(alpha=0.25)
fig.suptitle('Modelo equivalente: sifón Ø interior 12,7 mm, 2 m, elevación 0,5 m',fontsize=13)
fig.savefig(results/'injection-pressure.png',dpi=160)
print(results/'injection-pressure.png')

