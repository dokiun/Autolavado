"""Generate README figures directly from the current Modelica CSV."""
import csv
import hashlib
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parent.parent
source = ROOT/'verification/current/CurrentCycle_res.csv'
evidence = json.loads((ROOT/'verification/results/current-validation.json').read_text())
assert evidence['model_sha256'] == hashlib.sha256((ROOT/'autolavado.mo').read_bytes()).hexdigest(), 'Validate the current model before plotting'
keys = ['plant.injectorInletPressure', 'plant.injectorOutletPressure', 'plant.throatPressure',
        'plant.chemicalManifoldPressure', 'plant.inletHeater.T', 'plant.outletTemperature',
        'plant.waterFlow_L_min', 'plant.outletFlow_L_min', 'plant.injector.mChemical',
        'plant.prewash.tankDraw', 'plant.soap.tankDraw', 'plant.wax.tankDraw']
series = {k: [] for k in ['time']+keys}
with source.open(newline='') as stream:
    for row in csv.DictReader(stream):
        for key in series:
            series[key].append(float(row[key]))
time = series['time']
assert time[-1] == 64
destination = ROOT/'docs/figures'
destination.mkdir(parents=True, exist_ok=True)
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'axes.spines.top':False,
                     'axes.spines.right':False,'axes.titleweight':'bold','figure.facecolor':'white'})
stages = [(10,20,'Prelavado','#e8f2fc'),(25,35,'Jabón','#e9f5ec'),(40,50,'Cera','#fff1d8')]

def finish(fig, axes, name):
    for ax in axes:
        ax.set_xlim(0,64)
        ax.grid(alpha=.2)
        ax.set_xlabel('Tiempo [s]')
        for begin,end,label,color in stages:
            ax.axvspan(begin,end,color=color,zorder=0)
            ax.text((begin+end)/2,1.01,label,transform=ax.get_xaxis_transform(),ha='center',fontsize=9)
        ax.legend(loc='best',frameon=False)
    fig.savefig(destination/name,dpi=160,bbox_inches='tight')
    plt.close(fig)

fig,axes = plt.subplots(2,1,figsize=(12,8),layout='constrained')
for key,label in [('plant.injectorInletPressure','Entrada Venturi'),('plant.injectorOutletPressure','Salida Venturi'),('plant.throatPressure','Garganta')]:
    axes[0].plot(time,[(p-101325)/1e5 for p in series[key]],label=label,lw=1.7)
axes[0].set_title('Presiones del circuito · alta y baja presión',pad=28)
axes[0].set_ylabel('Presión [bar(g)]')
for key,label in [('plant.throatPressure','Garganta'),('plant.chemicalManifoldPressure','Manifold químico')]:
    axes[1].plot(time,[(p-101325)/1e5 for p in series[key]],label=label,lw=1.7)
axes[1].axhline(0,color='#555',lw=.8,ls='--')
axes[1].set_ylim(-.85,.2)
axes[1].set_title('Detalle de aspiración · valores fuera del rango vertical no se muestran',pad=28)
axes[1].set_ylabel('Presión [bar(g)]')
finish(fig,axes,'presiones.png')

fig,axes = plt.subplots(2,1,figsize=(12,8),layout='constrained')
for key,label in [('plant.waterFlow_L_min','Agua'),('plant.outletFlow_L_min','Descarga de mezcla')]:
    axes[0].plot(time,series[key],label=label,lw=1.7)
axes[0].set_title('Caudal principal · incluye transitorios al cambiar boquilla',pad=28)
axes[0].set_ylabel('Caudal [L/min]')
for key,label in [('plant.prewash.tankDraw','Prelavado: desde tanque'),('plant.soap.tankDraw','Jabón: desde tanque'),('plant.wax.tankDraw','Cera: desde tanque'),('plant.injector.mChemical','Total: entrada al inyector')]:
    axes[1].plot(time,[q*60000/995.586 for q in series[key]],label=label,lw=1.7,ls='--' if key.endswith('mChemical') else '-')
axes[1].set_title('Aspiración química · selección exclusiva y purga previa',pad=28)
axes[1].set_ylabel('Caudal químico [L/min]')
finish(fig,axes,'caudales.png')

fig,ax = plt.subplots(figsize=(12,5),layout='constrained')
for key,label in [('plant.inletHeater.T','Salida del calentador'),('plant.outletTemperature','Agua en descarga')]:
    ax.plot(time,[t-273.15 for t in series[key]],label=label,lw=2)
ax.plot([0,64],[13,13],ls=':',color='#555',label='Suministro: 13 °C')
ax.axvspan(57,64,color='#eee',zorder=0)
ax.text(60.5,.05,'Pistola cerrada\nAgua retenida',transform=ax.get_xaxis_transform(),ha='center',fontsize=9)
ax.set_title('Temperaturas del ciclo · calentador al máximo',pad=28)
ax.set_ylabel('Temperatura [°C]')
finish(fig,[ax],'temperaturas.png')
print('Figures:',destination)
