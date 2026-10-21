const { test } = require("node:test");
const assert = require("node:assert/strict");
const vm = require("node:vm");
const fs = require("node:fs");
const path = require("node:path");
const script = fs.readFileSync(path.join(__dirname, "../StickPocket/Web/VisibleImages.js"), "utf8");

function image(overrides = {}) {
  return {
    complete: true, naturalWidth: 100, naturalHeight: 100,
    currentSrc: "https://p16.tiktokcdn.com/sticker.gif", src: "",
    className: "sticker", alt: "", parentElement: null,
    getBoundingClientRect: () => ({ top: 10, left: 10, right: 110, bottom: 110, width: 100, height: 100 }),
    closest: () => null,
    getAttribute: () => null,
    style: { display: "block", visibility: "visible", opacity: "1" },
    ...overrides
  };
}

function scan(images) {
  const document = { images };
  // Any accidental credential or message scan fails immediately.
  Object.defineProperty(document, "cookie", { get() { throw Error("Credential access"); } });
  Object.defineProperty(document, "body", { get() { throw Error("Message text access"); } });
  document.querySelectorAll = () => { throw Error("Broad page scan"); };
  return JSON.parse(vm.runInNewContext(script, {
    document, innerWidth: 390, innerHeight: 844,
    getComputedStyle: node => node.style
  }));
}

test("returns source bytes reference and dimensions, never text", () => {
  const result = scan([image({ alt: "private message must not be exported" })]);
  assert.equal(result.length, 1);
  assert.deepEqual(Object.keys(result[0]).sort(), ["height", "id", "likelySticker", "src", "width"]);
  assert.equal(JSON.stringify(result).includes("private message"), false);
});

test("deduplicates responsive images by currentSrc", () => {
  assert.equal(scan([image(), image({ src: "https://p16.tiktokcdn.com/fallback.jpg" })]).length, 1);
});

test("excludes images outside viewport", () => {
  assert.equal(scan([image({ getBoundingClientRect: () => ({
    top: 900, left: 0, right: 100, bottom: 1000, width: 100, height: 100
  }) })]).length, 0);
});

test("excludes avatars and profile photos", () => {
  assert.equal(scan([image({ className: "ProfilePhoto" }), image({ closest: () => ({}) })]).length, 0);
});

test("excludes CSS-hidden images and hidden ancestors", () => {
  const parent = { parentElement: null, style: { display: "none", visibility: "visible", opacity: "1" } };
  assert.equal(scan([image({ parentElement: parent })]).length, 0);
});

test("ignores incomplete, tiny and unsupported-scheme images", () => {
  assert.equal(scan([image({ complete: false }), image({ naturalWidth: 1 }),
    image({ currentSrc: "javascript:alert(1)" }), image({ currentSrc: "file:///image.png" }),
    image({ currentSrc: "blob:https://tiktok.com/123" })]).length, 0);
});

test("allows embedded raster images", () => {
  assert.equal(scan([image({ currentSrc: "data:image/png;base64,AAAA" })]).length, 1);
});

test("caps results to prevent large page transfers", () => {
  const images = Array.from({ length: 80 }, (_, i) => image({ currentSrc: "https://p16.tiktokcdn.com/" + i + ".gif" }));
  assert.equal(scan(images).length, 48);
});

test("ranks likely stickers first without hiding other visible images", () => {
  const result = scan([image({ className: "", currentSrc: "https://p16.tiktokcdn.com/photo.jpg" }), image()]);
  assert.equal(result.length, 2);
  assert.equal(result[0].likelySticker, true);
});
