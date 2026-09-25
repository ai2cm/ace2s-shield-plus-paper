#!/opt/homebrew/bin/bash

set -e

DATE=2026-09-09
WANDB_USERNAME=spencerc_ai2
CONFIG_FILENAME="ace-som-2pctCO2-inference-config.yaml"
BEAKER_IMAGE=oliverwm/fme-deps-only-54045d546
ACE_COMMIT=56820c0eb856d2948e20fb696f96eb53d0a43098
SCRIPT_PATH=$(git rev-parse --show-prefix)  # relative to the root of the repository
CONFIG_PATH=$SCRIPT_PATH/$CONFIG_FILENAME
SET_SEED=$SCRIPT_PATH/set_seed.py

SPIN_UP_FORCING_ROOT=/climate-default/2024-08-15-vertically-resolved-1deg-c96-shield-som-ensemble-spin-up-fme-dataset/netcdfs/concatenated-1xCO2-ic_0005
MAIN_FORCING_ROOT=/climate-default/2026-01-28-vertically-resolved-1deg-c96-shield-som-increasing-co2-fme-dataset
MAIN_FORCING_PATH=increasing-CO2.zarr

declare -A MODELS=( \
    [no-random-co2-rs0]="01KHGDAMB2BDZQS8JFF65A2YDR" \
    [no-random-co2-rs1]="01KH4SDCYN1NF2RP2JXZS0WZ1Y" \
    [no-random-co2-energy-conserving-rs0]="01KHGDA8TVGP9JKWVJ1N0SMHCN" \
    [no-random-co2-energy-conserving-rs1]="01KH4SDT1Q5246GZ307W8AW4M3" \
    [full-rs0]="01KHKJ02SQM8S8T4B6030F94CV" \
    [full-rs1]="01KHJ5EQ04XTFG46QCKX3TTAHF" \
    [full-energy-conserving-rs0]="01KHJ5F1M6YKVZESPZAAVVD6G8" \
    [full-energy-conserving-rs1]="01KHCXABVNA3TJW0ZT5F4YDDQT" \
)

REPO_ROOT=$(git rev-parse --show-toplevel)
cd $REPO_ROOT  # so config path is valid no matter where we are running this script

CONFIG_B64=$(base64 < "$CONFIG_PATH" | tr -d '\n')

SPIN_UP_N_FORWARD_STEPS=1460
SPIN_UP_EXPERIMENT_DIR="/results/spin-up"

MAIN_INITIAL_CONDITION_TIME="2031-01-01T06:00:00"
MAIN_INITIAL_CONDITION_PATH="/results/spin-up/restart.nc"
MAIN_N_FORWARD_STEPS=102267
MAIN_EXPERIMENT_DIR="/results/main"

for model in "${!MODELS[@]}"; do
    job_name=$DATE-$model-2pctCO2-inference
    seed=$(python $SET_SEED $job_name)
    dataset_id="${MODELS[$model]}"

    spin_up_initial_condition_path=$SPIN_UP_FORCING_ROOT/2030010100.nc
    spin_up_log_to_wandb=false  # Disable logging to wandb in spin up case.
    spin_up_overrides="\
        experiment_dir=$SPIN_UP_EXPERIMENT_DIR \
        forcing_loader.dataset.data_path=$SPIN_UP_FORCING_ROOT \
        initial_condition.path=$spin_up_initial_condition_path \
        initial_condition.start_indices.times=[2030-01-01T06:00:00,2030-01-01T06:00:00] \
        n_forward_steps=$SPIN_UP_N_FORWARD_STEPS \
        logging.log_to_wandb=$spin_up_log_to_wandb \
        data_writer.files=[] \
        seed=$seed \
    "
    main_overrides="\
        experiment_dir=$MAIN_EXPERIMENT_DIR \
        forcing_loader.dataset.data_path=$MAIN_FORCING_ROOT \
        forcing_loader.dataset.engine=zarr \
        forcing_loader.dataset.file_pattern=$MAIN_FORCING_PATH \
        initial_condition.path=$MAIN_INITIAL_CONDITION_PATH \
        initial_condition.start_indices=null \
        n_forward_steps=$MAIN_N_FORWARD_STEPS \
        seed=$seed \
    "

    python -m fme.ace.validate_config --config_type inference $CONFIG_PATH --override $spin_up_overrides
    python -m fme.ace.validate_config --config_type inference $CONFIG_PATH --override $main_overrides
    gantry run \
        --remote https://github.com/ai2cm/ace \
        --ref $ACE_COMMIT \
        --name $job_name \
        --description 'Run inference with ACE' \
        --beaker-image "${BEAKER_IMAGE}" \
        --workspace ai2/ace \
        --priority high \
        --cluster ai2/titan \
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
        --min-runtime 8h \
        --weka climate-default:/climate-default \
        --system-python \
        --install "pip install --no-deps ." \
        -- /bin/bash -c "\
            echo '${CONFIG_B64}' | base64 -d > /tmp/config.yaml \
            && \
            python -I -m fme.ace.inference /tmp/config.yaml --override $spin_up_overrides \
            && \
            python -I -m fme.ace.inference /tmp/config.yaml --override $main_overrides \
        "
done
