/**
 * MND Admin — Approvals view (merged shop / job / rider approval queues).
 *
 * Replaces the three separate shop-approvals / job-approvals /
 * rider-approvals routes with one page and a client-side tab bar. All
 * three panels' pending-queue data is loaded up front by
 * loadViewData("approvals") (see app.js loadViewDataInner), so switching
 * tabs is instant — no re-navigation, no re-fetch. Already-published jobs
 * (Published jobs / Reported jobs) live on the separate "jobs" page, not
 * here — this view is approval queues only.
 *
 * Depends on globals exposed by app.js / the other approval view modules:
 * renderShopApprovals (shop-approvals.js), renderJobApprovals
 * (job-approvals.js), renderRiderApprovals (rider-approvals.js).
 */
(function () {
  const TABS = ["shop", "job", "rider"];
  let activeTab = "shop";

  function applyApprovalsTab() {
    document.querySelectorAll("[data-approvals-tab]").forEach((btn) => {
      const isActive = btn.getAttribute("data-approvals-tab") === activeTab;
      btn.classList.toggle("active", isActive);
      btn.setAttribute("aria-selected", String(isActive));
    });
    document.querySelectorAll("[data-approvals-panel]").forEach((panel) => {
      panel.hidden = panel.getAttribute("data-approvals-panel") !== activeTab;
    });
  }

  function setApprovalsTab(tab) {
    if (!TABS.includes(tab)) return;
    activeTab = tab;
    applyApprovalsTab();
  }

  function renderApprovals() {
    renderShopApprovals();
    renderJobApprovals();
    renderRiderApprovals();
    applyApprovalsTab();
  }

  document.getElementById("approvals-tabs")?.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-approvals-tab]");
    if (btn) setApprovalsTab(btn.getAttribute("data-approvals-tab"));
  });

  window.renderApprovals = renderApprovals;
  window.setApprovalsTab = setApprovalsTab;
})();
