const HeartAlert = require("../models/heartAlert");

exports.createHeartAlert = async (req, res) => {
  try {
    console.log('Received heart alert:', JSON.stringify(req.body, null, 2));
    const heartAlert = new HeartAlert(req.body);
    const saved = await heartAlert.save();
    console.log('Heart alert saved successfully:', saved._id);
    res.status(201).json(saved);
  } catch (error) {
    console.error('Error creating heart alert:', error.message);
    res.status(400).json({ 
      error: error.message,
      details: error.errors || 'Validation failed'
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
