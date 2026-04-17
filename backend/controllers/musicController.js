const mongoose = require("mongoose");
const Elder = require("../models/elder");
const { isStrictObjectIdString } = require("../utils/validateObjectId");
const MusicSession = require("../models/musicSession");

// Must exceed ~2 watch heartbeats (40s interval) so brief jitter does not drop "now playing".
const STALE_MS = 120000;
// Allow small client/server clock skew without keeping "now playing" forever.
const FUTURE_SKEW_MS = 5 * 60 * 1000;

/** Start of the current calendar day in Asia/Karachi (as a UTC Date). */
function startOfKarachiCalendarDay(now = new Date()) {
  const dStr = now.toLocaleDateString("en-CA", { timeZone: "Asia/Karachi" });
  const [y, m, day] = dStr.split("-").map(Number);
  const iso = `${y}-${String(m).padStart(2, "0")}-${String(day).padStart(2, "0")}T00:00:00+05:00`;
  return new Date(iso);
}

async function cleanupStaleMusicSessions(now = new Date(), options = {}) {
  const { quiet = false } = options;
  const cutoff = new Date(now.getTime() - STALE_MS);
  const futureCutoff = new Date(now.getTime() + FUTURE_SKEW_MS);
  const countBefore = await MusicSession.countDocuments({
    status: "playing",
    stoppedAt: null,
  });
  await MusicSession.updateMany(
    {
      status: "playing",
      stoppedAt: null,
      lastHeartbeatAt: { $lt: cutoff },
    },
    {
      $set: {
        status: "stopped",
        stoppedAt: now,
      },
    }
  );
  // If the client clock is ahead, lastHeartbeatAt may be in the "future" and would never go stale.
  await MusicSession.updateMany(
    {
      status: "playing",
      stoppedAt: null,
      lastHeartbeatAt: { $gt: futureCutoff },
    },
    {
      $set: {
        status: "stopped",
        stoppedAt: now,
        lastHeartbeatAt: now,
      },
    }
  );
  await MusicSession.updateMany(
    {
      status: "playing",
      stoppedAt: null,
      $or: [{ lastHeartbeatAt: null }, { lastHeartbeatAt: { $exists: false } }],
      startedAt: { $lt: cutoff },
    },
    {
      $set: {
        status: "stopped",
        stoppedAt: now,
      },
    }
  );
  const countAfter = await MusicSession.countDocuments({
    status: "playing",
    stoppedAt: null,
  });
  if (!quiet) {
    console.log("Before cleanup:", countBefore);
    console.log("After cleanup:", countAfter);
  } else if (countBefore !== countAfter) {
    console.log(
      `[music stale cleanup] playing sessions: ${countBefore} -> ${countAfter}`
    );
  }
  return { playingBefore: countBefore, playingAfter: countAfter };
}

/** Called on a timer from index.js; avoids noisy logs when nothing changes. */
exports.runMusicStaleCleanup = async (now = new Date()) =>
  cleanupStaleMusicSessions(now, { quiet: true });

