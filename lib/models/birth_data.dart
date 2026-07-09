/// The inputs needed to recompute a natal chart -- persisted locally (guest
/// mode) and/or to the backend (signed-in Google users) so a returning app
/// open can skip the birth data form entirely.
class BirthData {
  final String cityName;
  final double latitude;
  final double longitude;
  final String date;
  final String time;
  final double? tzOffset;

  BirthData({
    required this.cityName,
    required this.latitude,
    required this.longitude,
    required this.date,
    required this.time,
    this.tzOffset,
  });

  factory BirthData.fromJson(Map<String, dynamic> json) => BirthData(
    cityName: json['city_name'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    date: json['date'] as String,
    time: json['time'] as String,
    tzOffset: (json['tz_offset'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'city_name': cityName,
    'latitude': latitude,
    'longitude': longitude,
    'date': date,
    'time': time,
    'tz_offset': tzOffset,
  };
}
