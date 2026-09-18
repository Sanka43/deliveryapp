/**
 * MND Admin — Cash Flow view (platform-wide money movement overview).
 *
 * Depends on globals exposed by app.js: db, COL, cache, fmtMoney,
 * escapeHtml, toast — also window.MndCharts.
 *
 * Reads platform_daily_cashflow/{dateKey}, a server-maintained daily
 * aggregate of REALIZED (settled) money events — order commission/IPG fee
 * earned, refunds paid, COD cash settled to shops, ride commission,
 * rider/vendor payouts paid, monthly vendor invoices paid — written by
 * functions/src/platformCashFlow.ts (live, going forward) and seeded for
 * history by the one-time backfillPlatformCashFlow callable. See
 * platformCashFlowLogic.ts for exactly what's counted and what isn't yet
 * (orderRiderCommissionLkr is deliberately excluded — see that file).
 *
 * "Pending" balances (not yet settled) are a separate, lighter one-shot
 * read on view-open — they're what the dedicated Withdrawals / Vendor
 * payouts / Shop cash / Rider cash pages already manage in full; this tab
 * only needs their current totals, not live per-row detail.
 */
(function () {
  let cashFlowUnsub = null;
  let cashFlowDailyDocs = []; // [{id: "YYYY-MM-DD", income, outgoing, discountCost}]
  let cashFlowRangeDays = 30;
  let cashFlowPending = null;

  // Same pattern as dashboard.js's private goNav/bindGoNav — not shared on
  // window, so each view that uses data-go-nav wires it locally.
  function goNav(el) {
    window.MndRouter.navigate(el.getAttribute("data-go-nav"));
  }

  function bindGoNav(container) {
    if (!container) return;
    container.querySelectorAll("[data-go-nav]").forEach((el) => {
      el.addEventListener("click", () => goNav(el));
    });
  }

  function stopCashFlowListeners() {
    if (cashFlowUnsub) {
      try {
        cashFlowUnsub();
      } catch (_) {}
      cashFlowUnsub = null;
    }
  }

  async function startCashFlowListeners() {
    stopCashFlowListeners();
    await new Promise((resolve) => {
      let settled = false;
      const unsub = db
        .collection("platform_daily_cashflow")
        .orderBy("date", "desc")
        .limit(120)
        .onSnapshot(
          (snap) => {
            cashFlowDailyDocs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
            renderCashFlow();
            if (!settled) {
              settled = true;
              resolve();
            }
          },
          (e) => {
            toast(e.message || String(e), "error");
            if (!settled) {
              settled = true;
              resolve();
            }
          }
        );
      cashFlowUnsub = unsub;
    });
    await loadCashFlowPending();
  }

  async function loadCashFlowPending() {
    try {
      const [withdrawalsSnap, payoutsSnap, codSnap] = await Promise.all([
        db.collectionGroup("withdrawals").where("status", "in", ["pending", "approved"]).get(),
        db.collectionGroup("payouts").where("status", "==", "pending").get(),
        db
          .collection(COL.orders)
          .where("productCashStatus", "in", ["owed", "remittance_requested", "remitted_to_admin"])
          .get(),
      ]);
      const sum = (snap, field) => snap.docs.reduce((s, d) => s + (Number(d.data()[field]) || 0), 0);
      const riderCashInHandLkr = (cache.riders || []).reduce(
        (s, r) => s + (Number(r.cashInHandLkr) || 0),
        0
      );
      cashFlowPending = {
        withdrawalsLkr: sum(withdrawalsSnap, "amountLkr"),
        payoutsLkr: sum(payoutsSnap, "amountLkr"),
        codOwedLkr: sum(codSnap, "productCashLkr"),
        riderCashInHandLkr,
      };
    } catch (e) {
      console.error(e);
      cashFlowPending = null;
    }
    renderCashFlowPending();
  }

  // One label per calendar day in range, even if that day has no doc (no
  // cash-flow events) — keeps the chart's x-axis evenly spaced instead of
  // silently skipping quiet days.
  function buildDayRange(days) {
    const now = new Date();
    const keys = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - i));
      keys.push(d.toISOString().slice(0, 10));
    }
    return keys;
  }

  function docFor(dateKey) {
    return cashFlowDailyDocs.find((d) => d.id === dateKey) || null;
  }

  function sumFields(obj) {
    return Object.values(obj || {}).reduce((s, v) => s + (Number(v) || 0), 0);
  }

  function periodTotals(days) {
    const keys = buildDayRange(days);
    const totals = { incomeLkr: 0, outgoingLkr: 0, discountLkr: 0, byField: {} };
    for (const key of keys) {
      const doc = docFor(key);
      if (!doc) continue;
      for (const [k, v] of Object.entries(doc.income || {})) {
        totals.incomeLkr += Number(v) || 0;
        totals.byField[k] = (totals.byField[k] || 0) + (Number(v) || 0);
      }
      for (const [k, v] of Object.entries(doc.outgoing || {})) {
        totals.outgoingLkr += Number(v) || 0;
        totals.byField[k] = (totals.byField[k] || 0) + (Number(v) || 0);
      }
      for (const [k, v] of Object.entries(doc.discountCost || {})) {
        totals.discountLkr += Number(v) || 0;
        totals.byField[k] = (totals.byField[k] || 0) + (Number(v) || 0);
      }
    }
    return totals;
  }

  function setText(id, val) {
    const el = document.getElementById(id);
    if (el) el.textContent = val;
  }

  function renderCashFlowStats() {
    const totals = periodTotals(cashFlowRangeDays);
    setText("cashflow-income", fmtMoney(totals.incomeLkr));
    setText("cashflow-outgoing", fmtMoney(totals.outgoingLkr));
    setText("cashflow-discount", fmtMoney(totals.discountLkr));
    setText("cashflow-net", fmtMoney(totals.incomeLkr - totals.outgoingLkr - totals.discountLkr));
  }

  function renderCashFlowPending() {
    if (!cashFlowPending) return;
    setText("cashflow-pending-withdrawals", fmtMoney(cashFlowPending.withdrawalsLkr));
    setText("cashflow-pending-payouts", fmtMoney(cashFlowPending.payoutsLkr));
    setText("cashflow-pending-cod", fmtMoney(cashFlowPending.codOwedLkr));
    setText("cashflow-pending-ridercash", fmtMoney(cashFlowPending.riderCashInHandLkr));
  }

  function renderCashFlowChart() {
    const el = document.getElementById("cashflow-chart");
    if (!el || !window.MndCharts) return;
    const keys = buildDayRange(cashFlowRangeDays);
    const dayLabel = (key) => {
      const d = new Date(key + "T00:00:00Z");
      return d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
    };
    const incomePoints = keys.map((key) => ({
      label: dayLabel(key),
      value: sumFields((docFor(key) || {}).income),
    }));
    const outgoingPoints = keys.map((key) => ({
      label: dayLabel(key),
      value: sumFields((docFor(key) || {}).outgoing),
    }));
    const discountPoints = keys.map((key) => ({
      label: dayLabel(key),
      value: sumFields((docFor(key) || {}).discountCost),
    }));
    window.MndCharts.renderMultiLineChart(
      el,
      [
        { name: "Income", color: "var(--success)", points: incomePoints },
        { name: "Outgoing (paid)", color: "var(--danger)", points: outgoingPoints },
        { name: "Discount cost", color: "var(--accent)", points: discountPoints },
      ],
      {
        id: "cashflow-chart",
        title: `Cash flow — last ${cashFlowRangeDays} days`,
        desc: "Platform income, money paid out, and discount cost, by day.",
        xLabel: "Date",
        yLabel: "LKR",
        height: 96,
        valueFormatter: (v) => fmtMoney(v),
      }
    );
  }

  function breakdownRow(label, amount, navTarget) {
    return `<tr>
      <td data-label="Category">${escapeHtml(label)}</td>
      <td data-label="This period"><strong>${escapeHtml(fmtMoney(amount))}</strong></td>
      <td class="row-actions" data-label="Actions">${
        navTarget ? `<button type="button" class="btn btn-ghost btn-sm" data-go-nav="${navTarget}">Open</button>` : "—"
      }</td>
    </tr>`;
  }

  function renderCashFlowBreakdown() {
    const tbody = document.querySelector("#table-cashflow-breakdown tbody");
    if (!tbody) return;
    const f = periodTotals(cashFlowRangeDays).byField;
    tbody.innerHTML = [
      breakdownRow("Order commission", f["income.orderCommissionLkr"] || 0, "orders"),
      breakdownRow("IPG gateway fee recovered", f["income.ipgFeeLkr"] || 0, "platform-fees"),
      breakdownRow("Ride commission", f["income.rideCommissionLkr"] || 0, "ride-fares"),
      breakdownRow("Monthly vendor invoices paid", f["income.monthlyInvoiceLkr"] || 0, "platform-fees"),
      breakdownRow("Rider withdrawals paid", f["outgoing.riderWithdrawalsPaidLkr"] || 0, "withdrawals"),
      breakdownRow("Vendor payouts paid", f["outgoing.vendorPayoutsPaidLkr"] || 0, "vendor-payouts"),
      breakdownRow("COD cash settled to shops", f["outgoing.codSettledToShopLkr"] || 0, "shop-cash"),
      breakdownRow("Refunds paid", f["outgoing.refundsPaidLkr"] || 0, "refunds"),
      breakdownRow("Coupon discount cost", f["discountCost.couponsLkr"] || 0, "coupons"),
      breakdownRow("Referral reward cost", f["discountCost.referralsLkr"] || 0, "coupons"),
    ].join("");
    bindGoNav(tbody);
  }

  function renderCashFlow() {
    renderCashFlowStats();
    renderCashFlowChart();
    renderCashFlowBreakdown();
    renderCashFlowPending();
  }

  function setCashFlowRange(days) {
    cashFlowRangeDays = days;
    document.querySelectorAll("#cashflow-range button[data-range]").forEach((btn) => {
      btn.classList.toggle("active", Number(btn.getAttribute("data-range")) === days);
    });
    renderCashFlow();
  }

  document.addEventListener("DOMContentLoaded", () => {
    const rangeEl = document.getElementById("cashflow-range");
    if (rangeEl) {
      rangeEl.querySelectorAll("button[data-range]").forEach((btn) => {
        btn.addEventListener("click", () => setCashFlowRange(Number(btn.getAttribute("data-range"))));
      });
    }
    const refreshBtn = document.getElementById("btn-cashflow-refresh-pending");
    if (refreshBtn) refreshBtn.addEventListener("click", () => loadCashFlowPending());
  });

  window.startCashFlowListeners = startCashFlowListeners;
  window.stopCashFlowListeners = stopCashFlowListeners;
  window.renderCashFlow = renderCashFlow;
})();
