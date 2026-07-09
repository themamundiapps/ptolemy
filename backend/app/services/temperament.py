"""Ptolemaic temperament calculation — Tetrabiblos Book I (Ch. 4, 8) and Book III (Ch. 11).

Pure Ptolemaic method: qualities (Hot/Cold/Moist/Dry) are collected from five
significators — the Ascending sign, planets in the 1st house, the ruler of
the Ascendant, the Moon, and the season — then Hot/Cold and Moist/Dry cancel
against each other to yield the net temperament.
"""

# Traditional (single) domicile ruler per sign.
SIGN_RULERS = {
    "Aries": "Mars",
    "Taurus": "Venus",
    "Gemini": "Mercury",
    "Cancer": "Moon",
    "Leo": "Sun",
    "Virgo": "Mercury",
    "Libra": "Venus",
    "Scorpio": "Mars",
    "Sagittarius": "Jupiter",
    "Capricorn": "Saturn",
    "Aquarius": "Saturn",
    "Pisces": "Jupiter",
}

FIRE_SIGNS = {"Aries", "Leo", "Sagittarius"}
EARTH_SIGNS = {"Taurus", "Virgo", "Capricorn"}
AIR_SIGNS = {"Gemini", "Libra", "Aquarius"}
WATER_SIGNS = {"Cancer", "Scorpio", "Pisces"}

TEMPERAMENT_QUALITIES = {
    "Sanguine": "Hot & Moist",
    "Choleric": "Hot & Dry",
    "Phlegmatic": "Cold & Moist",
    "Melancholic": "Cold & Dry",
}

TEMPERAMENT_DESCRIPTIONS = {
    "Sanguine": {
        "body": (
            "The Sanguine temperament is governed by air and blood. The native tends toward "
            "cheerfulness, generosity, and a natural ease in social life — the hot quality gives "
            "energy and initiative, while the moist quality gives adaptability and a pleasant, "
            "yielding disposition. The body tends toward good color, flesh, and vitality. Ptolemy "
            "associates this temperament with the quadrant of spring, when the ambient both warms "
            "and humidifies."
        ),
        "citation": (
            '"Two of the four humours are fertile and active — the hot and the moist — for all '
            'things are brought together and increased by them." — Claudius Ptolemy, Tetrabiblos, Book I'
        ),
    },
    "Choleric": {
        "body": (
            "The Choleric temperament is governed by fire and yellow bile. The native tends toward "
            "boldness, ambition, quickness to anger, and a restless, driving energy — the hot "
            "quality gives force and initiative, while the dry quality gives sharpness and a "
            "capacity for sustained effort without the softening influence of moisture. The body "
            "tends toward leanness, intensity, and heat. Ptolemy associates this temperament with "
            "the quadrant of summer, when the sun's heat is greatest and its drying power most "
            "pronounced."
        ),
        "citation": (
            '"The nature of Mars is chiefly to dry and to burn, in conformity with his fiery colour '
            'and by reason of his nearness to the sun." — Claudius Ptolemy, Tetrabiblos, Book I'
        ),
    },
    "Phlegmatic": {
        "body": (
            "The Phlegmatic temperament is governed by water and phlegm. The native tends toward "
            "passivity, adaptability, a yielding and patient disposition, and a difficulty with "
            "sustained initiative or decisive action — the cold quality slows and contracts, while "
            "the moist quality gives flexibility and a tendency to take the shape of surrounding "
            "circumstances. The body tends toward pallor, softness, and a susceptibility to cold "
            "and damp complaints. Ptolemy associates this temperament with winter, when cold and "
            "moisture both predominate."
        ),
        "citation": (
            "\"Saturn's quality is chiefly to cool and to moisten rarely, probably because he is "
            'furthest removed both from the sun\'s heat and the moist exhalations about the earth." '
            "— Claudius Ptolemy, Tetrabiblos, Book I"
        ),
    },
    "Melancholic": {
        "body": (
            "The Melancholic temperament is governed by earth and black bile. The native tends "
            "toward seriousness, depth of thought, caution, and a characteristic heaviness — the "
            "cold quality contracts and withdraws, while the dry quality hardens and fixes, "
            "producing a native who is persistent, self-contained, and oriented toward endurance "
            "rather than expansion. The body tends toward darkness, leanness, and a susceptibility "
            "to chronic, slow-developing conditions. Ptolemy associates this temperament with "
            "autumn, when the ambient cools and dries simultaneously."
        ),
        "citation": (
            '"Two of the four humours are destructive and passive — the dry and the cold — through '
            'which all things, again, are separated and destroyed." — Claudius Ptolemy, Tetrabiblos, Book I'
        ),
    },
}


