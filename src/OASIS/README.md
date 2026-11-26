# CaMa-Flood OASIS3-MCT coupler (JULES and toy land model)

One coupler, `cmf_ctrl_oasis_mod.F90`, receives surface / sub-surface runoff from
any model through OASIS3-MCT. It has no JULES dependency (unlike
`../oasis_mct/oasis_rivers_control_mod.F90`). Model-specific settings are in the
`NOASIS` namelist (in the CaMa-Flood namelist file, `input_cmf.nam`) and in the `namcouple`.

```
&NOASIS
  CCOMPNAME = 'cmamod'         ! component name in namcouple $NBMODEL ('river' for the JULES rivers setup)
  CGRIDNAME = 'camgrd'         ! grid name of the CaMa-Flood input grid in namcouple
  CSURFNAME = 'surf_roff'      ! received surface runoff field (target name in namcouple)
  CSUBNAME  = 'sub_surf_roff'  ! received sub-surface runoff field ('' = none)
  LWRTGRID  = .FALSE.          ! .TRUE. to write grids/areas/masks (needed when OASIS remaps, e.g. JULES grid -> CaMa grid)
/
```

* Toy land model: same grid as CaMa-Flood (`NXIN,NYIN`), no remapping, `LWRTGRID=.FALSE.`.
* JULES: set `LWRTGRID=.TRUE.` and use a remapping (e.g. `SCRIPR CONSERV`) in the `namcouple`.

Rules
* Runoff coupling period in the `namcouple` must equal `DTIN` (`IFRQ_INP`).
* `LROSPLIT=.TRUE.`: surface and sub-surface runoff are used separately; `.FALSE.`: they are summed.
* Set `DROFUNIT` in `NFORCE` for the received unit (`1000` for kg m-2 s-1).
* Any number of CaMa-Flood processes (set the same number for the component in the launch command). The `NXIN x NYIN` input grid is split into contiguous point blocks (OASIS Apple partition); each process receives its block and `MPI_Allgatherv` assembles the full field on every process, as when each process reads the runoff file. Grid files are written by process 1 only. OASIS initialises/finalises MPI (`CMF_MPI_INIT/END` are not used).
* Use `NXIN,NYIN` from the CaMa-Flood `diminfo`; with `LINTERP=.FALSE.` they must equal `NX,NY`.

Build (Gadi, Intel + OpenMPI + netCDF): `module load intel-compiler/2021.10.0 netcdf/4.8.0 openmpi/4.1.5`, then
`./compile.sh` (or `make PRISM_PATH=<oasis3-mct>`); default settings: `Mkinclude_linux_ifort_gadi`, MPI on; output `src/MAIN_cmf_oasis`.
`./compile.sh clean` cleans only, `./compile.sh no` rebuilds without cleaning.
Other platform: `make MKINCLUDE=../../adm/Mkinclude_<platform>` (MPI must be enabled there).

Runoff comes from OASIS, so the netCDF runoff file is not used: `cmf_ctrl_forcing_mod.F90` in this folder is a copy of the shared
module in which `CMF_FORCING_INIT_CDF` does not open `CROFCDF` (no time check). Keep `LINPCDF=.TRUE.` in `input_cmf.nam`.
Only the executable is written to `src/` (override with `BINDIR=<dir>`); objects and `.mod` files stay in this folder, so they do not clash with the regular or toymodel builds in `src/`.
