MODULE oasis_toy_model_receive_mod
!==========================================================
!* PURPOSE: simplified OASIS3-MCT receive interface for coupling CaMa-Flood
!  with the toy land model (surface / sub-surface runoff).
!  Unlike oasis_rivers_control_mod, this module has no JULES dependency.
!
!  CaMa-Flood is registered as component 'cmamod' (the toy land model is 'toymod').
!  The input grid (NXIN x NYIN) is owned by CaMa-Flood rank 0 of the OASIS local communicator
!  (apple partition; other ranks hold 0 points). The received fields are broadcast to all
!  CaMa-Flood ranks, so any number of MPI ranks can be used.
!==========================================================
USE mod_oasis,        ONLY: oasis_init_comp, oasis_get_localcomm, oasis_def_partition,  &
                          & oasis_def_var, oasis_enddef, oasis_get, oasis_terminate,    &
                          & oasis_abort, oasis_in, oasis_real, oasis_recvd,             &
                          & oasis_fromrest, oasis_input, oasis_recvout,                 &
                          & oasis_fromrestout, oasis_ok
USE mod_oasis_kinds,  ONLY: ip_realwp_p
USE MPI
USE YOS_CMF_MAP,      ONLY: REGIONALL, REGIONTHIS, MPI_COMM_CAMA

IMPLICIT NONE

PRIVATE

PUBLIC :: oasis_toy_init, oasis_toy_set_comm, oasis_toy_partition, oasis_toy_grid, oasis_toy_variables, &
        & oasis_toy_receive, oasis_toy_finalise

CHARACTER(LEN=*), PARAMETER :: CCOMP_NAME = 'cmamod'          !! component name in namcouple $NBMODEL
CHARACTER(LEN=*), PARAMETER :: CGRID_NAME = 'cama'            !! grid name in namcouple
CHARACTER(LEN=*), PARAMETER :: CSURF_NAME = 'surf_roff'       !! received surface runoff (namcouple target)
CHARACTER(LEN=*), PARAMETER :: CSUB_NAME  = 'sub_surf_roff'   !! received sub-surface runoff (namcouple target)

INTEGER :: ICOMPID  = -1     !! OASIS component id
INTEGER :: IPARTID  = -1     !! OASIS partition id
INTEGER :: ISURFID  = -1     !! OASIS variable id (surface runoff)
INTEGER :: ISUBID   = -1     !! OASIS variable id (sub-surface runoff)
INTEGER :: ICOMM    = -1     !! MPI communicator allocated to this component
INTEGER :: IRANK    = 0      !! rank in ICOMM (0 owns the OASIS data)
INTEGER :: ILOCSIZE = 0      !! number of grid points owned by this rank

CONTAINS
!==========================================================
SUBROUTINE oasis_toy_init()
! initialise OASIS and get the local MPI communicator
IMPLICIT NONE
INTEGER :: IERR, IERR2
!================================================
CALL oasis_init_comp(ICOMPID, CCOMP_NAME, IERR)
CALL CHECK_ERR(IERR, "oasis_init_comp")

CALL oasis_get_localcomm(ICOMM, IERR2)
CALL CHECK_ERR(IERR2, "oasis_get_localcomm")
WRITE(6,*) "oasis_toy_init: component ", CCOMP_NAME, " initialised"

END SUBROUTINE oasis_toy_init
!==========================================================
SUBROUTINE oasis_toy_set_comm()
! restrict CaMa-Flood MPI to the component communicator (MPI_COMM_WORLD also contains the toy model)
IMPLICIT NONE
INTEGER :: IERR, ISIZE
!================================================
CALL MPI_Comm_size(ICOMM, ISIZE, IERR)
CALL MPI_Comm_rank(ICOMM, IRANK, IERR)
MPI_COMM_CAMA = ICOMM
REGIONALL     = ISIZE
REGIONTHIS    = IRANK+1

END SUBROUTINE oasis_toy_set_comm
!==========================================================
SUBROUTINE oasis_toy_partition(NX, NY)
! define the apple partition of the NX x NY grid: rank 0 owns all points, other ranks none
IMPLICIT NONE
INTEGER, INTENT(IN) :: NX, NY
INTEGER             :: IGPARAL(3), IERR
!================================================
ILOCSIZE = 0
IF( IRANK==0 ) ILOCSIZE = NX*NY

IGPARAL(1) = 1          !! apple partition
IGPARAL(2) = 0          !! offset
IGPARAL(3) = ILOCSIZE

CALL oasis_def_partition(IPARTID, IGPARAL, IERR)
CALL CHECK_ERR(IERR, "oasis_def_partition")

END SUBROUTINE oasis_toy_partition
!==========================================================
SUBROUTINE oasis_toy_grid(NX, NY, LON1D, LAT1D)
! write the grid description; only needed when OASIS remaps between the toy and CaMa-Flood grids
USE mod_oasis, ONLY: oasis_start_grids_writing, oasis_write_grid, oasis_write_mask, &
                   & oasis_terminate_grids_writing
IMPLICIT NONE
INTEGER,  INTENT(IN) :: NX, NY
REAL(KIND=ip_realwp_p), INTENT(IN) :: LON1D(NX), LAT1D(NY)
REAL(KIND=ip_realwp_p) :: LON2D(NX,NY), LAT2D(NX,NY)
INTEGER                :: MASK(NX,NY), IFLAG, IX, IY
!================================================
DO IY=1,NY
  DO IX=1,NX
    LON2D(IX,IY) = LON1D(IX)
    LAT2D(IX,IY) = LAT1D(IY)
  ENDDO
