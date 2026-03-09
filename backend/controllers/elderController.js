const Elder = require("../models/elder");

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
