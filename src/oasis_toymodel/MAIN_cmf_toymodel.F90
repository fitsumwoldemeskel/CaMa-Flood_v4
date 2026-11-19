PROGRAM MAIN_cmf_toymodel
!==========================================================
!* PURPOSE: CaMa-Flood driven by surface / sub-surface runoff received from
!  the OASIS3-MCT toy land model ('toymod'); CaMa-Flood is component 'cmamod'.
!  The original CaMa-Flood sources in src/ are used unchanged.
!
! Licensed under the Apache License, Version 2.0 (the "License");
!   You may not use this file except in compliance with the License.
!   You may obtain a copy of the License at: http://www.apache.org/licenses/LICENSE-2.0
!
! Unless required by applicable law or agreed to in writing, software distributed under the License is
!  distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
! See the License for the specific language governing permissions and limitations under the License.
!==========================================================
USE PARKIND1,                ONLY: JPRB, JPIM
USE YOS_CMF_INPUT,           ONLY: NXIN, NYIN, DT, DTIN, LROSPLIT, LTRACE, LOGNAM
USE YOS_CMF_TIME,            ONLY: NSTEPS, IYYYYMMDD, IHOUR
USE CMF_DRV_CONTROL_MOD,     ONLY: CMF_DRV_INPUT, CMF_DRV_INIT, CMF_DRV_END
USE CMF_DRV_ADVANCE_MOD,     ONLY: CMF_DRV_ADVANCE
USE CMF_CTRL_FORCING_MOD,    ONLY: CMF_FORCING_PUT
USE oasis_toy_model_receive_mod, ONLY: oasis_toy_init, oasis_toy_set_comm, oasis_toy_partition, &
&   oasis_toy_variables, oasis_toy_receive, oasis_toy_finalise
USE mod_oasis_kinds,         ONLY: ip_realwp_p
#ifdef UseMPI_CMF
USE CMF_CTRL_MPI_MOD,        ONLY: CMF_MPI_INIT
#endif
!$ USE OMP_LIB
IMPLICIT NONE
INTEGER(KIND=JPIM)              :: ISTEP              ! total time step
INTEGER(KIND=JPIM)              :: ISTEPADV           ! time steps per runoff coupling interval
REAL(KIND=JPRB),ALLOCATABLE     :: ZBUFF(:,:,:)       ! Buffer to store forcing runoff
REAL(KIND=ip_realwp_p),ALLOCATABLE :: SURF_ROFF(:,:)  ! surface runoff received through OASIS
REAL(KIND=ip_realwp_p),ALLOCATABLE :: SUB_ROFF(:,:)   ! sub-surface runoff received through OASIS
!================================================
!*** 0. MPI & OASIS initialization
#ifdef UseMPI_CMF
CALL CMF_MPI_INIT
#endif
CALL oasis_toy_init()
CALL oasis_toy_set_comm()   !! CaMa-Flood MPI region/communicator = OASIS component communicator

!*** 1a. Namelist handling
CALL CMF_DRV_INPUT

!*** 1b. OASIS partition (NXIN, NYIN are known after CMF_DRV_INPUT)
CALL oasis_toy_partition(NXIN, NYIN)

!*** 1c. INITIALIZATION
CALL CMF_DRV_INIT

!*** 1d. declare OASIS receive variables and end the OASIS definition phase
CALL oasis_toy_variables(NXIN, NYIN)

!*** 1e. allocate data buffers
ALLOCATE(ZBUFF(NXIN,NYIN,2))
ALLOCATE(SURF_ROFF(NXIN,NYIN))
ALLOCATE(SUB_ROFF(NXIN,NYIN))

!================================================
!*** 2. MAIN TEMPORAL LOOP / TIME-STEP (NSTEPS calculated by DRV_INIT)
!   The runoff coupling period in the namcouple must equal DTIN.
ISTEPADV=INT(DTIN/DT,JPIM)
DO ISTEP=1,NSTEPS
  WRITE(LOGNAM,'(a,i6)') '[MAIN_cmf_toymodel] Time step: ', ISTEP
  IF( MOD(ISTEP-1,ISTEPADV)==0 )THEN
    !*  2a Receive runoff from the toy land model (replaces reading forcing from file)
    CALL oasis_toy_receive((ISTEP-1)*NINT(DT), NXIN, NYIN, SURF_ROFF, SUB_ROFF)
    IF( LROSPLIT )THEN
      ZBUFF(:,:,1)=SURF_ROFF
      ZBUFF(:,:,2)=SUB_ROFF
    ELSE   !! aggregate surface and sub-surface runoff
      ZBUFF(:,:,1)=SURF_ROFF+SUB_ROFF
      ZBUFF(:,:,2)=0._JPRB
    ENDIF
    !*  2b Interpolate runoff & send to CaMa-Flood
    CALL CMF_FORCING_PUT(ZBUFF(:,:,:))
  ENDIF

  !*  2c  Advance CaMa-Flood model
  CALL CMF_DRV_ADVANCE(1)
ENDDO
!================================================

!*** 3. Finalize (OASIS terminates MPI, so CMF_MPI_END is not called)
DEALLOCATE(ZBUFF)
DEALLOCATE(SURF_ROFF)
DEALLOCATE(SUB_ROFF)
CALL CMF_DRV_END
CALL oasis_toy_finalise()

END PROGRAM MAIN_cmf_toymodel
