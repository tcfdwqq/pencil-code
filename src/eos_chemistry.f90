! $Id$
!
!  Equation of state for an ideal gas without ionization.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED lnTT; cp1tilde; glnTT(3); TT; TT1; gTT(3)
! PENCILS PROVIDED TT_2; TT_3; TT_4
! PENCILS PROVIDED hss(3,3); hlnTT(3,3); del2ss; del6ss; del2lnTT; del6lnTT
! PENCILS PROVIDED yH; ee; ss; pp; delta; glnmumol(3); ppvap; csvap2; cs2
! PENCILS PROVIDED mu1; gmu1(3); rho1gpp(3); glnpp(3); del2pp
!
!***************************************************************
module EquationOfState
!
  use Cdata
  use Cparam
  use Messages
  use Sub, only: keep_compiler_quiet
!
  implicit none
!
  include 'eos.h'
!
  interface eoscalc ! Overload subroutine `eoscalc' function
    module procedure eoscalc_pencil   ! explicit f implicit m,n
    module procedure eoscalc_point    ! explicit lnrho, ss
    module procedure eoscalc_farray   ! explicit lnrho, ss
  end interface
!
  interface pressure_gradient ! Overload subroutine `pressure_gradient'
    module procedure pressure_gradient_farray  ! explicit f implicit m,n
    module procedure pressure_gradient_point   ! explicit lnrho, ss
  end interface
!
  integer, parameter :: ilnrho_ss=1,ilnrho_ee=2,ilnrho_pp=3
  integer, parameter :: ilnrho_lnTT=4,ilnrho_cs2=5
  integer, parameter :: irho_cs2=6, irho_ss=7, irho_lnTT=8, ilnrho_TT=9
  integer, parameter :: ipp_ss=11,ipp_cs2=12
!
  integer :: iglobal_cs2, iglobal_glnTT
!
  real :: lnTT0=impossible
!
  real :: mu=1.
  real :: cs0=1., rho0=1.
  real :: cs20=1., lnrho0=0.
  real :: ptlaw=3./4.
  real :: gamma=5./3.
  real :: Rgas_cgs=0., Rgas, Rgas_unit_sys=1.,  error_cp=1e-6
  real :: gamma_m1    !(=gamma-1)
  real :: gamma_inv   !(=1/gamma)
  real :: cp=impossible, cp1=impossible, cv=impossible, cv1=impossible
  real :: cs2top_ini=impossible, dcs2top_ini=impossible
  real :: cs2bot=1., cs2top=1.
  real :: cs2cool=0.
  real :: mpoly=1.5, mpoly0=1.5, mpoly1=1.5, mpoly2=1.5
  real, dimension(3) :: beta_glnrho_global=0., beta_glnrho_scaled=0.
  integer :: isothtop=0
  integer :: ieosvars=-1, ieosvar1=-1, ieosvar2=-1, ieosvar_count=0
  integer :: ll1,ll2,mm1,mm2,nn1,nn2
  logical :: leos_isothermal=.false., leos_isentropic=.false.
  logical :: leos_isochoric=.false., leos_isobaric=.false.
  logical :: leos_localisothermal=.false.
  character (len=20) :: input_file='chem.inp'
  logical, SAVE ::  lcheminp_eos=.false.
  logical :: l_gamma_m1=.false.
  logical :: l_gamma=.false.
  logical :: l_cp=.false.
  integer :: imass=1!, iTemp1=2,iTemp2=3,iTemp3=4
!
  character (len=labellen) :: ieos_profile='nothing'
  real, dimension(mz) :: profz_eos=1.
!
 real, dimension(nchemspec,18) :: species_constants
 real, dimension(nchemspec,7)     :: tran_data
 real, dimension (mx,my,mz), SAVE :: mu1_full, pp_full, rho_full, TT_full
!
  namelist /eos_init_pars/  mu, cp, cs0, rho0, gamma, error_cp, ptlaw
!
  namelist /eos_run_pars/   mu, cp, cs0, rho0, gamma, error_cp, ptlaw
!
  contains
!***********************************************************************
    subroutine register_eos()
!
!  14-jun-03/axel: adapted from register_eos
!
      leos=.true.
      leos_chemistry=.true.
!
      ilnTT = 0
!
!  Identify version number.
!
      if (lroot) call svn_id( &
          '$Id$')
!
    endsubroutine register_eos
!***********************************************************************
    subroutine units_eos()
!
!  This routine calculates things related to units and must be called
!  before the rest of the units are being calculated.
!
!  22-jun-06/axel: adapted from initialize_eos
!  16-mar-10/Natalia
!
      use Mpicomm, only: stop_it
!
! Initialize variable selection code (needed for RELOADing)
!
      ieosvars=-1
      ieosvar_count=0
!
      if (unit_system == 'cgs') then
         Rgas_unit_sys = k_B_cgs/m_u_cgs
      elseif (unit_system == 'SI') then
         Rgas_unit_sys = k_B_cgs/m_u_cgs*1.e-4
      endif
!
      if (unit_temperature == impossible) then
        call stop_it('unit_temperature is not found!')
      else
        Rgas=Rgas_unit_sys*unit_temperature/unit_velocity**2
      endif
!
      inquire(FILE=input_file, EXIST=lcheminp_eos)
!
      if (lroot) then
!
       if (.not. lcheminp_eos ) then
        call fatal_error('initialize_eos',&
                        'chem.imp is not found!')
       else
        print*,'initialize_eos: chem.imp is found! Now cp, cv, gamma, mu are pencils ONLY!'
       endif
      endif
!
    endsubroutine units_eos
!***********************************************************************
    subroutine initialize_eos()
!
! Initialize variable selection code (needed for RELOADing)
!
      ieosvars=-1
      ieosvar_count=0
