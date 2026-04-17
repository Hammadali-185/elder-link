const express = require("express");
const router = express.Router();
const music = require("../controllers/musicController");

router.post("/start", music.startMusic);
router.post("/heartbeat", music.pingMusic);
router.post("/stop", music.stopMusic);
router.get("/panel", music.getPanel);

module.exports = router;
