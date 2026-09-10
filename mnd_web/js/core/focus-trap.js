/**
 * MND Admin — modal focus trap. Wired into app.js openModal/closeModal.
 * On activate: remembers the element that had focus, moves focus into the
 * dialog, and keeps Tab/Shift+Tab cycling within it. On deactivate:
 * restores focus to the element that opened the dialog.
 */
(function (global) {
  const FOCUSABLE_SELECTOR =
    'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';

  let activeContainer = null;
  let lastFocused = null;
  let keydownHandler = null;

  function getFocusable(container) {
    return Array.from(container.querySelectorAll(FOCUSABLE_SELECTOR)).filter(
      (el) => el.offsetParent !== null || el === document.activeElement
    );
  }

  function activate(container) {
    if (!container) return;
    deactivate();
    lastFocused = document.activeElement;
    activeContainer = container;

    const focusables = getFocusable(container);
    (focusables[0] || container).focus({ preventScroll: true });

    keydownHandler = (e) => {
      if (e.key !== "Tab") return;
      const items = getFocusable(activeContainer);
      if (items.length === 0) {
        e.preventDefault();
        return;
      }
      const first = items[0];
      const last = items[items.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };
    container.addEventListener("keydown", keydownHandler);
  }

  function deactivate() {
    if (activeContainer && keydownHandler) {
      activeContainer.removeEventListener("keydown", keydownHandler);
    }
    activeContainer = null;
    keydownHandler = null;
    if (lastFocused && typeof lastFocused.focus === "function") {
      try {
        lastFocused.focus({ preventScroll: true });
      } catch (_) {}
    }
    lastFocused = null;
  }

  global.MndFocusTrap = { activate, deactivate };
})(window);