!
!  write constants to disk. In future we may want to deal with this
!  using an include file or another module.
!
      if (lroot) then
        open (1,file=trim(datadir)//'/pc_constants.pro',position="append")
        write (1,'(a,1pd26.16)') 'k_B=',k_B
        write (1,'(a,1pd26.16)') 'm_H=',m_H
        write (1,*) 'lnTTO=',lnTT0
        write (1,*) 'cp=',cp
        close (1)
      endif
      
      if ((nxgrid==1) .and. (nygrid==1) .and. (nzgrid==1)) then
       ll1=1; ll2=mx; mm1=m1; mm2=m2; nn1=n1; nn2=n2
      else
      if (nxgrid==1) then
       ll1=l1; ll2=l2
      else
       ll1=1; ll2=mx
      endif

      if (nygrid==1) then
       mm1=m1; mm2=m2
      else
       mm1=1; mm2=my
      endif

      if (nzgrid==1) then
       nn1=n1; nn2=n2
      else
       nn1=1;  nn2=mz
      endif
     endif
!
    endsubroutine initialize_eos
!***********************************************************************
    subroutine select_eos_variable(variable,findex)
!
!  Select eos variable
!
!   02-apr-06/tony: implemented
!
      use FArrayManager
!
      character (len=*), intent(in) :: variable
      integer, intent(in) :: findex
      integer :: this_var=0
      integer, save :: ieosvar_selected=0
      integer, parameter :: ieosvar_lnrho = 2**0
      integer, parameter :: ieosvar_rho   = 2**1
      integer, parameter :: ieosvar_ss    = 2**2
      integer, parameter :: ieosvar_lnTT  = 2**3
      integer, parameter :: ieosvar_TT    = 2**4
      integer, parameter :: ieosvar_cs2   = 2**5
      integer, parameter :: ieosvar_pp    = 2**6
!
      if (ieosvar_count.eq.0) ieosvar_selected=0
!
      if (ieosvar_count.ge.2) &
        call fatal_error("select_eos_variable", &
             "2 thermodynamic quantities have already been defined while attempting to add a 3rd: ") !//variable)
!
      ieosvar_count=ieosvar_count+1
!
!      select case (variable)
      if (variable=='ss') then
          this_var=ieosvar_ss
          if (findex.lt.0) then
            leos_isentropic=.true.
          endif
      elseif (variable=='cs2') then
          this_var=ieosvar_cs2
          if (findex==-2) then
            leos_localisothermal=.true.
!
            call farray_register_global('cs2',iglobal_cs2)
            call farray_register_global('glnTT',iglobal_glnTT,vector=3)
!
          elseif (findex.lt.0) then
            leos_isothermal=.true.
          endif
      elseif (variable=='lnTT') then
          this_var=ieosvar_lnTT
          if (findex.lt.0) then
            leos_isothermal=.true.
          endif
      elseif (variable=='TT') then
          this_var=ieosvar_TT
      elseif (variable=='lnrho') then
          this_var=ieosvar_lnrho
          if (findex.lt.0) then
            leos_isochoric=.true.
          endif
      elseif (variable=='rho') then
          this_var=ieosvar_rho
          if (findex.lt.0) then
            leos_isochoric=.true.
          endif
      elseif (variable=='pp') then
          this_var=ieosvar_pp
          if (findex.lt.0) then
            leos_isobaric=.true.
          endif
      else
        call fatal_error("select_eos_variable", &
             "unknown thermodynamic variable")
      endif
      if (ieosvar_count==1) then
        ieosvar1=findex
        ieosvar_selected=ieosvar_selected+this_var
        return
      endif
!
! Ensure the indexes are in the correct order.
!
      if (this_var.lt.ieosvar_selected) then
        ieosvar2=ieosvar1
        ieosvar1=findex
      else
        ieosvar2=findex
      endif
      ieosvar_selected=ieosvar_selected+this_var
      select case (ieosvar_selected)
        case (ieosvar_lnrho+ieosvar_ss)
          if (lroot) print*,"select_eos_variable: Using lnrho and ss"
          ieosvars=ilnrho_ss
        case (ieosvar_rho+ieosvar_ss)
          if (lroot) print*,"select_eos_variable: Using rho and ss"
          ieosvars=irho_ss
        case (ieosvar_lnrho+ieosvar_lnTT)
          if (lroot) print*,"select_eos_variable: Using lnrho and lnTT"
          ieosvars=ilnrho_lnTT
        case (ieosvar_lnrho+ieosvar_TT)
          if (lroot) print*,"select_eos_variable: Using lnrho and TT"
          ieosvars=ilnrho_TT
        case (ieosvar_rho+ieosvar_lnTT)
          if (lroot) print*,"select_eos_variable: Using rho and lnTT"
          ieosvars=irho_lnTT
        case (ieosvar_lnrho+ieosvar_cs2)
          if (lroot) print*,"select_eos_variable: Using lnrho and cs2"
          ieosvars=ilnrho_cs2
        case (ieosvar_rho+ieosvar_cs2)
          if (lroot) print*,"select_eos_variable: Using rho and cs2",iproc
          ieosvars=irho_cs2
        case default
          if (lroot) print*,"select_eos_variable: Thermodynamic variable combination, ieosvar_selected= ",ieosvar_selected
          call fatal_error("select_eos_variable", &
             "This thermodynamic variable combination is not implemented: ")
      endselect
!
    endsubroutine select_eos_variable
!***********************************************************************
    subroutine getmu(f,mu1_full_tmp)
!
!  Calculate  mean molecular weight
!
!   12-aug-03/tony: implemented
!   16-mar-10/natalia 

    real, dimension (mx,my,mz,mfarray), optional :: f
    real, dimension (mx,my,mz) :: mu1_full_tmp
    integer :: k,j2,j3
       !
!  Mean molecular weight
!
          mu1_full_tmp=0.
          do k=1,nchemspec
           do j2=mm1,mm2
           do j3=nn1,nn2
            mu1_full_tmp(:,j2,j3)=mu1_full_tmp(:,j2,j3)+unit_mass*f(:,j2,j3,ichemspec(k)) &
                /species_constants(k,imass)
           enddo
           enddo
          enddo
           mu1_full=mu1_full_tmp

    endsubroutine getmu
!***********************************************************************
    subroutine rprint_eos(lreset,lwrite)
!
!  Writes iyH and ilnTT to index.pro file
!
!  14-jun-03/axel: adapted from rprint_radiation
!  21-11-04/anders: moved diagnostics to entropy
!
      logical :: lreset
      logical, optional :: lwrite
!
      call keep_compiler_quiet(lreset)
      call keep_compiler_quiet(present(lwrite))
!
    endsubroutine rprint_eos
!***********************************************************************
    subroutine get_slices_eos(f,slices)
!
!  Write slices for animation of Eos variables.
!
!  26-jul-06/tony: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
!
!  Loop over slices.
!
      select case (trim(slices%name))
!
!  Temperature.
!
        case ('lnTT')
          slices%yz =f(ix_loc,m1:m2,n1:n2,ilnTT)
          slices%xz =f(l1:l2,iy_loc,n1:n2,ilnTT)
          slices%xy =f(l1:l2,m1:m2,iz_loc,ilnTT)
          slices%xy2=f(l1:l2,m1:m2,iz2_loc,ilnTT)
          if (lwrite_slice_xy3) slices%xy3=f(l1:l2,m1:m2,iz3_loc,ilnTT)
          if (lwrite_slice_xy4) slices%xy4=f(l1:l2,m1:m2,iz4_loc,ilnTT)
          slices%ready=.true.
!
      endselect
!
    endsubroutine get_slices_eos
!***********************************************************************
   subroutine pencil_criteria_eos()
!
!  All pencils that the EquationOfState module depends on are specified here.
!
!  02-04-06/tony: coded
!
!  EOS is a pencil provider but evolves nothing so it is unlokely that
!  it will require any pencils for it's own use.
!
      lpenc_requested(i_lnTT)=.true.
      lpenc_requested(i_TT)=.true.
      lpenc_requested(i_TT_2)=.true.
      lpenc_requested(i_TT_3)=.true.
      lpenc_requested(i_TT_4)=.true.
      lpenc_requested(i_TT1)=.true.
      lpenc_requested(i_glnTT)=.true.
      lpenc_requested(i_del2lnTT)=.true.
!

     if (lcheminp_eos) then
      lpenc_requested(i_glnpp)=.true.
      lpenc_requested(i_del2pp)=.true.
      lpenc_requested(i_mu1)=.true.
      lpenc_requested(i_gmu1)=.true.
      lpenc_requested(i_pp)=.true.
     endif
    

    endsubroutine pencil_criteria_eos
!***********************************************************************
    subroutine pencil_interdep_eos(lpencil_in)
!
!  Interdependency among pencils from the Entropy module is specified here.
!
!  20-11-04/anders: coded
!
! Modified by Natalia. Taken from  eos_temperature_ionization module
!
   logical, dimension(npencils) :: lpencil_in
!
      if (lpencil_in(i_lnTT))   lpencil_in(i_TT)=.true.
      if (lpencil_in(i_TT))     lpencil_in(i_TT_2)=.true.
      if (lpencil_in(i_TT_2))   lpencil_in(i_TT_3)=.true.
      if (lpencil_in(i_TT_3))   lpencil_in(i_TT_4)=.true.
      if (lpencil_in(i_TT))     lpencil_in(i_TT1)=.true.
!
      call keep_compiler_quiet(lpencil_in)
!
    endsubroutine pencil_interdep_eos
!***********************************************************************
    subroutine calc_pencils_eos(f,p)
!
!  Calculate Entropy pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  02-apr-06/tony: coded
!
      use Sub, only: grad, del2
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f
      intent(inout) :: p
      integer :: i
!
!  Temperature
!
       if (lpencil(i_lnTT)) then
         if (ltemperature_nolog) then
          p%lnTT=log(f(l1:l2,m,n,iTT))
         else
          p%lnTT=f(l1:l2,m,n,ilnTT)
         endif
!
       endif
       if (lpencil(i_TT))  then
         if (ltemperature_nolog) then
           p%TT=f(l1:l2,m,n,iTT)
         else
           p%TT=exp(p%lnTT)
         endif
       endif

       if (lpencil(i_TT_2)) p%TT_2=p%TT*p%TT
       if (lpencil(i_TT_3)) p%TT_3=p%TT_2*p%TT
       if (lpencil(i_TT_4)) p%TT_4=p%TT_3*p%TT

       if (lpencil(i_TT1)) p%TT1=1./p%TT!

        if (minval(p%TT)==0.) then
          call fatal_error('calc_pencils_eos','p%TT=0!')
        endif
!
!  Temperature laplacian and gradient
!
        if (lpencil(i_glnTT)) then
         if (ltemperature_nolog) then
           call grad(f,iTT,p%glnTT)
           p%glnTT(:,1)=p%glnTT(:,1)/p%TT(:)
           p%glnTT(:,2)=p%glnTT(:,2)/p%TT(:)
           p%glnTT(:,3)=p%glnTT(:,3)/p%TT(:)
         else
           call grad(f,ilnTT,p%glnTT)
         endif
        endif
!
        if (ltemperature_nolog) then
         if (lpencil(i_gTT)) call grad(f,iTT,p%gTT)
         if (lpencil(i_del2lnTT)) call del2(f,iTT,p%del2lnTT)
        else
         if (lpencil(i_del2lnTT)) call del2(f,ilnTT,p%del2lnTT)
        endif
        if (lpencil(i_glnmumol)) p%glnmumol(:,:)=0.
       

       if (lcheminp_eos) then
!
!  Mean molecular weight
!
        if (lpencil(i_mu1)) then
          p%mu1=mu1_full(l1:l2,m,n)
        endif

        if (lpencil(i_gmu1)) call grad(mu1_full,p%gmu1)
!
!
!  Pressure
!
        if (lpencil(i_pp)) p%pp = Rgas*p%TT*p%mu1*p%rho

!
!  Logarithmic pressure gradient
!
        if (lpencil(i_rho1gpp)) then
!
          do i=1,3
            p%rho1gpp(:,i) = p%pp/p%rho(:) &
               *(p%glnrho(:,i)+p%glnTT(:,i)+p%gmu1(:,i)/p%mu1(:))
          enddo
        endif
!
! Gradient of the lnpp
!
       if (lpencil(i_glnpp)) then
            do i=1,3
             p%glnpp(:,i)=p%rho1gpp(:,i)*p%rho(:)/p%pp(:)
            enddo
       endif
!
! Laplasian of pressure
!
       if (lpencil(i_del2pp)) then
         call del2(pp_full(:,:,:),p%del2pp)
       endif

      endif
!
    endsubroutine calc_pencils_eos
!***********************************************************************
   subroutine ioninit(f)
!
!  the ionization fraction has to be set to a value yH0 < yH < yHmax before
!  rtsafe is called for the first time
!
!  12-jul-03/tobi: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine ioninit
!***********************************************************************
    subroutine ioncalc(f)
!
!   calculate degree of ionization and temperature
!   This routine is called from equ.f90 and operates on the full 3-D array.
!
!   13-jun-03/tobi: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine ioncalc
!***********************************************************************
   subroutine getdensity(f,EE,TT,yH,rho_full_tmp)

     real, dimension (mx,my,mz,mfarray) :: f
     real, dimension (mx,my,mz), intent(out) :: rho_full_tmp
     real, intent(in), optional :: EE,TT,yH

      if (ldensity_nolog) then
        rho_full_tmp=f(:,:,:,ilnrho)
      else
        rho_full_tmp=exp(f(:,:,:,ilnrho))
      endif
        rho_full=rho_full_tmp

      call keep_compiler_quiet(yH)
      call keep_compiler_quiet(EE)
      call keep_compiler_quiet(TT)

   endsubroutine getdensity
!***********************************************************************
   subroutine gettemperature(f,TT_full_tmp)

     real, dimension (mx,my,mz,mfarray) :: f
     real, dimension (mx,my,mz), intent(out) :: TT_full_tmp

      if (ldensity_nolog) then
        TT_full_tmp=f(:,:,:,ilnTT)
      else
        TT_full_tmp=exp(f(:,:,:,ilnTT))
      endif
        TT_full=TT_full_tmp

   endsubroutine gettemperature
!***********************************************************************
  subroutine getpressure(pp_full_tmp)

     real, dimension (mx,my,mz), intent(out) :: pp_full_tmp
     integer :: j2,j3
      
       do j2=mm1,mm2
       do j3=nn1,nn2
         pp_full_tmp(:,j2,j3)=Rgas*mu1_full(:,j2,j3) &
                   *rho_full(:,j2,j3)*TT_full(:,j2,j3)
       enddo
       enddo

       pp_full=pp_full_tmp

   endsubroutine getpressure
!***********************************************************************
    subroutine get_cp1(cp1_)
!
!  04-nov-06/axel: added to alleviate spurious use of pressure_gradient
!
!  return the value of cp1 to outside modules
!
    use Mpicomm, only: stop_it
!
      real, intent(out) :: cp1_
      call fatal_error('get_cp1','SHOULD NOT BE CALLED WITH eos_chemistry')
      cp1_=impossible
!
!
    endsubroutine get_cp1
!***********************************************************************
    subroutine get_ptlaw(ptlaw_)
!
!  04-jul-07/wlad: return the value of ptlaw to outside modules
!                  ptlaw is temperature gradient in accretion disks
!
      real, intent(out) :: ptlaw_
!
      call fatal_error('get_ptlaw','SHOULD NOT BE CALLED WITH eos_chemistry')
      ptlaw_=impossible
!
    endsubroutine get_ptlaw
!***********************************************************************
    subroutine isothermal_density_ion(pot,tmp)
!
      real, dimension (nx), intent(in) :: pot
      real, dimension (nx), intent(out) :: tmp
!
      call fatal_error('isothermal_density_ion','SHOULD NOT BE CALLED WITH eos_chemistry')
      tmp=impossible
!
      call keep_compiler_quiet(pot)
!
    endsubroutine isothermal_density_ion
!***********************************************************************
    subroutine pressure_gradient_farray(f,cs2,cp1tilde)
!
!   Calculate thermodynamical quantities, cs2 and cp1tilde
!   and optionally glnPP and glnTT
!   gP/rho=cs2*(glnrho+cp1tilde*gss)
!
!   17-nov-03/tobi: adapted from subroutine eoscalc
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(nx), intent(out) :: cs2,cp1tilde
!
      cs2=impossible
      cp1tilde=impossible
      call fatal_error('pressure_gradient_farray','SHOULD NOT BE CALLED WITH eos_chemistry')
!
      call keep_compiler_quiet(f)
!
    endsubroutine pressure_gradient_farray
!***********************************************************************
    subroutine pressure_gradient_point(lnrho,ss,cs2,cp1tilde)
!
!   Calculate thermodynamical quantities, cs2 and cp1tilde
!   and optionally glnPP and glnTT
!   gP/rho=cs2*(glnrho+cp1tilde*gss)
!
!   17-nov-03/tobi: adapted from subroutine eoscalc
!
!
      real, intent(in) :: lnrho,ss
      real, intent(out) :: cs2,cp1tilde
!
      call fatal_error('pressure_gradient_farray','SHOULD NOT BE CALLED WITH eos_chemistry')
!
      call keep_compiler_quiet(cs2,cp1tilde,ss,lnrho)
!
    endsubroutine pressure_gradient_point
!***********************************************************************
    subroutine temperature_gradient(f,glnrho,gss,glnTT)
!
!   Calculate thermodynamical quantities
!   and optionally glnPP and glnTT
!   gP/rho=cs2*(glnrho+cp1*gss)
!
!   17-nov-03/tobi: adapted from subroutine eoscalc
!
      use Mpicomm, only: stop_it
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(nx,3), intent(in) :: glnrho,gss
      real, dimension(nx,3), intent(out) :: glnTT
!
     call fatal_error('temperature_gradien','SHOULD NOT BE CALLED WITH eos_chemistry')
!
!  given that we just stopped, it cannot become worse by setting
!  cp1tilde to impossible, which allows the compiler to compile.
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(glnrho,gss,glnTT)
!
    endsubroutine temperature_gradient
!***********************************************************************
    subroutine temperature_laplacian(f,del2lnrho,del2ss,del2lnTT)
!
!   Calculate thermodynamical quantities
!   and optionally glnPP and glnTT
!   gP/rho=cs2*(glnrho+cp1*gss)
!
!   17-nov-03/tobi: adapted from subroutine eoscalc
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(nx), intent(in) :: del2lnrho,del2ss
      real, dimension(nx), intent(out) :: del2lnTT
!
      call fatal_error('temperature_laplacian','SHould not be called!')
!
     call keep_compiler_quiet(f)
     call keep_compiler_quiet(del2lnrho,del2ss,del2lnTT)
!
    endsubroutine temperature_laplacian
!***********************************************************************
    subroutine temperature_hessian(f,hlnrho,hss,hlnTT)
!
!   Calculate thermodynamical quantities, cs2 and cp1
!   and optionally hlnPP and hlnTT
!   hP/rho=cs2*(hlnrho+cp1*hss)
!
!   17-nov-03/tobi: adapted from subroutine eoscalc
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(nx,3,3), intent(in) :: hlnrho,hss
      real, dimension(nx,3,3), intent(out) :: hlnTT
!
      call fatal_error('temperature_hessian', &
        'This routine is not coded for eos_chemistry')
!
      hlnTT(:,:,:)=0
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(hss)
      call keep_compiler_quiet(hlnrho)
!
    endsubroutine temperature_hessian
!***********************************************************************
    subroutine eosperturb(f,psize,ee,pp,ss)
!
!  Set f(l1:l2,m,n,iss), depending on the valyes of ee and pp
!  Adding pressure perturbations is not implemented
!
      real, dimension(mx,my,mz,mfarray), intent(inout) :: f
      integer, intent(in) :: psize
      real, dimension(psize), intent(in), optional :: ee, pp, ss
      real, dimension(psize) :: lnrho_
!
      if (psize==nx) then
        lnrho_=f(l1:l2,m,n,ilnrho)
      elseif (psize==mx) then
        lnrho_=f(:,m,n,ilnrho)
      else
        call not_implemented("eosperturb")
      endif

     call fatal_error('eosperturb', &
        'This routine is not coded for eos_chemistry')
!
      call keep_compiler_quiet(present(ee))
      call keep_compiler_quiet(present(pp))
      call keep_compiler_quiet(present(ss))
!
    endsubroutine eosperturb
!***********************************************************************
    subroutine eoscalc_farray(f,psize,lnrho,yH,lnTT,ee,pp,kapparho)
!
!   Calculate thermodynamical quantities
!
!   02-feb-03/axel: simple example coded
!   13-jun-03/tobi: the ionization fraction as part of the f-array
!                   now needs to be given as an argument as input
!   17-nov-03/tobi: moved calculation of cs2 and cp1 to
!                   subroutine pressure_gradient
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      integer, intent(in) :: psize
      real, dimension(psize), intent(out), optional :: lnrho
      real, dimension(psize), intent(out), optional :: yH,ee,pp,kapparho
      real, dimension(psize), intent(out), optional :: lnTT
      real, dimension(psize) :: lnTT_
      real, dimension(psize) :: lnrho_

      if (present(lnrho)) lnrho=lnrho_
      if (present(lnTT)) lnTT=lnTT_
!
      if (.not. l_cp) then
        if (present(ee)) ee=cv*exp(lnTT_)
        if (ieosvars==ilnrho_lnTT) then
          if (present(pp)) pp=(cp-cv)*exp(lnTT_+lnrho_)
        else
          if (present(pp)) pp=(cp-cv)*exp(lnTT_)*lnrho_
        endif
      endif
!
      if (present(yH)) yH=impossible
!
      if (present(kapparho)) then
        kapparho=0
        call fatal_error("eoscalc","sorry, no Hminus opacity with noionization")
      endif
!
      call fatal_error('eoscalc_farray', &
          'This routine is not coded for eos_chemistry')
!
      call keep_compiler_quiet(f)
!
    endsubroutine eoscalc_farray
!***********************************************************************
    subroutine eoscalc_point(ivars,var1,var2,lnrho,ss,yH,lnTT,ee,pp,cs2)
!
!   Calculate thermodynamical quantities
!
!
!   22-jun-06/axel: reinstated cp,cp1,cv,cv1 in hopefully all the places.
!
      use Mpicomm, only: stop_it
!
      integer, intent(in) :: ivars
      real, intent(in) :: var1,var2
      real, intent(out), optional :: lnrho,ss
      real, intent(out), optional :: yH,lnTT
      real, intent(out), optional :: ee,pp,cs2
      real :: lnrho_,ss_,lnTT_,ee_,pp_,cs2_
!
!
      if (present(lnrho)) lnrho=lnrho_
      if (present(ss)) ss=ss_
      if (present(yH)) yH=impossible
      if (present(lnTT)) lnTT=lnTT_
      if (present(ee)) ee=ee_
      if (present(pp)) pp=pp_
      if (present(cs2)) cs2=cs2_

      call fatal_error('eoscalc_point', &
        'This routine is not coded for eos_chemistry')

!
    endsubroutine eoscalc_point
!***********************************************************************
    subroutine eoscalc_pencil(ivars,var1,var2,lnrho,ss,yH,lnTT,ee,pp,cs2)
!
!   Calculate thermodynamical quantities
!
!   2-feb-03/axel: simple example coded
!   13-jun-03/tobi: the ionization fraction as part of the f-array
!                   now needs to be given as an argument as input
!   17-nov-03/tobi: moved calculation of cs2 and cp1 to
!                   subroutine pressure_gradient
!   27-mar-06/tony: Introduces cv, cv1, gamma_inv to make faster
!                   + more explicit
!   31-mar-06/tony: I removed messy lcalc_cp stuff completely. cp=1.
!                   is just fine.
!   22-jun-06/axel: reinstated cp,cp1,cv,cv1 in hopefully all the places.
!
      integer, intent(in) :: ivars
      real, dimension(nx), intent(in) :: var1,var2
      real, dimension(nx), intent(out), optional :: lnrho,ss
      real, dimension(nx), intent(out), optional :: yH,lnTT
      real, dimension(nx), intent(out), optional :: ee,pp,cs2
      real, dimension(nx) :: lnrho_,ss_,lnTT_,ee_,pp_,cs2_
!
!
      if (present(lnrho)) lnrho=lnrho_
      if (present(ss)) ss=ss_
      if (present(yH)) yH=impossible
      if (present(lnTT)) lnTT=lnTT_
      if (present(ee)) ee=ee_
      if (present(pp)) pp=pp_
      if (present(cs2)) cs2=cs2_

      call fatal_error('eoscalc_pencil', &
        'This routine is not coded for eos_chemistry')
!
    endsubroutine eoscalc_pencil
!***********************************************************************
    subroutine get_soundspeed(lnTT,cs2)
!
!  Calculate sound speed for given temperature
!
!  20-Oct-03/tobi: Coded
!
     use Mpicomm, only: stop_it
!
      real, intent(in)  :: lnTT
      real, intent(out) :: cs2

      cs2=impossible
      call fatal_error('get_soundspeed', &
        'This routine is not coded for eos_chemistry')
!
      call keep_compiler_quiet(lnTT)
!
    endsubroutine get_soundspeed
!***********************************************************************
    subroutine read_eos_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=eos_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=eos_init_pars,ERR=99)
      endif
