const Elder = require("../models/elder");
const { isStrictObjectIdString } = require("./validateObjectId");

function escapeRegex(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function findElderByNameInsensitive(name) {
  const t = String(name || "").trim();
  if (!t) return null;
  return Elder.findOne({ name: new RegExp(`^${escapeRegex(t)}$`, "i") });
}

/** All elders whose name matches (case-insensitive); used to detect ambiguity. */
async function findAllEldersByNameInsensitive(name) {
  const t = String(name || "").trim();
  if (!t) return [];
  return Elder.find({ name: new RegExp(`^${escapeRegex(t)}$`, "i") }).lean();
}

/**
 * Resolves Mongo elder id from watch-style payloads (optional elderId + personName + username).
 * Updates Elder.readingUsername when username is present (stable device id for purge).
 * If [elderId] is sent (non-empty), it must be a valid 24-char id and match an existing Elder — no silent fallback to name.
 * @returns {Promise<mongoose.Types.ObjectId|null>}
 */
async function resolveElderIdForWatchPayload(body) {
  const b = body || {};
  const rawId = b.elderId;
  const rawStr = rawId != null ? String(rawId).trim() : "";
  if (rawStr !== "") {
    if (!isStrictObjectIdString(rawStr)) {
      const err = new Error("Invalid elderId");
      err.status = 400;
      throw err;
    }
    const e = await Elder.findById(rawStr);
    if (!e) {
      const err = new Error("Elder not found for elderId");
      err.status = 404;
      throw err;
    }
    const un = String(b.username || "").trim();
    if (un) {
      e.readingUsername = un;
      e.updatedAt = new Date();
      await e.save();
    }
    return e._id;
  }
  const personName = String(b.personName || "").trim();
  if (!personName) return null;
  let elder = await findElderByNameInsensitive(personName);
  if (!elder) return null;
  const un = String(b.username || "").trim();
  if (un) {
    elder.readingUsername = un;
    elder.updatedAt = new Date();
    await elder.save();
  }
  return elder._id;
}

module.exports = {
  escapeRegex,
  findElderByNameInsensitive,
  findAllEldersByNameInsensitive,
  resolveElderIdForWatchPayload,
};
