MODULE YOS_CMF_OASIS
!==========================================================
!* PURPOSE: Shared variables for the OASIS3-MCT coupler of CaMa-Flood
!
! One coupler serves every land-surface model (JULES, toy land model, ...):
! the model specific part (component/grid/field names) is set in the
! NOASIS namelist, and the exchange itself is described by the "namcouple".
!
! Licensed under the Apache License, Version 2.0 (the "License");
!   You may not use this file except in compliance with the License.
!   You may obtain a copy of the License at: http://www.apache.org/licenses/LICENSE-2.0
!
! Unless required by applicable law or agreed to in writing, software distributed under the License is
!  distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
! See the License for the specific language governing permissions and limitations under the License.
!==========================================================
USE PARKIND1, ONLY: JPIM, JPRB
IMPLICIT NONE
SAVE
!================================================
!*** NAMELIST/NOASIS/
CHARACTER(LEN=32)           :: CCOMPNAME   !! OASIS component name of CaMa-Flood (as in namcouple $NBMODEL)
CHARACTER(LEN=32)           :: CGRIDNAME   !! OASIS grid name of CaMa-Flood input grid (as in namcouple $STRINGS)
CHARACTER(LEN=32)           :: CSURFNAME   !! name of received surface runoff field    (target name in namcouple)
CHARACTER(LEN=32)           :: CSUBNAME    !! name of received sub-surface runoff field (blank: not received)
LOGICAL                     :: LWRTGRID    !! true: write OASIS grids/areas/masks files (needed for OASIS remapping)

!================================================
!*** coupler state
INTEGER(KIND=JPIM)          :: ICOMPID     !! OASIS component id
INTEGER(KIND=JPIM)          :: IPARTID     !! OASIS partition id
INTEGER(KIND=JPIM)          :: ISURFID     !! OASIS variable id (surface runoff)
INTEGER(KIND=JPIM)          :: ISUBID      !! OASIS variable id (sub-surface runoff)
LOGICAL                     :: LSUBRCV     !! true: sub-surface runoff is received

!* decomposition of the flattened NXIN*NYIN input grid over the CaMa-Flood processes (OASIS "Apple" partition)
INTEGER(KIND=JPIM)          :: INLOC       !! number of input grid points of this process
INTEGER(KIND=JPIM)          :: IOFFSET     !! offset of this process in the flattened global grid
INTEGER(KIND=JPIM),ALLOCATABLE :: ICOUNTS(:)  !! INLOC of every process (for MPI_Allgatherv)
INTEGER(KIND=JPIM),ALLOCATABLE :: IDISPLS(:)  !! IOFFSET of every process

!* last received fields on the CaMa-Flood input grid (NXIN,NYIN) on every process, kept between coupling steps
REAL(KIND=JPRB),ALLOCATABLE :: R2SURF(:,:)
REAL(KIND=JPRB),ALLOCATABLE :: R2SUB(:,:)

!================================================
END MODULE YOS_CMF_OASIS
