/// Service for resolving accurate, stop-aware destination names and via corridors.
///
/// Fixes:
/// 1. Circular routes (17, 18, 1, 2, 21, 23, 24, 25) which in raw GTFS are labelled
///    "City Centre" even when boarding in the City Centre departing towards Ely/Canton.
/// 2. Corridor distinctions (e.g. 44 via Rumney & New Rd vs 45 via Llanrumney & Greenway Rd)
///    so riders never see identical vague "St. Mellons" labels next to each other.
/// 3. Inbound vs Outbound stop detection based on Cardiff transit geography.
library;

class RouteDestinationResolver {
  // Common Cardiff City Centre stop identifiers & indicators
  static const Set<String> _kCityCentreKeywords = {
    'westgate',
    'wood street',
    'kingsway',
    'central station',
    'cardiff central',
    'wyndham',
    'philharmonic',
    'bute terrace',
    'cardiff bridge',
    'castle',
    'dumfries',
    'greyfriars',
    'customhouse',
    'churchill',
    'hayes',
    'st david',
    'marland',
  };

  /// Tests whether a stop is located in Cardiff City Centre.
  static bool isCityCentreStop(String stopName) {
    final lower = stopName.toLowerCase();
    return _kCityCentreKeywords.any((kw) => lower.contains(kw));
  }

  /// Returns the paired opposing route for circular Cardiff routes (e.g. 1 <-> 2).
  static String? getPairedOppositeRoute(String routeNumber) {
    switch (routeNumber.toUpperCase().trim()) {
      case '1':
        return '2';
      case '2':
        return '1';
      case '1A':
        return '2A';
      case '2A':
        return '1A';
      case '21':
        return '23';
      case '23':
        return '21';
      case '24':
        return '25';
      case '25':
        return '24';
      case '17':
        return '18';
      case '18':
        return '17';
      default:
        return null;
    }
  }

  /// Resolves the true rider-facing destination for a given [routeNumber] and [stopName].
  static String resolveDestination({
    required String routeNumber,
    required String stopName,
    String? rawHeadsign,
  }) {
    final normRoute = routeNumber.trim().toUpperCase();
    final atCityCentre = isCityCentreStop(stopName);
    final raw = rawHeadsign?.trim() ?? '';
    final rawLower = raw.toLowerCase();

    // Check if the raw headsign clearly indicates an inbound journey to City Centre
    final isRawInbound = rawLower == 'city centre' ||
        rawLower == 'cardiff' ||
        rawLower == 'cardiff city centre' ||
        rawLower == 'central station';

    // ── 1. Circular Routes (Special Outbound vs Inbound Resolution) ──────────
    switch (normRoute) {
      case '17':
        // Route 17: City Centre -> Canton -> Ely -> Caerau -> Canton -> City Centre
        if (atCityCentre || isRawInbound) {
          return atCityCentre ? 'Ely & Caerau via Canton' : 'City Centre via Canton';
        }
        return 'Ely & Caerau via Canton';

      case '18':
        // Route 18: City Centre -> Canton -> Caerau -> Ely -> Canton -> City Centre
        if (atCityCentre || isRawInbound) {
          return atCityCentre ? 'Canton & Ely via Grand Ave' : 'City Centre via Canton';
        }
        return 'Canton & Ely via Grand Ave';

      case '1':
        return 'City Circle (Clockwise)';

      case '2':
        return 'City Circle (Anti-Clockwise)';

      case '21':
        // City Centre -> Birchgrove -> Pantmawr -> City Centre
        if (atCityCentre) return 'Pantmawr via Birchgrove';
        return isRawInbound ? 'City Centre via Birchgrove' : 'Pantmawr via Birchgrove';

      case '23':
        // City Centre -> Pantmawr -> Birchgrove -> City Centre
        if (atCityCentre) return 'Birchgrove via Pantmawr';
        return isRawInbound ? 'City Centre via Pantmawr' : 'Birchgrove via Pantmawr';

      case '24':
        return 'Whitchurch & Llandaff North';

      case '25':
      case '25A':
        return 'Llandaff North via Llandaff';
    }

    // ── 2. Corridor Distinctions (e.g. 44 vs 45) ─────────────────────────────
    switch (normRoute) {
      case '44':
        if (isRawInbound || (rawLower.contains('cardiff') && !rawLower.contains('st'))) {
          return 'City Centre via Newport Road';
        }
        return 'St. Mellons via Rumney & New Rd';

      case '45':
        if (isRawInbound || (rawLower.contains('cardiff') && !rawLower.contains('st'))) {
          return 'City Centre via Newport Road';
        }
        return 'St. Mellons via Llanrumney';

      case '49':
        if (isRawInbound) return 'City Centre via Broadway';
        return 'Llanrumney via Newport Road';

      case '50':
        if (isRawInbound) return 'City Centre via Broadway';
        return 'Llanrumney via Ball Road';

      case '27':
        if (isRawInbound) return 'City Centre via Gabalfa';
        return 'Thornhill via Gabalfa';

      case '30':
        if (isRawInbound) return 'Cardiff via Old St. Mellons';
        return 'Newport Bus Station via Castleton';

      case '96':
      case '96A':
        if (isRawInbound) return 'Cardiff City Centre';
        return 'Barry Island via Wenvoe';

      case '6':
        // Baycar
        if (rawLower.contains('bay') || atCityCentre) {
          return 'Cardiff Bay (Millennium Centre)';
        }
        return 'City Centre via Station';

      case '7':
        if (isRawInbound) return 'City Centre via Grangetown';
        return 'Penarth via Llandough';

      case '8':
      case '9':
        if (rawLower.contains('bay') || rawLower.contains('sports') || atCityCentre) {
          return 'Cardiff Bay & Sports Village';
        }
        return 'Heath Hospital via City Centre';

      case '11':
        if (isRawInbound) return 'City Centre via Splott';
        return 'Pengam Green via Tremorfa';

      case '13':
        if (isRawInbound) return 'City Centre via Canton';
        return 'Drope via Canton & Ely';

      case '14':
        return 'Caerau & Ely – Heath Hospital';

      case '28':
        if (isRawInbound) return 'City Centre via Albany Road';
        return 'Thornhill via Roath Park & Lakeside';

      case '29':
        if (isRawInbound) return 'City Centre via Albany Road';
        return 'Llanishen via Lakeside';

      case '32':
        return 'St Fagans via Fairwater';

      case '35':
        if (isRawInbound) return 'City Centre via Gabalfa';
        return 'Gabalfa via North Road';

      case '52':
        if (isRawInbound) return 'City Centre via Albany Road';
        return 'Cyncoed via Albany Road';

      case '54':
        return 'Heath Hospital via Pontprennau';

      case '57':
        if (isRawInbound) return 'City Centre via Albany Road';
        return 'Pontprennau via Llanedeyrn & Pentwyn';

      case '58':
        if (isRawInbound) return 'City Centre via Albany Road';
        return 'Pontprennau via Pentwyn';

      case '61':
        if (isRawInbound) return 'City Centre via Canton';
        return 'Pentrebane via Fairwater';

      case '62':
        if (isRawInbound) return 'City Centre via Canton';
        return 'Rhydlafar via Danescourt';

      case '63':
        if (isRawInbound) return 'City Centre via Canton';
        return 'Creigiau via Danescourt & Pentyrch';

      case '64':
        return 'St Fagans & Drope via Canton';
    }

    // Default: Return cleaned raw headsign if available and not empty
    if (raw.isNotEmpty && raw != 'Cardiff' && raw != 'Bus') {
      return raw.replaceAll('"', '').trim();
    }

    return 'Cardiff Bus Service';
  }
}
