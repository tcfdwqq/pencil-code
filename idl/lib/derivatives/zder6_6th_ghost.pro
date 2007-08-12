;
;  $Id: zder6_6th_ghost.pro,v 1.1 2007-08-12 12:17:36 ajohan Exp $
;
;  Sixth derivative d^6/dz^6
;  - 6th-order (7-point stencil)
;  - with ghost cells
;
;***********************************************************************
function zder6,f
  COMPILE_OPT IDL2,HIDDEN
;
  common cdat,x,y,z
  common cdat_nonequidist,dx_1,dy_1,dz_1,dx_tilde,dy_tilde,dz_tilde,lequidist
;
;  Calculate nx, ny, and nz, based on the input array size.
;
  s=size(f) & d=make_array(size=s)
  nx=s[1] & ny=s[2] & nz=s[3]
;
;  Check for degenerate case (no x-extension)
;
  if (n_elements(lequidist) ne 3) then lequidist=[-1,-1,-1]
  if (nz eq 1) then return,fltarr(nx,ny,nz)
;
;  Determine location of ghost zones, assume nghost=3 for now.
;
  n1=3 & n2=nz-4
;
  if (lequidist[2]) then begin
    dz6=1./(z[4]-z[3])^6
  endif else begin
; 
;  Nonuniform mesh not implemented.
;     
    print, 'Nonuniform mesh not implemented for zder6_6th_ghost.pro'
    stop 
  endelse
;
  if (s[0] eq 3) then begin
    if (n2 gt n1) then begin
      d[*,*,n1:n2]=dz6*( -20.*f[*,*,n1:n2]$
                         +15.*(f[*,*,n1-1:n2-1]+f[*,*,n1+1:n2+1])$
                          -6.*(f[*,*,n1-2:n2-2]+f[*,*,n1+2:n2+2])$
                          +1.*(f[*,*,n1-3:n2-3]+f[*,*,n1+3:n2+3])$
                       )
    endif else begin
      d[*,*,n1:n2]=0.
    endelse
;
  endif else if (s[0] eq 4) then begin
;
    if (n2 gt n1) then begin
      d[*,*,n1:n2,*]=dz6*( -20.*f[*,*,n1:n2,*]$
                           +15.*(f[*,*,n1-1:n2-1,*]+f[*,*,n1+1:n2+1,*])$
                            -6.*(f[*,*,n1-2:n2-2,*]+f[*,*,n1+2:n2+2,*])$
                            +1.*(f[*,*,n1-3:n2-3,*]+f[*,*,n1+3:n2+3,*])$
                       )
    endif else begin
      d[*,*,n1:n2,*]=0.
    endelse
;
  endif else begin
    print, 'error: zder6_6th_ghost not implemented for ', $
           strtrim(s[0],2), '-D arrays'
    stop
  endelse
;
  return, d
;
end
