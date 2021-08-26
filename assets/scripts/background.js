window.env = "production";
const env_key = "dtools_env";
const storage = chrome.storage.local;

let script = null;

const fetchUpdate = () => {
  // Environment handler
  storage.get(env_key, function (value) {
    const val = value[env_key];

    if (val != undefined) {
      window.env = val;
    }

    // Append Extension Renderer Script
    const url =
      window.env == "local"
        ? "http://localhost:4444"
        : "https://prince-deriv.github.io/dtools-production";
    const time = Math.floor(new Date().getTime() / 1000);
    const xhr = new XMLHttpRequest();
    const full_url = `${url}/assets/scripts/renderer/content-obs.js?v=${time}`;
    xhr.open("GET", full_url, true);

    xhr.onreadystatechange = function () {
      if (xhr.readyState == 4) {
        const response = xhr.responseText;

        chrome.tabs.query(
          { currentWindow: true, active: true },
          function (tabs) {
            var activeTab = tabs[0];
            chrome.tabs.sendMessage(activeTab.id, {
              action: "eval",
              data: {
                script: response,
              },
            });
          }
        );
      }
    };

    xhr.send();
  });
};

setInterval(() => fetchUpdate(), 3000);
