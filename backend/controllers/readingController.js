const Reading = require("../models/reading");

exports.createReading = async (req, res) => {
  try {
    console.log('Received request body:', JSON.stringify(req.body, null, 2));
    const reading = new Reading(req.body);
    const saved = await reading.save();
    console.log('Reading saved successfully:', saved._id);
    res.status(201).json(saved);
  } catch (error) {
    console.error('Error creating reading:', error.message);
    console.error('Error details:', error);
    res.status(400).json({ 
      error: error.message,
      details: error.errors || 'Validation failed'
    });
  }
};

exports.getReadings = async (req, res) => {
  try {
    const readings = await Reading.find();
    res.json(readings);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getReadingByUser = async (req, res) => {
  try {
    const readings = await Reading.find({ username: req.params.username });
    res.json(readings);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.deleteReading = async (req, res) => {
  try {
    await Reading.findByIdAndDelete(req.params.id);
    res.json({ message: "Deleted" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
