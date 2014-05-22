;-----------------------------------------------------------;
;                                                           ;
;  Read data from a midas data file created by get_midas.pl ;
;  output will be a  2D matrix with one row per observation ;
;                                                           ;
; Written by:                                               ;
;   Adam Dingwell, Uppsala University, 2012                 ;
;-----------------------------------------------------------;
undef("read_midas_data")
function read_midas_data(fname)
local table,                                    \
      datestr,year,month,day,hour,minute,date,  \
      wdir,wspd
begin
  table = asciiread(fname,-1,"string")

  if(all(ismissing(table))) then
    print("Warning: no data found in file: "+fname)
  end if
  
  ; Get time
  datestr = str_get_field(table(0::), 3, ",")
  year    = stringtointeger(str_get_cols(datestr,1,4))
  month   = stringtointeger(str_get_cols(datestr,6,7))
  day     = stringtointeger(str_get_cols(datestr,9,10))
  hour    = stringtointeger(str_get_cols(datestr,12,13))
  minute  = stringtointeger(str_get_cols(datestr,15,16))
  date    = year+(day_of_year(year,month,day)+(hour+minute/60.)/24.)/ \
            where(isleapyear(year),366,365)
  ;date@units = "year"

  ; Get data
  wdir  = stringtofloat(str_get_field(table(0::), 8, ","))
  wspd  = stringtofloat(str_get_field(table(0::), 9, ","))

  ; Get metadata
  station = stringtointeger(str_get_field(table(0), 5, ","))

  ; Create data array
  data = (/date,wdir,wspd/)
  data@stn_id = station

  ; flag missing values
  if (any(isnan_ieee(data))) then
    value = -999.
    replace_ieeenan (data, value, 0)
    data@_FillValue = value
  end if
  ;print(data)
  return data
end

