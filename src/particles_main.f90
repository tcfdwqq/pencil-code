! $Id: particles_main.f90,v 1.32 2006-06-26 12:07:59 ajohan Exp $
!
!  This module contains all the main structure needed for particles.
!
module Particles_main

  use Cdata
  use Particles_cdata
  use Particles_sub
  use Particles
  use Particles_radius
  use Particles_number
  use Particles_selfgravity
  use Messages

  implicit none

  include 'particles_main.h'

  real, dimension (mpar_loc,mpvar) :: fp, dfp
  integer, dimension (mpar_loc,3) :: ineargrid

  contains

!***********************************************************************
    subroutine particles_register_modules()
!
!  Register particle modules.
!
!  07-jan-05/anders: coded
!
      call register_particles         ()
      call register_particles_radius  ()
      call register_particles_number  ()
      call register_particles_selfgrav()
!
    endsubroutine particles_register_modules
!***********************************************************************
    subroutine particles_rprint_list(lreset)
!
!  Read names of diagnostic particle variables to print out during run.
!
!  07-jan-05/anders: coded
!
      logical :: lreset
!
      if (lroot) open(3, file=trim(datadir)//'/index.pro', &
          STATUS='old', POSITION='append')
      call rprint_particles         (lreset,LWRITE=lroot)
      call rprint_particles_radius  (lreset,LWRITE=lroot)
      call rprint_particles_number  (lreset,LWRITE=lroot)
      call rprint_particles_selfgrav(lreset,LWRITE=lroot)
      if (lroot) close(3)
!
    endsubroutine particles_rprint_list
!***********************************************************************
    subroutine particles_initialize_modules(lstarting)
!
!  Initialize particle modules.
!
!  07-jan-05/anders: coded
!
      logical :: lstarting
!
!  Check if there is enough total space allocated for particles.
!
      if (ncpus*mpar_loc<npar) then
        if (lroot) then
          print*, 'particles_initialize_modules: '// &
          'total number of particle slots available at the processors '// &
          'is smaller than the number of particles!'
          print*, 'particles_initialize_modules: npar/ncpus=', npar/ncpus
          print*, 'particles_initialize_modules: mpar_loc-ncpus*npar_mig=', &
              mpar_loc-ncpus*npar_mig
        endif
        call fatal_error('particles_initialize_modules','')
      endif
!
      call initialize_particles         (lstarting)
      call initialize_particles_radius  (lstarting)
      call initialize_particles_number  (lstarting)
      call initialize_particles_selfgrav(lstarting)
!
    endsubroutine particles_initialize_modules
!***********************************************************************
    subroutine particles_init(f)
!
!  Set up initial condition for particle modules.
!
!  07-jan-05/anders: coded
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      intent (out) :: f
!
      call init_particles(f,fp,ineargrid)
      if (lparticles_radius) call init_particles_radius(f,fp)
      if (lparticles_number) call init_particles_number(f,fp)
!
    endsubroutine particles_init
!***********************************************************************
    subroutine particles_read_snapshot(filename)
!
!  Read particle snapshot from file.
!
!  07-jan-05/anders: coded
!
      character (len=*) :: filename
!
      call input_particles(filename,fp,npar_loc,ipar)
!
    endsubroutine particles_read_snapshot
!***********************************************************************
    subroutine particles_write_snapshot(chsnap,msnap,enum,flist)
!
!  Write particle snapshot to file.
!
!  07-jan-05/anders: coded
!
      integer :: msnap
      logical :: enum
      character (len=*) :: chsnap,flist
      optional :: flist
!
      logical :: lsnap
!
      if (present(flist)) then
        call wsnap_particles(chsnap,fp,msnap,enum,lsnap,dsnap_par_minor, &
            npar_loc,ipar,flist)
      else
        call wsnap_particles(chsnap,fp,msnap,enum,lsnap,dsnap_par_minor, &
            npar_loc,ipar)
      endif
!
    endsubroutine particles_write_snapshot
!***********************************************************************
    subroutine particles_write_dsnapshot(chsnap,msnap,enum,flist)
!
!  Write particle derivative snapshot to file.
!
!  07-jan-05/anders: coded
!
      integer :: msnap
      logical :: enum
      character (len=*) :: chsnap,flist
      optional :: flist
!
      logical :: lsnap
!
      if (present(flist)) then
        call wsnap_particles(chsnap,dfp,msnap,enum,lsnap,dsnap_par_minor, &
            npar_loc,ipar,flist)
      else
        call wsnap_particles(chsnap,dfp,msnap,enum,lsnap,dsnap_par_minor, &
            npar_loc,ipar)
      endif
!
    endsubroutine particles_write_dsnapshot
!***********************************************************************
    subroutine particles_write_pdim(filename)
!   
!  Write npar and mpvar to file.
!
!  09-jan-05/anders: coded
!
      character (len=*) :: filename
!
      open(1,file=filename)
        write(1,'(2i9)') npar, mpvar
      close(1)
!
    endsubroutine particles_write_pdim
