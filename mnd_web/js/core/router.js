/**
 * MND Admin — hash router.
 *
 * Every view gets a real, deep-linkable, shareable URL (#/orders,
 * #/rider-approvals, ...) with working browser back/forward, without any
 * view's data/render logic changing. Views register a handler (during
 * Phase 1-3 migration, the handler is a thin bridge into the legacy
 * app.js showView function; a migrated view registers its own module).
 */
(function (global) {
  const routes = new Map();
  let defaultName = "dashboard";
  let initialized = false;

  function parseHash() {
    const h = global.location.hash || "";
    const m = h.match(/^#\/?(.*)$/);
    return m ? decodeURIComponent(m[1]).split("?")[0] : "";
  }

  function register(name, handler) {
    routes.set(name, handler);
  }

  function dispatch(name) {
    const known = name && routes.has(name);
    const target = known ? name : defaultName;
    if (name && !known && global.MndUI && global.MndUI.showToast) {
      global.MndUI.showToast(`Unknown page "${name}" — showing ${target}.`, "warning");
    }
    const handler = routes.get(target);
    if (handler) handler();
  }

  function navigate(name, opts) {
    opts = opts || {};
    const newHash = "#/" + name;
    if (opts.replace) {
      global.history.replaceState(null, "", newHash);
      dispatch(name);
      return;
    }
    if (global.location.hash === newHash) {
      // Same route already active (e.g. clicking the current nav item) —
      // hashchange won't fire, so dispatch directly.
      dispatch(name);
      return;
    }
    global.location.hash = newHash;
  }

  function onHashChange() {
    dispatch(parseHash() || defaultName);
  }

  function init(opts) {
    opts = opts || {};
    if (opts.defaultName) defaultName = opts.defaultName;
    if (initialized) return;
    initialized = true;
    global.addEventListener("hashchange", onHashChange);
    const initial = parseHash();
    if (initial) {
      dispatch(initial);
    } else {
      navigate(defaultName, { replace: true });
    }
  }

  global.MndRouter = { register, navigate, init };
})(window);
