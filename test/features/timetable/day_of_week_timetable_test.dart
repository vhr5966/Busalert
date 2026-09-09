import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/models/bus_stop.dart';
import 'package:busalert/data/models/gtfs_model.dart';
import 'package:busalert/data/repositories/gtfs_repository.dart';
import 'package:busalert/data/repositories/timetable_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Day-of-Week Schedule Parity Tests', () {
    test('GtfsTrip operatesOn matches Monday-Friday, Saturday, Sunday correctly', () {
      const mfTrip = GtfsTrip(
        tripId: 'T_MF',
        routeId: 'R9',
        headsign: 'Sports Village',
        shapeId: 'SH1',
        serviceId: 'CB:9:009MFSH26:O:1',
      );
      const saTrip = GtfsTrip(
        tripId: 'T_SA',
        routeId: 'R9',
        headsign: 'Sports Village',
        shapeId: 'SH1',
        serviceId: 'CB:9:009SASH26:O:1',
      );
      const suTrip = GtfsTrip(
        tripId: 'T_SU',
        routeId: 'R9',
        headsign: 'Sports Village',
        shapeId: 'SH1',
        serviceId: 'CB:9:009SUSH26:O:1',
      );
      const dailyTrip = GtfsTrip(
        tripId: 'T_DY',
        routeId: 'R9',
        headsign: 'Sports Village',
        shapeId: 'SH1',
        serviceId: 'CB:9:009DYSH26:O:1',
      );

      final monday = DateTime(2026, 9, 7); // Monday
      final wednesday = DateTime(2026, 9, 9); // Wednesday
      final friday = DateTime(2026, 9, 11); // Friday
      final saturday = DateTime(2026, 9, 12); // Saturday
      final sunday = DateTime(2026, 9, 13); // Sunday

      // Monday-Friday service
      expect(mfTrip.operatesOn(monday), isTrue);
      expect(mfTrip.operatesOn(wednesday), isTrue);
      expect(mfTrip.operatesOn(friday), isTrue);
      expect(mfTrip.operatesOn(saturday), isFalse);
      expect(mfTrip.operatesOn(sunday), isFalse);

      // Saturday service
      expect(saTrip.operatesOn(saturday), isTrue);
      expect(saTrip.operatesOn(monday), isFalse);
      expect(saTrip.operatesOn(sunday), isFalse);

      // Sunday service
      expect(suTrip.operatesOn(sunday), isTrue);
      expect(suTrip.operatesOn(monday), isFalse);
      expect(suTrip.operatesOn(saturday), isFalse);

      // Daily service
      expect(dailyTrip.operatesOn(monday), isTrue);
      expect(dailyTrip.operatesOn(saturday), isTrue);
      expect(dailyTrip.operatesOn(sunday), isTrue);
    });

    test('Route 9 Strathnairn Street matches Cardiff Bus official app times exactly per day', () async {
      final gtfsRepository = GtfsRepository();
      final timetableRepository = TimetableRepository(gtfsRepository: gtfsRepository);

      const strathnairnStop = BusStop(
        id: 571010614,
        name: 'Strathnairn Street',
        latitude: 51.49186,
        longitude: -3.17106,
        routes: ['9'],
      );

      const mockRoutesCsv = 'route_id,route_short_name,route_long_name\nR9,9,Cardiff Bay - Sports Village';
      const mockTripsCsv = '''route_id,service_id,trip_id,trip_headsign,direction_id,shape_id
R9,CB:9:009MFSH26:O:1,T_MF_0617,Sports Village,0,SH1
R9,CB:9:009MFSH26:O:2,T_MF_0647,Sports Village,0,SH1
R9,CB:9:009MFSH26:O:3,T_MF_0719,Sports Village,0,SH1
R9,CB:9:009SASH26:O:1,T_SA_0705,Sports Village,0,SH1
R9,CB:9:009SASH26:O:2,T_SA_0805,Sports Village,0,SH1
R9,CB:9:009SASH26:O:3,T_SA_0835,Sports Village,0,SH1
R9,CB:9:009SASH26:O:4,T_SA_0906,Sports Village,0,SH1
R9,CB:9:009SASH26:O:5,T_SA_0936,Sports Village,0,SH1
R9,CB:9:009SUSH26:O:1,T_SU_0714,Sports Village,0,SH1
R9,CB:9:009SUSH26:O:2,T_SU_0814,Sports Village,0,SH1''';

      const mockStopsCsv = 'stop_id,stop_name,stop_lat,stop_lon\n571010614,Strathnairn Street,51.49186,-3.17106';
      const mockStopTimesCsv = '''trip_id,arrival_time,departure_time,stop_id,stop_sequence
T_MF_0617,06:17:00,06:17:00,571010614,1
T_MF_0647,06:47:00,06:47:00,571010614,1
T_MF_0719,07:19:00,07:19:00,571010614,1
T_SA_0705,07:05:00,07:05:00,571010614,1
T_SA_0805,08:05:00,08:05:00,571010614,1
T_SA_0835,08:35:00,08:35:00,571010614,1
T_SA_0906,09:06:00,09:06:00,571010614,1
T_SA_0936,09:36:00,09:36:00,571010614,1
T_SU_0714,07:14:00,07:14:00,571010614,1
T_SU_0814,08:14:00,08:14:00,571010614,1''';

      const mockShapesCsv = 'shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence\nSH1,51.49186,-3.17106,1';

      await gtfsRepository.loadGtfsData(
        routesCsv: mockRoutesCsv,
        tripsCsv: mockTripsCsv,
        stopsCsv: mockStopsCsv,
        stopTimesCsv: mockStopTimesCsv,
        shapesCsv: mockShapesCsv,
      );

      // On Saturday at 05:41 (the exact scenario from the Cardiff Bus official app comparison):
      final saturdayDate = DateTime(2026, 9, 12, 5, 41);
      final satDepartures = await timetableRepository.getRealTimeTimetable(
        stop: strathnairnStop,
        routeNumber: '9',
        relativeTo: saturdayDate,
      );

      // Must strictly return Saturday departures: 07:05, 08:05, 08:35, 09:06, 09:36
      expect(satDepartures.length, equals(5));
      expect(satDepartures.map((d) => d.scheduledDeparture).toList(), equals([
        '07:05',
        '08:05',
        '08:35',
        '09:06',
        '09:36',
      ]));

      // On Monday at 05:41:
      final mondayDate = DateTime(2026, 9, 7, 5, 41);
      final monDepartures = await timetableRepository.getRealTimeTimetable(
        stop: strathnairnStop,
        routeNumber: '9',
        relativeTo: mondayDate,
      );

      // Must strictly return Monday departures: 06:17, 06:47, 07:19
      expect(monDepartures.length, equals(3));
      expect(monDepartures.map((d) => d.scheduledDeparture).toList(), equals([
        '06:17',
        '06:47',
        '07:19',
      ]));

      // On Sunday at 05:41:
      final sundayDate = DateTime(2026, 9, 13, 5, 41);
      final sunDepartures = await timetableRepository.getRealTimeTimetable(
        stop: strathnairnStop,
        routeNumber: '9',
        relativeTo: sundayDate,
      );

      // Must strictly return Sunday departures: 07:14, 08:14
      expect(sunDepartures.length, equals(2));
      expect(sunDepartures.map((d) => d.scheduledDeparture).toList(), equals([
        '07:14',
        '08:14',
      ]));
    });
  });
}
