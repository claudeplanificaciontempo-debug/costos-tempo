# -*- coding: utf-8 -*-
import csv, sys, re
sys.path.insert(0,'/home/user/costos-tempo/consolidado')
from estilos import E

DEP, MARCA, COL, TEMP, ANIO = 'Mujer','Aeropostale','SPRING 2027','Spring','2027'

fich={}
for l in open('notas_fichas.txt'):
    p=[x.strip() for x in l.strip().split('|')]
    if len(p)>=5: fich[int(p[0])]={'tela':p[1],'cart':p[2],'ins':p[3],'det':p[4]}
looks={}
for l in open('notas_looks.txt'):
    if l.startswith('#') or not l.strip(): continue
    p=[x.strip() for x in l.split('|')]
    looks[int(p[0])]={'titulo':p[1],'colores':p[3]}

# --- consumo mediano medido en las fichas YA CERRADAS de Martha ---
CONS={  # (categoria, tipo) -> [(descripcion material, consumo, um, nota)]
 ('CAMISETAS','Fashion Graphics'):[('tela principal',0.180,'kg'),('ribb de cuello',0.020,'kg')],
 ('CAMISETAS','Camiseta CR'):[('tela principal',0.180,'kg'),('ribb de cuello',0.020,'kg')],
 ('CAMISETAS','Camiseta CV'):[('tela principal',0.185,'kg'),('ribb de cuello',0.020,'kg')],
 ('CAMISETAS','Camiseta ML'):[('tela principal',0.240,'kg'),('ribb de cuello y puños',0.030,'kg')],
 ('CAMISETAS','Camiseta Corte Moda'):[('tela principal',0.185,'kg'),('ribb de cuello',0.020,'kg')],
 ('CAMISETAS','Basica Crop'):[('tela principal',0.150,'kg'),('ribb de cuello',0.020,'kg')],
 ('CAMISETAS','Oversize'):[('tela principal',0.245,'kg'),('ribb de cuello',0.025,'kg')],
 ('POLOS','Polo Basica'):[('tela principal',0.270,'kg'),('cuello tejido',1,'u'),('puños tejidos',2,'u')],
 ('POLOS','Polo Moda'):[('tela principal',0.230,'kg'),('cuello tejido',1,'u')],
 ('FITS','Bare Tiras'):[('tela principal',0.130,'kg')],
 ('FITS','Bare Top'):[('tela principal',0.170,'kg')],
 ('FITS','Bare BVD'):[('tela principal',0.170,'kg')],
 ('FITS','Fit Moda'):[('tela principal',0.180,'kg')],
 ('BVD','BVD'):[('tela principal',0.138,'kg')],
 ('BODY','Body'):[('tela principal',0.245,'kg')],
 ('HENLEY','Henley MC'):[('tela principal',0.215,'kg'),('ribb de cuello',0.020,'kg')],
 ('HENLEY','Henley ML'):[('tela principal',0.250,'kg'),('ribb de cuello y puños',0.030,'kg')],
 ('FLEECE BASICO','Crew'):[('tela principal',0.390,'kg'),('ribb 2x2 grueso',0.170,'kg')],
 ('FLEECE PESADO','Crew Zip'):[('tela principal',0.520,'kg'),('ribb 2x2 grueso',0.065,'kg')],
 ('HODDIE','Hoodies'):[('tela principal',0.535,'kg'),('ribb 2x2 grueso',0.170,'kg')],
 ('JOGGER','Jogger'):[('tela principal',0.520,'kg'),('ribb 2x2',0.060,'kg')],
 ('JOGGER','Jogger Moda'):[('tela principal',0.270,'kg')],
 ('SHORT FLEECE','Short Fleece Basico'):[('tela principal',0.250,'kg')],
 ('SHORT FLEECE','Short Fleece Moda'):[('tela principal',0.250,'kg')],
 ('SHORT PLANOS','Short Basico'):[('tela principal',0.650,'m')],
 ('SHORT PLANOS','Short Moda'):[('tela principal',0.970,'m')],
 ('PANTALONES PLANOS','Pantalon Basico'):[('tela principal',1.350,'m')],
 ('PANTALONES PLANOS','Pantalon Moda'):[('tela principal',1.170,'m')],
 ('FALDAS','Faldas'):[('tela principal',0.300,'kg')],
}
MIN={'CAMISETAS':5,'POLOS':12,'FITS':6.5,'BVD':6,'BODY':14,'HENLEY':11,'FLEECE BASICO':11,
 'FLEECE PESADO':16,'HODDIE':15,'JOGGER':11,'SHORT FLEECE':12,'SHORT PLANOS':17,
 'PANTALONES PLANOS':14,'FALDAS':10}