!
99    return
    endsubroutine read_eos_init_pars
!***********************************************************************
    subroutine write_eos_init_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit,NML=eos_init_pars)
!
    endsubroutine write_eos_init_pars
!***********************************************************************
    subroutine read_eos_run_pars(unit,iostat)
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=eos_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=eos_run_pars,ERR=99)
      endif
!
99    return
    endsubroutine read_eos_run_pars
!***********************************************************************
    subroutine write_eos_run_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit,NML=eos_run_pars)
!
    endsubroutine write_eos_run_pars
!***********************************************************************
    subroutine isothermal_entropy(f,T0)
!
!  Isothermal stratification (for lnrho and ss)
!  This routine should be independent of the gravity module used.
!  When entropy is present, this module also initializes entropy.
!
!  Sound speed (and hence Temperature), is
!  initialised to the reference value:
!           sound speed: cs^2_0            from start.in
!           density: rho0 = exp(lnrho0)
!
!  11-jun-03/tony: extracted from isothermal routine in Density module
!                  to allow isothermal condition for arbitrary density
!  17-oct-03/nils: works also with leos_ionization=T
!  18-oct-03/tobi: distributed across ionization modules
!
      real, dimension(mx,my,mz,mfarray), intent(inout) :: f
      real, intent(in) :: T0
