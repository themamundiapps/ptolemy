"""AI-generated traditional synastry reading for two nativities, via the
Anthropic API. Mirrors services/analysis.py's structure (prompt builder +
generate function kept separate and independently testable) but covers two
charts, their house overlays, and the inter-aspects between them instead of
one chart alone.
"""
import os

from anthropic import Anthropic
from dotenv import load_dotenv

load_dotenv()

_MODEL = "claude-haiku-4-5-20251001"
_MAX_TOKENS = 1000

SYSTEM_PROMPT = (
    "You are a traditional astrologer working in the Hellenistic tradition — Ptolemy and Vettius "
    "Valens. You write in clear, direct English prose. You do not use modern psychological jargon "
    'or pop astrology language like "soulmates" or "twin flames". You refer to the two people as '
    '"the first native" and "the second native". You ground every observation in the planetary '
    "placements and aspects provided."
)

# Traditional glyphs, used only for compact readability inside the prompt
# text sent to the model -- see services/analysis.py for why this isn't the
# same mapping used by the Flutter chart wheel.
_ASPECT_SYMBOLS = {
    "conjunction": "☌",
    "sextile": "⚹",
    "square": "□",
    "trine": "△",
    "opposition": "☍",
}


class SynastryError(Exception):
    pass


def _dignity_label(dignities: list[str]) -> str:
    if not dignities:
        return "Peregrine"
    return " & ".join(d.capitalize() for d in dignities)


def _native_block(label: str, name: str, asc_sign: str, temperament_label: str, planets: list[dict]) -> str:
    """planets: [{"name", "sign", "house", "dignities"}, ...]."""
    planet_lines = [
        f"{p['name']} — {p['sign']} — House {p['house']} — {_dignity_label(p['dignities'])}" for p in planets
    ]
    return (
        f"{label}: {name}\n"
        f"Ascendant: {asc_sign} · Temperament: {temperament_label}\n"
        "Planets:\n" + "\n".join(planet_lines)
    )


def build_synastry_prompt(
    *,
    name_a: str,
    asc_sign_a: str,
    temperament_a: str,
    planets_a: list[dict],
    name_b: str,
    asc_sign_b: str,
    temperament_b: str,
    planets_b: list[dict],
    house_overlays: list[dict],
    inter_aspects: list[dict],
    angle_aspects: list[dict],
) -> str:
    """house_overlays: [{"planet", "from_chart", "house"}, ...], where
    from_chart is "A" or "B" -- whose planet it is, falling into the *other*
    native's house.
    inter_aspects: [{"planet_a", "planet_b", "aspect", "orb"}, ...], planet-to-
    planet only, planet_a from native A and planet_b from native B.
    angle_aspects: [{"planet", "from_chart", "angle_name", "aspect", "orb"}, ...],
    a native's planet against the *other* native's ASC or MC -- from_chart is
    "A" or "B", whichever native the planet (not the angle) belongs to.
    Neither list needs to be pre-sorted; order here is display order only.
    """
    overlay_lines = [
        f"{o['planet']} (of {name_a if o['from_chart'] == 'A' else name_b}) falls in House {o['house']} "
        f"of {name_b if o['from_chart'] == 'A' else name_a}"
        for o in house_overlays
    ]

    aspect_lines = [
        f"{a['planet_a']} ({name_a}) {_ASPECT_SYMBOLS.get(a['aspect'], a['aspect'])} {a['planet_b']} ({name_b}) "
        f"— orb {a['orb']:.1f}°"
        for a in inter_aspects
    ] or ["None within orb."]

    angle_lines = [
        f"{a['planet']} ({name_a if a['from_chart'] == 'A' else name_b}) "
        f"{_ASPECT_SYMBOLS.get(a['aspect'], a['aspect'])} {a['angle_name']} of "
        f"{name_b if a['from_chart'] == 'A' else name_a} — orb {a['orb']:.1f}°"
        for a in angle_aspects
    ] or ["None within orb."]

    return (
        "Cast a traditional synastry reading for the following two nativities.\n\n"
        + _native_block("First native", name_a, asc_sign_a, temperament_a, planets_a)
        + "\n\n"
        + _native_block("Second native", name_b, asc_sign_b, temperament_b, planets_b)
        + "\n\n"
        "House overlays:\n" + "\n".join(overlay_lines) + "\n\n"
        "Inter-aspects (planet to planet):\n" + "\n".join(aspect_lines) + "\n\n"
        "Inter-aspects (planets to angles):\n" + "\n".join(angle_lines) + "\n\n"
        "Pay particular attention to any aspects involving the Ascendant or Midheaven of either "
        "native — these are traditionally among the most significant indicators of how the two "
        "people experience each other.\n\n"
        "Write a 4-5 paragraph reading covering:\n"
        "1. The overall compatibility signature — what kind of connection is this?\n"
        "2. The strongest points of harmony\n"
        "3. The main points of tension or friction\n"
        "4. What each native brings to the relationship\n"
        "5. A summary of the traditional prognosis for this connection\n\n"
        "Write in the voice of a traditional astrologer. Be specific to these charts."
    )


def generate_synastry_analysis(user_prompt: str) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise SynastryError("ANTHROPIC_API_KEY is not configured")

    try:
        client = Anthropic(api_key=api_key)
        response = client.messages.create(
            model=_MODEL,
            max_tokens=_MAX_TOKENS,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_prompt}],
        )
    except Exception as e:
        raise SynastryError(str(e)) from e

    text = "".join(block.text for block in response.content if block.type == "text").strip()
    if not text:
        raise SynastryError("Empty response from model")
    return text
