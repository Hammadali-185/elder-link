const MedicineAssignmentEvent = require("../models/medicineAssignmentEvent");

/**
 * Persist medicine assignment audit row (watch uses polling + local alerts).
 * @param {import('mongoose').Document} medicineDoc saved Medicine
 * @param {'assigned'|'updated'} kind
 */
async function notifyMedicineChange(medicineDoc, _kind = "assigned") {
  const patientId = medicineDoc.elderName;
  if (!patientId || !String(patientId).trim()) return;

  try {
    await MedicineAssignmentEvent.create({
      patientId: String(patientId).trim(),
      medicineId: medicineDoc._id,
      assignedTime: new Date(),
      taken: false,
      medicineName: medicineDoc.medicineName,
      dosage: medicineDoc.dosage,
      time: medicineDoc.time,
    });
  } catch (e) {
    console.error("MedicineAssignmentEvent create failed:", e.message);
  }
}

module.exports = { notifyMedicineChange };
