"""AI-generated synthesis of a planet's placement, via the Anthropic API."""
import os

from anthropic import Anthropic
from dotenv import load_dotenv

load_dotenv()

_MODEL = "claude-haiku-4-5-20251001"

_DIGNITY_LABELS = {
    "domicile": "Domicile",
    "exaltation": "Exaltation",
    "detriment": "Detriment",
    "fall": "Fall",
}


class SynthesisError(Exception):
    pass


def _dignity_phrase(dignities: list[str]) -> str:
    if not dignities:
        return "peregrine (holding no essential dignity here)"
    labels = [_DIGNITY_LABELS.get(d, d) for d in dignities]
    return f"in {' and '.join(labels)}"


def _build_prompt(
    planet: str,
    sign: str,
    house: int,
    sect: str,
    dignities: list[str],
    aspects: list[str],
) -> str:
    aspects_text = "; ".join(aspects) if aspects else "none within orb"
    return (
        "You are a traditional astrologer working within the Hellenistic and classical tradition.\n"
        f"The native has {planet} in {sign} in House {house}, in a {sect} chart.\n"
        f"{planet} is {_dignity_phrase(dignities)}.\n"
        f"The following natal aspects involve this planet: {aspects_text}.\n\n"
        "Write a single paragraph of 3-4 sentences synthesizing what these placements mean together "
        "for this specific native. Ground your interpretation in classical significations. "
        'Use "the native" rather than "you". Do not mention modern psychological concepts. '
        "Write in the same tone as Vettius Valens and Claudius Ptolemy — direct, traditional, concrete."
    )


def generate_synthesis(
    planet: str,
    sign: str,
    house: int,
    sect: str,
    dignities: list[str],
    aspects: list[str],
) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise SynthesisError("ANTHROPIC_API_KEY is not configured")

    prompt = _build_prompt(planet, sign, house, sect, dignities, aspects)
    try:
        client = Anthropic(api_key=api_key)
        response = client.messages.create(
            model=_MODEL,
            max_tokens=300,
            messages=[{"role": "user", "content": prompt}],
        )
    except Exception as e:
        raise SynthesisError(str(e)) from e

    text = "".join(block.text for block in response.content if block.type == "text").strip()
    if not text:
        raise SynthesisError("Empty response from model")
    return text
