! $Id: start.f90,v 1.33 2002-06-01 02:56:21 brandenb Exp $
!
!***********************************************************************
      program start
!
!  start, to setup initial condition and file structure
!
!-----------------------------------------------------------------------
!  01-apr-01/axel+wolf: coded
!  01-sep-01/axel: adapted to MPI
!
        use Cdata
        use General
        use Mpicomm
        use Sub
        use Register
        use Global
        use Param_IO
!
        implicit none
!
!  define parameters
!
        integer :: i
        real, dimension (mx,my,mz,mvar) :: f
        real, dimension (mx,my,mz) :: xx,yy,zz
!
        call initialize         ! register modules, etc.
!
!  identify version
!
        if (lroot) call cvs_id( &
             "$RCSfile: start.f90,v $", &
             "$Revision: 1.33 $", &
             "$Date: 2002-06-01 02:56:21 $")
!
!  set default values
!
        xyz0 = (/  -pi,  -pi,  -pi /) ! first corner
        Lxyz = (/ 2*pi, 2*pi, 2*pi /) ! box lengths
        lperi =(/.true.,.true.,.true. /) ! periodicity
        z1=0; z2=1; ztop=1.32
        cs0=1; gamma=5./3.; rho0=1.
!
!  read parameters from start.in
!
        call read_inipars()
!
!  write input parameters to a parameter file (for run.x and IDL)
!
        gamma1 = gamma-1.
        call wparam()
        x0 = xyz0(1) ; y0 = xyz0(2) ; z0 = xyz0(3)
        Lx = Lxyz(1) ; Ly = Lxyz(2) ; Lz = Lxyz(3)
!
!  generate mesh, |x| < Lx, and similar for y and z.
!  lperi indicate periodicity of given direction
!
        if (lperi(1)) then; dx = Lx/nxgrid; else; dx = Lx/(nxgrid-1); endif
        if (lperi(2)) then; dy = Ly/nygrid; else; dy = Ly/(nygrid-1); endif
        if (lperi(3)) then; dz = Lz/nzgrid; else; dz = Lz/(nzgrid-1); endif
!
!  set x,y,z arrays
!
        do i=1,mx; x(i)=x0+(i-nghost-1+ipx*nx)*dx; enddo
        do i=1,my; y(i)=y0+(i-nghost-1+ipy*ny)*dy; enddo
        do i=1,mz; z(i)=z0+(i-nghost-1+ipz*nz)*dz; enddo
!
!  write grid.dat file
!
        call wgrid(trim(directory)//'/grid.dat')
!
!  as full arrays
!
        xx=spread(spread(x,2,my),3,mz)
        yy=spread(spread(y,1,mx),3,mz)
        zz=spread(spread(z,1,mx),2,my)
!
!        rr=sqrt(xx**2+yy**2+zz**2)
!        m_pot=(1.+rr**2)/(1.+rr**2+rr**3) ! negative potential
!
        cs20=cs0**2 ! (goes into cdata module)
!
!  different initial conditions
!
        f = 0.
        call init_hydro(f,xx,yy,zz)
        call init_ent  (f,xx,yy,zz)
        call init_aa   (f,xx,yy,zz)
        call init_grav (f,xx,yy,zz)
!
!  write to disk
!
        call output(trim(directory)//'/var.dat',f,mvar)
        call wdim(trim(directory)//'/dim.dat')
!  also write full dimensions to tmp/ :
        if (lroot) call wdim('tmp/dim.dat', &
             nxgrid+2*nghost,nygrid+2*nghost,nzgrid+2*nghost)
!  write global variables:
        call wglobal()
!
!  seed for random number generator, have to have the same on each
!  processor as forcing is applied in (global) Beltrami modes
!
        seed(1)=1000
        call outpui(trim(directory)//'/seed.dat',seed,2)
        if (iproc < 10) print*,'iproc,seed(1:2)=',iproc,seed
!
        call mpifinalize
!
      endprogram
