#!/opt/homebrew/bin/bash

set -e

CONFIG_FILENAME="ace-amip-data-only-evaluator-config-daily-PRATEsfc.yaml"
BEAKER_IMAGE=jeremym/fme-deps-only-5039277ac
SCRIPT_PATH=$(git rev-parse --show-prefix)  # relative to the root of the repository
CONFIG_PATH=$SCRIPT_PATH/$CONFIG_FILENAME
 # since we use a service account API key for wandb, we use the beaker username to set the wandb username
WANDB_USERNAME=spencerc_ai2
REPO_ROOT=$(git rev-parse --show-toplevel)

CHECKPOINT_PATH=training_checkpoints/best_inference_ckpt.tar

cd $REPO_ROOT  # so config path is valid no matter where we are running this script

CONFIG_B64=$(base64 < "$CONFIG_PATH" | tr -d '\n')

REFERENCE_MODEL="01KHGDAMB2BDZQS8JFF65A2YDR"

GCS_ROOT="gs://vcm-ml-experiments/spencerc/2026-04-25-amip-inference"

TRAIN_AND_VALIDATE_EXPERIMENT_DIR="/results/train-and-validate"

# xr.date_range("1980", "2012", freq="6h", inclusive="left")
TRAIN_AND_VALIDATE_START_TIME="1980-01-01T00:00:00"
TRAIN_AND_VALIDATE_N_FORWARD_STEPS=46752

# xr.date_range("2012", "2021", freq="6h", inclusive="left")
TEST_START_TIME="2012-01-01T00:00:00"
TEST_N_FORWARD_STEPS=13152

for ensemble_id in "ic_0001"; do
    test_experiment_dir="${GCS_ROOT}/SHiELD-${ensemble_id}/test"
    job_name="amip-${ensemble_id}-split-data-only-evaluator"
    train_and_validate_override="\
        experiment_dir=${TRAIN_AND_VALIDATE_EXPERIMENT_DIR} \
        n_forward_steps=${TRAIN_AND_VALIDATE_N_FORWARD_STEPS} \
        loader.start_indices.times=[${TRAIN_AND_VALIDATE_START_TIME}] \
        prediction_loader.start_indices.times=[${TRAIN_AND_VALIDATE_START_TIME}] \
        loader.dataset.file_pattern=${ensemble_id}.zarr \
        prediction_loader.dataset.file_pattern=${ensemble_id}.zarr \
        data_writer.files=[] \
    "
    python -m fme.ace.validate_config --config_type evaluator $CONFIG_PATH --override $train_and_validate_override
    test_override="\
        experiment_dir=${test_experiment_dir} \
        n_forward_steps=${TEST_N_FORWARD_STEPS} \
        loader.start_indices.times=[${TEST_START_TIME}] \
        prediction_loader.start_indices.times=[${TEST_START_TIME}] \
        loader.dataset.file_pattern=${ensemble_id}.zarr \
        prediction_loader.dataset.file_pattern=${ensemble_id}.zarr \
    "
    python -m fme.ace.validate_config --config_type evaluator $CONFIG_PATH --override $test_override

    gantry run \
        --remote https://github.com/ai2cm/ace \
        --ref 4ca6589b5189e82b89ea3c500862871a703d0ded \
        --name $job_name \
        --description 'Run ACE AMIP data-only evaluator' \
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
        -- /bin/bash -c "\
            echo '${CONFIG_B64}' | base64 -d > /tmp/config.yaml \
            && \
            python -I -m fme.ace.evaluator /tmp/config.yaml --override $train_and_validate_override \
            && \
            python -I -m fme.ace.evaluator /tmp/config.yaml --override $test_override \
        "
done
