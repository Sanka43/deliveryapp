/**
 * MND web admin â€” Firestore CRUD aligned with mnd_customer:
 * collections: orders, customers, vendors, products, banners, shop_categories, shop_types, riders, store_ratings (see firebase_collections.dart).
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
    rideFareConfig: "ride_fare_config",
    orders: "orders",
    storeRatings: "store_ratings",
    jobs: "jobs",
    jobApplications: "job_applications",
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

  const ORDER_STATUSES = [
    "placed",
    "confirmed",
    "preparing",
    "ready",
    "out_for_delivery",
    "on_the_way",
    "delivered",
    "cancelled",
  ];

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
    ratings: [],
    rideFares: null,
  };

  const DEFAULT_RIDE_FARES = {
    bike: { baseLkr: 100, perKmLkr: 25, minLkr: 150 },
    wheel: { baseLkr: 150, perKmLkr: 40, minLkr: 250 },
    car: { baseLkr: 200, perKmLkr: 50, minLkr: 400 },
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

  const elLogin = document.getElementById("login-screen");
  const elApp = document.getElementById("app");
  const elLoginForm = document.getElementById("login-form");
  const elLoginError = document.getElementById("login-error");
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

  function initFirebase() {
    if (!window.firebase || !window.__FIREBASE_CONFIG__) {
      throw new Error("Firebase SDK or config missing.");
    }
    if (!firebase.apps.length) {
      firebase.initializeApp(window.__FIREBASE_CONFIG__);
    }
    auth = firebase.auth();
    db = firebase.firestore();
  }

  async function assertAdmin(uid) {
    let role = "";
    const byDocId = await db.collection(COL.customers).doc(uid).get();
    if (byDocId.exists) {
      role = String(byDocId.data().role || "").trim().toLowerCase();
    } else {
      // This project rules resolve admin role from customers/{authUid}.
      // If profile was created under a random doc id, admin reads/writes will still fail.
      throw new Error(`Missing Firestore profile: create customers/${uid} with role "admin".`);
    }
    if (role !== "admin") {
      throw new Error(`customers/${uid} must have role "admin".`);
    }
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
    if (!val) return "â€”";
    try {
      if (typeof val.toDate === "function") return val.toDate().toLocaleString();
      if (val.seconds != null) return new Date(val.seconds * 1000).toLocaleString();
    } catch (_) {}
    return "â€”";
  }

  function badgeClass(status) {
    const s = String(status || "").toLowerCase();
    if (s === "placed" || s === "confirmed") return "badge-preparing";
    if (s === "preparing" || s === "ready") return "badge-preparing";
    if (s === "out_for_delivery" || s === "on_the_way") return "badge-out";
    if (s === "delivered") return "badge-delivered";
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
      cancelled: "Cancelled",
    };
    return map[k] || s || "â€”";
  }

  function orderAddrLine(data) {
    const a = data.deliveryAddress;
    if (!a || typeof a !== "object") return "â€”";
    const p = [a.line1, a.line2, a.city].filter(Boolean).join(", ");
    return p || "â€”";
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

  function riderVehicleLabel(r) {
    const type = r.vehicleType || r.vehicle || "";
    const num = r.vehicleNumber || "";
    if (type && num) {
      return `${type} Â· ${num}`;
    }
    return type || num || "â€”";
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
    return r.fullName || firstLast || r.displayName || r.name || r.id || "â€”";
  }

  function fmtCoordPair(pt) {
    if (!pt) return "â€”";
    return `${Number(pt.lat).toFixed(5)}, ${Number(pt.lng).toFixed(5)}`;
  }

  async function getVendorDocForOrder(vendorId) {
    const vid = String(vendorId || "").trim();
    if (!vid) return null;
    let v = cache.vendors.find((x) => x.id === vid);
    if (v) return v;
    const snap = await db.collection(COL.vendors).doc(vid).get();
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
    const shopName = String(o.storeName || vendor?.name || "â€”").trim() || "â€”";
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
                distKm != null && Number.isFinite(distKm) ? `${distKm.toFixed(1)} km` : "â€” (no coordinates)";
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
        ? `<p class="assign-warn">Shop has no map coordinates in <code>vendors/${escapeHtml(vid)}</code> â€” distances show as â€”. Add latitude/longitude in vendor Edit.</p>`
        : !vid
          ? `<p class="assign-warn">Order has no <code>vendorId</code> â€” cannot resolve shop location.</p>`
          : "";

    const html = `<p style="margin-top:0;color:var(--muted);font-size:0.9rem">Order <strong>${escapeHtml(titleLabel)}</strong> Â· Pick an online rider (nearest first when both rider and shop have coordinates).</p>
      ${shopWarn}
      <div class="table-wrap assign-rider-wrap">
        <table class="assign-rider-table">
          <thead><tr><th>Rider</th><th>Shop</th><th>Coordinates</th><th>Distance</th><th></th></tr></thead>
          <tbody>${tableBody}</tbody>
        </table>
      </div>`;

    openModal(`Assign rider â€” ${titleLabel}`, html, "assign-rider", orderId);
    modalSave.style.display = "none";
  }

  function openModal(title, html, mode, editId) {
    modalTitle.textContent = title;
    modalBody.innerHTML = html;
    modalMode = mode;
    modalEditId = editId;
    const dialog = modalBackdrop.querySelector(".modal");
    if (dialog) {
      dialog.classList.toggle("modal--wide", mode === "assign-rider" || mode === "job-applications");
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
    "ride-fares": "Ride fares",
    "shop-approvals": "Shop approvals",
    "job-approvals": "Job approvals",
    "rider-approvals": "Rider approvals",
    riders: "Riders",
    customers: "Customers",
    ratings: "Rating Management",
    help: "Setup",
  };

  function showView(name) {
    currentView = name;
    elPageTitle.textContent = titles[name] || name;
    elViews.forEach((v) => {
      v.hidden = v.getAttribute("data-view") !== name;
    });
    elNav.forEach((b) => b.classList.toggle("active", b.getAttribute("data-nav") === name));
    loadViewData(name).catch((e) => alert(e.message || String(e)));
  }

  async function loadViewData(name) {
    if (!db || !auth.currentUser) return;
    if (name === "dashboard") await loadOrders();
    if (name === "orders") await loadOrders();
    if (name === "vendors" || name === "shop-approvals" || name === "dashboard") {
      await loadVendors();
    }
    if (name === "job-approvals" || name === "dashboard") {
      await loadJobs();
      if (name === "job-approvals") await loadJobApplications();
    }
    if (name === "products") await loadProducts();
    if (name === "banners") await loadBanners();
    if (name === "shop-types") await loadShopTypes();
    if (name === "ride-fares") await loadRideFares();
    if (name === "riders" || name === "rider-approvals" || name === "dashboard") {
      await loadRiders();
    }
    if (name === "customers") await loadCustomers();
    if (name === "ratings") await loadRatings();
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
    if (name === "ride-fares") renderRideFares();
    if (name === "rider-approvals") renderRiderApprovals();
    if (name === "riders") renderRiders();
    if (name === "customers") renderCustomers();
    if (name === "ratings") renderRatings();
  }

  async function loadOrders() {
    try {
      const q = db.collection(COL.orders).orderBy("createdAt", "desc").limit(200);
      const snap = await q.get();
      cache.orders = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.orders).limit(200).get();
      cache.orders = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    }
  }

  async function loadVendors() {
    try {
      const snap = await db.collection(COL.vendors).orderBy("name").limit(300).get();
      cache.vendors = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.vendors).limit(300).get();
      cache.vendors = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.vendors.sort((a, b) =>
        String(a.name || "").localeCompare(String(b.name || ""))
      );
    }
    updatePendingShopNavBadge();
  }

  async function loadJobs() {
    try {
      const snap = await db.collection(COL.jobs).orderBy("createdAt", "desc").limit(200).get();
      cache.jobs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.jobs).limit(200).get();
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
        .get();
      cache.jobApplications = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.jobApplications).limit(500).get();
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

  async function loadProducts() {
    try {
      const snap = await db.collection(COL.products).orderBy("name").limit(500).get();
      cache.products = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.products).limit(500).get();
      cache.products = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    }
  }

  async function loadBanners() {
    try {
      const snap = await db.collection(COL.banners).orderBy("order").limit(100).get();
      cache.banners = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.banners).limit(100).get();
      cache.banners = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    }
  }

  async function loadShopCategories() {
    try {
      const snap = await db.collection(COL.shopCategories).orderBy("order").limit(200).get();
      cache.shopCategories = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.shopCategories).limit(200).get();
      cache.shopCategories = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.shopCategories.sort((a, b) => (Number(a.order) || 0) - (Number(b.order) || 0));
    }
  }

  async function loadShopTypes() {
    await loadShopCategories();
    try {
      const snap = await db.collection(COL.shopTypes).orderBy("order").limit(400).get();
      cache.shopTypes = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.shopTypes).limit(400).get();
      cache.shopTypes = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.shopTypes.sort((a, b) => (Number(a.order) || 0) - (Number(b.order) || 0));
    }
  }

  function shopCategoryLabelById(categoryId) {
    if (!categoryId || typeof categoryId !== "string") return "â€”";
    const c = cache.shopCategories.find((x) => x.id === categoryId);
    return c ? String(c.label || "â€”") : "(missing category)";
  }

  function fillShopTypeCategorySelect() {
    const sel = document.getElementById("shop-type-category");
    if (!sel) return;
    const active = cache.shopCategories.filter((c) => c.active !== false);
    const cur = sel.value;
    sel.innerHTML =
      '<option value="">Select categoryâ€¦</option>' +
      active
        .map((c) => `<option value="${escapeHtml(c.id)}">${escapeHtml(c.label || "â€”")}</option>`)
        .join("");
    if (cur && [...sel.options].some((o) => o.value === cur)) {
      sel.value = cur;
    }
  }

  async function loadRiders() {
    const snap = await db.collection(COL.riders).limit(200).get();
    cache.riders = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    updateAllApprovalBadges();
  }

  async function loadCustomers() {
    const snap = await db.collection(COL.customers).limit(300).get();
    cache.customers = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  }

  async function loadRatings() {
    try {
      const q = db.collection(COL.storeRatings).orderBy("createdAt", "desc").limit(300);
      const snap = await q.get();
      cache.ratings = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch (_) {
      const snap = await db.collection(COL.storeRatings).limit(300).get();
      cache.ratings = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    }
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
    updateAllApprovalBadges();
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
        const cust = String(o.customerId || "").toLowerCase();
        const store = String(o.storeName || "").toLowerCase();
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
        ? `<tr><td colspan="7"><div class="empty-state">No orders.</div></td></tr>`
        : list
            .map((o) => {
              const stRaw = String(o.status || "placed");
              const stLower = String(stRaw || "").toLowerCase();
              const readyAttention = stLower === "ready" ? " badge-ready-attention" : "";
              const track = String(o.trackingNumber || "").trim();
              const orderLabel = track || o.id;
              const assignBtn =
                stLower === "ready"
                  ? `<button type="button" class="btn btn-ghost btn-sm" data-assign-rider-order="${escapeHtml(o.id)}">Assign rider</button>`
                  : "";
              return `<tr>
          <td><strong>${escapeHtml(orderLabel)}</strong></td>
          <td>${escapeHtml(o.customerId || "â€”")}</td>
          <td>${escapeHtml(o.storeName || "â€”")}<br/><small style="color:var(--muted)">${escapeHtml(orderAddrLine(o))}</small></td>
          <td>${fmtMoney(o.total)}</td>
          <td><span class="badge ${badgeClass(stRaw)}${readyAttention}">${escapeHtml(statusLabel(stRaw))}</span></td>
          <td>${escapeHtml(fmtTs(o.createdAt))}</td>
          <td class="row-actions">
            ${assignBtn}
            <button type="button" class="btn btn-ghost btn-sm" data-edit-order="${escapeHtml(o.id)}">Edit</button>
            <button type="button" class="btn btn-ghost btn-sm" data-del-order="${escapeHtml(o.id)}">Delete</button>
          </td>
        </tr>`;
            })
            .join("");
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
        <td>${escapeHtml(v.name || "â€”")}</td>
        <td>${escapeHtml(v.tag || v.category || "â€”")}</td>
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

  function renderProducts() {
    const tbody = document.querySelector("#table-products tbody");
    const list = cache.products;
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="6"><div class="empty-state">No products.</div></td></tr>`
        : list
            .map(
              (p) => `<tr>
        <td>${escapeHtml(p.id)}</td>
        <td>${escapeHtml(p.name || "â€”")}</td>
        <td>${escapeHtml(p.storeId || "â€”")}</td>
        <td>${fmtMoney(p.price)}</td>
        <td>${p.active === true ? "Yes" : "No"}</td>
        <td class="row-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-edit-product="${escapeHtml(p.id)}">Edit</button>
          <button type="button" class="btn btn-ghost btn-sm" data-del-product="${escapeHtml(p.id)}">Delete</button>
        </td>
      </tr>`
            )
            .join("");
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
        <td>${escapeHtml(b.title || "â€”")}</td>
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
        <td>${escapeHtml(c.label || "â€”")}</td>
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
        <td>${escapeHtml(t.label || "â€”")}</td>
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

  function normalizeRideFareVehicle(raw, fallback) {
    const m = raw && typeof raw === "object" ? raw : {};
    const base = Math.floor(Number(m.baseLkr));
    const perKm = Math.floor(Number(m.perKmLkr));
    const min = Math.floor(Number(m.minLkr));
    return {
      baseLkr: Number.isFinite(base) && base >= 0 ? base : fallback.baseLkr,
      perKmLkr: Number.isFinite(perKm) && perKm >= 0 ? perKm : fallback.perKmLkr,
      minLkr: Number.isFinite(min) && min >= 0 ? min : fallback.minLkr,
    };
  }

  async function loadRideFares() {
    const snap = await db.collection(COL.rideFareConfig).doc("rates").get();
    if (!snap.exists) {
      cache.rideFares = {
        bike: { ...DEFAULT_RIDE_FARES.bike },
        wheel: { ...DEFAULT_RIDE_FARES.wheel },
        car: { ...DEFAULT_RIDE_FARES.car },
      };
      return;
    }
    const data = snap.data() || {};
    cache.rideFares = {
      bike: normalizeRideFareVehicle(data.bike, DEFAULT_RIDE_FARES.bike),
      wheel: normalizeRideFareVehicle(data.wheel, DEFAULT_RIDE_FARES.wheel),
      car: normalizeRideFareVehicle(data.car, DEFAULT_RIDE_FARES.car),
    };
  }

  function estimateRideFareLkr(rates, distanceKm) {
    const km = Math.max(0, Number(distanceKm) || 0);
    const raw = rates.baseLkr + Math.ceil(km * rates.perKmLkr);
    return Math.max(rates.minLkr, raw);
  }

  function getRideFareSampleKm() {
    const el = document.getElementById("ride-fare-sample-km");
    const km = Number(el?.value);
    if (!Number.isFinite(km) || km <= 0) return 5;
    return km;
  }

  function updateRideFarePreviews() {
    const km = getRideFareSampleKm();
    for (const v of RIDE_FARE_VEHICLES) {
      const baseEl = document.querySelector(`input[data-ride-fare="${v.id}"][data-field="baseLkr"]`);
      const perEl = document.querySelector(`input[data-ride-fare="${v.id}"][data-field="perKmLkr"]`);
      const minEl = document.querySelector(`input[data-ride-fare="${v.id}"][data-field="minLkr"]`);
      const preview = document.querySelector(`[data-ride-preview="${v.id}"]`);
      if (!preview) continue;
      const rates = {
        baseLkr: Math.floor(Number(baseEl?.value)),
        perKmLkr: Math.floor(Number(perEl?.value)),
        minLkr: Math.floor(Number(minEl?.value)),
      };
      if (
        !Number.isFinite(rates.baseLkr) ||
        !Number.isFinite(rates.perKmLkr) ||
        !Number.isFinite(rates.minLkr)
      ) {
        preview.textContent = "—";
        continue;
      }
      preview.textContent = fmtMoney(estimateRideFareLkr(rates, km));
    }
  }

  function renderRideFares() {
    const grid = document.getElementById("ride-fare-cards");
    const status = document.getElementById("ride-fare-save-status");
    if (!grid) return;
    const rates = cache.rideFares || DEFAULT_RIDE_FARES;
    const km = getRideFareSampleKm();
    grid.innerHTML = RIDE_FARE_VEHICLES.map((v) => {
      const r = rates[v.id] || DEFAULT_RIDE_FARES[v.id];
      const sample = estimateRideFareLkr(r, km);
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
      const baseLkr = Math.floor(Number(baseEl?.value));
      const perKmLkr = Math.floor(Number(perEl?.value));
      const minLkr = Math.floor(Number(minEl?.value));
      if (
        !Number.isFinite(baseLkr) ||
        !Number.isFinite(perKmLkr) ||
        !Number.isFinite(minLkr) ||
        baseLkr < 0 ||
        perKmLkr < 0 ||
        minLkr < 0
      ) {
        throw new Error(`Invalid rates for ${v.label}. Use whole numbers ≥ 0.`);
      }
      out[v.id] = { baseLkr, perKmLkr, minLkr };
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
    } catch (err) {
      if (status) status.textContent = err.message || String(err);
      alert(err.message || String(err));
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  function resetRideFaresToDefaults() {
    cache.rideFares = {
      bike: { ...DEFAULT_RIDE_FARES.bike },
      wheel: { ...DEFAULT_RIDE_FARES.wheel },
      car: { ...DEFAULT_RIDE_FARES.car },
    };
    renderRideFares();
    const status = document.getElementById("ride-fare-save-status");
    if (status) status.textContent = "Defaults loaded in the form. Click Save rates to apply.";
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
        .get();
      const fresh = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      cache.jobApplications = cache.jobApplications
        .filter((a) => String(a.jobId || "") !== String(jobId))
        .concat(fresh);
    } catch (_) {
      const snap = await db.collection(COL.jobApplications).where("jobId", "==", jobId).get();
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
      const appDoc = await db.collection(COL.jobApplications).doc(applicationId).get();
      if (!appDoc.exists) throw new Error("Application not found.");
      const app = appDoc.data();
      const current = String(app.status || "").toLowerCase();
      if (current !== "booked") {
        const jobId = app.jobId;
        const job = cache.jobs.find((x) => x.id === jobId);
        if (!job) {
          const jobSnap = await db.collection(COL.jobs).doc(jobId).get();
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
              const docsHtml = docs.length ? docs.join(" Â· ") : "â€”";
              return `<tr>
        <td>${escapeHtml(riderDisplayName(r))}</td>
        <td>${escapeHtml(r.phone || r.phoneNumber || "â€”")}</td>
        <td>${escapeHtml(r.nicNumber || "â€”")}</td>
        <td>${escapeHtml(r.city || "â€”")}</td>
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
              const phone = r.phoneNumber || r.phone || "â€”";
              const approval = riderRegistrationStatus(r);
              const isApproved = approval === "approved" || approval === "active";
              return `<tr>
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
    const list = cache.customers;
    tbody.innerHTML =
      list.length === 0
        ? `<tr><td colspan="5"><div class="empty-state">No customer profiles.</div></td></tr>`
        : list
            .map(
              (u) => `<tr>
        <td><code>${escapeHtml(u.id)}</code></td>
        <td>${escapeHtml(u.displayName || "â€”")}</td>
        <td>${escapeHtml(u.role || "â€”")}</td>
        <td>${escapeHtml(u.phoneNumber || u.phone || "â€”")}</td>
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
        const hay = [
          r.storeName,
          r.customerId,
          r.vendorId,
          r.comment,
          r.orderId,
          r.id,
        ]
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
              const starLabel = "★".repeat(Math.max(0, Math.min(5, stars))) +
                "☆".repeat(Math.max(0, 5 - Math.max(0, Math.min(5, stars))));
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
    } catch (e) {
      alert(e.message || String(e));
    }
  }

  async function deleteRating(id) {
    if (!id || !db) return;
    if (!confirm("Delete this rating permanently? Shop average will be recalculated.")) return;
    try {
      await db.collection(COL.storeRatings).doc(id).delete();
      await loadRatings();
      renderRatings();
    } catch (e) {
      alert(e.message || String(e));
    }
  }

  function openCustomerView(uid) {
    const u = cache.customers.find((x) => x.id === uid);
    if (!u) return;
    const json = JSON.stringify(u, null, 2);
    openModal(
      "Customer profile",
      `<pre style="margin:0;max-height:50vh;overflow:auto;font-size:12px;color:var(--text)">${escapeHtml(json)}</pre>
      <p style="color:var(--muted);font-size:0.85rem">Firestore rules allow admin read/delete on customers, not admin-side profile edits.</p>`,
      "readonly",
      null
    );
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
    const opts = ORDER_STATUSES.map(
      (s) => `<option value="${escapeHtml(s)}" ${String(o.status).toLowerCase() === s ? "selected" : ""}>${escapeHtml(statusLabel(s))}</option>`
    ).join("");
    openModal(
      "Edit order",
      `<div class="form-group"><label>Order ID</label><input type="text" value="${escapeHtml(o.id)}" readonly></div>
      <div class="form-group"><label>Status</label><select id="f-ord-status">${opts}</select></div>
      <div class="form-group"><label>Rider (optional)</label><select id="f-ord-rider">${riderOptions}</select></div>
      <div class="form-group"><label>Subtotal (LKR)</label><input type="number" id="f-ord-sub" min="0" step="1" value="${Number(o.subtotal) || 0}"></div>
      <div class="form-group"><label>Discount</label><input type="number" id="f-ord-disc" min="0" step="1" value="${Number(o.discount) || 0}"></div>
      <div class="form-group"><label>Delivery fee</label><input type="number" id="f-ord-fee" min="0" step="1" value="${Number(o.deliveryFee) || 0}"></div>
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
      <div class="form-group"><label>Rating (computed from reviews)</label><input type="number" id="f-v-rat" step="0.1" min="0" value="${Number(v?.rating) || 0}" readonly disabled></div>
      <div class="form-group"><label>Rating count</label><input type="number" id="f-v-rat-count" value="${Number(v?.ratingCount) || 0}" readonly disabled></div>
      <p style="color:var(--muted);font-size:0.85rem;margin:0 0 12px">Shop averages update automatically from visible customer ratings. Moderate reviews in Rating Management.</p>
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
    openModal(
      id ? "Edit product" : "New product",
      `<div class="form-group"><label>Name</label><input type="text" id="f-p-name" value="${escapeHtml(p?.name || "")}" required></div>
      <div class="form-group"><label>Store ID (vendor)</label><input type="text" id="f-p-sid" value="${escapeHtml(p?.storeId || "")}" required></div>
      <div class="form-group"><label>Store name</label><input type="text" id="f-p-sn" value="${escapeHtml(p?.storeName || p?.vendorName || "")}"></div>
      <div class="form-group"><label>Lookup key</label><input type="text" id="f-p-lk" value="${escapeHtml(p?.lookupKey || "")}" placeholder="auto: doc id if empty"></div>
      <div class="form-group"><label>Price (LKR)</label><input type="number" id="f-p-price" min="0" step="1" value="${Number(p?.price) || 0}"></div>
      <div class="form-group"><label>Image URL</label><input type="text" id="f-p-img" value="${escapeHtml(p?.imageUrl || "")}"></div>
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
      const riderRaw = document.getElementById("f-ord-rider").value.trim();
      const sub = Number(document.getElementById("f-ord-sub").value) || 0;
      const disc = Number(document.getElementById("f-ord-disc").value) || 0;
      const fee = Number(document.getElementById("f-ord-fee").value) || 0;
      const total = Number(document.getElementById("f-ord-total").value) || 0;
      const ref = db.collection(COL.orders).doc(modalEditId);
      const patch = {
        status,
        subtotal: sub,
        discount: disc,
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
        storeName,
        status,
        paymentMethod: "cashOnDelivery",
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
        imageUrl,
        deliveryFee: fee,
        active,
      };
      if (!modalEditId) {
        data.rating = 0;
        data.ratingCount = 0;
      }
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
    if (!confirm(`Delete order ${id}?`)) return;
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
    const q = await db.collection(COL.shopTypes).where("categoryId", "==", id).limit(1).get();
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
      alert("Enter a category label (1â€“80 characters).");
      return;
    }
    btn.disabled = true;
    if (status) status.textContent = "Savingâ€¦";
    try {
      let nextOrder = 0;
      try {
        const top = await db.collection(COL.shopCategories).orderBy("order", "desc").limit(1).get();
        if (!top.empty) {
          const o = top.docs[0].data().order;
          if (typeof o === "number") nextOrder = o + 1;
        }
      } catch (_) {
        const snap = await db.collection(COL.shopCategories).limit(200).get();
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
      alert("Enter a label (1â€“80 characters).");
      return;
    }
    btn.disabled = true;
    if (status) status.textContent = "Saving to Firestoreâ€¦";
    try {
      let nextOrder = 0;
      try {
        const top = await db
          .collection(COL.shopTypes)
          .where("categoryId", "==", categoryId)
          .orderBy("order", "desc")
          .limit(1)
          .get();
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
          "\n\nâ€¢ Deploy latest rules: from repo folder run  firebase deploy --only firestore  " +
          "(needs shop_types rules + indexes).\n" +
          "â€¢ Firestore customers/{yourAuthUid} must have role: admin (Admin / ADMIN also work).";
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
    if (!confirm(`Delete Firestore customers/${id}? (Does not delete Auth user.)`)) return;
    await db.collection(COL.customers).doc(id).delete();
    await loadViewData("customers");
  }

  elLoginForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    elLoginError.classList.remove("visible");
    const email = document.getElementById("login-email").value.trim();
    const pass = document.getElementById("login-pass").value;
    try {
      initFirebase();
      const cred = await auth.signInWithEmailAndPassword(email, pass);
      await assertAdmin(cred.user.uid);
      elLogin.hidden = true;
      elApp.classList.add("visible");
      if (elTopEmail) elTopEmail.textContent = email;
      showView("dashboard");
    } catch (err) {
      try {
        await auth.signOut();
      } catch (_) {}
      elLoginError.textContent =
        err.code === "auth/user-not-found" || err.code === "auth/wrong-password"
          ? "Invalid email or password."
          : err.message || err.code || "Sign-in failed.";
      elLoginError.classList.add("visible");
    }
  });

  elLogout.addEventListener("click", async () => {
    try {
      await auth.signOut();
    } catch (_) {}
    elApp.classList.remove("visible");
    elLogin.hidden = false;
  });

  elNav.forEach((btn) => {
    btn.addEventListener("click", () => showView(btn.getAttribute("data-nav")));
  });

  document.getElementById("btn-new-order")?.addEventListener("click", openOrderCreate);
  document.getElementById("filter-orders")?.addEventListener("input", () => renderOrders());
  document.getElementById("filter-order-status")?.addEventListener("change", () => renderOrders());
  document.getElementById("filter-ratings")?.addEventListener("input", () => renderRatings());
  document.getElementById("filter-rating-stars")?.addEventListener("change", () => renderRatings());
  document.getElementById("filter-rating-status")?.addEventListener("change", () => renderRatings());
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
  document.getElementById("btn-save-ride-fares")?.addEventListener("click", () => saveRideFares());
  document.getElementById("btn-reset-ride-fares")?.addEventListener("click", () => resetRideFaresToDefaults());
  document.getElementById("ride-fare-sample-km")?.addEventListener("input", updateRideFarePreviews);
  document.getElementById("btn-new-rider")?.addEventListener("click", () => openRiderModal(null));
  document.getElementById("btn-refresh")?.addEventListener("click", () => loadViewData(currentView).catch((e) => alert(e.message)));

  try {
    initFirebase();
  } catch (e) {
    elLoginError.textContent = "Firebase init failed: " + (e.message || String(e));
    elLoginError.classList.add("visible");
  }

  if (typeof firebase !== "undefined" && firebase.apps.length) {
    firebase.auth().onAuthStateChanged(async (user) => {
      if (!user) {
        elApp.classList.remove("visible");
        elLogin.hidden = false;
        if (elTopEmail) elTopEmail.textContent = "";
        return;
      }
      try {
        await assertAdmin(user.uid);
        elLogin.hidden = true;
        elApp.classList.add("visible");
        if (elTopEmail) elTopEmail.textContent = user.email || user.uid;
        await loadViewData(currentView);
        if (currentView === "dashboard") renderDashboard();
      } catch (err) {
        try {
          await firebase.auth().signOut();
        } catch (_) {}
        elLoginError.textContent = err.message || "Not authorized.";
        elLoginError.classList.add("visible");
      }
    });
  }
})();
