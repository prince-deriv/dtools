const offline_key = "dtools_popup_offline";
const feature_key = "dtools_feature_version";
const env_key = "dtools_env";
const storage = chrome.storage.local;
const has_update_key = "dtools_has_update";

window.env = "production";
window.is_offline = false;
window.feature_version = null;

const setStorageValue = (key, value) => {
  const obj = {};

  obj[key] = value;

  storage.set(obj);
};

let dev_clicks = 0;
const renderActionHandler = () => {
  document.body.addEventListener("click", function () {
    dev_clicks += 1;

    if (dev_clicks >= 10) {
      const new_env = window.env == "local" ? "production" : "local";

      setStorageValue(env_key, new_env);

      alert(`Dtools Environment is now ${new_env}`);

      window.close();
    }
  });

  setInterval(() => {
    dev_clicks = 0;
  }, 2000);
};

// Environment handler
// Check Production version and use local copy when no updates
storage.get(null, function (items) {
  const env = items[env_key];

  if (env != undefined) {
    window.env = env;
  }

  window.feature_version = items[feature_key];

  renderActionHandler();

  load();
});

const hasNewFeatures = () => localStorage[has_update_key] === "true";

// Append Extension Renderer Script
const load = () => {
  const url =
    window.env == "local"
      ? "http://localhost:4444"
      : "https://prince-deriv.github.io/dtools-production";
  const time = Math.floor(new Date().getTime() / 1000);
  const xhr = new XMLHttpRequest();
  const full_url = `${url}/assets/scripts/renderer/app-obs.js?v=${time}`;
  const local_code = localStorage[offline_key];

  // Use Local Code
  if (!hasNewFeatures() && local_code && window.env !== "local") {
    eval(local_code);

    return false;
  }

  // Fetch Live Code
  xhr.open("GET", full_url, true);
  xhr.onreadystatechange = function () {
    if (xhr.readyState == 4) {
      if (xhr.status == 0) {
        // Offline Mode
        window.is_offline = true;
        eval(localStorage[offline_key]);
        return false;
      }

      const response = xhr.responseText;

      localStorage[offline_key] = response;
      localStorage[has_update_key] = null;
      eval(response);
    }
  };

  try {
    xhr.send();
    return (xhr.status >= 200 && xhr.status < 300) || xhr.status === 304;
  } catch (error) {}
};
