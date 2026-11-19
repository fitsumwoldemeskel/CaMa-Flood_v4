MODULE CMF_CTRL_OASIS_MOD
!==========================================================
!* PURPOSE: OASIS3-MCT coupler for CaMa-Flood (receives runoff from a land surface model)
!
! Model independent: works with JULES and with the toy land model. Only the
! names in the NOASIS namelist (and the namcouple) differ between them.
!
! -- CMF_OASIS_INPUT       : read NOASIS namelist, initialise OASIS & MPI   (before CMF_DRV_INPUT)
! -- CMF_OASIS_INIT        : partition, grid, variable definition           (after  CMF_DRV_INIT)
! -- CMF_OASIS_FORCING_GET : receive runoff and put it into the forcing buffer
! -- CMF_OASIS_END         : terminate OASIS (also finalises MPI)
!
! MPI: CaMa-Flood may run on any number of processes. The NXIN x NYIN input
! grid is split into contiguous blocks of grid points (OASIS Apple partition);
! each process receives its block and the blocks are assembled on every process
! with MPI_Allgatherv, because each process needs the input cells that
! overlap its own river cells (as when reading runoff from file).
!
! Licensed under the Apache License, Version 2.0 (the "License");
!   You may not use this file except in compliance with the License.
!   You may obtain a copy of the License at: http://www.apache.org/licenses/LICENSE-2.0
!
! Unless required by applicable law or agreed to in writing, software distributed under the License is
!  distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
! See the License for the specific language governing permissions and limitations under the License.
!==========================================================
USE PARKIND1,                ONLY: JPIM, JPRB
USE YOS_CMF_INPUT,           ONLY: LOGNAM
USE YOS_CMF_OASIS
USE MPI
IMPLICIT NONE
PRIVATE
PUBLIC :: CMF_OASIS_INPUT, CMF_OASIS_INIT, CMF_OASIS_FORCING_GET, CMF_OASIS_END
!==========================================================
CONTAINS
!####################################################################
SUBROUTINE CMF_OASIS_INPUT
! read NOASIS namelist, initialise OASIS and take the MPI communicator it allocates
USE mod_oasis,               ONLY: oasis_init_comp, oasis_get_localcomm
USE YOS_CMF_INPUT,           ONLY: CSETFILE
USE YOS_CMF_MAP,             ONLY: REGIONALL, REGIONTHIS, MPI_COMM_CAMA
USE CMF_UTILS_MOD,           ONLY: INQUIRE_FID
IMPLICIT NONE
INTEGER(KIND=JPIM)              :: IFID, IOS, IERR, IERR2, NPROC, NID
NAMELIST/NOASIS/ CCOMPNAME, CGRIDNAME, CSURFNAME, CSUBNAME, LWRTGRID
!================================================
!*** 1. defaults, then read namelist (log file is not open yet: use standard output)
CCOMPNAME = 'cmamod'
CGRIDNAME = 'camgrd'
CSURFNAME = 'surf_roff'
CSUBNAME  = 'sub_surf_roff'
LWRTGRID  = .FALSE.

IFID=INQUIRE_FID()
OPEN(IFID,FILE=CSETFILE,STATUS="OLD",IOSTAT=IOS)
IF( IOS==0 )THEN
  READ(IFID,NML=NOASIS,IOSTAT=IOS)
  IF( IOS/=0 ) WRITE(6,*) "CMF::OASIS_INPUT: NOASIS namelist not read, using defaults, IOSTAT=", IOS
  CLOSE(IFID)
ELSE
  WRITE(6,*) "CMF::OASIS_INPUT: cannot open ", TRIM(CSETFILE), ", using NOASIS defaults"
ENDIF

!*** 2. initialise OASIS (initialises MPI if needed) and get the local communicator
CALL oasis_init_comp(ICOMPID, TRIM(CCOMPNAME), IERR)
IF( IERR/=0 )THEN
  WRITE(6,*) "CMF::OASIS_INPUT: oasis_init_comp error, IERR=", IERR
  STOP 9
