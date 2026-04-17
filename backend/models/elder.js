const mongoose = require("mongoose");

// Cascade hooks delete Medicine rows by elderId when an Elder is removed — do not rely on controllers alone.
const ElderSchema = new mongoose.Schema({
  name: { type: String, required: true },
  roomNumber: { type: String, required: true },
  age: { type: String, required: true },
  disease: { type: String },
  status: { type: String, enum: ["stable", "need_attention"], required: true },
  gender: { type: String, enum: ["Male", "Female"], required: true },
  /** Stable watch API [Reading.username] for this resident — used for purge of anonymous rows. */
  readingUsername: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

ElderSchema.index({ name: 1, roomNumber: 1 }, { unique: true });

async function cascadeDeleteMedicinesForElderDocs(docs) {
  if (!docs?.length) return;
  const Medicine = mongoose.model("Medicine");
  for (const d of docs) {
    if (d?._id) await Medicine.deleteMany({ elderId: d._id });
  }
}

ElderSchema.pre("findOneAndDelete", async function () {
  const doc = await this.model.findOne(this.getFilter()).select("_id");
  if (doc) await cascadeDeleteMedicinesForElderDocs([doc]);
});

ElderSchema.pre("deleteOne", { document: false, query: true }, async function () {
  const docs = await this.model.find(this.getFilter()).select("_id");
  await cascadeDeleteMedicinesForElderDocs(docs);
});

ElderSchema.pre("deleteMany", { document: false, query: true }, async function () {
  const docs = await this.model.find(this.getFilter()).select("_id");
  await cascadeDeleteMedicinesForElderDocs(docs);
});

module.exports = mongoose.model("Elder", ElderSchema);
