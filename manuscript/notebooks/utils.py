import logging

import beaker
import wandb


def beaker_dataset_id_from_name(name: str) -> str:
    """Get a dataset_id resulting from an experiment with a given name.
    
    Assumes it will be from the last job, which is assumed to be successful.
    """
    client = beaker.Beaker.from_env()
    experiment_client = beaker.services.ExperimentClient(client)
    return (
        experiment_client
        .get(name)
        .jobs[-1]
        .result
        .beaker
    )


def wandb_id_from_name(name: str, project: str = "ace-shield") -> str:
    api = wandb.Api()
    runs = api.runs(f"ai2cm/{project}", filters={"display_name": {"$eq": name}})
    completed = [run for run in runs if run.state == "finished"]
    if len(completed) > 1:
        raise ValueError(f"Ambiguous name {name}")
    elif len(completed) == 0:
        logging.info(f"No WandB run found for {name}")
        return None
    else:
        (result,) = completed
        return "/".join(result.path)
