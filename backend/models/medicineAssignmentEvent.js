const mongoose = require("mongoose");

/** Audit / real-time trail for medicine assignments (watch ack updates [taken]). */
const MedicineAssignmentEventSchema = new mongoose.Schema({
  patientId: { type: String, required: true, index: true },
  medicineId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Medicine",
    required: true,
    index: true,
  },
  assignedTime: { type: Date, default: Date.now, index: true },
  taken: { type: Boolean, default: false },
  takenAt: { type: Date },
  medicineName: { type: String },
  dosage: { type: String },
  time: { type: String },
});

module.exports = mongoose.model("MedicineAssignmentEvent", MedicineAssignmentEventSchema);
