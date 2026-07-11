import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/birth_data.dart';
import '../models/chart_models.dart';

/// Default backend URL for the platform this app is running on.
///
/// Points at the production API on Railway over HTTPS. Every request in
/// [ApiClient] is built by interpolating this value, so keeping it a single
/// `https://` origin here is enough to guarantee the whole app talks to the
/// backend over HTTPS.
String defaultBaseUrl() {
  return 'https://ptolemy-production.up.railway.app';
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Thrown specifically when a request's own [Future.timeout] elapses (as
/// opposed to a connection failure or a non-200 response), so callers can
/// show a distinct "this is taking too long" message rather than a generic
/// connectivity error.
class ApiTimeoutException extends ApiException {
  ApiTimeoutException(super.message);
}

class ApiClient {
  final String baseUrl;

  ApiClient({required this.baseUrl});

  /// Decodes the response body as UTF-8 explicitly rather than trusting
  /// `response.body`, which falls back to Latin-1 whenever the server
  /// doesn't declare a charset (FastAPI's default `application/json` don't)
  /// — that would corrupt the em-dashes and curly quotes in interpretation
  /// citations.
  Map<String, dynamic> _decodeJson(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

  Future<ChartResponse> fetchPositions({
    required String date,
    required String time,
    required double latitude,
    required double longitude,
    double? tzOffset,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/chart/positions');

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'date': date,
              'time': time,
              'latitude': latitude,
              'longitude': longitude,
              if (tzOffset != null) 'tz_offset': tzOffset,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw ApiException('Could not reach backend at $baseUrl: $e');
    }

    if (response.statusCode != 200) {
      throw ApiException('Backend error (${response.statusCode}): ${response.body}');
    }

    return ChartResponse.fromJson(_decodeJson(response));
  }

  Future<TemperamentResult> fetchTemperament({
    required String date,
    required String time,
    required double latitude,
    required double longitude,
    double? tzOffset,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/temperament');

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'date': date,
              'time': time,
              'latitude': latitude,
              'longitude': longitude,
              if (tzOffset != null) 'tz_offset': tzOffset,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw ApiException('Could not reach backend at $baseUrl: $e');
    }

    if (response.statusCode != 200) {
      throw ApiException('Backend error (${response.statusCode}): ${response.body}');
    }

    return TemperamentResult.fromJson(_decodeJson(response));
  }

  Future<TemperamentExpanded> fetchTemperamentExpanded({required String temperament}) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/temperament/expanded',
    ).replace(queryParameters: {'temperament': temperament});
    return TemperamentExpanded.fromJson(await _get(uri));
  }

  Future<ElectionalResult> fetchElectional({
    required String date,
    required String time,
    required double latitude,
    required double longitude,
    double? tzOffset,
    required String startDate,
    required String endDate,
    required String theme,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/electional');

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'date': date,
              'time': time,
              'latitude': latitude,
              'longitude': longitude,
              if (tzOffset != null) 'tz_offset': tzOffset,
              'start_date': startDate,
              'end_date': endDate,
              'theme': theme,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException catch (e) {
      throw ApiTimeoutException('Electional scan timed out: $e');
    } catch (e) {
      throw ApiException('Could not reach backend at $baseUrl: $e');
    }

    if (response.statusCode != 200) {
      throw ApiException('Backend error (${response.statusCode}): ${response.body}');
    }

    return ElectionalResult.fromJson(_decodeJson(response));
  }

  Future<List<HouseLordEntry>> fetchHouseLords({
    required String date,
    required String time,
    required double latitude,
    required double longitude,
    double? tzOffset,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/chart/house-lords');

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'date': date,
              'time': time,
              'latitude': latitude,
              'longitude': longitude,
              if (tzOffset != null) 'tz_offset': tzOffset,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw ApiException('Could not reach backend at $baseUrl: $e');
    }

    if (response.statusCode != 200) {
      throw ApiException('Backend error (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (json['entries'] as List)
        .map((e) => HouseLordEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Interpretation> fetchHouseLordInterpretation({required int fromHouse, required int toHouse}) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/interpretations/house-lord',
    ).replace(queryParameters: {'from_house': '$fromHouse', 'to_house': '$toHouse'});
    return Interpretation.fromJson(await _get(uri));
  }

  Future<List<CityResult>> searchCities(String query) async {
    final uri = Uri.parse('$baseUrl/api/v1/geocode/search').replace(queryParameters: {'q': query});

    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw ApiException('Could not reach backend at $baseUrl: $e');
    }

    if (response.statusCode != 200) {
      throw ApiException('Backend error (${response.statusCode}): ${response.body}');
    }

    final json = _decodeJson(response);
    return (json['results'] as List)
        .map((e) => CityResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Interpretation> fetchPlanetInSign({required String planet, required String sign}) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/interpretations/planet-sign',
    ).replace(queryParameters: {'planet': planet, 'sign': sign});
    return Interpretation.fromJson(await _get(uri));
  }

  Future<Interpretation> fetchPlanetInHouse({required String planet, required int house}) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/interpretations/planet-house',
    ).replace(queryParameters: {'planet': planet, 'house': '$house'});
    return Interpretation.fromJson(await _get(uri));
  }

  Future<Interpretation> fetchLotInterpretation({
    required String lot,
    required String sign,
    required int house,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/interpretations/lot',
    ).replace(queryParameters: {'lot': lot, 'sign': sign, 'house': '$house'});
    return Interpretation.fromJson(await _get(uri));
  }

  Future<Interpretation> fetchAspectInterpretation({
    required String planetA,
    required String planetB,
    required String aspectType,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/interpretations/aspect').replace(
      queryParameters: {'planet_a': planetA, 'planet_b': planetB, 'aspect_type': aspectType},
    );
    return Interpretation.fromJson(await _get(uri));
  }

  Future<void> saveUserChart({required String googleId, required BirthData birthData}) async {
    final uri = Uri.parse('$baseUrl/api/v1/user/chart');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'google_id': googleId, ...birthData.toJson()}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw ApiException('Could not reach backend at $baseUrl: $e');
    }

    if (response.statusCode != 200) {
      throw ApiException('Backend error (${response.statusCode}): ${response.body}');
    }
  }

  /// Returns null if this Google account has no saved chart yet (404) --
  /// that's the expected "first login on this device" case, not an error.
  Future<BirthData?> fetchUserChart({required String googleId}) async {
    final uri = Uri.parse('$baseUrl/api/v1/user/chart/$googleId');
    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw ApiException('Could not reach backend at $baseUrl: $e');
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ApiException('Backend error (${response.statusCode}): ${response.body}');
    }
    return BirthData.fromJson(_decodeJson(response));
  }

  Future<String> fetchSynthesis({
    required String planet,
    required String sign,
    required int house,
    required String sect,
    required List<String> dignities,
    required List<String> aspects,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/interpretations/synthesis');

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'planet': planet,
              'sign': sign,
              'house': house,
              'sect': sect,
              'dignities': dignities,
              'aspects': aspects,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw ApiException('Could not reach backend at $baseUrl: $e');
    }

    if (response.statusCode != 200) {
      throw ApiException('Backend error (${response.statusCode}): ${response.body}');
    }

    return _decodeJson(response)['synthesis'] as String;
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw ApiException('Could not reach backend at $baseUrl: $e');
    }

    if (response.statusCode != 200) {
      throw ApiException('Backend error (${response.statusCode}): ${response.body}');
    }

    return _decodeJson(response);
  }
}
