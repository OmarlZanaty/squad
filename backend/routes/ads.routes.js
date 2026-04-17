// services/systemSettingsAds.service.js
const db = require("../db");

// We store ads JSON in system_settings.settingKey = 'home_ads'
const KEY = "home_ads";

const DEFAULT_VALUE = {
  defaultImageUrl: "/public/ads/default.png",
  items: [
    { slot: 1, title: "", subtitle: "", link: "", imageUrl: "" },
    { slot: 2, title: "", subtitle: "", link: "", imageUrl: "" },
    { slot: 3, title: "", subtitle: "", link: "", imageUrl: "" },
  ],
};

function safeJsonParse(str) {
  try {
    return JSON.parse(str);
  } catch (e) {
    return null;
  }
}

function normalize(payload) {
  const v = payload && typeof payload === "object" ? payload : {};
  const defaultImageUrl =
    typeof v.defaultImageUrl === "string" && v.defaultImageUrl.trim()
      ? v.defaultImageUrl.trim()
      : DEFAULT_VALUE.defaultImageUrl;

  const itemsIn = Array.isArray(v.items) ? v.items : [];
  const items = [1, 2, 3].map((slot) => {
    const x = itemsIn.find((i) => Number(i?.slot) === slot) || {};
    return {
      slot,
      title: (x.title ?? "").toString(),
      subtitle: (x.subtitle ?? "").toString(),
      link: (x.link ?? "").toString(),
      imageUrl: (x.imageUrl ?? "").toString(), // can be empty
    };
  });

  return { defaultImageUrl, items };
}

function baseUrl(req) {
  const proto = req.headers["x-forwarded-proto"] || req.protocol;
  const host = req.headers["x-forwarded-host"] || req.get("host");
  return `${proto}://${host}`;
}

function toAbsolute(url, req) {
  if (!url) return url;
  if (url.startsWith("http://") || url.startsWith("https://")) return url;
  if (url.startsWith("/")) return baseUrl(req) + url;
  return baseUrl(req) + "/" + url;
}

async function getHomeAds(req) {
  const [rows] = await db.query(
    "SELECT settingValue FROM system_settings WHERE settingKey = ? LIMIT 1",
    [KEY]
  );

  const raw = rows.length ? rows[0].settingValue : null;
  const parsed = raw ? safeJsonParse(raw) : null;

  const data = normalize(parsed || DEFAULT_VALUE);

  // Apply: if imageUrl empty -> use defaultImageUrl
  const result = {
    defaultImageUrl: toAbsolute(data.defaultImageUrl, req),
    items: data.items.map((a) => {
      const img = (a.imageUrl || "").trim();
      const finalImageUrl = img ? img : data.defaultImageUrl;
      return {
        ...a,
        imageUrl: img,
        finalImageUrl: toAbsolute(finalImageUrl, req),
      };
    }),
  };

  return result;
}

async function saveHomeAds(value, updatedBy = null) {
  const normalized = normalize(value);

  await db.query(
    `
    INSERT INTO system_settings (settingKey, settingValue, updatedBy)
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE
      settingValue = VALUES(settingValue),
      updatedBy = VALUES(updatedBy),
      updatedAt = CURRENT_TIMESTAMP
    `,
    [KEY, JSON.stringify(normalized), updatedBy]
  );

  return normalized;
}

async function patchSlot(slot, patch, updatedBy = null) {
  const current = await getHomeAds({
    headers: {},
    protocol: "http",
    get: () => "localhost",
  });

  const data = normalize({
    defaultImageUrl: current.defaultImageUrl.replace(/^https?:\/\/[^/]+/, ""),
    items: current.items.map((x) => ({
      slot: x.slot,
      title: x.title,
      subtitle: x.subtitle,
      link: x.link,
      imageUrl: x.imageUrl,
    })),
  });

  const s = Number(slot);
  const idx = data.items.findIndex((x) => x.slot === s);
  if (idx === -1) throw new Error("Invalid slot");

  data.items[idx] = {
    ...data.items[idx],
    ...patch,
    slot: s,
  };

  await saveHomeAds(data, updatedBy);
  return data;
}

module.exports = {
  getHomeAds,
  saveHomeAds,
  patchSlot,
};