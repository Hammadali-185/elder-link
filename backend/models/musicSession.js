const mongoose = require("mongoose");

/**
 * Metadata only — never audio bytes.
 * Timestamps are stored in UTC (MongoDB Date).
 */
const MusicSessionSchema = new mongoose.Schema(
  {
    elderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Elder",
      required: true,
      index: true,
    },
    elderName: { type: String, required: true },
    trackId: { type: String, required: true },
    title: { type: String, required: true },
    category: { type: String, required: true, index: true },
    startedAt: { type: Date, required: true },
    stoppedAt: { type: Date, default: null },
    status: {
      type: String,
      enum: ["playing", "stopped"],
      required: true,
    },
  },
  { collection: "music_sessions" }
);

MusicSessionSchema.index({ elderId: 1, status: 1, startedAt: -1 });
MusicSessionSchema.index({ status: 1, stoppedAt: 1 });
MusicSessionSchema.index({ category: 1, startedAt: -1 });
MusicSessionSchema.index({ startedAt: 1 });

module.exports = mongoose.model("MusicSession", MusicSessionSchema);
