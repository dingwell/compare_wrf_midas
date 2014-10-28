; This script will load data from WRF output and midas      ;
; observation data.  WRF data will be interpolated to the   ;
; observation sites and performance tested in Taylor plots  ;
; A list of all data files named file_list_[name].txt must  ;
; exist in the working directory, where [name] is an        ;
; identifier for a specific set of data.                    ;
;                                                           ;
; Written by:                                               ;
;   Adam Dingwell, Uppsala University, 2012                 ;
;-----------------------------------------------------------;
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$WRF_MIDAS_ROOT/utilities.ncl"

load "./taylor_diagram.ncl" ; for Taylor diagrams
load "./auto_presets.ncl"     ; List of wrf-file-lists
;-----------------------------------------------------------;
begin;PRESETS;  
  ; The variables defined here are "global", for easy
  ; identification they are given names in all caps
  ; (Actually, all variables in NCL are global unless
  ;  stated otherwise)

  ; "u10dir" and "u10spd" are not in wrfout, in order to get
  ; these, we use get_wrf_u10dir and get_wrf_u10spd instead
  ; (included in this script
  VAR_WRF = (/"u10dir","u10spd","T2","td2","slp","PRECIP_H"/)
  ;VAR_MIDAS = (/6,7,16,17,18,20/)
  VAR_MIDAS = (/"WDir","WSpd","TAir","TDew","Pmsl","precip_hr_cnt"/)

  ; Observation times in MIDAS data:
  ; TIMES = (/ "00", "03", "06", "09", "12", "15", "18", "21" /)
  ; This is now set by compare_wrf_midas and uses numeric format, not string!

  ; Number of padding grid points required to include a station:
  PADDING = 10

  ; PATH settings:
  FNAME_MIDAS = "$MIDAS_DATA_DIR/station_list.dat"

  ; Misc settings:
  YEAR = START_DATE(0)

end;PRESETS;

; Structure of the rest of this script
; functions
; Number  Name                Desrciption
;   0     load_first_wrf      was used for testing, will be removed
;   1     indomain            check if LAT,LON is within WRF domain
;   2     read_station_list   read list of midas stns and coordinates
;   3     read_station_data   read corresponding stn data
;   4     get_wrf_var_in_ll   interpolate WRF data to given LAT,LON
;   5     get_wrf_u10dir      returns horizontal wind dir at 10 m
;   6     get_wrf_u10spd      returns horizontal wind speed at 10 m
;   7     ptaylor             plot taylor diagrams midas agains 1 WRF run
;
;   x     MAIN                the main program

; Function used to determine the closest WRF grid point for a given
; WRF netCDF file and a set ll-coordinates.  The function will return
; True or False.  Either a scalar or an array depending on input.
; Usage:
;   result = indomain(f,lon,lat)
; where:
;   f   is a file pointer
;   lat is a scalar or 1-D vector of latitude in degrees
;   lon is a scalar or 1-D vector of longitude in degrees
; Dimensions of lat and lon must match, this is not tested for!
undef("indomain")
function indomain(f_wrf,lon,lat)
local answer, ij, wrf,i,n
begin
  i = 0                   ; array index (iteration counter)
  n = dimsizes(lon)       ; number of points (lon should be 1-D array)
  answer = new(n,logical) ; True or false if point is within wrf-domain
  wrf=""                  ; Empty var, attributes will hold wrf-related values
  wrf@lat = wrf_user_getvar(f_wrf,"XLAT", 0)  ; get grid (lat-) coordinates
  wrf@n_ll= dimsizes(wrf@lat)                 ; get grid dimensions    
  wrf@ni  = wrf@n_ll(0)                       ; Points in x-dir (lon)
  wrf@nj  = wrf@n_ll(1)                       ; Points in y-dir (lat)

  ; Get closest grid points for given lon x lat coordinate
  ij = wrf_user_ll_to_ij(f_wrf,lon,lat,True)

  ; Check if ij is within the domain (and padding limits):
  ; First, check if lon is scalar
  if( n.eq.1 ) then ; if scalar, ij is 1-D vector, only one point to test
      if( ij(1) .ge. PADDING-1 .and. \
          ij(0) .ge. PADDING-1 ) then             ; Lower boundary?
        if( ij(1) .le. wrf@ni-PADDING-1 .and. \
            ij(0) .le. wrf@nj-PADDING-1 ) then    ; Upper boundary?
          answer(i) = True
        else                  ; Outside lower boundary?
          answer(i) = False
        end if
      else                    ; Outside upper boundary?
        answer(i) = False
      end if

  else              ; otherwise, ij is 2-D, multiple points must be tested
    do while(i.lt.n)
      ; Test if ij is withi the domain (uses global var PADDING for safety margin)
      if( ij(1,i) .ge. PADDING-1 .and. \
          ij(0,i) .ge. PADDING-1 ) then             ; Lower boundary?
        if( ij(1,i) .le. wrf@ni-PADDING-1 .and. \
            ij(0,i) .le. wrf@nj-PADDING-1 ) then    ; Upper boundary?
          answer(i) = True
          i=i+1
          continue
        else                  ; Outside lower boundary?
          answer(i) = False
          i=i+1
          continue
        end if
      else                    ; Outside upper boundary?
        answer(i) = False
        i=i+1
        continue
      end if
      print("Warning: indomain() couldn't determine given coordinates, exiting"\
           + " at i = "+tostring(i))
      break
    end do
  end if  ; scalar/vector test
  
  return answer
end


; Function to read midas observation data
; Depends on the following global variables:
;   VAR_MIDAS
undef("read_station_data")
function read_station_data(stations)
local data,dims,fname,fpath,table,        \
      doy,doy_all,    \
      nstations,ntimes,nvar,ndays,nhours, \
      i,j,iobs
begin
  if(START_DATE(0).ne.END_DATE(0)) then
    print("ERROR: year of START_DATE and END_DATE must equal!")
  end if

  fpath = "$MIDAS_DATA_DIR"

  nstations = dimsizes(stations)  ; number of stations
  nvar      = dimsizes(VAR_MIDAS) ; number of variables
  nhours    = dimsizes(TIMES)     ; number of sample hours

  ; We temporarily define the year,month,day variables
  ; in order to get the time-range of the observations
  ; the same names will later be used for the actual data
  year = (/START_DATE(0),END_DATE(0)/)  ;start,end year
  month = (/START_DATE(1),END_DATE(1)/) ;start,end month
  day = (/START_DATE(2),END_DATE(2)/)   ;start,end day
  doy = day_of_year(year,month,day)   ;start,end day of year
  
  ndays = (doy(1)-doy(0))+1         ; number of days
  ntimes    = nhours*ndays        ; number of observations (time-range)

  dims = (/ nstations, nvar, ntimes /) ; dimensions of output
  data = new(dims,float)          ; predefine output var
  data!0  = "Stations"            ; Set coordinate names
  data!1  = "Fields"              ;
  data!2  = "DayOfYear"         ;

  ; Define the DayOfYear dimension
  data&DayOfYear = new(ntimes,float)  ; create empty time coordinates
  data@hour = new(ntimes,float) ; we also want to keep track of the hour

  ; Fill time coordinate values
  do i=0,ntimes-1,nhours
    data&DayOfYear(i:i+nhours-1) = doy(0)+i/nhours+TIMES/24.  ; DayOfYear+hfrac
    data@hour(i:i+nhours-1) = TIMES    ; hour of observation for comparison
  end do

  ; Delete temporary variables
  delete([/year,month,day,doy/])

  do i=0,nstations-1              ; for each station
    print("Processing station: "+tostring(stations(i)))
    fname = "$MIDAS_DATA_DIR/"+stations(i)+".txt"
    ;print("POINT1")
    midas = read_midas_data(fname)
    ;table = asciiread(fpath+fname,-1,"string")  ; Read station file
    ;print("POINT2")
    ;print(midas@WDir)

    ;if( sum(dimsizes(midas)) .eq. 1 ) then        ; If file is empty
    ;  delete(midas) ; Delete files data (1 fillValue) and
    ;  continue      ; move to next iteration, leaving current station
    ;end if          ; undefined (i.e. as fillValues)

    doy_all = day_of_year(midas@year,midas@month,midas@day) + midas@hour/24.
    iobs = ind( doy_all .ge. data&DayOfYear(0) .and.  \
                doy_all .lt. data&DayOfYear(ntimes-1) ) ; find relevant obs
    if( sum(dimsizes(iobs)).eq.1) then
      print("Problem finding valid indexes")
      print(iobs)
      delete(iobs)
      continue
    end if

    ; We can now use iobs to extract the relevant rows from table
    print(midas)
    ;doy   = doy_all(iobs)+hour/24.
    doy=doy_all(iobs)

    do j=0,nvar-1                 ; load each variable to data
      print("Trying to read variable no. "+tostring(j)+\
            " (column: "+VAR_MIDAS(j)+")"   +\
            " (WRF-var: "+VAR_WRF(j)+")" )
      ; We will only insert values for points with data, the others are left as _FillValue
      data(i,j,{doy}) = midas@$VAR_MIDAS(j)$(iobs)

      ; Convert to WRF units:
      if(VAR_WRF(j).eq."T2") then    ; 2m temperature should be in K
        data(i,j,{doy}) = data(i,j,{doy})+273.15
      end if
      if(VAR_WRF(j).eq."u10spd") then
        data(i,j,{doy}) = data(i,j,{doy})*0.514444444
      end if
        
      ; Replace nan with _FillValue 
      if (any(isnan_ieee(data))) then
        replace_ieeenan (data, data@_FillValue, 0)
      end if
      print("Mean = "+tostring(avg(data(i,j,:))))
      ;print(i)
      ;print(table(iobs(0)))
      ;print(data(i,j,{doy}))
      ;print(VAR_MIDAS(j))
      ;print("Done reading variable")
    end do  ;variables
    delete([/midas,doy,doy_all,iobs/])
  end do  ;stations

  return data
end

; Function extract WRF data at specific (lat,lon) points
; the requires a (list of) wrf files, a variable name,
; and one or several pairs of latitude, longitude coordinates
; NOTE: the loaded variable should be on (t,x,y) format!
undef("get_wrf_var_in_ll")
function get_wrf_var_in_ll(var,vname,lat,lon)
local var, interp_var, dims, ntimes, npoints, i, latlon_var
begin
  ;var = wrf_user_getvar(f_wrf,vname,-1) ; load wrf field (all times)

  dims = dimsizes(var)                  ; check dimensions
  if( dimsizes(dims).ne.3 ) then
    print("WARNING: variable is not a 3D var (t,x,y), coordinates names will be wrong!")
  end if

  ;var@lat = wrf_user_getvar(f_wrf,"XLAT",1)  ; get grid coordinates
  ;var@lon = wrf_user_getvar(f_wrf,"XLONG",1) ; get grid coordinates

  ntimes  = dims(0)
  npoints = dimsizes(lat)
  interp_var = new( (/ntimes,npoints/) ,float)  ; predefine output variable
  ; Interpolate 2D-field to given lon-lat coordinates:
  ;   0,1 - inverse distance weight interpolation
  ;   2   - bilinear interpolation
  i=0
  do while i.lt.dims(0) ; loop over times (hopefully this is time)
    interp_var(i,:) = rcm2points(var@lat,var@lon,var(i,:,:),lat,lon,0)
    ;interp_var = rcm2points(var@lat,var@lon,var,lat,lon,2)
    i=i+1
  end do

  ; Define coordinate system:
  ; THIS METHOD IS UNSTABLE, INPUT MUST BE ON (T,X,Y) FORMAT
  interp_var!0 = "DayOfYear"
  interp_var!1 = "Stations"
  interp_var@lon = lon
  interp_var@lat = lat

  return interp_var
end

; Function to set color indices for stations
undef("color_list")
function color_list(wks,ts)
local nstns,colors,cmap,nc,istns
begin
  nstns = dimsizes(ts(:,0))
  colors = new(nstns,integer)
  cmap = gsn_retrieve_colormap(wks)
  nc = dimsizes(cmap)
  do istns=0,nstns-1
    colors(istns)=(nc(0)-1)*istns/(nstns)
  end do
  colors(0) = colors(0)+1
  return colors
end

; High level plot function for Taylor diagrams,
; will call taylor_diagram.ncl
; The input should have the dimensions:
;   [Stations]x[Times]
; ts is the test (estimated values) and ts0
; is the reference (observed values)
undef("ptaylor")
procedure ptaylor(wks,ts,ts0,title,lbl)
local dims,dims0,tts,tts0,cts,cts0,var,var0,\
      cc,ratio,plot,nonzero,                \
      nsets,npts,                           \
      res
begin
  dims  = dimsizes(ts)
  dims0 = dimsizes(ts0)
  if(dimsizes(dims).ne.2 .or. dimsizes(dims0).ne.2) then
    print("Error: arguments sent to ptaylor must be 2-D")
  end if

  nsets = dims(0)      ; number of data sets (sites)
  npts  = dims(1)      ; number of points per set (times)
  
  ; Create the transposed time series, tts, (needed for most statistics)
  tts = (ts)
  tts0= (ts0)

  ; Statistics used in taylor_diagram.ncl:
  cc    = new((/1,nsets/),float) ; cross corellation
  ratio = new((/1,nsets/),float) ; ratio of variances

  ; Cross correlation (centred), result 1-D [Stations]
  cts   = tts-avg(tts)    ; centre each time series over mean value
  cts0  = tts0-avg(tts0)  ;
  cc(0,:) = escorc(tts,tts0)   ; (R in Taylor, 2001)

  ; Calculate the ratio of the (standardized) variances
  var   = dim_variance_Wrap(tts)  ; calc. variance over rightmost dim (Time)
  var0  = dim_variance_Wrap(tts0) ; result: 1-D [Stations]
  nonzero = ind(var0.ne.0)
  if(.not.any(ismissing(nonzero))) then
    ratio(0,nonzero) = var(nonzero)/var0(nonzero)  ; ratio of variances (relative reference)
  else
    print("Warning: missing data or all zero values for field: "+title)
    print(var0)
  end if

  colors=color_list(wks,ts)  ; Setup color indices

  ; The rest is mainly from taylor_2.ncl found at:
  ; http://www.ncl.ucar.edu/Applications/taylor.shtml
  res                 = True               ; diagram mods desired
  res@tiMainString    = title              ; title
  ;res@Colors          = (/"black"/)        ; marker colors
  res@Colors          = colors      ; Note: this is supposed to be one per case
                                    ; however, I modified taylor_diagram to treat
                                    ; is one per variable (since each station is given
                                    ; as a variable)
  res@Markers         = (/14,9/)           ; marker styles
  res@markerTxYOffset = 0.04               ; offset btwn marker & label
  res@gsMarkerSizeF   = 0.01               ; marker size   
  res@txFontHeightF   = 0.015              ; text size 
  res@stnRad          = (/ 0.5, 1.5 /)     ; additional standard radii
  res@ccRays          = (/ 0.6, 0.9 /)     ; correllation rays
  ;res@ccRays_color    = (/130,130,130/)    ; default is "black", setting doesn't work

  res@centerDiffRMS   = True               ; RMS 'circles'
  ;res@centerDiffRMS_color = (/100,1,100/)   ; default is "black"

  ; Labels:
  res@varLabels    = lbl
  res@varLabelsYloc= 1.5
  ;res@caseLabels   = case


  print(dimsizes(ratio))
  print(dimsizes(ratio))
  print(dimsizes(ratio))
  plot = taylor_diagram(wks,ratio,cc,res)
  ; TODO
  ; set name of figure

end

; Procedure to show station locations in wrf
; domain.  stations must have attributes
; @lat and @lon assigned
undef("ppos_in_domain")
procedure ppos_in_domain(wks,f_wrf,stations)
local res, mpres,pres,lres, \
      npoints,              \
      i,                    \
      points,labels,map
begin
  npoints=dimsizes(stations)

  ; General settings
  res                   = True
  res@tiMainString      = "Available stations"

  ; Contour settings
  mres                  = res
  
  ; Point settings
  pres                  = res
  pres@gsMarkerIndex    = 16                ; filled dot
  pres@gsMarkerSizeF    = 0.005             ; default: 0.007
  points  = new(npoints,graphic)

  ; Label settings
  lres                  = res
  lres@txFontHeightF    = 0.015
  lres@txJust           = "TopLeft"
  labels  = new(npoints,graphic)

  ; The default settings are messed up, we need to set cen_lon and cen_lat manually:
  mres@mpCenterLatF=f_wrf[0]@CEN_LAT
  mres@mpCenterLonF=f_wrf[0]@CEN_LON
  ; Create map
  print("------------")
  map = wrf_map(wks,f_wrf[0],mres)
  ;draw(map)
  ;frame(wks)
  ;exit

  ; Overlay map with points (station positions)
  do i=0,npoints-1
    points(i) = gsn_add_polymarker(wks,map,                \
                stations@lon(i),stations@lat(i),pres)

    ; Different color of station names if they are included in statistics
    if(stations@indomain(i)) then
      lres@txFontColor      = "Green"
    else
      lres@txFontColor      = "Red"
    end if
    labels(i) = gsn_add_text(wks,map,"  "+tostring(stations(i)),\
                stations@lon(i),stations@lat(i),lres)
  end do

  draw(map)
  frame(wks)
end

undef("ptime_series")
procedure ptime_series(wks,ts,ts0,vname)
local res,nstns,istns,colors,cmap,nc,x,y
begin
  colors=color_list(wks,ts)  ; Setup color indices

  res                   = True
  res@tiMainString      = "Deviation from observation "+vname
  res@xyDashPattern     = 15
  res@xyLineThicknessF  = 2.0
  res@xyLineColors      = colors
  res@xyMarkLineMode    = "MarkLines"
  res@xyMarkerColors    = colors
  ;res@xyLineDashSegLenF = 
  x = ts0&DayOfYear
  y = ts-ts0
  res@tiXAxisString     = "Day of Year"

  plot = gsn_csm_xy(wks,x,y,res)
end

undef("pscatter")
procedure pscatter(wks,ts,ts0,vname)
local res,nstns,istns,colors,cmap,nc,x,y, \
      axmin,axmax
begin
  colors=color_list(wks,ts)  ; Setup color indices

  res                   = True
  res@tiMainString      = vname+"-scatter"
  res@tiXAxisString     = "Observed"
  res@tiYAxisString     = "Calculated"
  ;res@xyDashPattern     = 15
  ;res@xyLineThicknessF  = 2.0
  ;res@xyLineColors      = colors
  res@xyMarkLineMode    = "Markers"
  res@xyMarkerColors    = colors
  ;res@xyLineDashSegLenF = 
  x = ts0
  y = ts

  axmin=min((/x,y/))
  axmax=max((/x,y/))
  if((axmin.gt.0).and.(axmin.lt.100))
    axmin = 0
  end if
  res@trYMinF           = axmin
  res@trXMinF           = res@trYMinF
  res@trYMaxF           = axmax
  res@trXMaxF           = res@trYMaxF

  res@tmEqualizeXYSizes     = True
  plot = gsn_csm_xy(wks,x,y,res)
end
begin;MAIN;
  ; VARIABLES
  ;-------------------FILES AND PATHS---------------------------
  ; f_wrf         wrfout file pointers
  ;-------------------LENGTH VARIABLES--------------------------
  ; nfiles        number of wrfout files (should equal ntimes)
  ; nlists        number of wrf runs (ie no. of file lists)
  ; ntimes        length of 'Times' in wrf variable
  ; nvars         number of fields to check
  ;-------------------ITERATION COUNTERS------------------------
  ; i             main loop, iterates over nlists
  ; iv            index current variable, iterates over nvars
  ; istns         index list for stations within domain
  ; is            index for current stn (only indomain)
  ;-------------------DATA--------------------------------------
  ; wrf_data      current data field from WRF
  ; wrf_int       interpolated wrf data
  ; wrf_lat       latitude of grid points  (not staggered)
  ; wrf_lon       longitude of grid points (not staggered)
  ; midas_data    data fields from MIDAS
  ; midas_stns    list of midas stations (including @lat, @lon)

  ; Get lengths and make som checks
  nvars = dimsizes(VAR_WRF)
  if(nvars.ne.dimsizes(VAR_MIDAS))
    print("Error: length of VAR_MIDAS and VAR_WRF must equal")
  end if

  ;TODO load midas data fields and station coordinates
  
  midas_stns = read_station_list("$MIDAS_DATA_DIR/station_list.dat")    ; get available midas stations
  ;printVarSummary(midas_data)
  ;print(midas_data(0,:,0:6))

  ; Set up files
  wrf_list = asciiread("file_list_wrf.txt",-1,"string") ; load first file-list to EOF
  nfiles = dimsizes(wrf_list)

  ;print(wrf_list)
  f_wrf = addfiles( wrf_list,"r" )            ; open the wrf files for reading

  ; Check which stations are within the domain:
  midas_stns@indomain = indomain(f_wrf,midas_stns@lon,midas_stns@lat)
  istns = ind(midas_stns@indomain)
  midas_data = read_station_data(midas_stns(istns))
  lon = midas_stns@lon(istns)  ; lon for stns in domains
  lat = midas_stns@lat(istns)  ; lat for stns in domains

  ; We now want to create lat and lon arrays which only contain the
  ; coordinates of stations within the WRF domain, these points 
  ; will be used for interpolating the WRF data
  npoints = num(midas_stns@indomain)  ; number of stations in domain
  ;lon = new( npoints, float)          ; create new lat,lon arrays
  ;lat = new( npoints, float)          ;
  ntimes  = dimsizes(midas_data(0,0,:))   ; get length of time dimension
  obs = new( (/npoints, ntimes/), float ) ; create obs array, used in
                                          ; nvars loop (see below)

  ; This method is unecessary, see replacement
  ;il = 0    ; lat,lon counter (result)
  ;is = 0    ; station counter (input)
  ;do while(il.lt.npoints) ; get lat,lon for all stations in domain
    ;if(midas_stns@indomain(is)) then  ; station in domain?
      ;lon(il) = midas_stns@lon(is)    ; use longitude
      ;lat(il) = midas_stns@lat(is)    ; use latitude
      ;il=il+1                         ; prepare for next lat,lon
    ;end if
    ;is=is+1                           ; next station
  ;end do
  ; replacement method, no loop

  ; Get lat,lon this is the same for all variables
  ; (unless we read from the staggered grids, and  why would we do
  ; that?)
  wrf_lon = wrf_user_getvar(f_wrf,"XLONG",1) ;
  wrf_lat = wrf_user_getvar(f_wrf,"XLAT",1)  ;

  ; Prepare workstation for plotting
  wks = gsn_open_wks("pdf","plot")
  gsn_define_colormap(wks,"BkBlAqGrYeOrReViWh200")
  
  ; First plot an overview of the current domain
  ppos_in_domain(wks,f_wrf,midas_stns)

  ; Get all times for WRF data
  ntime_per_file=dimsizes(TIMES)
  WRF_TIMES=new((/nfiles*ntime_per_file/),integer)  ; Create empty array 
  ;WRF_TIMES=new((/ntimes/),float)  ; Create empty array 
  do id=0,nfiles-1
    istart=ntime_per_file*id
    iend=ntime_per_file*(id+1)-1
    ; fill array with values for each day:
    WRF_TIMES(istart:iend) = TIMES+24*id
    ; The indices above will select a singel day
    ; Each value in WRF_TIMES will be relative the firest output time (index 0)
  end do
  do iv=0,nvars-1       ; For each variable
    print("Variable "+VAR_WRF(iv)+":")

    ; Select midas data for current variable, and the relevant stations:
    obs = midas_data(:,iv,:) ; gives [stn,time]

    ; Read from files
    print("Attempt to read WRF file")
    if( VAR_WRF(iv).eq."u10dir" ) then      ; In some cases, e.g. wind direction
      wrf_data = get_wrf_u10dir(f_wrf,WRF_TIMES)      ; we need to preprocess the data before
    else if( VAR_WRF(iv).eq."u10spd" ) then ; interpolating to stations
      wrf_data = get_wrf_u10spd(f_wrf,WRF_TIMES)      ; such as for udir and uspd (this list is incomplete)
    else if( VAR_WRF(iv).eq."PRECIP_H" )  ; This is a custom diagnostic field
      print("Please skip this field for now")
      exit
      ;print(dimsizes(wrf_user_getvar(f_wrf,VAR_WRF(iv),-1)))
      ;print(dimsizes(wrf_data))
      ;wrf_data = wrf_user_getvar(f_wrf,VAR_WRF(iv),-1)*10 ; Hourly precip [1/10 mm]
      wrf_data = wrf_user_getvar(f_wrf,VAR_WRF(iv),WRF_TIMES)
      obs = obs/10.0 ; Hourly precip [mm]
    else                                ; Other variables can be read directly
      wrf_data = wrf_user_getvar(f_wrf,VAR_WRF(iv),WRF_TIMES) ; load wrf field (all times)
    end if
    end if 
    end if
    printVarSummary(wrf_data)
    print("Mean value: "+tostring(avg(wrf_data)))
    print("done")
    ; Interpolate wrf data to stations
    wrf_data@lon=wrf_lon  ; Store latitude and longitude as attributes
    wrf_data@lat=wrf_lat  ; (required for get_wrf_var_in_ll)
    ; Interpolate wrf_data to station locations and transpose to [stn,time]
    print("Interpolating WRF data")
    wrf_int = transpose(get_wrf_var_in_ll(wrf_data,VAR_WRF(iv),lat,lon))
    print("done")
    if( dimsizes(wrf_int(0,:)).ne.dimsizes(obs(0,:)) ) then
      print("Error: record length of WRF data and/or MIDAS data")
      print("       do not match time period in compare_wrf.sh")
      print("Record length of WRF:   "+dimsizes(wrf_int(0,:)))
      print("Record length of MIDAS: "+dimsizes(obs(0,:)))
      print(obs&DayOfYear)
      print("Please make sure WRF-data is in daily files from 00:00 to 23:00")
    end if

    ; Extra processing before plotting
    if( VAR_WRF(iv).eq."u10dir" ) then      ; In some cases, e.g. wind direction
      ; Check for wind speeds around 0 degrees (need to fix these for some plots)
      do is=0,dimsizes(istns)-1
        ddir = obs(is,:)-wrf_int(is,:)
        print("1")
        print("-------")
        print(dimsizes(ddir))
        print(dimsizes(obs(is,:)))
        print(max(ddir))
        print(min(ddir))
        obs(is,:) = where(ddir.gt.180,obs(is,:)-360,obs(is,:))
        obs(is,:) = where(ddir.lt.-180,obs(is,:)+360,obs(is,:))
        ddir = obs(is,:)-wrf_int(is,:)
        print(max(ddir))
        print(min(ddir))
      end do
    end if

    ; Send midas and wrf data to ptaylor for analysis
    print("Calling ptaylor")
    ptaylor(wks,wrf_int,obs,VAR_WRF(iv),midas_stns(istns))
    print("done")
    ; Plot time series:
    print("Calling ptime_series")
    ptime_series(wks,wrf_int,obs,VAR_WRF(iv))
    print("done")
    ; Plot Scatter:
    print("Calling pscatter")
    pscatter(wks,wrf_int,obs,VAR_WRF(iv))
    print("done")
  end do  ; nvars


  delete(wks)
  delete([/wrf_data,wrf_lat,wrf_lon/])
  
  print("Finished reading files")

end

;  wrf_list
