"""Loads traditional planet-in-sign / planet-in-house / aspect-pair
interpretations from the project's content markdown files, and provides
general Lot descriptions."""
import re
from functools import lru_cache
from pathlib import Path

# Relative to the backend/ directory itself (not the repo root) -- Railway's
# build is scoped to backend/ (its configured root directory), so a path that
# reached above it via one more ".parent" would resolve to files that were
# never uploaded and silently fail to be found in production.
_CONTENT_DIR = Path(__file__).resolve().parent.parent.parent / "content"
_SIGNS_FILE = _CONTENT_DIR / "ptolemy-planets-in-signs.md"
_HOUSES_FILE = _CONTENT_DIR / "ptolemy-planets-in-houses.md"
_ASPECTS_FILE = _CONTENT_DIR / "ptolemy-aspects.md"
_ASPECTS_EXTENDED_FILE = _CONTENT_DIR / "ptolemy-aspects-extended.md"
_HOUSE_LORDS_FILE = _CONTENT_DIR / "ptolemy-house-lords.md"
_TEMPERAMENT_EXPANDED_FILE = _CONTENT_DIR / "ptolemy-temperament-expanded.md"

_SIGN_HEADER = re.compile(r"^\*\*.+ IN ([A-Z]+)\*\*$")
_HOUSE_HEADER = re.compile(r"^\*\*.+ IN HOUSE (\d+)\*\*$")
_PLANET_TOKEN = re.compile(r"^#\s+\S+\s+([A-Z]+)$")
_ASPECT_PAIR_HEADER = re.compile(r"^\*\*(.+?) — (.+?)\*\*$")
_ASPECT_SPECIFIC_HEADER = re.compile(r"^\*\*(.+?) ([☌⚹□△☍]) (.+?)\*\*$")
_QUOTE_LINE = re.compile(r'^\*"(.+)"\*$')
_CITATION_LINE = re.compile(r"^— (.+)$")
_HOUSE_LORD_ENTRY_HEADER = re.compile(r"^\*\*Lord of House (\d+) in House (\d+)\*\*$")
_HOUSE_LORD_SECTION_HEADER = re.compile(r"^# LORD OF HOUSE \d+$")
# Matches only the 10 pure/mixed temperament section headers ("# SANGUINE —
# ..." / "# SANGUINE-CHOLERIC — ...") -- the all-caps name requirement is
# what keeps this from also matching the file's mixed-case title header
# ("# Ptolemy App — Temperament Expanded Content").
_TEMPERAMENT_ENTRY_HEADER = re.compile(r"^# ([A-Z]+(?:-[A-Z]+)?) — .+$")
_TEMPERAMENT_HEALTH_HEADER = re.compile(r"^## Health Tendencies \(Free\)$")
_TEMPERAMENT_RECOMMENDATIONS_HEADER = re.compile(r"^## Traditional Recommendations \(Pro\)$")

# Only square/trine/opposition are ever present in ptolemy-aspects-extended.md
# (conjunction and sextile always use the base pair text) -- but the map
# covers all five for robustness rather than assuming the file's content.
_ASPECT_SYMBOL_TO_TYPE = {
    "☌": "conjunction",
    "⚹": "sextile",
    "□": "square",
    "△": "trine",
    "☍": "opposition",
}

# The four chart angles keep their bare uppercase form (ASC, not Asc) since
# that's exactly what the aspect-computation service and the frontend both
# use as the identifier — everything else (a planet name) is title-cased.
_ANGLE_NAMES = {"ASC", "DSC", "MC", "IC"}


class Interpretation:
    def __init__(self, body: str, citation: str):
        self.body = body
        self.citation = citation


