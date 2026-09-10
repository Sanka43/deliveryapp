/**
 * MND Admin — Job post approvals (pending-approval queue only).
 *
 * Cut out of js/app.js verbatim (Phase 2 file-split). The other two
 * panels in the Job approvals view — Published jobs, Reported jobs —
 * are unrelated tables (renderPublishedJobs/renderJobReports) and stay
 * in app.js; only the pending-approval card-list moved.
 *
 * Depends on globals exposed by app.js: cache, escapeHtml, fmtTs,
 * approveJob, rejectJob.
 */
(function () {
  function renderJobApprovals() {
    const list = document.getElementById("job-approvals-list");
    if (!list) return;
    const pending = cache.jobs.filter((j) => String(j.status || "").toLowerCase() === "pending");
    list.innerHTML =
      pending.length === 0
        ? `<div class="empty-state">No job posts waiting for approval.</div>`
        : pending
            .map((j) => {
              const title = j.title || "—";
              return `<div class="data-card">
        <div class="data-card__header">
          <span class="data-card__title">${escapeHtml(title)}</span>
          <span class="status-chip" style="background: var(--warning-soft); color: var(--warning)">Pending</span>
        </div>
        <div class="data-card__meta">${escapeHtml(j.companyName || "—")} · ${escapeHtml(j.salary || "—")}</div>
        <div class="data-card__meta">${escapeHtml(j.remote ? "Remote" : j.location || "—")} · ${escapeHtml(j.type || j.category || "—")}</div>
        <div class="data-card__meta">Posted ${escapeHtml(fmtTs(j.createdAt))}</div>
        <div class="data-card__actions">
          <button type="button" class="btn btn-primary btn-sm u-w-auto" data-approve-job="${escapeHtml(j.id)}" aria-label="Approve job ${escapeHtml(title)}">Approve</button>
          <button type="button" class="btn btn-ghost btn-sm u-w-auto" data-reject-job="${escapeHtml(j.id)}" aria-label="Reject job ${escapeHtml(title)}">Reject</button>
        </div>
      </div>`;
            })
            .join("");
    list.querySelectorAll("[data-approve-job]").forEach((btn) => {
      btn.addEventListener("click", () => approveJob(btn.getAttribute("data-approve-job")));
    });
    list.querySelectorAll("[data-reject-job]").forEach((btn) => {
      btn.addEventListener("click", () => rejectJob(btn.getAttribute("data-reject-job")));
    });
  }

  window.renderJobApprovals = renderJobApprovals;
})();
