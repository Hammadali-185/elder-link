const express = require("express");
const router = express.Router();
const controller = require("../controllers/elderController");

router.post("/", controller.createElder);
router.get("/", controller.getElders);
router.get("/:id", controller.getElderById);
router.put("/:id", controller.updateElder);
router.delete("/:id", controller.deleteElder);

module.exports = router;
