/**
 * MND web admin — Firestore CRUD aligned with mnd_customer:
 * collections: orders, customers, vendors, products, banners, shop_categories, shop_types, riders (see firebase_collections.dart).
 * Auth: Firebase Email/Password; Firestore customers/{uid}.role must be "admin".
 */
(function () {
  const COL = {
    customers: "customers",
    riders: "riders",
    vendors: "vendors",
    products: "products",
    banners: "banners",
    shopCategories: "shop_categories",
    shopTypes: "shop_types",
    orders: "orders",
    jobs: "jobs",
    jobApplications: "job_applications",
    platformConfig: "platform_config",
    platformFeesDoc: "fees",
  };

  const PLATFORM_FEES_DEFAULTS = {
    orderCommissionLkr: 0,
    riderCommissionLkr: 0,
    minDeliveryFeeLkr: 170,
    pricePerKmLkr: 50,
    shopMonthlyCommissionPercent: 1,
  };

  const JOB_CATEGORIES = [
    "Part Time",
    "Full Time",
    "Remote",
    "Weekend",
    "Internship",
    "Event Jobs",
    "Delivery",
    "Freelance",
  ];

  const JOB_TYPES = [
    "Part Time",
    "Full Time",
    "Temporary",
    "Weekend",
    "Freelance",
    "Remote",
    "Internship",
    "Event Staff",
  ];

  /** One-shot reads; avoids stale cache sync over the Listen channel. */
  const FS_GET_SERVER = { source: "server" };

  const ORDER_STATUSES_DELIVERY = [
    "placed",
    "confirmed",
    "preparing",
    "ready",
    "out_for_delivery",
    "on_the_way",
    "delivered",
    "cancelled",
  ];

  const ORDER_STATUSES_SELF_PICKUP = [
    "placed",
    "confirmed",
    "preparing",
    "ready",
    "completed",
    "cancelled",
  ];

  /** @deprecated use orderStatusesFor() */
  const ORDER_STATUSES = ORDER_STATUSES_DELIVERY;

  let db = null;
  let auth = null;
  let currentView = "dashboard";
  let cache = {
    orders: [],
    vendors: [],
    products: [],
    banners: [],
    shopCategories: [],
    shopTypes: [],
    riders: [],
    customers: [],
    jobs: [],
    jobApplications: [],
    platformFees: { ...PLATFORM_FEES_DEFAULTS },
    monthlyInvoices: [],
  };

  const elAuthGate = document.getElementById("auth-gate");
  const elLogout = document.getElementById("btn-logout");
  const elPageTitle = document.getElementById("page-title");
  const elViews = document.querySelectorAll("[data-view]");
  const elNav = document.querySelectorAll(".nav-btn");
  const elTopEmail = document.getElementById("topbar-email");

  const modalBackdrop = document.getElementById("modal-backdrop");
  const modalTitle = document.getElementById("modal-title");
  const modalBody = document.getElementById("modal-body");
  const modalCancel = document.getElementById("modal-cancel");
  const modalSave = document.getElementById("modal-save");

  let modalMode = null;
  let modalEditId = null;
  const productImageUrlCache = new Map();
  const productImageBlobUrls = [];

  const ui = () => window.MndUI || {};

  function toast(msg, type) {
    const t = ui().showToast;
    if (t) t(msg, type);
  }

  function initFirebase() {
    const boot = window.MndFirebase.initFirebase();
    auth = boot.auth;
    db = boot.db;
  }

  function assertAdmin(uid) {
    return window.MndFirebase.assertAdmin(uid);
  }

  function hideAuthGate() {
    if (elAuthGate) {
      elAuthGate.classList.add("hidden");
    }
  }

  function redirectToLogin(message) {
    window.MndAuthRoutes.goLogin(message);
  }

  function escapeHtml(s) {
    if (s == null) return "";
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  }

  function fmtMoney(n) {
    const v = Number(n) || 0;
    return `LKR ${v.toLocaleString()}`;
  }

  function fmtTs(val) {
    if (!val) return "—";
    try {
      if (typeof val.toDate === "function") return val.toDate().toLocaleString();
      if (val.seconds != null) return new Date(val.seconds * 1000).toLocaleString();
    } catch (_) {}
    return "—";
  }

  function badgeClass(status) {
    const s = String(status || "").toLowerCase();
    if (s === "placed" || s === "confirmed") return "badge-preparing";
    if (s === "preparing" || s === "ready") return "badge-preparing";
    if (s === "out_for_delivery" || s === "on_the_way") return "badge-out";
    if (s === "delivered" || s === "completed") return "badge-delivered";
    if (s === "cancelled") return "badge-cancelled";
    return "badge-pending";
  }

  function statusLabel(s) {
    const k = String(s || "").toLowerCase();
    const map = {
      placed: "Placed",
      confirmed: "Confirmed",
      preparing: "Preparing",
      ready: "Ready",
      out_for_delivery: "Out for delivery",
      on_the_way: "On the way",
      delivered: "Delivered",
      completed: "Collected",
      cancelled: "Cancelled",
    };
    return map[k] || s || "—";
  }

  function isSelfPickupOrder(o) {
    const mode = String(o?.fulfillmentMode || "")
      .trim()
      .toLowerCase()
      .replace(/_/g, "");
    return mode === "selfpickup";
  }

  function orderStatusesFor(o) {
    return isSelfPickupOrder(o) ? ORDER_STATUSES_SELF_PICKUP : ORDER_STATUSES_DELIVERY;
  }

  /** Keeps the current status visible even if it no longer fits the fulfillment mode. */
  function resolveOrderStatusOptions(o) {
    const base = orderStatusesFor(o);
    const current = String(o?.status || "").toLowerCase();
    if (current && !base.includes(current)) {
      const withoutCancelled = base.filter((s) => s !== "cancelled");
      return [...withoutCancelled, current, "cancelled"];
    }
    return base;
  }

  function orderAddrLine(data) {
    const a = data.deliveryAddress;
    if (!a || typeof a !== "object") return "—";
    const p = [a.line1, a.line2, a.city].filter(Boolean).join(", ");
    return p || "—";
  }

  /** Firestore GeoPoint or plain lat/lng on vendor / rider docs. */
  function readLatLng(obj) {
    if (!obj || typeof obj !== "object") return null;
    const loc = obj.location;
    if (loc != null && typeof loc === "object") {
      const la = Number(loc.latitude);
      const ln = Number(loc.longitude);
      if (Number.isFinite(la) && Number.isFinite(ln)) return { lat: la, lng: ln };
    }
    const la1 = Number(obj.latitude);
    const ln1 = Number(obj.longitude);
    if (Number.isFinite(la1) && Number.isFinite(ln1)) return { lat: la1, lng: ln1 };
    const la2 = Number(obj.currentLatitude ?? obj.lat);
    const ln2 = Number(obj.currentLongitude ?? obj.lng);
    if (Number.isFinite(la2) && Number.isFinite(ln2)) return { lat: la2, lng: ln2 };
    return null;
  }

  function haversineKm(lat1, lng1, lat2, lng2) {
    const R = 6371;
    const toRad = (d) => (d * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  function riderRegistrationStatus(r) {
    return String(r.status || "pending").trim().toLowerCase();
  }

  function riderIsApproved(r) {
    const s = riderRegistrationStatus(r);
    return s === "approved" || s === "active";
  }

  function riderStatusBadge(statusRaw) {
    const s = String(statusRaw || "pending").toLowerCase();
    if (s === "approved" || s === "active") {
      return `<span class="badge badge-delivered">Approved</span>`;
    }
    if (s === "rejected") {
      return `<span class="badge badge-cancelled">Rejected</span>`;
    }
    return `<span class="badge badge-pending">Pending</span>`;
  }

  const RIDER_VEHICLE_TYPE_LABELS = {
    bike: "Bike",
    three_wheeler: "Three Wheeler",
    car: "Car",
    van: "Car",
  };

  const RIDER_LANGUAGE_LABELS = {
    en: "English",
    si: "සිංහල",
    ta: "தமிழ்",
  };

  const RIDER_VEHICLE_PHOTO_LABELS = {
    front: "Front",
    back: "Back",
    left: "Left",
    right: "Right",
    interior: "Interior",
  };

  function riderVehicleTypeLabel(raw) {
    const v = String(raw || "").trim().toLowerCase();
    return RIDER_VEHICLE_TYPE_LABELS[v] || raw || "—";
  }

  function riderLanguageLabel(code) {
    const key = String(code || "").trim().toLowerCase();
    return RIDER_LANGUAGE_LABELS[key] || code || "—";
  }

  function riderNestedObject(r, key) {
    const val = r?.[key];
    return val && typeof val === "object" ? val : {};
  }

  function riderLicense(r) {
    return riderNestedObject(r, "license");
  }

  function riderInsurance(r) {
    return riderNestedObject(r, "insurance");
  }

  function riderRevenueLicence(r) {
    return riderNestedObject(r, "revenueLicence");
  }

  function riderOwnership(r) {
    return riderNestedObject(r, "ownership");
  }

  function riderVehicleInfo(r) {
    return riderNestedObject(r, "vehicle");
  }

  function fmtDate(val) {
    if (!val) return "—";
    try {
      if (typeof val.toDate === "function") return val.toDate().toLocaleDateString();
      if (val.seconds != null) return new Date(val.seconds * 1000).toLocaleDateString();
      if (typeof val === "string" && val.trim()) {
        const d = new Date(val);
        if (!Number.isNaN(d.getTime())) return d.toLocaleDateString();
      }
    } catch (_) {}
    return "—";
  }

  function riderVehicleLabel(r) {
    const type = riderVehicleTypeLabel(r.vehicleType || (typeof r.vehicle === "string" ? r.vehicle : ""));
    const num = r.vehicleNumber || "";
    const vehicle = riderVehicleInfo(r);
    const details = [vehicle.brand, vehicle.model].filter(Boolean).join(" ").trim();
    if (type && num) {
      return details ? `${type} · ${details} · ${num}` : `${type} · ${num}`;
    }
    return type || num || details || "—";
  }

  function riderAvatarHtml(r, className = "") {
    const url = compactText(r?.profilePhotoUrl);
    const classes = `rider-avatar ${className}`.trim();
    if (url) {
      return `<img class="${escapeHtml(classes)}" src="${escapeHtml(url)}" alt="" loading="lazy" />`;
    }
    const name = riderDisplayName(r);
    const initials = name
      .split(/\s+/)
      .filter(Boolean)
      .map((part) => part[0])
      .join("")
      .slice(0, 2)
      .toUpperCase();
    return `<div class="${escapeHtml(classes)} rider-avatar--fallback">${escapeHtml(initials || "?")}</div>`;
  }

  function riderDocLink(url, label) {
    if (!url) return "—";
    return `<a class="rider-doc-link" href="${escapeHtml(url)}" target="_blank" rel="noopener">${escapeHtml(label)}</a>`;
  }

  function riderPhotoThumb(url, label) {
    if (!url) return "";
    return `<a class="rider-photo-thumb" href="${escapeHtml(url)}" target="_blank" rel="noopener" title="${escapeHtml(label)}">
      <img src="${escapeHtml(url)}" alt="${escapeHtml(label)}" loading="lazy" />
      <span>${escapeHtml(label)}</span>
    </a>`;
  }

  function riderIdentityDocsHtml(r) {
    const license = riderLicense(r);
    const items = [
      riderPhotoThumb(r.profilePhotoUrl, "Profile"),
      riderPhotoThumb(r.nicPhotoUrl, "NIC"),
      riderPhotoThumb(license.frontUrl || r.licensePhotoUrl, "License (front)"),
      riderPhotoThumb(license.backUrl, "License (back)"),
      riderPhotoThumb(riderInsurance(r).photoUrl, "Insurance"),
      riderPhotoThumb(riderRevenueLicence(r).photoUrl, "Revenue licence"),
    ].filter(Boolean);
    if (!items.length) {
      return `<div class="rider-profile-empty">No document photos uploaded.</div>`;
    }
    return `<div class="rider-photo-grid">${items.join("")}</div>`;
  }

  function riderVehiclePhotosHtml(r) {
    const photos = riderNestedObject(r, "vehiclePhotos");
    const items = ["front", "back", "left", "right", "interior"]
      .filter((side) => photos[side])
      .map((side) => riderPhotoThumb(photos[side], RIDER_VEHICLE_PHOTO_LABELS[side] || side));
    if (!items.length) {
      return `<div class="rider-profile-empty">No vehicle photos uploaded.</div>`;
    }
    return `<div class="rider-photo-grid">${items.join("")}</div>`;
  }

  function riderServicesHtml(r) {
    const tags = [];
    if (r.acceptsDelivery !== false) {
      tags.push('<span class="badge badge-delivered">Delivery</span>');
    }
    if (r.acceptsPassengerRides !== false) {
      tags.push('<span class="badge badge-preparing">Passenger rides</span>');
    }
    return tags.length ? tags.join(" ") : '<span class="muted">—</span>';
  }

  function bindRiderRowOpen(tbody) {
    tbody.querySelectorAll("[data-view-rider]").forEach((row) => {
      const open = () => openRiderDetailView(row.getAttribute("data-view-rider"));
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
  }

  function vendorApprovalStatus(v) {
    return String(v.approvalStatus || "pending").trim().toLowerCase();
  }

  function vendorIsPending(v) {
    const s = vendorApprovalStatus(v);
    return s !== "approved" && s !== "rejected";
  }

  function countPendingVendors() {
    return cache.vendors.filter((v) => vendorIsPending(v)).length;
  }

  function countPendingJobs() {
    return cache.jobs.filter((j) => String(j.status || "").toLowerCase() === "pending").length;
  }

  function countPendingRiders() {
    return cache.riders.filter((r) => riderRegistrationStatus(r) === "pending").length;
  }

  function updatePendingRiderNavBadge() {
    const n = countPendingRiders();
    const navBadge = document.getElementById("nav-pending-riders");
    if (navBadge) {
      if (n > 0) {
        navBadge.textContent = String(n);
        navBadge.hidden = false;
      } else {
        navBadge.hidden = true;
      }
    }
    const stat = document.getElementById("stat-riders-pending");
    if (stat) {
      stat.textContent = String(n);
    }
  }

  function updatePendingShopNavBadge() {
    const n = countPendingVendors();
    const navBadge = document.getElementById("nav-pending-shops");
    if (navBadge) {
      if (n > 0) {
        navBadge.textContent = String(n);
        navBadge.hidden = false;
      } else {
        navBadge.hidden = true;
      }
    }
    const stat = document.getElementById("stat-shops-pending");
    if (stat) stat.textContent = String(n);
  }

  function updatePendingJobNavBadge() {
    const n = countPendingJobs();
    const navBadge = document.getElementById("nav-pending-jobs");
    if (navBadge) {
      if (n > 0) {
        navBadge.textContent = String(n);
        navBadge.hidden = false;
      } else {
        navBadge.hidden = true;
      }
    }
    const stat = document.getElementById("stat-jobs-pending");
    if (stat) stat.textContent = String(n);
  }

  function updateAllApprovalBadges() {
    updatePendingRiderNavBadge();
    updatePendingShopNavBadge();
    updatePendingJobNavBadge();
  }

  function riderIsOnline(r) {
    if (!riderIsApproved(r)) {
      return false;
    }
    if (r.online === true) {
      return true;
    }
    const s = riderRegistrationStatus(r);
    return s === "online";
  }

  function riderDisplayName(r) {
    const firstLast = [r.firstName, r.lastName].filter(Boolean).join(" ").trim();
    return r.fullName || firstLast || r.displayName || r.name || r.id || "—";
  }

  function compactText(...values) {
    for (const value of values) {
      const text = String(value || "").trim();
      if (text) return text;
    }
    return "";
  }

  function customerById(customerId) {
    const id = String(customerId || "").trim();
    if (!id) return null;
    return cache.customers.find((x) => x.id === id || x.uid === id) || null;
  }

  function customerDisplayName(orderOrCustomer) {
    const source =
      orderOrCustomer && (orderOrCustomer.customerId || orderOrCustomer.uid)
        ? customerById(orderOrCustomer.customerId || orderOrCustomer.uid) || orderOrCustomer
        : orderOrCustomer;
    const firstLast = [source?.firstName, source?.lastName].filter(Boolean).join(" ").trim();
    return compactText(
      source?.customerName,
      source?.displayName,
      source?.fullName,
      firstLast,
      source?.name,
      source?.phoneNumber,
      source?.phone,
      "Unknown customer"
    );
  }

  function customerRole(u) {
    return String(u?.role || "customer").trim().toLowerCase() || "customer";
  }

  function customerRoleBadge(roleRaw) {
    const role = customerRole({ role: roleRaw });
    if (role === "admin") return `<span class="badge badge-preparing">Admin</span>`;
    if (role === "vendor") return `<span class="badge badge-out">Vendor</span>`;
    return `<span class="badge badge-delivered">Customer</span>`;
  }

  function customerInitials(u) {
    const name = customerDisplayName(u);
    const parts = name
      .split(/\s+/)
      .map((p) => p.trim())
      .filter(Boolean);
    if (parts.length >= 2) return `${parts[0][0]}${parts[1][0]}`.toUpperCase();
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return "CU";
  }

  function customerPhone(u) {
    return compactText(u?.phoneNumber, u?.phone, u?.mobile);
  }

  function customerEmail(u) {
    return compactText(u?.email);
  }

  function customerOrderCount(uid) {
    const id = String(uid || "").trim();
    if (!id) return 0;
    return cache.orders.filter((o) => String(o.customerId || "").trim() === id).length;
  }

  function customerAvatarHtml(u, className = "") {
    const url = compactText(u?.photoUrl, u?.photoURL, u?.avatarUrl, u?.imageUrl);
    const classes = `customer-avatar ${className}`.trim();
    if (url) {
      return `<img class="${escapeHtml(classes)}" src="${escapeHtml(url)}" alt="" loading="lazy" />`;
    }
    return `<div class="${escapeHtml(classes)}">${escapeHtml(customerInitials(u))}</div>`;
  }

  function vendorByOrder(order) {
    const id = compactText(order?.vendorId, order?.vendorStoreId, order?.storeId);
    if (!id) return null;
    return cache.vendors.find((x) => x.id === id || x.vendorStoreId === id) || null;
  }

  function shopDisplayName(order) {
    const vendor = vendorByOrder(order);
    return compactText(order?.storeName, vendor?.name, vendor?.storeName, vendor?.displayName, "Unknown shop");
  }

  function orderDisplayNumber(order) {
    return compactText(order?.trackingNumber, "Order");
  }

  function orderItemRows(order) {
    const items = Array.isArray(order?.items) ? order.items : [];
    if (!items.length) {
      return `<div class="order-detail-empty">No item details recorded.</div>`;
    }
    const rows = items
      .map((item) => {
        const qty = Number(item.quantity) || 1;
        const name = compactText(item.productName, item.name, item.title, "Item");
        const size = compactText(item.selectedSize, item.size);
        const extras = Array.isArray(item.extras)
          ? item.extras
              .map((extra) => compactText(extra?.name))
              .filter(Boolean)
              .join(", ")
          : "";
        const meta = [size, extras].filter(Boolean).join(" · ");
        const unit = Number(item.unitPrice ?? item.basePrice) || 0;
        const total = Number(item.lineTotal ?? item.totalPrice) || unit * qty;
        return `<div class="order-detail-item">
          <div>
            <strong>${escapeHtml(name)}</strong>
            ${meta ? `<small>${escapeHtml(meta)}</small>` : ""}
            <small>${escapeHtml(String(qty))} x ${fmtMoney(unit)}</small>
          </div>
          <div class="order-detail-item__price">${fmtMoney(total)}</div>
        </div>`;
      })
      .join("");
    return `<div class="order-detail-items">
      <div class="order-detail-item order-detail-item--head">
        <span>Item</span>
        <span>Amount</span>
      </div>
      ${rows}
    </div>`;
  }

  function orderDetailValue(label, value) {
    return `<div class="order-detail-field">
      <span>${escapeHtml(label)}</span>
      <strong>${escapeHtml(value || "—")}</strong>
    </div>`;
  }

  function orderDetailLine(label, value, extraClass = "") {
    return `<div class="order-detail-line ${extraClass}">
      <span>${escapeHtml(label)}</span>
      <strong>${escapeHtml(value || "—")}</strong>
    </div>`;
  }

  function paymentMethodLabel(value) {
    const key = String(value || "").trim();
    const map = {
      cashOnDelivery: "Cash on delivery",
      cod: "Cash on delivery",
      card: "Card",
      online: "Online",
    };
    return map[key] || key || "—";
  }

  function fmtCoordPair(pt) {
    if (!pt) return "—";
    return `${Number(pt.lat).toFixed(5)}, ${Number(pt.lng).toFixed(5)}`;
  }

  async function getVendorDocForOrder(vendorId) {
    const vid = String(vendorId || "").trim();
    if (!vid) return null;
    let v = cache.vendors.find((x) => x.id === vid);
    if (v) return v;
    const snap = await db.collection(COL.vendors).doc(vid).get(FS_GET_SERVER);
    if (!snap.exists) return null;
    return { id: snap.id, ...snap.data() };
  }

  async function openAssignRiderModal(orderId) {
    if (!db) return;
    if (cache.riders.length === 0) await loadRiders();
    if (cache.vendors.length === 0) await loadVendors();
    const o = cache.orders.find((x) => x.id === orderId);
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

  function openModal(title, html, mode, editId) {
    modalTitle.textContent = title;
    modalBody.innerHTML = html;
    modalMode = mode;
    modalEditId = editId;
    const dialog = modalBackdrop.querySelector(".modal");
    if (dialog) {
      dialog.classList.toggle(
        "modal--wide",
        mode === "assign-rider" ||
          mode === "job-applications" ||
          mode === "order-detail" ||
          mode === "customer-profile" ||
          mode === "rider-profile"
      );
    }
    modalBackdrop.classList.add("visible");
  }

  function closeModal() {
    modalBackdrop.classList.remove("visible");
    modalMode = null;
    modalEditId = null;
    const dialog = modalBackdrop.querySelector(".modal");
    if (dialog) dialog.classList.remove("modal--wide");
    modalSave.style.display = "inline-flex";
  }

  modalCancel.addEventListener("click", closeModal);
  modalBackdrop.addEventListener("click", (e) => {
    if (e.target === modalBackdrop) closeModal();
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && modalBackdrop.classList.contains("visible")) closeModal();
  });

  modalBody.addEventListener("click", async (e) => {
    const appBtn = e.target.closest("[data-app-status]");
    if (appBtn && modalMode === "job-applications" && modalEditId) {
      const appId = appBtn.getAttribute("data-app-id");
      const status = appBtn.getAttribute("data-app-status");
      if (!appId || !status) return;
      const label = status === "booked" ? "book this applicant" : status;
      if (!confirm(`Mark application as ${label}?`)) return;
      appBtn.disabled = true;
      try {
        await updateJobApplicationStatus(appId, status);
        await loadJobApplications();
        await refreshJobApplicationsModal(modalEditId);
        if (currentView === "job-approvals") renderPublishedJobs();
      } catch (err) {
        alert(err.message || String(err));
      } finally {
        appBtn.disabled = false;
      }
      return;
    }

    const approveRiderBtn = e.target.closest("[data-detail-approve-rider]");
    if (approveRiderBtn && modalMode === "rider-profile" && modalEditId) {
      approveRiderBtn.disabled = true;
      try {
        await approveRider(modalEditId);
        openRiderDetailView(modalEditId);
      } catch (err) {
        alert(err.message || String(err));
      } finally {
        approveRiderBtn.disabled = false;
      }
      return;
    }

    const rejectRiderBtn = e.target.closest("[data-detail-reject-rider]");
    if (rejectRiderBtn && modalMode === "rider-profile" && modalEditId) {
      rejectRiderBtn.disabled = true;
      try {
        await rejectRider(modalEditId);
        openRiderDetailView(modalEditId);
      } catch (err) {
        alert(err.message || String(err));
      } finally {
        rejectRiderBtn.disabled = false;
      }
      return;
    }

    const editRiderBtn = e.target.closest("[data-detail-edit-rider]");
    if (editRiderBtn && modalMode === "rider-profile" && modalEditId) {
      closeModal();
      openRiderModal(modalEditId);
      return;
    }

    const btn = e.target.closest("[data-assign-rider]");
    if (!btn || modalMode !== "assign-rider") return;
    const riderId = btn.getAttribute("data-assign-rider");
    const orderId = btn.getAttribute("data-assign-order");
    if (!riderId || !orderId || !db) return;
    e.preventDefault();
    try {
      btn.disabled = true;
      await db.collection(COL.orders).doc(orderId).update({
        riderId,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });
      closeModal();
      await loadOrders();
      if (currentView === "orders") renderOrders();
      if (currentView === "dashboard") renderDashboard();
    } catch (err) {
      alert(err.message || String(err));
      btn.disabled = false;
    }
  });

  const titles = {
    dashboard: "Dashboard",
    orders: "Orders",
    vendors: "Vendors",
    products: "Products",
    banners: "Banners",
    "shop-types": "Shop types",
    "shop-approvals": "Shop approvals",
    "job-approvals": "Job approvals",
    "rider-approvals": "Rider approvals",
    riders: "Riders",
    customers: "Customers",
    "platform-fees": "Fees & commissions",
    help: "Setup",
  };

  function showView(name) {
    currentView = name;
    elPageTitle.textContent = titles[name] || name;
    elViews.forEach((v) => {
      v.hidden = v.getAttribute("data-view") !== name;
    });
    elNav.forEach((b) => b.classList.toggle("active", b.getAttribute("data-nav") === name));
    loadViewData(name).catch((e) => {
      toast(e.message || String(e), "error");
    });
  }

  async function loadViewData(name) {
    if (!db || !auth.currentUser) return;
    const setLoading = ui().setLoading;
    if (setLoading) setLoading(true, "Loading data…");
    try {
      if (window.MndFirebase.ensureFirestoreAuth) {
        await window.MndFirebase.ensureFirestoreAuth();
      }
      await loadViewDataInner(name);
      if (ui().setLastSync) ui().setLastSync();
    } finally {
      if (setLoading) setLoading(false);
    }
  }

  async function loadViewDataInner(name) {
    if (name === "dashboard") {
      await Promise.all([loadOrders(), loadVendors(), loadCustomers(), loadJobs(), loadRiders()]);
    }
    if (name === "orders") await Promise.all([loadOrders(), loadCustomers(), loadVendors()]);
    if (name === "vendors" || name === "shop-approvals") {
      await loadVendors();
    }
    if (name === "job-approvals") {
      await loadJobs();
      await loadJobApplications();
    }
    if (name === "products") {
      await Promise.all([loadProducts(), loadVendors()]);
    }
    if (name === "banners") await loadBanners();
    if (name === "shop-types") await loadShopTypes();
    if (name === "riders" || name === "rider-approvals" || name === "dashboard") {
      await loadRiders();
    }
    if (name === "customers") await Promise.all([loadCustomers(), loadOrders()]);
    if (name === "platform-fees") {
      await Promise.all([loadPlatformFees(), loadVendors()]);
      seedInvoiceMonthInput();
      await loadMonthlyInvoicesForSelectedMonth();
    }
    if (name === "dashboard") renderDashboard();
    if (name === "orders") renderOrders();
    if (name === "vendors") renderVendors();
    if (name === "shop-approvals") renderShopApprovals();
    if (name === "job-approvals") {
      renderJobApprovals();
      renderPublishedJobs();
    }
    if (name === "products") renderProducts();
    if (name === "banners") renderBanners();
    if (name === "shop-types") {
      renderShopCategories();
      renderShopTypes();
    }
    if (name === "rider-approvals") renderRiderApprovals();
    if (name === "riders") renderRiders();
    if (name === "customers") renderCustomers();
    if (name === "platform-fees") {
      renderPlatformFeesForm();
      renderMonthlyInvoices();
    }
  }

  async function loadOrders() {
    try {
      const q = db.collection(COL.orders).orderBy("createdAt", "desc").limit(200);
      const snap = await q.get(FS_GET_SERVER);
      cache.orders = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.orders).limit(200).get(FS_GET_SERVER);
      cache.orders = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    }
  }

  async function loadVendors() {
    try {
      const snap = await db.collection(COL.vendors).orderBy("name").limit(300).get(FS_GET_SERVER);
      cache.vendors = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.vendors).limit(300).get(FS_GET_SERVER);
      cache.vendors = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.vendors.sort((a, b) =>
        String(a.name || "").localeCompare(String(b.name || ""))
      );
    }
    updatePendingShopNavBadge();
  }

  async function loadJobs() {
    try {
      const snap = await db.collection(COL.jobs).orderBy("createdAt", "desc").limit(200).get(FS_GET_SERVER);
      cache.jobs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.jobs).limit(200).get(FS_GET_SERVER);
      cache.jobs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.jobs.sort((a, b) => {
        const ta = a.createdAt && a.createdAt.seconds ? a.createdAt.seconds : 0;
        const tb = b.createdAt && b.createdAt.seconds ? b.createdAt.seconds : 0;
        return tb - ta;
      });
    }
    updatePendingJobNavBadge();
  }

  async function loadJobApplications() {
    if (!db) return;
    try {
      const snap = await db
        .collection(COL.jobApplications)
        .orderBy("appliedAt", "desc")
        .limit(500)
        .get(FS_GET_SERVER);
      cache.jobApplications = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.jobApplications).limit(500).get(FS_GET_SERVER);
      cache.jobApplications = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.jobApplications.sort((a, b) => {
        const ta = a.appliedAt && a.appliedAt.seconds ? a.appliedAt.seconds : 0;
        const tb = b.appliedAt && b.appliedAt.seconds ? b.appliedAt.seconds : 0;
        return tb - ta;
      });
    }
  }

  function applicationsForJob(jobId) {
    return cache.jobApplications.filter((a) => String(a.jobId || "") === String(jobId || ""));
  }

  function countJobApplications(jobId) {
    return applicationsForJob(jobId).length;
  }

  function countBookedForJob(jobId) {
    return applicationsForJob(jobId).filter(
      (a) => String(a.status || "").toLowerCase() === "booked"
    ).length;
  }

  function jobLaborLimit(job) {
    const n = parseInt(String(job?.availableLaborCount ?? 1), 10);
    if (!Number.isFinite(n) || n < 1) return 1;
    if (n > 99) return 99;
    return n;
  }

  function canBookMoreForJob(jobId) {
    const job = cache.jobs.find((x) => x.id === jobId);
    if (!job) return false;
    return countBookedForJob(jobId) < jobLaborLimit(job);
  }

  function jobApplicationStatusBadge(status) {
    const s = String(status || "submitted").toLowerCase();
    if (s === "booked") return `<span class="badge badge-delivered">Booked</span>`;
    if (s === "shortlisted") return `<span class="badge badge-preparing">Shortlisted</span>`;
    if (s === "rejected") return `<span class="badge badge-cancelled">Rejected</span>`;
    return `<span class="badge badge-pending">Applied</span>`;
  }

  function revokeProductImageBlobUrls() {
    productImageBlobUrls.forEach((url) => {
      try {
        URL.revokeObjectURL(url);
      } catch (_) {}
    });
    productImageBlobUrls.length = 0;
  }

  async function loadProducts() {
    productImageUrlCache.clear();
    revokeProductImageBlobUrls();
    try {
      const snap = await db.collection(COL.products).orderBy("name").limit(500).get(FS_GET_SERVER);
      cache.products = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.products).limit(500).get(FS_GET_SERVER);
      cache.products = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    }
    await enrichProductsWithDisplayImages();
  }

  function pickCatalogImageUrl(map) {
    const directKeys = [
      "imageUrl",
      "imageURL",
      "image",
      "photoUrl",
      "coverImage",
      "thumbnailUrl",
      "thumbUrl",
    ];
    for (const key of directKeys) {
      const raw = map[key];
      if (typeof raw === "string") {
        const trimmed = raw.trim();
        if (trimmed) return normalizeCatalogImageUrl(trimmed);
      }
      if (raw && typeof raw === "object") {
        const nested =
          typeof raw.url === "string"
            ? raw.url
            : typeof raw.downloadURL === "string"
              ? raw.downloadURL
              : "";
        const trimmed = nested.trim();
        if (trimmed) return normalizeCatalogImageUrl(trimmed);
      }
    }
    for (const key of ["galleryImageUrls", "gallery", "images", "photos"]) {
      const raw = map[key];
      if (!Array.isArray(raw)) continue;
      for (const entry of raw) {
        if (typeof entry === "string") {
          const trimmed = entry.trim();
          if (trimmed) return normalizeCatalogImageUrl(trimmed);
        }
      }
    }
    return "";
  }

  function normalizeCatalogImageUrl(url) {
    if (url.startsWith("//")) return `https:${url}`;
    return url;
  }

  function firebaseStorage() {
    return window.MndFirebase.storage;
  }

  function rememberProductBlobUrl(url) {
    if (url && url.startsWith("blob:")) productImageBlobUrls.push(url);
    return url;
  }

  async function fetchStoragePathWithAuth(storagePath) {
    const user = auth?.currentUser || firebase.auth()?.currentUser;
    if (!user || !storagePath) return "";
    try {
      const token = await user.getIdToken();
      const bucket = window.__FIREBASE_CONFIG__?.storageBucket;
      if (!bucket) return "";
      const encoded = encodeURIComponent(storagePath);
      const apiUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encoded}?alt=media`;
      const res = await fetch(apiUrl, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) return "";
      const blob = await res.blob();
      return rememberProductBlobUrl(URL.createObjectURL(blob));
    } catch (_) {
      return "";
    }
  }

  async function tryProductStorageDownloadUrl(storeId, productId) {
    const exts = ["jpg", "jpeg", "png", "webp"];
    for (const ext of exts) {
      const path = `vendor_products/${storeId}/${productId}.${ext}`;
      try {
        const url = await firebaseStorage().ref(path).getDownloadURL();
        if (url) return url;
      } catch (_) {
        const blobUrl = await fetchStoragePathWithAuth(path);
        if (blobUrl) return blobUrl;
      }
    }
    try {
      const folderRef = firebaseStorage().ref(`vendor_products/${storeId}`);
      const listed = await folderRef.listAll();
      const match = listed.items.find((item) => {
        const name = item.name || "";
        const base = name.replace(/\.[^.]+$/, "");
        return base === productId || name.startsWith(`${productId}.`);
      });
      if (match) {
        try {
          return await match.getDownloadURL();
        } catch (_) {
          return fetchStoragePathWithAuth(match.fullPath);
        }
      }
    } catch (_) {
      /* folder list not available */
    }
    return "";
  }

  async function resolveCatalogImageRaw(raw) {
    const trimmed = String(raw || "").trim();
    if (!trimmed) return "";

    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
      return trimmed;
    }

    if (trimmed.startsWith("gs://")) {
      try {
        return await firebaseStorage().refFromURL(trimmed).getDownloadURL();
      } catch (_) {
        const path = trimmed.replace(/^gs:\/\/[^/]+\//, "");
        return fetchStoragePathWithAuth(path);
      }
    }

    if (trimmed.startsWith("vendor_products/")) {
      try {
        return await firebaseStorage().ref(trimmed).getDownloadURL();
      } catch (_) {
        return fetchStoragePathWithAuth(trimmed);
      }
    }

    return trimmed;
  }

  async function resolveProductImageUrl(product) {
    const id = product?.id;
    if (!id) return "";
    if (productImageUrlCache.has(id)) {
      return productImageUrlCache.get(id);
    }
    const task = (async () => {
      const fromDoc = pickCatalogImageUrl(product);
      if (fromDoc) {
        const resolved = await resolveCatalogImageRaw(fromDoc);
        if (resolved) return resolved;
      }
      const storeId = String(product.storeId || "").trim();
      const productId = String(product.id || "").trim();
      if (storeId && productId) {
        return tryProductStorageDownloadUrl(storeId, productId);
      }
      return "";
    })();
    productImageUrlCache.set(id, task);
    return task;
  }

  function productDisplayImageUrl(p) {
    if (!p) return "";
    const fromCatalog = pickCatalogImageUrl(p);
    if (fromCatalog) return fromCatalog;
    const rawImage = typeof p.imageUrl === "string" ? p.imageUrl.trim() : "";
    if (rawImage) return normalizeCatalogImageUrl(rawImage);
    return String(p._displayImageUrl || "").trim();
  }

  async function enrichProductsWithDisplayImages() {
    const user = auth?.currentUser;
    if (user) {
      try {
        await user.getIdToken(true);
      } catch (_) {}
    }
    await Promise.all(
      cache.products.map(async (p) => {
        if (productDisplayImageUrl(p)) {
          delete p._displayImageUrl;
          return;
        }
        const resolved = await resolveProductImageUrl(p);
        if (resolved) p._displayImageUrl = resolved;
        else delete p._displayImageUrl;
      })
    );
  }

  async function loadBanners() {
    try {
      const snap = await db.collection(COL.banners).orderBy("order").limit(100).get(FS_GET_SERVER);
      cache.banners = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.banners).limit(100).get(FS_GET_SERVER);
      cache.banners = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    }
  }

  async function loadShopCategories() {
    try {
      const snap = await db.collection(COL.shopCategories).orderBy("order").limit(200).get(FS_GET_SERVER);
      cache.shopCategories = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.shopCategories).limit(200).get(FS_GET_SERVER);
      cache.shopCategories = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.shopCategories.sort((a, b) => (Number(a.order) || 0) - (Number(b.order) || 0));
    }
  }

  async function loadShopTypes() {
    await loadShopCategories();
    try {
      const snap = await db.collection(COL.shopTypes).orderBy("order").limit(400).get(FS_GET_SERVER);
      cache.shopTypes = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.shopTypes).limit(400).get(FS_GET_SERVER);
      cache.shopTypes = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.shopTypes.sort((a, b) => (Number(a.order) || 0) - (Number(b.order) || 0));
    }
  }

  function shopCategoryLabelById(categoryId) {
    if (!categoryId || typeof categoryId !== "string") return "—";
    const c = cache.shopCategories.find((x) => x.id === categoryId);
    return c ? String(c.label || "—") : "(missing category)";
  }

  function fillShopTypeCategorySelect() {
    const sel = document.getElementById("shop-type-category");
    if (!sel) return;
    const active = cache.shopCategories.filter((c) => c.active !== false);
    const cur = sel.value;
    sel.innerHTML =
      '<option value="">Select category…</option>' +
      active
        .map((c) => `<option value="${escapeHtml(c.id)}">${escapeHtml(c.label || "—")}</option>`)
        .join("");
    if (cur && [...sel.options].some((o) => o.value === cur)) {
      sel.value = cur;
    }
  }

  async function loadRiders() {
    const snap = await db.collection(COL.riders).limit(200).get(FS_GET_SERVER);
    cache.riders = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    updateAllApprovalBadges();
  }

  async function loadCustomers() {
    const snap = await db.collection(COL.customers).limit(300).get(FS_GET_SERVER);
    cache.customers = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  }

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
    renderDashboardApprovalPreviews();
    renderDashboardRecentOrders();
    updateDashboardQuickActions();
    updateAllApprovalBadges();
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
          <td><strong>${escapeHtml(orderLabel)}</strong></td>
          <td>${escapeHtml(shopDisplayName(o))}</td>
          <td>${fmtMoney(o.total)}</td>
          <td><span class="badge ${badgeClass(stRaw)}${readyAttention}">${escapeHtml(statusLabel(stRaw))}</span></td>
          <td>${escapeHtml(fmtTs(o.createdAt))}</td>
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
      btn.addEventListener("click", () => showView(btn.getAttribute("data-go-nav")));
    });
  }

  function renderOrders() {
    const q = (document.getElementById("filter-orders")?.value || "").toLowerCase();
    const st = document.getElementById("filter-order-status")?.value || "";
    let list = [...cache.orders];
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
    const tbody = document.querySelector("#table-orders tbody");
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="6"><div class="empty-state">No orders.</div></td></tr>`
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
                  ? `<button type="button" class="btn btn-ghost btn-sm" data-assign-rider-order="${escapeHtml(o.id)}">Assign rider</button>`
                  : "";
              return `<tr class="order-row" tabindex="0" data-view-order="${escapeHtml(o.id)}" aria-label="View order details">
          <td><strong>${escapeHtml(orderLabel)}</strong><br/><small>${escapeHtml(fmtTs(o.createdAt))}</small></td>
          <td><strong>${escapeHtml(customerName)}</strong>${customerMeta ? `<br/><small>${escapeHtml(customerMeta)}</small>` : ""}</td>
          <td><strong>${escapeHtml(shopName)}</strong><br/><small>${escapeHtml(orderAddrLine(o))}</small></td>
          <td>${fmtMoney(o.total)}</td>
          <td><span class="badge ${badgeClass(stRaw)}${readyAttention}">${escapeHtml(statusLabel(stRaw))}</span></td>
          <td class="row-actions">
            ${assignBtn}
            <button type="button" class="btn btn-ghost btn-sm" data-edit-order="${escapeHtml(o.id)}">Edit</button>
            <button type="button" class="btn btn-ghost btn-sm" data-del-order="${escapeHtml(o.id)}">Delete</button>
          </td>
        </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-view-order]").forEach((row) => {
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
    tbody.querySelectorAll("[data-assign-rider-order]").forEach((btn) => {
      btn.addEventListener("click", () => {
        openAssignRiderModal(btn.getAttribute("data-assign-rider-order")).catch((e) => alert(e.message || String(e)));
      });
    });
    tbody.querySelectorAll("[data-edit-order]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        try {
          await openOrderEdit(btn.getAttribute("data-edit-order"));
        } catch (e) {
          alert(e.message || String(e));
        }
      });
    });
    tbody.querySelectorAll("[data-del-order]").forEach((btn) => {
      btn.addEventListener("click", () => deleteOrder(btn.getAttribute("data-del-order")));
    });
  }

  function renderVendors() {
    const tbody = document.querySelector("#table-vendors tbody");
    const list = cache.vendors;
    const approvalBadge = (statusRaw) => {
      const s = String(statusRaw || "").toLowerCase();
      if (s === "approved") return `<span class="badge badge-delivered">Approved</span>`;
      if (s === "rejected") return `<span class="badge badge-cancelled">Rejected</span>`;
      if (s === "pending") return `<span class="badge badge-pending">Pending</span>`;
      return `<span class="badge badge-pending">Pending</span>`;
    };
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="6"><div class="empty-state">No vendors.</div></td></tr>`
        : list
            .map((v) => {
              const approval = String(v.approvalStatus || "pending").toLowerCase();
              const isApproved = approval === "approved";
              return `<tr>
        <td>${escapeHtml(v.id)}</td>
        <td>${escapeHtml(v.name || "—")}</td>
        <td>${escapeHtml(v.tag || v.category || "—")}</td>
        <td>${approvalBadge(v.approvalStatus)}</td>
        <td>${v.active === true ? "Yes" : "No"}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-approve-vendor="${escapeHtml(v.id)}" ${isApproved ? "disabled" : ""}>Approve</button>
          <button type="button" class="btn btn-ghost btn-sm" data-reject-vendor="${escapeHtml(v.id)}">Reject</button>
          <button type="button" class="btn btn-ghost btn-sm" data-edit-vendor="${escapeHtml(v.id)}">Edit</button>
          <button type="button" class="btn btn-ghost btn-sm" data-del-vendor="${escapeHtml(v.id)}">Delete</button>
        </td>
      </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-approve-vendor]").forEach((btn) => {
      btn.addEventListener("click", () => approveVendor(btn.getAttribute("data-approve-vendor")));
    });
    tbody.querySelectorAll("[data-reject-vendor]").forEach((btn) => {
      btn.addEventListener("click", () => rejectVendor(btn.getAttribute("data-reject-vendor")));
    });
    tbody.querySelectorAll("[data-edit-vendor]").forEach((btn) => {
      btn.addEventListener("click", () => openVendorModal(btn.getAttribute("data-edit-vendor")));
    });
    tbody.querySelectorAll("[data-del-vendor]").forEach((btn) => {
      btn.addEventListener("click", () => deleteVendor(btn.getAttribute("data-del-vendor")));
    });
  }

  function vendorById(id) {
    if (!id) return null;
    return cache.vendors.find((v) => v.id === id) || null;
  }

  function resolveProductShopName(p) {
    const fromProduct = String(p?.storeName || p?.vendorName || "").trim();
    if (fromProduct) return fromProduct;
    const vendor = vendorById(p?.storeId);
    if (vendor?.name) return vendor.name;
    return p?.storeId ? String(p.storeId) : "—";
  }

  function productShopFilterOptions() {
    const byId = new Map();
    cache.vendors.forEach((v) => {
      if (v.id) byId.set(v.id, v.name || v.id);
    });
    cache.products.forEach((p) => {
      if (p.storeId && !byId.has(p.storeId)) {
        byId.set(p.storeId, resolveProductShopName(p));
      }
    });
    return [...byId.entries()].sort((a, b) =>
      String(a[1]).localeCompare(String(b[1]), undefined, { sensitivity: "base" })
    );
  }

  function populateProductShopFilter() {
    const sel = document.getElementById("filter-product-shop");
    if (!sel) return;
    const options = productShopFilterOptions();
    const optionsKey = options.map(([id]) => id).join("|");
    if (sel.dataset.optionsKey === optionsKey) return;
    sel.dataset.optionsKey = optionsKey;
    const prev = sel.value;
    sel.innerHTML =
      `<option value="">All shops</option>` +
      options
        .map(
          ([id, label]) =>
            `<option value="${escapeHtml(id)}">${escapeHtml(label)}</option>`
        )
        .join("");
    if (prev && options.some(([id]) => id === prev)) sel.value = prev;
  }

  function appendProductThumbEmpty(cell) {
    const span = document.createElement("span");
    span.className = "product-thumb product-thumb--empty";
    span.setAttribute("aria-hidden", "true");
    span.textContent = "—";
    cell.replaceChildren(span);
  }

  function appendProductThumbImage(cell, url) {
    const wrap = document.createElement("div");
    wrap.className = "product-thumb-wrap";
    const img = document.createElement("img");
    img.className = "product-thumb";
    img.alt = "";
    img.decoding = "async";
    img.loading = "eager";
    img.referrerPolicy = "no-referrer";
    const fallback = document.createElement("span");
    fallback.className = "product-thumb product-thumb--empty product-thumb--fallback";
    fallback.setAttribute("aria-hidden", "true");
    fallback.hidden = true;
    fallback.textContent = "—";
    img.addEventListener("error", () => {
      img.remove();
      fallback.hidden = false;
    });
    img.addEventListener("load", () => {
      fallback.hidden = true;
    });
    img.src = url;
    wrap.append(img, fallback);
    cell.replaceChildren(wrap);
  }

  function paintProductTableImages(tbody) {
    tbody.querySelectorAll("[data-product-img]").forEach((cell) => {
      const productId = cell.getAttribute("data-product-img");
      const product = cache.products.find((p) => p.id === productId);
      const url = productDisplayImageUrl(product);
      if (!url) {
        appendProductThumbEmpty(cell);
        return;
      }
      appendProductThumbImage(cell, url);
    });
  }

  function productActiveBadge(active) {
    if (active === true) {
      return `<span class="badge badge-delivered">Active</span>`;
    }
    return `<span class="badge badge-cancelled">Inactive</span>`;
  }

  function renderProducts() {
    const tbody = document.querySelector("#table-products tbody");
    populateProductShopFilter();
    const shopId = document.getElementById("filter-product-shop")?.value || "";
    const q = (document.getElementById("filter-products")?.value || "").toLowerCase().trim();
    let list = [...cache.products];
    if (shopId) list = list.filter((p) => p.storeId === shopId);
    if (q) {
      list = list.filter((p) => {
        const name = String(p.name || "").toLowerCase();
        const shop = resolveProductShopName(p).toLowerCase();
        return name.includes(q) || shop.includes(q);
      });
    }
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="6"><div class="empty-state">No products${shopId || q ? " match your filters" : ""}.</div></td></tr>`
        : list
            .map((p) => {
              const shopName = resolveProductShopName(p);
              return `<tr>
        <td class="cell-product-img" data-product-img="${escapeHtml(p.id)}"></td>
        <td><strong>${escapeHtml(p.name || "—")}</strong></td>
        <td>${escapeHtml(shopName)}</td>
        <td>${fmtMoney(p.price)}</td>
        <td>${productActiveBadge(p.active)}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-edit-product="${escapeHtml(p.id)}">Edit</button>
          <button type="button" class="btn btn-ghost btn-sm" data-del-product="${escapeHtml(p.id)}">Delete</button>
        </td>
      </tr>`;
            })
            .join("");
    paintProductTableImages(tbody);
    tbody.querySelectorAll("[data-edit-product]").forEach((btn) => {
      btn.addEventListener("click", () => openProductModal(btn.getAttribute("data-edit-product")));
    });
    tbody.querySelectorAll("[data-del-product]").forEach((btn) => {
      btn.addEventListener("click", () => deleteProduct(btn.getAttribute("data-del-product")));
    });
  }

  function renderBanners() {
    const tbody = document.querySelector("#table-banners tbody");
    const list = [...cache.banners].sort((a, b) => (Number(a.order) || 0) - (Number(b.order) || 0));
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="5"><div class="empty-state">No banners.</div></td></tr>`
        : list
            .map(
              (b) => `<tr>
        <td>${escapeHtml(b.id)}</td>
        <td>${escapeHtml(b.title || "—")}</td>
        <td>${Number(b.order) || 0}</td>
        <td>${b.active === true ? "Yes" : "No"}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-edit-banner="${escapeHtml(b.id)}">Edit</button>
          <button type="button" class="btn btn-ghost btn-sm" data-del-banner="${escapeHtml(b.id)}">Delete</button>
        </td>
      </tr>`
            )
            .join("");
    tbody.querySelectorAll("[data-edit-banner]").forEach((btn) => {
      btn.addEventListener("click", () => openBannerModal(btn.getAttribute("data-edit-banner")));
    });
    tbody.querySelectorAll("[data-del-banner]").forEach((btn) => {
      btn.addEventListener("click", () => deleteBanner(btn.getAttribute("data-del-banner")));
    });
  }

  function renderShopCategories() {
    const tbody = document.querySelector("#table-shop-categories tbody");
    if (!tbody) return;
    const list = [...cache.shopCategories].sort(
      (a, b) => (Number(a.order) || 0) - (Number(b.order) || 0)
    );
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="4"><div class="empty-state">No categories. Add Food / Grocery first, then shop types.</div></td></tr>`
        : list
            .map((c) => {
              const active = c.active !== false;
              return `<tr>
        <td>${escapeHtml(c.label || "—")}</td>
        <td>${Number(c.order) || 0}</td>
        <td><label style="display:flex;align-items:center;gap:6px;cursor:pointer"><input type="checkbox" data-shop-category-active="${escapeHtml(c.id)}" ${active ? "checked" : ""} /> <span>${active ? "Shown" : "Hidden"}</span></label></td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-del-shop-category="${escapeHtml(c.id)}">Delete</button>
        </td>
      </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-shop-category-active]").forEach((input) => {
      input.addEventListener("change", async (e) => {
        const id = e.target.getAttribute("data-shop-category-active");
        const span = e.target.closest("label")?.querySelector("span");
        try {
          await db.collection(COL.shopCategories).doc(id).update({ active: !!e.target.checked });
          if (span) span.textContent = e.target.checked ? "Shown" : "Hidden";
          await loadShopCategories();
          fillShopTypeCategorySelect();
        } catch (err) {
          alert(err.message || String(err));
          e.target.checked = !e.target.checked;
        }
      });
    });
    tbody.querySelectorAll("[data-del-shop-category]").forEach((btn) => {
      btn.addEventListener("click", () => deleteShopCategory(btn.getAttribute("data-del-shop-category")));
    });
    fillShopTypeCategorySelect();
  }

  function renderShopTypes() {
    const tbody = document.querySelector("#table-shop-types tbody");
    if (!tbody) return;
    fillShopTypeCategorySelect();
    const list = [...cache.shopTypes].sort((a, b) => {
      const ac = shopCategoryLabelById(a.categoryId);
      const bc = shopCategoryLabelById(b.categoryId);
      if (ac !== bc) {
        return ac.localeCompare(bc);
      }
      return (Number(a.order) || 0) - (Number(b.order) || 0);
    });
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="5"><div class="empty-state">No shop types. Choose a category and add labels (e.g. Restaurant).</div></td></tr>`
        : list
            .map((t) => {
              const active = t.active !== false;
              return `<tr>
        <td>${escapeHtml(shopCategoryLabelById(t.categoryId))}</td>
        <td>${escapeHtml(t.label || "—")}</td>
        <td>${Number(t.order) || 0}</td>
        <td><label style="display:flex;align-items:center;gap:6px;cursor:pointer"><input type="checkbox" data-shop-type-active="${escapeHtml(t.id)}" ${active ? "checked" : ""} /> <span>${active ? "Shown" : "Hidden"}</span></label></td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-del-shop-type="${escapeHtml(t.id)}">Delete</button>
        </td>
      </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-shop-type-active]").forEach((input) => {
      input.addEventListener("change", async (e) => {
        const id = e.target.getAttribute("data-shop-type-active");
        const span = e.target.closest("label")?.querySelector("span");
        try {
          await db.collection(COL.shopTypes).doc(id).update({ active: !!e.target.checked });
          if (span) span.textContent = e.target.checked ? "Shown" : "Hidden";
        } catch (err) {
          alert(err.message || String(err));
          e.target.checked = !e.target.checked;
        }
      });
    });
    tbody.querySelectorAll("[data-del-shop-type]").forEach((btn) => {
      btn.addEventListener("click", () => deleteShopType(btn.getAttribute("data-del-shop-type")));
    });
  }

  function renderShopApprovals() {
    const tbody = document.querySelector("#table-shop-approvals tbody");
    if (!tbody) return;
    const pending = cache.vendors.filter((v) => vendorIsPending(v));
    tbody.innerHTML =
      pending.length === 0
        ? `<tr><td colspan="6"><div class="empty-state">No MND Shop stores waiting for approval. New registrations appear here automatically.</div></td></tr>`
        : pending
            .map((v) => {
              const phone = v.phone || v.phoneNumber || "—";
              return `<tr>
        <td><strong>${escapeHtml(v.name || v.id)}</strong><br/><small style="color:var(--muted)"><code>${escapeHtml(v.id)}</code></small></td>
        <td>${escapeHtml(v.city || "—")}</td>
        <td>${escapeHtml(v.category || v.tag || "—")}</td>
        <td>${escapeHtml(phone)}</td>
        <td>${escapeHtml(fmtTs(v.createdAt))}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-primary btn-sm" data-approve-vendor="${escapeHtml(v.id)}">Approve</button>
          <button type="button" class="btn btn-ghost btn-sm" data-reject-vendor="${escapeHtml(v.id)}">Reject</button>
          <button type="button" class="btn btn-ghost btn-sm" data-edit-vendor="${escapeHtml(v.id)}">Edit</button>
        </td>
      </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-approve-vendor]").forEach((btn) => {
      btn.addEventListener("click", () => approveVendor(btn.getAttribute("data-approve-vendor")));
    });
    tbody.querySelectorAll("[data-reject-vendor]").forEach((btn) => {
      btn.addEventListener("click", () => rejectVendor(btn.getAttribute("data-reject-vendor")));
    });
    tbody.querySelectorAll("[data-edit-vendor]").forEach((btn) => {
      btn.addEventListener("click", () => openVendorModal(btn.getAttribute("data-edit-vendor")));
    });
  }

  function renderJobApprovals() {
    const tbody = document.querySelector("#table-job-approvals tbody");
    if (!tbody) return;
    const pending = cache.jobs.filter((j) => String(j.status || "").toLowerCase() === "pending");
    tbody.innerHTML =
      pending.length === 0
        ? `<tr><td colspan="7"><div class="empty-state">No job posts waiting for approval.</div></td></tr>`
        : pending
            .map(
              (j) => `<tr>
        <td><strong>${escapeHtml(j.title || "—")}</strong></td>
        <td>${escapeHtml(j.companyName || "—")}</td>
        <td>${escapeHtml(j.salary || "—")}</td>
        <td>${escapeHtml(j.remote ? "Remote" : j.location || "—")}</td>
        <td>${escapeHtml(j.type || j.category || "—")}</td>
        <td>${escapeHtml(fmtTs(j.createdAt))}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-primary btn-sm" data-approve-job="${escapeHtml(j.id)}">Approve</button>
          <button type="button" class="btn btn-ghost btn-sm" data-reject-job="${escapeHtml(j.id)}">Reject</button>
        </td>
      </tr>`
            )
            .join("");
    tbody.querySelectorAll("[data-approve-job]").forEach((btn) => {
      btn.addEventListener("click", () => approveJob(btn.getAttribute("data-approve-job")));
    });
    tbody.querySelectorAll("[data-reject-job]").forEach((btn) => {
      btn.addEventListener("click", () => rejectJob(btn.getAttribute("data-reject-job")));
    });
  }

  function renderPublishedJobs() {
    const tbody = document.querySelector("#table-jobs-published tbody");
    if (!tbody) return;
    const list = cache.jobs.filter(
      (j) => String(j.status || "").toLowerCase() !== "pending"
    );
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="8"><div class="empty-state">No published jobs yet. Use <strong>+ Add job</strong> above.</div></td></tr>`
        : list
            .map((j) => {
              const n = countJobApplications(j.id);
              const booked = applicationsForJob(j.id).filter(
                (a) => String(a.status || "").toLowerCase() === "booked"
              ).length;
              const applicantLabel =
                n === 0
                  ? "—"
                  : booked > 0
                    ? `${n} <span class="muted-inline">(${booked} booked)</span>`
                    : String(n);
              return `<tr>
        <td><strong>${escapeHtml(j.title || "—")}</strong></td>
        <td>${escapeHtml(j.companyName || "—")}</td>
        <td>${escapeHtml(j.salary || "—")}</td>
        <td>${jobLaborLimit(j)} workers</td>
        <td><span class="badge ${j.status === "active" ? "badge-delivered" : "badge-pending"}">${escapeHtml(j.status || "—")}</span></td>
        <td>${applicantLabel}</td>
        <td>${escapeHtml(fmtTs(j.createdAt))}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-primary btn-sm" data-job-apps="${escapeHtml(j.id)}">Applications${n > 0 ? ` (${n})` : ""}</button>
          <button type="button" class="btn btn-ghost btn-sm" data-edit-job="${escapeHtml(j.id)}">Edit</button>
          <button type="button" class="btn btn-ghost btn-sm" data-del-job="${escapeHtml(j.id)}">Delete</button>
        </td>
      </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-job-apps]").forEach((btn) => {
      btn.addEventListener("click", () => openJobApplicationsModal(btn.getAttribute("data-job-apps")));
    });
    tbody.querySelectorAll("[data-edit-job]").forEach((btn) => {
      btn.addEventListener("click", () => openJobModal(btn.getAttribute("data-edit-job")));
    });
    tbody.querySelectorAll("[data-del-job]").forEach((btn) => {
      btn.addEventListener("click", () => deleteJob(btn.getAttribute("data-del-job")));
    });
  }

  function renderJobApplicationRow(app, jobId) {
    const status = String(app.status || "submitted").toLowerCase();
    const cv = app.cvUrl
      ? `<a href="${escapeHtml(app.cvUrl)}" target="_blank" rel="noopener">CV</a>`
      : "";
    const bio = app.bio ? `<p class="app-bio">${escapeHtml(app.bio)}</p>` : "";
    const slotsOpen = canBookMoreForJob(jobId);
    const actions =
      status === "booked" || status === "rejected"
        ? ""
        : `<div class="row-actions" style="margin-top: 0.5rem; flex-wrap: wrap">
          ${status !== "shortlisted" ? `<button type="button" class="btn btn-ghost btn-sm" data-app-status="shortlisted" data-app-id="${escapeHtml(app.id)}">Shortlist</button>` : ""}
          <button type="button" class="btn btn-primary btn-sm" data-app-status="booked" data-app-id="${escapeHtml(app.id)}" ${slotsOpen ? "" : "disabled"}>${slotsOpen ? "Book" : "Slots full"}</button>
          <button type="button" class="btn btn-ghost btn-sm" data-app-status="rejected" data-app-id="${escapeHtml(app.id)}">Reject</button>
        </div>`;
    return `<div class="job-app-card">
      <div class="job-app-card-head">
        <strong>${escapeHtml(app.applicantName || "—")}</strong>
        ${jobApplicationStatusBadge(status)}
      </div>
      <div class="job-app-meta">
        <span>Phone: <a href="tel:${escapeHtml(String(app.applicantPhone || "").replace(/\s/g, ""))}">${escapeHtml(app.applicantPhone || "—")}</a></span>
        <span>Applied: ${escapeHtml(fmtTs(app.appliedAt))}</span>
        ${app.bookedAt ? `<span>Booked: ${escapeHtml(fmtTs(app.bookedAt))}</span>` : ""}
        ${cv ? `<span>${cv}</span>` : ""}
      </div>
      ${bio}
      ${actions}
    </div>`;
  }

  function jobApplicationsModalHtml(job, apps) {
    const submitted = apps.filter((a) => String(a.status || "").toLowerCase() === "submitted");
    const shortlisted = apps.filter((a) => String(a.status || "").toLowerCase() === "shortlisted");
    const booked = apps.filter((a) => String(a.status || "").toLowerCase() === "booked");
    const rejected = apps.filter((a) => String(a.status || "").toLowerCase() === "rejected");
    const limit = jobLaborLimit(job);
    const slotsLabel = `${booked.length} / ${limit} booked`;
    const row = (list) => list.map((a) => renderJobApplicationRow(a, job.id)).join("");
    const sections = [];
    if (booked.length) {
      sections.push(`<h4 class="app-section-title">Booked (${booked.length})</h4>${row(booked)}`);
    }
    if (shortlisted.length) {
      sections.push(
        `<h4 class="app-section-title">Shortlisted (${shortlisted.length})</h4>${row(shortlisted)}`
      );
    }
    if (submitted.length) {
      sections.push(
        `<h4 class="app-section-title">New applications (${submitted.length})</h4>${row(submitted)}`
      );
    }
    if (rejected.length) {
      sections.push(
        `<h4 class="app-section-title">Rejected (${rejected.length})</h4>${row(rejected)}`
      );
    }
    const body =
      apps.length === 0
        ? `<div class="empty-state">No applications yet for this job.</div>`
        : sections.join("");
    return `<p style="color: var(--muted); margin-top: 0">${escapeHtml(job.companyName || "")} · ${escapeHtml(job.location || "")}</p>
      <p style="margin: 8px 0 12px"><strong>${escapeHtml(slotsLabel)}</strong> · max ${limit} worker${limit === 1 ? "" : "s"}</p>
      <div id="job-apps-modal-list">${body}</div>`;
  }

  async function openJobApplicationsModal(jobId) {
    const job = cache.jobs.find((x) => x.id === jobId);
    if (!job || !db) return;
    try {
      const snap = await db
        .collection(COL.jobApplications)
        .where("jobId", "==", jobId)
        .orderBy("appliedAt", "desc")
        .get(FS_GET_SERVER);
      const fresh = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.jobApplications = cache.jobApplications
        .filter((a) => String(a.jobId || "") !== String(jobId))
        .concat(fresh);
    } catch (_) {
      const snap = await db
        .collection(COL.jobApplications)
        .where("jobId", "==", jobId)
        .get(FS_GET_SERVER);
      const fresh = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.jobApplications = cache.jobApplications
        .filter((a) => String(a.jobId || "") !== String(jobId))
        .concat(fresh);
    }
    const apps = applicationsForJob(jobId);
    openModal(
      `Applications — ${job.title || "Job"}`,
      jobApplicationsModalHtml(job, apps),
      "job-applications",
      jobId
    );
    modalSave.style.display = "none";
  }

  async function refreshJobApplicationsModal(jobId) {
    if (!jobId || modalMode !== "job-applications" || modalEditId !== jobId) return;
    const job = cache.jobs.find((x) => x.id === jobId);
    if (!job) return;
    const apps = applicationsForJob(jobId);
    modalBody.innerHTML = jobApplicationsModalHtml(job, apps);
    modalSave.style.display = "none";
  }

  async function updateJobApplicationStatus(applicationId, status) {
    if (!applicationId || !status || !db) return;
    if (status === "booked") {
      const appDoc = await db.collection(COL.jobApplications).doc(applicationId).get(FS_GET_SERVER);
      if (!appDoc.exists) throw new Error("Application not found.");
      const app = appDoc.data();
      const current = String(app.status || "").toLowerCase();
      if (current !== "booked") {
        const jobId = app.jobId;
        const job = cache.jobs.find((x) => x.id === jobId);
        if (!job) {
          const jobSnap = await db.collection(COL.jobs).doc(jobId).get(FS_GET_SERVER);
          if (!jobSnap.exists) throw new Error("Job not found.");
          const limit = jobLaborLimit(jobSnap.data());
          const booked = countBookedForJob(jobId);
          if (booked >= limit) {
            throw new Error(`All ${limit} worker slot${limit === 1 ? "" : "s"} are already booked.`);
          }
        } else {
          const limit = jobLaborLimit(job);
          const booked = countBookedForJob(jobId);
          if (booked >= limit) {
            throw new Error(`All ${limit} worker slot${limit === 1 ? "" : "s"} are already booked.`);
          }
        }
      }
    }
    const patch = {
      status,
      updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    };
    if (status === "booked") {
      patch.bookedAt = firebase.firestore.FieldValue.serverTimestamp();
    }
    await db.collection(COL.jobApplications).doc(applicationId).update(patch);
    const idx = cache.jobApplications.findIndex((a) => a.id === applicationId);
    if (idx >= 0) {
      cache.jobApplications[idx] = { ...cache.jobApplications[idx], status };
      if (status === "booked") {
        cache.jobApplications[idx].bookedAt = { seconds: Math.floor(Date.now() / 1000) };
      }
    }
  }

  function jobCategoryOptions(selected) {
    const sel = String(selected || "");
    return JOB_CATEGORIES.map(
      (c) =>
        `<option value="${escapeHtml(c)}" ${sel === c ? "selected" : ""}>${escapeHtml(c)}</option>`
    ).join("");
  }

  function jobTypeOptions(selected) {
    const sel = String(selected || "");
    return JOB_TYPES.map(
      (t) =>
        `<option value="${escapeHtml(t)}" ${sel === t ? "selected" : ""}>${escapeHtml(t)}</option>`
    ).join("");
  }

  function openJobModal(id) {
    const j = id ? cache.jobs.find((x) => x.id === id) : null;
    const status = j ? String(j.status || "active").toLowerCase() : "active";
    openModal(
      id ? "Edit job" : "Add job",
      `<div class="form-group"><label>Job title *</label><input type="text" id="f-j-title" maxlength="120" value="${escapeHtml(j?.title || "")}" required></div>
      <div class="form-group"><label>Company / employer *</label><input type="text" id="f-j-company" value="${escapeHtml(j?.companyName || "")}" required></div>
      <div class="form-group"><label>Salary / rate *</label><input type="text" id="f-j-salary" placeholder="e.g. LKR 25,000 / month" value="${escapeHtml(j?.salary || "")}" required></div>
      <div class="form-group"><label>Workers needed *</label><input type="number" id="f-j-labor" min="1" max="99" value="${jobLaborLimit(j)}" required><small style="color:var(--muted)">Max applicants you can book for this job</small></div>
      <div class="form-group"><label>Category</label><select id="f-j-cat">${jobCategoryOptions(j?.category)}</select></div>
      <div class="form-group"><label>Job type</label><select id="f-j-type">${jobTypeOptions(j?.type)}</select></div>
      <div class="form-group"><label>Location *</label><input type="text" id="f-j-loc" value="${escapeHtml(j?.location || "")}" required></div>
      <div class="form-group"><label>Description * (min 10 chars)</label><textarea id="f-j-desc" rows="4" required>${escapeHtml(j?.description || "")}</textarea></div>
      <div class="form-group"><label>Contact phone *</label><input type="text" id="f-j-phone" value="${escapeHtml(j?.contactPhone || "")}" required></div>
      <div class="form-group"><label>WhatsApp (optional)</label><input type="text" id="f-j-wa" value="${escapeHtml(j?.whatsapp || "")}"></div>
      <div class="form-group"><label><input type="checkbox" id="f-j-remote" ${j?.remote ? "checked" : ""} /> Remote job</label></div>
      <div class="form-group"><label><input type="checkbox" id="f-j-urgent" ${j?.urgent ? "checked" : ""} /> Urgent hiring</label></div>
      <div class="form-group"><label><input type="checkbox" id="f-j-verified" ${j?.verified !== false ? "checked" : ""} /> Verified employer badge</label></div>
      <div class="form-group"><label>Publish as</label><select id="f-j-status">
        <option value="active" ${status === "active" ? "selected" : ""}>Active (live in app)</option>
        <option value="pending" ${status === "pending" ? "selected" : ""}>Pending (needs approval)</option>
      </select></div>`,
      "job",
      id || null
    );
    modalSave.style.display = "inline-flex";
  }

  function renderRiderApprovals() {
    const tbody = document.querySelector("#table-rider-approvals tbody");
    if (!tbody) {
      return;
    }
    const pending = cache.riders.filter((r) => riderRegistrationStatus(r) === "pending");
    tbody.innerHTML =
      pending.length === 0
        ? `<tr><td colspan="8"><div class="empty-state">No riders waiting for approval.</div></td></tr>`
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
              return `<tr class="rider-row" tabindex="0" data-view-rider="${escapeHtml(r.id)}" aria-label="View rider details">
        <td>${escapeHtml(riderDisplayName(r))}</td>
        <td>${escapeHtml(r.phone || r.phoneNumber || "—")}</td>
        <td>${escapeHtml(r.nicNumber || "—")}</td>
        <td>${escapeHtml(r.city || r.address || "—")}</td>
        <td>${escapeHtml(riderVehicleLabel(r))}</td>
        <td>${docsHtml}</td>
        <td>${escapeHtml(fmtTs(r.createdAt))}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-primary btn-sm" data-approve-rider="${escapeHtml(r.id)}">Approve</button>
          <button type="button" class="btn btn-ghost btn-sm" data-reject-rider="${escapeHtml(r.id)}">Reject</button>
        </td>
      </tr>`;
            })
            .join("");
    bindRiderRowOpen(tbody);
    tbody.querySelectorAll("[data-approve-rider]").forEach((btn) => {
      btn.addEventListener("click", () => approveRider(btn.getAttribute("data-approve-rider")));
    });
    tbody.querySelectorAll("[data-reject-rider]").forEach((btn) => {
      btn.addEventListener("click", () => rejectRider(btn.getAttribute("data-reject-rider")));
    });
  }

  function renderRiders() {
    const tbody = document.querySelector("#table-riders tbody");
    const list = cache.riders;
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="7"><div class="empty-state">No riders.</div></td></tr>`
        : list
            .map((r) => {
              const name = riderDisplayName(r);
              const phone = r.phoneNumber || r.phone || "—";
              const approval = riderRegistrationStatus(r);
              const isApproved = approval === "approved" || approval === "active";
              return `<tr class="rider-row" tabindex="0" data-view-rider="${escapeHtml(r.id)}" aria-label="View rider details">
        <td>${escapeHtml(r.id)}</td>
        <td>${escapeHtml(name)}</td>
        <td>${escapeHtml(phone)}</td>
        <td>${escapeHtml(riderVehicleLabel(r))}</td>
        <td>${riderStatusBadge(r.status)}</td>
        <td>${r.online === true ? "Yes" : "No"}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-approve-rider="${escapeHtml(r.id)}" ${isApproved ? "disabled" : ""}>Approve</button>
          <button type="button" class="btn btn-ghost btn-sm" data-reject-rider="${escapeHtml(r.id)}">Reject</button>
          <button type="button" class="btn btn-ghost btn-sm" data-edit-rider="${escapeHtml(r.id)}">Edit</button>
          <button type="button" class="btn btn-ghost btn-sm" data-del-rider="${escapeHtml(r.id)}">Delete</button>
        </td>
      </tr>`;
            })
            .join("");
    bindRiderRowOpen(tbody);
    tbody.querySelectorAll("[data-approve-rider]").forEach((btn) => {
      btn.addEventListener("click", () => approveRider(btn.getAttribute("data-approve-rider")));
    });
    tbody.querySelectorAll("[data-reject-rider]").forEach((btn) => {
      btn.addEventListener("click", () => rejectRider(btn.getAttribute("data-reject-rider")));
    });
    tbody.querySelectorAll("[data-edit-rider]").forEach((btn) => {
      btn.addEventListener("click", () => openRiderModal(btn.getAttribute("data-edit-rider")));
    });
    tbody.querySelectorAll("[data-del-rider]").forEach((btn) => {
      btn.addEventListener("click", () => deleteRider(btn.getAttribute("data-del-rider")));
    });
  }

  function renderCustomers() {
    const tbody = document.querySelector("#table-customers tbody");
    const q = (document.getElementById("filter-customers")?.value || "").trim().toLowerCase();
    const roleFilter = (document.getElementById("filter-customer-role")?.value || "").trim().toLowerCase();
    const all = [...cache.customers].sort((a, b) => {
      const ta = a.createdAt?.seconds || 0;
      const tb = b.createdAt?.seconds || 0;
      if (ta !== tb) return tb - ta;
      return customerDisplayName(a).localeCompare(customerDisplayName(b));
    });
    const total = all.length;
    const customerN = all.filter((u) => customerRole(u) === "customer").length;
    const staffN = all.filter((u) => ["vendor", "admin"].includes(customerRole(u))).length;
    const phoneN = all.filter((u) => customerPhone(u)).length;
    const setText = (id, value) => {
      const el = document.getElementById(id);
      if (el) el.textContent = String(value);
    };
    setText("customer-stat-total", total);
    setText("customer-stat-customers", customerN);
    setText("customer-stat-staff", staffN);
    setText("customer-stat-phone", phoneN);

    let list = all;
    if (roleFilter) list = list.filter((u) => customerRole(u) === roleFilter);
    if (q) {
      list = list.filter((u) => {
        const hay = [
          customerDisplayName(u),
          customerPhone(u),
          customerEmail(u),
          customerRole(u),
          u.id,
          u.uid,
        ]
          .join(" ")
          .toLowerCase();
        return hay.includes(q);
      });
    }
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="5"><div class="empty-state">No customer profiles.</div></td></tr>`
        : list
            .map(
              (u) => `<tr>
        <td>
          <div class="customer-cell">
            <div class="customer-avatar">${escapeHtml(customerInitials(u))}</div>
            <div>
              <strong>${escapeHtml(customerDisplayName(u))}</strong>
              <small>${escapeHtml(customerOrderCount(u.id))} orders loaded</small>
            </div>
          </div>
        </td>
        <td>
          <div class="customer-contact">
            <strong>${escapeHtml(customerPhone(u) || "No phone")}</strong>
            <small>${escapeHtml(customerEmail(u) || "No email")}</small>
          </div>
        </td>
        <td>${customerRoleBadge(u.role)}</td>
        <td>${escapeHtml(fmtTs(u.createdAt))}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-view-customer="${escapeHtml(u.id)}">View</button>
          <button type="button" class="btn btn-ghost btn-sm" data-del-customer="${escapeHtml(u.id)}">Delete</button>
        </td>
      </tr>`
            )
            .join("");
    tbody.querySelectorAll("[data-view-customer]").forEach((btn) => {
      btn.addEventListener("click", () => openCustomerView(btn.getAttribute("data-view-customer")));
    });
    tbody.querySelectorAll("[data-del-customer]").forEach((btn) => {
      btn.addEventListener("click", () => deleteCustomer(btn.getAttribute("data-del-customer")));
    });
  }

  function openCustomerView(uid) {
    const u = cache.customers.find((x) => x.id === uid);
    if (!u) return;
    const name = customerDisplayName(u);
    const phone = customerPhone(u);
    const email = customerEmail(u);
    const role = customerRole(u);
    const allOrders = cache.orders.filter((o) => String(o.customerId || "").trim() === uid);
    const orders = allOrders.slice(0, 6);
    const deliveredOrders = allOrders.filter((o) => ["delivered", "completed"].includes(String(o.status || "").toLowerCase()));
    const spent = deliveredOrders.reduce((sum, o) => sum + (Number(o.total) || 0), 0);
    const lastOrder = allOrders[0];
    const recentOrders =
      orders.length === 0
        ? `<div class="customer-profile-empty">No orders loaded for this customer yet.</div>`
        : orders
            .map(
              (o) => `<div class="customer-timeline-item">
                <div class="customer-timeline-dot"></div>
                <div class="customer-timeline-card">
                  <div>
                    <strong>${escapeHtml(orderDisplayNumber(o))}</strong>
                    <small>${escapeHtml(shopDisplayName(o))} · ${escapeHtml(fmtTs(o.createdAt))}</small>
                  </div>
                  <div class="customer-timeline-meta">
                    <span class="badge ${badgeClass(o.status)}">${escapeHtml(statusLabel(o.status))}</span>
                    <strong>${fmtMoney(o.total)}</strong>
                  </div>
                </div>
              </div>`
            )
            .join("");
    const json = JSON.stringify(u, null, 2);
    openModal(
      "Customer profile",
      `<div class="customer-profile">
        <div class="customer-profile-cover">
          <div class="customer-profile-cover__main">
            ${customerAvatarHtml(u, "customer-avatar--xl")}
            <div>
              <div class="customer-profile-role">${customerRoleBadge(role)}</div>
              <h4>${escapeHtml(name)}</h4>
              <p>${escapeHtml(email || "No email")} ${phone ? `· ${escapeHtml(phone)}` : ""}</p>
            </div>
          </div>
          <div class="customer-profile-cover__stat">
            <span>Total spent</span>
            <strong>${fmtMoney(spent)}</strong>
          </div>
        </div>

        <div class="customer-profile-metrics">
          <div><span>Loaded orders</span><strong>${escapeHtml(String(allOrders.length))}</strong></div>
          <div><span>Delivered</span><strong>${escapeHtml(String(deliveredOrders.length))}</strong></div>
          <div><span>Last order</span><strong>${escapeHtml(lastOrder ? fmtTs(lastOrder.createdAt) : "—")}</strong></div>
        </div>

        <div class="customer-profile-page">
          <div class="customer-profile-main">
            <section class="customer-profile-section customer-profile-section--contact">
              <h5>Contact</h5>
              <div class="customer-contact-grid">
                <div class="customer-contact-card">
                  <span>Phone</span>
                  <strong>${escapeHtml(phone || "Not added")}</strong>
                </div>
                <div class="customer-contact-card">
                  <span>Email</span>
                  <strong>${escapeHtml(email || "Not added")}</strong>
                </div>
              </div>
            </section>

            <section class="customer-profile-section">
              <h5>Recent activity</h5>
              <div class="customer-timeline">${recentOrders}</div>
            </section>
          </div>

          <aside class="customer-profile-side">
            <section class="customer-profile-section">
              <h5>Account</h5>
              ${orderDetailLine("Role", role)}
              ${orderDetailLine("Joined", fmtTs(u.createdAt))}
              ${orderDetailLine("Updated", fmtTs(u.updatedAt))}
              ${orderDetailLine("Profile ID", u.id)}
            </section>

            <section class="customer-profile-section">
              <h5>Operations note</h5>
              <p class="customer-profile-note">Admin can read or delete this profile document. Profile edits stay owner-only in Firestore rules.</p>
            </section>
          </aside>
        </div>

        <details class="customer-profile-raw">
          <summary>Technical profile data</summary>
          <pre>${escapeHtml(json)}</pre>
        </details>
      </div>`,
      "customer-profile",
      null
    );
    modalSave.style.display = "none";
  }

  function openOrderDetails(id) {
    const o = cache.orders.find((x) => x.id === id);
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
          ${orderDetailLine("Rider", riderLabel)}
          ${orderDetailLine("Payment", paymentMethodLabel(o.paymentMethod))}
        </div>

        <div class="order-detail-status">
          <span>${escapeHtml(itemCount ? `${itemCount} item${itemCount === 1 ? "" : "s"}` : "Items not recorded")}</span>
          <span>${escapeHtml(fulfillment)}</span>
        </div>
        <span class="badge ${badgeClass(o.status)}">${escapeHtml(statusLabel(o.status || "placed"))}</span>

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
    const o = cache.orders.find((x) => x.id === id);
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

  function openVendorModal(id) {
    const v = id ? cache.vendors.find((x) => x.id === id) : null;
    let lat = "";
    let lng = "";
    if (v && v.location && typeof v.location.latitude === "number") {
      lat = v.location.latitude;
      lng = v.location.longitude;
    } else if (v) {
      lat = v.latitude != null ? v.latitude : "";
      lng = v.longitude != null ? v.longitude : "";
    }
    openModal(
      id ? "Edit vendor" : "New vendor",
      `<div class="form-group"><label>Name</label><input type="text" id="f-v-name" value="${escapeHtml(v?.name || "")}" required></div>
      <div class="form-group"><label>Tag / category</label><input type="text" id="f-v-tag" value="${escapeHtml(v?.tag || v?.category || "")}"></div>
      <div class="form-group"><label>ETA text</label><input type="text" id="f-v-eta" value="${escapeHtml(v?.eta || "")}"></div>
      <div class="form-group"><label>Rating</label><input type="number" id="f-v-rat" step="0.1" min="0" value="${Number(v?.rating) || 0}"></div>
      <div class="form-group"><label>Image URL</label><input type="text" id="f-v-img" value="${escapeHtml(v?.imageUrl || "")}"></div>
      <div class="form-group"><label>Delivery fee (LKR number)</label><input type="number" id="f-v-fee" min="0" step="1" value="${typeof v?.deliveryFee === "number" ? v.deliveryFee : parseInt(String(v?.deliveryFee || "").replace(/\D/g, ""), 10) || 0}"></div>
      <div class="form-group"><label>Latitude (optional)</label><input type="text" id="f-v-lat" value="${lat}"></div>
      <div class="form-group"><label>Longitude (optional)</label><input type="text" id="f-v-lng" value="${lng}"></div>
      <div class="form-group"><label>Active</label><select id="f-v-act"><option value="true">Yes</option><option value="false" ${v && v.active === false ? "selected" : ""}>No</option></select></div>`,
      "vendor",
      id || null
    );
    modalSave.style.display = "inline-flex";
  }

  function openProductModal(id) {
    const p = id ? cache.products.find((x) => x.id === id) : null;
    const imgVal = p ? escapeHtml(productDisplayImageUrl(p)) : "";
    const imgPreview = imgVal
      ? `<div class="form-group"><label>Preview</label><img src="${imgVal}" alt="" class="product-thumb" style="width:96px;height:96px"></div>`
      : "";
    openModal(
      id ? "Edit product" : "New product",
      `<div class="form-group"><label>Name</label><input type="text" id="f-p-name" value="${escapeHtml(p?.name || "")}" required></div>
      <div class="form-group"><label>Store ID (vendor)</label><input type="text" id="f-p-sid" value="${escapeHtml(p?.storeId || "")}" required></div>
      <div class="form-group"><label>Store name</label><input type="text" id="f-p-sn" value="${escapeHtml(p?.storeName || p?.vendorName || "")}"></div>
      <div class="form-group"><label>Lookup key</label><input type="text" id="f-p-lk" value="${escapeHtml(p?.lookupKey || "")}" placeholder="auto: doc id if empty"></div>
      <div class="form-group"><label>Price (LKR)</label><input type="number" id="f-p-price" min="0" step="1" value="${Number(p?.price) || 0}"></div>
      ${imgPreview}
      <div class="form-group"><label>Image URL</label><input type="text" id="f-p-img" value="${imgVal}" placeholder="https://… or upload photo in mnd_shop app"></div>
      <div class="form-group"><label>Active</label><select id="f-p-act"><option value="true">Yes</option><option value="false" ${p && p.active === false ? "selected" : ""}>No</option></select></div>`,
      "product",
      id || null
    );
    modalSave.style.display = "inline-flex";
  }

  function openBannerModal(id) {
    const b = id ? cache.banners.find((x) => x.id === id) : null;
    const sc = colorToHexInput(b?.startColor);
    const ec = colorToHexInput(b?.endColor);
    openModal(
      id ? "Edit banner" : "New banner",
      `<div class="form-group"><label>Title</label><input type="text" id="f-b-t" value="${escapeHtml(b?.title || "")}"></div>
      <div class="form-group"><label>Subtitle</label><input type="text" id="f-b-s" value="${escapeHtml(b?.subtitle || "")}"></div>
      <div class="form-group"><label>Start color (#RRGGBB)</label><input type="text" id="f-b-sc" value="${escapeHtml(sc)}" placeholder="2563EB"></div>
      <div class="form-group"><label>End color (#RRGGBB)</label><input type="text" id="f-b-ec" value="${escapeHtml(ec)}" placeholder="1D4ED8"></div>
      <div class="form-group"><label>Icon key</label><input type="text" id="f-b-ik" value="${escapeHtml(b?.iconKey || "delivery")}"></div>
      <div class="form-group"><label>Sort order</label><input type="number" id="f-b-o" value="${Number(b?.order) || 0}"></div>
      <div class="form-group"><label>Active</label><select id="f-b-a"><option value="true">Yes</option><option value="false" ${b && b.active === false ? "selected" : ""}>No</option></select></div>`,
      "banner",
      id || null
    );
    modalSave.style.display = "inline-flex";
  }

  function colorToHexInput(val) {
    if (val == null) return "";
    if (typeof val === "number") {
      const hex = (val & 0xffffff).toString(16).padStart(6, "0");
      return hex.toUpperCase();
    }
    const s = String(val).replace(/^#/, "").trim();
    return s.length === 6 ? s.toUpperCase() : "";
  }

  function openRiderDetailView(id) {
    const r = cache.riders.find((x) => x.id === id);
    if (!r) return;

    const name = riderDisplayName(r);
    const phone = compactText(r.phone, r.phoneNumber);
    const extraPhone = compactText(r.extraPhone);
    const email = compactText(r.email);
    const address = compactText(r.address, r.city);
    const approval = riderRegistrationStatus(r);
    const isApproved = approval === "approved" || approval === "active";
    const isRejected = approval === "rejected";
    const license = riderLicense(r);
    const insurance = riderInsurance(r);
    const revenue = riderRevenueLicence(r);
    const ownership = riderOwnership(r);
    const vehicle = riderVehicleInfo(r);
    const location = readLatLng(r);
    const locationLabel = location
      ? `${location.lat.toFixed(5)}, ${location.lng.toFixed(5)}`
      : "—";
    const regComplete = r.registrationComplete === true ? "Yes" : "No";
    const ownerBlock = ownership.isOwner === false
      ? `${orderDetailLine("Owner name", ownership.ownerName || "—")}
              ${orderDetailLine("Owner contact", ownership.ownerContact || "—")}`
      : orderDetailLine("Vehicle owner", "Registered rider");
    const rejectionNote = compactText(r.rejectionNote);
    const json = JSON.stringify(r, null, 2);

    openModal(
      "Rider profile",
      `<div class="rider-profile customer-profile">
        <div class="customer-profile-cover rider-profile-cover">
          <div class="customer-profile-cover__main">
            ${riderAvatarHtml(r, "rider-avatar--xl")}
            <div>
              <div class="customer-profile-role">${riderStatusBadge(r.status)} ${r.online === true ? '<span class="badge badge-out">Online</span>' : '<span class="badge badge-pending">Offline</span>'}</div>
              <h4>${escapeHtml(name)}</h4>
              <p>${escapeHtml(phone || "No phone")}${extraPhone ? ` · ${escapeHtml(extraPhone)}` : ""}</p>
            </div>
          </div>
          <div class="customer-profile-cover__stat">
            <span>Vehicle</span>
            <strong>${escapeHtml(riderVehicleTypeLabel(r.vehicleType))}</strong>
          </div>
        </div>

        <div class="rider-profile-actions">
          <button type="button" class="btn btn-primary btn-sm" data-detail-approve-rider="${escapeHtml(r.id)}" ${isApproved ? "disabled" : ""}>Approve</button>
          <button type="button" class="btn btn-ghost btn-sm" data-detail-reject-rider="${escapeHtml(r.id)}" ${isRejected ? "disabled" : ""}>Reject</button>
          <button type="button" class="btn btn-ghost btn-sm" data-detail-edit-rider="${escapeHtml(r.id)}">Edit</button>
        </div>

        <div class="customer-profile-metrics">
          <div><span>Registration</span><strong>${escapeHtml(regComplete)}</strong></div>
          <div><span>Services</span><strong class="rider-service-tags">${riderServicesHtml(r)}</strong></div>
          <div><span>Registered</span><strong>${escapeHtml(fmtTs(r.createdAt))}</strong></div>
        </div>

        ${rejectionNote ? `<p class="rider-profile-note rider-profile-note--warn">Rejection note: ${escapeHtml(rejectionNote)}</p>` : ""}

        <div class="customer-profile-page">
          <div class="customer-profile-main">
            <section class="customer-profile-section">
              <h5>Personal details</h5>
              ${orderDetailLine("Full name", name)}
              ${orderDetailLine("Phone", phone || "—")}
              ${extraPhone ? orderDetailLine("Extra phone", extraPhone) : ""}
              ${orderDetailLine("NIC", r.nicNumber || "—")}
              ${orderDetailLine("Email", email || "—")}
              ${orderDetailLine("Address", address || "—")}
              ${orderDetailLine("Language", riderLanguageLabel(r.preferredLanguage))}
            </section>

            <section class="customer-profile-section">
              <h5>Vehicle</h5>
              ${orderDetailLine("Type", riderVehicleTypeLabel(r.vehicleType))}
              ${orderDetailLine("Number plate", r.vehicleNumber || "—")}
              ${orderDetailLine("Brand", vehicle.brand || "—")}
              ${orderDetailLine("Model", vehicle.model || "—")}
              ${orderDetailLine("Color", vehicle.color || "—")}
              ${orderDetailLine("Year", vehicle.yearMade != null ? String(vehicle.yearMade) : "—")}
            </section>

            <section class="customer-profile-section">
              <h5>License & compliance</h5>
              ${orderDetailLine("License number", license.number || "—")}
              ${orderDetailLine("License expiry", fmtDate(license.expiry))}
              ${orderDetailLine("Insurance expiry", fmtDate(insurance.expiry))}
              ${orderDetailLine("Revenue licence expiry", fmtDate(revenue.expiry))}
              <div class="rider-doc-links">
                ${riderDocLink(license.frontUrl || r.licensePhotoUrl, "License (front)")}
                ${license.backUrl ? " · " + riderDocLink(license.backUrl, "License (back)") : ""}
                ${insurance.photoUrl ? " · " + riderDocLink(insurance.photoUrl, "Insurance") : ""}
                ${revenue.photoUrl ? " · " + riderDocLink(revenue.photoUrl, "Revenue licence") : ""}
              </div>
            </section>

            <section class="customer-profile-section">
              <h5>Identity documents</h5>
              ${riderIdentityDocsHtml(r)}
            </section>

            <section class="customer-profile-section">
              <h5>Vehicle photos</h5>
              ${riderVehiclePhotosHtml(r)}
            </section>
          </div>

          <aside class="customer-profile-side">
            <section class="customer-profile-section">
              <h5>Ownership</h5>
              ${ownerBlock}
            </section>

            <section class="customer-profile-section">
              <h5>Account</h5>
              ${orderDetailLine("Rider ID", r.id)}
              ${orderDetailLine("UID", r.uid || r.id)}
              ${orderDetailLine("Status", approval)}
              ${orderDetailLine("Online", r.online === true ? "Yes" : "No")}
              ${orderDetailLine("Approved", fmtTs(r.approvedAt))}
              ${orderDetailLine("Updated", fmtTs(r.updatedAt))}
              ${orderDetailLine("Location", locationLabel)}
            </section>

            <section class="customer-profile-section">
              <h5>Operations note</h5>
              <p class="customer-profile-note">Riders register through the MND Rider app. Approve to allow deliveries; profile edits from the app stay owner-only in Firestore rules.</p>
            </section>
          </aside>
        </div>

        <details class="customer-profile-raw">
          <summary>Technical profile data</summary>
          <pre>${escapeHtml(json)}</pre>
        </details>
      </div>`,
      "rider-profile",
      id
    );
    modalSave.style.display = "none";
  }

  function openRiderModal(id) {
    const r = id ? cache.riders.find((x) => x.id === id) : null;
    const name = r?.fullName || r?.displayName || r?.name || "";
    const phone = r?.phoneNumber || r?.phone || "";
    openModal(
      id ? "Edit rider" : "New rider",
      `<div class="form-group"><label>Name</label><input type="text" id="f-r-name" value="${escapeHtml(name)}"></div>
      <div class="form-group"><label>Phone</label><input type="text" id="f-r-phone" value="${escapeHtml(phone)}"></div>
      <div class="form-group"><label>Vehicle</label><input type="text" id="f-r-veh" value="${escapeHtml(r?.vehicle || r?.vehicleType || "Bike")}"></div>
      <div class="form-group"><label>Latitude (optional)</label><input type="text" id="f-r-lat" value="${r?.latitude != null ? r.latitude : ""}"></div>
      <div class="form-group"><label>Longitude (optional)</label><input type="text" id="f-r-lng" value="${r?.longitude != null ? r.longitude : ""}"></div>`,
      "rider",
      id || null
    );
    modalSave.style.display = "inline-flex";
  }

  modalSave.addEventListener("click", async () => {
    if (modalMode === "readonly") {
      closeModal();
      modalSave.style.display = "inline-flex";
      return;
    }
    modalSave.disabled = true;
    try {
      await handleModalSave();
      closeModal();
      modalSave.style.display = "inline-flex";
      await loadViewData(currentView);
      if (currentView !== "dashboard") await loadOrders();
      if (currentView !== "dashboard") renderDashboard();
    } catch (e) {
      alert(e.message || String(e));
    } finally {
      modalSave.disabled = false;
    }
  });

  async function handleModalSave() {
    if (modalMode === "assign-rider") return;
    if (modalMode === "order-edit" && modalEditId) {
      const status = document.getElementById("f-ord-status").value;
      const riderEl = document.getElementById("f-ord-rider");
      const riderRaw = riderEl ? riderEl.value.trim() : "";
      const sub = Number(document.getElementById("f-ord-sub").value) || 0;
      const disc = Number(document.getElementById("f-ord-disc").value) || 0;
      const orderCommission = Number(document.getElementById("f-ord-commission")?.value) || 0;
      const baseFee = Number(document.getElementById("f-ord-base-fee")?.value) || 0;
      const riderFee = Number(document.getElementById("f-ord-rider-fee")?.value) || 0;
      const fee = Number(document.getElementById("f-ord-fee").value) || 0;
      const total = Number(document.getElementById("f-ord-total").value) || 0;
      const ref = db.collection(COL.orders).doc(modalEditId);
      const patch = {
        status,
        subtotal: sub,
        discount: disc,
        orderCommissionLkr: orderCommission,
        baseDeliveryFeeLkr: baseFee,
        riderCommissionLkr: riderFee,
        deliveryFee: fee,
        total,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      };
      if (riderRaw) patch.riderId = riderRaw;
      else patch.riderId = firebase.firestore.FieldValue.delete();
      await ref.update(patch);
    }
    if (modalMode === "order-create") {
      const customerId = document.getElementById("f-no-cust").value.trim();
      const vendorId = document.getElementById("f-no-vend").value.trim();
      const storeName = document.getElementById("f-no-store").value.trim();
      const status = document.getElementById("f-no-status").value;
      const total = Number(document.getElementById("f-no-total").value) || 0;
      const line1 = document.getElementById("f-no-l1").value.trim();
      const city = document.getElementById("f-no-city").value.trim();
      const phone = document.getElementById("f-no-phone").value.trim();
      if (!customerId || !vendorId || !storeName || total < 1 || !line1 || !city || phone.length < 8) {
        throw new Error("Fill all required fields (phone min 8 chars).");
      }
      const payload = {
        customerId,
        vendorId,
        vendorStoreId: vendorId,
        storeName,
        status,
        paymentMethod: "cashOnDelivery",
        fulfillmentMode: "delivery",
        items: [
          {
            productKey: "manual",
            productName: "Manual order",
            storeId: vendorId,
            storeName,
            imageUrl: "",
            selectedSize: "",
            quantity: 1,
            basePrice: total,
            sizePriceDelta: 0,
            extras: [],
            unitPrice: total,
            lineTotal: total,
          },
        ],
        subtotal: total,
        discount: 0,
        orderCommissionLkr: 0,
        baseDeliveryFeeLkr: 0,
        riderCommissionLkr: 0,
        deliveryFee: 0,
        total,
        deliveryAddress: { line1, line2: "", city, phone },
        deliveryNote: "",
        specialInstructions: "",
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      };
      await db.collection(COL.orders).add(payload);
    }
    if (modalMode === "vendor") {
      const name = document.getElementById("f-v-name").value.trim();
      const tag = document.getElementById("f-v-tag").value.trim();
      const eta = document.getElementById("f-v-eta").value.trim();
      const rating = Number(document.getElementById("f-v-rat").value) || 0;
      const imageUrl = document.getElementById("f-v-img").value.trim();
      const fee = Number(document.getElementById("f-v-fee").value) || 0;
      const latStr = document.getElementById("f-v-lat").value.trim();
      const lngStr = document.getElementById("f-v-lng").value.trim();
      const active = document.getElementById("f-v-act").value === "true";
      if (!name) throw new Error("Vendor name required.");
      const data = {
        name,
        tag: tag || "General",
        category: tag || "General",
        eta: eta || "N/A",
        rating,
        imageUrl,
        deliveryFee: fee,
        active,
      };
      const lat = parseFloat(latStr);
      const lng = parseFloat(lngStr);
      if (!Number.isNaN(lat) && !Number.isNaN(lng)) {
        data.location = new firebase.firestore.GeoPoint(lat, lng);
      }
      if (modalEditId) await db.collection(COL.vendors).doc(modalEditId).set(data, { merge: true });
      else await db.collection(COL.vendors).doc().set(data);
    }
    if (modalMode === "product") {
      const name = document.getElementById("f-p-name").value.trim();
      const storeId = document.getElementById("f-p-sid").value.trim();
      const storeName = document.getElementById("f-p-sn").value.trim();
      let lookupKey = document.getElementById("f-p-lk").value.trim().toLowerCase();
      const price = Number(document.getElementById("f-p-price").value) || 0;
      const imageUrl = document.getElementById("f-p-img").value.trim();
      const active = document.getElementById("f-p-act").value === "true";
      if (!name || !storeId) throw new Error("Name and store ID required.");
      const data = { name, storeId, storeName: storeName || "", price, imageUrl, active };
      if (lookupKey) data.lookupKey = lookupKey;
      if (modalEditId) {
        if (!lookupKey) lookupKey = modalEditId.toLowerCase();
        data.lookupKey = lookupKey;
        await db.collection(COL.products).doc(modalEditId).set(data, { merge: true });
      } else {
        const ref = await db.collection(COL.products).add(data);
        if (!lookupKey) await ref.set({ lookupKey: ref.id.toLowerCase() }, { merge: true });
      }
    }
    if (modalMode === "banner") {
      const title = document.getElementById("f-b-t").value.trim() || "Banner";
      const subtitle = document.getElementById("f-b-s").value.trim() || "";
      const sc = document.getElementById("f-b-sc").value.replace(/#/g, "").trim();
      const ec = document.getElementById("f-b-ec").value.replace(/#/g, "").trim();
      const iconKey = document.getElementById("f-b-ik").value.trim() || "delivery";
      const order = Number(document.getElementById("f-b-o").value) || 0;
      const active = document.getElementById("f-b-a").value === "true";
      const parseHex = (h) => {
        const n = parseInt(h.length === 6 ? h : "000000", 16);
        return Number.isNaN(n) ? 0xff2563eb : 0xff000000 | n;
      };
      const data = {
        title,
        subtitle,
        startColor: parseHex(sc || "2563eb"),
        endColor: parseHex(ec || "1d4ed8"),
        iconKey,
        order,
        active,
      };
      if (modalEditId) await db.collection(COL.banners).doc(modalEditId).set(data, { merge: true });
      else await db.collection(COL.banners).doc().set(data);
    }
    if (modalMode === "job") {
      const existing = modalEditId ? cache.jobs.find((x) => x.id === modalEditId) : null;
      const title = document.getElementById("f-j-title").value.trim();
      const companyName = document.getElementById("f-j-company").value.trim();
      const salary = document.getElementById("f-j-salary").value.trim();
      const category = document.getElementById("f-j-cat").value;
      const type = document.getElementById("f-j-type").value;
      const location = document.getElementById("f-j-loc").value.trim();
      const description = document.getElementById("f-j-desc").value.trim();
      const contactPhone = document.getElementById("f-j-phone").value.trim();
      const whatsapp = document.getElementById("f-j-wa").value.trim();
      const remote = document.getElementById("f-j-remote").checked;
      const urgent = document.getElementById("f-j-urgent").checked;
      const verified = document.getElementById("f-j-verified").checked;
      const status = document.getElementById("f-j-status").value;
      const availableLaborCount = jobLaborLimit({
        availableLaborCount: parseInt(document.getElementById("f-j-labor").value, 10),
      });
      if (!title || title.length < 3) throw new Error("Job title required (min 3 characters).");
      if (!companyName) throw new Error("Company name required.");
      if (!salary) throw new Error("Salary required.");
      if (!location) throw new Error("Location required.");
      if (description.length < 10) throw new Error("Description min 10 characters.");
      if (contactPhone.length < 8) throw new Error("Valid contact phone required.");
      const uid = auth.currentUser.uid;
      const now = firebase.firestore.Timestamp.now();
      const expiresAt = firebase.firestore.Timestamp.fromMillis(
        now.toMillis() + 30 * 24 * 60 * 60 * 1000
      );
      const data = {
        title,
        companyName,
        salary,
        category,
        type,
        location,
        description,
        contactPhone,
        userId: existing?.userId || uid,
        status,
        remote,
        urgent,
        verified,
        availableLaborCount,
        responsibilities: existing?.responsibilities || "",
        schedule: existing?.schedule || "",
        skills: existing?.skills || [],
        city: existing?.city || "",
        viewCount: existing?.viewCount || 0,
        reportedCount: existing?.reportedCount || 0,
        expiresAt: existing?.expiresAt || expiresAt,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      };
      if (whatsapp) data.whatsapp = whatsapp;
      if (modalEditId) {
        await db.collection(COL.jobs).doc(modalEditId).set(data, { merge: true });
      } else {
        data.createdAt = now;
        data.expiresAt = expiresAt;
        if (status === "active") {
          data.approvedAt = now;
        }
        await db.collection(COL.jobs).add(data);
      }
    }
    if (modalMode === "rider") {
      const name = document.getElementById("f-r-name").value.trim();
      const phone = document.getElementById("f-r-phone").value.trim();
      const vehicle = document.getElementById("f-r-veh").value.trim() || "Bike";
      const latStr = document.getElementById("f-r-lat").value.trim();
      const lngStr = document.getElementById("f-r-lng").value.trim();
      const data = { fullName: name, displayName: name, phoneNumber: phone, phone, vehicle, vehicleType: vehicle };
      const lat = parseFloat(latStr);
      const lng = parseFloat(lngStr);
      if (!Number.isNaN(lat) && !Number.isNaN(lng)) {
        data.latitude = lat;
        data.longitude = lng;
        data.currentLocation = new firebase.firestore.GeoPoint(lat, lng);
      }
      if (modalEditId) await db.collection(COL.riders).doc(modalEditId).set(data, { merge: true });
      else await db.collection(COL.riders).add(data);
    }
  }

  async function deleteOrder(id) {
    const o = cache.orders.find((x) => x.id === id);
    const label = o ? orderDisplayNumber(o) : "this order";
    if (!confirm(`Delete ${label}?`)) return;
    await db.collection(COL.orders).doc(id).delete();
    await loadViewData("orders");
    await loadOrders();
    renderDashboard();
  }

  async function deleteVendor(id) {
    if (!confirm(`Delete vendor ${id}?`)) return;
    await db.collection(COL.vendors).doc(id).delete();
    await loadViewData("vendors");
  }

  async function refreshAfterVendorChange() {
    await loadVendors();
    if (currentView === "shop-approvals") renderShopApprovals();
    if (currentView === "vendors") renderVendors();
    if (currentView === "dashboard") renderDashboard();
    updateAllApprovalBadges();
    updateDashboardQuickActions();
  }

  async function refreshAfterJobChange() {
    await loadJobs();
    if (currentView === "job-approvals") {
      await loadJobApplications();
      renderJobApprovals();
      renderPublishedJobs();
    }
    if (currentView === "dashboard") renderDashboard();
    updateAllApprovalBadges();
    updateDashboardQuickActions();
  }

  async function approveVendor(id) {
    if (!id) return;
    await db.collection(COL.vendors).doc(id).set(
      {
        approvalStatus: "approved",
        active: true,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    await refreshAfterVendorChange();
    toast("Shop approved.", "success");
  }

  async function rejectVendor(id) {
    if (!id) return;
    const reason = prompt("Optional rejection note (or leave blank):", "");
    await db.collection(COL.vendors).doc(id).set(
      {
        approvalStatus: "rejected",
        active: false,
        rejectionNote: reason ? String(reason).trim() : "",
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    await refreshAfterVendorChange();
  }

  async function approveJob(id) {
    if (!id) return;
    await db.collection(COL.jobs).doc(id).set(
      {
        status: "active",
        approvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    await refreshAfterJobChange();
    toast("Job published.", "success");
  }

  async function rejectJob(id) {
    if (!id) return;
    const reason = prompt("Optional rejection note (or leave blank):", "");
    const patch = {
      status: "rejected",
      updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    };
    if (reason) patch.rejectionNote = String(reason).trim();
    await db.collection(COL.jobs).doc(id).set(patch, { merge: true });
    await refreshAfterJobChange();
  }

  async function deleteJob(id) {
    if (!id || !confirm(`Delete job ${id}?`)) return;
    await db.collection(COL.jobs).doc(id).delete();
    await refreshAfterJobChange();
    if (currentView === "job-approvals") {
      renderJobApprovals();
      renderPublishedJobs();
    }
  }

  async function approveRider(id) {
    if (!id) return;
    await db.collection(COL.riders).doc(id).set(
      {
        status: "approved",
        online: false,
        approvedAt: firebase.firestore.FieldValue.serverTimestamp(),
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    await loadRiders();
    if (currentView === "rider-approvals") renderRiderApprovals();
    if (currentView === "riders") renderRiders();
    if (currentView === "dashboard") renderDashboard();
    updatePendingRiderNavBadge();
    toast("Rider approved.", "success");
  }

  async function rejectRider(id) {
    if (!id) return;
    const reason = prompt("Optional rejection note (or leave blank):", "");
    await db.collection(COL.riders).doc(id).set(
      {
        status: "rejected",
        online: false,
        rejectionNote: reason ? String(reason).trim() : "",
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    await loadRiders();
    if (currentView === "rider-approvals") renderRiderApprovals();
    if (currentView === "riders") renderRiders();
    updatePendingRiderNavBadge();
  }

  async function deleteProduct(id) {
    if (!confirm(`Delete product ${id}?`)) return;
    await db.collection(COL.products).doc(id).delete();
    await loadViewData("products");
  }

  async function deleteBanner(id) {
    if (!confirm(`Delete banner ${id}?`)) return;
    await db.collection(COL.banners).doc(id).delete();
    await loadViewData("banners");
  }

  async function deleteShopCategory(id) {
    const q = await db.collection(COL.shopTypes).where("categoryId", "==", id).limit(1).get(FS_GET_SERVER);
    if (!q.empty) {
      alert("This category still has shop types. Delete or reassign those first.");
      return;
    }
    if (!confirm(`Delete shop category? (${id})`)) return;
    await db.collection(COL.shopCategories).doc(id).delete();
    await loadViewData("shop-types");
  }

  async function deleteShopType(id) {
    if (!confirm(`Delete this shop type? (${id})`)) return;
    await db.collection(COL.shopTypes).doc(id).delete();
    await loadViewData("shop-types");
  }

  async function addShopCategoryFromWebForm() {
    const input = document.getElementById("shop-category-new-label");
    const btn = document.getElementById("btn-add-shop-category");
    const status = document.getElementById("shop-category-save-status");
    if (!input || !btn) return;
    const label = String(input.value || "").trim();
    if (!label || label.length > 80) {
      toast("Enter a category label (1–80 characters).", "warning");
      return;
    }
    btn.disabled = true;
    if (status) status.textContent = "Saving…";
    try {
      let nextOrder = 0;
      try {
        const top = await db
          .collection(COL.shopCategories)
          .orderBy("order", "desc")
          .limit(1)
          .get(FS_GET_SERVER);
        if (!top.empty) {
          const o = top.docs[0].data().order;
          if (typeof o === "number") nextOrder = o + 1;
        }
      } catch (_) {
        const snap = await db.collection(COL.shopCategories).limit(200).get(FS_GET_SERVER);
        snap.docs.forEach((d) => {
          const o = Number(d.data().order) || 0;
          if (o >= nextOrder) nextOrder = o + 1;
        });
      }
      await db.collection(COL.shopCategories).add({
        label,
        order: nextOrder,
        active: true,
      });
      input.value = "";
      if (status) {
        status.textContent = "Saved.";
        setTimeout(() => {
          if (status) status.textContent = "";
        }, 2500);
      }
      await loadViewData("shop-types");
    } catch (err) {
      let msg = err && err.message ? err.message : String(err);
      alert(msg);
      if (status) status.textContent = "";
    } finally {
      btn.disabled = false;
    }
  }

  async function addShopTypeFromWebForm() {
    const sel = document.getElementById("shop-type-category");
    const input = document.getElementById("shop-type-new-label");
    const btn = document.getElementById("btn-add-shop-type");
    const status = document.getElementById("shop-type-save-status");
    if (!input || !btn) return;
    const categoryId = sel ? String(sel.value || "").trim() : "";
    if (!categoryId) {
      alert("Select a shop category first (create one above if needed).");
      return;
    }
    const label = String(input.value || "").trim();
    if (!label || label.length > 80) {
      toast("Enter a label (1–80 characters).", "warning");
      return;
    }
    btn.disabled = true;
    if (status) status.textContent = "Saving to Firestore…";
    try {
      let nextOrder = 0;
      try {
        const top = await db
          .collection(COL.shopTypes)
          .where("categoryId", "==", categoryId)
          .orderBy("order", "desc")
          .limit(1)
          .get(FS_GET_SERVER);
        if (!top.empty) {
          const o = top.docs[0].data().order;
          if (typeof o === "number") nextOrder = o + 1;
        }
      } catch (_) {
        for (const t of cache.shopTypes) {
          if (t.categoryId !== categoryId) continue;
          const o = Number(t.order) || 0;
          if (o >= nextOrder) nextOrder = o + 1;
        }
      }
      await db.collection(COL.shopTypes).add({
        label,
        categoryId,
        order: nextOrder,
        active: true,
      });
      input.value = "";
      if (status) {
        status.textContent = "Saved.";
        setTimeout(() => {
          if (status) status.textContent = "";
        }, 2500);
      }
      await loadViewData("shop-types");
    } catch (err) {
      const code = err && err.code ? String(err.code) : "";
      let msg = err && err.message ? err.message : String(err);
      if (code === "permission-denied" || /permission/i.test(msg)) {
        msg +=
          "\n\n• Deploy latest rules: from repo folder run  firebase deploy --only firestore  " +
          "(needs shop_types rules + indexes).\n" +
          "• Firestore customers/{yourAuthUid} must have role: admin (Admin / ADMIN also work).";
      }
      alert(msg);
      if (status) status.textContent = "";
    } finally {
      btn.disabled = false;
    }
  }

  async function deleteRider(id) {
    if (!confirm(`Delete rider ${id}?`)) return;
    await db.collection(COL.riders).doc(id).delete();
    await loadViewData("riders");
  }

  async function deleteCustomer(id) {
    const u = cache.customers.find((x) => x.id === id);
    const label = u ? customerDisplayName(u) : "this customer";
    if (!confirm(`Delete ${label}? This removes the Firestore profile only, not the Auth user.`)) return;
    await db.collection(COL.customers).doc(id).delete();
    await loadViewData("customers");
  }

  async function loadPlatformFees() {
    try {
      const snap = await db
        .collection(COL.platformConfig)
        .doc(COL.platformFeesDoc)
        .get(FS_GET_SERVER);
      if (!snap.exists) {
        cache.platformFees = { ...PLATFORM_FEES_DEFAULTS };
        return;
      }
      const d = snap.data() || {};
      cache.platformFees = {
        orderCommissionLkr: Number(d.orderCommissionLkr) || 0,
        riderCommissionLkr: Number(d.riderCommissionLkr) || 0,
        minDeliveryFeeLkr:
          Number(d.minDeliveryFeeLkr) || PLATFORM_FEES_DEFAULTS.minDeliveryFeeLkr,
        pricePerKmLkr:
          Number(d.pricePerKmLkr) || PLATFORM_FEES_DEFAULTS.pricePerKmLkr,
        shopMonthlyCommissionPercent:
          d.shopMonthlyCommissionPercent == null
            ? PLATFORM_FEES_DEFAULTS.shopMonthlyCommissionPercent
            : Number(d.shopMonthlyCommissionPercent),
      };
    } catch (e) {
      cache.platformFees = { ...PLATFORM_FEES_DEFAULTS };
      console.warn("loadPlatformFees", e);
    }
  }

  function renderPlatformFeesForm() {
    const f = cache.platformFees || PLATFORM_FEES_DEFAULTS;
    const setVal = (id, v) => {
      const el = document.getElementById(id);
      if (el) el.value = v;
    };
    setVal("fee-order-commission", f.orderCommissionLkr);
    setVal("fee-rider-commission", f.riderCommissionLkr);
    setVal("fee-min-delivery", f.minDeliveryFeeLkr);
    setVal("fee-per-km", f.pricePerKmLkr);
    setVal("fee-shop-monthly-pct", f.shopMonthlyCommissionPercent);
  }

  async function savePlatformFeesFromForm() {
    const payload = {
      orderCommissionLkr: Math.max(
        0,
        Math.round(Number(document.getElementById("fee-order-commission").value) || 0)
      ),
      riderCommissionLkr: Math.max(
        0,
        Math.round(Number(document.getElementById("fee-rider-commission").value) || 0)
      ),
      minDeliveryFeeLkr: Math.max(
        0,
        Math.round(Number(document.getElementById("fee-min-delivery").value) || 0)
      ),
      pricePerKmLkr: Math.max(
        0,
        Math.round(Number(document.getElementById("fee-per-km").value) || 0)
      ),
      shopMonthlyCommissionPercent: Math.min(
        100,
        Math.max(0, Number(document.getElementById("fee-shop-monthly-pct").value) || 0)
      ),
      updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    };
    await db
      .collection(COL.platformConfig)
      .doc(COL.platformFeesDoc)
      .set(payload, { merge: true });
    cache.platformFees = {
      orderCommissionLkr: payload.orderCommissionLkr,
      riderCommissionLkr: payload.riderCommissionLkr,
      minDeliveryFeeLkr: payload.minDeliveryFeeLkr,
      pricePerKmLkr: payload.pricePerKmLkr,
      shopMonthlyCommissionPercent: payload.shopMonthlyCommissionPercent,
    };
    toast("Platform fees saved", "success");
  }

  function seedInvoiceMonthInput() {
    const el = document.getElementById("invoice-month");
    if (!el || el.value) return;
    const now = new Date();
    el.value = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  }

  function selectedInvoiceMonthKey() {
    const el = document.getElementById("invoice-month");
    const v = (el && el.value) || "";
    if (/^\d{4}-\d{2}$/.test(v)) return v;
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  }

  async function loadMonthlyInvoicesForSelectedMonth() {
    const monthKey = selectedInvoiceMonthKey();
    const invoices = [];
    const vendors = cache.vendors || [];
    await Promise.all(
      vendors.slice(0, 300).map(async (v) => {
        try {
          const snap = await db
            .collection(COL.vendors)
            .doc(v.id)
            .collection("monthly_invoices")
            .doc(monthKey)
            .get(FS_GET_SERVER);
          if (snap.exists) {
            invoices.push({ id: snap.id, vendorDocId: v.id, ...snap.data() });
          }
        } catch (_) {}
      })
    );
    invoices.sort((a, b) =>
      String(a.vendorName || a.vendorDocId || "").localeCompare(
        String(b.vendorName || b.vendorDocId || "")
      )
    );
    cache.monthlyInvoices = invoices;
  }

  function renderMonthlyInvoices() {
    const tbody = document.querySelector("#table-monthly-invoices tbody");
    if (!tbody) return;
    const list = cache.monthlyInvoices || [];
    if (!list.length) {
      tbody.innerHTML =
        '<tr><td colspan="7" style="color:var(--muted)">No invoices for this month yet. Generate from monthly stats.</td></tr>';
      return;
    }
    tbody.innerHTML = list
      .map((inv) => {
        const vendorId = inv.vendorDocId || inv.vendorId || "";
        const monthKey = inv.monthKey || inv.id || "";
        return `<tr>
          <td>${escapeHtml(inv.vendorName || vendorId)}</td>
          <td>${escapeHtml(monthKey)}</td>
          <td>${fmtMoney(inv.netSalesLkr)}</td>
          <td>${escapeHtml(String(inv.feePercent ?? ""))}%</td>
          <td>${fmtMoney(inv.feeLkr)}</td>
          <td><span class="badge">${escapeHtml(inv.status || "pending")}</span></td>
          <td class="row-actions">
            <button type="button" class="btn btn-ghost btn-sm" data-inv-status="invoiced" data-vendor="${escapeHtml(vendorId)}" data-month="${escapeHtml(monthKey)}">Mark invoiced</button>
            <button type="button" class="btn btn-ghost btn-sm" data-inv-status="paid" data-vendor="${escapeHtml(vendorId)}" data-month="${escapeHtml(monthKey)}">Mark paid</button>
          </td>
        </tr>`;
      })
      .join("");
  }

  async function generateMonthlyInvoices() {
    const monthKey = selectedInvoiceMonthKey();
    await loadPlatformFees();
    const feePercent = Number(cache.platformFees.shopMonthlyCommissionPercent) || 0;
    const vendors = cache.vendors || [];
    let created = 0;
    for (const v of vendors) {
      let netSales = 0;
      try {
        const statsSnap = await db
          .collection(COL.vendors)
          .doc(v.id)
          .collection("monthly_stats")
          .doc(monthKey)
          .get(FS_GET_SERVER);
        if (statsSnap.exists) {
          netSales = Number(statsSnap.data().netSalesLkr) || 0;
        }
      } catch (_) {
        continue;
      }
      if (netSales <= 0) continue;
      const feeLkr = Math.round((netSales * feePercent) / 100);
      const ref = db
        .collection(COL.vendors)
        .doc(v.id)
        .collection("monthly_invoices")
        .doc(monthKey);
      const existing = await ref.get(FS_GET_SERVER);
      const prev = existing.exists ? existing.data() : null;
      const status = prev && prev.status ? prev.status : "pending";
      await ref.set(
        {
          vendorId: v.id,
          vendorName: v.name || v.shopName || v.id,
          monthKey,
          netSalesLkr: netSales,
          feePercent,
          feeLkr,
          status,
          notes: (prev && prev.notes) || "",
          createdAt: prev && prev.createdAt
            ? prev.createdAt
            : firebase.firestore.FieldValue.serverTimestamp(),
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
          ...(prev && prev.invoicedAt ? { invoicedAt: prev.invoicedAt } : {}),
          ...(prev && prev.paidAt ? { paidAt: prev.paidAt } : {}),
        },
        { merge: true }
      );
      created += 1;
    }
    await loadMonthlyInvoicesForSelectedMonth();
    renderMonthlyInvoices();
    toast(`Updated ${created} invoice(s) for ${monthKey}`, "success");
  }

  async function setMonthlyInvoiceStatus(vendorId, monthKey, status) {
    const ref = db
      .collection(COL.vendors)
      .doc(vendorId)
      .collection("monthly_invoices")
      .doc(monthKey);
    const patch = {
      status,
      updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    };
    if (status === "invoiced") {
      patch.invoicedAt = firebase.firestore.FieldValue.serverTimestamp();
    }
    if (status === "paid") {
      patch.paidAt = firebase.firestore.FieldValue.serverTimestamp();
    }
    await ref.set(patch, { merge: true });
    await loadMonthlyInvoicesForSelectedMonth();
    renderMonthlyInvoices();
    toast(`Invoice marked ${status}`, "success");
  }

  elLogout?.addEventListener("click", async () => {
    try {
      if (window.MndFirebase.terminateFirestore) {
        await window.MndFirebase.terminateFirestore();
      }
      await auth.signOut();
    } catch (_) {}
    redirectToLogin();
  });

  elNav.forEach((btn) => {
    btn.addEventListener("click", () => showView(btn.getAttribute("data-nav")));
  });

  document.getElementById("btn-new-order")?.addEventListener("click", openOrderCreate);
  document.getElementById("btn-save-platform-fees")?.addEventListener("click", () => {
    savePlatformFeesFromForm().catch((e) => toast(e.message || String(e), "error"));
  });
  document.getElementById("btn-generate-monthly-invoices")?.addEventListener("click", () => {
    generateMonthlyInvoices().catch((e) => toast(e.message || String(e), "error"));
  });
  document.getElementById("btn-reload-monthly-invoices")?.addEventListener("click", () => {
    loadMonthlyInvoicesForSelectedMonth()
      .then(() => renderMonthlyInvoices())
      .catch((e) => toast(e.message || String(e), "error"));
  });
  document.getElementById("invoice-month")?.addEventListener("change", () => {
    loadMonthlyInvoicesForSelectedMonth()
      .then(() => renderMonthlyInvoices())
      .catch((e) => toast(e.message || String(e), "error"));
  });
  document.querySelector("#table-monthly-invoices")?.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-inv-status]");
    if (!btn) return;
    const vendorId = btn.getAttribute("data-vendor");
    const monthKey = btn.getAttribute("data-month");
    const status = btn.getAttribute("data-inv-status");
    if (!vendorId || !monthKey || !status) return;
    setMonthlyInvoiceStatus(vendorId, monthKey, status).catch((err) =>
      toast(err.message || String(err), "error")
    );
  });
  const debouncedRenderOrders = ui().debounce
    ? ui().debounce(() => renderOrders(), 280)
    : () => renderOrders();
  document.getElementById("filter-orders")?.addEventListener("input", debouncedRenderOrders);
  document.getElementById("filter-order-status")?.addEventListener("change", () => renderOrders());
  const debouncedRenderProducts = ui().debounce
    ? ui().debounce(() => renderProducts(), 280)
    : () => renderProducts();
  document.getElementById("filter-product-shop")?.addEventListener("change", () => renderProducts());
  document.getElementById("filter-products")?.addEventListener("input", debouncedRenderProducts);
  const debouncedRenderCustomers = ui().debounce
    ? ui().debounce(() => renderCustomers(), 220)
    : () => renderCustomers();
  document.getElementById("filter-customers")?.addEventListener("input", debouncedRenderCustomers);
  document.getElementById("filter-customer-role")?.addEventListener("change", () => renderCustomers());
  document.getElementById("btn-new-vendor")?.addEventListener("click", () => openVendorModal(null));
  document.getElementById("btn-new-product")?.addEventListener("click", () => openProductModal(null));
  document.getElementById("btn-new-banner")?.addEventListener("click", () => openBannerModal(null));
  document.getElementById("btn-new-job")?.addEventListener("click", () => openJobModal(null));
  document.getElementById("btn-dashboard-add-job")?.addEventListener("click", () => openJobModal(null));
  document.getElementById("btn-add-shop-category")?.addEventListener("click", () => addShopCategoryFromWebForm());
  document.getElementById("shop-category-new-label")?.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      addShopCategoryFromWebForm();
    }
  });
  document.getElementById("btn-add-shop-type")?.addEventListener("click", () => addShopTypeFromWebForm());
  document.getElementById("shop-type-new-label")?.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      addShopTypeFromWebForm();
    }
  });
  document.getElementById("btn-new-rider")?.addEventListener("click", () => openRiderModal(null));
  document.getElementById("btn-refresh")?.addEventListener("click", () => {
    loadViewData(currentView)
      .then(() => toast("Data refreshed.", "success"))
      .catch((e) => toast(e.message || String(e), "error"));
  });

  document.getElementById("dashboard-quick-actions")?.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-go-nav]");
    if (btn) showView(btn.getAttribute("data-go-nav"));
  });

  try {
    initFirebase();
  } catch (e) {
    redirectToLogin("Firebase init failed: " + (e.message || String(e)));
    return;
  }

  let dashboardSessionReady = false;

  async function bootstrapDashboardAuth() {
    const user = await window.MndFirebase.waitForAuthState();
    if (!user) {
      if (elTopEmail) elTopEmail.textContent = "";
      redirectToLogin();
      return;
    }
    try {
      await user.getIdToken();
      await assertAdmin(user.uid);
      hideAuthGate();
      if (elTopEmail) elTopEmail.textContent = user.email || user.uid;
      await loadViewData(currentView);
      if (currentView === "dashboard") renderDashboard();
      dashboardSessionReady = true;
    } catch (err) {
      try {
        await firebase.auth().signOut();
      } catch (_) {}
      redirectToLogin(err.message || "Not authorized.");
    }
  }

  if (typeof firebase !== "undefined" && firebase.apps.length) {
    bootstrapDashboardAuth().catch((e) => redirectToLogin(e.message || String(e)));

    firebase.auth().onAuthStateChanged((user) => {
      if (!dashboardSessionReady) {
        return;
      }
      if (!user) {
        redirectToLogin();
      }
    });
  }
})();