ENDDO
MASK(:,:) = 0     !! 0: valid point

CALL oasis_start_grids_writing(IFLAG)
IF( IFLAG/=0 )THEN
  CALL oasis_write_grid(CGRID_NAME, NX, NY, LON2D, LAT2D)
  CALL oasis_write_mask(CGRID_NAME, NX, NY, MASK)
ENDIF
CALL oasis_terminate_grids_writing()

END SUBROUTINE oasis_toy_grid
!==========================================================
SUBROUTINE oasis_toy_variables(NX, NY)
! declare the received variables and close the OASIS definition phase
IMPLICIT NONE
INTEGER, INTENT(IN)       :: NX, NY
INTEGER, PARAMETER        :: IVARNODIMS(2) = [1,1]
INTEGER                   :: IVARSHAPE(2), IERR
!================================================
IVARSHAPE(:) = [1, ILOCSIZE]

CALL oasis_def_var(ISURFID, CSURF_NAME, IPARTID, IVARNODIMS, oasis_in, IVARSHAPE, oasis_real, IERR)
CALL CHECK_ERR(IERR, "oasis_def_var "//CSURF_NAME)

CALL oasis_def_var(ISUBID, CSUB_NAME, IPARTID, IVARNODIMS, oasis_in, IVARSHAPE, oasis_real, IERR)
CALL CHECK_ERR(IERR, "oasis_def_var "//CSUB_NAME)

CALL oasis_enddef(IERR)
CALL CHECK_ERR(IERR, "oasis_enddef")

END SUBROUTINE oasis_toy_variables
!==========================================================
SUBROUTINE oasis_toy_receive(ITIME, NX, NY, SURF_ROFF_2D, SUB_SURF_ROFF_2D)
! receive surface and sub-surface runoff at model time ITIME [s]
IMPLICIT NONE
INTEGER, INTENT(IN)                :: ITIME
INTEGER, INTENT(IN)                :: NX, NY
REAL(KIND=ip_realwp_p), INTENT(OUT) :: SURF_ROFF_2D(NX,NY)
REAL(KIND=ip_realwp_p), INTENT(OUT) :: SUB_SURF_ROFF_2D(NX,NY)
REAL(KIND=ip_realwp_p)             :: RCV(NX*NY), RCVLOC(ILOCSIZE)
INTEGER                            :: IERR
!================================================
RCVLOC(:) = 0._ip_realwp_p
CALL oasis_get(ISURFID, ITIME, RCVLOC, IERR)
CALL CHECK_RCV(IERR, CSURF_NAME)
RCV(:) = 0._ip_realwp_p
IF( IRANK==0 ) RCV(:) = RCVLOC(:)
CALL MPI_Bcast(RCV, NX*NY, MPI_REAL8, 0, ICOMM, IERR)
SURF_ROFF_2D(:,:) = RESHAPE(RCV, [NX,NY])

RCVLOC(:) = 0._ip_realwp_p
CALL oasis_get(ISUBID, ITIME, RCVLOC, IERR)
CALL CHECK_RCV(IERR, CSUB_NAME)
RCV(:) = 0._ip_realwp_p
IF( IRANK==0 ) RCV(:) = RCVLOC(:)
CALL MPI_Bcast(RCV, NX*NY, MPI_REAL8, 0, ICOMM, IERR)
SUB_SURF_ROFF_2D(:,:) = RESHAPE(RCV, [NX,NY])

IF( IRANK==0 ) WRITE(6,*) "oasis_toy_receive: received runoff at time [s]:", ITIME

END SUBROUTINE oasis_toy_receive
!==========================================================
SUBROUTINE oasis_toy_finalise()
! terminate OASIS coupling
IMPLICIT NONE
INTEGER :: IERR
!================================================
CALL oasis_terminate(IERR)
CALL CHECK_ERR(IERR, "oasis_terminate")

END SUBROUTINE oasis_toy_finalise
!==========================================================
SUBROUTINE CHECK_ERR(KERR, CWHAT)
IMPLICIT NONE
INTEGER,          INTENT(IN) :: KERR
CHARACTER(LEN=*), INTENT(IN) :: CWHAT
!================================================
IF( KERR/=0 )THEN
  WRITE(6,*) "oasis_toy_model_receive_mod: error in ", CWHAT, ", IERR=", KERR
  CALL oasis_abort(ICOMPID, 'oasis_toy_model_receive_mod', 'OASIS toy coupling failed in '//CWHAT)
ENDIF

END SUBROUTINE CHECK_ERR
!==========================================================
SUBROUTINE CHECK_RCV(KINFO, CWHAT)
IMPLICIT NONE
INTEGER,          INTENT(IN) :: KINFO
CHARACTER(LEN=*), INTENT(IN) :: CWHAT
!================================================
IF( KINFO/=oasis_recvd .AND. KINFO/=oasis_fromrest .AND. KINFO/=oasis_input .AND. &
  & KINFO/=oasis_recvout .AND. KINFO/=oasis_fromrestout .AND. KINFO/=oasis_ok )THEN
  WRITE(6,*) "oasis_toy_receive: oasis_get error for ", CWHAT, ", IERR=", KINFO
  CALL oasis_abort(ICOMPID, 'oasis_toy_model_receive_mod', 'oasis_get failed for '//CWHAT)
ENDIF

END SUBROUTINE CHECK_RCV
!==========================================================
END MODULE oasis_toy_model_receive_mod
