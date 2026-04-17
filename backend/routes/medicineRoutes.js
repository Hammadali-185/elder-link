const express = require("express");
const router = express.Router();
const controller = require("../controllers/medicineController");

// Dev-only: set ELDERLINK_DEBUG_ROUTES=1 — POST body { elderId, medicineName, time, scheduledDate } → dedupe preview.
if (process.env.ELDERLINK_DEBUG_ROUTES === "1") {
  router.post("/__debug/dedupe-preview", controller.debugDedupePreview);
}

router.post("/", controller.createMedicine);
router.get("/", controller.getMedicines);
router.patch("/:id", controller.patchMedicine);
router.put("/:id/status", controller.updateMedicineStatus);
router.delete("/:id", controller.deleteMedicine);

module.exports = router;
