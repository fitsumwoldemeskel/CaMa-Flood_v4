# CaMa-Flood + OASIS3-MCT toy land model

Self-contained coupling of CaMa-Flood (component `cmamod`) to the toy land model (`toymod`).
Location: `src/OASIS/toymodel/`. The CaMa-Flood sources in `src/` are used unchanged (`vpath ../..` in the Makefile).

Files
* `MAIN_cmf_toymodel.F90`: driver; receives runoff through OASIS instead of reading forcing files.
* `oasis_toy_model_receive_mod.F90`: receive-only OASIS3-MCT interface (`cmamod`, grid `cama`, fields `surf_roff`, `sub_surf_roff`). Rank 0 of the component owns the `NXIN x NYIN` grid and broadcasts it to the other ranks.
* `Mkinclude_linux_ifort_gadi`: Gadi Intel/OpenMPI/netCDF/OASIS settings (MPI and netCDF enabled).
* `cmf_ctrl_forcing_mod.F90`: local copy of the shared CaMa-Flood module. It overrides the one in `src/` (make searches this folder first). Its only change: the netCDF forcing file (`CROFCDF`) is no longer opened or time-checked, since runoff comes from OASIS. The shared `src/cmf_ctrl_forcing_mod.F90` is untouched. If the shared module changes, this copy must be updated by hand.
* `Makefile`: builds `MAIN_cmf_toymodel`, and its objects and `.mod` files, into the parent `src/` directory (override with `BINDIR=<dir>`). `make clean` removes only the toymodel's own files; the regular CaMa-Flood build in `src/` is untouched.
* `compile.sh`: wrapper around `make` (`./compile.sh [clean|no]`).

Build (Gadi): `module load intel-compiler/2021.10.0 netcdf/4.8.0 openmpi/4.1.5; make [PRISM_PATH=<oasis3-mct>]`

Notes
* `LROSPLIT=.TRUE.`: surface and sub-surface runoff are used separately; `.FALSE.`: they are summed in the driver.
* The namcouple coupling period must equal `DTIN`.
* `CROFCDF` is ignored in this build, so no runoff file or time-range check is needed. The run's dates must still match the `RUNTIME` in `namcouple`.
* OASIS finalises MPI (`CMF_MPI_END` is not called). `oasis_toy_grid` is only needed if OASIS must regrid.

