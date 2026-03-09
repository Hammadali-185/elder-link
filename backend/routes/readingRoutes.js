const express = require("express");
const router = express.Router();
const controller = require("../controllers/readingController");

router.post("/", controller.createReading);
router.get("/", controller.getReadings);
router.get("/user/:username", controller.getReadingByUser);
router.delete("/:id", controller.deleteReading);

module.exports = router;
