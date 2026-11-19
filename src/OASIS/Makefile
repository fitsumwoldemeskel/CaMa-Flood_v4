#==========================================================
#* Makefile for CaMa-Flood coupled through OASIS3-MCT (JULES / toy land model)
#
# Usage (Gadi, Intel):
#   module load intel-compiler/2021.10.0 netcdf/4.8.0 openmpi/4.1.5
#   make                                   # builds MAIN_cmf_oasis
#   make PRISM_PATH=/path/to/oasis3-mct    # other OASIS3-MCT install
#
# Compiler / netCDF / MPI settings come from ../../adm/Mkinclude;
# MPI (-DUseMPI_CMF) must be enabled there and FCMP must be an MPI wrapper.
#==========================================================
include ../../adm/Mkinclude

VPATH = ../

# OASIS3-MCT root (provides mod_oasis.mod and libpsmile.MPI1/mct/mpeu/scrip)
PRISM_PATH ?= /g/data/access/projects/access/data/ACCESS_CMIP5/pre-build/oasis3-mct_local/Linux

OASIS_INC = -I$(PRISM_PATH)/build/lib/psmile.MPI1
OASIS_LIB = -L$(PRISM_PATH)/lib -lpsmile.MPI1 -lmct -lmpeu -lscrip

#=============================
#*** module
OBJECTS=\
parkind1.o              \
yos_cmf_input.o         \
yos_cmf_time.o          \
yos_cmf_map.o           \
yos_cmf_prog.o          \
yos_cmf_diag.o          \
cmf_utils_mod.o         \
yos_cmf_oasis.o         \
\
cmf_calc_outflw_mod.o   \
cmf_calc_pthout_mod.o   \
cmf_calc_fldstg_mod.o   \
cmf_calc_stonxt_mod.o   \
cmf_calc_diag_mod.o     \
cmf_opt_outflw_mod.o    \
\
cmf_ctrl_mpi_mod.o      \
cmf_ctrl_damout_mod.o   \
cmf_ctrl_tracer_mod.o   \
cmf_ctrl_levee_mod.o    \
cmf_ctrl_forcing_mod.o  \
cmf_ctrl_boundary_mod.o \
cmf_ctrl_upsinf_mod.o   \
cmf_ctrl_output_mod.o   \
cmf_ctrl_restart_mod.o  \
cmf_ctrl_physics_mod.o  \
cmf_ctrl_time_mod.o     \
cmf_ctrl_maps_mod.o     \
cmf_ctrl_vars_mod.o     \
cmf_ctrl_nmlist_mod.o   \
\
cmf_ctrl_oasis_mod.o    \
\
cmf_drv_control_mod.o   \
cmf_drv_advance_mod.o

#=============================
#*** suffix rule
.SUFFIXES : .o .F90
.F90.o:
	$(FCMP) $(FFLAGS) -c $(INC) $(OASIS_INC) $(MODS) $(CFLAGS) $< -o $@

#=============================
#*** for main program
TARGET = MAIN_cmf_oasis

all: $(TARGET)

$(TARGET): $(TARGET).o $(OBJECTS)
	$(FCMP) $(LFLAGS) $^ -o $@ $(LIB) $(OASIS_LIB)

# module dependencies not tracked by suffix rule
cmf_ctrl_oasis_mod.o: yos_cmf_oasis.o yos_cmf_input.o yos_cmf_map.o cmf_utils_mod.o
$(TARGET).o: cmf_ctrl_oasis_mod.o cmf_ctrl_forcing_mod.o cmf_drv_control_mod.o cmf_drv_advance_mod.o

#=============================
#*** general rule
clean:
	${RM} -rf *.o core *~ *trace temp* *.mod *.a *.s *.dSYM $(TARGET)
