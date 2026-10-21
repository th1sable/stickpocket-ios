(() => {
  // Read only the rendered images in the current viewport. Never read input
  // values, cookies, message text, network responses or off-screen chat history.
  const found = [];
  const seen = new Set();
  for (const img of Array.from(document.images).slice(0, 5000)) {
    if (found.length >= 48) break;
    const rect = img.getBoundingClientRect();
    if (rect.width < 24 || rect.height < 24 ||
        rect.bottom <= 0 || rect.right <= 0 ||
        rect.top >= innerHeight || rect.left >= innerWidth) continue;
    if (!img.complete || img.naturalWidth < 24 || img.naturalHeight < 24) continue;
    if (img.closest('[data-e2e*="avatar"], [class*="Avatar"], [class*="avatar"]')) continue;
    let visible = true;
    for (let node = img, depth = 0; node && depth < 12; node = node.parentElement, depth++) {
      const style = getComputedStyle(node);
      if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) {
        visible = false;
        break;
      }
    }
    if (!visible) continue;
    const src = img.currentSrc || img.src;
    if (!src || seen.has(src) || src.length > 6 * 1024 * 1024) continue;
    // Blob images cannot be fetched outside their document; keep no hidden page state.
    if (!src.startsWith("https://") && !/^data:image\/(png|jpeg|gif|webp);base64,/i.test(src)) continue;
    const tag = [img.className, img.getAttribute("data-e2e"), img.alt].join(" ").toLowerCase();
    if (/avatar|profile.?photo|profile.?pic|logo/.test(tag)) continue;
    seen.add(src);
    found.push({
      id: String(found.length + 1),
      src,
      width: img.naturalWidth,
      height: img.naturalHeight,
      likelySticker: /sticker|emoji|emoticon/.test(tag)
    });
  }
  return JSON.stringify(found.sort((a, b) => Number(b.likelySticker) - Number(a.likelySticker)));
})();
