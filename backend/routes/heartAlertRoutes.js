const express = require("express");
const router = express.Router();
const controller = require("../controllers/heartAlertController");

router.post("/", controller.createHeartAlert);
router.get("/", controller.getHeartAlerts);

module.exports = router;
