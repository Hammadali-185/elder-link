const crypto = require("crypto");
const mongoose = require("mongoose");
const Elder = require("../models/elder");
const Medicine = require("../models/medicine");
const MedicineAssignmentEvent = require("../models/medicineAssignmentEvent");
const { enqueueMedicineEvent } = require("../services/medicineEventOutbox");
const { assertValidObjectId } = require("../utils/validateObjectId");

/** 5-minute grid for idempotency — raw `time` strings are not used in dedupeKey. */
const DEDUPE_SLOT_MINUTES = 5;

/** `YYYY-MM-DD` civil date in Asia/Karachi for an instant (used for idempotency day bucket). */
function karachiYmdFromInstant(d = new Date()) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Karachi",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(d);
}

/** Whole minutes since local midnight in Asia/Karachi for this instant. */
function karachiMinutesSinceMidnight(instant) {
  const d = new Date(instant);
  if (Number.isNaN(d.getTime())) return 0;
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Karachi",
    hour: "numeric",
    minute: "numeric",
    hour12: false,
  }).formatToParts(d);
  const hour = Number(parts.find((p) => p.type === "hour")?.value ?? 0);
  const minute = Number(parts.find((p) => p.type === "minute")?.value ?? 0);
  return hour * 60 + minute;
}

function parseYmd(dateStr) {
  const s = String(dateStr).trim().split("T")[0];
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  return { y: +m[1], mo: +m[2], d: +m[3] };
}

function karachiCivilDayUtcBounds(y, mo, d) {
  const start = new Date(Date.UTC(y, mo - 1, d, 0, 0, 0, 0) - 5 * 60 * 60 * 1000);
  const end = new Date(
    Date.UTC(y, mo - 1, d, 23, 59, 59, 999) - 5 * 60 * 60 * 1000
  );
  return { start, end };
}

/**
 * Idempotency / dedupe: elderId + normalized medicineName + Karachi YMD + 5-min slotIndex only (no raw time).
 * Optional X-Idempotency-Key / body.idempotencyKey is mixed in so clients can scope retries.
 */
function computeMedicineDedupeKey({
  elderId,
  medicineName,
  scheduledDate,
  clientIdempotencyExtra,
}) {
  const inst = new Date(scheduledDate);
  const dayKey = karachiYmdFromInstant(inst);
  const nameNorm = String(medicineName || "").trim().toLowerCase();
  const minutes = karachiMinutesSinceMidnight(inst);
  const slotIndex = Math.floor(minutes / DEDUPE_SLOT_MINUTES);
  const parts = [
    String(clientIdempotencyExtra || "").trim(),
    String(elderId),
    nameNorm,
    dayKey,
    String(slotIndex),
  ];
  return crypto.createHash("sha256").update(parts.join("|"), "utf8").digest("hex");
}

function transactionUnsupportedError(err) {
  const msg = String(err?.message || "");
  const code = err?.codeName || err?.code;
  return (
    code === 20 ||
    code === "IllegalOperation" ||
    /Transaction|replica set|51091|IllegalOperation|mongos|multi-document transaction/i.test(
      msg
    )
  );
}

function applyElderDenorm(body, elder) {
  body.elderId = elder._id;
  body.elderName = elder.name;
  if (body.elderRoomNumber == null || String(body.elderRoomNumber).trim() === "") {
    body.elderRoomNumber = elder.roomNumber;
  }
}

async function findIdempotentMedicine(dedupeKey) {
  if (!dedupeKey) return null;
  return Medicine.findOne({ dedupeKey });
}

function respondIdempotentReplay(res, doc) {
  const o = doc.toObject ? doc.toObject() : doc;
  return res.status(200).json({ ...o, idempotentReplay: true });
}

async function handleDuplicateKeyRace(dedupeKey) {
  const dup = await Medicine.findOne({ dedupeKey });
  return dup;
}

// DO NOT remove transaction path — it prevents orphan medicines under concurrent elder deletes; fallback only when Mongo has no transaction support.
/**
 * POST /medicines — create medicine (transaction when available; safe fallback on standalone Mongo).
 */
