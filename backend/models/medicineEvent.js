const mongoose = require("mongoose");

/**
 * Outbox for medicine side-effects (audit / notifications). Processed asynchronously — do not call notify from HTTP handlers.
 * Collection name: MedicineEvents
 */
const MedicineEventSchema = new mongoose.Schema(
  {
    elderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Elder",
      required: true,
      index: true,
    },
    medicineId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Medicine",
      required: true,
      index: true,
    },
    type: {
      type: String,
      required: true,
      enum: ["CREATE", "UPDATE"],
    },
    /** Set when downstream notify / MedicineAssignmentEvent write succeeded. */
    processedAt: { type: Date, default: null, index: true },
    /** Present while a worker owns this row (prevents double notify under concurrent workers). */
    claimToken: { type: mongoose.Schema.Types.ObjectId },
    claimSetAt: { type: Date },
    processingError: { type: String, default: null },
    createdAt: { type: Date, default: Date.now },
  },
  { minimize: false }
);

MedicineEventSchema.index({ processedAt: 1, createdAt: 1 });

module.exports = mongoose.model("MedicineEvent", MedicineEventSchema, "MedicineEvents");
