const mongoose = require("mongoose");

const ReadingSchema = new mongoose.Schema({
  elderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Elder",
    index: true,
  },
  username: { type: String, required: true },
  /** Systolic when BP is present; legacy single BP value. */
  bp: { type: Number, default: 0 },
  bpDiastolic: { type: Number, default: null },
  heartRate: { type: Number, default: 0 },
  status: { type: String, enum: ["normal", "abnormal"], required: true },
  emergency: { type: Boolean, default: false },
  /** True for life-threatening BP (e.g. ≥180/≥120); not the same as panic button. */
  vitalsUrgent: { type: Boolean, default: false },
  /** e.g. LOW HEART RATE, CRITICAL BLOOD PRESSURE */
  alertReason: { type: String, default: null },
  timestamp: { type: Date, default: Date.now },
  personName: { type: String },
  gender: { type: String },
  age: { type: String },
  disease: { type: String },
  roomNumber: { type: String },
});

module.exports = mongoose.model("Reading", ReadingSchema);
