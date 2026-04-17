// ✅ Put your real store links here:
const ANDROID_URL = "https://play.google.com/store/apps/details?id=YOUR_APP_ID";
const IOS_URL = "https://apps.apple.com/app/idYOUR_APP_ID";

// ====== STORE LINKS (EDIT THESE) ======
const LINKS = {
  player: {
    android: "https://play.google.com/store/apps/details?id=com.mohamed_helicopter.squad_player",
    ios: "https://apps.apple.com/eg/app/%D9%84%D8%A7%D8%B9%D8%A8-%D8%A5%D8%B3%D9%83%D9%88%D8%A7%D8%AF/id6756811939?l=ar",
  },
  user: {
    android: "https://play.google.com/store/apps/details?id=com.mohamed_helicopter.squad",
    ios: "https://apps.apple.com/eg/app/%D8%A5%D8%B3%D9%83%D9%88%D8%A7%D8%AF/id6756811679?l=ar",
  }
};

// Helper
function setHref(id, url) {
  const el = document.getElementById(id);
  if (el) el.href = url;
}

setHref("playerAndroid", LINKS.player.android);
setHref("playerIOS", LINKS.player.ios);
setHref("userAndroid", LINKS.user.android);
setHref("userIOS", LINKS.user.ios);

setHref("playerAndroid2", LINKS.player.android);
setHref("playerIOS2", LINKS.player.ios);
setHref("userAndroid2", LINKS.user.android);
setHref("userIOS2", LINKS.user.ios);

// Year
const y = document.getElementById("year");
if (y) y.textContent = new Date().getFullYear();

function setLinks() {
  const btns = [
    document.getElementById("btnAndroid"),
    document.getElementById("btnAndroid2"),
  ].filter(Boolean);

  const btnsIos = [
    document.getElementById("btniOS"),
    document.getElementById("btniOS2"),
  ].filter(Boolean);

  btns.forEach(b => b.href = ANDROID_URL);
  btnsIos.forEach(b => b.href = IOS_URL);
}

function setYear() {
  const y = document.getElementById("year");
  if (y) y.textContent = new Date().getFullYear();
}

// Simple "EN" toggle (optional placeholder)
function setupLangToggle() {
  const t = document.getElementById("toggleLang");
  if (!t) return;

  t.addEventListener("click", () => {
    alert("");
  });
}

setLinks();
setYear();
setupLangToggle();