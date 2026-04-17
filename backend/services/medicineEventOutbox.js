const mongoose = require("mongoose");
const MedicineEvent = require("../models/medicineEvent");
const Medicine = require("../models/medicine");
const { notifyMedicineChange } = require("./medicineNotify");

const CLAIM_STALE_MS = 120000;

/**
 * Queue a medicine notification — same DB write path as medicine (use session when inside a transaction).
 * Identity is elderId + medicineId only (never elderName).
 */
async function enqueueMedicineEvent({ elderId, medicineId, type }, session) {
  const doc = {
    elderId,
    medicineId,
    type,
  };
  if (session) {
    await MedicineEvent.create([doc], { session });
  } else {
    await MedicineEvent.create(doc);
  }
}

async function abandonStaleClaims() {
  const cutoff = new Date(Date.now() - CLAIM_STALE_MS);
  await MedicineEvent.updateMany(
    {
      processedAt: null,
      claimSetAt: { $lt: cutoff },
      claimToken: { $exists: true },
    },
    {
      $unset: { claimToken: 1, claimSetAt: 1 },
      $set: { processingError: "claim expired; retry" },
    }
  );
}

/**
 * Process one pending event (atomic claim). Safe to call from interval or HTTP trigger.
 * For multiple app instances, use one worker process or external lock — see comments in model.
 */
async function processMedicineEventOnce() {
  await abandonStaleClaims();

  const token = new mongoose.Types.ObjectId();
  const ev = await MedicineEvent.findOneAndUpdate(
    {
      processedAt: null,
      $or: [{ claimToken: { $exists: false } }, { claimToken: null }],
    },
    { $set: { claimToken: token, claimSetAt: new Date(), processingError: null } },
    { sort: { createdAt: 1 }, new: true }
  );

  if (!ev) {
    return { processed: false };
  }

  try {
    const med = await Medicine.findById(ev.medicineId);
    if (!med) {
      await MedicineEvent.updateOne(
        { _id: ev._id },
        {
          $set: {
            processedAt: new Date(),
            processingError: "medicine missing",
          },
          $unset: { claimToken: 1, claimSetAt: 1 },
        }
      );
      return { processed: true, skipped: "medicine missing" };
    }

    await notifyMedicineChange(med, ev.type === "UPDATE" ? "updated" : "assigned");

    await MedicineEvent.updateOne(
      { _id: ev._id },
      {
        $set: { processedAt: new Date(), processingError: null },
        $unset: { claimToken: 1, claimSetAt: 1 },
      }
    );
    return { processed: true };
  } catch (e) {
    await MedicineEvent.updateOne(
      { _id: ev._id },
      {
        $unset: { claimToken: 1, claimSetAt: 1 },
        $set: { processingError: String(e.message || e) },
      }
    );
    return { processed: true, error: e.message };
  }
}

async function processMedicineEventsBatch(limit = 50) {
  let n = 0;
  for (let i = 0; i < limit; i++) {
    const r = await processMedicineEventOnce();
    if (!r.processed) break;
    n += 1;
  }
  return n;
}

module.exports = {
  enqueueMedicineEvent,
  processMedicineEventOnce,
  processMedicineEventsBatch,
};
