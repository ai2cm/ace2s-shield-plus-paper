import argparse
import json
import random

from pathlib import Path


DESCRIPTION = (
    "A simple command line tool meant to help facilitate randomly setting "
    "inference seeds for unique jobs and recording them in a file for future "
    "use. If the provided job_name is not found in the seed_record.json file, "
    "a new seed will be generated and printed out; if the provided job_name is "
    "found in the file, then it will print the seed that was used for that "
    "job. This tool also ensures that all generated seed are unique; if a "
    "generated seed already exists in the record for another job, the seed "
    "will be re-generated until a unique one is found."
)
SCRIPT_DIRCTORY = Path(__file__).parent
SEED_RECORD_FILE = Path(SCRIPT_DIRCTORY / "seed_record.json")
MAXIMUM_SEED = 2 ** 31 - 1


def load_seed_record():
    if SEED_RECORD_FILE.exists():
        with open(SEED_RECORD_FILE) as file:
            return json.load(file)
    else:
        return {}


def write_seed_record(seed_record: dict):
    with open(SEED_RECORD_FILE, "w") as file:
        json.dump(seed_record, file, indent=4)


def select_seed(job_name: str, seed_record: dict):
    if job_name in seed_record:
        seed = seed_record[job_name]
    else:
        seed = None
        while seed is None or seed in seed_record.values():
            seed = random.randint(0, MAXIMUM_SEED)
    return seed


def record_seed(job_name: str, seed_record: dict, seed: int):
    seed_record[job_name] = seed
    write_seed_record(seed_record)


def main(args):
    job_name = args.job_name
    seed_record = load_seed_record()
    seed = select_seed(job_name, seed_record)
    record_seed(job_name, seed_record, seed)
    print(seed)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=DESCRIPTION)
    parser.add_argument(
        "job_name", 
        help=(
            "Name of the beaker job to set the seed for; it is assumed this "
            "will be unique."
        )
    )
    args = parser.parse_args()
    main(args)
