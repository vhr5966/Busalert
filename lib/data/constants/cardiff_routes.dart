/// Official Cardiff Bus route reference data.
///
/// This dataset is sourced directly from Cardiff Bus and represents the
/// authoritative list of currently operating routes in the Cardiff area.
///
/// Status: OFFICIAL STATIC REFERENCE DATA.
/// This is NOT mock data. It mirrors the published Cardiff Bus timetable and
/// is maintained as a local dataset in the same way as the BODS NaPTAN stops
/// CSV. It is used as a fallback when the backend route-feed is unavailable.
///
/// Last reviewed: August 2026
library;

import '../models/bus_route.dart';

/// Official Cardiff Bus routes, keyed by route number.
///
/// Operator codes:
///   `CB`  = Cardiff Bus (Bws Caerdydd) — main operator
///   `BCB` = Barry/Coastal Bus (routes B1, B2)
const String _kCardiffBusOperatorId = 'CB';
const String _kCardiffBusOperatorName = 'Cardiff Bus (Bws Caerdydd)';

/// Full official Cardiff Bus route list with route numbers and descriptions.
///
/// Includes city circular services, park-and-ride, school services (6xx),
/// Cardiff Bay routes, inter-urban routes, and the Skycar tourist service.
const List<Map<String, String>> _kRawCardiffRoutes = [
  // ── City Circular services ──────────────────────────────────────────────
  {
    'number': '1',
    'name':
        'City Circle – Cardiff Bay – Canton – Heath Hospital – Albany Road – Tremorfa (Clockwise)',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '2',
    'name':
        'City Circle (Clockwise) via Tremorfa, Albany Road, Heath Hospital, Canton, Cardiff Bay',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '3',
    'name': 'Canal Street – Ocean Way – Wentloog Business Park',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Bay & City Centre ───────────────────────────────────────────────────
  {
    'number': '6',
    'name': 'Baycar – Cardiff Bay (Millennium Centre) – City Centre',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '7',
    'name': 'City Centre – Llandough Hospital – Penarth',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '8',
    'name': 'City Centre – Grangetown – Cardiff Bay & Atlantic Wharf',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '9',
    'name':
        'Heath Hospital – Sports Village via Whitchurch Road, Crwys Road, City Road, Grangetown',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '11',
    'name': 'City Centre – Pengam Green via Splott, Tremorfa',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '13',
    'name': 'City Centre – Drope via Canton, Ely',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '14',
    'name': 'Caerau & Ely – Western Avenue – Heath Hospital',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Circular Canton / Ely routes ────────────────────────────────────────
  {
    'number': '17',
    'name':
        'City Centre – City Centre via Canton, Heol Trelai, Grand Avenue',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '18',
    'name':
        'City Centre – City Centre via Canton, Grand Avenue, Heol Trelai',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Birchgrove / Pantmawr ────────────────────────────────────────────────
  {
    'number': '21',
    'name': 'City Centre – City Centre via Birchgrove, Pantmawr',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '23',
    'name': 'City Centre – City Centre via Pantmawr, Birchgrove',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Llandaff North / Whitchurch ─────────────────────────────────────────
  {
    'number': '24',
    'name': 'City Centre – Whitchurch – Llandaff North (Circular)',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '25',
    'name': 'City Centre – Llandaff – Llandaff North (Circular)',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '25A',
    'name':
        'City Centre – Llandaff North (Circular) via Llandaff & Gabalfa',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Thornhill / Llanishen ───────────────────────────────────────────────
  {
    'number': '27',
    'name':
        'City Centre – Gabalfa Flyover – Templeton Avenue – Excalibur Drive – Thornhill',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '28',
    'name':
        'City Centre – Albany Road, Roath Park Lake, Lakeside – Thornhill',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '29',
    'name':
        'City Centre – Albany Road – Lakeside – Fishguard Road – Llanishen',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Newport / St Mellons ────────────────────────────────────────────────
  {
    'number': '30',
    'name':
        'Cardiff – Old St. Mellons – Castleton – Tredegar Park – Newport',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '32',
    'name': 'Westgate Street – Fairwater – St Fagans',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '35',
    'name': 'City Centre – North Road – Gabalfa',
    'operator': _kCardiffBusOperatorId,
  },
  // ── St Mellons / Newport Road corridor ─────────────────────────────────
  {
    'number': '44',
    'name':
        'City Centre – Newport Road – New Road – Greenway Road – Brynbala Way – St Mellons',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '45',
    'name':
        'City Centre – Newport Road – Carpenters Arms – Caeglas Road – Greenway Road – St Mellons',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Llanrumney ──────────────────────────────────────────────────────────
  {
    'number': '49',
    'name':
        'City Centre – Broadway – Newport Road – Llanrumney Avenue – Llanrumney',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '50',
    'name':
        'City Centre – Broadway – Newport Road – Ball Road – Burnham Avenue – Llanrumney',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Cyncoed / Pontprennau ───────────────────────────────────────────────
  {
    'number': '52',
    'name': 'City Centre – Albany Road – Ty Gwyn Road – Cyncoed',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '54',
    'name':
        'St. Mellons – Heath Hospital via Pontprennau, Pentwyn, Llanederyn, Cyncoed',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '57',
    'name':
        'City Centre – Pontprennau via Albany Road, Llanedeyrn, Hollybush, Pentwyn',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '58',
    'name':
        'City Centre – Pontprennau via Albany Road, Llanedeyrn, Pentwyn, Holiday Inn',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Fairwater / Danescourt ─────────────────────────────────────────────
  {
    'number': '61',
    'name': 'City Centre – Pentrebane via Canton and Fairwater',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '62',
    'name': 'City Centre – Llandaff – Danescourt – Rhydlafar',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '64',
    'name': 'City Centre – Creigiau via Llandaff, Danescourt',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Heath / Llanishen ──────────────────────────────────────────────────
  {
    'number': '86',
    'name': 'City Centre – City Centre via Heath, Llanishen',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Penarth / Barry corridor ────────────────────────────────────────────
  {
    'number': '91',
    'name':
        'Cardiff City Centre – Flyer Summer Special – Penarth Esplanade',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '92',
    'name': 'Cardiff – Cogan – Penarth Centre',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '92B',
    'name':
        'Cardiff – Cogan – Penarth Centre – Stanwell Road – Penarth (St Luke\'s Avenue)',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '93',
    'name':
        'Cardiff – Cogan – Wordsworth Avenue – Murch – Cadoxton – Morrisons',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '93S',
    'name': 'Cardiff – Ferry Road – Redlands Road (St Cyres School)',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '94',
    'name': 'Cardiff – Barry or Morrisons',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '95',
    'name':
        'Cardiff – Llandough – Dinas Powys – Gibbonsdown – Morrisons – Barry',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '96',
    'name':
        'Cardiff – Barry via Culverhouse Cross, Colcot (Winston Square), Barry Hospital, Barry Island',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Cross-city / orbital ────────────────────────────────────────────────
  {
    'number': '101',
    'name':
        'West Cardiff – St. Mellons via Pentrebane, Llandaff, Gabalfa, Lakeside, Cyncoed, Pentwyn, Llanedeyrn',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '102',
    'name':
        'West Cardiff – Llanrumney via Pentrebane, Llandaff, Gabalfa, Lakeside, Cyncoed, Pentwyn, Llanedeyrn',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '136',
    'name': 'City Centre – Whitchurch – Creigiau',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '305',
    'name':
        'Cardiff – Dinas Powys via Cardiff Bay, Penarth Marina, Redlands Heights, Llandough Hospital',
    'operator': _kCardiffBusOperatorId,
  },
  // ── School services (6xx) ───────────────────────────────────────────────
  {
    'number': '604',
    'name': 'Leckwith – Grangetown – Ysgol Plasmawr',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '606',
    'name': 'Leckwith – Leckwith Road – Ysgol Plasmawr',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '608',
    'name':
        'James Street – Fitzalan School via Avondale Road, Channel View, Clive Street, Sloper Road',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '609',
    'name':
        'Clare Road – Fitzalan School via Clare Road, Ninian Park Road',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '610',
    'name':
        'Dumballs Road – Fitzalan School via Corporation Road, Sloper Road',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '611',
    'name':
        'Bute Street – Fitzalan School via Bute Street, City Centre, Tudor Street, Ninian Park Road',
    'operator': _kCardiffBusOperatorId,
  },
  {
    'number': '619',
    'name':
        'Cathays High School – City Centre via City Road and Crwys Road',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Barry local services ────────────────────────────────────────────────
  {
    'number': 'B1',
    'name':
        'Highlight Park – Barry Morrisons via Gibbonsdown, Barry Town Centre',
    'operator': 'BCB',
  },
  {
    'number': 'B2',
    'name':
        'Cwm Talwg Estate – Barry Morrisons via Gibbonsdown, Barry Hospital',
    'operator': 'BCB',
  },
  // ── Park & Ride ─────────────────────────────────────────────────────────
  {
    'number': 'H59',
    'name': 'East Park & Ride – A48 non-stop – Heath Hospital',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Cardiff Met shuttle ─────────────────────────────────────────────────
  {
    'number': 'M1',
    'name':
        'Cardiff Met Cyncoed – Cardiff Met Llandaff via Roath, Cathays',
    'operator': _kCardiffBusOperatorId,
  },
  // ── Tourist / seasonal ──────────────────────────────────────────────────
  {
    'number': 'Skycar',
    'name': 'Cardiff City Centre – Skycar Open Top – Cardiff Bay',
    'operator': _kCardiffBusOperatorId,
  },
];

/// Resolved [BusRoute] list built from [_kRawCardiffRoutes].
///
/// This list is the single source of truth for the local reference dataset.
/// It is loaded by [RouteRepository] as a fallback when the backend feed
/// is unavailable or returns an empty list.
final List<BusRoute> kCardiffReferenceRoutes = _kRawCardiffRoutes
    .map(
      (r) => BusRoute(
        id: 'cardiff-${r['number']!.toLowerCase().replaceAll(' ', '-')}',
        number: r['number']!,
        name: r['name']!,
        operatorId: r['operator']!,
        operatorName: r['operator'] == 'BCB'
            ? 'Barry/Coastal Bus'
            : _kCardiffBusOperatorName,
        isActive: true,
      ),
    )
    .toList();
