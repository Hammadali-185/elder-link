const mongoose = require("mongoose");
const Elder = require("../models/elder");
const MusicSession = require("../models/musicSession");

function utcStartOfDay(now = new Date()) {
  return new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0, 0)
  );
}

async function findElderByName(elderName) {
  if (!elderName || typeof elderName !== "string") return null;
  const trimmed = elderName.trim();
  if (!trimmed) return null;
  return Elder.findOne({
    name: new RegExp(`^${trimmed.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`, "i"),
  }).lean();
}

async function resolveElderFromBody(body) {
  const rawId = body.elderId;
  if (rawId && mongoose.Types.ObjectId.isValid(String(rawId))) {
    const elder = await Elder.findById(rawId).lean();
    if (elder) return elder;
  }
  return findElderByName(body.elderName || "");
}

/** Close any active session for this elder (one playing row per elder). */
async function closeOpenSessionsForElder(elderId, stoppedAt) {
  await MusicSession.updateMany(
    { elderId, status: "playing", stoppedAt: null },
    { $set: { stoppedAt, status: "stopped" } }
  );
}

/**
 * POST /api/music/start
 * Body: elderId | elderName, trackId, title, category, startedAt? (ISO UTC), status: "playing"
 */
exports.startMusic = async (req, res) => {
  try {
    const { trackId, title, category } = req.body;
    if (!trackId || !title || !category) {
      return res.status(400).json({
        error: "trackId, title, and category are required",
      });
    }

    const elder = await resolveElderFromBody(req.body);
    if (!elder) {
      return res.status(404).json({
        error: "Elder not found",
        hint: "Send elderId (Mongo id) or elderName matching an elder.",
      });
    }

    let startedAt = new Date();
    if (req.body.startedAt) {
      const parsed = new Date(req.body.startedAt);
      if (Number.isNaN(parsed.getTime())) {
        return res.status(400).json({ error: "Invalid startedAt ISO timestamp" });
      }
      startedAt = parsed;
    }

    await closeOpenSessionsForElder(elder._id, startedAt);

    const doc = await MusicSession.create({
      elderId: elder._id,
      elderName: elder.name,
      trackId: String(trackId),
      title: String(title),
      category: String(category),
      startedAt,
      stoppedAt: null,
      status: "playing",
    });

    return res.status(201).json({
      _id: doc._id.toString(),
      elderId: doc.elderId.toString(),
      trackId: doc.trackId,
      title: doc.title,
      category: doc.category,
      startedAt: doc.startedAt.toISOString(),
      status: doc.status,
    });
  } catch (err) {
    console.error("startMusic:", err);
    return res.status(500).json({ error: err.message });
  }
};

/**
 * POST /api/music/stop
 * Body: elderId | elderName, trackId?, stoppedAt? (ISO UTC), status: "stopped"
 * Updates the active playing session for that elder.
 */
exports.stopMusic = async (req, res) => {
  try {
    const elder = await resolveElderFromBody(req.body);
    if (!elder) {
      return res.status(404).json({ error: "Elder not found" });
    }

    let stoppedAt = new Date();
    if (req.body.stoppedAt) {
      const parsed = new Date(req.body.stoppedAt);
      if (Number.isNaN(parsed.getTime())) {
        return res.status(400).json({ error: "Invalid stoppedAt ISO timestamp" });
      }
      stoppedAt = parsed;
    }

    const filter = {
      elderId: elder._id,
      status: "playing",
      stoppedAt: null,
    };
    if (req.body.trackId != null && String(req.body.trackId).length > 0) {
      filter.trackId = String(req.body.trackId);
    }

    const doc = await MusicSession.findOneAndUpdate(
      filter,
      { $set: { stoppedAt, status: "stopped" } },
      { new: true, sort: { startedAt: -1 } }
    ).lean();

    if (!doc) {
      return res.status(404).json({
        error: "No active playing session for this elder",
      });
    }

    return res.json({
      _id: doc._id.toString(),
      elderId: doc.elderId.toString(),
      trackId: doc.trackId,
      stoppedAt: doc.stoppedAt.toISOString(),
      status: doc.status,
    });
  } catch (err) {
    console.error("stopMusic:", err);
    return res.status(500).json({ error: err.message });
  }
};