def _parse(path: Path, header_re: re.Pattern, key_transform) -> dict:
    """Generic parser: walks the file, tracking the current '# <glyph> PLANET'
    section, then extracting each '**PLANET IN X**' entry's body paragraph,
    quote, and attribution into a single formatted citation string.
    """
    lines = path.read_text(encoding="utf-8").splitlines()
    results: dict = {}
    current_planet = None
    i = 0
    while i < len(lines):
        line = lines[i].strip()

        planet_match = _PLANET_TOKEN.match(line)
        if planet_match:
            current_planet = planet_match.group(1).title()
            i += 1
            continue

        header_match = header_re.match(line)
        if not header_match or current_planet is None:
            i += 1
            continue

        key_raw = header_match.group(1)
        i += 1

        body_lines = []
        while i < len(lines) and not _QUOTE_LINE.match(lines[i].strip()):
            stripped = lines[i].strip()
            if stripped:
                body_lines.append(stripped)
            i += 1
        body = " ".join(body_lines).strip()

        citation = ""
        if i < len(lines):
            quote_match = _QUOTE_LINE.match(lines[i].strip())
            quote_text = quote_match.group(1) if quote_match else ""
            i += 1
            while i < len(lines) and not lines[i].strip():
                i += 1
            if i < len(lines):
                citation_match = _CITATION_LINE.match(lines[i].strip())
                if citation_match:
                    citation = f'"{quote_text}" — {citation_match.group(1)}'
                    i += 1

        results[(current_planet, key_transform(key_raw))] = Interpretation(body, citation)

    return results


@lru_cache
def _sign_interpretations() -> dict:
    return _parse(_SIGNS_FILE, _SIGN_HEADER, lambda raw: raw.title())


@lru_cache
def _house_interpretations() -> dict:
    return _parse(_HOUSES_FILE, _HOUSE_HEADER, int)


def get_planet_in_sign(planet: str, sign: str) -> Interpretation | None:
    return _sign_interpretations().get((planet, sign))


def get_planet_in_house(planet: str, house: int) -> Interpretation | None:
    return _house_interpretations().get((planet, house))


def _normalize_planet_or_angle(raw: str) -> str:
    """A bare token (from either a markdown header or an API query param) to
    its canonical form: ASC/DSC/MC/IC stay upper-cased, everything else
    (a planet name) is title-cased -- 'sun', 'SUN', and 'Sun' all resolve
    to the same key."""
    token = raw.strip()
    return token.upper() if token.upper() in _ANGLE_NAMES else token.title()


def _aspect_pair_key(side_a: str, side_b: str) -> frozenset:
    """Pairs are looked up regardless of which side was listed first, so the
    lookup key doesn't preserve order — Venus-Saturn and Saturn-Venus are the
    same entry."""
    return frozenset({_normalize_planet_or_angle(side_a), _normalize_planet_or_angle(side_b)})


@lru_cache
def _aspect_pair_interpretations() -> dict:
    """Parses ptolemy-aspects.md's 49 '**A — B**' pair entries. Structurally
    similar to _parse() above (header -> body paragraph -> quote -> citation)
    but each entry is fully self-contained (no running 'current planet'
    section state to track), and the header itself supplies both sides of
    the key directly rather than combining a section header with a per-entry
    suffix.
    """
    lines = _ASPECTS_FILE.read_text(encoding="utf-8").splitlines()
    results: dict = {}
    i = 0
    while i < len(lines):
        line = lines[i].strip()

        header_match = _ASPECT_PAIR_HEADER.match(line)
        if not header_match:
            i += 1
            continue

        # Each side is "<glyph> NAME" for a planet or bare "NAME" for an
        # angle -- the canonical identifier is always the last token.
        side_a = header_match.group(1).split()[-1]
        side_b = header_match.group(2).split()[-1]
        i += 1

        body_lines = []
        while i < len(lines) and not _QUOTE_LINE.match(lines[i].strip()):
            stripped = lines[i].strip()
            if stripped:
                body_lines.append(stripped)
            i += 1
        body = " ".join(body_lines).strip()

        citation = ""
        if i < len(lines):
            quote_match = _QUOTE_LINE.match(lines[i].strip())
            quote_text = quote_match.group(1) if quote_match else ""
            i += 1
            while i < len(lines) and not lines[i].strip():
                i += 1
            if i < len(lines):
                citation_match = _CITATION_LINE.match(lines[i].strip())
                if citation_match:
                    citation = f'"{quote_text}" — {citation_match.group(1)}'
                    i += 1

        results[_aspect_pair_key(side_a, side_b)] = Interpretation(body, citation)

    return results


