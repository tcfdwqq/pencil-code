! $Id: chemistry.f90,v 1.5 2008-01-09 12:54:08 dobler Exp $
!  This modules addes chemical species and reactions.

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lchemistry = .true.
!
! MVAR CONTRIBUTION 1
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Chemistry

  use Cparam
  use Cdata
  use Messages
  use Sub, only: keep_compiler_quiet

  implicit none

  include 'chemistry.h'

!!  character, len(50) :: initcustom

! input parameters
!  namelist /special_init_pars/ dummy
!!!eg.    initcustom
! run parameters
!  namelist /special_run_pars/ dummy

!!
!! Declare any index variables necessary for main or
!!
!!   integer :: iSPECIAL_VARIABLE_INDEX=0
!!
!! other variables (needs to be consistent with reset list below)
!!
!!   integer :: i_POSSIBLEDIAGNOSTIC=0
!!

  contains

!***********************************************************************
    subroutine register_chemistry()
!
!  Configure pre-initialised (i.e. before parameter read) variables
!  which should be know to be able to evaluate
!
!  13-aug-07/steveb: coded
!   8-jan-08/axel: added modifications analogously to dustdensity
!
      use Cdata
      use Mpicomm
      use General, only: chn
!
      logical, save :: first=.true.
      integer :: k
      character (len=5) :: schem
!
! A quick sanity check
!
      if (.not. first) call stop_it('register_chemistry called twice')
      first=.false.
!
!  Set ind to consecutive numbers nvar+1, nvar+2, ..., nvar+nchemspec
!
      do k=1,nchemspec
        ichemspec(k)=nvar+k
      enddo
!
!  Increase nvar accordingly
!
      nvar=nvar+nchemspec
!
!  Print some diagnostics
!
      do k=1,nchemspec
        if ((ip<=8) .and. lroot) then
          print*, 'register_chemistry: k = ', k
          print*, 'register_chemistry: nvar = ', nvar
          print*, 'register_chemistry: ichemspec = ', ichemspec(k)
        endif
!
!  Put variable name in array
!
        call chn(k,schem)
        varname(ichemspec(k))='nd('//trim(schem)//')'
      enddo
!
!  identify CVS version information (if checked in to a CVS repository!)
!  CVS should automatically update everything between $Id: chemistry.f90,v 1.5 2008-01-09 12:54:08 dobler Exp $
!  when the file in committed to a CVS repository.
!
      if (lroot) call cvs_id( &
           "$Id: chemistry.f90,v 1.5 2008-01-09 12:54:08 dobler Exp $")
!
!
!  Perform some sanity checks (may be meaningless if certain things haven't
!  been configured in a custom module but they do no harm)
!
      if (naux > maux) then
        if (lroot) write(0,*) 'naux = ', naux, ', maux = ', maux
        call stop_it('register_chemistry: naux > maux')
      endif
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('register_chemistry: nvar > mvar')
      endif
!
    endsubroutine register_chemistry
!***********************************************************************
    subroutine initialize_chemistry(f)
!
!  called by run.f90 after reading parameters, but before the time loop
!
!  13-aug-07/steveb: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray) :: f
!!
!!  Initialize any module variables which are parameter dependent
!!
!
! DO NOTHING
      call keep_compiler_quiet(f)
!
    endsubroutine initialize_chemistry
!***********************************************************************
    subroutine init_chemistry(f,xx,yy,zz)
!
!  initialise special condition; called from start.f90
!  13-aug-07/steveb: coded
!
      use Cdata
      use Mpicomm
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz) :: xx,yy,zz
!
      intent(in) :: xx,yy,zz
      intent(inout) :: f

!!
!!  SAMPLE IMPLEMENTATION
!!
!!      select case(initspecial)
!!        case('nothing'); if(lroot) print*,'init_special: nothing'
!!        case('zero', '0'); f(:,:,:,iSPECIAL_VARIABLE_INDEX) = 0.
!!        case default
!!          !
!!          !  Catch unknown values
!!          !
!!          if (lroot) print*,'init_special: No such value for initspecial: ', trim(initspecial)
!!          call stop_it("")
!!      endselect
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(xx,yy,zz)
!
    endsubroutine init_chemistry
