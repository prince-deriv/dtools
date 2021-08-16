const env = "production";
const offline_key = "dtools-popup-offline";

window.is_offline = false;
window.onload = () => {
  // Append Extension Renderer Script
  const url =
    env == "local"
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
    }
  };

  try {
    xhr.send();
    return (xhr.status >= 200 && xhr.status < 300) || xhr.status === 304;
  } catch (error) {}
};
