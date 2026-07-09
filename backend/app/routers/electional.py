from fastapi import APIRouter, HTTPException

from app.models.schemas import ElectionalDay, ElectionalHit, ElectionalRequest, ElectionalResponse
from app.services import electional, ephemeris
from app.services import timezone as tz_resolver

router = APIRouter(tags=["electional"])


@router.post("/electional", response_model=ElectionalResponse)
def get_electional(request: ElectionalRequest) -> ElectionalResponse:
    if request.theme not in electional.THEMES:
        raise HTTPException(status_code=400, detail=f"Unknown theme: {request.theme}")

    if request.tz_offset is not None:
        natal_tz_offset = request.tz_offset
    else:
        try:
            _timezone_id, natal_tz_offset = tz_resolver.resolve_utc_offset(
                request.latitude, request.longitude, request.date, request.time
            )
        except tz_resolver.TimezoneLookupError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e

    jd_ut = ephemeris.julian_day_ut(request.date, request.time, natal_tz_offset)
    asc_lon, _mc_lon = ephemeris.calc_angles(jd_ut, request.latitude, request.longitude)

    # The scan window is "now" (or a future window), not the birth date, so
    # its UTC offset is resolved separately — the two can legitimately differ
    # (e.g. a winter birth scanned against a summer DST window).
    try:
        _timezone_id, scan_tz_offset = tz_resolver.resolve_utc_offset(
            request.latitude, request.longitude, request.start_date, "12:00"
        )
    except tz_resolver.TimezoneLookupError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    result = electional.scan(
        asc_longitude=asc_lon,
        theme_key=request.theme,
        start_date=request.start_date,
        end_date=request.end_date,
        tz_offset=scan_tz_offset,
    )

    days = []
    for r in result["days"]:
        _derived_date, time_str = electional.jd_to_local_datetime(r["best_time_jd"], scan_tz_offset)
        days.append(
            ElectionalDay(
                date=r["date"],
                best_time=time_str,
                quality_label=r["quality_label"],
                reasons=r["reasons"],
                hits=[ElectionalHit(**h) for h in r["hits"]],
            )
        )

    return ElectionalResponse(
        theme=request.theme,
        theme_label=electional.THEMES[request.theme]["label"],
        banner=result["banner"],
        note=result["note"],
        days=days,
    )
