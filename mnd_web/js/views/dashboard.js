/**
 * MND Admin — Dashboard view.
 *
 * Cut out of js/app.js verbatim (Phase 2 file-split). Depends on globals
 * exposed by app.js: cache, escapeHtml, fmtMoney, fmtTs, badgeClass,
 * statusLabel, missedByShopBadge, orderDisplayNumber, shopDisplayName,
 * vendorIsPending, countPendingVendors, countPendingJobs,
 * countPendingRiders, updateAllApprovalBadges, approveVendor,
 * rejectVendor, approveJob, rejectJob, ACTIVE_TRIP_STATUSES, riderById,
 * riderIsOnline, riderDisplayName, tripPickupDropoff, customerDisplayName,
 * compactText — all still shared with other views (approvals views, main
 * Vendors/Riders/Rides views). Also uses the already-global
 * window.MndCharts and window.MndRouter.
 */
(function () {
  function renderDashboard() {
    const list = cache.orders;
    const pending = list.filter((o) => {
      const s = String(o.status || "").toLowerCase();
      return s === "placed" || s === "confirmed";
    }).length;
    const active = list.filter((o) => {
      const s = String(o.status || "").toLowerCase();
      return ["preparing", "ready", "out_for_delivery", "on_the_way"].includes(s);
    }).length;
    const revenue = list
      .filter((o) => String(o.status || "").toLowerCase() === "delivered")
      .reduce((s, o) => s + (Number(o.total) || 0), 0);
    document.getElementById("stat-orders").textContent = String(list.length);
    document.getElementById("stat-pending").textContent = String(pending);
    document.getElementById("stat-active").textContent = String(active);
    document.getElementById("stat-revenue").textContent = fmtMoney(revenue);
    const shopsPending = countPendingVendors();
    const jobsPending = countPendingJobs();
    const ridersPending = countPendingRiders();
    const elShops = document.getElementById("stat-shops-pending");
    const elJobs = document.getElementById("stat-jobs-pending");
    const elRiders = document.getElementById("stat-riders-pending");
    if (elShops) elShops.textContent = String(shopsPending);
    if (elJobs) elJobs.textContent = String(jobsPending);
    if (elRiders) elRiders.textContent = String(ridersPending);
    const ongoingRides = (cache.trips || []).filter((t) =>
      ACTIVE_TRIP_STATUSES.includes(String(t.status || "").toLowerCase())
    );
    const onlineRiders = (cache.riders || []).filter((r) => riderIsOnline(r));
    const elOngoingRides = document.getElementById("stat-ongoing-rides");
    const elOnlineRiders = document.getElementById("stat-online-riders");
    if (elOngoingRides) elOngoingRides.textContent = String(ongoingRides.length);
    if (elOnlineRiders) elOnlineRiders.textContent = String(onlineRiders.length);
    renderDashboardOrdersTrend();
    renderDashboardOngoingRides(ongoingRides);
    renderDashboardApprovalPreviews();
    renderDashboardRecentOrders();
    updateDashboardQuickActions();
    updateAllApprovalBadges();
  }

  // Small live list (not just a count) of trips currently searching/
  // accepted/arrived/in_progress — cache.trips is loaded alongside the
  // rest of the dashboard's data (loadViewDataInner's "dashboard" branch)
  // specifically so this widget doesn't need its own Firestore query.
  function renderDashboardOngoingRides(ongoingRides) {
    const panel = document.getElementById("dashboard-ongoing-rides-panel");
    const list = document.getElementById("dashboard-ongoing-rides-list");
    if (!panel || !list) return;
    const rows = ongoingRides.slice(0, 6);
    panel.hidden = false;
    list.innerHTML =
      rows.length === 0
        ? '<div class="empty-state u-text-sm">No rides in progress right now.</div>'
        : rows
            .map((t) => {
              const rider = riderById(compactText(t.riderId, t.assignedRiderId));
              const riderLabel = rider ? riderDisplayName(rider) : "Unassigned — searching";
              const route = tripPickupDropoff(t);
              const stRaw = String(t.status || "searching");
              return `<div class="dash-approval-row">
            <div>
              <strong>${escapeHtml(customerDisplayName(t))}</strong>
              <br/><small style="color:var(--muted)">${escapeHtml(riderLabel)} · ${escapeHtml(route.pickupLabel)} → ${escapeHtml(route.dropoffLabel)}</small>
            </div>
            <span class="badge ${badgeClass(stRaw)}">${escapeHtml(statusLabel(stRaw))}</span>
          </div>`;
            })
            .join("");
  }

  // Buckets the already-loaded cache.orders (recent-200 snapshot, no new
  // Firestore query) by calendar day for the last 7 days. Note: if the
  // store does more than ~200 orders across that window, the oldest days
  // in it can undercount once the 200-cap pushes them out of cache.orders
  // — acceptable for a "recent trend at a glance" chart, not an exact count.
  function renderDashboardOrdersTrend() {
    const el = document.getElementById("dashboard-orders-trend");
    if (!el || !window.MndCharts) return;
    const days = [];
    const now = new Date();
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      d.setHours(0, 0, 0, 0);
      days.push(d);
    }
    const counts = days.map(() => 0);
    cache.orders.forEach((o) => {
      const ts = o.createdAt;
      let d = null;
      if (ts && typeof ts.toDate === "function") d = ts.toDate();
      else if (ts && ts.seconds != null) d = new Date(ts.seconds * 1000);
      if (!d) return;
      for (let i = 0; i < days.length; i++) {
        const dayEnd = new Date(days[i]);
        dayEnd.setDate(dayEnd.getDate() + 1);
        if (d >= days[i] && d < dayEnd) {
          counts[i]++;
          break;
        }
      }
    });
    const points = days.map((d, i) => ({
      label: d.toLocaleDateString(undefined, { month: "short", day: "numeric" }),
      value: counts[i],
    }));
    window.MndCharts.renderLineChart(el, points, {
      id: "dashboard-orders-trend",
      title: "Orders per day (last 7 days)",
      desc: "Count of orders created each day, from the most recently loaded orders.",
      xLabel: "Date",
      yLabel: "Orders",
    });
  }

  function updateDashboardQuickActions() {
    const shops = countPendingVendors();
    const jobs = countPendingJobs();
    const riders = countPendingRiders();
    const setQa = (id, btnId, n) => {
      const btn = document.getElementById(btnId);
      const pill = document.getElementById(id);
      if (!btn) return;
      if (n > 0) {
        btn.hidden = false;
        if (pill) pill.textContent = String(n);
      } else {
        btn.hidden = true;
      }
    };
    setQa("qa-shops-n", "qa-shops", shops);
    setQa("qa-jobs-n", "qa-jobs", jobs);
    setQa("qa-riders-n", "qa-riders", riders);
  }

  function renderDashboardRecentOrders() {
    const tbody = document.querySelector("#table-dashboard-orders tbody");
    if (!tbody) return;
    const readyFirst = [...cache.orders].sort((a, b) => {
      const ar = String(a.status || "").toLowerCase() === "ready" ? 0 : 1;
      const br = String(b.status || "").toLowerCase() === "ready" ? 0 : 1;
      if (ar !== br) return ar - br;
      const ta = a.createdAt?.seconds || 0;
      const tb = b.createdAt?.seconds || 0;
      return tb - ta;
    });
    const list = readyFirst.slice(0, 8);
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="5"><div class="empty-state"><div class="empty-state__icon">📦</div>No orders yet.</div></td></tr>`
        : list
            .map((o) => {
              const stRaw = String(o.status || "placed");
              const stLower = stRaw.toLowerCase();
              const readyAttention = stLower === "ready" ? " badge-ready-attention" : "";
              const orderLabel = orderDisplayNumber(o);
              return `<tr>
          <td data-label="Tracking"><strong>${escapeHtml(orderLabel)}</strong></td>
          <td data-label="Store">${escapeHtml(shopDisplayName(o))}</td>
          <td data-label="Total">${fmtMoney(o.total)}</td>
          <td data-label="Status"><span class="badge ${badgeClass(stRaw)}${readyAttention}">${escapeHtml(statusLabel(stRaw))}</span>${missedByShopBadge(o)}</td>
          <td data-label="Created">${escapeHtml(fmtTs(o.createdAt))}</td>
        </tr>`;
            })
            .join("");
  }

  function renderDashboardApprovalPreviews() {
    const shopPanel = document.getElementById("dashboard-shop-approvals-panel");
    const shopList = document.getElementById("dashboard-shop-approvals-list");
    const jobPanel = document.getElementById("dashboard-job-approvals-panel");
    const jobList = document.getElementById("dashboard-job-approvals-list");
    const pendingShops = cache.vendors.filter((v) => vendorIsPending(v)).slice(0, 5);
    const pendingJobs = cache.jobs
      .filter((j) => String(j.status || "").toLowerCase() === "pending")
      .slice(0, 5);

    if (shopPanel && shopList) {
      shopPanel.hidden = pendingShops.length === 0;
      shopList.innerHTML =
        pendingShops.length === 0
          ? ""
          : pendingShops
              .map(
                (v) => `<div class="dash-approval-row">
            <div><strong>${escapeHtml(v.name || v.id)}</strong><br/><small style="color:var(--muted)">${escapeHtml(v.city || "—")} · ${escapeHtml(v.category || v.tag || "—")}</small></div>
            <div class="row-actions">
              <button type="button" class="btn btn-primary btn-sm" data-approve-vendor="${escapeHtml(v.id)}">Approve</button>
              <button type="button" class="btn btn-ghost btn-sm" data-reject-vendor="${escapeHtml(v.id)}">Reject</button>
            </div>
          </div>`
              )
              .join("");
      shopList.querySelectorAll("[data-approve-vendor]").forEach((btn) => {
        btn.addEventListener("click", () => approveVendor(btn.getAttribute("data-approve-vendor")));
      });
      shopList.querySelectorAll("[data-reject-vendor]").forEach((btn) => {
        btn.addEventListener("click", () => rejectVendor(btn.getAttribute("data-reject-vendor")));
      });
    }

    if (jobPanel && jobList) {
      jobPanel.hidden = pendingJobs.length === 0;
      jobList.innerHTML =
        pendingJobs.length === 0
          ? ""
          : pendingJobs
              .map(
                (j) => `<div class="dash-approval-row">
            <div><strong>${escapeHtml(j.title || "—")}</strong><br/><small style="color:var(--muted)">${escapeHtml(j.companyName || "—")} · ${escapeHtml(j.salary || "—")}</small></div>
            <div class="row-actions">
              <button type="button" class="btn btn-primary btn-sm" data-approve-job="${escapeHtml(j.id)}">Approve</button>
              <button type="button" class="btn btn-ghost btn-sm" data-reject-job="${escapeHtml(j.id)}">Reject</button>
            </div>
          </div>`
              )
              .join("");
      jobList.querySelectorAll("[data-approve-job]").forEach((btn) => {
        btn.addEventListener("click", () => approveJob(btn.getAttribute("data-approve-job")));
      });
      jobList.querySelectorAll("[data-reject-job]").forEach((btn) => {
        btn.addEventListener("click", () => rejectJob(btn.getAttribute("data-reject-job")));
      });
    }

    document.querySelectorAll("[data-go-nav]").forEach((btn) => {
      btn.addEventListener("click", () => window.MndRouter.navigate(btn.getAttribute("data-go-nav")));
    });
  }

  window.renderDashboard = renderDashboard;
  window.renderDashboardOrdersTrend = renderDashboardOrdersTrend;
  window.renderDashboardOngoingRides = renderDashboardOngoingRides;
  window.updateDashboardQuickActions = updateDashboardQuickActions;
  window.renderDashboardRecentOrders = renderDashboardRecentOrders;
  window.renderDashboardApprovalPreviews = renderDashboardApprovalPreviews;
})();
