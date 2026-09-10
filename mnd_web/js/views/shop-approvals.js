/**
 * MND Admin — Shop (MND Shop vendor) approvals view.
 *
 * Cut out of js/app.js verbatim (Phase 2 file-split). Depends on globals
 * exposed by app.js: cache, escapeHtml, fmtTs, vendorIsPending,
 * approveVendor, rejectVendor, openVendorModal — all still shared with
 * the main Vendors view (not yet migrated).
 */
(function () {
  function renderShopApprovals() {
    const list = document.getElementById("shop-approvals-list");
    if (!list) return;
    const pending = cache.vendors.filter((v) => vendorIsPending(v));
    list.innerHTML =
      pending.length === 0
        ? `<div class="empty-state">No MND Shop stores waiting for approval. New registrations appear here automatically.</div>`
        : pending
            .map((v) => {
              const phone = v.phone || v.phoneNumber || "—";
              const name = v.name || v.id;
              return `<div class="data-card">
        <div class="data-card__header">
          <span class="data-card__title">${escapeHtml(name)}</span>
          <span class="status-chip" style="background: var(--warning-soft); color: var(--warning)">Pending</span>
        </div>
        <div class="data-card__meta"><code>${escapeHtml(v.id)}</code></div>
        <div class="data-card__meta">${escapeHtml(v.city || "—")} · ${escapeHtml(v.category || v.tag || "—")} · ${escapeHtml(phone)}</div>
        <div class="data-card__meta">Registered ${escapeHtml(fmtTs(v.createdAt))}</div>
        <div class="data-card__actions">
          <button type="button" class="btn btn-primary btn-sm u-w-auto" data-approve-vendor="${escapeHtml(v.id)}" aria-label="Approve vendor ${escapeHtml(name)}">Approve</button>
          <button type="button" class="btn btn-ghost btn-sm u-w-auto" data-reject-vendor="${escapeHtml(v.id)}" aria-label="Reject vendor ${escapeHtml(name)}">Reject</button>
          <button type="button" class="btn btn-ghost btn-sm u-w-auto" data-edit-vendor="${escapeHtml(v.id)}" aria-label="Edit vendor ${escapeHtml(name)}">Edit</button>
        </div>
      </div>`;
            })
            .join("");
    list.querySelectorAll("[data-approve-vendor]").forEach((btn) => {
      btn.addEventListener("click", () => approveVendor(btn.getAttribute("data-approve-vendor")));
    });
    list.querySelectorAll("[data-reject-vendor]").forEach((btn) => {
      btn.addEventListener("click", () => rejectVendor(btn.getAttribute("data-reject-vendor")));
    });
    list.querySelectorAll("[data-edit-vendor]").forEach((btn) => {
      btn.addEventListener("click", () => openVendorModal(btn.getAttribute("data-edit-vendor")));
    });
  }

  window.renderShopApprovals = renderShopApprovals;
})();
