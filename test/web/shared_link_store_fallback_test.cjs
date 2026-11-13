const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const { runInNewContext } = require("node:vm");

const script = readFileSync(path.join(__dirname, "../../web/shared_link_store_fallback.js"), "utf8");
const appStore = "https://apps.apple.com/us/app/kaizenteams/id6773032580";
const playStore = "https://play.google.com/store/apps/details?id=com.kaizenteam";

function loadHelper(url, userAgent, maxTouchPoints = 0) {
  const navigations = [];
  const unexpectedSideEffect = () => assert.fail("The website must own UI and user actions");
  const location = {
    href: new URL(url, "https://app.kaizenteams.ai").href,
    replace: unexpectedSideEffect,
    assign: (url) => navigations.push(url),
  };
  const window = {
    location,
    navigator: { userAgent, maxTouchPoints },
    open: unexpectedSideEffect,
    addEventListener: unexpectedSideEffect,
    setTimeout: unexpectedSideEffect,
  };
  const originalHref = location.href;
  const document = new Proxy({}, { get: unexpectedSideEffect });
  const run = () => runInNewContext(script, {
    window, document,
    setTimeout: unexpectedSideEffect,
    setInterval: unexpectedSideEffect,
  });
  run();
  assert.equal(location.href, originalHref);
  assert.deepEqual(navigations, []);
  return {
    getStoreUrl: () => window.KaizenSharedLinks.getStoreUrl(),
    clickDialogButton: () => window.KaizenSharedLinks.openStore(),
    navigations,
    run,
    changeWebUrl: (href) => { location.href = href; },
  };
}

for (const host of ["app.kaizenteams.ai", "dev.kaizenteams.ai", "api.kaizenteams.ai"]) {
  for (const type of ["paygrades", "seat-profile", "lms"]) {
    test(`${host}/${type}: browser loads stay put and only the dialog action opens the store`, () => {
      const url = `https://${host}/shared/${type}/Public-ID_123/?source=share`;
      for (const [userAgent, store] of [["Android", playStore], ["iPhone", appStore]]) {
        const helper = loadHelper(url, userAgent);
        assert.equal(helper.getStoreUrl(), store);
        assert.deepEqual(helper.navigations, []);
        assert.equal(helper.clickDialogButton(), true);
        assert.deepEqual(helper.navigations, [store]);
      }
    });
  }
}

test("iPad and iPod actions open the App Store, including iPad desktop mode", () => {
  for (const userAgent of ["iPad", "iPod", "Macintosh"]) {
    const helper = loadHelper("/shared/paygrades/id", userAgent, 5);
    assert.equal(helper.getStoreUrl(), appStore);
    assert.equal(helper.clickDialogButton(), true);
    assert.deepEqual(helper.navigations, [appStore]);
  }
});

test("verification, organization and auth visits never redirect until the dialog action", () => {
  for (const link of [
    "/verify_token", "/verify_token/header.payload.signature/?source=email",
    "/organization", "/organization/id/ltc/assigned-track/track-id",
    "/auth", "/auth/", "/auth/login",
    "/auth/google/callback?code=code&state=state",
    "/auth/password-reset/confirm?token=token", "/AUTH/password-reset/?token=token",
  ]) {
    for (const [userAgent, store] of [["Android", playStore], ["iPhone", appStore]]) {
      const helper = loadHelper(link, userAgent);
      assert.deepEqual(helper.navigations, []);
      helper.clickDialogButton();
      assert.deepEqual(helper.navigations, [store]);
    }
  }
});

test("desktop and unknown devices do not navigate to an unrelated mobile store", () => {
  for (const userAgent of ["Macintosh", "Windows", "Linux x86_64", ""]) {
    const helper = loadHelper("/shared/paygrades/id", userAgent);
    assert.equal(helper.getStoreUrl(), null);
    assert.equal(helper.clickDialogButton(), false);
    assert.deepEqual(helper.navigations, []);
  }
});

test("query parameters and fragments cannot replace the official store destination", () => {
  const url = "/shared/paygrades/id?redirect=https://example.com#Intent;scheme=other;end";
  for (const [userAgent, store] of [["Android", playStore], ["iPhone", appStore]]) {
    const helper = loadHelper(url, userAgent);
    helper.clickDialogButton();
    assert.deepEqual(helper.navigations, [store]);
  }
});

test("the dialog store action still works after client-side routing changes the page", () => {
  const helper = loadHelper("/shared/paygrades/first", "Android");
  helper.changeWebUrl("https://dev.kaizenteams.ai/login");
  assert.deepEqual(helper.navigations, []);
  helper.clickDialogButton();
  assert.deepEqual(helper.navigations, [playStore]);
});

test("unrelated pages do not navigate or create UI when the script is loaded", () => {
  for (const url of ["/", "/settings", "/api/v1/shared/content/id/", "/shared/paygrades/"]) {
    const helper = loadHelper(url, "Android");
    assert.deepEqual(helper.navigations, []);
  }
});

test("duplicate script includes do not create UI, register listeners or navigate", () => {
  const helper = loadHelper("/shared/paygrades/id", "iPhone");
  helper.run();
  assert.deepEqual(helper.navigations, []);
  helper.clickDialogButton();
  assert.deepEqual(helper.navigations, [appStore]);
});
