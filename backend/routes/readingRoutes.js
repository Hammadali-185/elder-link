const express = require("express");
const router = express.Router();
const controller = require("../controllers/readingController");
const elderController = require("../controllers/elderController");

router.post("/admin/purge-elder", elderController.purgeElderData);
router.post("/admin/purgeelder", elderController.purgeElderData);

router.post("/", controller.createReading);
router.get("/", controller.getReadings);
router.get("/user/:username", controller.getReadingByUser);
router.delete("/:id", controller.deleteReading);

module.exports = router;
