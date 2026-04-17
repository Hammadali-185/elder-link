const mongoose = require("mongoose");
const Elder = require("../models/elder");
const Reading = require("../models/reading");
const Medicine = require("../models/medicine");
const MusicSession = require("../models/musicSession");
const HeartAlert = require("../models/heartAlert");
const MedicineAssignmentEvent = require("../models/medicineAssignmentEvent");
const { isStrictObjectIdString } = require("../utils/validateObjectId");

function escapeRegex(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Update Elder by Mongo id from watch My Info. Create new elders with POST /api/elders.
 */
exports.syncFromWatch = async (req, res) => {
  try {
    const rawId = req.body.elderId;
    if (rawId == null || String(rawId).trim() === "") {
      return res.status(400).json({ error: "elderId is required" });
    }
    if (!isStrictObjectIdString(rawId)) {
      return res.status(400).json({ error: "Invalid elderId" });
    }

    const elder = await Elder.findById(rawId);
    if (!elder) {
      return res.status(404).json({ error: "Elder not found" });
    }

    const name = (req.body.name || "").trim();
    if (!name) {
      return res.status(400).json({ error: "name is required" });
    }
    if (elder.name.trim().toLowerCase() !== name.toLowerCase()) {
      return res.status(400).json({ error: "name does not match elderId" });
    }

    const roomNumber = (req.body.roomNumber || "").trim() || "—";
    const age = (req.body.age || "").trim() || "—";
    const gender = req.body.gender === "Female" ? "Female" : "Male";
    const diseaseRaw = (req.body.disease || "").trim();
    const disease = diseaseRaw || undefined;
    const readingUsername = (req.body.readingUsername || "").trim() || undefined;

    elder.roomNumber = roomNumber;
    elder.age = age;
    elder.gender = gender;
    elder.disease = disease;
    if (readingUsername) elder.readingUsername = readingUsername;
    elder.updatedAt = new Date();
    await elder.save();
    return res.json(elder);
  } catch (error) {
    console.error("syncFromWatch:", error);
    return res.status(400).json({ error: error.message });
  }
};

exports.createElder = async (req, res) => {
  try {
    const elder = new Elder(req.body);
    const saved = await elder.save();
    res.status(201).json(saved);
  } catch (error) {
    console.error("Error creating elder:", error);
    if (error.code === 11000) {
      return res.status(409).json({
        error: "An elder with this name and room number already exists",
      });
    }
    res.status(400).json({ error: error.message });
  }
};

exports.getElders = async (req, res) => {
  try {
    const elders = await Elder.find().sort({ createdAt: -1 });
    res.json(elders);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getElderById = async (req, res) => {
  try {
    const id = String(req.params.id ?? "").trim();
    if (!id) {
      return res.status(400).json({ error: "id is required" });
    }
    if (!isStrictObjectIdString(id)) {
      return res.status(400).json({ error: "Invalid id" });
    }
    const elder = await Elder.findById(id);
    if (!elder) {
      return res.status(404).json({ error: "Elder not found" });
    }
    res.json(elder);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.updateElder = async (req, res) => {
  try {
    const id = String(req.params.id ?? "").trim();
    if (!id) {
      return res.status(400).json({ error: "id is required" });
    }
    if (!isStrictObjectIdString(id)) {
      return res.status(400).json({ error: "Invalid id" });
    }
    req.body.updatedAt = Date.now();
    const elder = await Elder.findByIdAndUpdate(id, req.body, {
      new: true,
      runValidators: true,
    });
    if (!elder) {
      return res.status(404).json({ error: "Elder not found" });
    }
    res.json(elder);
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        error: "An elder with this name and room number already exists",
      });
    }
    res.status(400).json({ error: error.message });
  }
};

/**
 * Deletes readings, medicines, music sessions, heart alerts, medicine events, and elder row(s)
 * for [canonicalName], optionally scoped to a single [elderDoc] Mongo document.
 *
 * [readingUsername] optional: API `username` stored on readings (stable watch id or legacy "Watch User").
 * Removes leftover rows where `username` equals that value and either `personName` matches this elder
 * or `personName` is empty (anonymous vitals for that device).
 */
async function purgeElderDataCore({
  canonicalName,
  elderDoc,
  readingUsername = null,
}) {
  const nameRegex = new RegExp(`^${escapeRegex(canonicalName)}$`, "i");

  const ruParam = readingUsername != null ? String(readingUsername).trim() : "";
  const ruDoc =
    elderDoc && elderDoc.readingUsername
      ? String(elderDoc.readingUsername).trim()
      : "";
  const effectiveDeviceUsername = ruParam || ruDoc;

  let byIdReads = 0;
  let byIdMeds = 0;
  let byIdMusic = 0;
  let byIdHeart = 0;
  let byIdEvents = 0;
  if (elderDoc) {
    const eid = elderDoc._id;
    const [a, b, c, d, e] = await Promise.all([
      Reading.deleteMany({ elderId: eid }),
      Medicine.deleteMany({ elderId: eid }),
      MusicSession.deleteMany({ elderId: eid }),
      HeartAlert.deleteMany({ elderId: eid }),
      MedicineAssignmentEvent.deleteMany({ elderId: eid }),
    ]);
    byIdReads = a.deletedCount || 0;
    byIdMeds = b.deletedCount || 0;
    byIdMusic = c.deletedCount || 0;
    byIdHeart = d.deletedCount || 0;
    byIdEvents = e.deletedCount || 0;
  }

  const musicFilter = elderDoc
    ? { $or: [{ elderId: elderDoc._id }, { elderName: nameRegex }] }
    : { elderName: nameRegex };

  const [readingsR, medsR, musicR, heartR, eventsR] = await Promise.all([
    Reading.deleteMany({
      $or: [{ personName: nameRegex }, { username: nameRegex }],
    }),
    elderDoc
      ? Promise.resolve({ deletedCount: 0 })
      : Medicine.deleteMany({ elderName: nameRegex }),
    MusicSession.deleteMany(musicFilter),
    HeartAlert.deleteMany({
      $or: [{ personName: nameRegex }, { username: nameRegex }],
    }),
    MedicineAssignmentEvent.deleteMany({ patientId: nameRegex }),
  ]);

  let readingsExtra = 0;
  let heartExtra = 0;
  const ru = effectiveDeviceUsername;
  if (ru.length > 0) {
    const userRegex = new RegExp(`^${escapeRegex(ru)}$`, "i");
    const deviceScoped = {
      $and: [
        { username: userRegex },
        {
          $or: [
            { personName: nameRegex },
            { personName: null },
            { personName: "" },
            { personName: { $exists: false } },
          ],
        },
      ],
    };
    const [r2, h2] = await Promise.all([
      Reading.deleteMany(deviceScoped),
      HeartAlert.deleteMany(deviceScoped),
    ]);
    readingsExtra = r2.deletedCount || 0;
    heartExtra = h2.deletedCount || 0;
  }

  let elderDeleted = 0;
  if (elderDoc) {
    await Elder.findByIdAndDelete(elderDoc._id);
    elderDeleted = 1;
  } else {
    const er = await Elder.deleteMany({ name: nameRegex });
    elderDeleted = er.deletedCount || 0;
  }

  return {
    elderName: canonicalName,
    deleted: {
      readings:
        byIdReads +
        (readingsR.deletedCount || 0) +
        readingsExtra,
      medicines: byIdMeds + (medsR.deletedCount || 0),
      musicSessions: byIdMusic + (musicR.deletedCount || 0),
      heartAlerts: byIdHeart + (heartR.deletedCount || 0) + heartExtra,
      medicineEvents: byIdEvents + (eventsR.deletedCount || 0),
      elderRecords: elderDeleted,
    },
  };
}

/** DELETE /api/elders/:id — same data removal as POST purge (not only the Elder row). */
exports.deleteElder = async (req, res) => {
  try {
    const id = String(req.params.id ?? "").trim();
    if (!id) {
      return res.status(400).json({ error: "id is required" });
    }
    if (!isStrictObjectIdString(id)) {
      return res.status(400).json({ error: "Invalid id" });
    }
    const elder = await Elder.findById(id);
    if (!elder) {
      return res.status(404).json({ error: "Elder not found" });
    }
    await Medicine.deleteMany({ elderId: elder._id });
    const canonicalName = elder.name.trim();
    const result = await purgeElderDataCore({
      canonicalName,
      elderDoc: elder,
    });
    return res.json({
      ok: true,
      message: "Elder and all related data deleted",
      elderName: result.elderName,
      deleted: result.deleted,
    });
  } catch (error) {
    console.error("deleteElder:", error);
    return res.status(500).json({ error: error.message });
  }
};

/**
 * POST /api/elders/purge
 * Body: { elderName: string (required), elderId?: string, readingUsername?: string }
 * readingUsername: raw Reading.username from the watch (stable id or "Watch User") so anonymous rows are removed.
 * Removes elder profile (if any), readings, medicines, music sessions, heart alerts, and medicine events for that person.
 */
exports.purgeElderData = async (req, res) => {
  try {
    const rawName = (req.body.elderName || "").trim();
    const rawId = req.body.elderId;

    let elder = null;
    let canonicalName = rawName;

    if (rawId && isStrictObjectIdString(String(rawId))) {
      elder = await Elder.findById(rawId);
      if (elder) canonicalName = elder.name.trim();
    }
    if (!elder && rawName) {
      const escaped = escapeRegex(rawName.trim());
      elder = await Elder.findOne({
        name: new RegExp(`^${escaped}$`, "i"),
      });
      if (elder) canonicalName = elder.name.trim();
    }

    if (!canonicalName) {
      return res.status(400).json({
        error: "elderName is required (or a valid elderId that exists)",
      });
    }

    const readingUsername = (req.body.readingUsername || "").trim() || null;

    const result = await purgeElderDataCore({
      canonicalName,
      elderDoc: elder,
      readingUsername,
    });

    return res.json({
      ok: true,
      elderName: result.elderName,
      deleted: result.deleted,
    });
  } catch (error) {
    console.error("purgeElderData:", error);
    return res.status(500).json({ error: error.message });
  }
};
