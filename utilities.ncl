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
local data
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
    data@PStn         = stringtofloat(str_get_field(table(0::),24, ","))
    data@PSfc         = stringtofloat(str_get_field(table(0::),25, ","))
    data@Psfc_hgt     = stringtofloat(str_get_field(table(0::),26, ","))
    data@Pmsl         = stringtofloat(str_get_field(table(0::),27, ","))
    data@Ptdcy        = stringtofloat(str_get_field(table(0::),28, ","))
    data@precip_hr_cnt= stringtofloat(str_get_field(table(0::),29, ","))
    data@precip_amt   = stringtofloat(str_get_field(table(0::),30, ","))
    data@precip_amt   = stringtofloat(str_get_field(table(0::),30, ","))
    data@maxT         = stringtofloat(str_get_field(table(0::),40, ","))
    data@minT         = stringtofloat(str_get_field(table(0::),41, ","))

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
function get_wrf_u10dir(f_wrf)
local u10,v10,r2d,dir,i
begin
  ; load 10m u,v-components on massgrid, rotated to Earth coordinate
  u10 = wrf_user_getvar(f_wrf,"U10",-1)
  v10 = wrf_user_getvar(f_wrf,"V10",-1)
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
function get_wrf_u10spd(f_wrf)
local uvmet10,spd
begin
  ; load 10m u,v-components on massgrid, rotated to Earth coordinate
  u10 = wrf_user_getvar(f_wrf,"U10",-1)
  v10 = wrf_user_getvar(f_wrf,"V10",-1)
  spd = sqrt( u10^2 + v10^2 ) ; horiz. wind spd

  ; Set dimension names
  spd!0 = u10!0
  spd!1 = u10!1
  spd!2 = u10!2
  return spd
end