!
      cs2top=cs2bot
      call fatal_error('isothermal_entropy', &
          'This routine is not coded for eos_chemistry')
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(T0)
!
    endsubroutine isothermal_entropy
!***********************************************************************
    subroutine isothermal_lnrho_ss(f,T0,rho0)
!
!  Isothermal stratification for lnrho and ss (for yH=0!)
!
!  Currently only implemented for ionization_fixed.
!
      real, dimension(mx,my,mz,mfarray), intent(inout) :: f
      real, intent(in) :: T0,rho0
!
      call fatal_error('isothermal_lnrho_ss', &
        'This routine is not coded for eos_chemistry')

      call keep_compiler_quiet(f)
      call keep_compiler_quiet(T0)
      call keep_compiler_quiet(rho0)
!
    endsubroutine isothermal_lnrho_ss
!***********************************************************************
     subroutine get_average_pressure(average_density,average_pressure)
!
!   01-dec-2009/piyali+dhrube: coded
!
      real, intent(in):: average_density
      real, intent(out):: average_pressure
      call keep_compiler_quiet(average_density)
      call keep_compiler_quiet(average_pressure)
    endsubroutine get_average_pressure
!***********************************************************************
    subroutine bc_ss_flux(f,topbot)
!
!  constant flux boundary condition for entropy (called when bcz='c1')
!
!  23-jan-2002/wolf: coded
!  11-jun-2002/axel: moved into the entropy module
!   8-jul-2002/axel: split old bc_ss into two
!  26-aug-2003/tony: distributed across ionization modules
!
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
 
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
    endsubroutine bc_ss_flux
