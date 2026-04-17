import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _tzInitialized = false;

/// Call once before using Karachi helpers (safe to call multiple times).
void ensureKarachiTimeZones() {
  if (_tzInitialized) return;
  tzdata.initializeTimeZones();
  _tzInitialized = true;
}

tz.Location get karachiLocation {
  ensureKarachiTimeZones();
  return tz.getLocation('Asia/Karachi');
}

/// Wall clock in Asia/Karachi as a local [DateTime] (use only for display).
DateTime nowKarachiWallClock() {
  final k = tz.TZDateTime.now(karachiLocation);
  return DateTime(k.year, k.month, k.day, k.hour, k.minute, k.second);
}

/// Converts an instant (UTC or local) to Karachi wall time for display.
DateTime utcInstantToKarachiWall(DateTime instant) {
  ensureKarachiTimeZones();
  final utc = instant.toUtc();
  final k = tz.TZDateTime.from(utc, karachiLocation);
  return DateTime(k.year, k.month, k.day, k.hour, k.minute, k.second);
}

/// `YYYY-MM-DD` for **today** in Asia/Karachi (medicine API day filter).
String karachiTodayYmd() {
  final k = tz.TZDateTime.now(karachiLocation);
  final mo = k.month.toString().padLeft(2, '0');
  final d = k.day.toString().padLeft(2, '0');
  return '${k.year}-$mo-$d';
}
