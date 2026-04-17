const mongoose = require("mongoose");
const { isStrictObjectIdString } = require("../utils/validateObjectId");

function isStrictObjectId(v) {
  if (v == null) return false;
  return isStrictObjectIdString(String(v));
}

// DO NOT use elderName for queries or identity — API and indexes are elderId-only; elderName is display-only.
const MedicineSchema = new mongoose.Schema(
  {
    elderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Elder",
      required: [true, "elderId is required"],
      index: true,
      validate: [
        {
          validator: isStrictObjectId,
          message: "elderId must be a valid 24-char ObjectId",
        },
        {
          validator: async function elderRefExists(value) {
            if (!value) return false;
            const Elder = mongoose.model("Elder");
            let q = Elder.exists({ _id: value });
            const session =
              typeof this.$session === "function" ? this.$session() : null;
            if (session) q = q.session(session);
            return !!(await q);
          },
          message: "Referenced elder does not exist",
        },
      ],
    },
    /** Denormalized display label only — never use for queries or joins. */
    elderName: { type: String, default: "" },
    elderRoomNumber: { type: String },
    medicineName: { type: String, required: true },
    dosage: { type: String, required: true },
    time: { type: String, required: true },
    frequency: { type: String, default: "daily" },
    status: {
      type: String,
      enum: ["pending", "taken", "missed"],
      default: "pending",
    },
    takenAt: { type: Date },
    scheduledDate: { type: Date, required: true },
    /** Stable idempotency key: hash(elderId + normalized name + Karachi YMD + 5-min slotIndex); no raw time string. */
    dedupeKey: { type: String },
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now },
  },
  {
    validateBeforeSave: true,
  }
);

// Query performance for elder + day + time ordering (matches staff UI patterns).
MedicineSchema.index({ elderId: 1, scheduledDate: 1, time: 1 });
// One logical row per elder + name + time + calendar day (Karachi) — retries must not duplicate.
MedicineSchema.index({ dedupeKey: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model("Medicine", MedicineSchema);
