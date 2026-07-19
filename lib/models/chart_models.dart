class ZodiacPosition {
  final double longitude;
  final String sign;
  final double signLongitude;
  final int house;
  final bool retrograde;
  final List<String> dignities;

  ZodiacPosition({
    required this.longitude,
    required this.sign,
    required this.signLongitude,
    required this.house,
    required this.retrograde,
    required this.dignities,
  });

  factory ZodiacPosition.fromJson(Map<String, dynamic> json) {
    return ZodiacPosition(
      longitude: (json['longitude'] as num).toDouble(),
      sign: json['sign'] as String,
      signLongitude: (json['sign_longitude'] as num).toDouble(),
      house: json['house'] as int,
      retrograde: json['retrograde'] as bool,
      dignities: (json['dignities'] as List).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'longitude': longitude,
    'sign': sign,
    'sign_longitude': signLongitude,
    'house': house,
    'retrograde': retrograde,
    'dignities': dignities,
  };

  String get label {
    final capitalizedDignities = dignities.map((d) => '${d[0].toUpperCase()}${d.substring(1)}');
    return '${signLongitude.toStringAsFixed(2)}° $sign'
        '${retrograde ? ' (R)' : ''} — house $house'
        '${dignities.isEmpty ? '' : ' [${capitalizedDignities.join(', ')}]'}';
  }
}

class Aspect {
  final String planetA;
  final String planetB;
  final String aspect;
  final double angle;
  final double orb;

  Aspect({
    required this.planetA,
    required this.planetB,
    required this.aspect,
    required this.angle,
    required this.orb,
  });

  factory Aspect.fromJson(Map<String, dynamic> json) {
    return Aspect(
      planetA: json['planet_a'] as String,
      planetB: json['planet_b'] as String,
      aspect: json['aspect'] as String,
      angle: (json['angle'] as num).toDouble(),
      orb: (json['orb'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'planet_a': planetA,
    'planet_b': planetB,
    'aspect': aspect,
    'angle': angle,
    'orb': orb,
  };

  String get _displayAspect => aspect == 'conjunction' ? 'Conjunct' : '${aspect[0].toUpperCase()}${aspect.substring(1)}';

  String get label => '$planetA $_displayAspect $planetB (orb ${orb.toStringAsFixed(2)}°)';
}

class ChartResponse {
  final double julianDayUt;
  final String sect;
  final String? timezoneId;
  final double utcOffsetUsed;
  final String tzSource;
  final ZodiacPosition ascendant;
  final ZodiacPosition midheaven;
  final Map<String, ZodiacPosition> planets;
  final ZodiacPosition lotOfFortune;
  final ZodiacPosition lotOfSpirit;
  final List<Aspect> aspects;

  ChartResponse({
    required this.julianDayUt,
    required this.sect,
    required this.timezoneId,
    required this.utcOffsetUsed,
    required this.tzSource,
    required this.ascendant,
    required this.midheaven,
    required this.planets,
    required this.lotOfFortune,
    required this.lotOfSpirit,
    required this.aspects,
  });

  factory ChartResponse.fromJson(Map<String, dynamic> json) {
    final planetsJson = json['planets'] as Map<String, dynamic>;
    return ChartResponse(
      julianDayUt: (json['julian_day_ut'] as num).toDouble(),
      sect: json['sect'] as String,
      timezoneId: json['timezone_id'] as String?,
      utcOffsetUsed: (json['utc_offset_used'] as num).toDouble(),
      tzSource: json['tz_source'] as String,
      ascendant: ZodiacPosition.fromJson(json['ascendant'] as Map<String, dynamic>),
      midheaven: ZodiacPosition.fromJson(json['midheaven'] as Map<String, dynamic>),
      planets: planetsJson.map(
        (name, value) => MapEntry(name, ZodiacPosition.fromJson(value as Map<String, dynamic>)),
      ),
      lotOfFortune: ZodiacPosition.fromJson(json['lot_of_fortune'] as Map<String, dynamic>),
      lotOfSpirit: ZodiacPosition.fromJson(json['lot_of_spirit'] as Map<String, dynamic>),
      aspects: (json['aspects'] as List)
          .map((e) => Aspect.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'julian_day_ut': julianDayUt,
    'sect': sect,
    'timezone_id': timezoneId,
    'utc_offset_used': utcOffsetUsed,
    'tz_source': tzSource,
    'ascendant': ascendant.toJson(),
    'midheaven': midheaven.toJson(),
    'planets': planets.map((name, position) => MapEntry(name, position.toJson())),
    'lot_of_fortune': lotOfFortune.toJson(),
    'lot_of_spirit': lotOfSpirit.toJson(),
    'aspects': aspects.map((a) => a.toJson()).toList(),
  };
}

class Transit {
  final String transitingPlanet;
  final String natalPlanet;
  final String aspect;
  final String aspectSymbol;
  final double orb;
  final bool isApplying;
  final String interpretationKey;
  final bool isHarmonious;

  Transit({
    required this.transitingPlanet,
    required this.natalPlanet,
    required this.aspect,
    required this.aspectSymbol,
    required this.orb,
    required this.isApplying,
    required this.interpretationKey,
    required this.isHarmonious,
  });

  factory Transit.fromJson(Map<String, dynamic> json) {
    return Transit(
      transitingPlanet: json['transiting_planet'] as String,
      natalPlanet: json['natal_planet'] as String,
      aspect: json['aspect'] as String,
      aspectSymbol: json['aspect_symbol'] as String,
      orb: (json['orb'] as num).toDouble(),
      isApplying: json['is_applying'] as bool,
      interpretationKey: json['interpretation_key'] as String,
      isHarmonious: json['is_harmonious'] as bool,
    );
  }
}

class MoonPosition {
  final String sign;
  final int house;
  final String phaseName;
  final double phaseAngle;

  MoonPosition({required this.sign, required this.house, required this.phaseName, required this.phaseAngle});

  factory MoonPosition.fromJson(Map<String, dynamic> json) {
    return MoonPosition(
      sign: json['sign'] as String,
      house: json['house'] as int,
      phaseName: json['phase_name'] as String,
      phaseAngle: (json['phase_angle'] as num).toDouble(),
    );
  }
}

class TransitsResult {
  final List<Transit> transits;
  final MoonPosition moonPosition;
  final Transit? moonNatalAspect;

  TransitsResult({required this.transits, required this.moonPosition, this.moonNatalAspect});

  factory TransitsResult.fromJson(Map<String, dynamic> json) {
    return TransitsResult(
      transits: (json['transits'] as List).map((e) => Transit.fromJson(e as Map<String, dynamic>)).toList(),
      moonPosition: MoonPosition.fromJson(json['moon_position'] as Map<String, dynamic>),
      moonNatalAspect: json['moon_natal_aspect'] == null
          ? null
          : Transit.fromJson(json['moon_natal_aspect'] as Map<String, dynamic>),
    );
  }
}

class HouseLordEntry {
  final int houseNumber;
  final String sign;
  final String lord;
  final int lordHouse;
  final String lordSign;
  final String? lordDignity;
  final String interpretationKey;

  HouseLordEntry({
    required this.houseNumber,
    required this.sign,
    required this.lord,
    required this.lordHouse,
    required this.lordSign,
    required this.lordDignity,
    required this.interpretationKey,
  });

  factory HouseLordEntry.fromJson(Map<String, dynamic> json) {
    return HouseLordEntry(
      houseNumber: json['house_number'] as int,
      sign: json['sign'] as String,
      lord: json['lord'] as String,
      lordHouse: json['lord_house'] as int,
      lordSign: json['lord_sign'] as String,
      lordDignity: json['lord_dignity'] as String?,
      interpretationKey: json['interpretation_key'] as String,
    );
  }
}

/// One native's birth data as sent to POST /chart/synastry -- separate from
/// [BirthData] since it also carries an optional display name, which only
/// matters for a synastry comparison.
class SynastryPersonInput {
  final String? name;
  final String date;
  final String time;
  final double latitude;
  final double longitude;
  final double? tzOffset;

  SynastryPersonInput({
    this.name,
    required this.date,
    required this.time,
    required this.latitude,
    required this.longitude,
    this.tzOffset,
  });

  Map<String, dynamic> toJson() => {
    if (name != null && name!.isNotEmpty) 'name': name,
    'date': date,
    'time': time,
    'latitude': latitude,
    'longitude': longitude,
    if (tzOffset != null) 'tz_offset': tzOffset,
  };
}

class SynastryHouseOverlay {
  final String planet;
  final String fromChart;
  final String sign;
  final int house;

  SynastryHouseOverlay({required this.planet, required this.fromChart, required this.sign, required this.house});

  factory SynastryHouseOverlay.fromJson(Map<String, dynamic> json) {
    return SynastryHouseOverlay(
      planet: json['planet'] as String,
      fromChart: json['from_chart'] as String,
      sign: json['sign'] as String,
      house: json['house'] as int,
    );
  }

  Map<String, dynamic> toJson() => {'planet': planet, 'from_chart': fromChart, 'sign': sign, 'house': house};
}

class SynastryAspect {
  final String planetA;
  final String fromChart;
  final String planetB;
  final bool isAngle;
  final String aspect;
  final double angle;
  final double orb;

  SynastryAspect({
    required this.planetA,
    required this.fromChart,
    required this.planetB,
    required this.isAngle,
    required this.aspect,
    required this.angle,
    required this.orb,
  });

  factory SynastryAspect.fromJson(Map<String, dynamic> json) {
    return SynastryAspect(
      planetA: json['planet_a'] as String,
      // Both fields are new -- default so a comparison cached by a previous
      // app version (before angle aspects existed) still loads instead of
      // throwing. Every aspect that predates this field was planet-to-planet
      // from native A, so these defaults are also the historically correct
      // values, not just crash-avoidance.
      fromChart: json['from_chart'] as String? ?? 'A',
      planetB: json['planet_b'] as String,
      isAngle: json['is_angle'] as bool? ?? false,
      aspect: json['aspect'] as String,
      angle: (json['angle'] as num).toDouble(),
      orb: (json['orb'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'planet_a': planetA,
    'from_chart': fromChart,
    'planet_b': planetB,
    'is_angle': isAngle,
    'aspect': aspect,
    'angle': angle,
    'orb': orb,
  };
}

class SynastryResult {
  final String personAName;
  final String personBName;
  final List<SynastryHouseOverlay> houseOverlays;
  final List<SynastryAspect> aspects;
  final String analysis;

  SynastryResult({
    required this.personAName,
    required this.personBName,
    required this.houseOverlays,
    required this.aspects,
    required this.analysis,
  });

  factory SynastryResult.fromJson(Map<String, dynamic> json) {
    return SynastryResult(
      personAName: json['person_a_name'] as String,
      personBName: json['person_b_name'] as String,
      houseOverlays: (json['house_overlays'] as List)
          .map((e) => SynastryHouseOverlay.fromJson(e as Map<String, dynamic>))
          .toList(),
      aspects: (json['aspects'] as List).map((e) => SynastryAspect.fromJson(e as Map<String, dynamic>)).toList(),
      analysis: json['analysis'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'person_a_name': personAName,
    'person_b_name': personBName,
    'house_overlays': houseOverlays.map((o) => o.toJson()).toList(),
    'aspects': aspects.map((a) => a.toJson()).toList(),
    'analysis': analysis,
  };
}

class CityResult {
  final String name;
  final double latitude;
  final double longitude;

  CityResult({required this.name, required this.latitude, required this.longitude});

  factory CityResult.fromJson(Map<String, dynamic> json) {
    return CityResult(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class Interpretation {
  final String body;
  final String citation;

  Interpretation({required this.body, required this.citation});

  factory Interpretation.fromJson(Map<String, dynamic> json) {
    return Interpretation(body: json['body'] as String, citation: json['citation'] as String);
  }
}

class TemperamentFactor {
  final String label;
  final String detail;

  TemperamentFactor({required this.label, required this.detail});

  factory TemperamentFactor.fromJson(Map<String, dynamic> json) {
    return TemperamentFactor(label: json['label'] as String, detail: json['detail'] as String);
  }
}

class TemperamentResult {
  final String temperament;
  final String qualities;
  final int netHeat;
  final int netMoisture;
  final String description;
  final String citation;
  final List<TemperamentFactor> factors;

  TemperamentResult({
    required this.temperament,
    required this.qualities,
    required this.netHeat,
    required this.netMoisture,
    required this.description,
    required this.citation,
    required this.factors,
  });

  factory TemperamentResult.fromJson(Map<String, dynamic> json) {
    return TemperamentResult(
      temperament: json['temperament'] as String,
      qualities: json['qualities'] as String,
      netHeat: json['net_heat'] as int,
      netMoisture: json['net_moisture'] as int,
      description: json['description'] as String,
      citation: json['citation'] as String,
      factors: (json['factors'] as List)
          .map((e) => TemperamentFactor.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TemperamentExpandedSection {
  final String text;
  final String citation;

  TemperamentExpandedSection({required this.text, required this.citation});

  factory TemperamentExpandedSection.fromJson(Map<String, dynamic> json) {
    return TemperamentExpandedSection(text: json['text'] as String, citation: json['citation'] as String);
  }
}

class TemperamentExpandedRecommendations {
  final String text;

  TemperamentExpandedRecommendations({required this.text});

  factory TemperamentExpandedRecommendations.fromJson(Map<String, dynamic> json) {
    return TemperamentExpandedRecommendations(text: json['text'] as String);
  }
}

class TemperamentExpanded {
  final String temperament;
  final TemperamentExpandedSection healthTendencies;
  final TemperamentExpandedRecommendations traditionalRecommendations;

  TemperamentExpanded({
    required this.temperament,
    required this.healthTendencies,
    required this.traditionalRecommendations,
  });

  factory TemperamentExpanded.fromJson(Map<String, dynamic> json) {
    return TemperamentExpanded(
      temperament: json['temperament'] as String,
      healthTendencies: TemperamentExpandedSection.fromJson(json['health_tendencies'] as Map<String, dynamic>),
      traditionalRecommendations: TemperamentExpandedRecommendations.fromJson(
        json['traditional_recommendations'] as Map<String, dynamic>,
      ),
    );
  }
}

class ElectionalHit {
  final String planet;
  final int house;
  final String houseName;
  final String aspect;
  final String mode;
  final double orb;
  final double score;
  final bool isSupporting;
  final bool isCazimi;

  ElectionalHit({
    required this.planet,
    required this.house,
    required this.houseName,
    required this.aspect,
    required this.mode,
    required this.orb,
    required this.score,
    required this.isSupporting,
    required this.isCazimi,
  });

  factory ElectionalHit.fromJson(Map<String, dynamic> json) {
    return ElectionalHit(
      planet: json['planet'] as String,
      house: json['house'] as int,
      houseName: json['house_name'] as String,
      aspect: json['aspect'] as String,
      mode: json['mode'] as String,
      orb: (json['orb'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
      isSupporting: json['is_supporting'] as bool,
      isCazimi: json['is_cazimi'] as bool,
    );
  }
}

class ElectionalDay {
  final String date;
  final String bestTime;
  final String qualityLabel;
  final List<String> reasons;
  final List<ElectionalHit> hits;

  ElectionalDay({
    required this.date,
    required this.bestTime,
    required this.qualityLabel,
    required this.reasons,
    required this.hits,
  });

  factory ElectionalDay.fromJson(Map<String, dynamic> json) {
    return ElectionalDay(
      date: json['date'] as String,
      bestTime: json['best_time'] as String,
      qualityLabel: json['quality_label'] as String,
      reasons: (json['reasons'] as List).map((e) => e as String).toList(),
      hits: (json['hits'] as List).map((e) => ElectionalHit.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ElectionalResult {
  final String theme;
  final String themeLabel;
  final String? banner;
  final String? note;
  final List<ElectionalDay> days;

  ElectionalResult({
    required this.theme,
    required this.themeLabel,
    required this.banner,
    required this.note,
    required this.days,
  });

  factory ElectionalResult.fromJson(Map<String, dynamic> json) {
    return ElectionalResult(
      theme: json['theme'] as String,
      themeLabel: json['theme_label'] as String,
      banner: json['banner'] as String?,
      note: json['note'] as String?,
      days: (json['days'] as List).map((e) => ElectionalDay.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
