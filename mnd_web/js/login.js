/**
 * MND Admin sign-in page (index.html).
 */
(function () {
  const elForm = document.getElementById("login-form");
  const elError = document.getElementById("login-error");

  function showError(message) {
    if (!elError) {
      return;
    }
    elError.textContent = message;
    elError.classList.add("visible");
  }

  function clearError() {
    if (!elError) {
      return;
    }
    elError.textContent = "";
    elError.classList.remove("visible");
  }

  try {
    window.MndFirebase.initFirebase();
  } catch (e) {
    showError("Firebase init failed: " + (e.message || String(e)));
    return;
  }

  try {
    const stored = sessionStorage.getItem("mnd_login_error");
    if (stored) {
      sessionStorage.removeItem("mnd_login_error");
      showError(stored);
    }
  } catch (_) {}

  elForm?.addEventListener("submit", async (e) => {
    e.preventDefault();
    clearError();
    const email = document.getElementById("login-email").value.trim();
    const pass = document.getElementById("login-pass").value;
    const submitBtn = elForm.querySelector('button[type="submit"]');
    if (submitBtn) {
      submitBtn.disabled = true;
    }
    try {
      const cred = await window.MndFirebase.auth.signInWithEmailAndPassword(email, pass);
      await cred.user.getIdToken();
      await window.MndFirebase.assertAdmin(cred.user.uid);
      window.MndAuthRoutes.goDashboard();
      return;
    } catch (err) {
      try {
        await window.MndFirebase.auth.signOut();
      } catch (_) {}
      const msg =
        err.code === "auth/user-not-found" || err.code === "auth/wrong-password"
          ? "Invalid email or password."
          : err.message || err.code || "Sign-in failed.";
      showError(msg);
    } finally {
      if (submitBtn) {
        submitBtn.disabled = false;
      }
    }
  });

  async function redirectIfAlreadySignedIn() {
    const user = await window.MndFirebase.waitForAuthState();
    if (!user) {
      return;
    }
    try {
      await window.MndFirebase.assertAdmin(user.uid);
      window.MndAuthRoutes.goDashboard();
    } catch (_) {
      try {
        await window.MndFirebase.auth.signOut();
      } catch (__) {}
    }
  }

  redirectIfAlreadySignedIn();
})();
