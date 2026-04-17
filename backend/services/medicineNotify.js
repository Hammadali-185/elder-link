const MedicineAssignmentEvent = require("../models/medicineAssignmentEvent");

/**
 * Persist medicine assignment audit row (watch uses polling + local alerts).
 * Invoked only from medicineEventOutbox worker — errors must propagate so the outbox can retry.
 * @param {import('mongoose').Document|object} medicineDoc saved Medicine (doc or lean)
 * @param {'assigned'|'updated'} kind
 */
async function notifyMedicineChange(medicineDoc, _kind = "assigned") {
  if (!medicineDoc.elderId) return;
  const patientId = String(medicineDoc.elderId);

  await MedicineAssignmentEvent.create({
    patientId,
    elderId: medicineDoc.elderId,
    medicineId: medicineDoc._id,
    assignedTime: new Date(),
    taken: false,
    medicineName: medicineDoc.medicineName,
    dosage: medicineDoc.dosage,
    time: medicineDoc.time,
  });
}

module.exports = { notifyMedicineChange };
