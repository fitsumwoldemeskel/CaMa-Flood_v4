PROGRAM MAIN_cmf_oasis
!==========================================================
!* PURPOSE: CaMa-Flood driven by runoff received through OASIS3-MCT
!  (JULES, toy land model, or any model sending surface / sub-surface runoff)
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
USE YOS_CMF_INPUT,           ONLY: NXIN, NYIN, DT, DTIN, LOGNAM
USE YOS_CMF_TIME,            ONLY: NSTEPS
USE CMF_DRV_CONTROL_MOD,     ONLY: CMF_DRV_INPUT, CMF_DRV_INIT, CMF_DRV_END
USE CMF_DRV_ADVANCE_MOD,     ONLY: CMF_DRV_ADVANCE
USE CMF_CTRL_FORCING_MOD,    ONLY: CMF_FORCING_PUT
USE CMF_CTRL_OASIS_MOD,      ONLY: CMF_OASIS_INPUT, CMF_OASIS_INIT, CMF_OASIS_FORCING_GET, CMF_OASIS_END
!$ USE OMP_LIB
IMPLICIT NONE
INTEGER(KIND=JPIM)              :: ISTEP              ! total time step
INTEGER(KIND=JPIM)              :: ISTEPADV           ! time steps per runoff coupling interval
REAL(KIND=JPRB),ALLOCATABLE     :: ZBUFF(:,:,:)       ! Buffer to store forcing runoff
!================================================

!*** 0. OASIS & MPI initialization (replaces CMF_MPI_INIT)
CALL CMF_OASIS_INPUT

!*** 1a. Namelist handling
CALL CMF_DRV_INPUT

!*** 1b. INITIALIZATION
CALL CMF_DRV_INIT
CALL CMF_OASIS_INIT

!*** 1c. allocate data buffer for input forcing
ALLOCATE(ZBUFF(NXIN,NYIN,2))

!================================================
!*** 2. MAIN TEMPORAL LOOP / TIME-STEP (NSTEPS calculated by DRV_INIT)
!   The runoff coupling period in the namcouple must equal DTIN (IFRQ_INP).
ISTEPADV=INT(DTIN/DT,JPIM)
DO ISTEP=1,NSTEPS
  WRITE(LOGNAM,'(a,i6)') '[MAIN_cmf_oasis] Time step: ', ISTEP
  IF( MOD(ISTEP-1,ISTEPADV)==0 )THEN
    !*  2a Receive runoff from the land surface model
    CALL CMF_OASIS_FORCING_GET(INT((ISTEP-1)*DT,JPIM), ZBUFF(:,:,:))
    !*  2b Interpolate runoff & send to CaMa-Flood
    CALL CMF_FORCING_PUT(ZBUFF(:,:,:))
  ENDIF

  !*  2c  Advance CaMa-Flood model
  CALL CMF_DRV_ADVANCE(1)
ENDDO
!================================================

!*** 3. Finalize
DEALLOCATE(ZBUFF)
CALL CMF_DRV_END
CALL CMF_OASIS_END   !! also finalises MPI

END PROGRAM MAIN_cmf_oasis