!***********************************************************************
    subroutine particles_timestep_first()
!
!  Setup dfp in the beginning of each itsub.
!
!  07-jan-05/anders: coded
!
      if (itsub==1) then
        dfp(1:npar_loc,:)=0.
      else
        dfp(1:npar_loc,:)=alpha(itsub)*dfp(1:npar_loc,:)
      endif
!
    endsubroutine particles_timestep_first
!***********************************************************************
    subroutine particles_timestep_second()
!
!  Time evolution of particle variables.
!
!  07-jan-05/anders: coded
!
      fp(1:npar_loc,:) = fp(1:npar_loc,:) + dt_beta(itsub)*dfp(1:npar_loc,:)
!
    endsubroutine particles_timestep_second
!***********************************************************************
    subroutine particles_boundconds(f)
!
!  Particle boundary conditions and parallel communication.
!
!  16-feb-06/anders: coded
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!      
      call boundconds_particles(fp,npar_loc,ipar,dfp=dfp)
!
!  Map the particle positions on the grid for later use.
!
      call map_nearest_grid(f,fp,ineargrid)
      call map_xxp_grid(f,fp,ineargrid)
!
!  Sort particles so that they can be accessed contiguously in the memory.
!      
      if (.not.lparticles_planet) &
           call sort_particles_imn(fp,ineargrid,ipar,dfp=dfp)
!
    endsubroutine particles_boundconds
!***********************************************************************
    subroutine particles_pencil_criteria()
!
!  Request pencils for particles.
!
!  20-apr-06/anders: coded
!
      call pencil_criteria_particles()
!
    endsubroutine particles_pencil_criteria
!***********************************************************************
    subroutine particles_pencil_interdep(lpencil_in)
!
!  Calculate particle pencils.
!
!  15-feb-06/anders: coded
!
      logical, dimension(npencils) :: lpencil_in
!
      call pencil_interdep_particles(lpencil_in)
!
    endsubroutine particles_pencil_interdep
!***********************************************************************
    subroutine particles_calc_selfpotential(f,rhs_poisson,rhs_poisson_const,lcontinued)
!
!  Calculate the potential of the dust particles (wrapper).
!
!  13-jun-06/anders: coded
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (nx,ny,nz) :: rhs_poisson
      real :: rhs_poisson_const
      logical :: lcontinued
!
      call calc_selfpotential_particles(f,rhs_poisson,rhs_poisson_const,lcontinued)
!
    endsubroutine particles_calc_selfpotential
!***********************************************************************
    subroutine particles_calc_pencils(f,p)
!
!  Calculate particle pencils.
!
!  14-feb-06/anders: coded
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (pencil_case) :: p
!
      call calc_pencils_particles(f,p)
!      call calc_pencils_particles_radius(f,p)
!      call calc_pencils_particles_number(f,p)
!
    endsubroutine particles_calc_pencils
!***********************************************************************
    subroutine particles_pde_pencil(f,df,p)
!
!  Dynamical evolution of particle variables.
!
!  20-apr-06/anders: coded
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      intent (in) :: p
      intent (inout) :: f, df
!
!  Dynamical equations.
!
      call dxxp_dt_pencil(f,df,fp,dfp,p,ineargrid)
      call dvvp_dt_pencil(f,df,fp,dfp,p,ineargrid)
!      if (lparticles_radius) call dap_dt(f,df,fp,dfp,ineargrid)
!      if (lparticles_number) call dnptilde_dt(f,df,fp,dfp,ineargrid)
!
    endsubroutine particles_pde_pencil
!***********************************************************************
    subroutine particles_pde(f,df)
!
!  Dynamical evolution of particle variables.
!
!  07-jan-05/anders: coded
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
!
      intent (out) :: f, df
!
!  Dynamical equations.
!
      call dxxp_dt(f,df,fp,dfp,ineargrid)
      call dvvp_dt(f,df,fp,dfp,ineargrid)
      if (lparticles_radius)      call dap_dt(f,df,fp,dfp,ineargrid)
      if (lparticles_number)      call dnptilde_dt(f,df,fp,dfp,ineargrid)
      if (lparticles_selfgravity) call dvvp_dt_selfgrav(f,df,fp,dfp,ineargrid)
!
    endsubroutine particles_pde
!***********************************************************************
    subroutine read_particles_init_pars_wrap(unit,iostat)
!    
      integer, intent (in) :: unit
      integer, intent (inout), optional :: iostat
!
      call read_particles_init_pars(unit,iostat)
      if (lparticles_radius) call read_particles_rad_init_pars(unit,iostat)
      if (lparticles_number) call read_particles_num_init_pars(unit,iostat)
      if (lparticles_selfgravity) &
          call read_particles_selfg_init_pars(unit,iostat)
!
    endsubroutine read_particles_init_pars_wrap
!***********************************************************************
    subroutine write_particles_init_pars_wrap(unit)
!    
      integer, intent (in) :: unit
!
      call write_particles_init_pars(unit)
      if (lparticles_radius) call write_particles_rad_init_pars(unit)
      if (lparticles_number) call write_particles_num_init_pars(unit)
      if (lparticles_selfgravity) &
          call write_particles_selfg_init_pars(unit)
