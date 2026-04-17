const express = require("express");
const router = express.Router();
const music = require("../controllers/musicController");

router.post("/admin/close-stale", music.closeStaleMusicSessionsAdmin);

/** Legacy dashboard endpoint (mobile dashboard_screen). */
router.get("/dashboard", music.getDashboard);

module.exports = router;
