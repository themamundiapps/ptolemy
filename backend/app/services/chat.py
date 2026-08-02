"""Conversational Q&A over a single nativity, via the Anthropic API. Unlike
services/analysis.py (one-shot 4-5 paragraph reading), this holds a running
conversation -- the full chart is restated as system-prompt context on every
call since the Anthropic API is stateless, and the client-supplied message
history carries the turn-by-turn conversation itself.
"""
import os

from anthropic import Anthropic
from dotenv import load_dotenv

load_dotenv()

_MODEL = "claude-haiku-4-5-20251001"
_MAX_TOKENS = 600

SYSTEM_PROMPT = (
    "You are a traditional astrologer trained in the Hellenistic tradition of Ptolemy and Vettius "
    "Valens. You have access to the user's full natal chart. Answer questions about their chart in "
    "clear, direct English. Ground every answer in the planetary positions provided. Do not use "
    "modern psychological jargon. Do not mention modern planets (Uranus, Neptune, Pluto). Refer to "
    'the user in the second person ("your chart shows...").'
)

# Appended after the chart context (never spliced into SYSTEM_PROMPT itself)
# for "plain" and "traditional" only -- "standard" is the default register
# SYSTEM_PROMPT was already written and calibrated for, so its prompt stays
# byte-for-byte what it was before `depth` existed. Each block governs
# REGISTER ONLY: identical doctrine, identical facts drawn from the chart
# context above it -- neither may add, omit, or soften an astrological claim
# the standard register wouldn't also make.
REGISTER_BLOCKS = {
    "plain": (
        "Register: PLAIN. The reader is new to astrology. When you use a technical term (a dignity, an "
        "aspect name, a lot, a house condition), briefly explain it in the same sentence or the next one "
        "-- don't assume it's already understood, and don't silently drop it either. Do not compensate "
        "for the plain-language explanations by thinning out the astrology itself: this is still a "
        "grounded reading of this specific chart, not a generic horoscope. Every claim must still trace "
        "to a specific placement, dignity, or aspect in the context above."
    ),
    "traditional": (
        "Register: TRADITIONAL. The reader already reads Lilly and is fluent in the tradition's "
        "vocabulary. Use technical terms precisely and without explaining them -- peregrine, cazimi, "
        "mutual reception, combustion, and the like need no gloss. You may cite the classical sources "
        "(Ptolemy, Valens, Lilly, Firmicus) by name where it strengthens the point. Do not pad the "
        "answer with beginner-level exposition it doesn't need."
    ),
}

_ASPECT_SYMBOLS = {
    "conjunction": "☌",
    "sextile": "⚹",
    "square": "□",
    "trine": "△",
    "opposition": "☍",
}


class ChatError(Exception):
    pass


def _dignity_label(dignities: list[str]) -> str:
    if not dignities:
        return "Peregrine"
    return " & ".join(d.capitalize() for d in dignities)


def build_chart_context(
    *,
    ascendant_sign: str,
    midheaven_sign: str,
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
    """planets: [{"name", "sign", "house", "dignities"}, ...].
    aspects: [{"planet_a", "planet_b", "aspect", "orb"}, ...]."""
    planet_lines = [f"{p['name']} — {p['sign']} — House {p['house']} — {_dignity_label(p['dignities'])}" for p in planets]
    aspect_lines = [
        f"{a['planet_a']} {_ASPECT_SYMBOLS.get(a['aspect'], a['aspect'])} {a['planet_b']} — orb {a['orb']:.1f}°"
        for a in aspects
    ] or ["None within orb."]

    return (
        f"Ascendant: {ascendant_sign}\n"
        f"Midheaven: {midheaven_sign}\n"
        f"Sect: {sect}\n"
        f"Temperament: {temperament_label}\n\n"
        "Planets:\n" + "\n".join(planet_lines) + "\n\n"
        "House Lords:\n" + "\n".join(house_lord_lines) + "\n\n"
        "Major Aspects:\n" + "\n".join(aspect_lines) + "\n\n"
        f"Lot of Fortune: {fortune_sign} — House {fortune_house}\n"
        f"Lot of Spirit: {spirit_sign} — House {spirit_house}"
    )


def generate_chat_reply(chart_context: str, messages: list[dict], depth: str = "standard") -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise ChatError("ANTHROPIC_API_KEY is not configured")

    system = f"{SYSTEM_PROMPT}\n\nContext:\n{chart_context}"
    register_block = REGISTER_BLOCKS.get(depth)
    if register_block:
        system = f"{system}\n\n{register_block}"

    try:
        client = Anthropic(api_key=api_key)
        response = client.messages.create(
            model=_MODEL,
            max_tokens=_MAX_TOKENS,
            system=system,
            messages=messages,
        )
    except Exception as e:
        raise ChatError(str(e)) from e

    text = "".join(block.text for block in response.content if block.type == "text").strip()
    if not text:
        raise ChatError("Empty response from model")
    return text
