# -*- coding: utf-8 -*-
import sys, csv
sys.path.insert(0,'/home/user/costos-tempo/consolidado')
from estilos import E
from estilos2 import NUEVOS, PUESTAS, TELA, YA
from armar import CONS, MIN, PUNT, BASE   # reusa las medianas medidas
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

filas=[]
for pagina in sorted(E):
    f=fich.get(pagina+1,{'tela':'','cart':'','ins':'','det':''})
    if pagina in NUEVOS:
        est=[(r,n,'CAMISETAS','Fashion Graphics','',c,pos) for (r,n,c,pos) in NUEVOS[pagina]]
    else:
        puestas=PUESTAS.get(pagina,[])
        est=[]
        for k,(ref,nom,cat,tipo,rc) in enumerate(E[pagina]):
            if not ref and k<len(puestas): ref=puestas[k]
            est.append((ref,nom,cat,tipo,rc,'',None))
    for (ref,nom,cat,tipo,rc,color,pos) in est:
        rec=CONS.get((cat,tipo),[('tela principal',0.200,'kg')])
        det=f['det'].upper(); dec=[]
        if 'BORDADO' in det: dec.append(f"BORDADO {PUNT.get(cat,2561)} puntadas")
        if 'ESTAMPAD' in det: dec.append('ESTAMPADO')
        if 'LAVAD' in det: dec.append('LAVADO DE PRENDA')
        if 'TINTURAD' in det: dec.append('TINTURADO')
        filas.append({'Referencia':ref,'Nombre':nom,'Categoria':cat,'Tipo':tipo,
          'Departamento':DEP,'Marca':MARCA,'Coleccion':COL,
          'pagina':pagina,'color':color or looks[pagina]['colores'],'refs_color':rc,
          'ya_existe':YA.get(ref,''),'pos':pos,
          'tela_pdf':f['tela'],'tela_tempo':TELA.get(f['tela'],'REVISAR'),
          'consumo':' + '.join(f"{d} {c} {u}" for d,c,u in rec),
          'insumos_pdf':f['ins'],'insumos_base':BASE,'decoracion':'; '.join(dec) or '-',
          'minutos':MIN.get(cat,10),'cartoneria_fit':f['cart'],'detalles_pdf':f['det']})
print('productos:',len(filas),'| sin referencia:',sum(1 for x in filas if not x['Referencia']),
      '| ya existen:',sum(1 for x in filas if x['ya_existe']))
import json; json.dump(filas,open('filas.json','w'))