!***********************************************************************
    subroutine pencil_criteria_chemistry()
!
!  All pencils that this special module depends on are specified here.
!
!  13-aug-07/steveb: coded
!
    endsubroutine pencil_criteria_chemistry
!***********************************************************************
    subroutine pencil_interdep_chemistry(lpencil_in)
!
!  Interdependency among pencils provided by this module are specified here
!
!  13-aug-07/steveb: coded
!
      use Sub, only: keep_compiler_quiet
!
      logical, dimension(npencils) :: lpencil_in
!
      call keep_compiler_quiet(lpencil_in)
!
    endsubroutine pencil_interdep_chemistry
!***********************************************************************
    subroutine calc_pencils_chemistry(f,p)
!
!  Calculate Hydro pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!   13-aug-07/steveb: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f
      intent(inout) :: p
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(p)
!
    endsubroutine calc_pencils_chemistry
!***********************************************************************
    subroutine dchemistry_dt(f,df,p)
!
!  calculate right hand side of ONE OR MORE extra coupled PDEs
!  along the 'current' Pencil, i.e. f(l1:l2,m,n) where
!  m,n are global variables looped over in equ.f90
!
!  Due to the multi-step Runge Kutta timestepping used one MUST always
!  add to the present contents of the df array.  NEVER reset it to zero.
!
!  several precalculated Pencils of information are passed if for
!  efficiency.
!
!   13-aug-07/steveb: coded
!
      use Cdata
      use Mpicomm
      use Sub
      use Global
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
     
      real, dimension (mx,3) :: glchemspec
      real, dimension (mx) :: uglchemspec 
      type (pencil_case) :: p


      integer :: k
!
      intent(in) :: f,p
      intent(inout) :: df
!
!  identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'dchemistry_dt: SOLVE dchemistry_dt'
!!      if (headtt) call identify_bcs('ss',iss)
!
!!
!! SAMPLE DIAGNOSTIC IMPLEMENTATION
!!
!!      if(ldiagnos) then
!!        if(i_SPECIAL_DIAGNOSTIC/=0) then
!!          call sum_mn_name(SOME MATHEMATICAL EXPRESSION,i_SPECIAL_DIAGNOSTIC)
!!! see also integrate_mn_name
!!        endif
!!      endif

       do k=1,nchemspec

     
        call grad(f,ichemspec(k),glchemspec) 

       
        call dot_mn(p%uu,glchemspec,uglchemspec)
      
        df(l1:l2,m,n,ichemspec(k)) = df(l1:l2,m,n,ichemspec(k)) - uglchemspec(l1:l2)
       enddo 


! Keep compiler quiet by ensuring every parameter is used
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)

    endsubroutine dchemistry_dt
!***********************************************************************
    subroutine read_chemistry_init_pars(unit,iostat)
!
      use Sub, only: keep_compiler_quiet
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) call keep_compiler_quiet(iostat)
      call keep_compiler_quiet(unit)

    endsubroutine read_chemistry_init_pars
!***********************************************************************
    subroutine write_chemistry_init_pars(unit)
!
      use Sub, only: keep_compiler_quiet
!
      integer, intent(in) :: unit

      call keep_compiler_quiet(unit)

    endsubroutine write_chemistry_init_pars
!***********************************************************************
    subroutine read_chemistry_run_pars(unit,iostat)
!
      use Sub, only: keep_compiler_quiet
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) call keep_compiler_quiet(iostat)
      call keep_compiler_quiet(unit)

    endsubroutine read_chemistry_run_pars
!***********************************************************************
    subroutine write_chemistry_run_pars(unit)
!
      use Sub, only: keep_compiler_quiet
!
      integer, intent(in) :: unit

      call keep_compiler_quiet(unit)

    endsubroutine write_chemistry_run_pars
!***********************************************************************
    subroutine rprint_chemistry(lreset,lwrite)
!
!  reads and registers print parameters relevant to chemistry
!
!  13-aug-07/steveb: coded
!
      use Cdata
      use Sub
      use General, only: chn
