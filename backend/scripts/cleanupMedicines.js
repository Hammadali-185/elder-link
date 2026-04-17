/**
 * Maintenance: delete Medicine rows not scoped by a valid Mongo ObjectId elderId.
 * From backend/: `node scripts/cleanupMedicines.js`
 * Uses MONGO_URI from .env (same as index.js).
 */
const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });

const mongoose = require("mongoose");
const Medicine = require(path.join(__dirname, "..", "models", "medicine"));

async function main() {
  const uri = process.env.MONGO_URI;
  if (!uri) {
    console.error("MONGO_URI is not set");
    process.exit(1);
  }
  await mongoose.connect(uri);
  console.log("Connected.");

  const res = await Medicine.deleteMany({
    $or: [
      { elderId: { $exists: false } },
      { elderId: null },
      { elderId: { $not: { $type: "objectId" } } },
    ],
  });
  console.log("Deleted medicines without valid ObjectId elderId:", res.deletedCount);

  const n = await Medicine.countDocuments({});
  console.log("Remaining medicine documents:", n);
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
