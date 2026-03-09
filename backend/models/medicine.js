const mongoose = require("mongoose");

const MedicineSchema = new mongoose.Schema({
  elderName: { type: String, required: true },
  elderRoomNumber: { type: String },
  medicineName: { type: String, required: true },
  dosage: { type: String, required: true }, // e.g., "500mg"
  time: { type: String, required: true }, // e.g., "09:00", "14:30"
  frequency: { type: String, default: "daily" }, // daily, weekly, etc.
  status: { type: String, enum: ["pending", "taken", "missed"], default: "pending" },
  takenAt: { type: Date },
  scheduledDate: { type: Date, required: true }, // Date when medicine should be taken
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model("Medicine", MedicineSchema);
