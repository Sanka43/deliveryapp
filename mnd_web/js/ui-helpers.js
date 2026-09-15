/**
 * MND Admin — shared UI utilities (toasts, loading, debounce).
 */
(function (global) {
  const TOAST_DURATION = 4200;

  function ensureToastRoot() {
    let root = document.getElementById("toast-root");
    if (!root) {
      root = document.createElement("div");
      root.id = "toast-root";
      root.className = "toast-root";
      root.setAttribute("aria-live", "polite");
      document.body.appendChild(root);
    }
    return root;
  }

  function showToast(message, type) {
    const kind = type || "info";
    const root = ensureToastRoot();
    const el = document.createElement("div");
    el.className = `toast toast--${kind}`;
    el.setAttribute("role", "status");
    el.textContent = String(message || "");
    root.appendChild(el);
    requestAnimationFrame(() => el.classList.add("toast--visible"));
    const remove = () => {
      el.classList.remove("toast--visible");
      setTimeout(() => el.remove(), 280);
    };
    setTimeout(remove, TOAST_DURATION);
    el.addEventListener("click", remove);
  }

  function setLoading(active, label) {
    let overlay = document.getElementById("global-loading");
    if (!overlay) {
      overlay = document.createElement("div");
      overlay.id = "global-loading";
      overlay.className = "global-loading";
      overlay.hidden = true;
      overlay.innerHTML =
        '<div class="global-loading__card" role="status" aria-live="polite">' +
        '<div class="spinner" aria-hidden="true"></div>' +
        '<span class="global-loading__label">Loading…</span></div>';
      document.body.appendChild(overlay);
    }
    const lbl = overlay.querySelector(".global-loading__label");
    if (lbl) lbl.textContent = label || "Loading…";
    overlay.hidden = !active;
    overlay.classList.toggle("global-loading--on", !!active);
    document.body.classList.toggle("is-loading", !!active);
  }

  function debounce(fn, ms) {
    let t;
    return function (...args) {
      clearTimeout(t);
      t = setTimeout(() => fn.apply(this, args), ms);
    };
  }

  function setLastSync() {
    const el = document.getElementById("last-sync");
    if (!el) return;
    const now = new Date();
    el.textContent = `Updated ${now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`;
  }

  const SIDEBAR_COLLAPSED_KEY = "mnd_sidebar_collapsed";
  const isDesktopWidth = () => window.matchMedia("(min-width: 961px)").matches;

  function updateSidebarToggleLabel(toggle) {
    if (!toggle) return;
    const collapsed = document.body.classList.contains(isDesktopWidth() ? "sidebar-collapsed" : "sidebar-open");
    const label = isDesktopWidth()
      ? collapsed
        ? "Expand sidebar"
        : "Collapse sidebar"
      : collapsed
        ? "Close menu"
        : "Open menu";
    toggle.setAttribute("aria-label", label);
    toggle.setAttribute("aria-expanded", isDesktopWidth() ? String(!collapsed) : String(collapsed));
  }

  function initSidebar() {
    const toggle = document.getElementById("sidebar-toggle");
    const backdrop = document.getElementById("sidebar-backdrop");
    const close = () => {
      document.body.classList.remove("sidebar-open");
      updateSidebarToggleLabel(toggle);
    };

    // Desktop/tablet: a persisted icon-rail collapse (body.sidebar-collapsed,
    // see layout.css) that reclaims width for the dashboard's wide grids.
    // Below 960px this same button instead opens/closes the off-canvas
    // overlay drawer (body.sidebar-open) — collapsing to icons doesn't
    // help on a phone-width screen, so that behavior is untouched.
    try {
      if (isDesktopWidth() && localStorage.getItem(SIDEBAR_COLLAPSED_KEY) === "1") {
        document.body.classList.add("sidebar-collapsed");
      }
    } catch (_) {}
    updateSidebarToggleLabel(toggle);

    toggle?.addEventListener("click", () => {
      if (isDesktopWidth()) {
        const collapsed = document.body.classList.toggle("sidebar-collapsed");
        try {
          localStorage.setItem(SIDEBAR_COLLAPSED_KEY, collapsed ? "1" : "0");
        } catch (_) {}
      } else {
        document.body.classList.toggle("sidebar-open");
      }
      updateSidebarToggleLabel(toggle);
    });
    backdrop?.addEventListener("click", close);
    document.querySelectorAll(".nav-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        if (window.matchMedia("(max-width: 960px)").matches) close();
      });
    });

    initSidebarKeyboardNav();
  }

  /** Up/Down arrow keys roam between sidebar nav buttons (roving focus). */
  function initSidebarKeyboardNav() {
    const scroll = document.querySelector(".sidebar-scroll");
    if (!scroll) return;
    scroll.addEventListener("keydown", (e) => {
      if (e.key !== "ArrowDown" && e.key !== "ArrowUp") return;
      const buttons = Array.from(scroll.querySelectorAll(".nav-btn"));
      const idx = buttons.indexOf(document.activeElement);
      if (idx === -1) return;
      e.preventDefault();
      const step = e.key === "ArrowDown" ? 1 : -1;
      const next = buttons[(idx + step + buttons.length) % buttons.length];
      next.focus();
    });
  }

  function initModalKeys() {
    document.addEventListener("keydown", (e) => {
      if (e.key !== "Escape") return;
      const modal = document.getElementById("modal-backdrop");
      if (modal?.classList.contains("visible")) {
        modal.classList.remove("visible");
      }
    });
  }

  global.MndUI = {
    showToast,
    setLoading,
    debounce,
    setLastSync,
    initSidebar,
    initModalKeys,
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => {
      initSidebar();
      initModalKeys();
    });
  } else {
    initSidebar();
    initModalKeys();
  }
})(window);
