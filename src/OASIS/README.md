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

Build (Intel + OpenMPI, MPI enabled in `adm/Mkinclude`): `make PRISM_PATH=<oasis3-mct>`; output `MAIN_cmf_oasis`.
