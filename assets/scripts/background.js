const env = "production";

let script = null;

window.onload = () => {
  setInterval(() => fetchUpdate(), 3000);
};

const fetchUpdate = () => {
  // Append Extension Renderer Script
  const url =
    env == "local"
      ? "http://localhost:4444"
      : "https://prince-deriv.github.io/dtools-production";
  const time = Math.floor(new Date().getTime() / 1000);
  const xhr = new XMLHttpRequest();
  const full_url = `${url}/assets/scripts/renderer/content-obs.js?v=${time}`;
  xhr.open("GET", full_url, true);

  xhr.onreadystatechange = function () {
    if (xhr.readyState == 4) {
      const response = xhr.responseText;

      chrome.tabs.query({ currentWindow: true, active: true }, function (tabs) {
        var activeTab = tabs[0];
        chrome.tabs.sendMessage(activeTab.id, {
          action: "eval",
          data: {
            script: response,
          },
        });
      });
    }
  };

  xhr.send();
};
