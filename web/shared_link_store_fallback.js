(function () {
  "use strict";

  // The website owns its dialog. Loading this script does not create UI,
  // launch the app, detect installation or navigate anywhere.
  const appStoreUrl = "https://apps.apple.com/us/app/kaizenteams/id6773032580";
  const playStoreUrl = "https://play.google.com/store/apps/details?id=com.kaizenteam";

  function getStoreUrl() {
    const userAgent = window.navigator.userAgent || "";
    if (/Android/i.test(userAgent)) return playStoreUrl;
    if (/iPhone|iPad|iPod/i.test(userAgent) ||
        (/Macintosh/i.test(userAgent) && window.navigator.maxTouchPoints > 1)) {
      return appStoreUrl;
    }
    return null;
  }

  // Call only from the website's existing dialog button click handler.
  function openStore() {
    const storeUrl = getStoreUrl();
    if (!storeUrl) return false;
    window.location.assign(storeUrl);
    return true;
  }

  // Store selection is independent of the page path: shared content, auth,
  // verification and organization pages all use the same explicit action.
  window.KaizenSharedLinks = Object.freeze({ getStoreUrl, openStore });
})();
