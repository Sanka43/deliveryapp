/**
 * MND Admin — Dashboard view (wireframe redesign).
 *
 * Depends on globals exposed by app.js: cache, escapeHtml, fmtMoney, fmtTs,
 * badgeClass, statusLabel, missedByShopBadge, orderMissedByShop,
 * orderDisplayNumber, shopDisplayName, vendorIsPending, countPendingVendors,
 * countPendingJobs, countPendingRiders, updateAllApprovalBadges,
 * riderIsOnline, riderIsApproved, riderCashInHand, riderDisplayName,
 * riderById, tripPickupDropoff, customerDisplayName, compactText,
 * countUnreadSupportThreads, countUnreadVendorSupportThreads,
 * openOrderDetails, openAssignRiderModal, openVendorModal,
 * openRiderDetailView, toast, ACTIVE_TRIP_STATUSES — also
 * window.MndCharts and window.MndRouter.
 */
(function () {
  let dashboardChartRangeDays = 7;

  // Real-time is handled in app.js (startDashboardListeners/
  // stopDashboardListeners) via live onSnapshot listeners on every
  // widget-backing collection, started on nav-in and stopped on nav-out —
  // this view only renders whatever's currently in `cache`.

  function tsToDate(val) {
    if (!val) return null;
    if (typeof val.toDate === "function") return val.toDate();
    if (val.seconds != null) return new Date(val.seconds * 1000);
    return null;
  }

  function agoLabel(date) {
    if (!date) return "—";
    const ms = Date.now() - date.getTime();
    if (ms < 60000) return "just now";
    const totalMin = Math.floor(ms / 60000);
    if (totalMin < 60) return `${totalMin} min`;
    const h = Math.floor(totalMin / 60);
    const m = totalMin % 60;
    return `${h}h ${m}m`;
  }

  function setText(id, val) {
    const el = document.getElementById(id);
    if (el) el.textContent = String(val);
  }

  function setDelta(id, diff, suffix) {
    const el = document.getElementById(id);
    if (!el) return;
    const arrow = diff > 0 ? "▲" : diff < 0 ? "▼" : "—";
    el.textContent = `${arrow} ${Math.abs(diff)} ${suffix}`;
  }

  // data-go-tab is optional and only meaningful for the merged "approvals"
  // view (data-go-nav="approvals") — it picks which of the shop/job/rider
  // tabs to land on, since that route no longer distinguishes them itself.
  function goNav(el) {
    window.MndRouter.navigate(el.getAttribute("data-go-nav"));
    const tab = el.getAttribute("data-go-tab");
    if (tab && window.setApprovalsTab) window.setApprovalsTab(tab);
  }

  function bindGoNav(container) {
    if (!container) return;
    container.querySelectorAll("[data-go-nav]").forEach((el) => {
      if (el.tagName !== "BUTTON") {
        el.setAttribute("role", "button");
        el.setAttribute("tabindex", "0");
        el.addEventListener("keydown", (e) => {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            goNav(el);
          }
        });
      }
      el.addEventListener("click", () => goNav(el));
    });
  }

  function renderDashboard() {
    renderDashboardStatTiles();
    renderDashboardNeedsAction();
    renderDashboardOrdersVsRidesChart();
    renderDashboardIncomeVsOutgoings();
    const ongoingRides = (cache.trips || []).filter((t) =>
      ACTIVE_TRIP_STATUSES.includes(String(t.status || "").toLowerCase())
    );
    renderDashboardOngoingRides(ongoingRides);
    renderDashboardRidersOnline();
    renderDashboardOrdersNeedingEyes();
    renderDashboardMoneyQueue();
    renderDashboardTopShops();
    renderDashboardLowRatingsReports();
    renderDashboardCatalogGrowth();
    updateAllApprovalBadges();
  }

  // ---------------------------------------------------------------------
  // Needs action now
  // ---------------------------------------------------------------------
  function renderDashboardNeedsAction() {
    const el = document.getElementById("dashboard-needs-action");
    const empty = document.getElementById("dashboard-needs-action-empty");
    if (!el) return;
    const shops = countPendingVendors();
    const jobs = countPendingJobs();
    const riders = countPendingRiders();
    const withdrawals = cache.withdrawals || [];
    const withdrawalsSum = withdrawals.reduce((s, w) => s + (Number(w.amountLkr) || 0), 0);
    const missedOrders = cache.orders.filter((o) => orderMissedByShop(o)).length;

    const tiles = [];
    if (shops > 0) tiles.push({ label: "Shop approvals", value: String(shops), action: "Review", nav: "approvals", tab: "shop" });
    if (jobs > 0) tiles.push({ label: "Job approvals", value: String(jobs), action: "Review", nav: "approvals", tab: "job" });
    if (riders > 0) tiles.push({ label: "Rider approvals", value: String(riders), action: "Review", nav: "approvals", tab: "rider" });
    if (withdrawals.length > 0) {
      tiles.push({
        label: "Withdrawals pending",
        value: `${withdrawals.length} · ${fmtMoney(withdrawalsSum)}`,
        action: "Release",
        nav: "withdrawals",
      });
    }
    if (missedOrders > 0) {
      tiles.push({ label: "Orders missed by shop", value: String(missedOrders), action: "Open", nav: "orders" });
    }

    if (tiles.length === 0) {
      el.innerHTML = "";
      if (empty) empty.hidden = false;
      return;
    }
    if (empty) empty.hidden = true;
    el.innerHTML = tiles
      .map(
        (t) => `<div class="needs-action-tile">
        <div class="label">${escapeHtml(t.label)}</div>
        <div class="value">${escapeHtml(t.value)}</div>
        <button type="button" class="btn btn-ghost btn-sm u-w-auto" data-go-nav="${escapeHtml(t.nav)}"${t.tab ? ` data-go-tab="${escapeHtml(t.tab)}"` : ""}>${escapeHtml(t.action)}</button>
      </div>`
      )
      .join("");
    bindGoNav(el);
  }

  // ---------------------------------------------------------------------
  // Stat tiles
  // ---------------------------------------------------------------------
  function renderDashboardStatTiles() {
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yestStart = new Date(todayStart);
    yestStart.setDate(yestStart.getDate() - 1);

    const ordersToday = cache.orders.filter((o) => {
      const d = tsToDate(o.createdAt);
      return d && d >= todayStart;
    }).length;
    const ordersYesterday = cache.orders.filter((o) => {
      const d = tsToDate(o.createdAt);
      return d && d >= yestStart && d < todayStart;
    }).length;
    const ridesToday = (cache.trips || []).filter((t) => {
      const d = tsToDate(t.createdAt);
      return d && d >= todayStart;
    }).length;
    const ridesYesterday = (cache.trips || []).filter((t) => {
      const d = tsToDate(t.createdAt);
      return d && d >= yestStart && d < todayStart;
    }).length;

    const delivered = cache.orders.filter((o) => String(o.status || "").toLowerCase() === "delivered");
    const deliveredRevenue = delivered.reduce((s, o) => s + (Number(o.total) || 0), 0);

    // Best-effort estimate from what's already loaded (recent-200 orders,
    // recent-200 trips) — not a ledger total. Order side sums the platform
    // commission snapshot on each delivered order this month; ride side
    // multiplies completed-this-month rides by the flat per-ride commission
    // rate, since trips don't carry a per-trip commission snapshot.
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const orderFeesMonth = delivered
      .filter((o) => {
        const d = tsToDate(o.createdAt);
        return d && d >= monthStart;
      })
      .reduce((s, o) => s + (Number(o.orderCommissionLkr) || 0), 0);
    const completedTripsMonth = (cache.trips || []).filter((t) => {
      const d = tsToDate(t.createdAt);
      return String(t.status || "").toLowerCase() === "completed" && d && d >= monthStart;
    }).length;
    const rideRate = Number((cache.platformFees || {}).rideCommissionLkr) || 0;
    const platformFeesMonth = orderFeesMonth + completedTripsMonth * rideRate;

    const approvedRiders = (cache.riders || []).filter((r) => riderIsApproved(r));
    const onlineRiders = (cache.riders || []).filter((r) => riderIsOnline(r));
    const fleetPct = approvedRiders.length ? Math.round((onlineRiders.length / approvedRiders.length) * 100) : 0;

    const cancelled = cache.orders.filter((o) => String(o.status || "").toLowerCase() === "cancelled").length;
    const cancelRate = cache.orders.length ? Math.round((cancelled / cache.orders.length) * 1000) / 10 : 0;
    const CANCEL_TARGET = 5;

    setText("stat-orders-today", ordersToday);
    setDelta("stat-orders-today-delta", ordersToday - ordersYesterday, "vs yesterday");
    setText("stat-rides-today", ridesToday);
    setDelta("stat-rides-today-delta", ridesToday - ridesYesterday, "vs yesterday");
    setText("stat-delivered-revenue", fmtMoney(deliveredRevenue));
    setText("stat-platform-fees-month", fmtMoney(platformFeesMonth));
    setText("stat-riders-online-frac", `${onlineRiders.length} / ${approvedRiders.length}`);
    setText("stat-riders-online-pct", `${fleetPct}% of fleet`);
    setText("stat-cancel-rate", `${cancelRate}%`);
    const hint = document.getElementById("stat-cancel-rate-hint");
    if (hint) {
      if (cancelRate > CANCEL_TARGET) {
        hint.textContent = `above ${CANCEL_TARGET}% target`;
        hint.className = "stat-card__delta is-warn";
      } else {
        hint.textContent = `within ${CANCEL_TARGET}% target`;
        hint.className = "stat-card__delta is-ok";
      }
    }
  }

  // ---------------------------------------------------------------------
  // Orders vs rides chart
  // ---------------------------------------------------------------------
  function bucketByDay(items, days, dateField) {
    const now = new Date();
    const daysArr = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      d.setHours(0, 0, 0, 0);
      daysArr.push(d);
    }
    const counts = daysArr.map(() => 0);
    items.forEach((it) => {
      const d = tsToDate(it[dateField]);
      if (!d) return;
      for (let i = 0; i < daysArr.length; i++) {
        const dayEnd = new Date(daysArr[i]);
        dayEnd.setDate(dayEnd.getDate() + 1);
        if (d >= daysArr[i] && d < dayEnd) {
          counts[i]++;
          break;
        }
      }
    });
    return daysArr.map((d, i) => ({
      label: d.toLocaleDateString(undefined, { month: "short", day: "numeric" }),
      value: counts[i],
    }));
  }

  // Same day-bucketing as bucketByDay() above, but sums a value per item
  // instead of counting items — used for the income/outgoings chart.
  function bucketByDaySum(items, days, dateField, valueFn) {
    const now = new Date();
    const daysArr = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      d.setHours(0, 0, 0, 0);
      daysArr.push(d);
    }
    const sums = daysArr.map(() => 0);
    items.forEach((it) => {
      const d = tsToDate(it[dateField]);
      if (!d) return;
      for (let i = 0; i < daysArr.length; i++) {
        const dayEnd = new Date(daysArr[i]);
        dayEnd.setDate(dayEnd.getDate() + 1);
        if (d >= daysArr[i] && d < dayEnd) {
          sums[i] += Number(valueFn(it)) || 0;
          break;
        }
      }
    });
    return daysArr.map((d, i) => ({
      label: d.toLocaleDateString(undefined, { month: "short", day: "numeric" }),
      value: sums[i],
    }));
  }

  // NOTE: cache.orders/cache.trips are recent-200 snapshots, so on a
  // high-volume store the 30-day view can undercount early days once the
  // 200-cap pushes them out of cache — same caveat as the old single-series
  // trend chart, acceptable for an at-a-glance widget.
  function renderDashboardOrdersVsRidesChart() {
    const el = document.getElementById("dashboard-orders-rides-chart");
    if (!el || !window.MndCharts) return;
    const days = dashboardChartRangeDays;
    const label = document.getElementById("dashboard-chart-range-label");
    if (label) label.textContent = String(days);
    const orderPoints = bucketByDay(cache.orders, days, "createdAt");
    const ridePoints = bucketByDay(cache.trips || [], days, "createdAt");
    window.MndCharts.renderMultiLineChart(
      el,
      [
        { name: "Orders", color: "var(--brand)", points: orderPoints },
        { name: "Rides", color: "var(--accent)", dashed: true, points: ridePoints },
      ],
      {
        id: "dashboard-orders-rides",
        title: `Orders vs rides — last ${days} days`,
        desc: "Count of orders and rides created each day, from the most recently loaded records.",
        xLabel: "Date",
        yLabel: "Count",
        height: 130,
      }
    );
    document.querySelectorAll("#dashboard-chart-range button").forEach((btn) => {
      btn.classList.toggle("active", Number(btn.getAttribute("data-range")) === days);
    });
  }

  // Income: platform commission snapshot on each order (set at order
  // create/edit) + a flat per-ride commission rate for completed rides,
  // since trips don't carry a per-trip commission snapshot — same
  // approximation the "Platform fees" stat tile already uses. Outgoings:
  // rider withdrawal + vendor payout amounts requested that day (cache.
  // withdrawals/vendorPayouts only hold pending/approved rows, not a full
  // paid-out ledger, so this reads as "money queued to go out" per day
  // rather than a strict cash-flow statement).
  function renderDashboardIncomeVsOutgoings() {
    const el = document.getElementById("dashboard-income-outgoings-chart");
    if (!el || !window.MndCharts) return;
    const days = dashboardChartRangeDays;
    const label = document.getElementById("dashboard-money-range-label");
    if (label) label.textContent = String(days);

    const rideRate = Number((cache.platformFees || {}).rideCommissionLkr) || 0;
    const orderIncome = bucketByDaySum(cache.orders, days, "createdAt", (o) => Number(o.orderCommissionLkr) || 0);
    const completedTrips = (cache.trips || []).filter((t) => String(t.status || "").toLowerCase() === "completed");
    const rideIncome = bucketByDaySum(completedTrips, days, "createdAt", () => rideRate);
    const incomePoints = orderIncome.map((p, i) => ({ label: p.label, value: p.value + rideIncome[i].value }));

    const withdrawalOut = bucketByDaySum(cache.withdrawals || [], days, "createdAt", (w) => Number(w.amountLkr) || 0);
    const payoutOut = bucketByDaySum(cache.vendorPayouts || [], days, "createdAt", (p) => Number(p.amountLkr) || 0);
    const outgoingPoints = withdrawalOut.map((p, i) => ({ label: p.label, value: p.value + payoutOut[i].value }));

    window.MndCharts.renderMultiLineChart(
      el,
      [
        { name: "Income", color: "var(--success)", points: incomePoints },
        { name: "Outgoings", color: "var(--danger)", dashed: true, points: outgoingPoints },
      ],
      {
        id: "dashboard-income-outgoings",
        title: `Income vs outgoings — last ${days} days`,
        desc: "Platform commission earned vs rider/vendor payout amounts requested, by day.",
        xLabel: "Date",
        yLabel: "LKR",
        height: 130,
        valueFormatter: (v) => fmtMoney(v),
      }
    );
  }

  document.getElementById("dashboard-chart-range")?.addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-range]");
    if (!btn) return;
    dashboardChartRangeDays = Number(btn.getAttribute("data-range")) || 7;
    renderDashboardOrdersVsRidesChart();
    renderDashboardIncomeVsOutgoings();
  });

  // ---------------------------------------------------------------------
  // Live now — ongoing rides + riders online
  // ---------------------------------------------------------------------
  function renderDashboardOngoingRides(ongoingRides) {
    const list = document.getElementById("dashboard-ongoing-rides-list");
    if (!list) return;
    const rows = ongoingRides.slice(0, 6);
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

  function renderDashboardRidersOnline() {
    const el = document.getElementById("dashboard-riders-online-list");
    if (!el) return;
    const online = (cache.riders || []).filter((r) => riderIsOnline(r)).slice(0, 14);
    el.innerHTML =
      online.length === 0
        ? '<div class="empty-state u-text-sm">No riders online right now.</div>'
        : online
            .map(
              (r) =>
                `<span class="live-rider-chip"><span class="live-rider-chip__dot"></span>${escapeHtml(riderDisplayName(r))}</span>`
            )
            .join("");
  }

  // ---------------------------------------------------------------------
  // Orders needing eyes
  // ---------------------------------------------------------------------
  function orderNeedsEyesAction(o) {
    const st = String(o.status || "").toLowerCase();
    if (st === "ready" && !o.riderId) return { label: "Assign", run: () => openAssignRiderModal(o.id) };
    if (orderMissedByShop(o)) return { label: "Call shop", run: () => openOrderDetails(o.id) };
    return { label: "Open", run: () => openOrderDetails(o.id) };
  }

  function renderDashboardOrdersNeedingEyes() {
    const tbody = document.querySelector("#table-dashboard-orders tbody");
    const moreEl = document.getElementById("dashboard-orders-eyes-more");
    if (!tbody) return;
    const readyFirst = [...cache.orders]
      .filter((o) => {
        const s = String(o.status || "").toLowerCase();
        return s !== "delivered" && s !== "cancelled";
      })
      .sort((a, b) => {
        const ar = String(a.status || "").toLowerCase() === "ready" ? 0 : 1;
        const br = String(b.status || "").toLowerCase() === "ready" ? 0 : 1;
        if (ar !== br) return ar - br;
        const ta = a.createdAt?.seconds || 0;
        const tb = b.createdAt?.seconds || 0;
        return tb - ta;
      });
    const VISIBLE = 6;
    const list = readyFirst.slice(0, VISIBLE);
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="6"><div class="empty-state"><div class="empty-state__icon">📦</div>Nothing needs eyes right now.</div></td></tr>`
        : list
            .map((o) => {
              const stRaw = String(o.status || "placed");
              const stLower = stRaw.toLowerCase();
              const readyAttention = stLower === "ready" ? " badge-ready-attention" : "";
              const orderLabel = orderDisplayNumber(o);
              const created = tsToDate(o.createdAt);
              const age = created ? agoLabel(created) : "—";
              const noRider =
                stLower === "ready" && !o.riderId ? ` <span class="badge badge-cancelled">no rider</span>` : "";
              const action = orderNeedsEyesAction(o);
              return `<tr>
          <td data-label="Tracking"><strong>${escapeHtml(orderLabel)}</strong></td>
          <td data-label="Store">${escapeHtml(shopDisplayName(o))}</td>
          <td data-label="Total">${fmtMoney(o.total)}</td>
          <td data-label="Status"><span class="badge ${badgeClass(stRaw)}${readyAttention}">${escapeHtml(statusLabel(stRaw))}</span>${missedByShopBadge(o)}${noRider}</td>
          <td data-label="Age">${escapeHtml(age)}</td>
          <td class="row-actions" data-label="Action"><button type="button" class="btn btn-ghost btn-sm u-w-auto" data-eyes-action="${escapeHtml(o.id)}">${escapeHtml(action.label)}</button></td>
        </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-eyes-action]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const id = btn.getAttribute("data-eyes-action");
        const order = cache.orders.find((o) => o.id === id);
        if (order) orderNeedsEyesAction(order).run();
      });
    });
    if (moreEl) {
      const remaining = readyFirst.length - list.length;
      moreEl.textContent = remaining > 0 ? `… ${remaining} more rows` : "";
    }
  }

  // ---------------------------------------------------------------------
  // Money queue
  // ---------------------------------------------------------------------
  function renderDashboardMoneyQueue() {
    const el = document.getElementById("dashboard-money-queue");
    if (!el) return;
    const withdrawals = cache.withdrawals || [];
    const withdrawalsSum = withdrawals.reduce((s, w) => s + (Number(w.amountLkr) || 0), 0);
    const payouts = cache.vendorPayouts || [];
    const payoutsSum = payouts.reduce((s, p) => s + (Number(p.amountLkr) || 0), 0);
    const cashRiders = cache.cashRiders || [];
    const cashSum = cashRiders.reduce((s, r) => s + riderCashInHand(r), 0);
    const custUnread = countUnreadSupportThreads();
    const vendUnread = countUnreadVendorSupportThreads();

    const unreadThreads = [
      ...(cache.supportThreads || []).filter((t) => Number(t.unreadByStaff || 0) > 0),
      ...(cache.vendorSupportThreads || []).filter((t) => Number(t.unreadByStaff || 0) > 0),
    ];
    let oldest = "—";
    const oldestDate = unreadThreads
      .map((t) => tsToDate(t.lastMessageAt))
      .filter(Boolean)
      .sort((a, b) => a - b)[0];
    if (oldestDate) oldest = agoLabel(oldestDate);

    let invoiceRow = "";
    if ((cache.monthlyInvoices || []).length) {
      const unpaid = cache.monthlyInvoices.filter((i) => String(i.status || "").toLowerCase() !== "paid").length;
      if (unpaid > 0) {
        invoiceRow = `<div class="kv-row" data-go-nav="platform-fees"><span class="kv-row__label">Monthly invoices unpaid</span><span class="kv-row__value">${unpaid}</span></div>`;
      }
    }

    el.innerHTML = `
      <div class="kv-row" data-go-nav="withdrawals"><span class="kv-row__label">Rider withdrawals</span><span class="kv-row__value">${withdrawals.length} · ${fmtMoney(withdrawalsSum)}</span></div>
      <div class="kv-row" data-go-nav="vendor-payouts"><span class="kv-row__label">Vendor payouts</span><span class="kv-row__value">${payouts.length} · ${fmtMoney(payoutsSum)}</span></div>
      <div class="kv-row" data-go-nav="rider-cash"><span class="kv-row__label">Rider cash to collect</span><span class="kv-row__value">${cashRiders.length} riders · ${fmtMoney(cashSum)}</span></div>
      ${invoiceRow}
      <p class="kv-section-title">Support inbox</p>
      <div class="kv-row" data-go-nav="support"><span class="kv-row__label">Customer threads unread</span><span class="kv-row__value">${custUnread}</span></div>
      <div class="kv-row" data-go-nav="vendor-support"><span class="kv-row__label">Vendor threads unread</span><span class="kv-row__value">${vendUnread}</span></div>
      <div class="kv-row"><span class="kv-row__label">Oldest waiting</span><span class="kv-row__value">${escapeHtml(oldest)}</span></div>
    `;
    bindGoNav(el);
  }

  // ---------------------------------------------------------------------
  // Top shops this week
  // ---------------------------------------------------------------------
  // Aggregates the already-loaded cache.orders (recent-200 snapshot) —
  // same undercount caveat as the trend chart on a high-volume store.
  function renderDashboardTopShops() {
    const el = document.getElementById("dashboard-top-shops");
    if (!el) return;
    const now = new Date();
    const weekStart = new Date(now);
    weekStart.setDate(now.getDate() - now.getDay());
    weekStart.setHours(0, 0, 0, 0);
    const byShop = new Map();
    cache.orders.forEach((o) => {
      const d = tsToDate(o.createdAt);
      if (!d || d < weekStart) return;
      const key = compactText(o.vendorStoreId, o.vendorId, shopDisplayName(o));
      const entry = byShop.get(key) || { name: shopDisplayName(o), count: 0, total: 0 };
      entry.count++;
      entry.total += Number(o.total) || 0;
      byShop.set(key, entry);
    });
    const top = Array.from(byShop.values())
      .sort((a, b) => b.total - a.total)
      .slice(0, 5);
    el.innerHTML =
      top.length === 0
        ? '<div class="empty-state u-text-sm">No orders yet this week.</div>'
        : top
            .map(
              (s, i) =>
                `<div class="kv-row"><span class="kv-row__label">${i + 1}. ${escapeHtml(s.name)}</span><span class="kv-row__value">${s.count} orders · ${fmtMoney(s.total)}</span></div>`
            )
            .join("");
  }

  // ---------------------------------------------------------------------
  // Low ratings & reports
  // ---------------------------------------------------------------------
  function renderDashboardLowRatingsReports() {
    const el = document.getElementById("dashboard-low-ratings");
    if (!el) return;
    const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    const lowShops = new Set();
    (cache.ratings || []).forEach((r) => {
      const d = tsToDate(r.createdAt);
      if (!d || d.getTime() < weekAgo) return;
      if (Number(r.stars) < 3) lowShops.add(r.vendorId || r.storeName || r.id);
    });
    const jobReportsOpen = (cache.jobReports || []).length;
    el.innerHTML = `
      <div class="kv-row" data-go-nav="ratings"><span class="kv-row__label">Shops rated &lt; 3★ (7d)</span><span class="kv-row__value">${lowShops.size}</span></div>
      <div class="kv-row" data-go-nav="jobs"><span class="kv-row__label">Job reports open</span><span class="kv-row__value">${jobReportsOpen}</span></div>
    `;
    bindGoNav(el);
  }

  // ---------------------------------------------------------------------
  // Catalog & growth
  // ---------------------------------------------------------------------
  function renderDashboardCatalogGrowth() {
    const el = document.getElementById("dashboard-catalog-growth");
    if (!el) return;
    const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    const newCustomers = (cache.customers || []).filter((c) => {
      const d = tsToDate(c.createdAt);
      return d && d.getTime() >= weekAgo;
    }).length;
    const activeShops = (cache.vendors || []).filter((v) => v.active === true).length;
    const totalShops = (cache.vendors || []).length;
    const soonMs = Date.now() + 3 * 24 * 60 * 60 * 1000;
    const nowMs = Date.now();
    const expiringOffers = (cache.offers || []).filter((o) => {
      const d = tsToDate(o.endsAt);
      return d && d.getTime() >= nowMs && d.getTime() <= soonMs;
    }).length;
    const expiringCoupons = (cache.couponsExpiringSoon || []).filter((c) => {
      const d = tsToDate(c.expiresAt);
      return d && d.getTime() >= nowMs && d.getTime() <= soonMs;
    }).length;
    el.innerHTML = `
      <div class="kv-row" data-go-nav="customers"><span class="kv-row__label">New customers (7d)</span><span class="kv-row__value">${newCustomers}</span></div>
      <div class="kv-row" data-go-nav="vendors"><span class="kv-row__label">Active shops / total</span><span class="kv-row__value">${activeShops} / ${totalShops}</span></div>
      <div class="kv-row" data-go-nav="offers"><span class="kv-row__label">Coupons / offers expiring</span><span class="kv-row__value">${expiringCoupons + expiringOffers} in 3 days</span></div>
    `;
    bindGoNav(el);
  }

  // ---------------------------------------------------------------------
  // Global search (order / rider / shop)
  // ---------------------------------------------------------------------
  function handleDashboardSearch(raw) {
    const q = String(raw || "").trim();
    if (!q) return;
    const qLower = q.toLowerCase();

    const order = cache.orders.find(
      (o) => String(o.id).toLowerCase() === qLower || orderDisplayNumber(o).toLowerCase().includes(qLower)
    );
    if (order) {
      window.MndRouter.navigate("orders");
      openOrderDetails(order.id);
      return;
    }

    const rider = (cache.riders || []).find(
      (r) =>
        String(r.id).toLowerCase() === qLower ||
        riderDisplayName(r).toLowerCase().includes(qLower) ||
        String(r.phone || r.phoneNumber || "").includes(q)
    );
    if (rider) {
      window.MndRouter.navigate("riders");
      openRiderDetailView(rider.id);
      return;
    }

    const vendor = (cache.vendors || []).find(
      (v) => String(v.id).toLowerCase() === qLower || String(v.name || "").toLowerCase().includes(qLower)
    );
    if (vendor) {
      window.MndRouter.navigate("vendors");
      openVendorModal(vendor.id);
      return;
    }

    toast(`No order, rider, or shop matched "${q}".`, "error");
  }

  document.getElementById("dashboard-search")?.addEventListener("keydown", (e) => {
    if (e.key !== "Enter") return;
    e.preventDefault();
    handleDashboardSearch(e.target.value);
  });

  // Static [data-go-nav] buttons that live in the dashboard's markup from
  // page load (e.g. "All orders", "View all") and are never re-rendered —
  // bind them once here. Dynamically-rendered sections (needs-action,
  // money queue, top shops, ...) get their own bindGoNav() call after each
  // innerHTML swap instead, so their buttons aren't double-bound.
  bindGoNav(document.querySelector('section[data-view="dashboard"]'));

  window.renderDashboard = renderDashboard;
  window.renderDashboardOngoingRides = renderDashboardOngoingRides;
  // Kept under its old name — app.js still calls this after vendor/job
  // approve/reject actions regardless of which view is currently active.
  window.updateDashboardQuickActions = renderDashboardNeedsAction;
  window.renderDashboardRecentOrders = renderDashboardOrdersNeedingEyes;
})();
