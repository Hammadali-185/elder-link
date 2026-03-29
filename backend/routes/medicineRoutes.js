const express = require("express");
const router = express.Router();
const controller = require("../controllers/medicineController");

router.post("/", controller.createMedicine);
router.get("/", controller.getMedicines);
router.patch("/:id", controller.patchMedicine);
router.put("/:id/status", controller.updateMedicineStatus);
router.delete("/:id", controller.deleteMedicine);

module.exports = router;
