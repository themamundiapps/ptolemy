# Ptolemy App — Temperament Calculation Algorithm
## Source: Claudius Ptolemy, Tetrabiblos, Book I (Chapters 4, 8) and Book III (Chapter 11)
## Pure Ptolemaic method — no adaptations, no hybrid sources

---

## Overview

The temperament is determined by collecting qualities — **Hot, Cold, Moist, Dry** — from four significators. The combination that accumulates the most testimonies determines the final temperament:

| Heat + Moisture | → | **Sanguine**   |
|---|---|---|
| Heat + Dryness  | → | **Choleric**   |
| Cold + Moisture | → | **Phlegmatic** |
| Cold + Dryness  | → | **Melancholic** |

---

## Step 1 — Determine Oriental or Occidental for each planet

Ptolemy explicitly states that planet qualities differ depending on whether the planet is a morning star (Oriental) or evening star (Occidental):

*"The planets, in oriental aspects only, are more productive of moisture from rising to their first station, of heat from first station to evening rising..."* — Tetrabiblos, Book I, Chapter 8

**Calculation:**
```
difference = (planet_longitude - sun_longitude + 360) % 360
if difference < 180: planet is ORIENTAL (morning star, precedes Sun)
if difference >= 180: planet is OCCIDENTAL (evening star, follows Sun)
```

Apply to: Saturn, Jupiter, Mars, Venus, Mercury.

---

## Step 2 — Quality of each planet

Directly from Ptolemy, Tetrabiblos Book I, Chapters 4 and 11:

| Planet | Oriental | Occidental |
|---|---|---|
| Saturn | Cold & Moist | Cold & Dry |
| Jupiter | Hot & Moist | Moist (Hot reduced) |
| Mars | Hot & Dry | Dry (Hot reduced) |
| Venus | Hot & Moist | Hot & Moist (primarily Moist) |
| Mercury | Hot | Dry |
| Sun | Hot & Dry | Hot & Dry (constant) |

**Implementation note for Jupiter and Mars Occidental:**
When Occidental, Jupiter contributes only Moist (not Hot), and Mars contributes only Dry (not Hot). This reflects Ptolemy's text directly.

---

## Step 3 — Moon phase qualities

Directly from Ptolemy, Tetrabiblos Book I, Chapter 8:

*"In its waxing from new moon to first quarter the moon is more productive of moisture; in its passage from first quarter to full, of heat; from full to last quarter, of dryness, and from last quarter to occultation, of cold."*

**Calculation:**
```
moon_phase_angle = (moon_longitude - sun_longitude + 360) % 360

0° – 90°:   Moist  (New Moon to First Quarter)
90° – 180°: Hot    (First Quarter to Full Moon)
180° – 270°: Dry   (Full Moon to Last Quarter)
270° – 360°: Cold  (Last Quarter to New Moon)
```

---

## Step 4 — Sign qualities

Directly from Ptolemy, Tetrabiblos Book I:

| Sign | Element | Quality |
|---|---|---|
| Aries, Leo, Sagittarius | Fire | Hot & Dry |
| Taurus, Virgo, Capricorn | Earth | Cold & Dry |
| Gemini, Libra, Aquarius | Air | Hot & Moist |
| Cancer, Scorpio, Pisces | Water | Cold & Moist |

---

## Step 5 — Season (quadrant of the Sun)

Directly from Ptolemy, Tetrabiblos Book III, Chapter 11:

*"The quadrant from the spring equinox to the summer solstice makes subjects exceeding in the moist and warm. The quadrant from the summer solstice to the autumn equinox produces individuals exceeding in the warm and dry. The quadrant from the autumn equinox to the winter solstice makes them exceeding in the dry and cold. The quadrant from the winter solstice to the spring equinox produces individuals exceeding in the cold and moist."*

| Sun's longitude | Season | Quality |
|---|---|---|
| 0° – 90° (Aries to Cancer) | Spring | Hot & Moist |
| 90° – 180° (Cancer to Libra) | Summer | Hot & Dry |
| 180° – 270° (Libra to Capricorn) | Autumn | Cold & Dry |
| 270° – 360° (Capricorn to Aries) | Winter | Cold & Moist |

---

## Step 6 — The Four Significators

Directly from Ptolemy, Tetrabiblos Book III, Chapter 11:

*"We must, then, in general observe the eastern horizon and the planets that are upon it or assume its rulership... and in particular also the moon as well; for it is through the formative power of these two places and of their rulers and through the mixture of the two kinds that the conformation of the body is ascertained."*

### Significator 1 — The Ascending Sign
Take the quality of the Ascending sign (from Step 4).
**Weight: 1 testimony per quality.**

### Significator 2 — Planets in the Ascending Sign (House 1 in Whole Sign)
For each planet physically located in the Ascending sign:
- Apply that planet's quality based on Oriental/Occidental (Step 2)
- Apply the quality of the sign that planet is in — which is the Ascending sign itself (Step 4)

**Weight: 1 testimony per quality per planet.**

### Significator 3 — Ruler of the Ascending Sign
Take the planet that rules the Ascending sign (traditional domicile rulers only):
- Apply that planet's quality based on Oriental/Occidental (Step 2)
- Apply the quality of the sign the ruler is currently occupying (Step 4)

**Weight: 1 testimony per quality.**

### Significator 4 — The Moon
- Apply the Moon's phase quality (Step 3)
- Apply the quality of the sign the Moon occupies (Step 4)

