;-----------------------------------------------------------;
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
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$HOME/ncl/taylor_diagram.ncl" ; for Taylor diagrams
load "$HOME/ncl/io_utils.ncl" ; reading station data & descr 
load "./auto_presets.ncl"     ; List of wrf-file-lists
;-----------------------------------------------------------;
begin;PRESETS;  
  ; The variables defined here are "global", for easy
  ; identification they are given names in all caps
  ; (Actually, all variables in NCL are global unless
  ;  stated otherwise)

  ; Set Date & Time:
  ; START_DATE  = (/ 2010, 04, 14 /) ;  (year,month,day)
  ; END_DATE    = (/ 2010, 04, 19 /) ;  (year,month,day)
  ; 
  ; These commented out settings have been moved to 
  ; compare_wrf_midas.sh which in turn puts them
  ; in file_list_wrf.ncl (change name on this one!)
  ; the NCL script is load by this script
  ;
  ; TODO: 
  ; Put all presets in compare_wrf_midas.sh
  ; and print "global" variables to 
  ; file_list_wrf.ncl

  ; midas data load functions only support one year
  ; (start & end date must equal)
  ; could be set to read dates from file_list_wrf.ncl
  ; or maybe from the wrfout files directly, this would reduce 
  ; number of places were changes must be made between runs...

  ; Fields to be compared:
  VAR = (/ "T" , "UST"/)

  ; Observation times in MIDAS data:
  TIMES = (/ "00", "03", "06", "09", "12", "15", "18", "21" /)

  ; Number of padding grid points required to include a station:
  PADDING = 10

  ; PATH settings:
  PATH_MIDAS  = "$HOME/data/obs/midas/"
  FNAME_MIDAS = PATH_MIDAS+"station_list.dat"

  ; Misc settings:
  YEAR = START_DATE(0)

end;PRESETS;

; Structure of the rest of this script
; functions
; Number  Name
;   1     load_wrf_file_names
;
;
;
;

undef("load_first_wrf")
function load_first_wrf(wrflists) ; Primarily used for testing, may be removed later on...
local wrf_list, wrf, n_latxlon
begin
  wrf_list = asciiread( lists(0),-1,"string") ; load first file-list to EOF
  wrf = wrf_list(0)                       ; Current file name
  wrf@file   = addfile( wrf_list(0),"r" )   ; open the first wrf file
  wrf@lat = wrf_user_getvar(f_wrf,"XLAT",0)    ; read lat
  wrf@lon = wrf_user_getvar(f_wrf,"XLONG",0)   ; read lon
  n_latxlon   = dimsizes(lat)
  wrf@n_lat = wrf@n_latxlon(0)    ;used in Read midas data
  wrf@n_lon = wrf@n_latxlon(1)    ;used in Read midas data

  wrf@U = wrf_user_getvar(f_wrf,"U",0)    ; just for testing

  return wrf
end


; Function used to determine the closest WRF grid point for a given
; WRF netCDF file and a set ll-coordinates.  The function will return
; the ij-coordinates if the given ll is within the domain otherwise
; zero values is returned.
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

; Function to read a list of MIDAS stations and returns:
; id, id@lat, id@lon
; The function takes no attributes but expects the variable
; MIDAS_ROOT to be defined
undef("read_station_list")
function read_station_list()
local fname,header,stations
begin
  fname  = MIDAS_ROOT + "/station_list.dat"
  table   = asciiread(fname,-1,"string")  ; Read entire file to memory
  stations = stringtoint(str_get_field(table(1::), 1, " ")); station id
  stations@lat = stringtofloat(str_get_field(table(1::),7," "));latitude
  stations@lon = stringtofloat(str_get_field(table(1::),8," "));longitude

  ;header  = headerreadAsciiHead(infile, 1) ; header (first row)
  ;stations = readAsciiTable(infile,1,"int",1) ; station ID
  ;stations@lat = readAsciiTable(infile,

  return stations
end


begin;MAIN;

  ; open wrf output for reading
  i = 1
  do while(i.lt.dimsizes(LISTS))
    wrf_list = asciiread( LISTS(i),-1,"string") ; load first file-list to EOF
    f_wrf = addfiles( wrf_list,"r" )   ; open the wrf files
    print(f_wrf)

    i=i+1
  end do
  
  print("Finished reading files")

  ;TESTING
    ;; CHECK IF INDOMAIN() IS WORKING -ok
  ;wrf_list = asciiread( LISTS(0),-1,"string") ; load first file-list to EOF
  ;print(wrf_list(0))
  ;f_wrf = addfile( wrf_list(0),"r" )   ; open the first wrf file
  ; f_wrf = addfiles( wrf_list,"r" )   ; open multiple files, supported by ll_to_ij
  ;a=indomain(f_wrf,-18.083,65.683)   
  ;print(a)
    ;; CHECK IF READ_STATION_LIST IS WORKING
  ;stat = read_station_list()
  ;print(stat)
  ;printVarSummary(stat)
  ;print(stat@lon)
    ;; COMBINE:
  ;b=indomain(f_wrf,stat@lon,stat@lat)
  ;print(b)
end

;  wrf_list
