from fastapi import APIRouter, HTTPException

from app.models.schemas import ChatAstrologerRequest, ChatAstrologerResponse
from app.services import chat, ephemeris, natal, rate_limit

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("/astrologer", response_model=ChatAstrologerResponse)
def astrologer(request: ChatAstrologerRequest) -> ChatAstrologerResponse:
    if not rate_limit.check_and_consume(request.user_id):
        raise HTTPException(status_code=429, detail=rate_limit.LIMIT_MESSAGE)

    try:
        tz_offset = natal.resolve_tz_offset(request)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    native = natal.compute_natal(request.date, request.time, request.latitude, request.longitude, tz_offset)

    asc_lon = native["asc_lon"]
    planets = native["planets"]

    planet_entries = [
        {"name": name, "sign": pos.sign, "house": pos.house, "dignities": pos.dignities} for name, pos in planets.items()
    ]

    house_lord_lines = []
    for house_number in range(1, 13):
        sign = ephemeris.house_sign(house_number, asc_lon)
        lord = ephemeris.sign_ruler(sign)
        house_lord_lines.append(f"House {house_number} — Lord: {lord} — in House {planets[lord].house}")

    planet_longitudes = {name: pos.longitude for name, pos in planets.items()}
    aspects = sorted(ephemeris.find_aspects(planet_longitudes), key=lambda a: a["orb"])

    fortune_lon = ephemeris.lot_of_fortune(asc_lon, native["sun_lon"], native["moon_lon"], native["diurnal"])
    fortune_sign, _fortune_deg = ephemeris.sign_and_degree(fortune_lon)
    fortune_house = ephemeris.whole_sign_house(fortune_lon, asc_lon)

    spirit_lon = ephemeris.lot_of_spirit(asc_lon, native["sun_lon"], native["moon_lon"], native["diurnal"])
    spirit_sign, _spirit_deg = ephemeris.sign_and_degree(spirit_lon)
    spirit_house = ephemeris.whole_sign_house(spirit_lon, asc_lon)

    chart_context = chat.build_chart_context(
        ascendant_sign=native["asc_sign"],
        midheaven_sign=native["mc_sign"],
        sect="Diurnal" if native["diurnal"] else "Nocturnal",
        temperament_label=native["temperament_label"],
        planets=planet_entries,
        house_lord_lines=house_lord_lines,
        aspects=aspects,
        fortune_sign=fortune_sign,
        fortune_house=fortune_house,
        spirit_sign=spirit_sign,
        spirit_house=spirit_house,
    )

    conversation = [{"role": m.role, "content": m.content} for m in request.messages]

    try:
        reply = chat.generate_chat_reply(chart_context, conversation, request.depth)
    except chat.ChatError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e

    return ChatAstrologerResponse(reply=reply)
