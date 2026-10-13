# -*- coding: utf-8 -*-
import sys, json
sys.path.insert(0,'/home/user/costos-tempo/consolidado')
from estilos import E
from estilos2 import NUEVOS, PUESTAS, TELA, YA
from estilos3 import PORCOLOR
from armar import CONS, MIN, PUNT, BASE
DEP,MARCA,COL='Mujer','Aeropostale','SPRING 2027'
fich={}
for l in open('notas_fichas.txt'):
    p=[x.strip() for x in l.strip().split('|')]
    if len(p)>=5: fich[int(p[0])]={'tela':p[1],'cart':p[2],'ins':p[3],'det':p[4]}
looks={}
for l in open('notas_looks.txt'):
    if l.startswith('#') or not l.strip(): continue
    p=[x.strip() for x in l.split('|')]
    looks[int(p[0])]={'colores':p[3]}

def refinal(r):
    """las referencias que ya estan en el sistema entran con -1; se deja la original quieta"""
    base=r[:-2] if r.endswith('-2') else r
    if base in YA and r==base: return base+'-1', YA[base]
    if base in YA: return r, YA[base]
    return r, ''

filas=[]
for pagina in sorted(E):
    f=fich.get(pagina+1,{'tela':'','cart':'','ins':'','det':''})
    est=[]
    if pagina in NUEVOS:
        est=[(r,n,'CAMISETAS','Fashion Graphics',c,pos,'A') for (r,n,c,pos) in NUEVOS[pagina]]
    elif pagina in PORCOLOR:
        base=E[pagina][0]
        for (r,color,pos) in PORCOLOR[pagina]:
            est.append((r,f"{base[1]} {color}",base[2],base[3],color,pos,'B'))
    else:
        puestas=PUESTAS.get(pagina,[])
        for k,(ref,nom,cat,tipo,rc) in enumerate(E[pagina]):
            if not ref and k<len(puestas): ref=puestas[k]
            est.append((ref,nom,cat,tipo,looks[pagina]['colores'],None,None))
    for (ref,nom,cat,tipo,color,pos,grid) in est:
        ref2,viejo=refinal(ref)
        rec=CONS.get((cat,tipo),[('tela principal',0.200,'kg')])
        det=f['det'].upper(); dec=[]
        if 'BORDADO' in det: dec.append(f"BORDADO {PUNT.get(cat,2561)} puntadas")
        if 'ESTAMPAD' in det: dec.append('ESTAMPADO')
        if 'LAVAD' in det: dec.append('LAVADO DE PRENDA')
        if 'TINTURAD' in det: dec.append('TINTURADO')
        filas.append({'Referencia':ref2,'Nombre':nom,'Categoria':cat,'Tipo':tipo,'Departamento':DEP,
          'Marca':MARCA,'Coleccion':COL,'pagina':pagina,'color':color,'ref_pdf':ref,'ya_existe':viejo,
          'pos':pos,'grid':grid,'tela_pdf':f['tela'],'tela_tempo':TELA.get(f['tela'],'REVISAR'),
          'consumo':' + '.join(f"{d} {c} {u}" for d,c,u in rec),'insumos_pdf':f['ins'],
          'insumos_base':BASE,'decoracion':'; '.join(dec) or '-','minutos':MIN.get(cat,10),
          'cartoneria_fit':f['cart'],'detalles_pdf':f['det']})
json.dump(filas,open('filas.json','w'))
refs=[x['Referencia'] for x in filas]
print('productos:',len(filas),'| referencias repetidas:',[r for r in set(refs) if refs.count(r)>1],
      '| con -1:',sum(1 for r in refs if r.endswith('-1')))

# --- ninguna referencia puede repetirse: la segunda vez lleva -2, -3 ... ---
vistos={}
for f in filas:
    r=f['Referencia']
    if r in vistos:
        k=2
        while f"{r}-{k}" in vistos: k+=1
        f['Referencia']=f"{r}-{k}"
    vistos[f['Referencia']]=1
json.dump(filas,open('filas.json','w'))
refs=[x['Referencia'] for x in filas]
assert len(refs)==len(set(refs))
print('OK sin repetidas:',len(refs),'productos')