/** POST /api/music-sessions/admin/close-stale — force stale-session sweep (staff troubleshooting). */
exports.closeStaleMusicSessionsAdmin = async (req, res) => {
  try {
    const r = await cleanupStaleMusicSessions(new Date(), { quiet: false });
    return res.json({
      ok: true,
      playingBefore: r.playingBefore,
      playingAfter: r.playingAfter,
      closed: Math.max(0, r.playingBefore - r.playingAfter),
    });
  } catch (err) {
    console.error("closeStaleMusicSessionsAdmin:", err);
    return res.status(500).json({ error: err.message });
  }
};

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
  if (rawId && isStrictObjectIdString(String(rawId))) {
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
      lastHeartbeatAt: startedAt,
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

    let doc = await MusicSession.findOneAndUpdate(
      filter,
      { $set: { stoppedAt, status: "stopped" } },
      { new: true, sort: { startedAt: -1 } }
    ).lean();

    if (!doc && filter.trackId) {
      doc = await MusicSession.findOneAndUpdate(
        { elderId: elder._id, status: "playing", stoppedAt: null },
        { $set: { stoppedAt, status: "stopped" } },
        { new: true, sort: { startedAt: -1 } }
      ).lean();
    }

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

/**
 * POST /api/music/heartbeat
 * Body: elderId | elderName, optional trackId, optional at (ISO UTC)
 */
exports.pingMusic = async (req, res) => {
  try {
    const elder = await resolveElderFromBody(req.body);
    if (!elder) {
      return res.status(404).json({ error: "Elder not found" });
    }

    let at = new Date();
    if (req.body.at) {
      const parsed = new Date(req.body.at);
      if (!Number.isNaN(parsed.getTime())) at = parsed;
    }

    const filter = {
      elderId: elder._id,
      status: "playing",
      stoppedAt: null,
    };
    if (req.body.trackId != null && String(req.body.trackId).length > 0) {
      filter.trackId = String(req.body.trackId);
    }

    let doc = await MusicSession.findOneAndUpdate(
      filter,
      { $set: { lastHeartbeatAt: at } },
      { new: true, sort: { startedAt: -1 } }
    ).lean();

    if (!doc && filter.trackId) {
      doc = await MusicSession.findOneAndUpdate(
        { elderId: elder._id, status: "playing", stoppedAt: null },
        { $set: { lastHeartbeatAt: at } },
        { new: true, sort: { startedAt: -1 } }
      ).lean();
    }

    if (!doc) {
      return res.status(404).json({ error: "No active playing session" });
    }

    return res.json({ ok: true });
  } catch (err) {
    console.error("pingMusic:", err);
    return res.status(500).json({ error: err.message });
  }
};

async function buildAnalytics(now = new Date()) {
  await cleanupStaleMusicSessions(now);
  const dayStart = startOfKarachiCalendarDay(now);
  const cutoff = new Date(now.getTime() - STALE_MS);
  const futureCutoff = new Date(now.getTime() + FUTURE_SKEW_MS);

  const [playingRaw, durationTodayAgg, playsByCategory, lastFinishedAgg] =
    await Promise.all([
      MusicSession.find({
        status: "playing",
        stoppedAt: null,
        lastHeartbeatAt: { $gte: cutoff, $lte: futureCutoff },
      })
        .sort({ startedAt: -1 })
        .select(
          "elderId elderName trackId title category startedAt lastHeartbeatAt _id"
        )
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
        { $sort: { stoppedAt: -1 } },
        {
          $group: {
            _id: "$elderId",
            elderName: { $first: "$elderName" },
            lastStartedAt: { $first: "$startedAt" },
            lastStoppedAt: { $first: "$stoppedAt" },
            title: { $first: "$title" },
            category: { $first: "$category" },
          },
        },
        { $sort: { lastStoppedAt: -1 } },
      ]),
    ]);

  const byElder = new Map();
  for (const s of playingRaw) {
    const id = s.elderId.toString();
    const prev = byElder.get(id);
    if (!prev || s.startedAt > prev.startedAt) {
      byElder.set(id, s);
    }
  }
  const currentlyPlaying = [...byElder.values()].sort(
    (a, b) => b.startedAt - a.startedAt
  );

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
    asiaKarachiDayStart: dayStart.toISOString(),
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
    lastPlayedByElder: lastFinishedAgg.map((row) => ({
      elderId: row._id.toString(),
      elderName: row.elderName,
      lastStartedAt: row.lastStartedAt ? row.lastStartedAt.toISOString() : null,
      lastStoppedAt: row.lastStoppedAt ? row.lastStoppedAt.toISOString() : null,
      title: row.title || "",
      category: row.category || "",
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
      asiaKarachiDayStart: a.asiaKarachiDayStart,
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
        lastStartedAt: e.lastStartedAt,
        lastStoppedAt: e.lastStoppedAt,
        lastPlayedAt: e.lastStoppedAt, // backwards compatibility for older clients
        title: e.title,
        category: e.category,
      })),
    });
  } catch (err) {
    console.error("getDashboard:", err);
    return res.status(500).json({ error: err.message });
  }
};
