#!/opt/homebrew/bin/bash

set -e

CONFIG_FILENAME="ace-2pctCO2-data-only-evaluator-config.yaml"
BEAKER_IMAGE=jeremym/fme-deps-only-5039277ac
SCRIPT_PATH=$(git rev-parse --show-prefix)  # relative to the root of the repository
CONFIG_PATH=$SCRIPT_PATH/$CONFIG_FILENAME
 # since we use a service account API key for wandb, we use the beaker username to set the wandb username
WANDB_USERNAME=spencerc_ai2
REPO_ROOT=$(git rev-parse --show-toplevel)

REFERENCE_MODEL="01KHGDAMB2BDZQS8JFF65A2YDR"
CHECKPOINT_PATH=training_checkpoints/best_inference_ckpt.tar

cd $REPO_ROOT  # so config path is valid no matter where we are running this script

CONFIG_B64=$(base64 < "$CONFIG_PATH" | tr -d '\n')

DATA_ROOT="/climate-default/2026-01-28-vertically-resolved-1deg-c96-shield-som-increasing-co2-fme-dataset"
FILE_PATTERN="increasing-CO2.zarr"
override="\
    loader.dataset.data_path=${DATA_ROOT} \
    loader.dataset.file_pattern=${FILE_PATTERN} \
    prediction_loader.dataset.data_path=${DATA_ROOT} \
    prediction_loader.dataset.file_pattern=${FILE_PATTERN} \
"
python -m fme.ace.validate_config --config_type evaluator $CONFIG_PATH --override $override
job_name="2pctCO2-ic_0001-data-only-evaluator"
gantry run \
    --remote https://github.com/ai2cm/ace \
    --ref 4ca6589b5189e82b89ea3c500862871a703d0ded \
    --name $job_name \
    --description 'Run ACE 2pctCO2 data-only evaluator' \
    --beaker-image "${BEAKER_IMAGE}" \
    --workspace ai2/climate-titan \
    --priority urgent \
    --preemptible \
    --cluster ai2/titan \
    --env WANDB_USERNAME=$WANDB_USERNAME \
    --env WANDB_NAME=$job_name \
    --env WANDB_JOB_TYPE=inference \
    --env WANDB_RUN_GROUP= \
    --env GOOGLE_APPLICATION_CREDENTIALS=/tmp/google_application_credentials.json \
    --env-secret WANDB_API_KEY=wandb-api-key-ai2cm-sa \
    --dataset-secret google-credentials:/tmp/google_application_credentials.json \
    --dataset $REFERENCE_MODEL:$CHECKPOINT_PATH:/ckpt.tar \
    --gpus 1 \
    --shared-memory 20GiB \
    --weka climate-default:/climate-default \
    --system-python \
    --install "pip install --no-deps ." \
    -- bash -c "\
        echo '${CONFIG_B64}' | base64 -d > /tmp/config.yaml \
        && \
        python -I -m fme.ace.evaluator /tmp/config.yaml --override $override \
    "


DATA_ROOT="/climate-default/2025-03-22-vertically-resolved-1deg-c96-shield-som-3d-radiative-heating-rates-increasing-co2-fme-dataset"
FILE_PATTERN="increasing-CO2.zarr"
override="\
    loader.dataset.data_path=${DATA_ROOT} \
    loader.dataset.file_pattern=${FILE_PATTERN} \
    prediction_loader.dataset.data_path=${DATA_ROOT} \
    prediction_loader.dataset.file_pattern=${FILE_PATTERN} \
"
python -m fme.ace.validate_config --config_type evaluator $CONFIG_PATH --override $override
job_name="2pctCO2-ic_0002-data-only-evaluator"
gantry run \
    --remote https://github.com/ai2cm/ace \
    --ref 4ca6589b5189e82b89ea3c500862871a703d0ded \
    --name $job_name \
    --description 'Run ACE 2pctCO2 data-only evaluator' \
    --beaker-image "${BEAKER_IMAGE}" \
    --workspace ai2/climate-titan \
    --priority urgent \
    --preemptible \
    --cluster ai2/titan \
    --env WANDB_USERNAME=$WANDB_USERNAME \
    --env WANDB_NAME=$job_name \
    --env WANDB_JOB_TYPE=inference \
    --env WANDB_RUN_GROUP= \
    --env GOOGLE_APPLICATION_CREDENTIALS=/tmp/google_application_credentials.json \
    --env-secret WANDB_API_KEY=wandb-api-key-ai2cm-sa \
    --dataset-secret google-credentials:/tmp/google_application_credentials.json \
    --dataset $REFERENCE_MODEL:$CHECKPOINT_PATH:/ckpt.tar \
    --gpus 1 \
    --shared-memory 20GiB \
    --weka climate-default:/climate-default \
    --system-python \
    --install "pip install --no-deps ." \
    -- bash -c "\
        echo '${CONFIG_B64}' | base64 -d > /tmp/config.yaml \
        && \
        python -I -m fme.ace.evaluator /tmp/config.yaml --override $override \
    "
