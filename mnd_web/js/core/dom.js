/**
 * MND Admin — DOM helpers shared by legacy app.js and new view modules.
 * Not a virtual DOM: just escaping plus a cheap re-render skip/preserve
 * helper for listener-driven views (Support chat, Ongoing riders) that
 * currently re-render on every Firestore snapshot tick.
 */
(function (global) {
  function esc(value) {
    if (value == null) return "";
    const d = document.createElement("div");
    d.textContent = value;
    return d.innerHTML;
  }

  /**
   * Writes htmlString into el, but skips the DOM write entirely if the
   * content is unchanged since the last renderInto call on this element —
   * and optionally preserves scroll position / the focused element across
   * a write, so a background snapshot update doesn't jump a chat's scroll
   * or steal focus from an in-progress filter input.
   */
  const lastHtml = new WeakMap();

  function renderInto(el, htmlString, opts) {
    if (!el) return;
    opts = opts || {};
    if (lastHtml.get(el) === htmlString) return;

    const preserveScroll = opts.preserveScroll;
    const preserveFocus = opts.preserveFocus;
    const scrollTop = preserveScroll ? el.scrollTop : null;

    let focusedSelector = null;
    let selectionStart = null;
    let selectionEnd = null;
    if (preserveFocus && el.contains(document.activeElement)) {
      const active = document.activeElement;
      if (active && active.id) {
        focusedSelector = "#" + active.id;
        if (typeof active.selectionStart === "number") {
          selectionStart = active.selectionStart;
          selectionEnd = active.selectionEnd;
        }
      }
    }

    el.innerHTML = htmlString;
    lastHtml.set(el, htmlString);

    if (scrollTop != null) el.scrollTop = scrollTop;
    if (focusedSelector) {
      const restored = el.querySelector(focusedSelector);
      if (restored) {
        restored.focus({ preventScroll: true });
        if (selectionStart != null && typeof restored.setSelectionRange === "function") {
          try {
            restored.setSelectionRange(selectionStart, selectionEnd);
          } catch (_) {}
        }
      }
    }
  }

  global.MndDom = { esc, renderInto };
})(window);