ENDIF
CALL oasis_get_localcomm(MPI_COMM_CAMA, IERR2)
IF( IERR2/=0 )THEN
  WRITE(6,*) "CMF::OASIS_INPUT: oasis_get_localcomm error, IERR=", IERR2
  STOP 9
ENDIF

CALL MPI_Comm_size(MPI_COMM_CAMA, NPROC, IERR)
CALL MPI_Comm_rank(MPI_COMM_CAMA, NID,   IERR)
REGIONALL =NPROC
REGIONTHIS=NID+1

END SUBROUTINE CMF_OASIS_INPUT
!####################################################################


!####################################################################
SUBROUTINE CMF_OASIS_INIT
! define partition, grid and coupling variables; close OASIS definition phase
USE mod_oasis,               ONLY: oasis_def_partition, oasis_def_var, oasis_enddef, &
                                 & oasis_in, oasis_real
USE YOS_CMF_INPUT,           ONLY: NXIN, NYIN
USE YOS_CMF_MAP,             ONLY: REGIONALL, REGIONTHIS
IMPLICIT NONE
INTEGER(KIND=JPIM)              :: IGPARAL(3), IERR, IPE, INTOT
INTEGER(KIND=JPIM),PARAMETER    :: IVARNODIMS(2) = [1,1]
INTEGER(KIND=JPIM)              :: IVARSHAPE(2)
!================================================
WRITE(LOGNAM,*) ""
WRITE(LOGNAM,*) "!---------------------!"
WRITE(LOGNAM,*) "CMF::OASIS_INIT: component, grid:       ", TRIM(CCOMPNAME), " ", TRIM(CGRIDNAME)
WRITE(LOGNAM,*) "CMF::OASIS_INIT: surface runoff field:  ", TRIM(CSURFNAME)
LSUBRCV = LEN_TRIM(CSUBNAME)>0
IF( LSUBRCV ) WRITE(LOGNAM,*) "CMF::OASIS_INIT: sub-surface runoff field:", TRIM(CSUBNAME)

ALLOCATE(R2SURF(NXIN,NYIN))
ALLOCATE(R2SUB(NXIN,NYIN))
R2SURF(:,:)=0._JPRB
R2SUB(:,:) =0._JPRB

!*** 1. split the flattened input grid into contiguous blocks, one per process
INTOT=NXIN*NYIN
ALLOCATE(ICOUNTS(REGIONALL), IDISPLS(REGIONALL))
DO IPE=1,REGIONALL
  ICOUNTS(IPE)=INTOT/REGIONALL
  IF( IPE<=MOD(INTOT,REGIONALL) ) ICOUNTS(IPE)=ICOUNTS(IPE)+1
ENDDO
IDISPLS(1)=0
DO IPE=2,REGIONALL
  IDISPLS(IPE)=IDISPLS(IPE-1)+ICOUNTS(IPE-1)
ENDDO
INLOC  =ICOUNTS(REGIONTHIS)
IOFFSET=IDISPLS(REGIONTHIS)
WRITE(LOGNAM,*) "CMF::OASIS_INIT: input grid points (offset, local, total):", IOFFSET, INLOC, INTOT

IGPARAL(1)=1        !! Apple partition
IGPARAL(2)=IOFFSET
IGPARAL(3)=INLOC
CALL oasis_def_partition(IPARTID, IGPARAL, IERR)
CALL CHECK_ERR(IERR, "oasis_def_partition")

!*** 2. grid description (only needed when OASIS remaps between grids)
IF( LWRTGRID ) CALL GRID_WRITE

