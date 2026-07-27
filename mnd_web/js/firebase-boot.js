/**
 * Shared Firebase init and admin role check for MND web admin pages.
 */
(function () {
  const COL_CUSTOMERS = "customers";

  let auth = null;
  let db = null;
  let storage = null;

  function initFirebase() {
    if (!window.firebase || !window.__FIREBASE_CONFIG__) {
      throw new Error("Firebase SDK or config missing.");
    }
    if (!firebase.apps.length) {
      firebase.initializeApp(window.__FIREBASE_CONFIG__);
    }
    auth = firebase.auth();
    if (!db) {
      db = firebase.firestore();
    }
    storage = firebase.storage();
    return { auth, db, storage };
  }

  async function ensureFirestoreAuth() {
    if (!auth) {
      initFirebase();
    }
    const user = auth.currentUser;
    if (!user) {
      return;
    }
    try {
      await user.getIdToken(true);
    } catch (_) {}
  }

  async function terminateFirestore() {
    if (!db || typeof db.terminate !== "function") {
      return;
    }
    try {
      await db.terminate();
    } catch (_) {}
    db = null;
  }

  async function assertAdmin(uid) {
    if (!db) {
      initFirebase();
    }
    try {
      const byDocId = await db.collection(COL_CUSTOMERS).doc(uid).get();
      if (!byDocId.exists) {
        throw new Error(`Missing Firestore profile: create customers/${uid} with role "admin".`);
      }
      const role = String(byDocId.data().role || "").trim().toLowerCase();
      if (role !== "admin") {
        throw new Error(`customers/${uid} must have role "admin".`);
      }
    } catch (e) {
      if (e && e.code === "permission-denied") {
        throw new Error(
          `Firestore denied reading customers/${uid}. Add that document with role "admin" and deploy rules.`,
        );
      }
      throw e;
    }
  }

  /**
   * Resolves once Firebase Auth has finished restoring the session (or confirmed signed out).
   */
  function waitForAuthState() {
    if (!auth) {
      initFirebase();
    }

    const whenReady =
      typeof auth.authStateReady === "function"
        ? auth.authStateReady()
        : Promise.resolve();

    return whenReady.then(() => {
      if (auth.currentUser) {
        return auth.currentUser;
      }
      return new Promise((resolve) => {
        let settled = false;
        const finish = (user) => {
          if (settled) {
            return;
          }
          settled = true;
          clearTimeout(timer);
          unsub();
          resolve(user);
        };
        const unsub = auth.onAuthStateChanged((user) => {
          if (user) {
            finish(user);
          }
        });
        const timer = setTimeout(() => finish(auth.currentUser), 3000);
      });
    });
  }

  window.MndFirebase = {
    initFirebase,
    assertAdmin,
    waitForAuthState,
    ensureFirestoreAuth,
    terminateFirestore,
    get auth() {
      if (!auth) {
        initFirebase();
      }
      return auth;
    },
    get db() {
      if (!db) {
        initFirebase();
      }
      return db;
    },
    get storage() {
      if (!storage) {
        initFirebase();
      }
      return storage;
    },
  };

  window.MndAuthRoutes = {
    login: "index.html",
    dashboard: "dashboard.html",
    goLogin(message) {
      if (message) {
        try {
          sessionStorage.setItem("mnd_login_error", message);
        } catch (_) {}
      }
      window.location.replace(this.login);
    },
    goDashboard() {
      window.location.replace(this.dashboard);
    },
  };
})();