async function buildAnalytics(now = new Date()) {
  const dayStart = utcStartOfDay(now);

  const [currentlyPlaying, durationTodayAgg, playsByCategory, lastStoppedAgg] =
    await Promise.all([
      MusicSession.find({ status: "playing", stoppedAt: null })
        .sort({ startedAt: -1 })
        .select("elderId elderName trackId title category startedAt _id")
        .lean(),

      MusicSession.aggregate([
        {
          $match: {
            startedAt: { $gte: dayStart, $lte: now },
          },
        },
        {
          $project: {
            elderId: 1,
            elderName: 1,
            start: "$startedAt",
            end: { $ifNull: ["$stoppedAt", now] },
          },
        },
        {
          $project: {
            elderId: 1,
            elderName: 1,
            ms: {
              $max: [0, { $subtract: ["$end", "$start"] }],
            },
          },
        },
        {
          $group: {
            _id: "$elderId",
            elderName: { $first: "$elderName" },
            totalMs: { $sum: "$ms" },
          },
        },
      ]),

      MusicSession.aggregate([
        { $match: { startedAt: { $gte: dayStart, $lte: now } } },
        {
          $group: {
            _id: "$category",
            playCount: { $sum: 1 },
          },
        },
        { $sort: { playCount: -1 } },
        { $limit: 1 },
      ]),

      MusicSession.aggregate([
        { $match: { stoppedAt: { $ne: null } } },
        {
          $group: {
            _id: "$elderId",
            elderName: { $first: "$elderName" },
            lastStoppedAt: { $max: "$stoppedAt" },
          },
        },
        { $sort: { lastStoppedAt: -1 } },
      ]),
    ]);

  let mostPlayedCategory = null;
  if (playsByCategory.length > 0) {
    mostPlayedCategory = {
      category: playsByCategory[0]._id,
      playCount: playsByCategory[0].playCount,
    };
  }

  const durationByCategoryAgg = await MusicSession.aggregate([
    { $match: { startedAt: { $gte: dayStart, $lte: now } } },
    {
      $project: {
        category: 1,
        start: "$startedAt",
        end: { $ifNull: ["$stoppedAt", now] },
      },
    },
    {
      $group: {
        _id: "$category",
        totalMs: {
          $sum: { $max: [0, { $subtract: ["$end", "$start"] }] },
        },
      },
    },
    { $sort: { totalMs: -1 } },
    { $limit: 1 },
  ]);

  let mostPlayedCategoryByDuration = null;
  if (durationByCategoryAgg.length > 0) {
    mostPlayedCategoryByDuration = {
      category: durationByCategoryAgg[0]._id,
      totalSeconds: Math.round(durationByCategoryAgg[0].totalMs / 1000),
    };
  }

  return {
    generatedAt: now.toISOString(),
    utcDayStart: dayStart.toISOString(),
    currentlyPlaying: currentlyPlaying.map((s) => ({
      sessionId: s._id.toString(),
      elderId: s.elderId.toString(),
      elderName: s.elderName,
      trackId: s.trackId,
      title: s.title,
      category: s.category,
      startedAt: s.startedAt.toISOString(),
    })),
    totalDurationTodayByElder: durationTodayAgg.map((row) => ({
      elderId: row._id.toString(),
      elderName: row.elderName,
      totalSeconds: Math.round(row.totalMs / 1000),
    })),
    mostPlayedCategory,
    mostPlayedCategoryByDuration,
    lastPlayedByElder: lastStoppedAgg.map((row) => ({
      elderId: row._id.toString(),
      elderName: row.elderName,
      lastStoppedAt: row.lastStoppedAt.toISOString(),
    })),
    activeListenersCount: currentlyPlaying.length,
  };
}

/** GET /api/music/panel — staff Music Panel (structured). */
exports.getPanel = async (req, res) => {
  try {
    const payload = await buildAnalytics();
    return res.json(payload);
  } catch (err) {
    console.error("getPanel:", err);
    return res.status(500).json({ error: err.message });
  }
};

/** GET /api/music-sessions/dashboard — legacy shape for dashboard_screen. */
exports.getDashboard = async (req, res) => {
  try {
    const a = await buildAnalytics();
    return res.json({
      generatedAt: a.generatedAt,
      utcDayStart: a.utcDayStart,
      activeListenersCount: a.activeListenersCount,
      nowPlaying: a.currentlyPlaying.map((p) => ({
        sessionId: p.sessionId,
        elderId: p.elderId,
        elderName: p.elderName,
        trackId: p.trackId,
        title: p.title,
        artist: "",
        category: p.category,
        playStart: p.startedAt,
      })),
      listeningTodaySecondsByElder: a.totalDurationTodayByElder.map((e) => ({
        elderId: e.elderId,
        elderName: e.elderName,
        totalSeconds: e.totalSeconds,
      })),
      mostPlayedCategoryToday: a.mostPlayedCategoryByDuration
        ? {
            category: a.mostPlayedCategoryByDuration.category,
            totalSeconds: a.mostPlayedCategoryByDuration.totalSeconds,
          }
        : null,
      mostPlayedCategoryTodayByPlays: a.mostPlayedCategory,
      lastPlayedByElder: a.lastPlayedByElder.map((e) => ({
        elderId: e.elderId,
        elderName: e.elderName,
        lastPlayedAt: e.lastStoppedAt,
      })),
    });
  } catch (err) {
    console.error("getDashboard:", err);
    return res.status(500).json({ error: err.message });
  }
};