!*** 3. receive variables (local block)
IVARSHAPE(:)=[1,INLOC]
CALL oasis_def_var(ISURFID, TRIM(CSURFNAME), IPARTID, IVARNODIMS, oasis_in, IVARSHAPE, oasis_real, IERR)
CALL CHECK_ERR(IERR, "oasis_def_var "//TRIM(CSURFNAME))
IF( LSUBRCV )THEN
  CALL oasis_def_var(ISUBID, TRIM(CSUBNAME), IPARTID, IVARNODIMS, oasis_in, IVARSHAPE, oasis_real, IERR)
  CALL CHECK_ERR(IERR, "oasis_def_var "//TRIM(CSUBNAME))
ENDIF

CALL oasis_enddef(IERR)
CALL CHECK_ERR(IERR, "oasis_enddef")
WRITE(LOGNAM,*) "CMF::OASIS_INIT: end"

CONTAINS
!==========================================================
!+ GRID_WRITE : write grids.nc / areas.nc / masks.nc for the regular lat-lon input grid
!==========================================================
SUBROUTINE GRID_WRITE
USE mod_oasis_kinds,         ONLY: ip_realwp_p
USE mod_oasis,               ONLY: oasis_start_grids_writing, oasis_write_grid, oasis_write_corner, &
                                 & oasis_write_area, oasis_write_mask, oasis_terminate_grids_writing
USE YOS_CMF_INPUT,           ONLY: WEST, EAST, NORTH, SOUTH
IMPLICIT NONE
REAL(KIND=ip_realwp_p),PARAMETER :: PI180 = 3.14159265358979323846_ip_realwp_p / 180._ip_realwp_p
REAL(KIND=ip_realwp_p)           :: DLON, DLAT
REAL(KIND=ip_realwp_p)           :: LON2(NXIN,NYIN), LAT2(NXIN,NYIN), AREA(NXIN,NYIN)
REAL(KIND=ip_realwp_p)           :: CLON(NXIN,NYIN,4), CLAT(NXIN,NYIN,4)
INTEGER(KIND=JPIM)               :: MASK(NXIN,NYIN)
INTEGER(KIND=JPIM)               :: IX, IY, IFLAG
!================================================
DLON=(REAL(EAST,ip_realwp_p)-REAL(WEST,ip_realwp_p))  /REAL(NXIN,ip_realwp_p)
DLAT=(REAL(NORTH,ip_realwp_p)-REAL(SOUTH,ip_realwp_p))/REAL(NYIN,ip_realwp_p)
DO IY=1,NYIN
  DO IX=1,NXIN
    LON2(IX,IY)=REAL(WEST,ip_realwp_p) +(REAL(IX,ip_realwp_p)-0.5_ip_realwp_p)*DLON
    LAT2(IX,IY)=REAL(NORTH,ip_realwp_p)-(REAL(IY,ip_realwp_p)-0.5_ip_realwp_p)*DLAT
    !* corners from south-west, anticlockwise
    CLON(IX,IY,:)=[LON2(IX,IY)-0.5_ip_realwp_p*DLON, LON2(IX,IY)+0.5_ip_realwp_p*DLON, &
                 & LON2(IX,IY)+0.5_ip_realwp_p*DLON, LON2(IX,IY)-0.5_ip_realwp_p*DLON]
    CLAT(IX,IY,:)=[LAT2(IX,IY)-0.5_ip_realwp_p*DLAT, LAT2(IX,IY)-0.5_ip_realwp_p*DLAT, &
                 & LAT2(IX,IY)+0.5_ip_realwp_p*DLAT, LAT2(IX,IY)+0.5_ip_realwp_p*DLAT]
    AREA(IX,IY)=(DLAT*PI180)*(DLON*PI180)*COS(LAT2(IX,IY)*PI180)   !! [sr]
    MASK(IX,IY)=0                                                  !! 0: unmasked
  ENDDO
ENDDO

!* only the master process writes, and only when OASIS flags the grid files as missing (IFLAG/=0)
IF( REGIONTHIS/=1 ) RETURN
CALL oasis_start_grids_writing(IFLAG)
IF( IFLAG/=0 )THEN
CALL oasis_write_grid  (TRIM(CGRIDNAME), NXIN, NYIN, LON2, LAT2)
CALL oasis_write_corner(TRIM(CGRIDNAME), NXIN, NYIN, 4, CLON, CLAT)
CALL oasis_write_area  (TRIM(CGRIDNAME), NXIN, NYIN, AREA)
CALL oasis_write_mask  (TRIM(CGRIDNAME), NXIN, NYIN, MASK)
ENDIF
CALL oasis_terminate_grids_writing()
WRITE(LOGNAM,*) "CMF::OASIS_INIT: grid files written for ", TRIM(CGRIDNAME)
END SUBROUTINE GRID_WRITE
!==========================================================

END SUBROUTINE CMF_OASIS_INIT
!####################################################################


!####################################################################
SUBROUTINE CMF_OASIS_FORCING_GET(KTIME, PBUFF)
! receive runoff from OASIS and fill the forcing buffer used by CMF_FORCING_PUT
!   PBUFF(:,:,1) : surface runoff (or surface + sub-surface runoff when LROSPLIT is false)
!   PBUFF(:,:,2) : sub-surface runoff (LROSPLIT only)
! Runoff unit is set with DROFUNIT in NFORCE, e.g. DROFUNIT=1000 for kg/m2/s.
USE mod_oasis,               ONLY: oasis_get, oasis_recvd, oasis_fromrest, oasis_input, &
                                 & oasis_recvout, oasis_fromrestout, oasis_ok
USE mod_oasis_kinds,         ONLY: ip_realwp_p
USE YOS_CMF_INPUT,           ONLY: NXIN, NYIN, LROSPLIT, RMIS
USE YOS_CMF_MAP,             ONLY: MPI_COMM_CAMA
USE CMF_UTILS_MOD,           ONLY: CMF_CheckNanB
IMPLICIT NONE
INTEGER(KIND=JPIM),INTENT(IN)   :: KTIME              !! time since start of run [s]
REAL(KIND=JPRB),INTENT(INOUT)   :: PBUFF(:,:,:)
REAL(KIND=ip_realwp_p)          :: RCV(INLOC)         !! received block of this process
INTEGER(KIND=JPIM)              :: IERR
!================================================
WRITE(LOGNAM,*) "CMF::OASIS_FORCING_GET: receive at time [s]:", KTIME

CALL oasis_get(ISURFID, KTIME, RCV, IERR)
CALL CHECK_RCV(IERR, CSURFNAME)
CALL GATHER(RCV, R2SURF)

IF( LSUBRCV )THEN
  CALL oasis_get(ISUBID, KTIME, RCV, IERR)
  CALL CHECK_RCV(IERR, CSUBNAME)
  CALL GATHER(RCV, R2SUB)
ELSE
  R2SUB(:,:)=0._JPRB
ENDIF

IF( LROSPLIT )THEN
  PBUFF(:,:,1)=R2SURF(:,:)
  PBUFF(:,:,2)=R2SUB(:,:)
ELSE   !! total runoff = surface + sub-surface
  PBUFF(:,:,1)=R2SURF(:,:)
  WHERE( R2SUB(:,:)/=RMIS .AND. R2SURF(:,:)/=RMIS ) PBUFF(:,:,1)=R2SURF(:,:)+R2SUB(:,:)
  PBUFF(:,:,2)=0._JPRB
ENDIF

CONTAINS
!==========================================================
SUBROUTINE GATHER(PIN, POUT)
! clean the local block, then assemble the full input grid on every process
! undefined (NaN / fill) -> RMIS, negative runoff -> 0, as in CMF_FORCING_GET
REAL(KIND=ip_realwp_p),INTENT(IN) :: PIN(:)
REAL(KIND=JPRB),INTENT(OUT)       :: POUT(:,:)
REAL(KIND=JPRB)                   :: ZLOC(INLOC), ZGLB(NXIN*NYIN)
INTEGER(KIND=JPIM)                :: II, IERRM
DO II=1,INLOC
  ZLOC(II)=REAL(PIN(II),JPRB)
  IF( CMF_CheckNanB(ZLOC(II),0._JPRB) .OR. ABS(PIN(II))>=1.E19_ip_realwp_p )THEN
    ZLOC(II)=RMIS
  ELSE
    ZLOC(II)=MAX(ZLOC(II),0._JPRB)
  ENDIF
ENDDO
#ifdef SinglePrec_CMF
CALL MPI_Allgatherv(ZLOC, INLOC, MPI_REAL4, ZGLB, ICOUNTS, IDISPLS, MPI_REAL4, MPI_COMM_CAMA, IERRM)
#else
CALL MPI_Allgatherv(ZLOC, INLOC, MPI_REAL8, ZGLB, ICOUNTS, IDISPLS, MPI_REAL8, MPI_COMM_CAMA, IERRM)
#endif
POUT(:,:)=RESHAPE(ZGLB,[NXIN,NYIN])
END SUBROUTINE GATHER
!==========================================================
SUBROUTINE CHECK_RCV(KINFO, CNAME)
INTEGER(KIND=JPIM),INTENT(IN)   :: KINFO
CHARACTER(LEN=*),INTENT(IN)     :: CNAME
IF( KINFO/=oasis_recvd .AND. KINFO/=oasis_fromrest .AND. KINFO/=oasis_input .AND. &
  & KINFO/=oasis_recvout .AND. KINFO/=oasis_fromrestout .AND. KINFO/=oasis_ok )THEN
  WRITE(LOGNAM,*) "CMF::OASIS_FORCING_GET: oasis_get error for ", TRIM(CNAME), ", IERR=", KINFO
  WRITE(6,*)      "CMF::OASIS_FORCING_GET: oasis_get error for ", TRIM(CNAME), ", IERR=", KINFO
  CALL oasis_abort_all
ENDIF
END SUBROUTINE CHECK_RCV
!==========================================================
END SUBROUTINE CMF_OASIS_FORCING_GET
!####################################################################


!####################################################################
SUBROUTINE CMF_OASIS_END
! terminate OASIS (calls MPI_Finalize)
USE mod_oasis,               ONLY: oasis_terminate
IMPLICIT NONE
INTEGER(KIND=JPIM)              :: IERR
!================================================
IF( ALLOCATED(R2SURF) ) DEALLOCATE(R2SURF)
IF( ALLOCATED(R2SUB)  ) DEALLOCATE(R2SUB)
IF( ALLOCATED(ICOUNTS) ) DEALLOCATE(ICOUNTS, IDISPLS)
CALL oasis_terminate(IERR)
IF( IERR/=0 ) WRITE(6,*) "CMF::OASIS_END: oasis_terminate error, IERR=", IERR
END SUBROUTINE CMF_OASIS_END
!####################################################################


!####################################################################
SUBROUTINE CHECK_ERR(KERR, CWHAT)
INTEGER(KIND=JPIM),INTENT(IN)   :: KERR
CHARACTER(LEN=*),INTENT(IN)     :: CWHAT
IF( KERR/=0 )THEN
  WRITE(LOGNAM,*) "CMF::OASIS: error in ", CWHAT, ", IERR=", KERR
  WRITE(6,*)      "CMF::OASIS: error in ", CWHAT, ", IERR=", KERR
  CALL oasis_abort_all
ENDIF
END SUBROUTINE CHECK_ERR
!####################################################################

SUBROUTINE oasis_abort_all
USE mod_oasis,               ONLY: oasis_abort
IMPLICIT NONE
CALL oasis_abort(ICOMPID, 'CMF_CTRL_OASIS_MOD', 'CaMa-Flood OASIS coupling failed')
END SUBROUTINE oasis_abort_all

END MODULE CMF_CTRL_OASIS_MOD
