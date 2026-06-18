#!/bin/bash

set -e

CONFIG_FILENAME="one-step-pre-train-config-full.yaml"
SCRIPT_PATH=$(git rev-parse --show-prefix)  # relative to the root of the repository
CONFIG_PATH=$SCRIPT_PATH/$CONFIG_FILENAME
WANDB_USERNAME=spencerc_ai2
WANDB_GROUP=ace-shield
REPO_ROOT=$(git rev-parse --show-toplevel)
N_GPUS=4
STATS_DATASET=andrep/2026-02-06-vertically-resolved-1deg-c96-shield-ramped-climSST-random-CO2-ensemble-fme-dataset-stats

cd $REPO_ROOT  # so config path is valid no matter where we are running this

CONFIG_B64=$(base64 < "$CONFIG_PATH" | tr -d '\n')

for seed in 0 1
do
    job_name="ace-shield-one-step-pre-train-full-rs${seed}"
    override="seed=${seed}"
    python -m fme.ace.validate_config --config_type train $CONFIG_PATH --override $override
    gantry run \
        --remote https://github.com/ai2cm/ace \
        --ref 4ca6589b5189e82b89ea3c500862871a703d0ded \
        --name $job_name \
        --description 'Run ACE training' \
        --beaker-image "$(cat $REPO_ROOT/latest_deps_only_image.txt)" \
        --workspace ai2/climate-titan \
        --priority urgent \
        --preemptible \
        --cluster ai2/titan \
        --env WANDB_NAME=$job_name \
        --env WANDB_USERNAME=$WANDB_USERNAME \
        --env WANDB_JOB_TYPE=training \
        --env WANDB_RUN_GROUP=$WANDB_GROUP \
        --env GOOGLE_APPLICATION_CREDENTIALS=/tmp/google_application_credentials.json \
        --env-secret WANDB_API_KEY=wandb-api-key-ai2cm-sa \
        --dataset-secret google-credentials:/tmp/google_application_credentials.json \
        --dataset $STATS_DATASET:/statsdata \
        --gpus $N_GPUS \
        --shared-memory 400GiB \
        --weka climate-default:/climate-default \
        --system-python \
        --install "pip install --no-deps ." \
        -- bash -c "echo '${CONFIG_B64}' | base64 -d > /tmp/config.yaml && torchrun --nproc_per_node $N_GPUS -m fme.ace.train /tmp/config.yaml --override $override"
done
