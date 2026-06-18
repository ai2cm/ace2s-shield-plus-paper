# Variables one might modify
SCRATCH_ROOT=/gpfs/f5/gfdl_w/scratch/Spencer.Clark/scratch/2025-07-23-reference-SHiELD-runs
SPIN_UP_REPEATING_SST_RUN=/gpfs/f5/gfdl_w/scratch/Spencer.Clark/scratch/2024-06-19-reference-SHiELD-runs/repeating-sst-bridge-C96
INITIAL_CONDITIONS_ROOT=$(SCRATCH_ROOT)/initial-conditions
GRID_DATA_ROOT=/gpfs/f5/gfdl_w/scratch/Spencer.Clark/reference/2024-06-19-vcm-fv3config/data/grid_data/v1.2
ENVIRONMENT_NAME=2025-07-16-SHiELD-simulations
CONFIG_DIR=$(shell pwd)/config

# Static variables
SOFTWARE_DIR=$(shell pwd)/software
SCRIPTS_DIR=$(shell pwd)/scripts
ENVIRONMENT_FILE=$(SOFTWARE_DIR)/environment.yaml
PIP_REQUIREMENTS=$(SOFTWARE_DIR)/requirements.txt
CONDA_RUN=$(SOFTWARE_DIR)/conda_run.sh
EXECUTABLE=$(SOFTWARE_DIR)/submodules/SHiELD_build/Build/bin/SHiELD_nh.repro.64bit.intel.x

# A Python package for running SHiELD simulations via fv3config and SLURM
SHIELD_RUN_DIR=$(SOFTWARE_DIR)/shield_run
SHIELD_RUN_TESTS=$(SHIELD_RUN_DIR)/shield_run/tests

CO2_CONCENTRATIONS=1xCO2 2xCO2 4xCO2

# Key-value pairs to infer initial condition date from initial condition name
# https://stackoverflow.com/questions/62005888/key-value-pair-in-makefile
IC_DATE_1xCO2_C96_RANDOM := 2034092400
IC_DATE_2xCO2_C96_RANDOM := 2034092500
IC_DATE_4xCO2_C96_RANDOM := 2034092600

IC_DATE_1xCO2_C96_ic_0002_RANDOM := 2034091800
IC_DATE_2xCO2_C96_ic_0002_RANDOM := 2034091900
IC_DATE_4xCO2_C96_ic_0002_RANDOM := 2034092000

IC_DATE_1xCO2_C96_ic_0003_RANDOM := 2034092100
IC_DATE_2xCO2_C96_ic_0003_RANDOM := 2034092200
IC_DATE_4xCO2_C96_ic_0003_RANDOM := 2034092300

update_submodules:
	git submodule update --init --recursive

build_shield:
	bash $(SOFTWARE_DIR)/build_SHiELD.sh

create_environment:
	bash $(SOFTWARE_DIR)/create_environment.sh \
		$(ENVIRONMENT_FILE) \
		$(ENVIRONMENT_NAME) \
		$(PIP_REQUIREMENTS) \
		$(SHIELD_RUN_DIR)

lock_pip:
	$(CONDA_RUN) $(ENVIRONMENT_NAME) pip-compile \
		$(ENVIRONMENT_DIR)/requirements.in > $(PIP_REQUIREMENTS)

reformat:
	$(CONDA_RUN) $(ENVIRONMENT_NAME) black $(SHIELD_RUN_DIR)

test_shield_run:
	$(CONDA_RUN) $(ENVIRONMENT_NAME) pytest -vv $(SHIELD_RUN_TESTS)

# See
# https://github.com/ai2cm/ace2-som-paper/blob/main/SHiELD-simulations/SHiELD
# for the configuration information for the simulation that produced these
# initial conditions.
prepare_initial_conditions_C96:
	$(SCRIPTS_DIR)/prepare_restart_files.sh \
		$(SPIN_UP_REPEATING_SST_RUN)/restart/2034100100 \
		$(INITIAL_CONDITIONS_ROOT)/repeating-sst-bridge-C96 \
		2034091800 \
		2034091900 \
		2034092000 \
		2034092100 \
		2034092200 \
		2034092300 \
		2034092400 \
		2034092500 \
		2034092600

submit_climatological_ramped_sst_random_co2_C96: $(addprefix submit_climatological_ramped_sst_random_co2_C96_, $(CO2_CONCENTRATIONS))
submit_climatological_ramped_sst_random_co2_C96_%:
	$(CONDA_RUN) $(ENVIRONMENT_NAME) python -m shield_run.submit \
		$(EXECUTABLE) \
		$(CONFIG_DIR)/climatological-ramped-sst-$*-C96-random-co2.yaml \
		63 \
		00:42:00 \
		$(SCRATCH_ROOT)/climatological-ramped-sst-$*-C96-random-co2 \
		--initial-conditions=$(INITIAL_CONDITIONS_ROOT)/repeating-sst-bridge-C96/$(IC_DATE_$*_C96_RANDOM) \
		--grid-data-root=$(GRID_DATA_ROOT)

submit_climatological_ramped_sst_random_co2_ic_0002_C96: $(addprefix submit_climatological_ramped_sst_random_co2_ic_0002_C96_, $(CO2_CONCENTRATIONS))
submit_climatological_ramped_sst_random_co2_ic_0002_C96_%:
	$(CONDA_RUN) $(ENVIRONMENT_NAME) python -m shield_run.submit \
		$(EXECUTABLE) \
		$(CONFIG_DIR)/climatological-ramped-sst-$*-C96-random-co2-ic2.yaml \
		63 \
		00:42:00 \
		$(SCRATCH_ROOT)/climatological-ramped-sst-$*-C96-random-co2-ic_0002 \
		--initial-conditions=$(INITIAL_CONDITIONS_ROOT)/repeating-sst-bridge-C96/$(IC_DATE_$*_C96_ic_0002_RANDOM) \
		--grid-data-root=$(GRID_DATA_ROOT)

submit_climatological_ramped_sst_random_co2_ic_0003_C96: $(addprefix submit_climatological_ramped_sst_random_co2_ic_0003_C96_, $(CO2_CONCENTRATIONS))
submit_climatological_ramped_sst_random_co2_ic_0003_C96_%:
	$(CONDA_RUN) $(ENVIRONMENT_NAME) python -m shield_run.submit \
		$(EXECUTABLE) \
		$(CONFIG_DIR)/climatological-ramped-sst-$*-C96-random-co2-ic3.yaml \
		63 \
		00:42:00 \
		$(SCRATCH_ROOT)/climatological-ramped-sst-$*-C96-random-co2-ic_0003 \
		--initial-conditions=$(INITIAL_CONDITIONS_ROOT)/repeating-sst-bridge-C96/$(IC_DATE_$*_C96_ic_0003_RANDOM) \
		--grid-data-root=$(GRID_DATA_ROOT)

# Rules below are for integration testing
submit_simulation_6_hour:
	$(CONDA_RUN) $(ENVIRONMENT_NAME) python -m shield_run.submit \
		$(EXECUTABLE) \
		$(CONFIG_DIR)/repeating-sst-6-hour.yaml \
		2 \
		00:15:00 \
		$(SCRATCH_ROOT)/repeating-sst-6-hour

submit_simulation_12_hour:
	$(CONDA_RUN) $(ENVIRONMENT_NAME) python -m shield_run.submit \
		$(EXECUTABLE) \
		$(CONFIG_DIR)/repeating-sst-12-hour.yaml \
		1 \
		00:15:00 \
		$(SCRATCH_ROOT)/repeating-sst-12-hour