def sign_quality(sign: str) -> list[str]:
    if sign in FIRE_SIGNS:
        return ["hot", "dry"]
    if sign in EARTH_SIGNS:
        return ["cold", "dry"]
    if sign in AIR_SIGNS:
        return ["hot", "moist"]
    if sign in WATER_SIGNS:
        return ["cold", "moist"]
    raise ValueError(f"Unknown sign: {sign}")


def sign_element(sign: str) -> str:
    if sign in FIRE_SIGNS:
        return "Fire"
    if sign in EARTH_SIGNS:
        return "Earth"
    if sign in AIR_SIGNS:
        return "Air"
    if sign in WATER_SIGNS:
        return "Water"
    raise ValueError(f"Unknown sign: {sign}")


def is_oriental(planet_longitude: float, sun_longitude: float) -> bool:
    difference = (planet_longitude - sun_longitude + 360) % 360
    return difference < 180


def planet_quality(planet: str, oriental: bool) -> list[str]:
    if planet == "Saturn":
        return ["cold", "moist"] if oriental else ["cold", "dry"]
    if planet == "Jupiter":
        return ["hot", "moist"] if oriental else ["moist"]
    if planet == "Mars":
        return ["hot", "dry"] if oriental else ["dry"]
    if planet == "Venus":
        return ["hot", "moist"]
    if planet == "Mercury":
        return ["hot"] if oriental else ["dry"]
    if planet == "Sun":
        return ["hot", "dry"]
    raise ValueError(f"planet_quality does not apply to {planet} — Moon's quality comes from its phase")


def moon_phase(moon_longitude: float, sun_longitude: float) -> tuple[str, list[str]]:
    angle = (moon_longitude - sun_longitude + 360) % 360
    if angle < 90:
        return "New Moon", ["moist"]
    if angle < 180:
        return "First Quarter", ["hot"]
    if angle < 270:
        return "Full Moon", ["dry"]
    return "Last Quarter", ["cold"]


def season(sun_longitude: float) -> tuple[str, list[str]]:
    if sun_longitude < 90:
        return "Spring", ["hot", "moist"]
    if sun_longitude < 180:
        return "Summer", ["hot", "dry"]
    if sun_longitude < 270:
        return "Autumn", ["cold", "dry"]
    return "Winter", ["cold", "moist"]


def _format_qualities(qualities: list[str]) -> str:
    """Formats a deduplicated list of qualities as flowing prose: "Hot",
    "Hot & Dry", or "Hot, Cold & Dry" for one, two, or three items."""
    words = []
    for q in qualities:
        word = q.capitalize()
        if word not in words:
            words.append(word)
    if len(words) == 1:
        return words[0]
    if len(words) == 2:
        return " & ".join(words)
    return ", ".join(words[:-1]) + " & " + words[-1]


def _planet_quality_and_label(name: str, longitude: float, sun_longitude: float) -> tuple[list[str], str]:
    """Returns (qualities, orientation label) for a planet, where the label is
    '' for Sun/Moon (orientation doesn't apply to either — Sun can't be
    oriental/occidental to itself, and the Moon's quality comes from phase)."""
    if name == "Sun":
        return ["hot", "dry"], ""
    if name == "Moon":
        _phase_name, qualities = moon_phase(longitude, sun_longitude)
        return qualities, ""
    oriental = is_oriental(longitude, sun_longitude)
    label = "Oriental" if oriental else "Occidental"
    return planet_quality(name, oriental), label


def _temperament_name(net_heat: int, net_moisture: int) -> str:
    if net_heat > 0 and net_moisture > 0:
        return "Sanguine"
    if net_heat > 0 and net_moisture <= 0:
        return "Choleric"
    if net_heat <= 0 and net_moisture > 0:
        return "Phlegmatic"
    return "Melancholic"


def _final_temperament_name(net_heat: int, net_moisture: int) -> str:
    primary = _temperament_name(net_heat, net_moisture)
    secondary = None
    if abs(net_heat) == 1:
        secondary = _temperament_name(-net_heat, net_moisture)
    elif abs(net_moisture) == 1:
        secondary = _temperament_name(net_heat, -net_moisture)
    if secondary and secondary != primary:
        return f"{primary}-{secondary}"
    return primary


