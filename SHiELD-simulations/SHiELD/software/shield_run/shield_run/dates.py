import argparse
import re

import cftime
import fv3config
import xarray as xr
import yaml

from pathlib import Path
from typing import Dict, Tuple


UNITS = {"seconds", "minutes", "hours", "days", "months"}
NON_MONTH_UNITS = {"seconds", "minutes", "hours", "days"}
DATE_FORMAT = "%Y%m%d%H"
DATE_TYPES = {"gregorian": cftime.DatetimeGregorian, "julian": cftime.DatetimeJulian}


def get_duration_config(config: dict) -> Dict[str, int]:
    coupler_nml = config["namelist"].get("coupler_nml", {})
    return {unit: coupler_nml.get(unit, 0) for unit in UNITS}


def duration_timedelta_representable(config: dict) -> bool:
    duration_config = get_duration_config(config)
    return duration_config["months"] == 0


def duration_months_representable(config: dict) -> bool:
    duration_config = get_duration_config(config)
    return all(duration_config[unit] == 0 for unit in NON_MONTH_UNITS)


def get_initial_condition_directory(config: dict) -> Path:
    return Path(config["initial_conditions"])


def parse_date_from_line(line) -> Tuple[int, ...]:
    """coupler.res parsing code based on fv3config"""
    return (int(d) for d in re.findall(r"\d+", line))


def infer_start_date_from_coupler_res(config: dict) -> cftime.datetime:
    """coupler.res parsing code based on fv3config"""
    initial_condition_directory = get_initial_condition_directory(config)
    coupler_res = initial_condition_directory / "coupler.res"
    with coupler_res.open("r") as file:
        lines = file.readlines()
        initial_date_tuple = parse_date_from_line(lines[2])
    return initial_date_tuple


def get_initial_date(config: dict) -> cftime.datetime:
    force_date_from_namelist = config["namelist"]["coupler_nml"].get(
        "force_date_from_namelist", False
    )
    warm_start = config["namelist"].get("fv_core_nml", {}).get("warm_start", False)

    if force_date_from_namelist or not warm_start:
        initial_date_tuple = config["namelist"]["coupler_nml"]["current_date"]
    else:
        initial_date_tuple = infer_start_date_from_coupler_res(config)

    calendar = get_calendar(config)
    datetime = DATE_TYPES[calendar]
    return datetime(*initial_date_tuple)


def get_calendar(config: dict) -> str:
    return config["namelist"]["coupler_nml"]["calendar"]


def get_date(config: dict, segment: int, end_date: bool = False) -> cftime.datetime:
    """Return the date associated with the start or end of the segment

    Args:
        config: dict
            fv3config configuration dictionary for the simulation
        segment: int
            segment of the simulation (note this is zero indexed; the first
            segment is segment zero).
        end_date: bool
            whether to return the end date of the segment instead of the start

    Returns:
        date: cftime.datetime
    """
    initial_date = get_initial_date(config)
    calendar = get_calendar(config)

    if duration_timedelta_representable(config):
        duration = fv3config.get_run_duration(config)
        if end_date:
            segment = segment + 1
        date = initial_date + segment * duration
    elif duration_months_representable(config) and initial_date.day == 1:
        duration = get_duration_config(config)["months"]
        if end_date:
            segment = segment + 1
        freq = f"{duration}MS"
        periods = segment + 1  # segment == 1 to return initial date
        date_range = xr.cftime_range(
            initial_date, freq=freq, periods=periods, calendar=calendar
        )
        date = date_range.values[-1]
    else:
        raise ValueError("Segment length and initial date combination not supported.")

    return date


def get_segment_dates(config: dict, segment_number: int) -> Tuple[str, str]:
    start_date = get_date(config, segment_number, end_date=False)
    end_date = get_date(config, segment_number, end_date=True)
    return start_date.strftime(DATE_FORMAT), end_date.strftime(DATE_FORMAT)