exports.createMedicine = async (req, res) => {
  try {
    const body = { ...req.body };
    assertValidObjectId(body.elderId, "elderId", { logRejection: true });
    delete body._id;

    if (!body.scheduledDate) {
      return res.status(400).json({ error: "scheduledDate is required" });
    }
    const scheduledDate = new Date(body.scheduledDate);
    if (Number.isNaN(scheduledDate.getTime())) {
      return res.status(400).json({ error: "Invalid scheduledDate" });
    }
    body.scheduledDate = scheduledDate;

    const clientExtra =
      (req.get("x-idempotency-key") || body.idempotencyKey || "").trim();
    delete body.idempotencyKey;

    body.dedupeKey = computeMedicineDedupeKey({
      elderId: body.elderId,
      medicineName: body.medicineName,
      scheduledDate: body.scheduledDate,
      clientIdempotencyExtra: clientExtra,
    });

    const existing = await findIdempotentMedicine(body.dedupeKey);
    if (existing) {
      return respondIdempotentReplay(res, existing);
    }

    const session = await mongoose.startSession();
    let saved;
    try {
      await session.withTransaction(async () => {
        const elder = await Elder.findById(body.elderId).session(session);
        if (!elder) {
          console.warn(
            "[medicine] elder not found during medicine creation:",
            String(body.elderId)
          );
          const err = new Error("Elder not found for elderId");
          err.status = 400;
          throw err;
        }
        applyElderDenorm(body, elder);
        const medicine = new Medicine(body);
        await medicine.save({ session });
        // Outbox in same transaction as Medicine — no direct notify (worker delivers MedicineAssignmentEvent).
        await enqueueMedicineEvent(
          {
            elderId: medicine.elderId,
            medicineId: medicine._id,
            type: "CREATE",
          },
          session
        );
        saved = medicine;
      });
    } catch (txnErr) {
      const status = txnErr.status;
      if (status === 400) {
        return res.status(400).json({ error: txnErr.message });
      }
      if (txnErr.code === 11000) {
        const dup = await handleDuplicateKeyRace(body.dedupeKey);
        if (dup) return respondIdempotentReplay(res, dup);
        return res.status(409).json({ error: "Duplicate medicine (race); retry" });
      }
      if (!transactionUnsupportedError(txnErr)) {
        console.warn("[medicine] createMedicine transaction aborted:", txnErr.message);
        return res.status(500).json({ error: txnErr.message });
      }
      return await createMedicineWithoutTransaction(res, body);
    } finally {
      await session.endSession().catch(() => {});
    }

    return res.status(201).json(saved);
  } catch (error) {
    const code = error.status || 400;
    return res.status(code).json({ error: error.message });
  }
};

/**
 * Standalone MongoDB: save, then final commit gate (lean elder re-fetch) before notify + JSON — no notifications on invalid state.
 * DO NOT use elderName for lookups — elderId only.
 */
async function createMedicineWithoutTransaction(res, body) {
  const elder = await Elder.findById(body.elderId);
  if (!elder) {
    console.warn(
      "[medicine] createMedicine(fallback): elderId not found:",
      String(body.elderId)
    );
    return res.status(400).json({ error: "Elder not found for elderId" });
  }
  applyElderDenorm(body, elder);

  let medicine;
  try {
    medicine = new Medicine(body);
    await medicine.save();
  } catch (saveErr) {
    if (saveErr.code === 11000) {
      const dup = await handleDuplicateKeyRace(body.dedupeKey);
      if (dup) return respondIdempotentReplay(res, dup);
      return res.status(409).json({ error: "Duplicate medicine (race); retry" });
    }
    throw saveErr;
  }

  // Final commit gate (non-tx path): lean re-read elder BEFORE response or notification — no side effects on invalid state.
  const elderFinal = await Elder.findById(medicine.elderId).select("_id").lean();
  if (!elderFinal) {
    await Medicine.findByIdAndDelete(medicine._id);
    console.warn(
      "[medicine] createMedicine(fallback): final gate failed — elder gone; orphan removed, notify skipped:",
      String(medicine._id)
    );
    return res.status(409).json({
      error: "Elder no longer exists; medicine not created",
    });
  }

  try {
    await enqueueMedicineEvent(
      {
        elderId: medicine.elderId,
        medicineId: medicine._id,
        type: "CREATE",
      },
      null
    );
  } catch (outboxErr) {
    console.error(
      "[medicine] OUTBOX enqueue failed after save (fallback):",
      outboxErr.message
    );
    return res.status(503).json({
      error:
        "Medicine saved but notification queue failed; retry or POST /api/medicine-events/process",
      medicineId: medicine._id,
    });
  }
  return res.status(201).json(medicine);
}

/** Dev-only: requires ELDERLINK_DEBUG_ROUTES=1 — shows dedupe key for a payload without writing. */
exports.debugDedupePreview = (req, res) => {
  if (process.env.ELDERLINK_DEBUG_ROUTES !== "1") {
    return res.status(404).json({ error: "Not found" });
  }
  try {
    const b = req.body || {};
    assertValidObjectId(b.elderId, "elderId");
    if (!b.scheduledDate || b.medicineName == null) {
      return res.status(400).json({
        error: "elderId, medicineName, scheduledDate required",
      });
    }
    const sd = new Date(b.scheduledDate);
    const minutes = karachiMinutesSinceMidnight(sd);
    const slotIndex = Math.floor(minutes / DEDUPE_SLOT_MINUTES);
    const key = computeMedicineDedupeKey({
      elderId: b.elderId,
      medicineName: b.medicineName,
      scheduledDate: sd,
      clientIdempotencyExtra: (req.get("x-idempotency-key") || b.idempotencyKey || "").trim(),
    });
    return res.status(200).json({
      dedupeKey: key,
      karachiDay: karachiYmdFromInstant(sd),
      slotIndex,
      karachiMinutesSinceMidnight: minutes,
      slotMinutes: DEDUPE_SLOT_MINUTES,
    });
  } catch (e) {
    const code = e.status || 400;
    return res.status(code).json({ error: e.message });
  }
};

