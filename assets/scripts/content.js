let content_script = null;

const env = "production";

const url =
  env == "local"
    ? "http://localhost:4444"
    : "https://prince-deriv.github.io/dtools-production";

const msgHandler = (request, sender, sendResponse) => {
  const { action, data } = request;

  switch (action) {
    case "eval":
      const { script } = data;

      if (script != content_script) {
        if (!content_script) {
          eval(script);
          content_script = script;
        } else {
          window.location.reload();
        }
      }
      break;
  }
};

chrome.runtime.onMessage.addListener(function (request, sender, sendResponse) {
  msgHandler(request, sender, sendResponse);
});
