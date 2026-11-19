# CaMa-Flood + OASIS3-MCT toy land model

Self-contained coupling of CaMa-Flood (component `cmamod`) to the toy land model (`toymod`).
The CaMa-Flood sources in `src/` are used unchanged (`vpath` in the Makefile).

Files
* `MAIN_cmf_toymodel.F90`: driver; receives runoff through OASIS instead of reading forcing files.
* `oasis_toy_model_receive_mod.F90`: receive-only OASIS3-MCT interface (`cmamod`, grid `cama`, fields `surf_roff`, `sub_surf_roff`). Rank 0 of the component owns the `NXIN x NYIN` grid and broadcasts it to the other ranks.
* `Mkinclude_linux_ifort_gadi`: Gadi Intel/OpenMPI/netCDF/OASIS settings (MPI and netCDF enabled).
* `Makefile`: builds `MAIN_cmf_toymodel`.

Build (Gadi): `module load intel-compiler/2021.10.0 netcdf/4.8.0 openmpi/4.1.5; make [PRISM_PATH=<oasis3-mct>]`

Notes
* `LROSPLIT=.TRUE.`: surface and sub-surface runoff are used separately; `.FALSE.`: they are summed in the driver.
* The namcouple coupling period must equal `DTIN`.
* `CMF_FORCING_INIT` is unchanged: with `LINPCDF=.TRUE.` keep a valid `CROFCDF` (it is opened but not read), or use plain-binary settings with an existing runoff file.
* OASIS finalises MPI (`CMF_MPI_END` is not called). `oasis_toy_grid` is only needed if OASIS must regrid.
