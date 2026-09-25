#!/opt/homebrew/bin/bash

set -e

DATE=2026-09-09
WANDB_USERNAME=spencerc_ai2
CONFIG_FILENAME="ace-amip-inference-config-daily-PRATEsfc.yaml"
BEAKER_IMAGE=oliverwm/fme-deps-only-54045d546
ACE_COMMIT=56820c0eb856d2948e20fb696f96eb53d0a43098
SCRIPT_PATH=$(git rev-parse --show-prefix)  # relative to the root of the repository
CONFIG_PATH=$SCRIPT_PATH/$CONFIG_FILENAME
SET_SEED=$SCRIPT_PATH/set_seed.py

ENSEMBLE_ID="ic_0002"
AMIP_DATA_ROOT="/climate-default/2026-01-28-vertically-resolved-c96-1deg-shield-amip-ensemble-dataset"

declare -A MODELS=( \
    # [published-baseline-rs3]="01J4BR6J5AW32ZDQ77VZ60P4KT" \
    # ["ACE2-SHiELD"]="brianhenn/shield-amip-1deg-ace2-train-RS2-best-inference-ckpt" \
    # [no-random-co2-energy-conserving-rs0]="01KHGDA8TVGP9JKWVJ1N0SMHCN" \
    [no-random-co2-energy-conserving-rs1]="01KH4SDT1Q5246GZ307W8AW4M3" \
    [full-energy-conserving-rs1]="01KHCXABVNA3TJW0ZT5F4YDDQT" \
    # [full-energy-conserving-rs0]="01KHJ5F1M6YKVZESPZAAVVD6G8" \
    # [baseline-like-full-rs0]="01M17655EQD9BVRB9MY4T7S6EY" \
    [baseline-like-full-rs1]="01M235Y7DSCW4TPKTX7S305QYD" \
)

REPO_ROOT=$(git rev-parse --show-toplevel)
cd $REPO_ROOT  # so config path is valid no matter where we are running this script

CONFIG_B64=$(base64 < "$CONFIG_PATH" | tr -d '\n')

GCS_ROOT="gs://vcm-ml-experiments/spencerc/${DATE}-amip-inference"

SPIN_UP_EXPERIMENT_DIR="/results/spin-up"
TRAIN_AND_VALIDATE_EXPERIMENT_DIR="/results/train-and-validate"

# xr.date_range("1979-01-01T06:00:00", "1980", freq="6h", inclusive="left")
SPIN_UP_MAXIMUM_N_FORWARD_STEPS=1459

# xr.date_range("1980", "2012", freq="6h", inclusive="left")
TRAIN_AND_VALIDATE_N_FORWARD_STEPS=46752

# xr.date_range("2012", "2021", freq="6h", inclusive="left")
TEST_N_FORWARD_STEPS=13152

