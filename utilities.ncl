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