const PATCH_ALLOWED = new Set([
  "medicineName",
  "dosage",
  "time",
  "frequency",
  "scheduledDate",
  "status",
  "takenAt",
  "elderRoomNumber",
]);

exports.patchMedicine = async (req, res) => {
  try {
    assertValidObjectId(req.params.id, "medicine id");
    const raw = { ...req.body };
    delete raw._id;
    if (raw.elderId !== undefined || raw.elderName !== undefined) {
      return res.status(400).json({
        error: "elderId and elderName cannot be modified on a medicine",
      });
    }
    const updates = {};
    for (const k of Object.keys(raw)) {
      if (PATCH_ALLOWED.has(k)) updates[k] = raw[k];
    }
    updates.updatedAt = new Date();

    const medicine = await Medicine.findByIdAndUpdate(req.params.id, updates, {
      new: true,
      runValidators: true,
    });
    if (!medicine) {
      return res.status(404).json({ error: "Medicine not found" });
    }
    try {
      await enqueueMedicineEvent(
        {
          elderId: medicine.elderId,
          medicineId: medicine._id,
          type: "UPDATE",
        },
        null
      );
    } catch (outboxErr) {
      console.error("[medicine] OUTBOX enqueue failed (patch):", outboxErr.message);
      return res.status(503).json({
        error:
          "Medicine updated but notification queue failed; retry or POST /api/medicine-events/process",
        medicine,
      });
    }
    res.json(medicine);
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({ error: error.message });
    }
    const code = error.status || 400;
    res.status(code).json({ error: error.message });
  }
};

exports.getMedicines = async (req, res) => {
  try {
    if (
      req.query.elderName != null &&
      String(req.query.elderName).trim() !== ""
    ) {
      return res.status(400).json({
        error: "elderName query is not supported; use elderId only",
      });
    }

    const { date, elderId } = req.query;
    assertValidObjectId(elderId, "elderId");
    const elder = await Elder.findById(elderId);
    if (!elder) {
      return res.status(404).json({ error: "Elder not found" });
    }

    let ymd = date ? parseYmd(date) : null;
    if (!ymd) {
      ymd = parseYmd(karachiYmdFromInstant(new Date()));
    }
    if (!ymd) {
      return res.status(400).json({ error: "Invalid date query" });
    }
    const { start, end } = karachiCivilDayUtcBounds(ymd.y, ymd.mo, ymd.d);
    const dayRange = { $gte: start, $lte: end };

    const medicines = await Medicine.find({
      elderId: elder._id,
      scheduledDate: dayRange,
    }).sort({ time: 1 });
    res.json(medicines);
  } catch (error) {
    const code = error.status || 500;
    res.status(code).json({ error: error.message });
  }
};

exports.updateMedicineStatus = async (req, res) => {
  try {
    assertValidObjectId(req.params.id, "medicine id");
    const { status } = req.body;
    const medicine = await Medicine.findByIdAndUpdate(
      req.params.id,
      {
        status,
        takenAt: status === "taken" ? new Date() : null,
        updatedAt: new Date(),
      },
      { new: true }
    );

    if (!medicine) {
      return res.status(404).json({ error: "Medicine not found" });
    }

    const latestEvent = await MedicineAssignmentEvent.findOne({
      medicineId: medicine._id,
    }).sort({ assignedTime: -1 });
    if (latestEvent) {
      latestEvent.taken = status === "taken";
      latestEvent.takenAt = status === "taken" ? new Date() : null;
      await latestEvent.save();
    }

    res.json(medicine);
  } catch (error) {
    const code = error.status || 400;
    res.status(code).json({ error: error.message });
  }
};

exports.deleteMedicine = async (req, res) => {
  try {
    assertValidObjectId(req.params.id, "medicine id");
    const medicine = await Medicine.findByIdAndDelete(req.params.id);
    if (!medicine) {
      return res.status(404).json({ error: "Medicine not found" });
    }
    res.json({ message: "Medicine deleted successfully" });
  } catch (error) {
    const code = error.status || 400;
    res.status(code).json({ error: error.message });
  }
};
