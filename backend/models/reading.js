const mongoose = require("mongoose");

const ReadingSchema = new mongoose.Schema({
  username: { type: String, required: true },
  bp: { type: Number, required: true },
  status: { type: String, enum: ["normal", "abnormal"], required: true },
  emergency: { type: Boolean, default: false },
  timestamp: { type: Date, default: Date.now },
  personName: { type: String },
  gender: { type: String },
  age: { type: String },
  disease: { type: String },
  roomNumber: { type: String }
});

module.exports = mongoose.model("Reading", ReadingSchema);
