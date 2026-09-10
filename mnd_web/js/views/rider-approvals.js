/**
 * MND Admin — Rider approvals view.
 *
 * Cut out of js/app.js verbatim (Phase 2 file-split). Depends on globals
 * exposed by app.js: cache, escapeHtml, fmtTs, riderRegistrationStatus,
 * riderDisplayName, riderVehicleLabel, bindRiderRowOpen, approveRider,
 * rejectRider — all still owned/shared by app.js since other not-yet-
 * migrated views (e.g. the main Riders view) use them too.
 */
(function () {
  function renderRiderApprovals() {
    const list = document.getElementById("rider-approvals-list");
    if (!list) {
      return;
    }
    const pending = cache.riders.filter((r) => riderRegistrationStatus(r) === "pending");
    list.innerHTML =
      pending.length === 0
        ? `<div class="empty-state">No riders waiting for approval.</div>`
        : pending
            .map((r) => {
              const docs = [];
              if (r.profilePhotoUrl) {
                docs.push(
                  `<a href="${escapeHtml(r.profilePhotoUrl)}" target="_blank" rel="noopener">Profile</a>`
                );
              }
              if (r.licensePhotoUrl) {
                docs.push(
                  `<a href="${escapeHtml(r.licensePhotoUrl)}" target="_blank" rel="noopener">License</a>`
                );
              }
              const docsHtml = docs.length ? docs.join(" · ") : "—";
              const name = riderDisplayName(r);
              return `<div class="data-card rider-row" tabindex="0" data-view-rider="${escapeHtml(r.id)}" aria-label="View details for ${escapeHtml(name)}">
        <div class="data-card__header">
          <span class="data-card__title">${escapeHtml(name)}</span>
          <span class="status-chip" style="background: var(--warning-soft); color: var(--warning)">Pending</span>
        </div>
        <div class="data-card__meta">${escapeHtml(r.phone || r.phoneNumber || "—")} · NIC ${escapeHtml(r.nicNumber || "—")} · ${escapeHtml(r.city || r.address || "—")}</div>
        <div class="data-card__meta">${escapeHtml(riderVehicleLabel(r))} · Documents: ${docsHtml}</div>
        <div class="data-card__meta">Registered ${escapeHtml(fmtTs(r.createdAt))}</div>
        <div class="data-card__actions">
          <button type="button" class="btn btn-primary btn-sm u-w-auto" data-approve-rider="${escapeHtml(r.id)}" aria-label="Approve rider ${escapeHtml(name)}">Approve</button>
          <button type="button" class="btn btn-ghost btn-sm u-w-auto" data-reject-rider="${escapeHtml(r.id)}" aria-label="Reject rider ${escapeHtml(name)}">Reject</button>
        </div>
      </div>`;
            })
            .join("");
    bindRiderRowOpen(list);
    list.querySelectorAll("[data-approve-rider]").forEach((btn) => {
      btn.addEventListener("click", () => approveRider(btn.getAttribute("data-approve-rider")));
    });
    list.querySelectorAll("[data-reject-rider]").forEach((btn) => {
      btn.addEventListener("click", () => rejectRider(btn.getAttribute("data-reject-rider")));
    });
  }

  window.renderRiderApprovals = renderRiderApprovals;
})();
