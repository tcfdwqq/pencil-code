! $Id: grav_z.f90,v 1.10 2002-06-01 02:56:21 brandenb Exp $

module Gravity

!
!  Vertical gravity (for convection tests, etc.)
!

  use Cparam
  use Cdata, only: z1,z2,ztop,gravz

  implicit none

  namelist /grav_z_init_pars/ &
       z1,z2,ztop,gravz

  namelist /grav_z_run_pars/ &
       gravz

  contains

!***********************************************************************
    subroutine register_grav()
!
!  initialise gravity flags
!
!  9-jan-02/wolf: coded
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_grav called twice')
      first = .false.
!
!  identify version number (generated automatically by CVS)
!
      if (lroot) call cvs_id( &
           "$RCSfile: grav_z.f90,v $", &
           "$Revision: 1.10 $", &
           "$Date: 2002-06-01 02:56:21 $")
!
      lgrav = .true.
      lgravz = .true.
      lgravr = .false.
!
    endsubroutine register_grav
!***********************************************************************
    subroutine init_grav(f,xx,yy,zz)
!
!  initialise gravity; called from start.f90
!  9-jan-02/wolf: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar) :: f
      real, dimension (mx,my,mz) :: xx,yy,zz
!
! Not doing anything (this might change if we decide to store gg)
!
!
    endsubroutine init_grav
!***********************************************************************
    subroutine duu_dt_grav(f,df)
!
!  add duu/dt according to gravity
!
!  9-jan-02/wolf: coded
!
      use Cdata
!      use Mpicomm
      use Sub
      use Slices
!
      real, dimension (mx,my,mz,mvar) :: f,df
!
      df(l1:l2,m,n,iuz) = df(l1:l2,m,n,iuz) + gravz
!
    endsubroutine duu_dt_grav
!***********************************************************************
    subroutine potential(xmn,ymn,zmn,rmn, pot)
!
!  gravity potential
!  21-jan-02/wolf: coded
!
      use Cdata, only: nx,ny,nz,gravz
      use Sub, only: poly
!
      real, dimension (nx,1,1) :: xmn,ymn,zmn,rmn, pot
!
      pot = -gravz*zmn
!
    endsubroutine potential
!***********************************************************************

endmodule Gravity
