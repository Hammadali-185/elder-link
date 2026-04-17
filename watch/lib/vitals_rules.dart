/// Clinical-style rules for watch vitals → staff alerts.
/// HR: below 60 LOW, above 100 HIGH. BP: critical 180/120; low under 90/60; high from 130/80.
class VitalsAssessment {
  final bool isNormal;
  final bool isWarning;
  final bool isCritical;
  final String? alertReason;

  const VitalsAssessment({
    required this.isNormal,
    required this.isWarning,
    required this.isCritical,
    this.alertReason,
  });

  String get apiStatus => isNormal ? 'normal' : 'abnormal';

  static VitalsAssessment forHeartRate(int hr) {
    if (hr <= 0) {
      return const VitalsAssessment(
        isNormal: true,
        isWarning: false,
        isCritical: false,
      );
    }
    if (hr < 60) {
      return const VitalsAssessment(
        isNormal: false,
        isWarning: true,
        isCritical: false,
        alertReason: 'LOW HEART RATE',
      );
    }
    if (hr > 100) {
      return const VitalsAssessment(
        isNormal: false,
        isWarning: true,
        isCritical: false,
        alertReason: 'HIGH HEART RATE',
      );
    }
    return const VitalsAssessment(
      isNormal: true,
      isWarning: false,
      isCritical: false,
    );
  }

  static VitalsAssessment forBloodPressure(int systolic, int diastolic) {
    if (systolic <= 0 && diastolic <= 0) {
      return const VitalsAssessment(
        isNormal: true,
        isWarning: false,
        isCritical: false,
      );
    }
    if (systolic >= 180 || diastolic >= 120) {
      return const VitalsAssessment(
        isNormal: false,
        isWarning: true,
        isCritical: true,
        alertReason: 'CRITICAL BLOOD PRESSURE',
      );
    }
    if (systolic < 90 || diastolic < 60) {
      return const VitalsAssessment(
        isNormal: false,
        isWarning: true,
        isCritical: false,
        alertReason: 'LOW BLOOD PRESSURE',
      );
    }
    if (systolic >= 130 || diastolic >= 80) {
      return const VitalsAssessment(
        isNormal: false,
        isWarning: true,
        isCritical: false,
        alertReason: 'HIGH BLOOD PRESSURE',
      );
    }
    return const VitalsAssessment(
      isNormal: true,
      isWarning: false,
      isCritical: false,
    );
  }
}
