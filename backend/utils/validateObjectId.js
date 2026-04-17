const mongoose = require("mongoose");

/** Strict 24-hex ObjectId string (rejects legacy 12-byte string edge cases). */
function isStrictObjectIdString(id) {
  const s = String(id ?? "").trim();
  return s.length === 24 && mongoose.Types.ObjectId.isValid(s);
}

/**
 * @param {unknown} id
 * @param {string} [label]
 * @param {{ logRejection?: boolean }} [opts] - log only for critical paths (e.g. medicine create elderId)
 */
function assertValidObjectId(id, label = "id", opts = {}) {
  const log = opts.logRejection === true;
  if (id == null || String(id).trim() === "") {
    if (log) console.warn(`[objectId] empty ${label} rejected`);
    const err = new Error(`${label} is required`);
    err.status = 400;
    throw err;
  }
  if (!isStrictObjectIdString(id)) {
    if (log) console.warn(`[objectId] invalid ${label}:`, String(id));
    const err = new Error(`Invalid ${label}`);
    err.status = 400;
    throw err;
  }
}

module.exports = {
  isStrictObjectIdString,
  assertValidObjectId,
};
