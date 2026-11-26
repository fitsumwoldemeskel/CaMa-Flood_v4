#==========================================================
#* Makefile for CaMa-Flood coupled to the OASIS3-MCT toy land model
#
# Usage (Gadi, Intel):
#   module load intel-compiler/2021.10.0 netcdf/4.8.0 openmpi/4.1.5
#   make                                   # builds MAIN_cmf_toymodel
#   make PRISM_PATH=/path/to/oasis3-mct    # other OASIS3-MCT install
#
# Compiler / netCDF / MPI settings come from Mkinclude_linux_ifort_gadi;
# MPI (-DUseMPI_CMF) must be enabled there and FCMP must be an MPI wrapper.
#==========================================================
include Mkinclude_linux_ifort_gadi

vpath %.F90 ../..
# Local cmf_ctrl_forcing_mod.F90 overrides the shared one (make searches this directory first)

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
oasis_toy_model_receive_mod.o \
\
cmf_drv_control_mod.o   \
cmf_drv_advance_mod.o

#=============================
#*** output location: objects and .mod files stay in this folder (they would clash with the
# regular / OASIS builds in src/); only the executable goes to src/ (override with BINDIR=...)
BINDIR ?= ../..

#=============================
#*** suffix rule (-module: write .mod files here, -I: find them here)
MODS = -module . -I.
.SUFFIXES:
.SUFFIXES : .o .F90
.F90.o:
	$(FCMP) $(FFLAGS) -c $(INC) $(OASIS_INC) $(MODS) $(CFLAGS) $< -o $@

#=============================
#*** for main program
TARGET = MAIN_cmf_toymodel

all: $(BINDIR)/$(TARGET)

# OBJECTS first so modules are compiled in list order (parkind1.mod before its users)
$(BINDIR)/$(TARGET): $(OBJECTS) $(TARGET).o
	$(FCMP) $(LFLAGS) $^ -o $@ $(LIB) $(OASIS_LIB)

# module dependencies not tracked by suffix rule
oasis_toy_model_receive_mod.o: yos_cmf_map.o
$(TARGET).o: $(OBJECTS)

#=============================
#*** general rule
clean:
	${RM} -rf *.o core *~ *trace temp* *.mod *.a *.s *.dSYM $(BINDIR)/$(TARGET)