def calculate(
    asc_sign: str,
    planets: dict[str, dict],
    sun_longitude: float,
    moon_longitude: float,
) -> dict:
    """planets: {name: {"longitude": float, "sign": str, "house": int}} for the 7 classical planets."""
    hot = cold = moist = dry = 0
    factors: list[dict] = []

    def add(qualities: list[str]) -> None:
        nonlocal hot, cold, moist, dry
        for q in qualities:
            if q == "hot":
                hot += 1
            elif q == "cold":
                cold += 1
            elif q == "moist":
                moist += 1
            elif q == "dry":
                dry += 1

    # Significator 1 — the Ascending sign.
    asc_quality = sign_quality(asc_sign)
    add(asc_quality)
    factors.append(
        {
            "label": "Ascending sign",
            "detail": f"Ascending sign: {asc_sign} ({sign_element(asc_sign)}) → {_format_qualities(asc_quality)}",
        }
    )

    # Significator 2 — each planet physically in the Ascending sign (house 1).
    for name, pos in planets.items():
        if pos["house"] != 1:
            continue
        planet_qualities, orientation_label = _planet_quality_and_label(name, pos["longitude"], sun_longitude)
        house_sign_quality = sign_quality(asc_sign)
        add(planet_qualities)
        add(house_sign_quality)
        descriptor = f", {orientation_label}," if orientation_label else ""
        combined = _format_qualities(planet_qualities + house_sign_quality)
        factors.append(
            {
                "label": "Planet in Ascendant",
                "detail": (
                    f"Planet in Ascendant: {name}{descriptor} in {asc_sign} "
                    f"({sign_element(asc_sign)}) → {combined}"
                ),
            }
        )

    # Significator 3 — ruler of the Ascending sign.
    ruler_name = SIGN_RULERS[asc_sign]
    ruler_pos = planets[ruler_name]
    ruler_qualities, ruler_orientation_label = _planet_quality_and_label(
        ruler_name, ruler_pos["longitude"], sun_longitude
    )
    ruler_sign_quality = sign_quality(ruler_pos["sign"])
    add(ruler_qualities)
    add(ruler_sign_quality)
    ruler_descriptor = f", {ruler_orientation_label}," if ruler_orientation_label else ""
    ruler_combined = _format_qualities(ruler_qualities + ruler_sign_quality)
    factors.append(
        {
            "label": "Ruler of Ascendant",
            "detail": (
                f"Ruler of Ascendant: {ruler_name}{ruler_descriptor} in {ruler_pos['sign']} "
                f"({sign_element(ruler_pos['sign'])}) → {ruler_combined}"
            ),
        }
    )

    # Significator 4 — the Moon (phase + sign), evaluated unconditionally.
    moon_sign = planets["Moon"]["sign"]
    phase_name, phase_quality = moon_phase(moon_longitude, sun_longitude)
    moon_sign_quality = sign_quality(moon_sign)
    add(phase_quality)
    add(moon_sign_quality)
    factors.append(
        {
            "label": "Moon",
            "detail": (
                f"Moon: {phase_name} phase → {_format_qualities(phase_quality)}; "
                f"in {moon_sign} ({sign_element(moon_sign)}) → {_format_qualities(moon_sign_quality)}"
            ),
        }
    )

    # Significator 5 — the season (Sun's quadrant).
    sun_sign = planets["Sun"]["sign"]
    season_name, season_quality = season(sun_longitude)
    add(season_quality)
    factors.append(
        {
            "label": "Season",
            "detail": f"Season: {season_name} (Sun in {sun_sign}) → {_format_qualities(season_quality)}",
        }
    )

    net_heat = hot - cold
    net_moisture = moist - dry
    temperament_name = _final_temperament_name(net_heat, net_moisture)
    primary_name = temperament_name.split("-")[0]
    description = TEMPERAMENT_DESCRIPTIONS[primary_name]

    return {
        "temperament": temperament_name,
        "qualities": TEMPERAMENT_QUALITIES[primary_name],
        "net_heat": net_heat,
        "net_moisture": net_moisture,
        "description": description["body"],
        "citation": description["citation"],
        "factors": factors,
    }
