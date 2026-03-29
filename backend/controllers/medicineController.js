const Medicine = require("../models/medicine");
const MedicineAssignmentEvent = require("../models/medicineAssignmentEvent");
const { notifyMedicineChange } = require("../services/medicineNotify");

exports.createMedicine = async (req, res) => {
  try {
    const medicine = new Medicine(req.body);
    const saved = await medicine.save();
    try {
      await notifyMedicineChange(saved, "assigned");
    } catch (notifyErr) {
      console.error("notifyMedicineChange (create):", notifyErr.message);
    }
    res.status(201).json(saved);
  } catch (error) {
    console.error("Error creating medicine:", error);
    res.status(400).json({ error: error.message });
  }
};

exports.patchMedicine = async (req, res) => {
  try {
    const updates = { ...req.body };
    delete updates._id;
    const medicine = await Medicine.findByIdAndUpdate(
      req.params.id,
      { ...updates, updatedAt: new Date() },
      { new: true, runValidators: true }
    );
    if (!medicine) {
      return res.status(404).json({ error: "Medicine not found" });
    }
    try {
      await notifyMedicineChange(medicine, "updated");
    } catch (notifyErr) {
      console.error("notifyMedicineChange (patch):", notifyErr.message);
    }
    res.json(medicine);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.getMedicines = async (req, res) => {
  try {
    const { elderName, date } = req.query;
    let query = {};
    
    if (elderName) {
      query.elderName = elderName;
    }
    
    if (date) {
      const startOfDay = new Date(date);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(date);
      endOfDay.setHours(23, 59, 59, 999);
      query.scheduledDate = { $gte: startOfDay, $lte: endOfDay };
    } else {
      // Default to today
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);
      query.scheduledDate = { $gte: today, $lt: tomorrow };
    }
    
    const medicines = await Medicine.find(query).sort({ time: 1 });
    res.json(medicines);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.updateMedicineStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const medicine = await Medicine.findByIdAndUpdate(
      req.params.id,
      {
        status,
        takenAt: status === "taken" ? new Date() : null,
        updatedAt: new Date(),
      },
      { new: true }
    );

    if (!medicine) {
      return res.status(404).json({ error: "Medicine not found" });
    }

    const latestEvent = await MedicineAssignmentEvent.findOne({
      medicineId: medicine._id,
    }).sort({ assignedTime: -1 });
    if (latestEvent) {
      latestEvent.taken = status === "taken";
      latestEvent.takenAt = status === "taken" ? new Date() : null;
      await latestEvent.save();
    }

    res.json(medicine);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.deleteMedicine = async (req, res) => {
  try {
    const medicine = await Medicine.findByIdAndDelete(req.params.id);
    if (!medicine) {
      return res.status(404).json({ error: "Medicine not found" });
    }
    res.json({ message: "Medicine deleted successfully" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