!***********************************************************************
    subroutine bc_ss_flux_turb(f,topbot)
!
!  dummy routine
!
!   4-may-2009/axel: dummy routine
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_ss_flux_turb
!***********************************************************************
    subroutine bc_ss_temp_old(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!  23-jan-2002/wolf: coded
!  11-jun-2002/axel: moved into the entropy module
!   8-jul-2002/axel: split old bc_ss into two
!  23-jun-2003/tony: implemented for leos_fixed_ionization
!  26-aug-2003/tony: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_ss_temp_old
!***********************************************************************
 subroutine bc_ss_temp_x(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f

      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
!
    endsubroutine bc_ss_temp_x
!***********************************************************************
!***********************************************************************
    subroutine bc_ss_temp_y(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f

      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
!
    endsubroutine bc_ss_temp_y
!***********************************************************************
    subroutine bc_ss_temp_z(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f

      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_ss_temp_z
!***********************************************************************
    subroutine bc_lnrho_temp_z(f,topbot)
!
!  boundary condition for lnrho *and* ss: constant temperature
!
!  27-sep-2002/axel: coded
!  19-aug-2005/tobi: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f

      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_lnrho_temp_z
!***********************************************************************
    subroutine bc_lnrho_pressure_z(f,topbot)
!
!  boundary condition for lnrho: constant pressure
!
!   4-apr-2003/axel: coded
!   1-may-2003/axel: added the same for top boundary
!  19-aug-2005/tobi: distributed across ionization modules
!
!      use Gravity, only: lnrho_bot,lnrho_top,ss_bot,ss_top
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_lnrho_pressure_z
!***********************************************************************
    subroutine bc_ss_temp2_z(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_ss_temp2_z
!***********************************************************************
    subroutine bc_ss_stemp_x(f,topbot)
!
!  boundary condition for entropy: symmetric temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_ss_stemp_x
!***********************************************************************
   subroutine bc_ss_stemp_y(f,topbot)
!
!  boundary condition for entropy: symmetric temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_ss_stemp_y
!***********************************************************************
    subroutine bc_ss_stemp_z(f,topbot)
!
!  boundary condition for entropy: symmetric temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_ss_stemp_z
!***********************************************************************
    subroutine bc_ss_energy(f,topbot)
!
!  boundary condition for entropy
!
!  may-2002/nils: coded
!  11-jul-2002/nils: moved into the entropy module
!  26-aug-2003/tony: distributed across ionization modules
!
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_ss_energy
!***********************************************************************
    subroutine bc_stellar_surface(f,topbot)
!
!      use Mpicomm, only: stop_it
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_stellar_surface
!***********************************************************************
    subroutine bc_lnrho_cfb_r_iso(f,topbot)
!
!  Boundary condition for radial centrifugal balance
!
!
!  21-aug-2006/wlad: coded
!
!
      real, dimension (mx,my,mz,mfarray), intent (inout) :: f
      character (len=3), intent (in) :: topbot

      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
 
!
    endsubroutine bc_lnrho_cfb_r_iso
!***********************************************************************
    subroutine bc_lnrho_hds_z_iso(f,topbot)
!
!  Boundary condition for density *and* entropy.
!
!  12-Juil-2006/dintrans: coded
!
      use Gravity
      use Sub, only: div
!
      real, dimension (mx,my,mz,mfarray), intent (inout) :: f
      character (len=3), intent (in) :: topbot

      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_lnrho_hds_z_iso
!***********************************************************************
    subroutine bc_lnrho_hdss_z_iso(f,topbot)
!
!  Smooth out density perturbations with respect to hydrostatic
!  stratification in Fourier space.
!  05-jul-07/tobi: Adapted from bc_aa_pot3
!
!
      real, dimension (mx,my,mz,mfarray), intent (inout) :: f
      character (len=3), intent (in) :: topbot

      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)

    endsubroutine bc_lnrho_hdss_z_iso
!***********************************************************************
    subroutine bc_lnrho_hdss_z_liso(f,topbot)
!
!  Potential field boundary condition
!
!  02-jul-07/wlad: Adapted from Tobi's bc_aa_pot2
!  Does the same thing as bc_lnrho_hdss_z_iso, but for a local isothermal
!  equation of state (as opposed to strictly isothermal).
!
!
      real, dimension (mx,my,mz,mfarray), intent (inout) :: f
      character (len=3), intent (in) :: topbot
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
!
    endsubroutine bc_lnrho_hdss_z_liso
!***********************************************************************
    subroutine bc_lnrho_hds_z_liso(f,topbot)
!
!  Boundary condition for density
!
!
!
!  12-Jul-2006/dintrans: coded
!  18-Jul-2007/wlad: adapted for local isothermal equation of state
!
      use Gravity
!
      real, dimension (mx,my,mz,mfarray), intent (inout) :: f
      character (len=3), intent (in) :: topbot
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(topbot)
    endsubroutine bc_lnrho_hds_z_liso
!***********************************************************************
!0000000000000000000000000000000000000000000000000000000000000000000000000
! moved form chemistry module
!000000000000000000000000000000000000000000000000000000000000000000000000
    subroutine find_mass(element_name,MolMass)
!
!  Find mass of element
!
!  05-feb-08/nils: coded
!
      use Mpicomm, only: stop_it

      character (len=*), intent(in) :: element_name
      real, intent(out) :: MolMass
!
      select case (element_name)
      case ('H')
        MolMass=1.00794
      case ('C')
        MolMass=12.0107
      case ('N')
        MolMass=14.00674
      case ('O')
        MolMass=15.9994
      case ('Ar','AR')
        MolMass=39.948
      case ('He','HE')
        MolMass=4.0026
      case default
        if (lroot) print*,'element_name=',element_name
        call stop_it('find_mass: Element not found!')
      end select
!
    endsubroutine find_mass
!***********************************************************************
   subroutine find_species_index(species_name,ind_glob,ind_chem,found_specie)
!
!  Find index in the f array for specie
!
!  05-feb-08/nils: coded
!


      integer, intent(out) :: ind_glob
      integer, intent(inout) :: ind_chem
      character (len=*), intent(in) :: species_name
      integer :: k
      logical, intent(out) :: found_specie
!
      ind_glob=0
    !  ind_chem=0
      do k=1,nchemspec
        if (trim(varname(ichemspec(k)))==species_name) then
          ind_glob=k+ichemspec(1)-1
          ind_chem=k
          exit
        endif
!print*, varname(ichemspec(k))
      enddo
!
!  Check if the species was really found
!


      if ((ind_glob==0)) then
        found_specie=.false.
      ! if (lroot) print*,' no species has been found  ',' species index= ', ind_glob,ind_chem
      !  call fatal_error('find_species_index',&
      !                  'no species has been found')
      else
        found_specie=.true.
    !    if (lroot) print*,species_name,'   species index= ',ind_chem
      endif
!
    endsubroutine find_species_index
!***********************************************************************
    subroutine read_species(input_file)
!
!  This subroutine reads all species information from chem.inp
!  See the chemkin manual for more information on
!  the syntax of chem.inp.
!
!  06-mar-08/nils: coded
!

      use Mpicomm, only: stop_it

      logical :: IsSpecie=.false., emptyfile
      integer :: k,file_id=123, StartInd, StopInd
      character (len=80) :: ChemInpLine
      character (len=*) :: input_file
!
      emptyFile=.true.
      k=1
      open(file_id,file=input_file)
      dataloop: do
        read(file_id,'(80A)',end=1000) ChemInpLine(1:80)
        emptyFile=.false.
!
!  Check if we are reading a line within the species section
!
        if (ChemInpLine(1:7)=="SPECIES")            IsSpecie=.true.
        if (ChemInpLine(1:3)=="END" .and. IsSpecie) IsSpecie=.false.
!
!  Read in species
!
        if (IsSpecie) then
          if (ChemInpLine(1:7) /= "SPECIES") then
            StartInd=1; StopInd =0
            stringloop: do
              StopInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
              if (StopInd==StartInd) then
                StartInd=StartInd+1
              else
                varname(ichemspec(k))=trim(ChemInpLine(StartInd:StopInd-1))
                StartInd=StopInd
                k=k+1
                if (k>nvar) then
                  print*,'nchemspec=',nchemspec
                  call stop_it("There were too many species, "//&
                      "please increase nchemspec!")
                endif
              endif
              if (StartInd==80) exit
            enddo stringloop
          endif
        endif
      enddo dataloop
!
!  Stop if chem.inp is empty
!
1000  if (emptyFile)  call stop_it('The input file chem.inp was empty!')
      close(file_id)
!
    endsubroutine read_species
!***********************************************************************
   subroutine read_thermodyn(input_file)
!
!  This subroutine reads the thermodynamical data for all species
!  from chem.inp. See the chemkin manual for more information on
!  the syntax of chem.inp.
!
!  06-mar-08/nils: coded
!

      character (len=*), intent(in) :: input_file
      integer :: file_id=123, ind_glob, ind_chem
      character (len=80) :: ChemInpLine
      integer :: In1,In2,In3,In4,In5,iElement,iTemperature,StopInd
      integer :: NumberOfElement_i
      logical :: IsThermo=.false., found_specie
      real, dimension(4) :: MolMass
      real, dimension(3) :: tmp_temp
      character (len=5) :: NumberOfElement_string,element_string
      character (len=10) :: specie_string,TemperatureNr_i
      real :: nne
      integer, dimension(7) :: iaa1,iaa2

      integer :: imass=1, iTemp1=2,iTemp2=3,iTemp3=4

      ind_chem=0

 
!  Initialize some index pointers
!
      iaa1(1)=5;iaa1(2)=6;iaa1(3)=7;iaa1(4)=8
      iaa1(5)=9;iaa1(6)=10;iaa1(7)=11
!
      iaa2(1)=12;iaa2(2)=13;iaa2(3)=14;iaa2(4)=15
      iaa2(5)=16;iaa2(6)=17;iaa2(7)=18

!
      open(file_id,file=input_file)
      dataloop2: do
        read(file_id,'(80A)',end=1001) ChemInpLine(1:80)
!
! Check if we are reading a line within the thermo section
!
        if (ChemInpLine(1:6)=="THERMO") IsThermo=.true.
        if (ChemInpLine(1:3)=="END" .and. IsThermo) IsThermo=.false.
!
! Read in thermo data
!
        if (IsThermo) then
          if (ChemInpLine(1:7) /= "THERMO") then
            StopInd=index(ChemInpLine,' ')
            specie_string=trim(ChemInpLine(1:StopInd-1))

            call find_species_index(specie_string,ind_glob,ind_chem,&
                found_specie)
!
! What problems are in the case of  ind_chem=0?
!
            if (ind_chem>0 .and. ind_chem<=nchemspec) then

            if (found_specie) then
!
! Find molar mass
!
              MolMass=0
              do iElement=1,4
                In1=25+(iElement-1)*5
                In2=26+(iElement-1)*5
                In3=27+(iElement-1)*5
                In4=29+(iElement-1)*5
                if (ChemInpLine(In1:In1)==' ') then
                  MolMass(iElement)=0
                else
                  element_string=trim(ChemInpLine(In1:In2))
                  call find_mass(element_string,MolMass(iElement))
                  In5=verify(ChemInpLine(In3:In4),' ')+In3-1
                  NumberOfElement_string=trim(ChemInpLine(In5:In4))
                  read (unit=NumberOfElement_string,fmt='(I5)') &
                      NumberOfElement_i
                  MolMass(iElement)=MolMass(iElement)*NumberOfElement_i
                endif
              enddo
              species_constants(ind_chem,imass)=sum(MolMass)

!
! Find temperature-ranges for low and high temperature fitting
!
              do iTemperature=1,3
                In1=46+(iTemperature-1)*10
                In2=55+(iTemperature-1)*10
                if (iTemperature==3) In2=73
                In3=verify(ChemInpLine(In1:In2),' ')+In1-1
                TemperatureNr_i=trim(ChemInpLine(In3:In2))
                read (unit=TemperatureNr_i,fmt='(F10.1)') nne
                tmp_temp(iTemperature)=nne
              enddo
              species_constants(ind_chem,iTemp1)=tmp_temp(1)
              species_constants(ind_chem,iTemp2)=tmp_temp(3)
              species_constants(ind_chem,iTemp3)=tmp_temp(2)
!
            elseif (ChemInpLine(80:80)=="2") then
              ! Read iaa1(1):iaa1(5)
              read (unit=ChemInpLine(1:75),fmt='(5E15.8)')  &
                  species_constants(ind_chem,iaa1(1):iaa1(5))
!
            elseif (ChemInpLine(80:80)=="3") then
              ! Read iaa1(6):iaa5(3)
              read (unit=ChemInpLine(1:75),fmt='(5E15.8)')  &
                  species_constants(ind_chem,iaa1(6):iaa2(3))
            elseif (ChemInpLine(80:80)=="4") then
              ! Read iaa2(4):iaa2(7)
              read (unit=ChemInpLine(1:75),fmt='(4E15.8)')  &
                  species_constants(ind_chem,iaa2(4):iaa2(7))
            endif

          endif
          endif !(from ind_chem>0 query)
        endif
      enddo dataloop2
1001  continue
      close(file_id)
!

   endsubroutine read_thermodyn
!***********************************************************************
    subroutine write_thermodyn()
!
!  This subroutine writes the thermodynamical data for every specie
!  to ./data/chem.out.
!
!  06-mar-08/nils: coded
!
      use General
!
      character (len=20) :: input_file="./data/chem.out"
      character (len=5) :: ispec
      integer :: file_id=123,k
      integer, dimension(7) :: iaa1,iaa2
      integer :: imass=1, iTemp1=2,iTemp3=4
!
!      Initialize some index pointers
!
      iaa1(1)=5;iaa1(2)=6;iaa1(3)=7;iaa1(4)=8
      iaa1(5)=9;iaa1(6)=10;iaa1(7)=11
!
      iaa2(1)=12;iaa2(2)=13;iaa2(3)=14;iaa2(4)=15
      iaa2(5)=16;iaa2(6)=17;iaa2(7)=18
!
      open(file_id,file=input_file)
      write(file_id,*) 'Specie'
      write(file_id,*) 'MolMass Temp1 Temp2 Temp3'
      write(file_id,*) 'a1(1)  a1(2)  a1(3)  a1(4)  a1(5)  a1(6)  a1(7)'
      write(file_id,*) 'a2(1)  a2(2)  a2(3)  a2(4)  a2(5)  a2(6)  a2(7)'
      write(file_id,*) '***********************************************'
      dataloop2: do k=1,nchemspec
        write(file_id,*) varname(ichemspec(k))
        write(file_id,'(F10.2,3F10.2)') species_constants(k,imass),&
            species_constants(k,iTemp1:iTemp3)
        write(file_id,'(7E12.5)') species_constants(k,iaa1)
        write(file_id,'(7E12.5)') species_constants(k,iaa2)
      enddo dataloop2
!
      close(file_id)
!
      if (lroot) then
        print*,'Write pc_constants.pro in chemistry.f90'
        open (143,FILE=trim(datadir)//'/pc_constants.pro',POSITION="append")
        write (143,*) 'specname=strarr(',nchemspec,')'
        write (143,*) 'specmass=fltarr(',nchemspec,')'
        do k=1,nchemspec
          call chn(k-1,ispec)
          write (143,*) 'specname[',trim(ispec),']=',"'",&
              trim(varname(ichemspec(k))),"'"
          write (143,*) 'specmass[',trim(ispec),']=',species_constants(k,imass)
        enddo
        close (143)
      endif
!
    endsubroutine write_thermodyn
!***********************************************************************
   subroutine read_transport_data
!
!  Reading of the chemkin transport data
!
!  01-apr-08/natalia: coded
!
     use Mpicomm, only: stop_it

      logical :: emptyfile
      logical :: found_specie
      integer :: file_id=123, ind_glob, ind_chem
      character (len=80) :: ChemInpLine
      character (len=10) :: specie_string
      integer :: VarNumber
      integer :: StartInd,StopInd,StartInd_1,StopInd_1

!
      emptyFile=.true.
!
      StartInd_1=1; StopInd_1 =0
      open(file_id,file="tran.dat")
!
      if (lroot) print*, 'the following species are found '//&
          'in tran.dat: beginning of the list:'
!
      dataloop: do
!
        read(file_id,'(80A)',end=1000) ChemInpLine(1:80)
        emptyFile=.false.
!
        StopInd_1=index(ChemInpLine,' ')
        specie_string=trim(ChemInpLine(1:StopInd_1-1))
!
        call find_species_index(specie_string,ind_glob,ind_chem,found_specie)
!
        if (found_specie) then
          if (lroot) print*,specie_string,' ind_glob=',ind_glob,' ind_chem=',ind_chem
!
          VarNumber=1; StartInd=1; StopInd =0
          stringloop: do while (VarNumber<7)
!
            StopInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
            StartInd=verify(ChemInpLine(StopInd:),' ')+StopInd-1
            StopInd=index(ChemInpLine(StartInd:),' ')+StartInd-1
!
            if (StopInd==StartInd) then
              StartInd=StartInd+1
            else
              if (VarNumber==1) then
                read (unit=ChemInpLine(StartInd:StopInd),fmt='(E1.0)')  &
                    tran_data(ind_chem,VarNumber)
              elseif (VarNumber==2) then
                read (unit=ChemInpLine(StartInd:StopInd),fmt='(E15.8)')  &
                    tran_data(ind_chem,VarNumber)
              elseif (VarNumber==3) then
                read (unit=ChemInpLine(StartInd:StopInd),fmt='(E15.8)')  &
                    tran_data(ind_chem,VarNumber)
              elseif (VarNumber==4) then
                read (unit=ChemInpLine(StartInd:StopInd),fmt='(E15.8)')  &
                    tran_data(ind_chem,VarNumber)
              elseif (VarNumber==5) then
                read (unit=ChemInpLine(StartInd:StopInd),fmt='(E15.8)')  &
                    tran_data(ind_chem,VarNumber)
              elseif (VarNumber==6) then
                read (unit=ChemInpLine(StartInd:StopInd),fmt='(E15.8)')  &
                    tran_data(ind_chem,VarNumber)
              else
                call stop_it("No such VarNumber!")
              endif
!
              VarNumber=VarNumber+1
              StartInd=StopInd
            endif
            if (StartInd==80) exit
          enddo stringloop
!
        endif
      enddo dataloop
!
! Stop if tran.dat is empty
!

1000  if (emptyFile)  call stop_it('The input file tran.dat was empty!')
!
      if (lroot) print*, 'the following species are found in tran.dat: end of the list:'
!
      close(file_id)
!
    endsubroutine read_transport_data
!***********************************************************************
!!***********************************************************************
endmodule EquationOfState
