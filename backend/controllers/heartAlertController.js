const HeartAlert = require("../models/heartAlert");
const Reading = require("../models/reading");
const { resolveElderIdForWatchPayload } = require("../utils/elderResolve");

exports.createHeartAlert = async (req, res) => {
  try {
    console.log('Received heart alert:', JSON.stringify(req.body, null, 2));
    const elderOid = await resolveElderIdForWatchPayload(req.body);
    const payload = { ...req.body };
    if (elderOid) payload.elderId = elderOid;
    const heartAlert = new HeartAlert(payload);
    const saved = await heartAlert.save();
    console.log('Heart alert saved successfully:', saved._id);
    try {
      const reason =
        saved.heartRate < 60
          ? "LOW HEART RATE"
          : saved.heartRate > 100
            ? "HIGH HEART RATE"
            : "ABNORMAL HEART RATE";
      await Reading.create({
        username: saved.username,
        ...(saved.elderId ? { elderId: saved.elderId } : {}),
        bp: 0,
        heartRate: saved.heartRate,
        status: "abnormal",
        emergency: false,
        vitalsUrgent: false,
        alertReason: reason,
        personName: saved.personName || undefined,
        roomNumber: saved.roomNumber || undefined,
      });
    } catch (mirrorErr) {
      console.error("Heart alert → reading mirror failed:", mirrorErr.message);
    }
    res.status(201).json(saved);
  } catch (error) {
    console.error('Error creating heart alert:', error.message);
    const code = error.status || 400;
    res.status(code).json({
      error: error.message,
      details: error.errors || 'Validation failed',
    });
  }
};

exports.getHeartAlerts = async (req, res) => {
  try {
    const alerts = await HeartAlert.find().sort({ timestamp: -1 });
    res.json(alerts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
