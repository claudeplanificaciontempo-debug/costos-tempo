# -*- coding: utf-8 -*-
# Paginas donde el PDF numera CADA COLOR: cada referencia es un producto aparte.
# (ref, color, posicion en el tablero 0..5)
PORCOLOR = {
 25:[('7460','BRIGHT WHITE',0),('7461','CRUDO',1),('7462','ARENA',2),
     ('7463','PEACH WHIP',3),('7464','SPA RETREAT',4),('7465','AERO MIDNIGHT',5)],
 27:[('7450','BRIGHT WHITE',0),('7451','CRUDO',1),('7452','GRIS JASPE LHG',2),
     ('7453','AERO MIDNIGHT',3),('7454','SPA RETREAT',4),('7455','ACRYLIC PURPLE',5)],
 35:[('7460-2','BRIGHT WHITE',0),('7461-2','CRUDO',1),('7462-2','ARENA',2),
     ('7463-2','AERO MIDNIGHT',3),('7464-2','WINE',4),('7465-2','OLIVE GREEN',5)],
 37:[('7470','BRIGHT WHITE',0),('7471','CRUDO',1),('7472','ARENA',2),
     ('7473','AERO MIDNIGHT',3),('7474','SPA RETREAT',4),('7475','PEACH WHIP',5)],
 39:[('7480','BRIGHT WHITE',0),('7481','CRUDO',1),('7482','ARENA',2),
     ('7483','AERO MIDNIGHT',3),('7484','SPA RETREAT',4),('7485','PEACH WHIP',5)],
 43:[('7506','BRIGHT WHITE',0),('7507','CRUDO',1),('7508','ARENA',2),
     ('7509','AERO MIDNIGHT',3),('7510','SPA RETREAT',4),('7511','PEACH WHIP',5)],
}
# geometria del tablero para recortar cada prenda
GRID_A = ([(0.405,0.565),(0.565,0.725),(0.725,0.885)],[(0.06,0.47),(0.50,0.91)])   # pags 1,3,5
GRID_B = ([(0.325,0.475),(0.475,0.625),(0.625,0.775)],[(0.07,0.50),(0.51,0.94)])   # pags 25,27,35,37,39,43
