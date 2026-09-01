/**
 * MND web admin — Firestore CRUD aligned with mnd_customer:
 * collections: orders, customers, vendors, products, banners, offers, shop_categories, shop_types, grocery_aisles, riders, store_ratings, ride_fare_config (see firebase_collections.dart).
 * Auth: Firebase Email/Password; Firestore customers/{uid}.role must be "admin".
 */
(function () {
  const COL = {
    customers: "customers",
    riders: "riders",
    riderLocations: "rider_locations",
    vendors: "vendors",
    products: "products",
    banners: "banners",
    offers: "offers",
    shopCategories: "shop_categories",
    shopTypes: "shop_types",
    groceryAisles: "grocery_aisles",
    orders: "orders",
    trips: "trips",
    jobs: "jobs",
    jobApplications: "job_applications",
    jobReports: "job_reports",
    platformConfig: "platform_config",
    platformFeesDoc: "fees",
    rideFareConfig: "ride_fare_config",
    riderCashLedger: "cash_ledger",
    riderCashSettlements: "cash_settlements",
    storeRatings: "store_ratings",
  };

  const ACTIVE_DELIVERY_STATUSES = ["out_for_delivery", "picked_up", "on_the_way"];
  // "searching" included so a ride request with no driver ever claiming it
  // is visible to admin instead of sitting invisible forever.
  const ACTIVE_TRIP_STATUSES = ["searching", "accepted", "arrived", "in_progress"];
  const STALE_LOCATION_MS = 3 * 60 * 1000;
  /** Same Maps key as mnd_customer EnvConfig.googleMapsApiKey default. */
  const GOOGLE_MAPS_JS_KEY = "AIzaSyB3kvkvDZ7QRu_MJnpuWKt2Bgr_qtXN5FI";

  const PLATFORM_FEES_DEFAULTS = {
    serviceChargePercent: 5,
    // Flat cut the platform keeps per completed passenger ride. Mirrors
    // DEFAULT_RIDE_COMMISSION_LKR in functions/src/riderCashLogic.ts.
    rideCommissionLkr: 0,
    // Cash a rider may hold before new jobs stop being claimable. Mirrors
    // DEFAULT_MAX_CASH_IN_HAND_LKR in functions/src/riderCashLogic.ts.
    maxRiderCashInHandLkr: 7000,
    minDeliveryFeeLkr: 120,
    pricePerKmLkr: 42,
    shopMonthlyCommissionPercent: 1,
  };

  const DEFAULT_RIDE_FARES = {
    bike: { baseLkr: 100, perKmLkr: 25, minLkr: 150, perStopLkr: 50 },
    wheel: { baseLkr: 150, perKmLkr: 40, minLkr: 250, perStopLkr: 50 },
    car: { baseLkr: 200, perKmLkr: 50, minLkr: 400, perStopLkr: 100 },
  };

  const RIDE_FARE_VEHICLES = [
    {
      id: "bike",
      label: "Bike",
      capacity: 1,
      blurb: "Fast solo trips",
      icon: `<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="6.5" cy="16.5" r="3.25"/><circle cx="17.5" cy="16.5" r="3.25"/><path d="M6.5 16.5 10 8h3.5l2.5 5.5M10 8l-2 5.5h5"/></svg>`,
    },
    {
      id: "wheel",
      label: "Wheel",
      capacity: 3,
      blurb: "Tuk / three-wheeler",
      icon: `<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="7" cy="17" r="2.75"/><circle cx="17" cy="17" r="2.75"/><path d="M4.5 17H3l1.2-6.5A2 2 0 0 1 6.16 9H11l1.5 4h4.2a2 2 0 0 1 1.9 1.37L19.5 17H17M11 9V6.5A1.5 1.5 0 0 1 12.5 5H15"/></svg>`,
    },
    {
      id: "car",
      label: "Car",
      capacity: 4,
      blurb: "Comfort rides",
      icon: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 16.5V14l1.5-5A2 2 0 0 1 7.4 7.5h9.2A2 2 0 0 1 18.5 9l1.5 5v2.5"/><path d="M4 14h16"/><circle cx="7.5" cy="17" r="1.75"/><circle cx="16.5" cy="17" r="1.75"/></svg>`,
    },
  ];

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
  let functionsClient = null;
  let currentView = "dashboard";
  let cache = {
    orders: [],
    vendors: [],
    products: [],
    banners: [],
    offers: [],
    shopCategories: [],
    shopTypes: [],
    groceryAisles: [],
    riders: [],
    customers: [],
    jobs: [],
    jobApplications: [],
    jobReports: [],
    platformFees: { ...PLATFORM_FEES_DEFAULTS },
    monthlyInvoices: [],
    ratings: [],
    rideFares: null,
    ongoingJobs: [],
    cashSettlements: [],
    cashRiders: [],
  };

  let ongoingUnsubs = [];
  let riderTrackUnsub = null;
  let riderTrackMap = null;
  let riderTrackRiderMarker = null;
  let riderTrackPickupMarker = null;
  let riderTrackDropoffMarker = null;
  let googleMapsLoadPromise = null;

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
    functionsClient = boot.functions || window.MndFirebase.functions;
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
    if (
      s === "out_for_delivery" ||
      s === "on_the_way" ||
      s === "picked_up" ||
      s === "accepted" ||
      s === "arrived" ||
      s === "in_progress"
    ) {
      return "badge-out";
    }
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
      picked_up: "Picked up",
      on_the_way: "On the way",
      delivered: "Delivered",
      completed: "Collected",
      cancelled: "Cancelled",
      searching: "Searching",
      accepted: "Accepted",
      arrived: "Arrived",
      in_progress: "In progress",
    };
    return map[k] || s || "—";
  }

  function orderMissedByShop(o) {
    if (!o) return false;
    return (
      String(o.cancellationReason || "").trim() === "vendor_no_response" ||
      o.adminEscalated === true
    );
  }

  function missedByShopBadge(o) {
    if (!orderMissedByShop(o)) return "";
    return ` <span class="badge badge-cancelled">Missed by shop</span>`;
  }

  function fmtDateTime(val) {
    if (!val) return "—";
    try {
      let d = null;
      if (typeof val.toDate === "function") d = val.toDate();
      else if (val.seconds != null) d = new Date(val.seconds * 1000);
      else if (typeof val === "string" && val.trim()) d = new Date(val);
      else if (val instanceof Date) d = val;
      if (d && !Number.isNaN(d.getTime())) return d.toLocaleString();
    } catch (_) {}
    return "—";
  }

  function tsMillis(val) {
    if (!val) return 0;
    try {
      if (typeof val.toDate === "function") return val.toDate().getTime();
      if (val.seconds != null) return Number(val.seconds) * 1000;
      if (typeof val === "number") return val;
      if (typeof val === "string" && val.trim()) {
        const t = Date.parse(val);
        return Number.isNaN(t) ? 0 : t;
      }
    } catch (_) {}
    return 0;
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
    if (mode === "product-pick-shop") {
      modalSave.textContent = "Next";
    } else {
      modalSave.textContent = "Save";
    }
    const dialog = modalBackdrop.querySelector(".modal");
    if (dialog) {
      dialog.classList.toggle(
        "modal--wide",
        mode === "assign-rider" ||
          mode === "job-applications" ||
          mode === "order-detail" ||
          mode === "customer-profile" ||
          mode === "rider-profile" ||
          mode === "rider-track" ||
          mode === "rider-cash-ledger" ||
          mode === "product" ||
          mode === "product-pick-shop"
      );
    }
    modalBackdrop.classList.add("visible");
  }

  function teardownRiderTrack() {
    if (typeof riderTrackUnsub === "function") {
      try {
        riderTrackUnsub();
      } catch (_) {}
    }
    riderTrackUnsub = null;
    riderTrackMap = null;
    riderTrackRiderMarker = null;
    riderTrackPickupMarker = null;
    riderTrackDropoffMarker = null;
  }

  function closeModal() {
    if (modalMode === "rider-track") {
      teardownRiderTrack();
    }
    modalBackdrop.classList.remove("visible");
    modalMode = null;
    modalEditId = null;
    const dialog = modalBackdrop.querySelector(".modal");
    if (dialog) dialog.classList.remove("modal--wide");
    modalSave.style.display = "inline-flex";
    modalSave.textContent = "Save";
    if (modalCancel) modalCancel.textContent = "Cancel";
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
    offers: "Offers",
    "shop-types": "Shop types",
    "shop-approvals": "Shop approvals",
    "job-approvals": "Job approvals",
    "rider-approvals": "Rider approvals",
    riders: "Riders",
    "ongoing-riders": "Ongoing riders",
    customers: "Customers",
    "rider-cash": "Rider cash",
    "ride-fares": "Ride fares",
    ratings: "Rating Management",
    "platform-fees": "Fees & commissions",
    help: "Setup",
  };

  function stopOngoingListeners() {
    for (const unsub of ongoingUnsubs) {
      try {
        if (typeof unsub === "function") unsub();
      } catch (_) {}
    }
    ongoingUnsubs = [];
  }

  function showView(name) {
    if (currentView === "ongoing-riders" && name !== "ongoing-riders") {
      stopOngoingListeners();
    }
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
      await Promise.all([loadOrders(), loadVendors(), loadCustomers(), loadJobs(), loadRiders(), loadOffers()]);
    }
    if (name === "orders") await Promise.all([loadOrders(), loadCustomers(), loadVendors()]);
    if (name === "vendors" || name === "shop-approvals") {
      await loadVendors();
    }
    if (name === "job-approvals") {
      await loadJobs();
      await loadJobApplications();
      await loadJobReports();
    }
    if (name === "products") {
      await Promise.all([loadProducts(), loadVendors(), loadGroceryAisles()]);
    }
    if (name === "banners") await loadBanners();
    if (name === "offers") await loadOffers();
    if (name === "shop-types") await loadShopTypes();
    if (name === "riders" || name === "rider-approvals" || name === "dashboard") {
      await loadRiders();
    }
    if (name === "ongoing-riders") {
      if (cache.riders.length === 0) await loadRiders();
      await startOngoingJobsListeners();
    }
    if (name === "customers") await Promise.all([loadCustomers(), loadOrders()]);
    if (name === "rider-cash") await loadRiderCash();
    if (name === "ride-fares") await loadRideFares();
    if (name === "ratings") await loadRatings();
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
      renderJobReports();
    }
    if (name === "products") renderProducts();
    if (name === "banners") renderBanners();
    if (name === "offers") {
      renderOfferApprovals();
      renderOffers();
    }
    if (name === "shop-types") {
      renderShopCategories();
      renderShopTypes();
      renderGroceryAisles();
    }
    if (name === "rider-approvals") renderRiderApprovals();
    if (name === "riders") renderRiders();
    if (name === "ongoing-riders") renderOngoingRiders();
    if (name === "customers") renderCustomers();
    if (name === "rider-cash") renderRiderCash();
    if (name === "ride-fares") renderRideFares();
    if (name === "ratings") renderRatings();
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

  // Previously collected (job_reports) with zero admin visibility — nothing
  // ever queried this collection, so reported jobs were invisible forever.
  async function loadJobReports() {
    if (!db) return;
    try {
      const snap = await db
        .collection(COL.jobReports)
        .orderBy("createdAt", "desc")
        .limit(200)
        .get(FS_GET_SERVER);
      cache.jobReports = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.jobReports).limit(200).get(FS_GET_SERVER);
      cache.jobReports = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.jobReports.sort((a, b) => {
        const ta = a.createdAt && a.createdAt.seconds ? a.createdAt.seconds : 0;
        const tb = b.createdAt && b.createdAt.seconds ? b.createdAt.seconds : 0;
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

  async function loadOffers() {
    try {
      const snap = await db
        .collection(COL.offers)
        .orderBy("createdAt", "desc")
        .limit(300)
        .get(FS_GET_SERVER);
      cache.offers = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.offers).limit(300).get(FS_GET_SERVER);
      cache.offers = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    }
    updatePendingOffersBadge();
  }

  function offerEndsDate(o) {
    const raw = o?.endsAt;
    if (!raw) return null;
    if (typeof raw.toDate === "function") return raw.toDate();
    if (raw instanceof Date) return raw;
    return null;
  }

  function offerDisplayStatus(o) {
    const status = String(o?.status || "pending").toLowerCase();
    const ends = offerEndsDate(o);
    if (status === "approved" && ends && ends.getTime() <= Date.now()) {
      return "expired";
    }
    return status;
  }

  function updatePendingOffersBadge() {
    const el = document.getElementById("nav-pending-offers");
    if (!el) return;
    const n = cache.offers.filter((o) => String(o.status || "").toLowerCase() === "pending").length;
    if (n > 0) {
      el.hidden = false;
      el.textContent = String(n);
    } else {
      el.hidden = true;
      el.textContent = "0";
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
    await loadGroceryAisles();
    try {
      const snap = await db.collection(COL.shopTypes).orderBy("order").limit(400).get(FS_GET_SERVER);
      cache.shopTypes = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.shopTypes).limit(400).get(FS_GET_SERVER);
      cache.shopTypes = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.shopTypes.sort((a, b) => (Number(a.order) || 0) - (Number(b.order) || 0));
    }
  }

  async function loadGroceryAisles() {
    try {
      const snap = await db.collection(COL.groceryAisles).orderBy("order").limit(200).get(FS_GET_SERVER);
      cache.groceryAisles = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.groceryAisles).limit(200).get(FS_GET_SERVER);
      cache.groceryAisles = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.groceryAisles.sort((a, b) => (Number(a.order) || 0) - (Number(b.order) || 0));
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

  function riderById(riderId) {
    const id = String(riderId || "").trim();
    if (!id) return null;
    return cache.riders.find((x) => x.id === id) || null;
  }

  function effectiveJobRiderId(doc) {
    return compactText(doc?.assignedRiderId, doc?.riderId);
  }

  function placeLabel(place, fallback) {
    if (!place || typeof place !== "object") return fallback || "—";
    return compactText(place.label, place.address, place.name, fallback) || "—";
  }

  function placeLatLng(place) {
    if (!place || typeof place !== "object") return null;
    const fromRead = readLatLng(place);
    if (fromRead) return fromRead;
    const la = Number(place.lat);
    const ln = Number(place.lng);
    if (Number.isFinite(la) && Number.isFinite(ln)) return { lat: la, lng: ln };
    return null;
  }

  function orderPickupDropoff(order) {
    const pickup = compactText(
      order?.pickupAddress,
      order?.storeAddress,
      order?.vendorAddress,
      shopDisplayName(order)
    );
    const dropoff = compactText(order?.deliveryAddress, order?.dropoffAddress, orderAddrLine(order));
    const pickupLL =
      readLatLng({
        latitude: order?.pickupLatitude,
        longitude: order?.pickupLongitude,
      }) ||
      readLatLng({
        latitude: order?.storeLatitude,
        longitude: order?.storeLongitude,
      });
    const dropoffLL = readLatLng({
      latitude: order?.dropoffLatitude ?? order?.deliveryLatitude,
      longitude: order?.dropoffLongitude ?? order?.deliveryLongitude,
    });
    return {
      pickupLabel: pickup || "Pickup",
      dropoffLabel: dropoff || "Dropoff",
      pickupLL,
      dropoffLL,
    };
  }

  function tripPickupDropoff(trip) {
    const pickup = trip?.pickup;
    const dropoff = trip?.dropoff;
    return {
      pickupLabel: placeLabel(pickup, "Pickup"),
      dropoffLabel: placeLabel(dropoff, "Dropoff"),
      pickupLL: placeLatLng(pickup),
      dropoffLL: placeLatLng(dropoff),
    };
  }

  function buildOngoingRowFromOrder(order) {
    const riderId = effectiveJobRiderId(order);
    if (!riderId) return null;
    const route = orderPickupDropoff(order);
    const since =
      order.riderAcceptedAt ||
      order.pickedUpAt ||
      order.onTheWayAt ||
      order.updatedAt ||
      order.createdAt;
    return {
      key: `delivery:${order.id}`,
      jobType: "delivery",
      jobId: order.id,
      riderId,
      status: String(order.status || "").toLowerCase(),
      jobLabel: `${orderDisplayNumber(order)} · ${shopDisplayName(order)}`,
      pickupLabel: route.pickupLabel,
      dropoffLabel: route.dropoffLabel,
      pickupLL: route.pickupLL,
      dropoffLL: route.dropoffLL,
      since,
      sinceMs: tsMillis(since),
      searchText: [
        order.id,
        order.trackingNumber,
        shopDisplayName(order),
        route.pickupLabel,
        route.dropoffLabel,
        riderId,
      ]
        .join(" ")
        .toLowerCase(),
    };
  }

  function buildOngoingRowFromTrip(trip) {
    const riderId = effectiveJobRiderId(trip);
    // Unlike delivery orders, a "searching" ride has no rider yet — still
    // surfaced as a row (rather than dropped) so a stuck, unclaimed ride
    // request is visible to admin instead of invisible forever.
    const route = tripPickupDropoff(trip);
    const since =
      trip.riderAcceptedAt || trip.arrivedAt || trip.startedAt || trip.updatedAt || trip.createdAt;
    const vehicle = riderVehicleTypeLabel(trip.vehicleType);
    return {
      key: `ride:${trip.id}`,
      jobType: "ride",
      jobId: trip.id,
      riderId,
      status: String(trip.status || "").toLowerCase(),
      jobLabel: `Trip ${String(trip.id).slice(0, 8)} · ${vehicle}`,
      pickupLabel: route.pickupLabel,
      dropoffLabel: route.dropoffLabel,
      pickupLL: route.pickupLL,
      dropoffLL: route.dropoffLL,
      since,
      sinceMs: tsMillis(since),
      searchText: [
        trip.id,
        trip.contactPhone,
        trip.vehicleType,
        route.pickupLabel,
        route.dropoffLabel,
        riderId,
      ]
        .join(" ")
        .toLowerCase(),
    };
  }

  function rebuildOngoingJobs(activeOrders, activeTrips) {
    const rows = [];
    for (const o of activeOrders) {
      const row = buildOngoingRowFromOrder(o);
      if (row) rows.push(row);
    }
    for (const t of activeTrips) {
      const row = buildOngoingRowFromTrip(t);
      if (row) rows.push(row);
    }
    rows.sort((a, b) => b.sinceMs - a.sinceMs);
    cache.ongoingJobs = rows;
    updateOngoingRidersNavBadge();
  }

  function updateOngoingRidersNavBadge() {
    const n = cache.ongoingJobs.length;
    const navBadge = document.getElementById("nav-ongoing-riders");
    if (!navBadge) return;
    if (n > 0) {
      navBadge.textContent = String(n);
      navBadge.hidden = false;
    } else {
      navBadge.hidden = true;
    }
  }

  /**
   * Live listeners for active deliveries + trips. Resolves after first snapshots
   * so the table can render immediately; keeps listening while the view is open.
   */
  function startOngoingJobsListeners() {
    stopOngoingListeners();
    return new Promise((resolve, reject) => {
      let ordersSnap = null;
      let tripsSnap = null;
      let settled = false;
      let ordersReady = false;
      let tripsReady = false;

      const trySettle = () => {
        if (!ordersReady || !tripsReady || settled) return;
        settled = true;
        rebuildOngoingJobs(
          (ordersSnap?.docs || []).map((d) => ({ id: d.id, ...d.data() })),
          (tripsSnap?.docs || []).map((d) => ({ id: d.id, ...d.data() }))
        );
        resolve();
      };

      const onError = (err) => {
        if (!settled) {
          settled = true;
          reject(err);
        } else {
          toast(err.message || String(err), "error");
        }
      };

      const apply = () => {
        rebuildOngoingJobs(
          (ordersSnap?.docs || []).map((d) => ({ id: d.id, ...d.data() })),
          (tripsSnap?.docs || []).map((d) => ({ id: d.id, ...d.data() }))
        );
        if (currentView === "ongoing-riders") renderOngoingRiders();
      };

      const ordersUnsub = db
        .collection(COL.orders)
        .where("status", "in", ACTIVE_DELIVERY_STATUSES)
        .limit(100)
        .onSnapshot(
          (snap) => {
            ordersSnap = snap;
            ordersReady = true;
            if (settled) apply();
            else trySettle();
          },
          onError
        );

      const tripsUnsub = db
        .collection(COL.trips)
        .where("status", "in", ACTIVE_TRIP_STATUSES)
        .limit(100)
        .onSnapshot(
          (snap) => {
            tripsSnap = snap;
            tripsReady = true;
            if (settled) apply();
            else trySettle();
          },
          onError
        );

      ongoingUnsubs = [ordersUnsub, tripsUnsub];
    });
  }

  function filteredOngoingJobs() {
    const typeFilter = (document.getElementById("filter-ongoing-type")?.value || "").trim().toLowerCase();
    const q = (document.getElementById("filter-ongoing-riders")?.value || "").trim().toLowerCase();
    let list = cache.ongoingJobs;
    if (typeFilter === "delivery" || typeFilter === "ride") {
      list = list.filter((row) => row.jobType === typeFilter);
    }
    if (q) {
      list = list.filter((row) => {
        const rider = riderById(row.riderId);
        const hay = [
          row.searchText,
          riderDisplayName(rider || {}),
          rider?.phoneNumber || rider?.phone || "",
          row.riderId,
          row.status,
          row.jobLabel,
        ]
          .join(" ")
          .toLowerCase();
        return hay.includes(q);
      });
    }
    return list;
  }

  function renderOngoingRiders() {
    const tbody = document.querySelector("#table-ongoing-riders tbody");
    if (!tbody) return;
    const list = filteredOngoingJobs();
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="7"><div class="empty-state"><div class="empty-state__icon">🛵</div>No riders on active jobs right now.</div></td></tr>`
        : list
            .map((row) => {
              const rider = riderById(row.riderId);
              const name = rider
                ? riderDisplayName(rider)
                : row.riderId || "Unassigned — searching";
              const phone = rider?.phoneNumber || rider?.phone || "—";
              const vehicle = rider ? riderVehicleLabel(rider) : "—";
              const typeBadge =
                row.jobType === "ride"
                  ? `<span class="job-type-badge job-type-badge--ride">Ride</span>`
                  : `<span class="job-type-badge job-type-badge--delivery">Delivery</span>`;
              const route = `${row.pickupLabel} → ${row.dropoffLabel}`;
              const canCancelRide =
                row.jobType === "ride" && !["completed", "cancelled"].includes(row.status);
              const actions = [];
              if (row.riderId) {
                actions.push(
                  `<button type="button" class="btn btn-primary btn-sm" data-track-rider="${escapeHtml(
                    row.key
                  )}">Map</button>`
                );
              }
              if (canCancelRide) {
                actions.push(
                  `<button type="button" class="btn btn-ghost btn-sm" data-cancel-trip="${escapeHtml(
                    row.jobId
                  )}">Cancel</button>`
                );
              }
              return `<tr>
        <td>
          <div class="ongoing-rider-cell">
            <strong>${escapeHtml(name)}</strong>
            <small>${escapeHtml(phone)}</small>
            <small>${escapeHtml(vehicle)}</small>
          </div>
        </td>
        <td>${typeBadge}</td>
        <td><code>${escapeHtml(row.jobLabel)}</code></td>
        <td class="ongoing-route-cell">${escapeHtml(route)}</td>
        <td><span class="badge ${badgeClass(row.status)}">${escapeHtml(statusLabel(row.status))}</span></td>
        <td>${escapeHtml(fmtDateTime(row.since))}</td>
        <td class="row-actions">${actions.join(" ")}</td>
      </tr>`;
            })
            .join("");

    tbody.querySelectorAll("[data-track-rider]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const key = btn.getAttribute("data-track-rider");
        const row = cache.ongoingJobs.find((r) => r.key === key);
        if (row) openRiderTrackModal(row);
      });
    });
    tbody.querySelectorAll("[data-cancel-trip]").forEach((btn) => {
      btn.addEventListener("click", () => {
        adminCancelTrip(btn.getAttribute("data-cancel-trip"));
      });
    });
  }

  /**
   * Admin-cancels a trip directly — the only way to clear a ride stuck in
   * "searching" with no driver, or to stop an accepted/arrived/in_progress
   * ride, since there was previously no admin write path for trips at all.
   */
  async function adminCancelTrip(tripId) {
    if (!tripId || !auth.currentUser) return;
    if (!window.confirm("Cancel this ride? This cannot be undone.")) return;
    try {
      await db.collection(COL.trips).doc(tripId).update({
        status: "cancelled",
        openForRiders: false,
        cancelledBy: "admin",
        cancelReason: "admin_cancelled",
        cancelledAt: firebase.firestore.FieldValue.serverTimestamp(),
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });
      toast("Ride cancelled.", "success");
    } catch (err) {
      alert(err.message || String(err));
    }
  }

  function ensureGoogleMaps() {
    if (window.google?.maps) return Promise.resolve(window.google.maps);
    if (googleMapsLoadPromise) return googleMapsLoadPromise;
    googleMapsLoadPromise = new Promise((resolve, reject) => {
      const cbName = "__mndAdminMapsReady";
      window[cbName] = () => {
        try {
          delete window[cbName];
        } catch (_) {}
        if (window.google?.maps) resolve(window.google.maps);
        else reject(new Error("Google Maps failed to load"));
      };
      const script = document.createElement("script");
      script.async = true;
      script.defer = true;
      script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(
        GOOGLE_MAPS_JS_KEY
      )}&callback=${cbName}`;
      script.onerror = () => reject(new Error("Could not load Google Maps script"));
      document.head.appendChild(script);
    });
    return googleMapsLoadPromise;
  }

  function locationAgeLabel(updatedAt) {
    const ms = tsMillis(updatedAt);
    if (!ms) return { text: "Location time unknown", stale: true };
    const age = Date.now() - ms;
    const stale = age > STALE_LOCATION_MS;
    if (age < 60_000) return { text: `Updated ${Math.max(1, Math.round(age / 1000))}s ago`, stale };
    if (age < 3_600_000) return { text: `Updated ${Math.round(age / 60_000)}m ago`, stale };
    return { text: `Updated ${Math.round(age / 3_600_000)}h ago`, stale };
  }

  function fallbackRiderLatLng(riderId) {
    const rider = riderById(riderId);
    if (!rider) return null;
    return (
      readLatLng(rider) ||
      readLatLng(rider.currentLocation) ||
      readLatLng({
        latitude: rider.currentLatitude,
        longitude: rider.currentLongitude,
      })
    );
  }

  function fitTrackMapBounds(maps, riderLL) {
    if (!riderTrackMap) return;
    const points = [];
    if (riderLL) points.push(riderLL);
    if (riderTrackPickupMarker) {
      const p = riderTrackPickupMarker.getPosition();
      if (p) points.push({ lat: p.lat(), lng: p.lng() });
    }
    if (riderTrackDropoffMarker) {
      const p = riderTrackDropoffMarker.getPosition();
      if (p) points.push({ lat: p.lat(), lng: p.lng() });
    }
    if (points.length === 0) return;
    if (points.length === 1) {
      riderTrackMap.setCenter(points[0]);
      riderTrackMap.setZoom(15);
      return;
    }
    const bounds = new maps.LatLngBounds();
    points.forEach((p) => bounds.extend(p));
    riderTrackMap.fitBounds(bounds, 48);
  }

  function updateRiderTrackMeta(loc) {
    const meta = document.getElementById("ongoing-rider-map-meta");
    if (!meta) return;
    const age = locationAgeLabel(loc?.locationUpdatedAt || loc?.updatedAt);
    meta.innerHTML = age.stale
      ? `<span class="ongoing-map-stale">${escapeHtml(age.text)} — location may be stale</span>`
      : `<span>${escapeHtml(age.text)}</span>`;
  }

  async function openRiderTrackModal(row) {
    const rider = riderById(row.riderId);
    const name = rider ? riderDisplayName(rider) : row.riderId;
    const typeLabel = row.jobType === "ride" ? "Ride" : "Delivery";
    const html = `
      <div class="ongoing-track-meta">
        <div><strong>${escapeHtml(name)}</strong> · ${escapeHtml(typeLabel)}</div>
        <div>${escapeHtml(row.jobLabel)}</div>
        <div class="ongoing-route-cell">${escapeHtml(row.pickupLabel)} → ${escapeHtml(row.dropoffLabel)}</div>
        <div><span class="badge ${badgeClass(row.status)}">${escapeHtml(statusLabel(row.status))}</span></div>
      </div>
      <div id="ongoing-rider-map-meta" class="ongoing-map-meta">Loading live location…</div>
      <div id="ongoing-rider-map" class="ongoing-rider-map" role="img" aria-label="Rider live map"></div>
    `;
    openModal(`Track — ${name}`, html, "rider-track", row.riderId);
    modalSave.style.display = "none";
    modalCancel.textContent = "Close";

    const mapEl = document.getElementById("ongoing-rider-map");
    if (!mapEl) return;

    let maps;
    try {
      maps = await ensureGoogleMaps();
    } catch (err) {
      mapEl.innerHTML = `<div class="empty-state">${escapeHtml(err.message || String(err))}</div>`;
      return;
    }
    if (modalMode !== "rider-track") return;

    const defaultCenter = { lat: 6.9271, lng: 79.8612 };
    riderTrackMap = new maps.Map(mapEl, {
      center: defaultCenter,
      zoom: 13,
      mapTypeControl: false,
      streetViewControl: false,
      fullscreenControl: true,
    });

    if (row.pickupLL) {
      riderTrackPickupMarker = new maps.Marker({
        map: riderTrackMap,
        position: row.pickupLL,
        title: "Pickup",
        label: "P",
      });
    }
    if (row.dropoffLL) {
      riderTrackDropoffMarker = new maps.Marker({
        map: riderTrackMap,
        position: row.dropoffLL,
        title: "Dropoff",
        label: "D",
      });
    }

    const applyLoc = (loc, fromFallback) => {
      const ll = loc ? readLatLng(loc) : null;
      const position = ll || (fromFallback ? fallbackRiderLatLng(row.riderId) : null);
      if (!position) {
        updateRiderTrackMeta(loc);
        const meta = document.getElementById("ongoing-rider-map-meta");
        if (meta && !ll) {
          meta.innerHTML = `<span class="ongoing-map-stale">No live GPS yet for this rider</span>`;
        }
        fitTrackMapBounds(maps, null);
        return;
      }
      if (!riderTrackRiderMarker) {
        riderTrackRiderMarker = new maps.Marker({
          map: riderTrackMap,
          position,
          title: name,
          label: "R",
        });
        fitTrackMapBounds(maps, position);
      } else {
        riderTrackRiderMarker.setPosition(position);
      }
      updateRiderTrackMeta(loc || { locationUpdatedAt: null });
    };

    const fallback = fallbackRiderLatLng(row.riderId);
    if (fallback) applyLoc({ latitude: fallback.lat, longitude: fallback.lng }, true);

    riderTrackUnsub = db
      .collection(COL.riderLocations)
      .doc(row.riderId)
      .onSnapshot(
        (snap) => {
          if (!snap.exists) {
            applyLoc(null, true);
            return;
          }
          applyLoc({ id: snap.id, ...snap.data() }, false);
        },
        (err) => {
          toast(err.message || String(err), "error");
        }
      );
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
          <td><span class="badge ${badgeClass(stRaw)}${readyAttention}">${escapeHtml(statusLabel(stRaw))}</span>${missedByShopBadge(o)}</td>
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
          <td><span class="badge ${badgeClass(stRaw)}${readyAttention}">${escapeHtml(statusLabel(stRaw))}</span>${missedByShopBadge(o)}</td>
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

  function renderOfferApprovals() {
    const tbody = document.querySelector("#table-offer-approvals tbody");
    if (!tbody) return;
    const pending = cache.offers.filter(
      (o) => String(o.status || "").toLowerCase() === "pending"
    );
    tbody.innerHTML =
      pending.length === 0
        ? `<tr><td colspan="6"><div class="empty-state">No offers waiting for approval.</div></td></tr>`
        : pending
            .map((o) => {
              const img = (o.imageUrl || "").trim();
              const thumb = img
                ? `<img src="${escapeHtml(img)}" alt="" style="width:48px;height:48px;object-fit:cover;border-radius:8px" />`
                : "—";
              return `<tr>
        <td>
          <div style="display:flex;gap:10px;align-items:center">
            ${thumb}
            <div>
              <strong>${escapeHtml(o.title || "—")}</strong>
              <br/><small style="color:var(--muted)"><code>${escapeHtml(o.id)}</code></small>
            </div>
          </div>
        </td>
        <td>${escapeHtml(o.storeName || o.storeId || "—")}<br/><small style="color:var(--muted)"><code>${escapeHtml(o.storeId || "")}</code></small></td>
        <td>LKR ${Number(o.priceLkr) || 0}</td>
        <td>${escapeHtml(fmtTs(o.endsAt))}</td>
        <td>${escapeHtml(fmtTs(o.createdAt))}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-primary btn-sm" data-approve-offer="${escapeHtml(o.id)}">Approve</button>
          <button type="button" class="btn btn-ghost btn-sm" data-reject-offer="${escapeHtml(o.id)}">Reject</button>
        </td>
      </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-approve-offer]").forEach((btn) => {
      btn.addEventListener("click", () => approveOffer(btn.getAttribute("data-approve-offer")));
    });
    tbody.querySelectorAll("[data-reject-offer]").forEach((btn) => {
      btn.addEventListener("click", () => rejectOffer(btn.getAttribute("data-reject-offer")));
    });
  }

  function renderOffers() {
    const tbody = document.querySelector("#table-offers tbody");
    if (!tbody) return;
    const filter = (document.getElementById("offers-status-filter")?.value || "all").toLowerCase();
    let list = [...cache.offers];
    if (filter !== "all") {
      list = list.filter((o) => offerDisplayStatus(o) === filter);
    }
    list.sort((a, b) => {
      const ta = a.createdAt?.toMillis?.() || 0;
      const tb = b.createdAt?.toMillis?.() || 0;
      return tb - ta;
    });
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="7"><div class="empty-state">No offers match this filter.</div></td></tr>`
        : list
            .map((o) => {
              const status = offerDisplayStatus(o);
              const img = (o.imageUrl || "").trim();
              const thumb = img
                ? `<img src="${escapeHtml(img)}" alt="" style="width:44px;height:44px;object-fit:cover;border-radius:8px" />`
                : "—";
              const rejectNote =
                status === "rejected" && o.rejectionReason
                  ? `<br/><small style="color:var(--muted)">${escapeHtml(o.rejectionReason)}</small>`
                  : "";
              return `<tr>
        <td>${thumb}</td>
        <td><strong>${escapeHtml(o.title || "—")}</strong><br/><small style="color:var(--muted)"><code>${escapeHtml(o.id)}</code></small></td>
        <td>${escapeHtml(o.storeName || o.storeId || "—")}</td>
        <td>LKR ${Number(o.priceLkr) || 0}</td>
        <td><span class="badge">${escapeHtml(status)}</span>${rejectNote}</td>
        <td>${escapeHtml(fmtTs(o.endsAt))}</td>
        <td class="row-actions">
          ${
            status === "pending"
              ? `<button type="button" class="btn btn-primary btn-sm" data-approve-offer="${escapeHtml(o.id)}">Approve</button>
                 <button type="button" class="btn btn-ghost btn-sm" data-reject-offer="${escapeHtml(o.id)}">Reject</button>`
              : ""
          }
          ${
            status === "approved"
              ? `<button type="button" class="btn btn-ghost btn-sm" data-reject-offer="${escapeHtml(o.id)}">Unpublish</button>`
              : ""
          }
          <button type="button" class="btn btn-ghost btn-sm" data-del-offer="${escapeHtml(o.id)}">Delete</button>
        </td>
      </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-approve-offer]").forEach((btn) => {
      btn.addEventListener("click", () => approveOffer(btn.getAttribute("data-approve-offer")));
    });
    tbody.querySelectorAll("[data-reject-offer]").forEach((btn) => {
      btn.addEventListener("click", () => rejectOffer(btn.getAttribute("data-reject-offer")));
    });
    tbody.querySelectorAll("[data-del-offer]").forEach((btn) => {
      btn.addEventListener("click", () => deleteOffer(btn.getAttribute("data-del-offer")));
    });
  }

  async function approveOffer(id) {
    if (!id || !auth.currentUser) return;
    try {
      await db.collection(COL.offers).doc(id).update({
        status: "approved",
        approvedAt: firebase.firestore.FieldValue.serverTimestamp(),
        approvedBy: auth.currentUser.uid,
        rejectionReason: firebase.firestore.FieldValue.delete(),
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });
      toast("Offer approved", "success");
      await loadOffers();
      renderOfferApprovals();
      renderOffers();
    } catch (err) {
      alert(err.message || String(err));
    }
  }

  async function rejectOffer(id) {
    if (!id) return;
    const reason = window.prompt("Rejection reason (optional):", "") || "";
    try {
      await db.collection(COL.offers).doc(id).update({
        status: "rejected",
        rejectionReason: reason.trim() || firebase.firestore.FieldValue.delete(),
        approvedAt: firebase.firestore.FieldValue.delete(),
        approvedBy: firebase.firestore.FieldValue.delete(),
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });
      toast("Offer rejected / unpublished", "success");
      await loadOffers();
      renderOfferApprovals();
      renderOffers();
    } catch (err) {
      alert(err.message || String(err));
    }
  }

  async function deleteOffer(id) {
    if (!id) return;
    if (!window.confirm("Delete this offer permanently? Sale history will be lost.")) return;
    try {
      await db.collection(COL.offers).doc(id).delete();
      toast("Offer deleted", "success");
      await loadOffers();
      renderOfferApprovals();
      renderOffers();
    } catch (err) {
      alert(err.message || String(err));
    }
  }

  function renderShopCategories() {
    const tbody = document.querySelector("#table-shop-categories tbody");
    if (!tbody) return;
    const list = [...cache.shopCategories].sort(
      (a, b) => (Number(a.order) || 0) - (Number(b.order) || 0)
    );
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="5"><div class="empty-state">No categories. Add Food / Grocery first, then shop types.</div></td></tr>`
        : list
            .map((c) => {
              const active = c.active !== false;
              const isGrocery = c.isGrocery === true;
              return `<tr>
        <td>${escapeHtml(c.label || "—")}</td>
        <td>${Number(c.order) || 0}</td>
        <td><label style="display:flex;align-items:center;gap:6px;cursor:pointer"><input type="checkbox" data-shop-category-active="${escapeHtml(c.id)}" ${active ? "checked" : ""} /> <span>${active ? "Shown" : "Hidden"}</span></label></td>
        <td><label style="display:flex;align-items:center;gap:6px;cursor:pointer"><input type="checkbox" data-shop-category-grocery="${escapeHtml(c.id)}" ${isGrocery ? "checked" : ""} /> <span>${isGrocery ? "Grocery" : "Food"}</span></label></td>
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
    tbody.querySelectorAll("[data-shop-category-grocery]").forEach((input) => {
      input.addEventListener("change", async (e) => {
        const id = e.target.getAttribute("data-shop-category-grocery");
        const span = e.target.closest("label")?.querySelector("span");
        try {
          await db.collection(COL.shopCategories).doc(id).update({ isGrocery: !!e.target.checked });
          if (span) span.textContent = e.target.checked ? "Grocery" : "Food";
          await loadShopCategories();
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

  const DEFAULT_GROCERY_AISLES = [
    "Fresh Produce",
    "Dairy",
    "Bakery",
    "Beverages",
    "Snacks",
    "Household",
    "Personal Care",
    "Other",
  ];

  function renderGroceryAisles() {
    const tbody = document.querySelector("#table-grocery-aisles tbody");
    if (!tbody) return;
    const list = [...cache.groceryAisles].sort(
      (a, b) => (Number(a.order) || 0) - (Number(b.order) || 0)
    );
    const seedBtn = document.getElementById("btn-seed-grocery-aisles");
    if (seedBtn) seedBtn.hidden = list.length > 0;
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="4"><div class="empty-state">No aisles yet. Add labels or click <strong>Seed defaults</strong>.</div></td></tr>`
        : list
            .map((a) => {
              const active = a.active !== false;
              return `<tr>
        <td>${escapeHtml(a.label || "—")}</td>
        <td>${Number(a.order) || 0}</td>
        <td><label style="display:flex;align-items:center;gap:6px;cursor:pointer"><input type="checkbox" data-grocery-aisle-active="${escapeHtml(a.id)}" ${active ? "checked" : ""} /> <span>${active ? "Shown" : "Hidden"}</span></label></td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-edit-grocery-aisle="${escapeHtml(a.id)}">Edit</button>
          <button type="button" class="btn btn-ghost btn-sm" data-del-grocery-aisle="${escapeHtml(a.id)}">Delete</button>
        </td>
      </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-grocery-aisle-active]").forEach((input) => {
      input.addEventListener("change", async (e) => {
        const id = e.target.getAttribute("data-grocery-aisle-active");
        const row = cache.groceryAisles.find((x) => x.id === id);
        const span = e.target.closest("label")?.querySelector("span");
        try {
          await db.collection(COL.groceryAisles).doc(id).update({
            label: String(row?.label || "").trim() || "Aisle",
            order: Number(row?.order) || 0,
            active: !!e.target.checked,
          });
          if (span) span.textContent = e.target.checked ? "Shown" : "Hidden";
          await loadGroceryAisles();
        } catch (err) {
          alert(err.message || String(err));
          e.target.checked = !e.target.checked;
        }
      });
    });
    tbody.querySelectorAll("[data-edit-grocery-aisle]").forEach((btn) => {
      btn.addEventListener("click", () => editGroceryAisle(btn.getAttribute("data-edit-grocery-aisle")));
    });
    tbody.querySelectorAll("[data-del-grocery-aisle]").forEach((btn) => {
      btn.addEventListener("click", () => deleteGroceryAisle(btn.getAttribute("data-del-grocery-aisle")));
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

  function renderJobReports() {
    const tbody = document.querySelector("#table-job-reports tbody");
    if (!tbody) return;
    const list = cache.jobReports;
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="5"><div class="empty-state">No reported jobs.</div></td></tr>`
        : list
            .map((r) => {
              const job = cache.jobs.find((x) => x.id === r.jobId);
              return `<tr>
        <td><strong>${escapeHtml(job ? job.title : r.jobId || "—")}</strong></td>
        <td>${escapeHtml(r.reason || "—")}</td>
        <td>${escapeHtml(r.reporterId || "—")}</td>
        <td>${escapeHtml(fmtTs(r.createdAt))}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-dismiss-job-report="${escapeHtml(r.id)}">Dismiss</button>
        </td>
      </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-dismiss-job-report]").forEach((btn) => {
      btn.addEventListener("click", () => dismissJobReport(btn.getAttribute("data-dismiss-job-report")));
    });
  }

  async function dismissJobReport(id) {
    if (!id) return;
    try {
      await db.collection(COL.jobReports).doc(id).delete();
      cache.jobReports = cache.jobReports.filter((r) => r.id !== id);
      renderJobReports();
      toast("Report dismissed.", "success");
    } catch (err) {
      alert(err.message || String(err));
    }
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
        ? `<tr><td colspan="8"><div class="empty-state">No riders.</div></td></tr>`
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
        <td>${riderCashCell(r)}</td>
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
        ? `<tr><td colspan="6"><div class="empty-state">No customer profiles.</div></td></tr>`
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
        <td><strong>${escapeHtml(String(jobPostCreditsOf(u)))}</strong></td>
        <td>${escapeHtml(fmtTs(u.createdAt))}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-view-customer="${escapeHtml(u.id)}">View</button>
          <button type="button" class="btn btn-primary btn-sm" data-grant-credits="${escapeHtml(u.id)}">Grant credits</button>
          <button type="button" class="btn btn-ghost btn-sm" data-del-customer="${escapeHtml(u.id)}">Delete</button>
        </td>
      </tr>`
            )
            .join("");
    tbody.querySelectorAll("[data-view-customer]").forEach((btn) => {
      btn.addEventListener("click", () => openCustomerView(btn.getAttribute("data-view-customer")));
    });
    tbody.querySelectorAll("[data-grant-credits]").forEach((btn) => {
      btn.addEventListener("click", () => promptGrantJobCredits(btn.getAttribute("data-grant-credits")));
    });
    tbody.querySelectorAll("[data-del-customer]").forEach((btn) => {
      btn.addEventListener("click", () => deleteCustomer(btn.getAttribute("data-del-customer")));
    });
  }

  function jobPostCreditsOf(u) {
    const n = Number(u?.jobPostCredits);
    return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
  }

  async function promptGrantJobCredits(uid) {
    if (!uid || !auth.currentUser) return;
    const u = cache.customers.find((x) => x.id === uid);
    const current = jobPostCreditsOf(u);
    const name = u ? customerDisplayName(u) : uid;
    const raw = window.prompt(
      `Grant job post credits to ${name}\nCurrent credits: ${current}\nEnter amount to add (1, 5, 10, or 20):`,
      "5"
    );
    if (raw == null) return;
    const amount = Number(String(raw).trim());
    if (![1, 5, 10, 20].includes(amount)) {
      toast("Choose 1, 5, 10, or 20 credits.", "warning");
      return;
    }
    try {
      await db.collection(COL.customers).doc(uid).set(
        {
          jobPostCredits: firebase.firestore.FieldValue.increment(amount),
          jobPostCreditsUpdatedAt: firebase.firestore.FieldValue.serverTimestamp(),
          jobPostCreditsUpdatedBy: auth.currentUser.uid,
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      toast(`Granted ${amount} job credit(s).`, "success");
      await loadCustomers();
      if (currentView === "customers") renderCustomers();
    } catch (err) {
      console.error(err);
      toast(err?.message || "Could not grant credits.", "error");
    }
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
          <div><span>Job credits</span><strong>${escapeHtml(String(jobPostCreditsOf(u)))}</strong></div>
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
              ${orderDetailLine("Job credits", String(jobPostCreditsOf(u)))}
              ${orderDetailLine("Joined", fmtTs(u.createdAt))}
              ${orderDetailLine("Updated", fmtTs(u.updatedAt))}
              ${orderDetailLine("Profile ID", u.id)}
            </section>

            <section class="customer-profile-section">
              <h5>Job membership</h5>
              <p class="customer-profile-note">Grant job post credits after offline payment. Each posted job uses 1 credit.</p>
              <div class="row-actions" style="margin-top:8px;flex-wrap:wrap;gap:6px">
                <button type="button" class="btn btn-primary btn-sm" data-grant-credits-modal="${escapeHtml(u.id)}">Grant credits</button>
              </div>
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
    document.querySelectorAll("[data-grant-credits-modal]").forEach((btn) => {
      btn.addEventListener("click", () => promptGrantJobCredits(btn.getAttribute("data-grant-credits-modal")));
    });
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

  const PRODUCT_FOOD_ETA_PRESETS = [
    "5-10 min",
    "10-15 min",
    "15-20 min",
    "20-30 min",
    "30-45 min",
    "45-60 min",
    "1 hr",
  ];
  const PRODUCT_GROCERY_ETA_PRESETS = [
    "Ready now",
    "15-30 min",
    "30-60 min",
    "Same day",
  ];
  const PRODUCT_SIZE_LABELS = ["Small", "Medium", "Large"];
  const PRODUCT_PACK_LABELS = ["250g", "500g", "1kg", "1L", "Pack of 6", "Pack of 12"];
  const PRODUCT_MAX_FOOD = 30;
  const PRODUCT_MAX_GROCERY = 100;
  const PRODUCT_ETA_CUSTOM = "__eta_custom__";

  /** @type {{ storeId: string, storeName: string, isGrocery: boolean }} */
  let productModalCtx = { storeId: "", storeName: "", isGrocery: false };

  function vendorFieldText(raw) {
    if (raw == null) return "";
    if (typeof raw === "string") return raw.trim();
    return String(raw).trim();
  }

  function textLooksGrocery(raw) {
    const t = String(raw || "")
      .toLowerCase()
      .trim();
    if (!t) return false;
    return (
      t.includes("groc") ||
      t.includes("grosery") ||
      t.includes("grocary") ||
      t.includes("supermarket") ||
      t.includes("hypermarket") ||
      t.includes("pharmacy") ||
      t.includes("convenience") ||
      t.includes("mini mart") ||
      t.includes("minimart") ||
      t.includes("mini-mart") ||
      t === "mart" ||
      t.endsWith(" mart") ||
      t === "fresh produce" ||
      t.includes("fresh produce") ||
      (t.includes("dairy") && t.includes("store"))
    );
  }

  /** Mirror mnd_shop `isGroceryVendorDoc`. */
  function isGroceryVendorDoc(map) {
    if (!map || typeof map !== "object") return false;
    const kind = vendorFieldText(map.catalogKind).toLowerCase();
    if (kind === "grocery" || kind === "groc") return true;
    const category = vendorFieldText(map.category);
    const tag = vendorFieldText(map.tag);
    const name = vendorFieldText(map.name) || vendorFieldText(map.displayName);
    if (textLooksGrocery(category) || textLooksGrocery(tag) || textLooksGrocery(name)) {
      return true;
    }
    if (kind === "food" || kind === "restaurant" || kind === "resto") return false;
    return false;
  }

  function groceryAisleLabelsForForm() {
    const fromCache = [...(cache.groceryAisles || [])]
      .filter((a) => a.active !== false)
      .sort((a, b) => (Number(a.order) || 0) - (Number(b.order) || 0))
      .map((a) => String(a.label || "").trim())
      .filter(Boolean);
    return fromCache.length ? fromCache : DEFAULT_GROCERY_AISLES.slice();
  }

  function parseProductSizeOptions(raw) {
    if (!Array.isArray(raw)) return [];
    const out = [];
    for (const row of raw) {
      if (!row || typeof row !== "object") continue;
      const name = String(row.name || "").trim();
      if (!name) continue;
      const p = row.priceLkr ?? row.price;
      let lkr = 0;
      if (typeof p === "number") lkr = Math.round(p);
      else if (typeof p === "string") {
        lkr = parseInt(p.replace(/[^\d]/g, ""), 10) || 0;
      }
      out.push({ name, priceLkr: Math.max(0, lkr) });
    }
    return out;
  }

  function inferProductPriceKind(options, isGrocery) {
    if (isGrocery) return "pack";
    if (!options.length) return "size";
    const names = options.map((o) => o.name);
    if (names.every((n) => PRODUCT_SIZE_LABELS.includes(n))) return "size";
    if (
      names.some(
        (n) => n === "Single portion" || /^\d+\s*person$/i.test(n)
      )
    ) {
      return "portion";
    }
    if (
      names.some((n) =>
        ["Half", "Full", "Half plate", "Full plate"].includes(n)
      )
    ) {
      return "half";
    }
    if (names.every((n) => PRODUCT_PACK_LABELS.includes(n))) return "pack";
    return "size";
  }

  function productShopSelectOptionsHtml(selectedId) {
    const options = productShopFilterOptions();
    return (
      `<option value="">Select shop…</option>` +
      options
        .map(([id, label]) => {
          const v = cache.vendors.find((x) => x.id === id);
          const kind = v && isGroceryVendorDoc(v) ? "Grocery" : "Food";
          const sel = id === selectedId ? " selected" : "";
          return `<option value="${escapeHtml(id)}"${sel}>${escapeHtml(label)} (${kind})</option>`;
        })
        .join("")
    );
  }

  function updateProductShopKindBadge() {
    const sel = document.getElementById("f-p-shop");
    const badge = document.getElementById("f-p-shop-kind");
    if (!sel || !badge) return;
    const id = sel.value.trim();
    if (!id) {
      badge.hidden = true;
      badge.textContent = "";
      return;
    }
    const v = vendorById(id);
    const grocery = isGroceryVendorDoc(v);
    badge.hidden = false;
    badge.className =
      "product-kind-badge " +
      (grocery ? "product-kind-badge--grocery" : "product-kind-badge--food");
    badge.textContent = grocery ? "Grocery catalog" : "Food catalog";
  }

  function storageExtFromFile(file) {
    const name = String(file?.name || "").toLowerCase();
    if (name.endsWith(".png") || file?.type === "image/png") return "png";
    if (name.endsWith(".webp") || file?.type === "image/webp") return "webp";
    return "jpg";
  }

  async function uploadAdminProductImage(storeId, productId, file) {
    if (!file || !storeId || !productId) return "";
    const ext = storageExtFromFile(file);
    const contentType =
      ext === "png" ? "image/png" : ext === "webp" ? "image/webp" : "image/jpeg";
    const path = `vendor_products/${storeId}/${productId}.${ext}`;
    const ref = firebaseStorage().ref(path);
    await ref.put(file, { contentType });
    return ref.getDownloadURL();
  }

  function etaSelectHtml(presets, currentEta) {
    const eta = String(currentEta || "").trim();
    const isPreset = !eta || presets.includes(eta);
    const selected = isPreset ? eta || presets[0] || "" : PRODUCT_ETA_CUSTOM;
    const opts =
      presets
        .map(
          (p) =>
            `<option value="${escapeHtml(p)}"${p === selected ? " selected" : ""}>${escapeHtml(p)}</option>`
        )
        .join("") +
      `<option value="${PRODUCT_ETA_CUSTOM}"${selected === PRODUCT_ETA_CUSTOM ? " selected" : ""}>Custom…</option>`;
    return {
      selectHtml: opts,
      customValue: isPreset ? "" : eta,
      showCustom: selected === PRODUCT_ETA_CUSTOM,
    };
  }

  function presetPriceInputsHtml(labels, existingOptions) {
    const byName = new Map(existingOptions.map((o) => [o.name, o.priceLkr]));
    return labels
      .map((label, i) => {
        const val = byName.has(label) ? String(byName.get(label)) : "";
        return `<div class="product-option-row">
          <span class="product-option-label">${escapeHtml(label)}</span>
          <input type="number" min="0" step="1" class="f-p-preset-price" data-preset-label="${escapeHtml(label)}" data-preset-idx="${i}" value="${escapeHtml(val)}" placeholder="optional LKR">
        </div>`;
      })
      .join("");
  }

  function customOptionRowsHtml(rows) {
    if (!rows.length) return "";
    return rows
      .map(
        (r, i) => `<div class="product-option-row product-custom-row" data-custom-idx="${i}">
          <input type="text" class="f-p-custom-label" value="${escapeHtml(r.name || "")}" placeholder="Label">
          <input type="number" min="0" step="1" class="f-p-custom-price" value="${r.priceLkr != null ? escapeHtml(String(r.priceLkr)) : ""}" placeholder="LKR">
          <button type="button" class="btn btn-ghost btn-sm f-p-remove-custom" aria-label="Remove">×</button>
        </div>`
      )
      .join("");
  }

  function leftoverCustomOptions(options, isGrocery, priceKind) {
    const presetSet = new Set(
      isGrocery || priceKind === "pack"
        ? PRODUCT_PACK_LABELS
        : priceKind === "size"
          ? PRODUCT_SIZE_LABELS
          : priceKind === "portion"
            ? []
            : priceKind === "half"
              ? ["Half", "Full", "Half plate", "Full plate"]
              : []
    );
    if (priceKind === "portion") {
      return options.filter(
        (o) => o.name !== "Single portion" && !/^\d+\s*person$/i.test(o.name)
      );
    }
    if (priceKind === "half") {
      return options.filter((o) => !presetSet.has(o.name));
    }
    return options.filter((o) => !presetSet.has(o.name));
  }

  function portionFieldsFromOptions(options) {
    let single = "";
    let multiPersons = "2";
    let multiPrice = "";
    for (const o of options) {
      if (o.name === "Single portion") single = String(o.priceLkr);
      else {
        const m = o.name.match(/^(\d+)\s*person$/i);
        if (m) {
          multiPersons = m[1];
          multiPrice = String(o.priceLkr);
        }
      }
    }
    return { single, multiPersons, multiPrice };
  }

  function halfFieldsFromOptions(options) {
    const by = new Map(options.map((o) => [o.name, o.priceLkr]));
    return {
      half: by.has("Half")
        ? String(by.get("Half"))
        : by.has("Half plate")
          ? String(by.get("Half plate"))
          : "",
      full: by.has("Full")
        ? String(by.get("Full"))
        : by.has("Full plate")
          ? String(by.get("Full plate"))
          : "",
    };
  }

  function buildProductOptionsPanelHtml(isGrocery, existingOptions, priceKind) {
    const kind = isGrocery ? "pack" : priceKind || "size";
    let presetBlock = "";
    if (kind === "pack") {
      presetBlock = `<p class="form-hint">Enter LKR for each pack size you sell (leave blank to skip).</p>
        <div id="f-p-preset-prices">${presetPriceInputsHtml(PRODUCT_PACK_LABELS, existingOptions)}</div>`;
    } else if (kind === "size") {
      presetBlock = `<p class="form-hint">Enter LKR for each size you sell (leave blank to skip).</p>
        <div id="f-p-preset-prices">${presetPriceInputsHtml(PRODUCT_SIZE_LABELS, existingOptions)}</div>`;
    } else if (kind === "portion") {
      const pf = portionFieldsFromOptions(existingOptions);
      presetBlock = `<p class="form-hint">Price single portion and/or multi-person. Leave blank to skip.</p>
        <div id="f-p-preset-prices">
          <div class="product-option-row">
            <span class="product-option-label">Single portion</span>
            <input type="number" min="0" step="1" id="f-p-portion-single" value="${escapeHtml(pf.single)}" placeholder="optional LKR">
          </div>
          <div class="product-option-row product-option-row--portion-multi">
            <span class="product-option-label">Multi</span>
            <input type="number" min="1" max="99" step="1" id="f-p-portion-n" value="${escapeHtml(pf.multiPersons)}" title="Person count">
            <span class="product-option-suffix">person</span>
            <input type="number" min="0" step="1" id="f-p-portion-multi" value="${escapeHtml(pf.multiPrice)}" placeholder="optional LKR">
          </div>
        </div>`;
    } else {
      const hf = halfFieldsFromOptions(existingOptions);
      presetBlock = `<p class="form-hint">Enter LKR for Half and/or Full (leave blank to skip one).</p>
        <div id="f-p-preset-prices">
          <div class="product-option-row">
            <span class="product-option-label">Half</span>
            <input type="number" min="0" step="1" id="f-p-half" value="${escapeHtml(hf.half)}" placeholder="optional LKR">
          </div>
          <div class="product-option-row">
            <span class="product-option-label">Full</span>
            <input type="number" min="0" step="1" id="f-p-full" value="${escapeHtml(hf.full)}" placeholder="optional LKR">
          </div>
        </div>`;
    }
    const customs = leftoverCustomOptions(existingOptions, isGrocery, kind);
    return `${presetBlock}
      <div class="product-custom-head">
        <span>Custom options</span>
        <button type="button" class="btn btn-ghost btn-sm" id="f-p-add-custom">+ Add</button>
      </div>
      <div id="f-p-custom-options">${customOptionRowsHtml(customs)}</div>`;
  }

  function wireProductFormInteractions() {
    const modeToggle = document.getElementById("f-p-price-mode");
    const singleWrap = document.getElementById("f-p-single-price-wrap");
    const optionsWrap = document.getElementById("f-p-options-wrap");
    const kindSel = document.getElementById("f-p-price-kind");
    const optionsPanel = document.getElementById("f-p-options-panel");
    const stockToggle = document.getElementById("f-p-manage-stock");
    const stockWrap = document.getElementById("f-p-stock-wrap");
    const etaSel = document.getElementById("f-p-eta-sel");
    const etaCustom = document.getElementById("f-p-eta-custom");
    const fileInput = document.getElementById("f-p-file");
    const imgPreview = document.getElementById("f-p-img-preview");
    const imgUrl = document.getElementById("f-p-img");
    const backBtn = document.getElementById("btn-product-back");

    const refreshOptionsPanel = () => {
      if (!optionsPanel) return;
      const isGrocery = productModalCtx.isGrocery;
      const kind = isGrocery
        ? "pack"
        : kindSel
          ? kindSel.value
          : "size";
      optionsPanel.innerHTML = buildProductOptionsPanelHtml(isGrocery, [], kind);
      wireCustomOptionButtons();
    };

    const syncPriceMode = () => {
      const optionsMode = modeToggle && modeToggle.value === "options";
      if (singleWrap) singleWrap.hidden = !!optionsMode;
      if (optionsWrap) optionsWrap.hidden = !optionsMode;
    };

    modeToggle?.addEventListener("change", () => {
      syncPriceMode();
      if (modeToggle.value === "options") refreshOptionsPanel();
    });
    kindSel?.addEventListener("change", refreshOptionsPanel);
    stockToggle?.addEventListener("change", () => {
      if (stockWrap) stockWrap.hidden = !stockToggle.checked;
    });
    etaSel?.addEventListener("change", () => {
      if (!etaCustom) return;
      const custom = etaSel.value === PRODUCT_ETA_CUSTOM;
      etaCustom.hidden = !custom;
      if (custom) etaCustom.focus();
    });
    fileInput?.addEventListener("change", () => {
      const file = fileInput.files && fileInput.files[0];
      if (!file || !imgPreview) return;
      const url = URL.createObjectURL(file);
      imgPreview.src = url;
      imgPreview.hidden = false;
    });
    imgUrl?.addEventListener("change", () => {
      const u = imgUrl.value.trim();
      if (imgPreview && u && !(fileInput?.files && fileInput.files[0])) {
        imgPreview.src = u;
        imgPreview.hidden = false;
      }
    });
    backBtn?.addEventListener("click", () => {
      openProductShopStep(productModalCtx.storeId || null);
    });

    wireCustomOptionButtons();
    syncPriceMode();
  }

  function wireCustomOptionButtons() {
    document.getElementById("f-p-add-custom")?.addEventListener("click", () => {
      const box = document.getElementById("f-p-custom-options");
      if (!box) return;
      const wrap = document.createElement("div");
      wrap.className = "product-option-row product-custom-row";
      wrap.innerHTML = `<input type="text" class="f-p-custom-label" placeholder="Label">
        <input type="number" min="0" step="1" class="f-p-custom-price" placeholder="LKR">
        <button type="button" class="btn btn-ghost btn-sm f-p-remove-custom" aria-label="Remove">×</button>`;
      box.appendChild(wrap);
      wrap.querySelector(".f-p-remove-custom")?.addEventListener("click", () => wrap.remove());
    });
    document.querySelectorAll(".f-p-remove-custom").forEach((btn) => {
      btn.addEventListener("click", () => btn.closest(".product-custom-row")?.remove());
    });
  }

  function collectSizeOptionsFromForm(isGrocery) {
    const mode = document.getElementById("f-p-price-mode")?.value;
    if (mode !== "options") return [];
    const kind = isGrocery
      ? "pack"
      : document.getElementById("f-p-price-kind")?.value || "size";
    const built = [];
    const pushOpt = (name, raw) => {
      const label = String(name || "").trim();
      if (!label) return;
      const t = String(raw ?? "").trim();
      if (t === "") return;
      const n = Number(t);
      if (!Number.isFinite(n) || n < 0 || !Number.isInteger(n)) {
        throw new Error(`Invalid LKR for “${label}” (whole number ≥ 0).`);
      }
      built.push({ name: label, priceLkr: n });
    };

    if (kind === "pack" || kind === "size") {
      document.querySelectorAll(".f-p-preset-price").forEach((inp) => {
        pushOpt(inp.getAttribute("data-preset-label"), inp.value);
      });
    } else if (kind === "portion") {
      pushOpt("Single portion", document.getElementById("f-p-portion-single")?.value);
      const multiRaw = document.getElementById("f-p-portion-multi")?.value;
      if (String(multiRaw ?? "").trim() !== "") {
        let n = parseInt(document.getElementById("f-p-portion-n")?.value || "2", 10);
        if (!Number.isFinite(n) || n < 1) n = 1;
        if (n > 99) n = 99;
        pushOpt(`${n} person`, multiRaw);
      }
    } else if (kind === "half") {
      pushOpt("Half", document.getElementById("f-p-half")?.value);
      pushOpt("Full", document.getElementById("f-p-full")?.value);
    }

    document.querySelectorAll(".product-custom-row").forEach((row) => {
      const label = row.querySelector(".f-p-custom-label")?.value;
      const price = row.querySelector(".f-p-custom-price")?.value;
      if (String(label || "").trim() || String(price || "").trim()) {
        pushOpt(label, price);
      }
    });

    const seen = new Set();
    for (const o of built) {
      const key = o.name.toLowerCase();
      if (seen.has(key)) throw new Error(`Duplicate option name: ${o.name}`);
      seen.add(key);
    }
    if (!built.length) {
      throw new Error("Enter at least one option price (or add a custom option).");
    }
    return built;
  }

  function collectProductFormPayload() {
    const storeId = productModalCtx.storeId || document.getElementById("f-p-sid")?.value?.trim() || "";
    const storeName =
      productModalCtx.storeName ||
      document.getElementById("f-p-sn")?.value?.trim() ||
      "";
    const isGrocery = !!productModalCtx.isGrocery;
    const name = document.getElementById("f-p-name")?.value?.trim() || "";
    const description = document.getElementById("f-p-desc")?.value?.trim() || "";
    let lookupKey = (document.getElementById("f-p-lk")?.value || "").trim().toLowerCase();
    const active = document.getElementById("f-p-act")?.value === "true";
    const imageUrl = document.getElementById("f-p-img")?.value?.trim() || "";
    const fileInput = document.getElementById("f-p-file");
    const file = fileInput?.files && fileInput.files[0] ? fileInput.files[0] : null;

    if (!name) throw new Error("Name required.");
    if (!storeId) throw new Error("Shop required.");

    let productCategory = "";
    let manageStock = false;
    let stockQty = 0;
    if (isGrocery) {
      productCategory = document.getElementById("f-p-aisle")?.value?.trim() || "";
      if (!productCategory) throw new Error("Select a product aisle.");
      manageStock = document.getElementById("f-p-manage-stock")?.checked === true;
      if (manageStock) {
        const raw = document.getElementById("f-p-stock")?.value;
        const n = Number(raw);
        if (!Number.isFinite(n) || n < 0 || !Number.isInteger(n)) {
          throw new Error("Stock qty must be a whole number ≥ 0.");
        }
        stockQty = n;
      }
    }

    const etaSel = document.getElementById("f-p-eta-sel");
    let eta = "";
    if (etaSel) {
      if (etaSel.value === PRODUCT_ETA_CUSTOM) {
        eta = document.getElementById("f-p-eta-custom")?.value?.trim() || "";
      } else {
        eta = etaSel.value.trim();
      }
    }
    if (!eta) throw new Error(isGrocery ? "Pick a ready time." : "Pick a prep time.");
    if (eta.length > 40) throw new Error("ETA must be 40 characters or less.");

    const optionsMode = document.getElementById("f-p-price-mode")?.value === "options";
    let sizeOptions = [];
    let price = 0;
    if (optionsMode) {
      sizeOptions = collectSizeOptionsFromForm(isGrocery);
      price = sizeOptions.reduce((min, o) => Math.min(min, o.priceLkr), sizeOptions[0].priceLkr);
    } else {
      const raw = document.getElementById("f-p-price")?.value;
      const n = Number(raw);
      if (!Number.isFinite(n) || n < 0 || !Number.isInteger(n)) {
        throw new Error("Price must be a whole number ≥ 0.");
      }
      price = n;
      sizeOptions = [];
    }

    return {
      storeId,
      storeName,
      isGrocery,
      name,
      description,
      lookupKey,
      active,
      imageUrl,
      file,
      productCategory,
      manageStock,
      stockQty,
      eta,
      price,
      sizeOptions,
    };
  }

  async function saveProductFromModal() {
    const payload = collectProductFormPayload();
    const max = payload.isGrocery ? PRODUCT_MAX_GROCERY : PRODUCT_MAX_FOOD;
    if (!modalEditId) {
      const count = (cache.products || []).filter((p) => p.storeId === payload.storeId).length;
      if (count >= max) {
        throw new Error(`Maximum ${max} products per shop.`);
      }
    }

    const ref = modalEditId
      ? db.collection(COL.products).doc(modalEditId)
      : db.collection(COL.products).doc();
    const productId = ref.id;

    let imageUrl = payload.imageUrl;
    if (payload.file) {
      imageUrl = await uploadAdminProductImage(payload.storeId, productId, payload.file);
    }

    let lookupKey = payload.lookupKey;
    if (!lookupKey) lookupKey = productId.toLowerCase();

    const data = {
      storeId: payload.storeId,
      storeName: payload.storeName || "",
      name: payload.name,
      description: payload.description,
      price: payload.price,
      imageUrl: imageUrl || "",
      lookupKey,
      active: payload.active,
      stockQty: payload.manageStock ? payload.stockQty : modalEditId ? Number(cache.products.find((x) => x.id === modalEditId)?.stockQty) || 0 : 0,
      manageStock: payload.manageStock,
      eta: payload.eta,
      productCategory: payload.productCategory,
      sizeOptions: payload.sizeOptions.map((o) => ({
        name: o.name,
        priceLkr: o.priceLkr,
      })),
    };

    await ref.set(data, { merge: true });
  }

  function openProductShopStep(prefillStoreId) {
    const filterSel = document.getElementById("filter-product-shop");
    const selected =
      prefillStoreId ||
      (filterSel && filterSel.value ? filterSel.value : "") ||
      "";
    modalSave.textContent = "Next";
    modalSave.style.display = "inline-flex";
    openModal(
      "New product — select shop",
      `<div class="product-form product-form--shop" data-product-step="shop">
        <p class="form-hint">Choose the shop first. The form will match food or grocery catalogs like the vendor app.</p>
        <div class="form-group">
          <label for="f-p-shop">Shop</label>
          <select id="f-p-shop" required>${productShopSelectOptionsHtml(selected)}</select>
        </div>
        <div id="f-p-shop-kind" class="product-kind-badge" hidden></div>
      </div>`,
      "product-pick-shop",
      null
    );
    updateProductShopKindBadge();
    document.getElementById("f-p-shop")?.addEventListener("change", updateProductShopKindBadge);
  }

  function openProductFormStep(storeId, product) {
    const vendor = vendorById(storeId);
    const isGrocery =
      isGroceryVendorDoc(vendor) ||
      (!vendor &&
        (String(product?.productCategory || "").trim() !== "" ||
          product?.manageStock === true));
    const storeName =
      (vendor && (vendor.name || vendor.displayName)) ||
      product?.storeName ||
      product?.vendorName ||
      storeId;
    productModalCtx = {
      storeId,
      storeName: String(storeName || "").trim(),
      isGrocery,
    };

    const existingOptions = parseProductSizeOptions(product?.sizeOptions);
    const optionsMode = existingOptions.length > 0;
    const priceKind = inferProductPriceKind(existingOptions, isGrocery);
    const aisles = groceryAisleLabelsForForm();
    const aisleVal = String(product?.productCategory || "").trim();
    const etaPresets = isGrocery ? PRODUCT_GROCERY_ETA_PRESETS : PRODUCT_FOOD_ETA_PRESETS;
    const etaInfo = etaSelectHtml(etaPresets, product?.eta || "");
    const imgVal = product ? productDisplayImageUrl(product) || String(product.imageUrl || "").trim() : "";
    const manageStock = product?.manageStock === true;
    const stockQty =
      product && product.manageStock ? String(Number(product.stockQty) || 0) : "0";
    const title = product
      ? isGrocery
        ? "Edit grocery item"
        : "Edit product"
      : isGrocery
        ? "Add grocery item"
        : "Add product";
    const aisleOptions =
      aisles
        .map((a) => {
          const sel = a === aisleVal ? " selected" : "";
          return `<option value="${escapeHtml(a)}"${sel}>${escapeHtml(a)}</option>`;
        })
        .join("") +
      (aisleVal && !aisles.includes(aisleVal)
        ? `<option value="${escapeHtml(aisleVal)}" selected>${escapeHtml(aisleVal)}</option>`
        : "");

    const groceryBanner = isGrocery
      ? `<div class="product-form-banner">Grocery catalog — aisle, optional stock, pack sizes</div>`
      : "";
    const groceryFields = isGrocery
      ? `<div class="form-group">
          <label for="f-p-aisle">Aisle</label>
          <select id="f-p-aisle" required>
            <option value="">Select aisle…</option>
            ${aisleOptions}
          </select>
        </div>
        <div class="form-group">
          <label class="product-check-label">
            <input type="checkbox" id="f-p-manage-stock"${manageStock ? " checked" : ""}>
            Manage stock
          </label>
        </div>
        <div class="form-group" id="f-p-stock-wrap"${manageStock ? "" : " hidden"}>
          <label for="f-p-stock">Stock qty</label>
          <input type="number" id="f-p-stock" min="0" step="1" value="${escapeHtml(stockQty)}">
        </div>`
      : "";

    const priceKindSelect = isGrocery
      ? `<input type="hidden" id="f-p-price-kind" value="pack">
         <p class="form-hint">Price by pack / weight</p>`
      : `<div class="form-group">
          <label for="f-p-price-kind">Price by</label>
          <select id="f-p-price-kind">
            <option value="size"${priceKind === "size" ? " selected" : ""}>Size</option>
            <option value="portion"${priceKind === "portion" ? " selected" : ""}>Portion</option>
            <option value="half"${priceKind === "half" ? " selected" : ""}>Half or full</option>
          </select>
        </div>`;

    const backBtn = product
      ? ""
      : `<button type="button" class="btn btn-ghost btn-sm" id="btn-product-back" style="width:auto;margin-bottom:12px">← Change shop</button>`;

    modalSave.textContent = "Save";
    modalSave.style.display = "inline-flex";
    openModal(
      title,
      `${backBtn}
      <div class="product-form" data-product-step="form">
        ${groceryBanner}
        <div class="form-group">
          <label>Shop</label>
          <input type="text" value="${escapeHtml(productModalCtx.storeName)}" disabled>
          <input type="hidden" id="f-p-sid" value="${escapeHtml(storeId)}">
          <input type="hidden" id="f-p-sn" value="${escapeHtml(productModalCtx.storeName)}">
        </div>
        <div class="form-group">
          <label>Catalog</label>
          <div class="product-kind-badge ${isGrocery ? "product-kind-badge--grocery" : "product-kind-badge--food"}">${isGrocery ? "Grocery" : "Food"}</div>
        </div>
        <div class="form-group">
          <label>Image</label>
          <img id="f-p-img-preview" class="product-form-preview" src="${escapeHtml(imgVal)}" alt="" ${imgVal ? "" : "hidden"}>
          <input type="file" id="f-p-file" accept="image/jpeg,image/png,image/webp">
          <input type="text" id="f-p-img" value="${escapeHtml(imgVal)}" placeholder="Or paste image URL" style="margin-top:8px">
        </div>
        <div class="form-group">
          <label for="f-p-name">Name</label>
          <input type="text" id="f-p-name" value="${escapeHtml(product?.name || "")}" required placeholder="${isGrocery ? "Brand / pack name" : "Dish name"}">
        </div>
        <div class="form-group">
          <label for="f-p-desc">Description</label>
          <textarea id="f-p-desc" rows="2" placeholder="${isGrocery ? "Pack size, storage notes…" : "Ingredients, spice level…"}">${escapeHtml(product?.description || "")}</textarea>
        </div>
        ${groceryFields}
        <div class="form-group">
          <label for="f-p-price-mode">Pricing</label>
          <select id="f-p-price-mode">
            <option value="single"${optionsMode ? "" : " selected"}>Single price</option>
            <option value="options"${optionsMode ? " selected" : ""}>${isGrocery ? "Pack / weight options" : "Size / portion options"}</option>
          </select>
        </div>
        <div id="f-p-single-price-wrap" class="form-group"${optionsMode ? " hidden" : ""}>
          <label for="f-p-price">Price (LKR)</label>
          <input type="number" id="f-p-price" min="0" step="1" value="${Number.isFinite(Number(product?.price)) ? Number(product.price) : 0}">
        </div>
        <div id="f-p-options-wrap"${optionsMode ? "" : " hidden"}>
          ${priceKindSelect}
          <div id="f-p-options-panel">${buildProductOptionsPanelHtml(isGrocery, existingOptions, priceKind)}</div>
        </div>
        <div class="form-group">
          <label for="f-p-eta-sel">${isGrocery ? "Ready time" : "ETA"}</label>
          <select id="f-p-eta-sel">${etaInfo.selectHtml}</select>
          <input type="text" id="f-p-eta-custom" maxlength="40" value="${escapeHtml(etaInfo.customValue)}" placeholder="Custom time" ${etaInfo.showCustom ? "" : "hidden"} style="margin-top:8px">
        </div>
        <div class="form-group">
          <label for="f-p-lk">Lookup key</label>
          <input type="text" id="f-p-lk" value="${escapeHtml(product?.lookupKey || "")}" placeholder="auto: doc id if empty">
        </div>
        <div class="form-group">
          <label for="f-p-act">Active</label>
          <select id="f-p-act">
            <option value="true">Yes</option>
            <option value="false"${product && product.active === false ? " selected" : ""}>No</option>
          </select>
        </div>
      </div>`,
      "product",
      product?.id || null
    );
    wireProductFormInteractions();
  }

  function advanceProductShopStep() {
    const sel = document.getElementById("f-p-shop");
    const storeId = sel?.value?.trim() || "";
    if (!storeId) throw new Error("Select a shop.");
    const vendor = vendorById(storeId);
    if (!vendor) throw new Error("Shop not found. Refresh and try again.");
    openProductFormStep(storeId, null);
  }

  function openProductModal(id) {
    const p = id ? cache.products.find((x) => x.id === id) : null;
    if (p) {
      const storeId = String(p.storeId || "").trim();
      if (!storeId) {
        toast("This product has no storeId.", "error");
        return;
      }
      openProductFormStep(storeId, p);
      return;
    }
    openProductShopStep(null);
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
              <h5>Cash in hand</h5>
              ${orderDetailLine("Collected, unsettled", fmtMoney(riderCashInHand(r)))}
              ${orderDetailLine("Owed to admin", fmtMoney(Number(r.cashOwedToAdminLkr) || 0))}
              ${orderDetailLine("Awaiting confirm", fmtMoney(Number(r.cashPendingSettlementLkr) || 0))}
              ${orderDetailLine("Accepting jobs", r.cashHoldActive === true ? "No — over the cash limit" : "Yes")}
              ${r.cashHoldActive === true ? orderDetailLine("On hold since", fmtTs(r.cashHoldSince)) : ""}
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
    if (modalMode === "product-pick-shop") {
      modalSave.disabled = true;
      try {
        advanceProductShopStep();
      } catch (e) {
        alert(e.message || String(e));
      } finally {
        modalSave.disabled = false;
      }
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
      await saveProductFromModal();
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

  // Routed through Cloud Function callables (not a raw Firestore write) so
  // there's a server-side audit trail (approvedBy/rejectedBy) and the same
  // action also fires the job-poster notification (onJobStatusUpdatedNotify).
  async function approveJob(id) {
    if (!id) return;
    try {
      await functionsClient.httpsCallable("approveJobPost")({ jobId: id });
      await refreshAfterJobChange();
      toast("Job published.", "success");
    } catch (err) {
      alert(err.message || String(err));
    }
  }

  async function rejectJob(id) {
    if (!id) return;
    const reason = prompt("Optional rejection note (or leave blank):", "");
    try {
      await functionsClient.httpsCallable("rejectJobPost")({
        jobId: id,
        note: reason ? String(reason).trim() : "",
      });
      await refreshAfterJobChange();
      toast("Job rejected.", "success");
    } catch (err) {
      alert(err.message || String(err));
    }
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

  async function deleteGroceryAisle(id) {
    if (!id) return;
    const row = cache.groceryAisles.find((x) => x.id === id);
    const label = row?.label || id;
    if (!confirm(`Delete grocery aisle "${label}"?`)) return;
    await db.collection(COL.groceryAisles).doc(id).delete();
    await loadGroceryAisles();
    renderGroceryAisles();
    toast("Aisle deleted", "success");
  }

  async function editGroceryAisle(id) {
    if (!id) return;
    const row = cache.groceryAisles.find((x) => x.id === id);
    if (!row) return;
    const nextLabel = window.prompt("Aisle label (1–80 characters)", String(row.label || ""));
    if (nextLabel === null) return;
    const label = String(nextLabel).trim();
    if (!label || label.length > 80) {
      toast("Enter a label (1–80 characters).", "warning");
      return;
    }
    const orderRaw = window.prompt("Order (number)", String(Number(row.order) || 0));
    if (orderRaw === null) return;
    const order = Number(orderRaw);
    if (!Number.isFinite(order)) {
      toast("Order must be a number.", "warning");
      return;
    }
    try {
      await db.collection(COL.groceryAisles).doc(id).update({
        label,
        order,
        active: row.active !== false,
      });
      await loadGroceryAisles();
      renderGroceryAisles();
      toast("Aisle updated", "success");
    } catch (err) {
      alert(err.message || String(err));
    }
  }

  async function addGroceryAisleFromWebForm() {
    const input = document.getElementById("grocery-aisle-new-label");
    const btn = document.getElementById("btn-add-grocery-aisle");
    const status = document.getElementById("grocery-aisle-save-status");
    if (!input || !btn) return;
    const label = String(input.value || "").trim();
    if (!label || label.length > 80) {
      toast("Enter an aisle label (1–80 characters).", "warning");
      return;
    }
    btn.disabled = true;
    if (status) status.textContent = "Saving…";
    try {
      let nextOrder = 0;
      try {
        const top = await db
          .collection(COL.groceryAisles)
          .orderBy("order", "desc")
          .limit(1)
          .get(FS_GET_SERVER);
        if (!top.empty) {
          const o = top.docs[0].data().order;
          if (typeof o === "number") nextOrder = o + 1;
        }
      } catch (_) {
        const snap = await db.collection(COL.groceryAisles).limit(200).get(FS_GET_SERVER);
        snap.docs.forEach((d) => {
          const o = Number(d.data().order) || 0;
          if (o >= nextOrder) nextOrder = o + 1;
        });
      }
      await db.collection(COL.groceryAisles).add({
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
      await loadGroceryAisles();
      renderGroceryAisles();
    } catch (err) {
      alert(err && err.message ? err.message : String(err));
      if (status) status.textContent = "";
    } finally {
      btn.disabled = false;
    }
  }

  async function seedGroceryAislesDefaults() {
    const btn = document.getElementById("btn-seed-grocery-aisles");
    const status = document.getElementById("grocery-aisle-save-status");
    await loadGroceryAisles();
    if (cache.groceryAisles.length > 0) {
      toast("Aisles already exist. Seed is only for an empty collection.", "warning");
      renderGroceryAisles();
      return;
    }
    if (!confirm("Add default grocery aisles (Fresh Produce, Dairy, …)?")) return;
    if (btn) btn.disabled = true;
    if (status) status.textContent = "Seeding…";
    try {
      const batch = db.batch();
      DEFAULT_GROCERY_AISLES.forEach((label, i) => {
        const ref = db.collection(COL.groceryAisles).doc();
        batch.set(ref, { label, order: i, active: true });
      });
      await batch.commit();
      if (status) {
        status.textContent = "Defaults saved.";
        setTimeout(() => {
          if (status) status.textContent = "";
        }, 2500);
      }
      await loadGroceryAisles();
      renderGroceryAisles();
      toast("Default aisles added", "success");
    } catch (err) {
      alert(err && err.message ? err.message : String(err));
      if (status) status.textContent = "";
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  async function addShopCategoryFromWebForm() {
    const input = document.getElementById("shop-category-new-label");
    const groceryInput = document.getElementById("shop-category-new-is-grocery");
    const btn = document.getElementById("btn-add-shop-category");
    const status = document.getElementById("shop-category-save-status");
    if (!input || !btn) return;
    const label = String(input.value || "").trim();
    const isGrocery = !!groceryInput?.checked;
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
        isGrocery,
      });
      input.value = "";
      if (groceryInput) groceryInput.checked = false;
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

  async function loadRatings() {
    try {
      const q = db.collection(COL.storeRatings).orderBy("createdAt", "desc").limit(300);
      const snap = await q.get(FS_GET_SERVER);
      cache.ratings = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.storeRatings).limit(300).get(FS_GET_SERVER);
      cache.ratings = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    }
  }

  function renderRatings() {
    const tbody = document.querySelector("#table-ratings tbody");
    if (!tbody) return;
    const q = (document.getElementById("filter-ratings")?.value || "").toLowerCase().trim();
    const starsFilter = document.getElementById("filter-rating-stars")?.value || "";
    const statusFilter = document.getElementById("filter-rating-status")?.value || "";
    let list = cache.ratings.slice();
    if (starsFilter) {
      const n = Number(starsFilter);
      list = list.filter((r) => Number(r.stars) === n);
    }
    if (statusFilter) {
      list = list.filter((r) => String(r.status || "").toLowerCase() === statusFilter);
    }
    if (q) {
      list = list.filter((r) => {
        const hay = [r.storeName, r.customerId, r.vendorId, r.comment, r.orderId, r.id]
          .map((x) => String(x || "").toLowerCase())
          .join(" ");
        return hay.includes(q);
      });
    }
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="7"><div class="empty-state">No ratings found.</div></td></tr>`
        : list
            .map((r) => {
              const status = String(r.status || "visible").toLowerCase();
              const stars = Number(r.stars) || 0;
              const clamped = Math.max(0, Math.min(5, stars));
              const starLabel = "★".repeat(clamped) + "☆".repeat(5 - clamped);
              const hideLabel = status === "hidden" ? "Unhide" : "Hide";
              const nextStatus = status === "hidden" ? "visible" : "hidden";
              return `<tr>
        <td>
          <strong>${escapeHtml(r.storeName || "—")}</strong><br>
          <code style="font-size:11px">${escapeHtml(r.vendorId || "")}</code>
        </td>
        <td><code>${escapeHtml(r.customerId || "—")}</code></td>
        <td title="${stars}/5">${escapeHtml(starLabel)} <span style="color:var(--muted)">${stars}</span></td>
        <td style="max-width:220px;white-space:normal">${escapeHtml(r.comment || "—")}</td>
        <td><span class="badge">${escapeHtml(status)}</span></td>
        <td>${escapeHtml(fmtTs(r.createdAt))}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-rating-status="${escapeHtml(nextStatus)}" data-rating-id="${escapeHtml(r.id)}">${hideLabel}</button>
          <button type="button" class="btn btn-ghost btn-sm" data-del-rating="${escapeHtml(r.id)}">Delete</button>
        </td>
      </tr>`;
            })
            .join("");
    tbody.querySelectorAll("[data-rating-status]").forEach((btn) => {
      btn.addEventListener("click", () =>
        setRatingStatus(btn.getAttribute("data-rating-id"), btn.getAttribute("data-rating-status"))
      );
    });
    tbody.querySelectorAll("[data-del-rating]").forEach((btn) => {
      btn.addEventListener("click", () => deleteRating(btn.getAttribute("data-del-rating")));
    });
  }

  async function setRatingStatus(id, status) {
    if (!id || !db) return;
    const next = status === "hidden" ? "hidden" : "visible";
    try {
      await db.collection(COL.storeRatings).doc(id).update({
        status: next,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });
      await loadRatings();
      renderRatings();
      toast(next === "hidden" ? "Rating hidden." : "Rating visible again.", "success");
    } catch (e) {
      toast(e.message || String(e), "error");
    }
  }

  async function deleteRating(id) {
    if (!id || !db) return;
    if (!confirm("Delete this rating permanently? Shop average will be recalculated.")) return;
    try {
      await db.collection(COL.storeRatings).doc(id).delete();
      await loadRatings();
      renderRatings();
      toast("Rating deleted.", "success");
    } catch (e) {
      toast(e.message || String(e), "error");
    }
  }

  function normalizeRideFareVehicle(raw, fallback) {
    const m = raw && typeof raw === "object" ? raw : {};
    const base = Math.floor(Number(m.baseLkr));
    const perKm = Math.floor(Number(m.perKmLkr));
    const min = Math.floor(Number(m.minLkr));
    // Older configs predate this field — fall back rather than reject.
    const perStop = m.perStopLkr === undefined ? NaN : Math.floor(Number(m.perStopLkr));
    return {
      baseLkr: Number.isFinite(base) && base >= 0 ? base : fallback.baseLkr,
      perKmLkr: Number.isFinite(perKm) && perKm >= 0 ? perKm : fallback.perKmLkr,
      minLkr: Number.isFinite(min) && min >= 0 ? min : fallback.minLkr,
      perStopLkr: Number.isFinite(perStop) && perStop >= 0 ? perStop : (fallback.perStopLkr ?? 0),
    };
  }

  function cloneDefaultRideFares() {
    return {
      bike: { ...DEFAULT_RIDE_FARES.bike },
      wheel: { ...DEFAULT_RIDE_FARES.wheel },
      car: { ...DEFAULT_RIDE_FARES.car },
    };
  }

  async function loadRideFares() {
    const snap = await db.collection(COL.rideFareConfig).doc("rates").get(FS_GET_SERVER);
    if (!snap.exists) {
      cache.rideFares = cloneDefaultRideFares();
      return;
    }
    const data = snap.data() || {};
    cache.rideFares = {
      bike: normalizeRideFareVehicle(data.bike, DEFAULT_RIDE_FARES.bike),
      wheel: normalizeRideFareVehicle(data.wheel, DEFAULT_RIDE_FARES.wheel),
      car: normalizeRideFareVehicle(data.car, DEFAULT_RIDE_FARES.car),
    };
  }

  function estimateRideFareLkr(rates, distanceKm, stopCount = 0) {
    const km = Math.max(0, Number(distanceKm) || 0);
    const stops = Math.max(0, Number(stopCount) || 0);
    const raw = rates.baseLkr + Math.ceil(km * rates.perKmLkr) + stops * (rates.perStopLkr || 0);
    return Math.max(rates.minLkr, raw);
  }

  function getRideFareSampleKm() {
    const el = document.getElementById("ride-fare-sample-km");
    const km = Number(el?.value);
    if (!Number.isFinite(km) || km <= 0) return 5;
    return km;
  }

  function getRideFareSampleStops() {
    const el = document.getElementById("ride-fare-sample-stops");
    const n = Number(el?.value);
    if (!Number.isFinite(n) || n < 0) return 0;
    return Math.min(2, Math.floor(n));
  }

  function updateRideFarePreviews() {
    const km = getRideFareSampleKm();
    const stops = getRideFareSampleStops();
    for (const v of RIDE_FARE_VEHICLES) {
      const baseEl = document.querySelector(`input[data-ride-fare="${v.id}"][data-field="baseLkr"]`);
      const perEl = document.querySelector(`input[data-ride-fare="${v.id}"][data-field="perKmLkr"]`);
      const minEl = document.querySelector(`input[data-ride-fare="${v.id}"][data-field="minLkr"]`);
      const perStopEl = document.querySelector(`input[data-ride-fare="${v.id}"][data-field="perStopLkr"]`);
      const preview = document.querySelector(`[data-ride-preview="${v.id}"]`);
      if (!preview) continue;
      const rates = {
        baseLkr: Math.floor(Number(baseEl?.value)),
        perKmLkr: Math.floor(Number(perEl?.value)),
        minLkr: Math.floor(Number(minEl?.value)),
        perStopLkr: Math.floor(Number(perStopEl?.value)),
      };
      if (
        !Number.isFinite(rates.baseLkr) ||
        !Number.isFinite(rates.perKmLkr) ||
        !Number.isFinite(rates.minLkr) ||
        !Number.isFinite(rates.perStopLkr)
      ) {
        preview.textContent = "—";
        continue;
      }
      preview.textContent = fmtMoney(estimateRideFareLkr(rates, km, stops));
    }
  }

  function renderRideFares() {
    const grid = document.getElementById("ride-fare-cards");
    const status = document.getElementById("ride-fare-save-status");
    if (!grid) return;
    const rates = cache.rideFares || DEFAULT_RIDE_FARES;
    const km = getRideFareSampleKm();
    const stops = getRideFareSampleStops();
    grid.innerHTML = RIDE_FARE_VEHICLES.map((v) => {
      const r = rates[v.id] || DEFAULT_RIDE_FARES[v.id];
      const sample = estimateRideFareLkr(r, km, stops);
      return `<article class="ride-fare-card" data-vehicle="${escapeHtml(v.id)}">
        <div class="ride-fare-card-head">
          <div class="ride-fare-icon">${v.icon}</div>
          <div>
            <h4 class="ride-fare-card-title">${escapeHtml(v.label)}</h4>
            <p class="ride-fare-card-meta">${escapeHtml(v.blurb)} · ${v.capacity} seat${v.capacity === 1 ? "" : "s"} · <code>${escapeHtml(v.id)}</code></p>
          </div>
        </div>
        <div class="ride-fare-fields">
          <div class="ride-fare-field">
            <label for="ride-fare-${escapeHtml(v.id)}-base">Base (LKR)</label>
            <input id="ride-fare-${escapeHtml(v.id)}-base" type="number" min="0" step="1" data-ride-fare="${escapeHtml(v.id)}" data-field="baseLkr" value="${Number(r.baseLkr)}" />
          </div>
          <div class="ride-fare-field">
            <label for="ride-fare-${escapeHtml(v.id)}-perkm">Per km (LKR)</label>
            <input id="ride-fare-${escapeHtml(v.id)}-perkm" type="number" min="0" step="1" data-ride-fare="${escapeHtml(v.id)}" data-field="perKmLkr" value="${Number(r.perKmLkr)}" />
          </div>
          <div class="ride-fare-field">
            <label for="ride-fare-${escapeHtml(v.id)}-min">Minimum (LKR)</label>
            <input id="ride-fare-${escapeHtml(v.id)}-min" type="number" min="0" step="1" data-ride-fare="${escapeHtml(v.id)}" data-field="minLkr" value="${Number(r.minLkr)}" />
          </div>
          <div class="ride-fare-field">
            <label for="ride-fare-${escapeHtml(v.id)}-perstop">Per stop (LKR)</label>
            <input id="ride-fare-${escapeHtml(v.id)}-perstop" type="number" min="0" step="1" data-ride-fare="${escapeHtml(v.id)}" data-field="perStopLkr" value="${Number(r.perStopLkr || 0)}" />
          </div>
        </div>
        <div class="ride-fare-preview">
          <span class="ride-fare-preview-label">Sample fare</span>
          <span class="ride-fare-preview-value" data-ride-preview="${escapeHtml(v.id)}">${escapeHtml(fmtMoney(sample))}</span>
        </div>
      </article>`;
    }).join("");
    grid.querySelectorAll("input[data-ride-fare]").forEach((input) => {
      input.addEventListener("input", updateRideFarePreviews);
    });
    if (status) status.textContent = "Edit rates, preview updates live, then Save.";
  }

  function readRideFaresFromForm() {
    const out = {};
    for (const v of RIDE_FARE_VEHICLES) {
      const baseEl = document.querySelector(`input[data-ride-fare="${v.id}"][data-field="baseLkr"]`);
      const perEl = document.querySelector(`input[data-ride-fare="${v.id}"][data-field="perKmLkr"]`);
      const minEl = document.querySelector(`input[data-ride-fare="${v.id}"][data-field="minLkr"]`);
      const perStopEl = document.querySelector(`input[data-ride-fare="${v.id}"][data-field="perStopLkr"]`);
      const baseLkr = Math.floor(Number(baseEl?.value));
      const perKmLkr = Math.floor(Number(perEl?.value));
      const minLkr = Math.floor(Number(minEl?.value));
      const perStopLkr = Math.floor(Number(perStopEl?.value));
      if (
        !Number.isFinite(baseLkr) ||
        !Number.isFinite(perKmLkr) ||
        !Number.isFinite(minLkr) ||
        !Number.isFinite(perStopLkr) ||
        baseLkr < 0 ||
        perKmLkr < 0 ||
        minLkr < 0 ||
        perStopLkr < 0
      ) {
        throw new Error(`Invalid rates for ${v.label}. Use whole numbers ≥ 0.`);
      }
      out[v.id] = { baseLkr, perKmLkr, minLkr, perStopLkr };
    }
    return out;
  }

  async function saveRideFares() {
    const status = document.getElementById("ride-fare-save-status");
    const btn = document.getElementById("btn-save-ride-fares");
    try {
      const rates = readRideFaresFromForm();
      if (btn) btn.disabled = true;
      if (status) status.textContent = "Saving…";
      await db
        .collection(COL.rideFareConfig)
        .doc("rates")
        .set(
          {
            ...rates,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedBy: auth.currentUser?.uid || "",
          },
          { merge: true }
        );
      cache.rideFares = rates;
      if (status) status.textContent = "Saved. New ride quotes will use these rates.";
      toast("Ride fares saved.", "success");
    } catch (err) {
      if (status) status.textContent = err.message || String(err);
      toast(err.message || String(err), "error");
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  function resetRideFaresToDefaults() {
    cache.rideFares = cloneDefaultRideFares();
    renderRideFares();
    const status = document.getElementById("ride-fare-save-status");
    if (status) status.textContent = "Defaults loaded in the form. Click Save rates to apply.";
  }

  /** Collected cash a rider still holds, per riders/{id} (server-written). */
  function riderCashInHand(r) {
    return Number(r && r.cashInHandLkr) || 0;
  }

  /** Riders-table cell: amount plus an On-hold badge when jobs are blocked. */
  function riderCashCell(r) {
    const cash = riderCashInHand(r);
    if (cash <= 0 && r.cashHoldActive !== true) {
      return '<span style="color:var(--muted)">—</span>';
    }
    const amount = escapeHtml(fmtMoney(cash));
    if (r.cashHoldActive !== true) {
      return amount;
    }
    return `${amount} <span class="badge badge-out">On hold</span>`;
  }

  function setRiderCashNavBadge(n) {
    const navBadge = document.getElementById("nav-rider-cash");
    if (!navBadge) return;
    if (n > 0) {
      navBadge.textContent = String(n);
      navBadge.hidden = false;
    } else {
      navBadge.hidden = true;
    }
  }

  /**
   * Pending handovers (collection group, admin-only per firestore.rules) plus
   * the riders currently carrying cash. Riders come from the same cache the
   * Riders page uses, so names/phones resolve without a second fan-out.
   */
  async function loadRiderCash() {
    if (cache.riders.length === 0) {
      await loadRiders();
    }
    await loadPlatformFees();
    try {
      const snap = await db
        .collectionGroup(COL.riderCashSettlements)
        .where("status", "==", "requested")
        .orderBy("requestedAt", "desc")
        .limit(100)
        .get(FS_GET_SERVER);
      cache.cashSettlements = snap.docs.map((d) => ({
        id: d.id,
        // riders/{riderId}/cash_settlements/{id} — parent of the parent.
        riderDocId: d.ref.parent.parent ? d.ref.parent.parent.id : "",
        ...d.data(),
      }));
    } catch (e) {
      cache.cashSettlements = [];
      toast(e.message || String(e), "error");
    }
    cache.cashRiders = cache.riders
      .filter((r) => riderCashInHand(r) > 0 || r.cashHoldActive === true)
      .sort((a, b) => riderCashInHand(b) - riderCashInHand(a));
    setRiderCashNavBadge(cache.cashSettlements.length);
  }

  function renderRiderCash() {
    const limit = Number(
      (cache.platformFees || PLATFORM_FEES_DEFAULTS).maxRiderCashInHandLkr
    );
    const limitEl = document.getElementById("rider-cash-limit");
    if (limitEl) {
      limitEl.textContent = limit > 0
        ? `Limit ${fmtMoney(limit)} per rider`
        : "No limit set — riders are never blocked.";
    }

    const settleBody = document.querySelector("#table-cash-settlements tbody");
    if (settleBody) {
      const list = cache.cashSettlements || [];
      settleBody.innerHTML = list.length === 0
        ? '<tr><td colspan="7"><div class="empty-state">No handovers waiting for confirmation.</div></td></tr>'
        : list
            .map((s) => {
              const rider = cache.riders.find((r) => r.id === s.riderDocId);
              const name = rider ? riderDisplayName(rider) : s.riderDocId || "Unknown rider";
              const b = s.breakdown || {};
              return `<tr>
        <td>
          ${escapeHtml(name)}
          <div style="color:var(--muted);font-size:12px">
            Shops ${escapeHtml(fmtMoney(b.productCashLkr))} · Commission ${escapeHtml(fmtMoney(b.rideCommissionLkr))}
          </div>
        </td>
        <td><strong>${escapeHtml(fmtMoney(s.amountLkr))}</strong></td>
        <td>${escapeHtml(fmtMoney(s.cashCoveredLkr))}</td>
        <td>${escapeHtml(String(s.entryCount ?? (s.entryIds || []).length))}</td>
        <td>${escapeHtml(s.method || "bank")}${s.reference ? ` · ${escapeHtml(s.reference)}` : ""}</td>
        <td>${escapeHtml(fmtTs(s.requestedAt))}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-primary btn-sm" data-confirm-cash="${escapeHtml(s.id)}" data-rider="${escapeHtml(s.riderDocId)}">Confirm received</button>
          <button type="button" class="btn btn-ghost btn-sm" data-reject-cash="${escapeHtml(s.id)}" data-rider="${escapeHtml(s.riderDocId)}">Reject</button>
        </td>
      </tr>`;
            })
            .join("");
    }

    const cashBody = document.querySelector("#table-rider-cash tbody");
    if (cashBody) {
      const list = cache.cashRiders || [];
      cashBody.innerHTML = list.length === 0
        ? '<tr><td colspan="7"><div class="empty-state">No rider is carrying collected cash.</div></td></tr>'
        : list
            .map((r) => {
              const held = r.cashHoldActive === true;
              return `<tr>
        <td>${escapeHtml(riderDisplayName(r))}</td>
        <td>${escapeHtml(r.phoneNumber || r.phone || "—")}</td>
        <td><strong>${escapeHtml(fmtMoney(riderCashInHand(r)))}</strong></td>
        <td>${escapeHtml(fmtMoney(r.cashOwedToAdminLkr))}</td>
        <td>${escapeHtml(fmtMoney(r.cashPendingSettlementLkr))}</td>
        <td>${held ? '<span class="badge badge-out">On hold</span>' : '<span class="badge">Accepting jobs</span>'}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-view-cash-ledger="${escapeHtml(r.id)}">View ledger</button>
        </td>
      </tr>`;
            })
            .join("");
      cashBody.querySelectorAll("[data-view-cash-ledger]").forEach((btn) => {
        btn.addEventListener("click", () =>
          openRiderCashLedgerModal(btn.getAttribute("data-view-cash-ledger"))
        );
      });
    }
  }

  /**
   * Itemized cash_ledger for one rider — what specifically makes up the
   * totals shown in the "Riders holding cash" table (which ride, which
   * order, still open or already locked into a settlement request).
   */
  async function openRiderCashLedgerModal(riderId) {
    const r = riderById(riderId);
    if (!r) return;
    const name = riderDisplayName(r);
    let rows = [];
    try {
      const snap = await db
        .collection(COL.riders)
        .doc(riderId)
        .collection(COL.riderCashLedger)
        .orderBy("createdAt", "desc")
        .limit(100)
        .get(FS_GET_SERVER);
      rows = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (e) {
      toast(e.message || String(e), "error");
    }

    const statusBadge = (status) => {
      if (status === "settled") return '<span class="badge">Settled</span>';
      if (status === "pending_settlement")
        return '<span class="badge badge-preparing">Awaiting confirm</span>';
      return '<span class="badge badge-out">Open</span>';
    };

    const tableHtml = rows.length === 0
      ? '<div class="empty-state">No cash ledger entries.</div>'
      : `<div class="table-wrap"><table>
          <thead><tr><th>Job</th><th>Collected</th><th>Owed</th><th>Status</th><th>Date</th></tr></thead>
          <tbody>
            ${rows
              .map(
                (e) => `<tr>
                <td>${escapeHtml(e.title || (e.type === "ride_cash" ? "Ride" : "Order"))}
                  <div style="color:var(--muted);font-size:12px">${escapeHtml(e.subtitle || "")}</div>
                </td>
                <td>${escapeHtml(fmtMoney(e.cashLkr))}</td>
                <td>${escapeHtml(fmtMoney(e.owedLkr))}</td>
                <td>${statusBadge(e.status)}</td>
                <td>${escapeHtml(fmtTs(e.createdAt))}</td>
              </tr>`
              )
              .join("")}
          </tbody>
        </table></div>`;

    openModal(
      `Cash ledger — ${name}`,
      `<div class="customer-profile-metrics">
          <div><span>Cash in hand</span><strong>${escapeHtml(fmtMoney(riderCashInHand(r)))}</strong></div>
          <div><span>Owed to admin</span><strong>${escapeHtml(fmtMoney(r.cashOwedToAdminLkr))}</strong></div>
          <div><span>Awaiting confirm</span><strong>${escapeHtml(fmtMoney(r.cashPendingSettlementLkr))}</strong></div>
        </div>
        ${tableHtml}`,
      "rider-cash-ledger",
      riderId
    );
    modalSave.style.display = "none";
  }

  /**
   * Records that the rider's cash physically arrived. The callable clears the
   * covered ledger entries, stamps the covered orders' product cash as
   * remitted, and lifts the hold — none of which a client may write directly.
   */
  async function settleRiderCash(riderId, settlementId, action) {
    if (!riderId || !settlementId) return;
    const confirming = action === "confirm";
    let reason = "";
    if (confirming) {
      if (!confirm("Confirm you physically received this cash from the rider?")) return;
    } else {
      const entered = prompt("Why is this handover being rejected?", "");
      if (entered === null) return;
      reason = entered.trim();
    }
    try {
      const name = confirming
        ? "adminConfirmCashSettlement"
        : "adminRejectCashSettlement";
      await functionsClient.httpsCallable(name)({
        riderId,
        settlementId,
        ...(confirming ? {} : { reason }),
      });
      await loadRiders();
      await loadRiderCash();
      renderRiderCash();
      toast(confirming ? "Cash settled. Rider can accept jobs again." : "Handover rejected.", "success");
    } catch (e) {
      toast(e.message || String(e), "error");
    }
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
        serviceChargePercent:
          d.serviceChargePercent == null
            ? PLATFORM_FEES_DEFAULTS.serviceChargePercent
            : Number(d.serviceChargePercent),
        rideCommissionLkr: Number(d.rideCommissionLkr) || 0,
        maxRiderCashInHandLkr:
          Number(d.maxRiderCashInHandLkr) > 0
            ? Number(d.maxRiderCashInHandLkr)
            : PLATFORM_FEES_DEFAULTS.maxRiderCashInHandLkr,
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
    setVal("fee-service-charge-pct", f.serviceChargePercent);
    setVal("fee-ride-commission", f.rideCommissionLkr);
    setVal("fee-max-cash-in-hand", f.maxRiderCashInHandLkr);
    setVal("fee-min-delivery", f.minDeliveryFeeLkr);
    setVal("fee-per-km", f.pricePerKmLkr);
    setVal("fee-shop-monthly-pct", f.shopMonthlyCommissionPercent);
  }

  async function savePlatformFeesFromForm() {
    const payload = {
      serviceChargePercent: Math.min(
        100,
        Math.max(0, Number(document.getElementById("fee-service-charge-pct").value) || 0)
      ),
      orderCommissionLkr: firebase.firestore.FieldValue.delete(),
      // Superseded by rideCommissionLkr, which the ride-earnings trigger
      // actually reads. The old field was never wired to anything.
      riderCommissionLkr: firebase.firestore.FieldValue.delete(),
      rideCommissionLkr: Math.max(
        0,
        Math.round(Number(document.getElementById("fee-ride-commission").value) || 0)
      ),
      maxRiderCashInHandLkr: Math.max(
        0,
        Math.round(Number(document.getElementById("fee-max-cash-in-hand").value) || 0)
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
      serviceChargePercent: payload.serviceChargePercent,
      rideCommissionLkr: payload.rideCommissionLkr,
      maxRiderCashInHandLkr: payload.maxRiderCashInHandLkr,
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
  document.getElementById("btn-reload-rider-cash")?.addEventListener("click", () => {
    loadRiderCash()
      .then(() => renderRiderCash())
      .catch((e) => toast(e.message || String(e), "error"));
  });
  document.querySelector("#table-cash-settlements")?.addEventListener("click", (e) => {
    const confirmBtn = e.target.closest("[data-confirm-cash]");
    if (confirmBtn) {
      settleRiderCash(
        confirmBtn.getAttribute("data-rider"),
        confirmBtn.getAttribute("data-confirm-cash"),
        "confirm"
      );
      return;
    }
    const rejectBtn = e.target.closest("[data-reject-cash]");
    if (rejectBtn) {
      settleRiderCash(
        rejectBtn.getAttribute("data-rider"),
        rejectBtn.getAttribute("data-reject-cash"),
        "reject"
      );
    }
  });
  document.getElementById("btn-save-ride-fares")?.addEventListener("click", () => {
    saveRideFares().catch((e) => toast(e.message || String(e), "error"));
  });
  document.getElementById("btn-reset-ride-fares")?.addEventListener("click", () => resetRideFaresToDefaults());
  document.getElementById("ride-fare-sample-km")?.addEventListener("input", updateRideFarePreviews);
  document.getElementById("ride-fare-sample-stops")?.addEventListener("input", updateRideFarePreviews);
  const debouncedRenderRatings = ui().debounce
    ? ui().debounce(() => renderRatings(), 220)
    : () => renderRatings();
  document.getElementById("filter-ratings")?.addEventListener("input", debouncedRenderRatings);
  document.getElementById("filter-rating-stars")?.addEventListener("change", () => renderRatings());
  document.getElementById("filter-rating-status")?.addEventListener("change", () => renderRatings());
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
  const debouncedRenderOngoing = ui().debounce
    ? ui().debounce(() => renderOngoingRiders(), 220)
    : () => renderOngoingRiders();
  document.getElementById("filter-ongoing-riders")?.addEventListener("input", debouncedRenderOngoing);
  document.getElementById("filter-ongoing-type")?.addEventListener("change", () => renderOngoingRiders());
  document.getElementById("btn-refresh-ongoing-riders")?.addEventListener("click", () => {
    if (cache.riders.length === 0) {
      loadRiders()
        .then(() => startOngoingJobsListeners())
        .then(() => {
          renderOngoingRiders();
          toast("Ongoing riders refreshed.", "success");
        })
        .catch((e) => toast(e.message || String(e), "error"));
      return;
    }
    startOngoingJobsListeners()
      .then(() => {
        renderOngoingRiders();
        toast("Ongoing riders refreshed.", "success");
      })
      .catch((e) => toast(e.message || String(e), "error"));
  });
  document.getElementById("btn-new-vendor")?.addEventListener("click", () => openVendorModal(null));
  document.getElementById("btn-new-product")?.addEventListener("click", () => openProductModal(null));
  document.getElementById("btn-new-banner")?.addEventListener("click", () => openBannerModal(null));
  document.getElementById("offers-status-filter")?.addEventListener("change", () => renderOffers());
  document.getElementById("btn-refresh-job-reports")?.addEventListener("click", () => {
    loadJobReports()
      .then(() => {
        renderJobReports();
        toast("Reported jobs refreshed.", "success");
      })
      .catch((e) => toast(e.message || String(e), "error"));
  });
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
  document.getElementById("btn-add-grocery-aisle")?.addEventListener("click", () => addGroceryAisleFromWebForm());
  document.getElementById("grocery-aisle-new-label")?.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      addGroceryAisleFromWebForm();
    }
  });
  document.getElementById("btn-seed-grocery-aisles")?.addEventListener("click", () => seedGroceryAislesDefaults());
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
