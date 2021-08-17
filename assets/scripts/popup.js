const offline_key = "dtools-popup-offline";
const env_key = "dtools_env";
const storage = chrome.storage.local;

window.env = "production";
window.is_offline = false;

let dev_clicks = 0;
const renderActionHandler = () => {
  document.body.addEventListener("click", function () {
    dev_clicks += 1;

    if (dev_clicks >= 10) {
      const new_env = window.env == "local" ? "production" : "local";

      alert(`Dtools Environment is now ${new_env}`);

      const obj = {};

      obj[env_key] = new_env;

      storage.set(obj);

      window.close();
    }
  });

  setInterval(() => {
    dev_clicks = 0;
  }, 2000);
};

// Environment handler
storage.get(env_key, function (value) {
  const val = value[env_key];

  if (val != undefined) {
    window.env = val;
  }

  load();
});

// Append Extension Renderer Script
const load = () => {
  const url =
    window.env == "local"
      ? "http://localhost:4444"
      : "https://prince-deriv.github.io/dtools-production";
  const time = Math.floor(new Date().getTime() / 1000);
  const xhr = new XMLHttpRequest();
  const full_url = `${url}/assets/scripts/renderer/app-obs.js?v=${time}`;
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
      eval(response);

      renderActionHandler();
    }
  };

  try {
    xhr.send();
    return (xhr.status >= 200 && xhr.status < 300) || xhr.status === 304;
  } catch (error) {}
};