for model in "${!MODELS[@]}"; do
    dataset_id="${MODELS[$model]}"
    test_experiment_dir="${GCS_ROOT}/${model}/test"

    spin_up_initial_condition_time="1979-01-01T06:00:00"
    spin_up_n_forward_steps=${SPIN_UP_MAXIMUM_N_FORWARD_STEPS}
    spin_up_log_to_wandb=false  # Disable logging to wandb in spin up case.

    if [ $model == "ACE2-SHiELD" ]; then
        interpolate=false
    else
        interpolate=true
    fi

    job_name=$DATE-$model-split-amip-daily-PRATEsfc
    seed=$(python $SET_SEED $job_name)
    spin_up_overrides="\
        experiment_dir=$SPIN_UP_EXPERIMENT_DIR \
        forcing_loader.dataset.data_path=$AMIP_DATA_ROOT \
        forcing_loader.dataset.engine=zarr \
        forcing_loader.dataset.file_pattern=${ENSEMBLE_ID}.zarr \
        initial_condition.path=$AMIP_DATA_ROOT/${ENSEMBLE_ID}.zarr \
        initial_condition.engine=zarr \
        initial_condition.start_indices.times=[$spin_up_initial_condition_time] \
        n_forward_steps=$spin_up_n_forward_steps \
        logging.log_to_wandb=$spin_up_log_to_wandb \
        data_writer.files=[] \
        stepper_override.ocean.surface_temperature_name=surface_temperature \
        stepper_override.ocean.ocean_fraction_name=ocean_fraction \
        stepper_override.ocean.interpolate=$interpolate \
        stepper_override.ocean.slab=null \
        seed=$seed \
    "
    train_and_validate_overrides="\
        experiment_dir=$TRAIN_AND_VALIDATE_EXPERIMENT_DIR \
        forcing_loader.dataset.data_path=$AMIP_DATA_ROOT \
        forcing_loader.dataset.engine=zarr \
        forcing_loader.dataset.file_pattern=${ENSEMBLE_ID}.zarr \
        initial_condition.path=$SPIN_UP_EXPERIMENT_DIR/restart.nc \
        initial_condition.engine=netcdf4 \
        initial_condition.start_indices=null \
        n_forward_steps=$TRAIN_AND_VALIDATE_N_FORWARD_STEPS \
        data_writer.files=[] \
        stepper_override.ocean.surface_temperature_name=surface_temperature \
        stepper_override.ocean.ocean_fraction_name=ocean_fraction \
        stepper_override.ocean.interpolate=$interpolate \
        stepper_override.ocean.slab=null \
        seed=$seed \
    "
    test_overrides="\
        experiment_dir=$test_experiment_dir \
        forcing_loader.dataset.data_path=$AMIP_DATA_ROOT \
        forcing_loader.dataset.engine=zarr \
        forcing_loader.dataset.file_pattern=${ENSEMBLE_ID}.zarr \
        initial_condition.path=$TRAIN_AND_VALIDATE_EXPERIMENT_DIR/restart.nc \
        initial_condition.engine=netcdf4 \
        initial_condition.start_indices=null \
        n_forward_steps=$TEST_N_FORWARD_STEPS \
        stepper_override.ocean.surface_temperature_name=surface_temperature \
        stepper_override.ocean.ocean_fraction_name=ocean_fraction \
        stepper_override.ocean.interpolate=$interpolate \
        stepper_override.ocean.slab=null \
        seed=$seed \
    "

    python -m fme.ace.validate_config --config_type inference $CONFIG_PATH --override $spin_up_overrides
    python -m fme.ace.validate_config --config_type inference $CONFIG_PATH --override $train_and_validate_overrides
    python -m fme.ace.validate_config --config_type inference $CONFIG_PATH --override $test_overrides

    gantry run \
        --remote https://github.com/ai2cm/ace \
        --ref $ACE_COMMIT \
        --name $job_name \
        --description 'Run inference with ACE' \
        --beaker-image "${BEAKER_IMAGE}" \
        --workspace ai2/ace \
        --priority urgent \
        --cluster ai2/jupiter \
        --env WANDB_USERNAME=$WANDB_USERNAME \
        --env WANDB_NAME=$job_name \
        --env WANDB_JOB_TYPE=inference \
        --env WANDB_RUN_GROUP= \
        --env GOOGLE_APPLICATION_CREDENTIALS=/tmp/google_application_credentials.json \
        --env-secret WANDB_API_KEY=wandb-api-key-ai2cm-sa \
        --dataset-secret google-credentials:/tmp/google_application_credentials.json \
        --dataset $dataset_id:training_checkpoints/best_inference_ckpt.tar:/ckpt.tar \
        --gpus 1 \
        --shared-memory 20GiB \
        --min-runtime 5h \
        --weka climate-default:/climate-default \
        --system-python \
        --install "pip install --no-deps ." \
        -- /bin/bash -c "\
            echo '${CONFIG_B64}' | base64 -d > /tmp/config.yaml \
            && \
            python -I -m fme.ace.inference /tmp/config.yaml --override $spin_up_overrides \
            && \
            python -I -m fme.ace.inference /tmp/config.yaml --override $train_and_validate_overrides \
            && \
            python -I -m fme.ace.inference /tmp/config.yaml --override $test_overrides \
        "
done
