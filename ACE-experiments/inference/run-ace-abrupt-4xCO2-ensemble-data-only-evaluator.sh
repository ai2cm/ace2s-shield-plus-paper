#!/bin/bash

set -e

WANDB_USERNAME=spencerc_ai2
CONFIG_FILENAME="ace-abrupt-4xCO2-ensemble-data-only-evaluator-config.yaml"
BEAKER_IMAGE=jeremym/fme-deps-only-5039277ac
SCRIPT_PATH=$(git rev-parse --show-prefix)  # relative to the root of the repository
CONFIG_PATH=$SCRIPT_PATH/$CONFIG_FILENAME
REPO_ROOT=$(git rev-parse --show-toplevel)

EXISTING_RESULTS_DATASET="01KHGDAMB2BDZQS8JFF65A2YDR"
len=36

cd $REPO_ROOT

CONFIG_B64=$(base64 < "$CONFIG_PATH" | tr -d '\n')

python -m fme.ace.validate_config --config_type evaluator $CONFIG_PATH
for (( i=1; i<=$len; i++ )); do
    i_padded=$(printf "%04d" $i)
    JOB_NAME=shield-data-only-evaluator-abrupt4xCO2-ic-$i_padded
    FILE_PATTERN="abrupt4xCO2-ic_$i_padded.zarr"

    gantry run \
        --remote https://github.com/ai2cm/ace \
        --ref 4ca6589b5189e82b89ea3c500862871a703d0ded \
        --name $JOB_NAME \
        --description 'Run ACE evaluator' \
        --beaker-image "${BEAKER_IMAGE}" \
        --workspace ai2/climate-titan \
        --priority urgent \
        --cluster ai2/titan \
        --env WANDB_USERNAME=$WANDB_USERNAME \
        --env WANDB_NAME=$JOB_NAME \
        --env WANDB_JOB_TYPE=inference \
        --env WANDB_RUN_GROUP= \
        --env GOOGLE_APPLICATION_CREDENTIALS=/tmp/google_application_credentials.json \
        --env-secret WANDB_API_KEY=wandb-api-key-ai2cm-sa \
        --dataset $EXISTING_RESULTS_DATASET:training_checkpoints/best_inference_ckpt.tar:/ckpt.tar \
        --dataset-secret google-credentials:/tmp/google_application_credentials.json \
        --gpus 1 \
        --shared-memory 20GiB \
        --weka climate-default:/climate-default \
        --system-python \
        --preemptible \
        --install "pip install --no-deps ." \
        -- bash -c "\
            echo '${CONFIG_B64}' | base64 -d > /tmp/config.yaml \
            && \
            python -I -m fme.ace.evaluator /tmp/config.yaml --override loader.dataset.file_pattern=$FILE_PATTERN prediction_loader.dataset.file_pattern=$FILE_PATTERN
        "
done
