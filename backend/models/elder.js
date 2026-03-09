const mongoose = require("mongoose");

const ElderSchema = new mongoose.Schema({
  name: { type: String, required: true },
  roomNumber: { type: String, required: true },
  age: { type: String, required: true },
  disease: { type: String },
  status: { type: String, enum: ["stable", "need_attention"], required: true },
  gender: { type: String, enum: ["Male", "Female"], required: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model("Elder", ElderSchema);
