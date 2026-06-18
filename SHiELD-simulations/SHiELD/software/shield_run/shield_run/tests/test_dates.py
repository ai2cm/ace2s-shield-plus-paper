import textwrap

import cftime
import pytest


from shield_run.dates import (
    duration_months_representable,
    duration_timedelta_representable,
    get_date,
    get_duration_config,
    get_initial_date,
    get_segment_dates,
    DATE_TYPES,
)


SAMPLE_COUPLER_RES = textwrap.dedent(
    """\
         3        (Calendar: no_calendar=0, thirty_day_months=1, julian=2, gregorian=3, noleap=4)
      2030     1     1     0     0     0        Model start time:   year, month, day, hour, minute, second
      2031     1    31     0     0     0        Current model time: year, month, day, hour, minute, second
    """
)


def test_get_duration_config():
    config = {"namelist": {"coupler_nml": {"days": 1, "seconds": 5}}}
    expected = {"months": 0, "days": 1, "hours": 0, "minutes": 0, "seconds": 5}
    result = get_duration_config(config)
    assert result == expected


@pytest.mark.parametrize(("months", "expected"), [(0, True), (1, False)])
def test_duration_timedelta_representable(months, expected):
    config = {"namelist": {"coupler_nml": {"months": months}}}
    assert duration_timedelta_representable(config) == expected


@pytest.mark.parametrize("units", ["seconds", "minutes", "hours", "days"])
def test_duration_months_representable(units):
    config = {"namelist": {"coupler_nml": {units: 1}}}
    assert duration_months_representable(config) == False


@pytest.mark.parametrize("calendar", ["gregorian", "julian"])
def test_get_date_timedelta_representable(calendar):
    config = {
        "namelist": {
            "coupler_nml": {
                "current_date": [2020, 2, 1, 0, 0, 0],
                "days": 1,
                "hours": 10,
                "calendar": calendar,
                "force_date_from_namelist": True,
            }
        }
    }
    segment = 1
    datetime = DATE_TYPES[calendar]

    result_start = get_date(config, segment, end_date=False)
    expected_start = datetime(2020, 2, 2, 10)
    assert result_start == expected_start

    result_end = get_date(config, segment, end_date=True)
    expected_end = datetime(2020, 2, 3, 20)
    assert result_end == expected_end


@pytest.mark.parametrize("calendar", ["gregorian", "julian"])
def test_get_date_months_representable(calendar):
    config = {
        "namelist": {
            "coupler_nml": {
                "current_date": [2020, 2, 1, 0, 0, 0],
                "months": 2,
                "calendar": calendar,
                "force_date_from_namelist": True,
            }
        }
    }
    segment = 1
    datetime = DATE_TYPES[calendar]

    result_start = get_date(config, segment, end_date=False)
    expected_start = datetime(2020, 4, 1)
    assert result_start == expected_start

    result_end = get_date(config, segment, end_date=True)
    expected_end = datetime(2020, 6, 1)
    assert result_end == expected_end


@pytest.mark.parametrize("calendar", ["gregorian", "julian"])
def test_get_date_invalid_months_representable(calendar):
    config = {
        "namelist": {
            "coupler_nml": {
                "current_date": [2020, 2, 5, 0, 0, 0],
                "months": 2,
                "calendar": calendar,
                "force_date_from_namelist": True,
            }
        }
    }
    segment = 1
    with pytest.raises(ValueError, match="Segment length"):
        get_date(config, segment)


@pytest.mark.parametrize("calendar", ["gregorian", "julian"])
def test_get_segment_dates(calendar):
    config = {
        "namelist": {
            "coupler_nml": {
                "current_date": [2020, 2, 1, 0, 0, 0],
                "days": 1,
                "hours": 10,
                "calendar": calendar,
            }
        }
    }
    segment = 1
    expected = ("2020020210", "2020020320")
    result = get_segment_dates(config, segment)
    assert result == expected


@pytest.mark.parametrize("calendar", ["gregorian", "julian"])
@pytest.mark.parametrize(
    ("force_date_from_namelist", "warm_start", "expected_date_tuple"),
    [
        (False, False, [2020, 2, 1, 0, 0, 0]),
        (False, True, [2031, 1, 31, 0, 0, 0]),
        (True, False, [2020, 2, 1, 0, 0, 0]),
        (True, True, [2020, 2, 1, 0, 0, 0]),
    ],
)
def test_get_initial_date(
    tmp_path, calendar, force_date_from_namelist, warm_start, expected_date_tuple
):
    if warm_start:
        coupler_res = tmp_path / "coupler.res"
        with coupler_res.open("w") as file:
            file.write(SAMPLE_COUPLER_RES)
            print(SAMPLE_COUPLER_RES.split("\n"))

        initial_conditions = tmp_path.as_posix()
    else:
        initial_conditions = "/path/to/nggps/initial_condition"

    config = {
        "initial_conditions": initial_conditions,
        "namelist": {
            "coupler_nml": {
                "current_date": [2020, 2, 1, 0, 0, 0],
                "days": 1,
                "hours": 10,
                "calendar": calendar,
                "force_date_from_namelist": force_date_from_namelist,
            },
            "fv_core_nml": {"warm_start": warm_start},
        },
    }

    datetime = DATE_TYPES[calendar]
    expected = datetime(*expected_date_tuple)
    result = get_initial_date(config)
    assert result == expected
