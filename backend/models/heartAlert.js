const mongoose = require("mongoose");

const heartAlertSchema = new mongoose.Schema(
  {
    elderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Elder",
      index: true,
    },
    username: {
      type: String,
      required: true,
    },
    personName: {
      type: String,
    },
    roomNumber: {
      type: String,
    },
    heartRate: {
      type: Number,
      required: true,
    },
    status: {
      type: String,
      required: true,
      enum: ["normal", "abnormal"],
      default: "abnormal",
    },
    timestamp: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("HeartAlert", heartAlertSchema);
