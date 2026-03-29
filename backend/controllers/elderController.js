const Elder = require("../models/elder");

/** Create or update elder by name when watch saves My Info (so staff Meds list sees them). */
exports.syncFromWatch = async (req, res) => {
  try {
    const name = (req.body.name || "").trim();
    if (!name) {
      return res.status(400).json({ error: "name is required" });
    }
    const roomNumber = (req.body.roomNumber || "").trim() || "—";
    const age = (req.body.age || "").trim() || "—";
    const gender = req.body.gender === "Female" ? "Female" : "Male";
    const diseaseRaw = (req.body.disease || "").trim();
    const disease = diseaseRaw || undefined;

    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    let elder = await Elder.findOne({
      name: new RegExp(`^${escaped}$`, "i"),
    });

    if (elder) {
      elder.roomNumber = roomNumber;
      elder.age = age;
      elder.gender = gender;
      elder.disease = disease;
      elder.updatedAt = new Date();
      await elder.save();
      return res.json(elder);
    }

    elder = await Elder.create({
      name,
      roomNumber,
      age,
      gender,
      disease,
      status: "stable",
    });
    return res.status(201).json(elder);
  } catch (error) {
    console.error("syncFromWatch:", error);
    return res.status(400).json({ error: error.message });
  }
};

exports.createElder = async (req, res) => {
  try {
    const elder = new Elder(req.body);
    const saved = await elder.save();
    res.status(201).json(saved);
  } catch (error) {
    console.error("Error creating elder:", error);
    res.status(400).json({ error: error.message });
  }
};

exports.getElders = async (req, res) => {
  try {
    const elders = await Elder.find().sort({ createdAt: -1 });
    res.json(elders);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getElderById = async (req, res) => {
  try {
    const elder = await Elder.findById(req.params.id);
    if (!elder) {
      return res.status(404).json({ error: "Elder not found" });
    }
    res.json(elder);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.updateElder = async (req, res) => {
  try {
    req.body.updatedAt = Date.now();
    const elder = await Elder.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });
    if (!elder) {
      return res.status(404).json({ error: "Elder not found" });
    }
    res.json(elder);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.deleteElder = async (req, res) => {
  try {
    const elder = await Elder.findByIdAndDelete(req.params.id);
    if (!elder) {
      return res.status(404).json({ error: "Elder not found" });
    }
    res.json({ message: "Elder deleted successfully" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