!
    endsubroutine write_particles_init_pars_wrap
!***********************************************************************
    subroutine read_particles_run_pars_wrap(unit,iostat)
!    
      integer, intent (in) :: unit
      integer, intent (inout), optional :: iostat
!
      call read_particles_run_pars(unit,iostat)
      if (lparticles_radius) call read_particles_rad_run_pars(unit,iostat)
      if (lparticles_number) call read_particles_num_run_pars(unit,iostat)
      if (lparticles_selfgravity) &
          call read_particles_selfg_run_pars(unit,iostat)
!
    endsubroutine read_particles_run_pars_wrap
!***********************************************************************
    subroutine write_particles_run_pars_wrap(unit)
!    
      integer, intent (in) :: unit
!
      call write_particles_run_pars(unit)
      if (lparticles_radius) call write_particles_rad_run_pars(unit)
      if (lparticles_number) call write_particles_num_run_pars(unit)
      if (lparticles_selfgravity) &
          call write_particles_selfg_run_pars(unit)
!
    endsubroutine write_particles_run_pars_wrap
!***********************************************************************
    subroutine particles_powersnap(f)
!
!  Calculate power spectra of particle variables.
!
!  01-jan-06/anders: coded
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      call powersnap_particles(f)
!
    endsubroutine particles_powersnap
!***********************************************************************
    subroutine particles_wvid(f,path,lfirstloop,lnewfile)
!
!  Write slices for animation of particle variables.
!
!  26-jun-06/anders: split from wvid
!
      use Sub, only: wslice
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      character(len=*) :: path
      logical :: lfirstloop, lnewfile
!
      real, dimension (nx,ny) :: np_xy, np_xy2, rhop_xy, rhop_xy2
      real, dimension (nx,nz) :: np_xz, rhop_xz
      real, dimension (ny,nz) :: np_yz, rhop_yz
      integer :: inamev
!
!  Loop over slices
!
      do inamev=1,nnamev
        select case (trim(cnamev(inamev)))
!
!  Dust number density (auxiliary variable)
!
        case ('np')
          np_yz=f(ix_loc,m1:m2,n1:n2,inp)
          np_xz=f(l1:l2,iy_loc,n1:n2,inp)
          np_xy=f(l1:l2,m1:m2,iz_loc,inp)
          np_xy2=f(l1:l2,m1:m2,iz2_loc,inp)
          call wslice(path//'np.yz',np_yz,x(ix_loc),ny,nz)
          call wslice(path//'np.xz',np_xz,y(iy_loc),nx,nz)
          call wslice(path//'np.xy',np_xy,z(iz_loc),nx,ny)
          call wslice(path//'np.Xy',np_xy2,z(iz2_loc),nx,ny)
!
!  Dust density (auxiliary variable)
!
        case ('rhop')
          if (irhop/=0) then
            rhop_yz=f(ix_loc,m1:m2,n1:n2,irhop)
            rhop_xz=f(l1:l2,iy_loc,n1:n2,irhop)
            rhop_xy=f(l1:l2,m1:m2,iz_loc,irhop)
            rhop_xy2=f(l1:l2,m1:m2,iz2_loc,irhop)
          else
            rhop_yz=rhop_tilde*f(ix_loc,m1:m2,n1:n2,inp)
            rhop_xz=f(l1:l2,iy_loc,n1:n2,inp)
            rhop_xy=f(l1:l2,m1:m2,iz_loc,inp)
            rhop_xy2=f(l1:l2,m1:m2,iz2_loc,inp)
          endif
          call wslice(path//'rhop.yz',rhop_yz,x(ix_loc),ny,nz)
          call wslice(path//'rhop.xz',rhop_xz,y(iy_loc),nx,nz)
          call wslice(path//'rhop.xy',rhop_xy,z(iz_loc),nx,ny)
          call wslice(path//'rhop.Xy',rhop_xy2,z(iz2_loc),nx,ny)
!
!  Catch unknown values
!
        case default
          if (lfirstloop.and.lroot) then
            if (lnewfile) then
              open(1,file='video.err')
              lnewfile=.false.
            else
              open(1,file='video.err',position='append')
            endif
            write(1,*) 'unknown slice: ',trim(cnamev(inamev))
            close(1)
          endif
!
        endselect
      enddo
!
    endsubroutine particles_wvid
!***********************************************************************
    subroutine auxcall_gravcomp(f,df,g0,r0_pot,n_pot,p)
!
!  Auxiliary call to gravity_companion in order 
!  to fetch the array fp inside the mn loop  
!
!  01-feb-06/wlad : coded 
!
      use Planet, only : gravity_companion
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real :: g0,r0_pot
      integer :: n_pot
      type (pencil_case) :: p
!
      call gravity_companion(f,df,fp,dfp,g0,r0_pot,n_pot,p)
!
    endsubroutine auxcall_gravcomp
!***********************************************************************
endmodule Particles_main