!!
!!!   SAMPLE IMPLEMENTATION
!!
!!      integer :: iname
      logical :: lreset,lwr
      logical, optional :: lwrite
      character (len=5) :: schem,schemspec,snd1,smd1,smi1
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
!!        i_SPECIAL_DIAGNOSTIC=0
      endif
!
      call chn(nchemspec,schemspec)
!!
!!      do iname=1,nname
!!        call parse_name(iname,cname(iname),cform(iname),'NAMEOFSPECIALDIAGNOSTIC',i_SPECIAL_DIAGNOSTIC)
!!      enddo
!!
!!!  write column where which magnetic variable is stored
!!      if (lwr) then
!!        write(3,*) 'i_SPECIAL_DIAGNOSTIC=',i_SPECIAL_DIAGNOSTIC
!!      endif
!!

!
!  Write chemistry index in short notation
!XX
      call chn(ichemspec(1),snd1)
      if (lwr) then
        write(3,*) 'ichemspec=indgen('//trim(schemspec)//') + '//trim(snd1)
      endif
!
    endsubroutine rprint_chemistry
!***********************************************************************
    subroutine get_slices_chemistry(f,slices)
!
!  Write slices for animation of chemistry variables.
!
!  13-aug-07/steveb: dummy
!
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(slices%ready)
!
    endsubroutine get_slices_chemistry
!***********************************************************************
    subroutine special_calc_density(f,df,p)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   13-aug-07/steveb: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p

!!
!!  SAMPLE IMPLEMENTATION
!!     (remember one must ALWAYS add to df)
!!
!!
!!  df(l1:l2,m,n,ilnrho) = df(l1:l2,m,n,ilnrho) + SOME NEW TERM
!!
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_density
!***********************************************************************
    subroutine special_calc_hydro(f,df,p)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   13-aug-07/steveb: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet

      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p

!!
!!  SAMPLE IMPLEMENTATION
!!     (remember one must ALWAYS add to df)
!!
!!
!!  df(l1:l2,m,n,iux) = df(l1:l2,m,n,iux) + SOME NEW TERM
!!  df(l1:l2,m,n,iuy) = df(l1:l2,m,n,iuy) + SOME NEW TERM
!!  df(l1:l2,m,n,iuz) = df(l1:l2,m,n,iuz) + SOME NEW TERM
!!
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_hydro
!***********************************************************************
    subroutine special_calc_magnetic(f,df,p)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   13-aug-07/steveb: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet

      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p

!!
!!  SAMPLE IMPLEMENTATION
!!     (remember one must ALWAYS add to df)
!!
!!
!!  df(l1:l2,m,n,iux) = df(l1:l2,m,n,iux) + SOME NEW TERM
!!  df(l1:l2,m,n,iuy) = df(l1:l2,m,n,iuy) + SOME NEW TERM
!!  df(l1:l2,m,n,iuz) = df(l1:l2,m,n,iuz) + SOME NEW TERM
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_magnetic
!!***********************************************************************
    subroutine special_calc_entropy(f,df,p)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   13-aug-07/steveb: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet

      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p

!!
!!  SAMPLE IMPLEMENTATION
!!     (remember one must ALWAYS add to df)
!!
!!
!!  df(l1:l2,m,n,ient) = df(l1:l2,m,n,ient) + SOME NEW TERM
!!
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_entropy
!***********************************************************************
    subroutine special_boundconds(f,bc)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   13-aug-07/steveb: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      type (boundary_condition) :: bc
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(bc)
!
    endsubroutine special_boundconds
!***********************************************************************
    subroutine special_before_boundary(f)
!
!   Possibility to modify the f array before the boundaries are
!   communicated.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-jul-06/tony: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine special_before_boundary
!***********************************************************************

!********************************************************************
!************        DO NOT DELETE THE FOLLOWING       **************
!********************************************************************
!**  This is an automatically generated include file that creates  **
!**  copies dummy routines from nospecial.f90 for any Special      **
!**  routines not implemented in this file                         **
!**                                                                **
    include 'special_dummies.inc'
!********************************************************************

endmodule Chemistry

