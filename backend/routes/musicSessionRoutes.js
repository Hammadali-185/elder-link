const express = require("express");
const router = express.Router();
const music = require("../controllers/musicController");

/** Legacy dashboard endpoint (mobile dashboard_screen). */
router.get("/dashboard", music.getDashboard);

module.exports = router;
