import '../models/chart_models.dart';

/// Pre-written planet-in-house template sentences used to assemble a
/// synthesis paragraph for an electional moment, without any AI call.
/// Each (planet, house) combination has 3 phrasing variants so that a
/// results list showing several days doesn't repeat identical wording
/// when the same combination recurs across different days.
const Map<String, Map<int, List<String>>> _templates = {
  'Sun': {
    1: [
      'The Sun illuminates your personal identity and vitality at this moment.',
      'Solar energy brings added vitality and confidence to your sense of self right now.',
      "The Sun's influence sharpens personal identity and lends the native fresh vigor.",
    ],
    2: [
      'The Sun strengthens matters of wealth and material resources.',
      'Solar energy lends firmness and confidence to matters of income and possessions.',
      "The Sun's influence favors the steady growth of material resources.",
    ],
    3: [
      'The Sun brings clarity and confidence to communication and short journeys.',
      'Solar energy sharpens the mind for clear speech and favors brief travels.',
      "The Sun's influence lends confidence to conversations and nearby journeys.",
    ],
    4: [
      'The Sun shines on the foundations of home and family life.',
      'Solar energy brings warmth and vitality to matters of home and household.',
      "The Sun's influence strengthens the foundations upon which family life rests.",
    ],
    5: [
      'The Sun favors creative expression, pleasure, and matters of the heart.',
      'Solar energy brightens romance, creative pursuits, and simple pleasures.',
      "The Sun's influence lends warmth and confidence to affairs of the heart.",
    ],
    6: [
      'The Sun supports health, daily work, and service to others.',
      'Solar energy lends vitality to daily routines and the service one gives to others.',
      "The Sun's influence favors steady health and diligent, useful work.",
    ],
    7: [
      'The Sun illuminates partnership and significant one-on-one relationships.',
      'Solar energy brings clarity and confidence to significant partnerships.',
      "The Sun's influence favors open dealings within marriage and close alliance.",
    ],
    8: [
      'The Sun brings attention to shared resources and matters of inheritance.',
      'Solar energy draws focus toward joint finances and questions of legacy.',
      "The Sun's influence illuminates matters of inheritance and shared holdings.",
    ],
    9: [
      'The Sun favors long journeys, higher learning, and philosophical inquiry.',
      'Solar energy favors distant travel, higher study, and the pursuit of wisdom.',
      "The Sun's influence lends confidence to philosophical inquiry and far travel.",
    ],
    10: [
      'The Sun elevates career matters and public reputation.',
      "Solar energy raises the native's standing in career and public esteem.",
      "The Sun's influence favors advancement in career and public honor.",
    ],
    11: [
      'The Sun brightens friendships, social networks, and future hopes.',
      'Solar energy lends warmth to friendships and confidence to long-held hopes.',
      "The Sun's influence favors alliances among friends and the fulfillment of hopes.",
    ],
    12: [
      'The Sun casts light on hidden matters and solitary reflection.',
      'Solar energy brings quiet clarity to private affairs and inward reflection.',
      "The Sun's influence illuminates what has been hidden and favors solitude.",
    ],
  },
  'Moon': {
    1: [
      'The Moon heightens emotional sensitivity and public visibility.',
      'The Moon brings the native into greater public awareness and emotional openness.',
      'Lunar energy amplifies personal presence and emotional responsiveness.',
    ],
    2: [
      'The Moon favors the flow of resources and financial intuition.',
      'The Moon supports an intuitive sense for money and the steady flow of resources.',
      'Lunar energy favors instinctive financial judgment and the gathering of resources.',
    ],
    3: [
      'The Moon supports communication, travel, and sibling relationships.',
      'The Moon favors easy conversation, short journeys, and bonds with siblings.',
      'Lunar energy supports responsive communication and ties with brothers and sisters.',
    ],
    4: [
      'The Moon deeply favors domestic matters, home, and family.',
      'The Moon strongly supports the home, domestic comfort, and family bonds.',
      'Lunar energy deeply favors matters of household and kin.',
    ],
    5: [
      'The Moon encourages emotional expression, romance, and pleasure.',
      'The Moon favors open emotional expression and tender romantic feeling.',
      'Lunar energy encourages heartfelt romance and simple pleasure.',
    ],
    6: [
      'The Moon supports healing, daily routines, and care for others.',
      'The Moon favors gentle healing, steady routines, and care given to others.',
      'Lunar energy supports recovery, daily habit, and nurturing service.',
    ],
    7: [
      'The Moon favors emotional connection and the deepening of partnerships.',
      'The Moon supports deepening emotional bonds within significant partnership.',
      'Lunar energy favors closeness and emotional attunement in partnership.',
    ],
    8: [
      'The Moon illuminates hidden emotional depths and shared bonds.',
      'The Moon brings quiet awareness to hidden feeling and shared attachment.',
      'Lunar energy uncovers emotional depths within shared bonds.',
    ],
    9: [
      'The Moon favors travel, exploration, and intuitive wisdom.',
      'The Moon supports journeys of exploration and intuitive understanding.',
      'Lunar energy favors wandering, discovery, and instinctive wisdom.',
    ],
    10: [
      'The Moon brings popular attention and public recognition.',
      'The Moon draws the native into the public eye and popular favor.',
      'Lunar energy favors visibility and recognition among the many.',
    ],
    11: [
      'The Moon supports friendships and emotional connection within groups.',
      'The Moon favors warmth and emotional closeness among friends and groups.',
      'Lunar energy supports belonging and fellow-feeling within community.',
    ],
    12: [
      'The Moon favors rest, retreat, and inner reflection.',
      'The Moon supports withdrawal, quiet rest, and inward reflection.',
      'Lunar energy favors solitude, repose, and reflective retreat.',
    ],
  },
  'Mercury': {
    1: [
      'Mercury sharpens the mind and favors clear self-expression.',
      'Mercury quickens the intellect and favors clear, confident speech.',
      'Mercurial energy sharpens thought and favors ready self-expression.',
    ],
    2: [
      'Mercury favors financial reasoning and commercial dealings.',
      'Mercury supports sharp financial reasoning and profitable trade.',
      'Mercurial energy favors calculation in money matters and commerce.',
    ],
    3: [
      'Mercury is exceptionally strong here, favoring all communication and travel.',
      'Mercury is especially potent here, favoring every form of speech and short travel.',
      'Mercurial energy is at its height, strongly favoring communication and journeys.',
    ],
    4: [
      'Mercury supports conversations about home, property, and family matters.',
      'Mercury favors clear discussion of property, household, and family affairs.',
      'Mercurial energy supports negotiation over home and family matters.',
    ],
    5: [
      'Mercury favors creative writing, intellectual play, and teaching.',
      'Mercury supports inventive writing, playful wit, and instruction.',
      'Mercurial energy favors the crafting of words and lighthearted teaching.',
    ],
    6: [
      'Mercury supports detailed work, health analysis, and practical problem-solving.',
      'Mercury favors careful, detailed work and clear-headed problem-solving.',
      'Mercurial energy supports meticulous analysis and practical remedies.',
    ],
    7: [
      'Mercury favors negotiation, contracts, and intellectual partnership.',
      'Mercury supports sharp negotiation and the careful drafting of contracts.',
      'Mercurial energy favors agreement-making and intellectual exchange in partnership.',
    ],
    8: [
      'Mercury supports research into hidden matters and complex investigations.',
      'Mercury favors careful research and the untangling of complex questions.',
      'Mercurial energy supports probing inquiry into hidden or complex affairs.',
    ],
    9: [
      'Mercury favors study, teaching, foreign correspondence, and philosophical inquiry.',
      'Mercury supports scholarly study, teaching, and correspondence abroad.',
      'Mercurial energy favors inquiry, instruction, and distant correspondence.',
    ],
    10: [
      'Mercury supports career advancement through communication and intellect.',
      'Mercury favors professional advancement through wit and clear communication.',
      'Mercurial energy supports career progress achieved through skillful speech.',
    ],
    11: [
      'Mercury favors networking, group discussions, and the exchange of ideas.',
      'Mercury supports lively group discussion and the free exchange of ideas.',
      'Mercurial energy favors building connections through conversation and shared ideas.',
    ],
    12: [
      'Mercury supports solitary study and work done behind the scenes.',
      'Mercury favors quiet study and careful work conducted out of sight.',
      'Mercurial energy supports private research and unseen intellectual labor.',
    ],
  },
  'Venus': {
    1: [
      "Venus graces the native's personal appearance and immediate environment with beauty and charm.",
      "Venus lends charm and grace to the native's appearance and surroundings.",
      'Venusian energy brings beauty and pleasantness to one\'s presence and setting.',
    ],
    2: [
      'Venus favors the acquisition of beautiful things and material comfort.',
      'Venus supports gathering fine possessions and comfortable living.',
      'Venusian energy favors ease, comfort, and an eye for beautiful things.',
    ],
    3: [
      'Venus brings harmony and pleasantness to communication and short journeys.',
      'Venus lends warmth and ease to conversation and nearby travel.',
      'Venusian energy favors pleasant exchanges and agreeable short journeys.',
    ],
    4: [
      'Venus favors the beautification of the home and harmony within the family.',
      'Venus supports a beautiful home and peaceable family relations.',
      'Venusian energy favors domestic charm and family goodwill.',
    ],
    5: [
      'Venus is exceptionally strong here, strongly favoring romance, pleasure, and creative expression.',
      'Venus is especially potent here, greatly favoring love, pleasure, and artistic expression.',
      'Venusian energy is at its height, strongly favoring romance and creative delight.',
    ],
    6: [
      'Venus brings grace to service, and may favor health treatments of a gentle nature.',
      'Venus lends grace to acts of service and favors gentle, soothing remedies.',
      'Venusian energy softens daily service and favors mild, pleasant treatments.',
    ],
    7: [
      'Venus strongly favors partnership, marriage, and all significant one-on-one relationships.',
      'Venus greatly favors marriage, courtship, and close one-on-one bonds.',
      'Venusian energy strongly favors union, marriage, and devoted partnership.',
    ],
    8: [
      'Venus softens matters of shared resources and brings grace to difficult transitions.',
      'Venus eases matters of shared finance and lends grace to hard transitions.',
      'Venusian energy brings comfort to joint resources and difficult change.',
    ],
    9: [
      'Venus favors travel for pleasure, artistic or spiritual pursuits abroad.',
      'Venus supports pleasurable travel and artistic or spiritual pursuits in foreign places.',
      'Venusian energy favors journeys taken for delight, art, or devotion.',
    ],
    10: [
      'Venus favors career advancement through charm, beauty, and social grace.',
      'Venus supports professional success won through charm and social grace.',
      'Venusian energy favors advancement gained through likability and elegance.',
    ],
    11: [
      'Venus supports friendship, social harmony, and the fulfillment of hopes.',
      'Venus favors pleasant friendships and harmony within social circles.',
      'Venusian energy supports goodwill among friends and the fulfillment of wishes.',
    ],
    12: [
      'Venus brings quiet beauty to solitary retreat and hidden pleasures.',
      'Venus lends gentle beauty to private retreat and secret delights.',
      'Venusian energy favors quiet charm in solitude and hidden enjoyments.',
    ],
  },
  'Mars': {
    1: [
      'Mars brings energy and initiative to personal action — favorable for bold beginnings.',
      'Mars lends bold energy and drive — a good time for decisive new beginnings.',
      'Martial energy favors courageous action and the start of new undertakings.',
    ],
    2: [
      'Mars drives the pursuit of resources but may bring financial conflict.',
      'Mars energizes the pursuit of income, though it may stir money disputes.',
      'Martial energy pushes hard for resources but risks financial friction.',
    ],
    3: [
      'Mars sharpens communication and favors decisive short journeys.',
      'Mars lends a cutting edge to speech and favors quick, decisive travel.',
      'Martial energy favors blunt communication and swift short journeys.',
    ],
    4: [
      'Mars brings energy to domestic matters but may stir conflict at home.',
      'Mars energizes household affairs but risks friction within the home.',
      'Martial energy activates domestic life, though tempers may flare at home.',
    ],
    5: [
      'Mars brings passion and competitive energy to creative and romantic pursuits.',
      'Mars lends fiery passion and competitive drive to romance and creativity.',
      'Martial energy fuels bold romantic and creative pursuits.',
    ],
    6: [
      'Mars strongly supports physical work, athletic effort, and decisive health action.',
      'Mars greatly favors physical labor, athletic exertion, and decisive care for health.',
      'Martial energy strongly supports vigorous work and bold health action.',
    ],
    7: [
      'Mars brings intensity to partnerships — favorable for bold relationship moves but watch for conflict.',
      'Mars intensifies partnership — good for bold romantic moves, though conflict may arise.',
      'Martial energy heightens intensity in partnership; act boldly but watch for strife.',
    ],
    8: [
      'Mars activates shared resources and matters requiring courage and decisiveness.',
      'Mars stirs joint resources and favors courageous, decisive action there.',
      'Martial energy activates shared finances and rewards bold decisiveness.',
    ],
    9: [
      'Mars favors bold journeys and the courageous pursuit of philosophical or religious truth.',
      'Mars supports daring travel and a bold pursuit of philosophical or religious truth.',
      'Martial energy favors courageous journeys and the vigorous pursuit of truth.',
    ],
    10: [
      'Mars supports decisive career action and competitive professional advancement.',
      'Mars favors bold career moves and competitive drive toward advancement.',
      'Martial energy supports decisive professional action and rivalry well-met.',
    ],
    11: [
      'Mars energizes group activities and the pursuit of ambitious social goals.',
      'Mars fuels group efforts and the drive toward ambitious shared goals.',
      'Martial energy energizes collective action and bold social ambition.',
    ],
    12: [
      'Mars activates hidden matters — proceed with awareness of unseen opposition.',
      'Mars stirs what is hidden — proceed boldly but stay alert to unseen rivals.',
      'Martial energy activates concealed affairs; move forward with wary courage.',
    ],
  },
  'Jupiter': {
    1: [
      'Jupiter bestows confidence, optimism, and an expansive personal presence.',
      'Jupiter grants confidence, good cheer, and an expansive sense of self.',
      'Jovian energy bestows optimism and a generously expansive presence.',
    ],
    2: [
      'Jupiter strongly favors financial growth, abundance, and material prosperity.',
      'Jupiter greatly favors growing wealth, abundance, and material ease.',
      'Jovian energy strongly favors prosperity and material abundance.',
    ],
    3: [
      'Jupiter expands communication and brings fortunate short journeys.',
      'Jupiter broadens communication and favors fortunate, easy travel nearby.',
      'Jovian energy expands speech and favors lucky short journeys.',
    ],
    4: [
      'Jupiter brings abundance and good fortune to home and family matters.',
      'Jupiter grants abundance and good fortune within home and family life.',
      'Jovian energy favors a flourishing household and fortunate family ties.',
    ],
    5: [
      'Jupiter greatly favors pleasure, creative expansion, and matters of the heart.',
      'Jupiter richly favors pleasure, creative growth, and affairs of the heart.',
      'Jovian energy greatly favors joyful expansion in love and creativity.',
    ],
    6: [
      'Jupiter brings healing and fortunate outcomes in matters of health and service.',
      'Jupiter grants healing and favorable outcomes in health and daily service.',
      'Jovian energy favors recovery and fortunate results in health matters.',
    ],
    7: [
      'Jupiter greatly favors partnership, bringing wisdom and good fortune to significant relationships.',
      'Jupiter richly favors partnership, lending wisdom and good fortune to close bonds.',
      'Jovian energy greatly favors significant relationships, bringing wisdom and luck.',
    ],
    8: [
      'Jupiter brings fortunate outcomes in matters of inheritance and shared resources.',
      'Jupiter grants favorable results in inheritance and shared financial matters.',
      'Jovian energy favors fortunate outcomes in legacy and joint resources.',
    ],
    9: [
      'Jupiter is exceptionally strong here, greatly favoring long journeys, higher learning, and spiritual growth.',
      'Jupiter is especially potent here, richly favoring distant travel, higher study, and spiritual growth.',
      'Jovian energy is at its height, strongly favoring far journeys and higher wisdom.',
    ],
    10: [
      'Jupiter greatly favors career advancement, public recognition, and positions of authority.',
      'Jupiter richly favors professional advancement, public honor, and positions of authority.',
      'Jovian energy greatly favors rising in career, reputation, and rank.',
    ],
    11: [
      'Jupiter strongly supports friendship, benefactors, and the fulfillment of long-held hopes.',
      'Jupiter greatly favors loyal friendship, generous benefactors, and hopes fulfilled.',
      'Jovian energy strongly supports friendship and the fulfillment of cherished hopes.',
    ],
    12: [
      'Jupiter brings hidden protection and quiet grace to solitary or spiritual pursuits.',
      'Jupiter grants quiet protection and grace to solitary or spiritual pursuits.',
      'Jovian energy favors hidden blessing and grace in solitude or devotion.',
    ],
  },
  'Saturn': {
    1: [
      'Saturn brings seriousness and endurance — favorable for long-term commitments but not for impulsive action.',
      'Saturn lends gravity and endurance — good for long-term commitment, poor for impulsive action.',
      'Saturnine energy favors patient endurance and long commitment over hasty action.',
    ],
    2: [
      'Saturn supports disciplined financial planning but slows material gains.',
      'Saturn favors careful, disciplined budgeting, though gains come slowly.',
      'Saturnine energy supports methodical financial planning at a gradual pace.',
    ],
    3: [
      'Saturn favors serious, methodical communication and deliberate travel.',
      'Saturn supports careful, methodical speech and deliberate, well-planned travel.',
      'Saturnine energy favors measured communication and unhurried journeys.',
    ],
    4: [
      'Saturn brings structure and long-term stability to home and family matters.',
      'Saturn lends lasting structure and stability to household and family life.',
      'Saturnine energy favors durable foundations in home and family.',
    ],
    5: [
      'Saturn tempers pleasure and creative expression — better for disciplined creative work than for romance.',
      'Saturn restrains pleasure and romance, favoring disciplined creative work instead.',
      'Saturnine energy cools romance but favors patient, disciplined creative effort.',
    ],
    6: [
      'Saturn supports disciplined health regimens and serious, sustained work.',
      'Saturn favors strict health routines and long, sustained effort at work.',
      'Saturnine energy supports disciplined care of the body and enduring labor.',
    ],
    7: [
      'Saturn favors serious, long-term commitments in partnership — not casual connections.',
      'Saturn favors lasting, serious commitment in partnership, not casual ties.',
      'Saturnine energy favors enduring partnership over fleeting connection.',
    ],
    8: [
      'Saturn brings gravity to matters of inheritance and shared resources — proceed with care.',
      'Saturn lends weight to matters of inheritance and shared resources — proceed carefully.',
      'Saturnine energy brings seriousness to legacy and joint resources; act with caution.',
    ],
    9: [
      'Saturn favors serious scholarly study and deliberate, well-planned long journeys.',
      'Saturn favors disciplined scholarship and carefully planned distant travel.',
      'Saturnine energy favors patient study and methodically planned journeys.',
    ],
    10: [
      'Saturn supports slow but lasting career advancement through discipline and demonstrated competence.',
      'Saturn favors gradual but durable career progress earned through discipline.',
      'Saturnine energy supports steady advancement built on proven competence.',
    ],
    11: [
      'Saturn brings serious, loyal friendships and the patient pursuit of long-term goals.',
      'Saturn favors loyal, long-lasting friendship and patient work toward goals.',
      'Saturnine energy favors enduring loyalty in friendship and long-term aims.',
    ],
    12: [
      'Saturn deepens solitary reflection and favors serious spiritual discipline.',
      'Saturn favors quiet solitude and committed spiritual discipline.',
      'Saturnine energy deepens inward reflection and favors disciplined practice.',
    ],
  },
};

