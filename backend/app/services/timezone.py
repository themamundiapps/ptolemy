"""Historically-accurate UTC offset resolution from coordinates + local date/time."""
from datetime import datetime

import pytz
from timezonefinder import TimezoneFinder

_tf = TimezoneFinder()


class TimezoneLookupError(Exception):
    pass


def resolve_utc_offset(latitude: float, longitude: float, date: str, time: str) -> tuple[str, float]:
    """Returns (IANA tz id, UTC offset in hours) in effect at the given local date/time."""
    tz_name = _tf.timezone_at(lat=latitude, lng=longitude)
    if tz_name is None:
        raise TimezoneLookupError("Could not determine a timezone for these coordinates")

    tz = pytz.timezone(tz_name)
    naive_dt = datetime.strptime(f"{date} {time}", "%Y-%m-%d %H:%M")
    localized = tz.localize(naive_dt)
    offset_hours = localized.utcoffset().total_seconds() / 3600
    return tz_name, offset_hours
