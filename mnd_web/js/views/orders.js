/**
 * MND Admin — Orders view.
 *
 * Cut out of js/app.js verbatim (Phase 2 file-split). Owns its own
 * pagination state (ordersPager/ordersPageDocs — nothing outside this
 * file touched them even when they lived in app.js).
 *
 * Depends on globals exposed by app.js: db, COL, cache, FS_GET_SERVER,
 * escapeHtml, fmtMoney, fmtTs, fmtCoordPair, badgeClass, statusLabel,
 * missedByShopBadge, orderMissedByShop, isSelfPickupOrder,
 * resolveOrderStatusOptions, orderAddrLine, orderDisplayNumber,
 * orderItemRows, orderDetailLine, paymentMethodLabel, readLatLng,
 * haversineKm, getVendorDocForOrder, compactText, customerById,
 * customerDisplayName, shopDisplayName, riderDisplayName, riderIsOnline,
 * loadRiders, loadVendors, loadOrders, loadViewData, openModal,
 * modalSave, ORDER_STATUSES — all still owned/shared by app.js.
 * Also uses the already-global window.MndPagination.
 */
(function () {
  // Orders view: real cursor pagination (js/core/pagination.js), separate
  // from cache.orders (which stays a fixed recent-200 snapshot used for
  // Dashboard stats / Customers) — this is the paged data source the
  // Orders list actually renders from.
  let ordersPager = null;
  let ordersPageDocs = [];

  // Looks in both order sources: cache.orders (recent-200, used by
  // Dashboard/Customers) and ordersPageDocs (the Orders view's current
  // paginated page, which can reach older orders cache.orders doesn't
  // have) — so a click on any order actually visible in the Orders list
  // resolves, regardless of which page it came from.
  function findOrder(id) {
    return cache.orders.find((x) => x.id === id) || ordersPageDocs.find((x) => x.id === id) || null;
  }

  // Orders view's own paged data source (js/core/pagination.js) — replaces
  // the fixed .limit(200) with real forward/backward paging so an order
  // older than the most recent 200 is still reachable, not silently gone.
  // direction: "first" (fresh page 1, e.g. on view entry) | "next" | "prev".
  async function loadOrdersPage(direction) {
    if (!direction || direction === "first" || !ordersPager) {
      ordersPager = window.MndPagination.createPager({
        query: db.collection(COL.orders).orderBy("createdAt", "desc"),
        pageSize: 50,
        getOpts: FS_GET_SERVER,
      });
      ordersPageDocs = await ordersPager.first();
      return;
    }
    ordersPageDocs = direction === "prev" ? await ordersPager.prev() : await ordersPager.next();
  }

  // Filters/searches only within the currently loaded page of orders
  // (ordersPageDocs, ~50 rows) rather than the whole collection — Firestore
  // has no full-text search, so browsing further back means paging with
  // Next, same tradeoff loadOrdersPage's cursor pagination is built on.
  function renderOrders() {
    const q = (document.getElementById("filter-orders")?.value || "").toLowerCase();
    const st = document.getElementById("filter-order-status")?.value || "";
    let list = [...ordersPageDocs];
    if (st) list = list.filter((o) => String(o.status || "").toLowerCase() === st);
    if (q) {
      list = list.filter((o) => {
        const id = o.id.toLowerCase();
        const track = String(o.trackingNumber || "").toLowerCase().trim();
        const cust = customerDisplayName(o).toLowerCase();
        const store = shopDisplayName(o).toLowerCase();
        const addr = orderAddrLine(o).toLowerCase();
        return (
          id.includes(q) ||
          (track && track.includes(q)) ||
          cust.includes(q) ||
          store.includes(q) ||
          addr.includes(q)
        );
      });
    }
    const listEl = document.getElementById("orders-list");
    listEl.innerHTML =
      list.length === 0
        ? `<div class="empty-state">No orders${q || st ? " match this page's filter." : "."}</div>`
        : list
            .map((o) => {
              const stRaw = String(o.status || "placed");
              const stLower = String(stRaw || "").toLowerCase();
              const readyAttention = stLower === "ready" ? " badge-ready-attention" : "";
              const orderLabel = orderDisplayNumber(o);
              const customerName = customerDisplayName(o);
              const customer = customerById(o.customerId);
              const customerMeta = compactText(customer?.phoneNumber, customer?.phone, o.deliveryAddress?.phone);
              const shopName = shopDisplayName(o);
              const assignBtn =
                stLower === "ready" && !isSelfPickupOrder(o)
                  ? `<button type="button" class="btn btn-ghost btn-sm u-w-auto" data-assign-rider-order="${escapeHtml(o.id)}" aria-label="Assign rider for order ${escapeHtml(orderLabel)}">Assign rider</button>`
                  : "";
              return `<div class="data-card order-row" tabindex="0" data-view-order="${escapeHtml(o.id)}" aria-label="View details for order ${escapeHtml(orderLabel)}">
          <div class="data-card__header">
            <span class="data-card__title">${escapeHtml(orderLabel)}</span>
            <span class="badge ${badgeClass(stRaw)}${readyAttention}">${escapeHtml(statusLabel(stRaw))}</span>${missedByShopBadge(o)}
          </div>
          <div class="data-card__meta">${escapeHtml(customerName)}${customerMeta ? ` · ${escapeHtml(customerMeta)}` : ""}</div>
          <div class="data-card__meta">${escapeHtml(shopName)} · ${escapeHtml(orderAddrLine(o))}</div>
          <div class="data-card__meta">${fmtMoney(o.total)} · ${escapeHtml(fmtTs(o.createdAt))}</div>
          <div class="data-card__actions">
            ${assignBtn}
            <button type="button" class="btn btn-ghost btn-sm u-w-auto" data-edit-order="${escapeHtml(o.id)}" aria-label="Edit order ${escapeHtml(orderLabel)}">Edit</button>
            <button type="button" class="btn btn-ghost btn-sm u-w-auto" data-del-order="${escapeHtml(o.id)}" aria-label="Delete order ${escapeHtml(orderLabel)}">Delete</button>
          </div>
        </div>`;
            })
            .join("");
    listEl.querySelectorAll("[data-view-order]").forEach((row) => {
      const open = () => openOrderDetails(row.getAttribute("data-view-order"));
      row.addEventListener("click", (e) => {
        if (e.target.closest("button, a, input, select, textarea")) return;
        open();
      });
      row.addEventListener("keydown", (e) => {
        if (e.key !== "Enter" && e.key !== " ") return;
        if (e.target.closest("button, a, input, select, textarea")) return;
        e.preventDefault();
        open();
      });
    });
    listEl.querySelectorAll("[data-assign-rider-order]").forEach((btn) => {
      btn.addEventListener("click", () => {
        openAssignRiderModal(btn.getAttribute("data-assign-rider-order")).catch((e) => alert(e.message || String(e)));
      });
    });
    listEl.querySelectorAll("[data-edit-order]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        try {
          await openOrderEdit(btn.getAttribute("data-edit-order"));
        } catch (e) {
          alert(e.message || String(e));
        }
      });
    });
    listEl.querySelectorAll("[data-del-order]").forEach((btn) => {
      btn.addEventListener("click", () => deleteOrder(btn.getAttribute("data-del-order")));
    });
    renderOrdersPaginationControls();
  }

  function renderOrdersPaginationControls() {
    const prevBtn = document.getElementById("btn-orders-prev");
    const nextBtn = document.getElementById("btn-orders-next");
    const label = document.getElementById("orders-page-label");
    if (!ordersPager) return;
    if (prevBtn) prevBtn.disabled = !ordersPager.hasPrev();
    if (nextBtn) nextBtn.disabled = !ordersPager.hasNext();
    if (label) label.textContent = `Page ${ordersPager.pageNumber()}`;
  }

  function openOrderDetails(id) {
    const o = findOrder(id);
    if (!o) return;
    const customer = customerById(o.customerId);
    const rider = cache.riders.find((x) => x.id === compactText(o.riderId, o.assignedRiderId));
    const customerName = customerDisplayName(o);
    const customerPhone = compactText(customer?.phoneNumber, customer?.phone, o.deliveryAddress?.phone);
    const customerEmail = compactText(customer?.email);
    const shopName = shopDisplayName(o);
    const title = orderDisplayNumber(o);
    const fulfillment = isSelfPickupOrder(o) ? "Self pickup" : "Delivery";
    const note = compactText(o.deliveryNote, o.specialInstructions);
    const riderLabel = rider ? riderDisplayName(rider) : compactText(o.riderName, o.riderId ? "Assigned" : "Unassigned");
    const items = Array.isArray(o.items) ? o.items : [];
    const itemCount = items.reduce((sum, item) => sum + (Number(item.quantity) || 1), 0);
    const address = orderAddrLine(o);
    const html = `<div class="order-detail">
      <div class="order-detail-receipt">
        <div class="order-detail-head">
          <span class="order-detail-kicker">MND Delivery Bill</span>
          <h4>${escapeHtml(title)}</h4>
          <p>${escapeHtml(shopName)}</p>
        </div>

        <div class="order-detail-meta">
          ${orderDetailLine("Date", fmtTs(o.createdAt))}
          ${orderDetailLine("Customer", customerName)}
          ${orderDetailLine("Phone", customerPhone)}
          ${customerEmail ? orderDetailLine("Email", customerEmail) : ""}
          ${orderDetailLine("Order type", fulfillment)}
          ${orderDetailLine("Status", statusLabel(o.status || "placed"))}
          ${orderMissedByShop(o) ? orderDetailLine("Cancel reason", "Missed by shop (no confirm)") : ""}
          ${orderDetailLine("Rider", riderLabel)}
          ${orderDetailLine("Payment", paymentMethodLabel(o.paymentMethod))}
        </div>

        <div class="order-detail-status">
          <span>${escapeHtml(itemCount ? `${itemCount} item${itemCount === 1 ? "" : "s"}` : "Items not recorded")}</span>
          <span>${escapeHtml(fulfillment)}</span>
        </div>
        <span class="badge ${badgeClass(o.status)}">${escapeHtml(statusLabel(o.status || "placed"))}</span>${missedByShopBadge(o)}

        <div class="order-detail-divider"></div>

        <div class="order-detail-section order-detail-section--items">
          <h5>Items</h5>
          ${orderItemRows(o)}
        </div>

        <div class="order-detail-section order-detail-section--payment">
          ${orderDetailLine("Subtotal", fmtMoney(o.subtotal))}
          ${orderDetailLine("Discount", fmtMoney(o.discount))}
          ${Number(o.orderCommissionLkr) > 0 ? orderDetailLine("Order commission", fmtMoney(o.orderCommissionLkr)) : ""}
          ${Number(o.baseDeliveryFeeLkr) > 0 || Number(o.riderCommissionLkr) > 0
            ? orderDetailLine(
                "Delivery (base + rider)",
                `${fmtMoney(o.baseDeliveryFeeLkr || 0)} + ${fmtMoney(o.riderCommissionLkr || 0)}`
              )
            : ""}
          ${orderDetailLine("Delivery fee", fmtMoney(o.deliveryFee))}
          ${orderDetailLine("Total", fmtMoney(o.total), "order-detail-line--total")}
        </div>

        <div class="order-detail-section">
          <h5>${isSelfPickupOrder(o) ? "Pickup" : "Delivery address"}</h5>
          <p class="order-detail-address">${escapeHtml(address)}</p>
          ${note ? `<div class="order-detail-note"><span>Note</span>${escapeHtml(note)}</div>` : ""}
        </div>

        <p class="order-detail-footer">Thank you for using MND Delivery</p>
      </div>
    </div>`;
    openModal("Order details", html, "order-detail", id);
    modalSave.style.display = "none";
  }

  async function openOrderEdit(id) {
    if (cache.riders.length === 0) {
      await loadRiders();
    }
    const o = findOrder(id);
    if (!o) return;
    const currentRiderId = o.riderId || o.assignedRiderId || "";
    const riderOptions = [
      `<option value="">Unassigned</option>`,
      ...cache.riders.map((r) => {
        const riderId = String(r.id || "").trim();
        const firstLast = [r.firstName, r.lastName].filter(Boolean).join(" ").trim();
        const riderName = r.fullName || firstLast || r.displayName || r.name || riderId || "Unnamed rider";
        const riderPhone = r.phoneNumber || r.phone || "";
        const riderLabel = riderPhone ? `${riderName} (${riderPhone})` : riderName;
        const selected = riderId === currentRiderId ? "selected" : "";
        return `<option value="${escapeHtml(riderId)}" ${selected}>${escapeHtml(riderLabel)}</option>`;
      }),
    ].join("");
    const selfPickup = isSelfPickupOrder(o);
    const statusOptions = resolveOrderStatusOptions(o);
    const opts = statusOptions
      .map(
        (s) =>
          `<option value="${escapeHtml(s)}" ${String(o.status).toLowerCase() === s ? "selected" : ""}>${escapeHtml(statusLabel(s))}</option>`
      )
      .join("");
    const riderField = selfPickup
      ? ""
      : `<div class="form-group"><label>Rider (optional)</label><select id="f-ord-rider">${riderOptions}</select></div>`;
    const fulfillmentHint = selfPickup
      ? `<p style="color:var(--muted);font-size:0.85rem;margin:0 0 12px">Self pickup — delivery statuses are hidden.</p>`
      : "";
    openModal(
      "Edit order",
      `${fulfillmentHint}<div class="form-group"><label>Status</label><select id="f-ord-status">${opts}</select></div>
      ${riderField}
      <div class="form-group"><label>Subtotal (LKR)</label><input type="number" id="f-ord-sub" min="0" step="1" value="${Number(o.subtotal) || 0}"></div>
      <div class="form-group"><label>Discount</label><input type="number" id="f-ord-disc" min="0" step="1" value="${Number(o.discount) || 0}"></div>
      <div class="form-group"><label>Order commission</label><input type="number" id="f-ord-commission" min="0" step="1" value="${Number(o.orderCommissionLkr) || 0}"></div>
      <div class="form-group"><label>Base delivery fee</label><input type="number" id="f-ord-base-fee" min="0" step="1" value="${Number(o.baseDeliveryFeeLkr) || 0}"></div>
      <div class="form-group"><label>Rider commission</label><input type="number" id="f-ord-rider-fee" min="0" step="1" value="${Number(o.riderCommissionLkr) || 0}"></div>
      <div class="form-group"><label>Delivery fee (base + rider)</label><input type="number" id="f-ord-fee" min="0" step="1" value="${Number(o.deliveryFee) || 0}"></div>
      <div class="form-group"><label>Total</label><input type="number" id="f-ord-total" min="0" step="1" value="${Number(o.total) || 0}"></div>`,
      "order-edit",
      id
    );
    modalSave.style.display = "inline-flex";
  }

  function openOrderCreate() {
    openModal(
      "New order (admin)",
      `<p style="color:var(--muted);font-size:0.85rem;margin-top:0">Creates one line item matching <code>total</code>. Requires valid customer/vendor IDs.</p>
      <div class="form-group"><label>Customer UID</label><input type="text" id="f-no-cust" required placeholder="customers doc id (Auth UID)"></div>
      <div class="form-group"><label>Vendor / store ID</label><input type="text" id="f-no-vend" required></div>
      <div class="form-group"><label>Store name</label><input type="text" id="f-no-store" required></div>
      <div class="form-group"><label>Status</label><select id="f-no-status">${ORDER_STATUSES.map((s) => `<option value="${s}">${statusLabel(s)}</option>`).join("")}</select></div>
      <div class="form-group"><label>Total (LKR)</label><input type="number" id="f-no-total" min="1" step="1" value="500" required></div>
      <div class="form-group"><label>Address line 1</label><input type="text" id="f-no-l1" required></div>
      <div class="form-group"><label>City</label><input type="text" id="f-no-city" required></div>
      <div class="form-group"><label>Phone</label><input type="text" id="f-no-phone" required minlength="8"></div>`,
      "order-create",
      null
    );
    modalSave.style.display = "inline-flex";
  }

  async function openAssignRiderModal(orderId) {
    if (!db) return;
    if (cache.riders.length === 0) await loadRiders();
    if (cache.vendors.length === 0) await loadVendors();
    const o = findOrder(orderId);
    if (!o) return;
    const vid = String(o.vendorId || o.vendorStoreId || "").trim();
    const vendor = await getVendorDocForOrder(vid);
    const shopPt = readLatLng(vendor || {});
    const shopName = String(o.storeName || vendor?.name || "—").trim() || "—";
    const track = String(o.trackingNumber || "").trim();
    const titleLabel = track || o.id;

    const online = cache.riders.filter(riderIsOnline);
    const rows = online.map((r) => {
      const riderPt = readLatLng(r);
      let distKm = null;
      if (shopPt && riderPt) distKm = haversineKm(riderPt.lat, riderPt.lng, shopPt.lat, shopPt.lng);
      return { r, riderPt, distKm };
    });
    rows.sort((a, b) => {
      const aOk = a.distKm != null && Number.isFinite(a.distKm);
      const bOk = b.distKm != null && Number.isFinite(b.distKm);
      if (aOk && bOk) return a.distKm - b.distKm;
      if (aOk) return -1;
      if (bOk) return 1;
      return riderDisplayName(a.r).localeCompare(riderDisplayName(b.r));
    });

    let tableBody =
      rows.length === 0
        ? `<tr><td colspan="5"><div class="empty-state">No online riders (<code>online: true</code> on <code>riders</code>).</div></td></tr>`
        : rows
            .map(({ r, riderPt, distKm }) => {
              const name = riderDisplayName(r);
              const distLabel =
                distKm != null && Number.isFinite(distKm) ? `${distKm.toFixed(1)} km` : "— (no coordinates)";
              const locBlock = `<div class="assign-loc"><span>Rider</span> ${escapeHtml(fmtCoordPair(riderPt))}<br/><span>Shop</span> ${escapeHtml(fmtCoordPair(shopPt))}</div>`;
              return `<tr>
          <td><strong>${escapeHtml(name)}</strong></td>
          <td>${escapeHtml(shopName)}</td>
          <td class="assign-loc-cell">${locBlock}</td>
          <td>${escapeHtml(distLabel)}</td>
          <td><button type="button" class="btn btn-primary btn-sm" data-assign-rider="${escapeHtml(r.id)}" data-assign-order="${escapeHtml(orderId)}">Assign</button></td>
        </tr>`;
            })
            .join("");

    const shopWarn =
      !shopPt && vid
        ? `<p class="assign-warn">Shop has no map coordinates in <code>vendors/${escapeHtml(vid)}</code> — distances show as —. Add latitude/longitude in vendor Edit.</p>`
        : !vid
          ? `<p class="assign-warn">Order has no <code>vendorId</code> — cannot resolve shop location.</p>`
          : "";

    const html = `<p style="margin-top:0;color:var(--muted);font-size:0.9rem">Order <strong>${escapeHtml(titleLabel)}</strong> · Pick an online rider (nearest first when both rider and shop have coordinates).</p>
      ${shopWarn}
      <div class="table-wrap assign-rider-wrap">
        <table class="assign-rider-table">
          <thead><tr><th>Rider</th><th>Shop</th><th>Coordinates</th><th>Distance</th><th></th></tr></thead>
          <tbody>${tableBody}</tbody>
        </table>
      </div>`;

    openModal(`Assign rider — ${titleLabel}`, html, "assign-rider", orderId);
    modalSave.style.display = "none";
  }

  async function deleteOrder(id) {
    const o = findOrder(id);
    const label = o ? orderDisplayNumber(o) : "this order";
    if (!confirm(`Delete ${label}?`)) return;
    await db.collection(COL.orders).doc(id).delete();
    await loadViewData("orders");
    await loadOrders();
    renderDashboard();
  }

  window.findOrder = findOrder;
  window.loadOrdersPage = loadOrdersPage;
  window.renderOrders = renderOrders;
  window.renderOrdersPaginationControls = renderOrdersPaginationControls;
  window.openOrderDetails = openOrderDetails;
  window.openOrderEdit = openOrderEdit;
  window.openOrderCreate = openOrderCreate;
  window.openAssignRiderModal = openAssignRiderModal;
  window.deleteOrder = deleteOrder;
})();
