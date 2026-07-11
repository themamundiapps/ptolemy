"""AI-generated full natal chart reading, via the Anthropic API.

Distinct from services/synthesis.py (a single planet's placement, 3-4
sentences) -- this covers the whole chart in one 4-5 paragraph reading, and
is deliberately kept separate so each can be tuned/priced independently.
"""
import os

from anthropic import Anthropic
from dotenv import load_dotenv

load_dotenv()

_MODEL = "claude-haiku-4-5-20251001"
_MAX_TOKENS = 1000

SYSTEM_PROMPT = (
    "You are a traditional astrologer working strictly within the Hellenistic and Renaissance "
    "tradition — Ptolemy, Vettius Valens, and William Lilly. You write in clear, direct English "
    "prose. You do not use modern psychological jargon. You refer to the native in the third "
    'person ("the native"). You ground every observation in the planetary positions, dignities, '
    "and configurations provided."
)

# Traditional glyphs, used only for compact readability inside the prompt
# text sent to the model -- not subject to the Astronomicon font-mapping
# constraint that applies to on-screen Flutter Text widgets.
_ASPECT_SYMBOLS = {
    "conjunction": "☌",
    "sextile": "⚹",
    "square": "□",
    "trine": "△",
    "opposition": "☍",
}


class AnalysisError(Exception):
    pass


def _dignity_label(dignities: list[str]) -> str:
    if not dignities:
        return "Peregrine"
    return " & ".join(d.capitalize() for d in dignities)


def build_analysis_prompt(
    *,
    ascendant_sign: str,
    midheaven_sign: str,
    season: str,
    sect: str,
    temperament_label: str,
    planets: list[dict],
    house_lord_lines: list[str],
    aspects: list[dict],
    fortune_sign: str,
    fortune_house: int,
    spirit_sign: str,
    spirit_house: int,
) -> str:
    """planets: [{"name", "sign", "house", "dignities", "orientation"}, ...].
    aspects: [{"planet_a", "planet_b", "aspect", "orb"}, ...]."""
    planet_lines = [
        f"{p['name']} — {p['sign']} — House {p['house']} — {_dignity_label(p['dignities'])} — {p['orientation']}"
        for p in planets
    ]
    aspect_lines = [
        f"{a['planet_a']} {_ASPECT_SYMBOLS.get(a['aspect'], a['aspect'])} {a['planet_b']} — orb {a['orb']:.1f}°"
        for a in aspects
    ] or ["None within orb."]

    return (
        "Cast a traditional natal chart reading for the following nativity.\n\n"
        f"Ascendant: {ascendant_sign}\n"
        f"Midheaven: {midheaven_sign}\n"
        f"Season of birth: {season}\n"
        f"Sect: {sect}\n"
        f"Temperament: {temperament_label}\n\n"
        "Planets:\n" + "\n".join(planet_lines) + "\n\n"
        "House Lords:\n" + "\n".join(house_lord_lines) + "\n\n"
        "Major Aspects:\n" + "\n".join(aspect_lines) + "\n\n"
        f"Lot of Fortune: {fortune_sign} — House {fortune_house}\n"
        f"Lot of Spirit: {spirit_sign} — House {spirit_house}\n\n"
        "Write a 4-5 paragraph reading covering:\n"
        "1. The overall chart signature — what kind of nativity is this?\n"
        "2. The dominant planets and their themes\n"
        "3. Areas of natural strength\n"
        "4. Areas of challenge or difficulty\n"
        "5. The fundamental nature of the native according to the Ptolemaic tradition\n\n"
        "Write in the voice of a traditional astrologer. Be specific to this chart — do not give "
        "generic descriptions."
    )


def generate_analysis(user_prompt: str) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise AnalysisError("ANTHROPIC_API_KEY is not configured")

    try:
        client = Anthropic(api_key=api_key)
        response = client.messages.create(
            model=_MODEL,
            max_tokens=_MAX_TOKENS,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_prompt}],
        )
    except Exception as e:
        raise AnalysisError(str(e)) from e

    text = "".join(block.text for block in response.content if block.type == "text").strip()
    if not text:
        raise AnalysisError("Empty response from model")
    return text
