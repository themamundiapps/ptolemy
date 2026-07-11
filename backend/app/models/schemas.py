from pydantic import BaseModel, Field


class ChartRequest(BaseModel):
    date: str = Field(..., description="Birth date, format YYYY-MM-DD", examples=["1990-06-15"])
    time: str = Field(..., description="Birth time (local to tz_offset), format HH:MM (24h)", examples=["14:30"])
    latitude: float = Field(..., ge=-90, le=90, description="Latitude in decimal degrees, north positive")
    longitude: float = Field(..., ge=-180, le=180, description="Longitude in decimal degrees, east positive")
    tz_offset: float | None = Field(
        None,
        description=(
            "Manual UTC offset override in hours, e.g. -5 for EST. "
            "If omitted, the historically-accurate offset is resolved automatically "
            "from latitude/longitude and the birth date."
        ),
    )


class CityResult(BaseModel):
    name: str
    latitude: float
    longitude: float


class GeocodeResponse(BaseModel):
    results: list[CityResult]


class ZodiacPosition(BaseModel):
    longitude: float
    sign: str
    sign_longitude: float
    house: int
    retrograde: bool = False
    dignities: list[str] = Field(default_factory=list)


class Aspect(BaseModel):
    planet_a: str
    planet_b: str
    aspect: str
    angle: float
    orb: float


class ChartResponse(BaseModel):
    julian_day_ut: float
    sect: str
    timezone_id: str | None
    utc_offset_used: float
    tz_source: str
    ascendant: ZodiacPosition
    midheaven: ZodiacPosition
    planets: dict[str, ZodiacPosition]
    lot_of_fortune: ZodiacPosition
    lot_of_spirit: ZodiacPosition
    aspects: list[Aspect]


class HouseLordEntry(BaseModel):
    house_number: int
    sign: str
    lord: str
    lord_house: int
    lord_sign: str
    lord_dignity: str | None = None
    interpretation_key: str


class HouseLordsResponse(BaseModel):
    entries: list[HouseLordEntry]


class InterpretationResponse(BaseModel):
    body: str
    citation: str


class SynthesisRequest(BaseModel):
    planet: str
    sign: str
    house: int
    sect: str
    dignities: list[str] = Field(default_factory=list)
    aspects: list[str] = Field(default_factory=list)


class SynthesisResponse(BaseModel):
    synthesis: str


class TemperamentFactor(BaseModel):
    label: str
    detail: str


class TemperamentResponse(BaseModel):
    temperament: str
    qualities: str
    net_heat: int
    net_moisture: int
    description: str
    citation: str
    factors: list[TemperamentFactor]


class TemperamentExpandedSection(BaseModel):
    text: str
    citation: str = ""


class TemperamentExpandedRecommendations(BaseModel):
    text: str


class TemperamentExpandedResponse(BaseModel):
    temperament: str
    health_tendencies: TemperamentExpandedSection
    traditional_recommendations: TemperamentExpandedRecommendations


class ElectionalRequest(BaseModel):
    date: str = Field(..., description="Natal birth date, format YYYY-MM-DD")
    time: str = Field(..., description="Natal birth time, format HH:MM (24h)")
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    tz_offset: float | None = Field(None, description="Manual UTC offset override for the natal data")
    start_date: str = Field(..., description="Scan period start, format YYYY-MM-DD")
    end_date: str = Field(..., description="Scan period end (inclusive), format YYYY-MM-DD")
    theme: str = Field(..., description="One of the electional theme keys")


class ElectionalHit(BaseModel):
    planet: str
    house: int
    house_name: str
    aspect: str
    mode: str
    orb: float
    score: float
    is_supporting: bool
    is_cazimi: bool


class ElectionalDay(BaseModel):
    date: str
    best_time: str
    quality_label: str
    reasons: list[str]
    hits: list[ElectionalHit]


class ElectionalResponse(BaseModel):
    theme: str
    theme_label: str
    banner: str | None = None
    note: str | None = None
    days: list[ElectionalDay]


class UserChartSaveRequest(BaseModel):
    google_id: str
    city_name: str
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    date: str = Field(..., description="Birth date, format YYYY-MM-DD")
    time: str = Field(..., description="Birth time, format HH:MM (24h)")
    tz_offset: float | None = None


class UserChartResponse(BaseModel):
    city_name: str
    latitude: float
    longitude: float
    date: str
    time: str
    tz_offset: float | None = None