@lru_cache
def _extended_aspect_interpretations() -> dict:
    """Parses ptolemy-aspects-extended.md's square/trine/opposition entries,
    e.g. '**Venus △ Saturn**' followed by a single body paragraph (no quote
    or citation -- these passages are original, not sourced quotations).
    Unlike the base pair headers, each side here is already a bare name with
    no glyph prefix, and the aspect symbol sits directly between them, so
    header and aspect type are extracted from one regex match rather than
    needing separate section-header tracking. Pairs with no square/trine/
    opposition entries at all (Sun-Mercury, Sun-Venus -- astronomically
    impossible at those aspects) are simply absent from the result, which is
    exactly the fallback-to-base-text behavior that's wanted for them.
    """
    lines = _ASPECTS_EXTENDED_FILE.read_text(encoding="utf-8").splitlines()
    results: dict = {}
    i = 0
    while i < len(lines):
        line = lines[i].strip()

        header_match = _ASPECT_SPECIFIC_HEADER.match(line)
        if not header_match:
            i += 1
            continue

        side_a, symbol, side_b = header_match.group(1), header_match.group(2), header_match.group(3)
        aspect_type = _ASPECT_SYMBOL_TO_TYPE[symbol]
        i += 1

        body_lines = []
        while i < len(lines) and lines[i].strip():
            body_lines.append(lines[i].strip())
            i += 1
        body = " ".join(body_lines).strip()

        results[(_aspect_pair_key(side_a, side_b), aspect_type)] = Interpretation(body, citation="")

    return results


def get_aspect_interpretation(planet_a: str, planet_b: str, aspect_type: str) -> Interpretation | None:
    """The square/trine/opposition-specific passage when one exists for this
    exact pair and aspect type, otherwise the base pair interpretation
    (which is also what conjunction and sextile always use)."""
    pair_key = _aspect_pair_key(planet_a, planet_b)
    specific = _extended_aspect_interpretations().get((pair_key, aspect_type.lower()))
    if specific is not None:
        return specific
    return _aspect_pair_interpretations().get(pair_key)


@lru_cache
def _house_lord_interpretations() -> dict:
    """Parses ptolemy-house-lords.md's 144 '**Lord of House X in House Y**'
    entries. Unlike the other content files, only a representative entry per
    house-section carries a quote/citation (37 of 144) -- the rest are a bare
    body paragraph followed directly by the next entry or a '---' rule, with
    no quote line to signal the end of the body. So unlike _parse()'s body
    loop (which only stops at a quote line, safe there because every entry in
    those files has one), this loop must also stop at the next entry header,
    the next section header, or a '---' rule.
    """
    lines = _HOUSE_LORDS_FILE.read_text(encoding="utf-8").splitlines()
    results: dict = {}
    i = 0
    while i < len(lines):
        line = lines[i].strip()

        header_match = _HOUSE_LORD_ENTRY_HEADER.match(line)
        if not header_match:
            i += 1
            continue

        from_house = int(header_match.group(1))
        to_house = int(header_match.group(2))
        i += 1

        body_lines = []
        while i < len(lines):
            stripped = lines[i].strip()
            if (
                stripped == "---"
                or _QUOTE_LINE.match(stripped)
                or _HOUSE_LORD_ENTRY_HEADER.match(stripped)
                or _HOUSE_LORD_SECTION_HEADER.match(stripped)
            ):
                break
            if stripped:
                body_lines.append(stripped)
            i += 1
        body = " ".join(body_lines).strip()

        citation = ""
        if i < len(lines) and _QUOTE_LINE.match(lines[i].strip()):
            quote_match = _QUOTE_LINE.match(lines[i].strip())
            quote_text = quote_match.group(1)
            i += 1
            while i < len(lines) and not lines[i].strip():
                i += 1
            if i < len(lines):
                citation_match = _CITATION_LINE.match(lines[i].strip())
                if citation_match:
                    citation = f'"{quote_text}" — {citation_match.group(1)}'
                    i += 1

        results[(from_house, to_house)] = Interpretation(body, citation)

    return results


def get_house_lord_interpretation(from_house: int, to_house: int) -> Interpretation | None:
    return _house_lord_interpretations().get((from_house, to_house))


class TemperamentExpandedEntry:
    def __init__(self, health_text: str, health_citation: str, recommendations_text: str):
        self.health_text = health_text
        self.health_citation = health_citation
        self.recommendations_text = recommendations_text


