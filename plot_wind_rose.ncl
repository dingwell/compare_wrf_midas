;***************************************
; based on example: rose_4.ncl
;***************************************
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl" 
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/wind_rose.ncl"
load "$WRF_MIDAS_ROOT/utilities.ncl"
load "./auto_presets.ncl"
;***************************************

;PRESETS
fname="$MIDAS_DATA_DIR/$STATION"
;type="x11"
type="eps"

begin
;***************************************
; Read midas data
;***************************************
  data  = read_midas_data(fname)
  station = tostring(data@stn_id)
  
  wdir  = data(1,0:)
  wspd  = data(2,0:)*0.51444444444 ;knots to m/s
                                  
  wspd@long_name = "Wind Speed"
  wspd@units     = "m/s"
  ;wspd@_FillValue= nan
  wdir@long_name = "Wind Direction"
  wdir@units     = "degrees"
  ;printVarSummary(wdir)
  ;print(stddev(wspd))
  ;print(num(wspd.eq.0.))
  ;print(num(.not.ismissing(wspd)))
  ;print(tofloat(num(wspd.eq.0.))/num(.not.ismissing(wspd)))
  ;print(wspd)

;******************************
; specify plot arguments
;******************************
  numPetals =  8                    ; N, NE, E, SE, S, SW, W, NW
  circFr    = 10. 
  spdBounds = (/ 10., 20., 30., 100. /)
  colorBounds = (/ "blue", "green", "yellow", "red" /)
;******************************
; generate panel plot
;******************************
  wks = gsn_open_wks(type,station)
  plot = new (4, graphic)

  res          = True
  res@gsnDraw  = False
  res@gsnFrame = False
;******************************
; create first plot
;******************************
  res@tiMainString  = "Wind Rose: Basic"
  plot(0)           = WindRoseBasic (wks,wspd,wdir,numPetals,circFr,res)
;******************************
; create second plot
;******************************
  res@tiMainString  = "Wind Rose: Variable Line Thickness"
  plot(1)           = WindRoseThickLine (wks,wspd,wdir,numPetals \
                                         ,circFr,spdBounds,res)
;******************************
; create third plot
;******************************
  res@tiMainString  = "Wind Rose: Color + Variable Thickness"
  plot(2)           = WindRoseColor (wks,wspd,wdir,numPetals \
                          ,circFr,spdBounds,colorBounds,res)
;******************************
; create fourth plot
;******************************
  numPetals         =  4                    ; N, E, S, W
  res@tiMainString  = "Wind Rose: numPetals="+numPetals
  plot(3)           = WindRoseColor (wks,wspd,wdir,numPetals \
                          ,circFr,spdBounds,colorBounds,res)
;******************************
; create panel plot
;******************************
  gsn_panel (wks, plot, (/2,2/), False)
end