**Weight: 1 testimony per quality.**

### Significator 5 — The Season
Apply the seasonal quality based on the Sun's position (Step 5).
**Weight: 1 testimony.**

---

## Step 7 — Collect and count all testimonies

Create four counters: `hot`, `cold`, `moist`, `dry`.

Go through each significator and add its qualities to the appropriate counters.

**Cancellation rule (Ptolemy):** Hot and Cold are opposing — they cancel each other. Moist and Dry are opposing — they cancel each other.

After collecting all testimonies:
```
net_heat     = hot - cold    (positive = net Hot; negative = net Cold)
net_moisture = moist - dry   (positive = net Moist; negative = net Dry)
```

---

## Step 8 — Determine final temperament

```
if net_heat > 0 and net_moisture > 0:    SANGUINE   (Hot & Moist)
if net_heat > 0 and net_moisture <= 0:   CHOLERIC   (Hot & Dry)
if net_heat <= 0 and net_moisture > 0:   PHLEGMATIC (Cold & Moist)
if net_heat <= 0 and net_moisture <= 0:  MELANCHOLIC (Cold & Dry)
```

**Mixed temperaments:** When the margin in either dimension is 1 point, report a mixed temperament — the dominant quality first, the secondary second. Example: "Sanguine-Choleric" means Hot dominates strongly but Moist only barely edges out Dry. This reflects Ptolemy's own acknowledgment that temperaments are mixtures, not absolutes.

---

## Step 9 — Output for the user

Display:
1. **Final temperament** (e.g. "Sanguine" or "Sanguine-Choleric")
2. **Quality scores** — net Hot/Cold and net Moist/Dry before cancellation, so the user sees the margins
3. **Factor breakdown** — each significator listed with its contribution:
   - Ascending sign: [sign] → [quality]
   - Planets in Ascendant: [planet] ([Oriental/Occidental]) in [sign] → [quality]
   - Ruler of Ascendant: [planet] ([Oriental/Occidental]) in [sign] → [quality]
   - Moon: phase [phase name] → [quality] + in [sign] → [quality]
   - Season: [season] → [quality]

---

## Temperament descriptions (for display to user)

**Sanguine — Hot & Moist**
The Sanguine temperament is governed by air and blood. The native tends toward cheerfulness, generosity, and a natural ease in social life — the hot quality gives energy and initiative, while the moist quality gives adaptability and a pleasant, yielding disposition. The body tends toward good color, flesh, and vitality. Ptolemy associates this temperament with the quadrant of spring, when the ambient both warms and humidifies.

*"Two of the four humours are fertile and active — the hot and the moist — for all things are brought together and increased by them."*
— Claudius Ptolemy, Tetrabiblos, Book I

---

**Choleric — Hot & Dry**
The Choleric temperament is governed by fire and yellow bile. The native tends toward boldness, ambition, quickness to anger, and a restless, driving energy — the hot quality gives force and initiative, while the dry quality gives sharpness and a capacity for sustained effort without the softening influence of moisture. The body tends toward leanness, intensity, and heat. Ptolemy associates this temperament with the quadrant of summer, when the sun's heat is greatest and its drying power most pronounced.

*"The nature of Mars is chiefly to dry and to burn, in conformity with his fiery colour and by reason of his nearness to the sun."*
— Claudius Ptolemy, Tetrabiblos, Book I

---

**Phlegmatic — Cold & Moist**
The Phlegmatic temperament is governed by water and phlegm. The native tends toward passivity, adaptability, a yielding and patient disposition, and a difficulty with sustained initiative or decisive action — the cold quality slows and contracts, while the moist quality gives flexibility and a tendency to take the shape of surrounding circumstances. The body tends toward pallor, softness, and a susceptibility to cold and damp complaints. Ptolemy associates this temperament with winter, when cold and moisture both predominate.

*"Saturn's quality is chiefly to cool and to moisten rarely, probably because he is furthest removed both from the sun's heat and the moist exhalations about the earth."*
— Claudius Ptolemy, Tetrabiblos, Book I

---

**Melancholic — Cold & Dry**
The Melancholic temperament is governed by earth and black bile. The native tends toward seriousness, depth of thought, caution, and a characteristic heaviness — the cold quality contracts and withdraws, while the dry quality hardens and fixes, producing a native who is persistent, self-contained, and oriented toward endurance rather than expansion. The body tends toward darkness, leanness, and a susceptibility to chronic, slow-developing conditions. Ptolemy associates this temperament with autumn, when the ambient cools and dries simultaneously.

*"Two of the four humours are destructive and passive — the dry and the cold — through which all things, again, are separated and destroyed."*
— Claudius Ptolemy, Tetrabiblos, Book I

---

## Summary of significators

| Significator | Source |
|---|---|
| Ascending sign quality | Sign element table |
| Planets in Ascendant | Planet oriental/occidental quality + sign quality |
| Ruler of Ascendant | Planet oriental/occidental quality + sign it occupies |
| Moon | Phase quality + sign quality |
| Season | Sun's quadrant |

---

*Source: Claudius Ptolemy, Tetrabiblos, Book I Chapters 4, 6, 7, 8 and Book III Chapter 11 (tr. J.M. Ashmand)*
*All planetary qualities, moon phases, seasonal quadrants, and sign qualities are quoted directly from the text.*
