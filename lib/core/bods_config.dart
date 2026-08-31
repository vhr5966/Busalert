/// Configuration for the Bus Open Data Service (BODS) API.
///
/// Contains API key, operator reference, and endpoint URLs.
/// Register free at https://data.bus-data.dft.gov.uk/
library;

class BodsConfig {
  /// BODS API key (stored ONLY in backend .env in production).
  static const String apiKey = '31b6e8976e65967080fae706544cd44a355bdcc3';

  /// Operator National Operator Code (NOC).
  /// 'FCYM' = First Cymru (publishes real-time data to BODS)
  /// 'CBAO' = Cardiff Bus (does NOT publish real-time data)
  static const String operatorRef = 'FCYM';

  /// SIRI-VM endpoint for live vehicle positions.
  ///
  /// Verified against the live BODS API (2026): the `api/v1/datafeed/`
  /// endpoint serves the Vehicle Monitoring (SIRI-VM) feed and returns
  /// 200 OK with your `api_key`. The commonly-documented
  /// `api/v1/vehicle-monitoring/` path currently returns 404.
  /// Requires `api_key` on every request.
  static const String siriUrl =
      'https://data.bus-data.dft.gov.uk/api/v1/datafeed/';

  /// GTFS-RT endpoint for real-time updates (alternative feed).
  static const String gtfsRtUrl = 'https://data.bus-data.dft.gov.uk/api/v1/gtfs-rt';

  /// How often to refresh vehicle data (in seconds).
  static const int refreshIntervalSeconds = 30;

  /// Maximum age of vehicle data before considering it stale (in seconds).
  static const int maxDataAgeSeconds = 120;
}