const Map<String, String> _aspectPrefixes = {
  'conjunction': 'Powerfully,',
  'trine': 'Harmoniously,',
  'sextile': 'Favorably,',
  'square': 'With some tension,',
  'opposition': 'With notable intensity,',
};

/// Three closing-line variants per quality tier (as returned by the backend
/// checklist system — see ElectionalDay.qualityLabel), rotated the same way
/// as the planet/house templates.
const Map<String, List<String>> _closingVariants = {
  'Auspicious': [
    'This is one of the most astrologically powerful moments of the period.',
    'The heavens align with unusual clarity in your favor at this time.',
    'Rarely does the chart show such concentrated support for action.',
  ],
  'Favorable': [
    'This moment carries genuine astrological support for your intentions.',
    'The chart offers real assistance to those who act with awareness.',
    'A genuinely supportive configuration for the matter at hand.',
  ],
  'Best Available': [
    'This moment offers modest but real astrological assistance.',
    'The chart provides some support, though stronger moments may follow.',
    'A workable moment — not the most powerful, but astrologically sound.',
  ],
};

/// Glyph shown alongside each quality tier's label in the UI.
const Map<String, String> qualitativeSymbols = {
  'Auspicious': '✦',
  'Favorable': '◆',
  'Best Available': '◇',
};

