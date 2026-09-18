/**
 * MND Admin — PayHere Payments view (lightweight payment log).
 *
 * Depends on globals exposed by app.js: db, COL, cache, fmtMoney, fmtTs,
 * escapeHtml, toast.
 *
 * Deliberately NOT backed by a new persisted webhook-event collection —
 * paymentWebhook.ts (live payment processing) is not touched. This is a
 * read-only derived view over the same paymentStatus/paymentProvider/
 * paymentTransactionId fields already written on orders/trips, fetched
 * one-shot on view-open (not a live listener) since it's a log, not a
 * dashboard.
 */
(function () {
  let payHereRows = [];
  let payHereLoaded = false;

  // Opens the same order/trip detail modal the Orders/Rides tabs use
  // (openOrderDetails/openTripDetails only look at cache.orders/cache.trips
  // — a PayHere order may not be in either cache yet, e.g. it's older than
  // the dashboard's recent-200 listener window, so fetch it fresh and
  // upsert it into the cache first rather than risk a silent no-op).
  async function openDetails(row) {
    try {
      const isOrder = row.type === "Order";
      const colName = isOrder ? COL.orders : COL.trips;
      const snap = await db.collection(colName).doc(row.id).get();
      if (!snap.exists) {
        toast("Not found — it may have been deleted.", "error");
        return;
      }
      const doc = { id: snap.id, ...snap.data() };
      const list = isOrder ? cache.orders : cache.trips;
      const idx = list.findIndex((x) => x.id === doc.id);
      if (idx >= 0) list[idx] = doc;
      else list.unshift(doc);
      if (isOrder && window.openOrderDetails) window.openOrderDetails(doc.id);
      else if (!isOrder && window.openTripDetails) window.openTripDetails(doc.id);
    } catch (e) {
      console.error(e);
      toast(e.message || String(e), "error");
    }
  }

  function bindOpenButtons(container) {
    if (!container) return;
    container.querySelectorAll("[data-open-detail]").forEach((el) => {
      el.addEventListener("click", () => {
        openDetails({
          id: el.getAttribute("data-open-detail"),
          type: el.getAttribute("data-open-type"),
        });
      });
    });
  }

  function tsMs(val) {
    try {
      if (val && typeof val.toDate === "function") return val.toDate().getTime();
      if (val && val.seconds != null) return val.seconds * 1000;
    } catch (_) {}
    return 0;
  }

  function paymentBadgeClass(status) {
    const s = String(status || "").toLowerCase();
    if (s === "paid") return "badge-delivered";
    if (s === "failed" || s === "refunded") return "badge-cancelled";
    return "badge-pending";
  }

  function rowFromOrder(id, o) {
    return {
      type: "Order",
      id,
      amountLkr: Number(o.total) || 0,
      status: String(o.paymentStatus || "").trim().toLowerCase(),
      transactionId: String(o.paymentTransactionId || "").trim(),
      updatedAtMs: tsMs(o.paymentUpdatedAt || o.paidAt || o.refundedAt || o.createdAt),
      updatedAtRaw: o.paymentUpdatedAt || o.paidAt || o.refundedAt || o.createdAt,
    };
  }

  function rowFromTrip(id, t) {
    return {
      type: "Trip",
      id,
      amountLkr: Number(t.estimatedFareLkr) || 0,
      status: String(t.paymentStatus || "").trim().toLowerCase(),
      transactionId: String(t.paymentTransactionId || "").trim(),
      updatedAtMs: tsMs(t.paymentUpdatedAt || t.createdAt),
      updatedAtRaw: t.paymentUpdatedAt || t.createdAt,
    };
  }

  async function loadPayHereLog() {
    try {
      const [ordersSnap, tripsSnap] = await Promise.all([
        db.collection(COL.orders).where("paymentProvider", "==", "payhere").limit(300).get(),
        db.collection(COL.trips).where("paymentProvider", "==", "payhere").limit(300).get(),
      ]);
      const orderRows = ordersSnap.docs.map((d) => rowFromOrder(d.id, d.data()));
      const tripRows = tripsSnap.docs.map((d) => rowFromTrip(d.id, d.data()));
      payHereRows = [...orderRows, ...tripRows]
        .sort((a, b) => b.updatedAtMs - a.updatedAtMs)
        .slice(0, 200);
    } catch (e) {
      console.error(e);
      toast(e.message || String(e), "error");
      payHereRows = [];
    }
    payHereLoaded = true;
    renderPayHereLog();
  }

  function matchesFilters(row, search, statusFilter) {
    if (statusFilter && row.status !== statusFilter) return false;
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      row.id.toLowerCase().includes(q) ||
      row.transactionId.toLowerCase().includes(q)
    );
  }

  function renderPayHereLog() {
    const tbody = document.querySelector("#table-payhere-log tbody");
    if (!tbody) return;
    const search = (document.getElementById("filter-payhere-log")?.value || "").trim();
    const statusFilter = document.getElementById("filter-payhere-log-status")?.value || "";
    const rows = payHereRows.filter((r) => matchesFilters(r, search, statusFilter));

    if (!payHereLoaded) {
      tbody.innerHTML = `<tr><td colspan="7">Loading…</td></tr>`;
      return;
    }
    if (rows.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7">No PayHere payments found.</td></tr>`;
      return;
    }

    tbody.innerHTML = rows
      .map(
        (r) => `<tr>
          <td data-label="Type">${escapeHtml(r.type)}</td>
          <td data-label="ID"><code>${escapeHtml(r.id)}</code></td>
          <td data-label="Amount">${escapeHtml(fmtMoney(r.amountLkr))}</td>
          <td data-label="Status"><span class="badge ${paymentBadgeClass(r.status)}">${escapeHtml(
            r.status || "—"
          )}</span></td>
          <td data-label="Transaction ID">${r.transactionId ? `<code>${escapeHtml(r.transactionId)}</code>` : "—"}</td>
          <td data-label="Updated">${escapeHtml(fmtTs(r.updatedAtRaw))}</td>
          <td class="row-actions" data-label="Actions">
            <button type="button" class="btn btn-ghost btn-sm" data-open-detail="${escapeHtml(r.id)}" data-open-type="${escapeHtml(r.type)}">Open</button>
          </td>
        </tr>`
      )
      .join("");
    bindOpenButtons(tbody);
  }

  document.addEventListener("DOMContentLoaded", () => {
    const searchEl = document.getElementById("filter-payhere-log");
    if (searchEl) searchEl.addEventListener("input", () => renderPayHereLog());
    const statusEl = document.getElementById("filter-payhere-log-status");
    if (statusEl) statusEl.addEventListener("change", () => renderPayHereLog());
    const refreshBtn = document.getElementById("btn-payhere-log-refresh");
    if (refreshBtn) refreshBtn.addEventListener("click", () => loadPayHereLog());
  });

  window.loadPayHereLog = loadPayHereLog;
})();