PUNT={'CAMISETAS':2561,'POLOS':1200,'FLEECE BASICO':6325,'FLEECE PESADO':3133,'HODDIE':5600,
 'JOGGER':5566,'BVD':2725,'HENLEY':2561,'BODY':2561,'FITS':2561,'FALDAS':2561,
 'SHORT FLEECE':2561,'SHORT PLANOS':4237,'PANTALONES PLANOS':4230}
BASE='HILO PARA COSER; ETIQUETAS TALLAS; ETIQUETA DE LAVADO; CARTONERIA'

prod=[]; sinref=[]; cons=[]; telas={}
for pag in sorted(E):
    f=fich.get(pag+1,{'tela':'','cart':'','ins':'','det':''})
    for (ref,nom,cat,tipo,refcol) in E[pag]:
        fila=[ref,nom,cat,tipo,DEP,MARCA,COL]
        (prod if ref else sinref).append(fila+[f'pag {pag}', refcol, looks[pag]['colores']])
        telas.setdefault(f['tela'],[]).append(ref or f'(pag {pag})')
        rec=CONS.get((cat,tipo),[('tela principal',0.200,'kg')])
        det=f['det'].upper()
        dec=[]
        if 'BORDADO' in det: dec.append(f"BORDADO {PUNT.get(cat,2561)} puntadas (mediana {cat})")
        if 'ESTAMPAD' in det: dec.append('ESTAMPADO (elegir la serigrafia segun tamaño)')
        if 'LAVAD' in det: dec.append('LAVADO DE PRENDA')
        if 'TINTURAD' in det: dec.append('TINTURADO')
        cons.append({'referencia':ref or 'SIN REFERENCIA','producto':nom,'categoria':cat,'tipo':tipo,
          'pagina_pdf':pag,'tela_segun_pdf':f['tela'],
          'consumo_estimado':' + '.join(f"{d} {c} {u}" for d,c,u in rec),
          'insumos_segun_pdf':f['ins'],'insumos_base_tempo':BASE,
          'decoracion_servicios':'; '.join(dec) or '-',
          'minutos_confeccion':MIN.get(cat,10),
          'cartoneria_fit_pdf':f['cart'],'detalles_pdf':f['det'],
          'fuente_consumo':f"mediana de las fichas cerradas de {cat} / {tipo}"})

def esc(r): return r
with open('1_productos.csv','w',newline='',encoding='utf-8-sig') as fh:
    w=csv.writer(fh,delimiter=';')
    w.writerow(['Referencia','Nombre','Categoria','Tipo','Departamento','Marca','Coleccion','(pagina)','(refs de color)','(colores)'])
    w.writerows(prod)
with open('2_productos_SIN_REFERENCIA.csv','w',newline='',encoding='utf-8-sig') as fh:
    w=csv.writer(fh,delimiter=';')
    w.writerow(['Referencia (PONER)','Nombre','Categoria','Tipo','Departamento','Marca','Coleccion','(pagina)','(refs de color)','(colores)'])
    w.writerows(sinref)
with open('3_consumos_estimados.csv','w',newline='',encoding='utf-8-sig') as fh:
    w=csv.DictWriter(fh,fieldnames=list(cons[0].keys()),delimiter=';'); w.writeheader(); w.writerows(cons)
with open('4_telas_del_pdf.csv','w',newline='',encoding='utf-8-sig') as fh:
    w=csv.writer(fh,delimiter=';'); w.writerow(['Tela segun el PDF','Veces','Referencias'])
    for t,rs in sorted(telas.items(), key=lambda x:-len(x[1])):
        w.writerow([t,len(rs),', '.join(rs)])
print('productos con ref:',len(prod),'| sin ref:',len(sinref),'| telas distintas:',len(telas))