@lru_cache
def _temperament_expanded_entries() -> dict:
    """Parses ptolemy-temperament-expanded.md's 10 entries (4 pure + 6 mixed
    temperaments). Each entry has a Health Tendencies body (1-2 paragraphs,
    plus an optional quote/citation -- only 8 of 10 entries carry one) and a
    Traditional Recommendations body (several '**Label:** text' paragraphs).
    Paragraphs are joined with blank lines rather than flattened to a single
    line (unlike this module's other parsers) because both sections are
    genuinely multi-paragraph prose meant to read as separate paragraphs, and
    the Recommendations body's '**Label:**' prefixes are what the Flutter
    side splits on to render each sub-section's own gold-caps header.
    """
    lines = _TEMPERAMENT_EXPANDED_FILE.read_text(encoding="utf-8").splitlines()
    results: dict = {}
    i = 0
    while i < len(lines):
        line = lines[i].strip()

        entry_match = _TEMPERAMENT_ENTRY_HEADER.match(line)
        if not entry_match:
            i += 1
            continue

        temperament_key = entry_match.group(1)
        i += 1

        while i < len(lines) and not _TEMPERAMENT_HEALTH_HEADER.match(lines[i].strip()):
            i += 1
        i += 1  # past the "## Health Tendencies (Free)" header itself

        health_paragraphs = []
        health_citation = ""
        while i < len(lines):
            stripped = lines[i].strip()
            if (
                stripped == "---"
                or _TEMPERAMENT_RECOMMENDATIONS_HEADER.match(stripped)
                or _TEMPERAMENT_ENTRY_HEADER.match(stripped)
            ):
                break
            quote_match = _QUOTE_LINE.match(stripped)
            if quote_match:
                quote_text = quote_match.group(1)
                i += 1
                while i < len(lines) and not lines[i].strip():
                    i += 1
                if i < len(lines):
                    citation_match = _CITATION_LINE.match(lines[i].strip())
                    if citation_match:
                        health_citation = f'"{quote_text}" — {citation_match.group(1)}'
                        i += 1
                continue
            if stripped:
                health_paragraphs.append(stripped)
            i += 1
        health_text = "\n\n".join(health_paragraphs)

        while (
            i < len(lines)
            and not _TEMPERAMENT_RECOMMENDATIONS_HEADER.match(lines[i].strip())
            and not _TEMPERAMENT_ENTRY_HEADER.match(lines[i].strip())
        ):
            i += 1

        recommendations_paragraphs = []
        if i < len(lines) and _TEMPERAMENT_RECOMMENDATIONS_HEADER.match(lines[i].strip()):
            i += 1  # past the "## Traditional Recommendations (Pro)" header itself
            while i < len(lines):
                stripped = lines[i].strip()
                if stripped == "---" or _TEMPERAMENT_ENTRY_HEADER.match(stripped):
                    break
                if stripped:
                    recommendations_paragraphs.append(stripped)
                i += 1
        recommendations_text = "\n\n".join(recommendations_paragraphs)

        results[temperament_key] = TemperamentExpandedEntry(health_text, health_citation, recommendations_text)

    return results


def get_temperament_expanded(temperament: str) -> TemperamentExpandedEntry | None:
    return _temperament_expanded_entries().get(temperament.strip().upper())


# No dedicated content file for the Lots — general traditional descriptions,
# combined with the specific sign/house at request time.
_LOT_GENERAL_TEXT = {
    "fortune": (
        "The Lot of Fortune is the ancient marker of the body, health, and material "
        "circumstance — the portion of fate tied most closely to livelihood, chance "
        "events, and the native's physical experience of life. Where it falls shows "
        "the house and sign through which fortune, in the plainest sense, most often "
        "moves for this native."
    ),
    "spirit": (
        "The Lot of Spirit is the ancient marker of will, action, and the native's own "
        "initiative — the portion of fate tied to what the native does rather than "
        "what befalls them. Where it falls shows the house and sign through which "
        "purposeful action and reputation most often move for this native."
    ),
}


def get_lot_interpretation(lot: str, sign: str, house: int) -> Interpretation:
    lot_key = lot.lower()
    general = _LOT_GENERAL_TEXT.get(lot_key, "")
    body = f"{general} In this nativity it falls in {sign}, in house {house}."
    return Interpretation(body=body, citation="")
