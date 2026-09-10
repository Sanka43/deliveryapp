/**
 * MND Admin — generic per-section skeleton / error-state overlay.
 *
 * Used by the router integration in app.js: on view entry, a skeleton is
 * injected into the target <section data-view> immediately (replacing the
 * old behavior of a single full-screen blocking overlay for every fetch).
 * It doesn't need to know a view's real markup — it just overlays the
 * section and hides the section's other children via CSS until the data
 * load finishes (success removes it; failure swaps it for an error state
 * with a Retry button).
 */
(function (global) {
  const OVERLAY_ATTR = "data-mnd-overlay";

  function clearOverlay(section) {
    if (!section) return;
    section.querySelectorAll(`:scope > [${OVERLAY_ATTR}]`).forEach((el) => el.remove());
    section.classList.remove("has-skeleton");
  }

  function showIn(section) {
    if (!section) return;
    clearOverlay(section);
    const wrap = document.createElement("div");
    wrap.className = "skeleton-block";
    wrap.setAttribute(OVERLAY_ATTR, "skeleton");
    wrap.setAttribute("aria-hidden", "true");
    wrap.innerHTML =
      '<div class="skeleton skeleton-card"></div>' +
      '<div class="skeleton skeleton-row"></div>' +
      '<div class="skeleton skeleton-row"></div>' +
      '<div class="skeleton skeleton-row"></div>';
    section.insertBefore(wrap, section.firstChild);
    section.classList.add("has-skeleton");
  }

  function hide(section) {
    clearOverlay(section);
  }

  function showError(section, message, onRetry) {
    if (!section) return;
    clearOverlay(section);
    const wrap = document.createElement("div");
    wrap.className = "error-state";
    wrap.setAttribute(OVERLAY_ATTR, "error");
    wrap.innerHTML =
      '<div class="error-state__icon" aria-hidden="true">&#9888;</div>' +
      '<p class="error-state__message"></p>' +
      '<button type="button" class="btn btn-primary btn-sm u-w-auto">Retry</button>';
    wrap.querySelector(".error-state__message").textContent = message || "Something went wrong.";
    wrap.querySelector("button").addEventListener("click", () => {
      clearOverlay(section);
      if (typeof onRetry === "function") onRetry();
    });
    section.insertBefore(wrap, section.firstChild);
    section.classList.add("has-skeleton");
  }

  global.MndSkeleton = { showIn, hide, showError, clear: clearOverlay };
})(window);