String _prefixFor(ElectionalHit hit) {
  if (hit.mode == 'antiscion') return 'By hidden sympathy,';
  return _aspectPrefixes[hit.aspect] ?? '';
}

/// Picks the next unused variant for [key] out of [variants], rotating
/// through them via [usageCounts] so repeated keys within one results list
/// don't repeat the exact same sentence.
String _nextVariant(String key, List<String> variants, Map<String, int> usageCounts) {
  final index = (usageCounts[key] ?? 0) % variants.length;
  usageCounts[key] = (usageCounts[key] ?? 0) + 1;
  return variants[index];
}

/// Builds a synthesis paragraph for one electional moment. [usageCounts] is
/// shared across every day in the same results list (create one empty map
/// per scan, and pass the same instance into every call) so that sentence
/// and closing-line variants rotate rather than repeat across the list.
String buildSynthesis(
  List<ElectionalHit> hits,
  String qualitativeLabel,
  Map<String, int> usageCounts,
) {
  final candidates = hits.toList()..sort((a, b) => b.score.compareTo(a.score));
  final top = candidates.take(3).toList();

  final sentences = <String>[];
  for (var i = 0; i < top.length; i++) {
    final hit = top[i];
    final variants = _templates[hit.planet]?[hit.house];
    if (variants == null) continue;
    final template = _nextVariant('${hit.planet}-${hit.house}', variants, usageCounts);
    if (i == 0) {
      final prefix = _prefixFor(hit);
      sentences.add(prefix.isEmpty ? template : '$prefix ${template[0].toLowerCase()}${template.substring(1)}');
    } else {
      sentences.add(template);
    }
  }

  final closingVariants = _closingVariants[qualitativeLabel];
  final closing = closingVariants == null ? '' : _nextVariant('closing-$qualitativeLabel', closingVariants, usageCounts);
  return [...sentences, closing].where((s) => s.isNotEmpty).join(' ');
}
