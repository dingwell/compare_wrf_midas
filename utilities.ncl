;-----------------------------------------------------------;
;                                                           ;
;  Read data from a midas data file created by get_midas.pl ;
;  output will be a  2D matrix with one row per observation ;
;                                                           ;
; Written by:                                               ;
;   Adam Dingwell, Uppsala University, 2014                 ;
;-----------------------------------------------------------;
undef("read_midas_data")
function read_midas_data(fname)
local table,data,Td,Tv,g,Zg,Rd,p
begin
    ; Columns in file:
    ;  1- 6: id, id_type, date (yyyy-mm-dd HH:MM), type, src_id, region
    ;  7-12: rec_st_ind, wdir, wspd, weather_code, past_weather, past_weather2,
    ; 13-18: ttl_cld, cld_base_amt, cld_base_hgt, low_cld_type, med_cld_type, hi_cld_type,
    ; 19-24: wspd_unit, vis, air_T, wetb_T, Td, stn_pres,
    ; 25-30: sfc_pres, sfc_pres_hgt, msl_pres, pres_tdcy, prcp_hr_cnt, prcp_amt,
    ; 31-36: cld_amt1, cld_type1, cld_base_hgt1, cld_amt2, cld_type2, cld_base2,
    ; 37-42: cld_amt3, cld_type3, cld_base_hgt3, max_T, min_T, ground_state_id,
    ; 43-48: min_grss_T, snow_depth, sun_obs_hr_cnt, su_dur, prcp_tdcy_24hr, vert_cis,
    ; 49-54: src_opr_type, gust_spd_type, max_gust, rnwy_name, rnwy_vis, alt_pres,
    ; 55-56: qc_flag1, qc_flag2

    ; Read the values in as 1D, since we don't know rows and columns yet.
    table = asciiread(fname,-1,"string") ; -1 reads to 1-D array
    ;values_1d = asciiread(fname,-1,"float") ; -1 reads to 1-D array
        ; "float" stores each row as a float

    if(all(ismissing(table))) then
      print("Warning: no data found in file: "+fname)
    end if

    ; The script which extracts midas data inserts NaNs for missing data
    ; Seems to be supported by asciiread
    
    data=True
    ; Get time
    datestr = str_get_field(table(0::), 3, ",")
    data@year    = stringtointeger(str_get_cols(datestr,1,4))
    data@month   = stringtointeger(str_get_cols(datestr,6,7))
    data@day     = stringtointeger(str_get_cols(datestr,9,10))
    data@hour    = stringtointeger(str_get_cols(datestr,12,13))
    data@minute  = stringtointeger(str_get_cols(datestr,15,16))
    data@YearFrac= data@year+(day_of_year(data@year,data@month,data@day)+  \
                    (data@hour+data@minute/60.)/24.)/ \
                    where(isleapyear(data@year),366,365)
    
    data@stn_id       = stringtointeger(str_get_field(table(0), 5, ","))
    data@WDir         = stringtointeger(str_get_field(table(0::),8, ","))
    data@WSpd         = stringtofloat(str_get_field(table(0::),9, ","))
    data@TAir         = stringtofloat(str_get_field(table(0::),21, ","))
    data@TWet         = stringtofloat(str_get_field(table(0::),22, ","))
    data@TDew         = stringtofloat(str_get_field(table(0::),23, ","))
    data@Pstn         = stringtofloat(str_get_field(table(0::),24, ","))*100  ; in Pa (WRF data is in Pa)
    data@Psfc         = stringtofloat(str_get_field(table(0::),25, ","))*100  ; in Pa (don't use, seems wrong)
    data@Psfc_hgt     = stringtofloat(str_get_field(table(0::),26, ","))
    data@Pmsl         = stringtofloat(str_get_field(table(0::),27, ","))  ;WRF data is in hPa
    data@Ptdcy        = stringtofloat(str_get_field(table(0::),28, ","))
    data@precip_hr_cnt= stringtofloat(str_get_field(table(0::),29, ","))
    data@precip_amt   = stringtofloat(str_get_field(table(0::),30, ","))
    data@precip_amt   = stringtofloat(str_get_field(table(0::),30, ","))
    data@maxT         = stringtofloat(str_get_field(table(0::),40, ","))
    data@minT         = stringtofloat(str_get_field(table(0::),41, ","))

    ; Calculate Virtual Temperature according to NOAA:
    Td= data@TDew     ; Dewpoint temperature in C
    p = data@Pstn     ; Pressure in Pa
    Tv = (data@TAir+273.15)/(1-0.379*(6.11*10^(7.5*Td/(237.7+Td))/(p/100)))
    ; Provide an option to use the calculated msl pressure:
    g = 9.82          ; gravity acc. in m/s2
    Zg=data@Psfc_hgt  ; Elevation in m
    Rd=287            ; Specific gas constant dry air in 
    data@Pmsl_calc    = p*exp(g*Zg/(Rd*Tv))/100 ; msl pressure in hPa

    return data
end
;-----------------------------------------------------------;
;                                                           ;
;  Function to read a list of MIDAS stations, returning:    ;
;  src_id, src_id@lat, src_id@lon                           ;
;                                                           ;
;  where src_id is a 1-D array of station identifiers       ;
;  and the attributes lat and lon have the same dimensions  ;
;                                                           ;
; Written by:                                               ;
;   Adam Dingwell, Uppsala University, 2012                 ;
;-----------------------------------------------------------;
undef("read_station_list")
function read_station_list(fname)
local fname,header,stations,table
begin
  table = asciiread(fname,-1,"string")  ; Read entire file to memory
  stations = stringtoint(str_get_field(table(1::), 1, " ")); station id
  stations@lat  = stringtofloat(str_get_field(table(1::),7," "));latitude
  stations@lon  = stringtofloat(str_get_field(table(1::),8," "));longitude

  ;header  = headerreadAsciiHead(infile, 1) ; header (first row)
  ;stations = readAsciiTable(infile,1,"int",1) ; station ID
  ;stations@lat = readAsciiTable(infile,

  return stations
end
;-----------------------------------------------------------;
;                                                           ;
; Interpolate WRF-data to give lon-lat coordinate           ;
;                                                           ; 
; Input should be a WRF variable on (t,x,y) format          ;
; It is recommended to do this in smaller chunks if working ;
; if working with large data sets as RAM can easily be a    ;
; limiting factor when reading t,x,y fields                 ;
;                                                           ;
; Written by:                                               ;
;   Adam Dingwell, Uppsala University, 2012                 ;
;-----------------------------------------------------------;
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



;-----------------------------------------------------------;
;                                                           ;
; Get Azimuthal 10m-wind direction from WRF file            ;
;                                                           ; 
; Function will use wrf_user_getvar to load rotated         ;
; u,v-components of the 10m wind field and convert this to  ;
; wind direction.                                           ;
;                                                           ;
; Written by:                                               ;
;   Adam Dingwell, Uppsala University, 2012                 ;
;-----------------------------------------------------------;
undef("get_wrf_u10dir")
function get_wrf_u10dir(f_wrf,it)
local u10,v10,r2d,dir,i
begin
  ; load 10m u,v-components on massgrid, rotated to Earth coordinate
  u10 = wrf_user_getvar(f_wrf,"U10",it)
  v10 = wrf_user_getvar(f_wrf,"V10",it)
  r2d = 45.0/atan(1.0)  ; conversion factor (radians to degrees)

  ; We use atan2 instead of atan since plain atan is not able
  ; to determine direction completely (sometimes 180 degrees off)
  dir = atan2(u10,v10)*r2d+180  ; horiz. wind dir

  ; Set dimension names
  dir!0 = u10!0
  dir!1 = u10!1
  dir!2 = u10!2
  return dir
end

;-----------------------------------------------------------;
;                                                           ;
; Get 10m wind speed from WRF file                          ;
;                                                           ; 
; Function will use wrf_user_getvar to load rotated         ;
; u,v-components of the 10m wind field and convert this to  ;
; wind speed.                                               ;
;                                                           ;
; Written by:                                               ;
;   Adam Dingwell, Uppsala University, 2012                 ;
;-----------------------------------------------------------;
undef("get_wrf_u10spd")
function get_wrf_u10spd(f_wrf,it)
local uvmet10,spd
begin
  ; load 10m u,v-components on massgrid, rotated to Earth coordinate
  u10 = wrf_user_getvar(f_wrf,"U10",it)
  v10 = wrf_user_getvar(f_wrf,"V10",it)
  spd = sqrt( u10^2 + v10^2 ) ; horiz. wind spd

  ; Set dimension names
  spd!0 = u10!0
  spd!1 = u10!1
  spd!2 = u10!2
  return spd
end

