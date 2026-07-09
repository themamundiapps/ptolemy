"""City search / geocoding via OpenStreetMap Nominatim."""
from geopy.geocoders import Nominatim

_geolocator = Nominatim(user_agent="ptolemy-astrology-app", timeout=5)


def search_cities(query: str, limit: int = 8) -> list[dict]:
    locations = _geolocator.geocode(query, exactly_one=False, limit=limit)
    if not locations:
        return []
    return [
        {"name": loc.address, "latitude": loc.latitude, "longitude": loc.longitude}
        for loc in locations
    ]
