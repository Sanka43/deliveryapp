import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

function mapsKey(): string {
  const key = (process.env.GOOGLE_MAPS_KEY ?? "").trim();
  if (!key) {
    throw new HttpsError("failed-precondition", "Maps is not configured.");
  }
  return key;
}

// Load-testing escape hatch: with MAPS_API_MOCK=true, skip the real Google
// Maps call entirely and return a synthetic response instead. Never set in
// any deployed environment — it only ever gets exported in a local shell
// before starting the emulator, so this stays inert in production. Exists
// because getDrivingRoute/geocodePlace can't otherwise be load-tested
// without incurring real, billed Google Maps traffic.
function mapsApiMocked(): boolean {
  return process.env.MAPS_API_MOCK === "true";
}

interface DrivingRouteResult {
  status: string;
  points: string;
  distanceMeters: number;
  durationSeconds: number;
  summary: string;
}

async function fetchDrivingRoute(
  origin: string,
  destination: string,
  waypoints: string[],
): Promise<DrivingRouteResult> {
  if (mapsApiMocked()) {
    return {
      status: "OK",
      points: "mock_polyline",
      distanceMeters: 12_000,
      durationSeconds: 1_500,
      summary: `Mock route: ${origin} -> ${destination}` +
        (waypoints.length ? ` via ${waypoints.length} stop(s)` : ""),
    };
  }

  const params = new URLSearchParams({
    origin,
    destination,
    mode: "driving",
    alternatives: "false",
    units: "metric",
    region: "lk",
    key: mapsKey(),
  });
  if (waypoints.length > 0) {
    params.set("waypoints", waypoints.join("|"));
  }

  let response: Response;
  try {
    response = await fetch(
      `https://maps.googleapis.com/maps/api/directions/json?${params.toString()}`,
    );
  } catch (e) {
    logger.error("getDrivingRoute: network error", e);
    throw new HttpsError("unavailable", "Could not reach Directions API.");
  }
  const data = (await response.json()) as Record<string, unknown>;
  const status = String(data.status ?? "");
  if (status !== "OK") {
    if (status !== "ZERO_RESULTS") {
      logger.warn("getDrivingRoute: non-OK status", {
        status,
        error: data.error_message,
      });
    }
    return {status, points: "", distanceMeters: 0, durationSeconds: 0, summary: ""};
  }

  const routes = (data.routes as Record<string, unknown>[]) ?? [];
  if (routes.length === 0) {
    return {
      status: "ZERO_RESULTS",
      points: "",
      distanceMeters: 0,
      durationSeconds: 0,
      summary: "",
    };
  }
  const route = routes[0];
  const overview = (route.overview_polyline as Record<string, unknown>) ?? {};
  const points = String(overview.points ?? "");
  const legs = (route.legs as Record<string, unknown>[]) ?? [];
  let meters = 0;
  let seconds = 0;
  for (const leg of legs) {
    meters += Number((leg.distance as Record<string, unknown>)?.value ?? 0);
    seconds += Number((leg.duration as Record<string, unknown>)?.value ?? 0);
  }
  return {
    status: "OK",
    points,
    distanceMeters: meters,
    durationSeconds: seconds,
    summary: String(route.summary ?? ""),
  };
}

/**
 * Server-side proxy for Google's Directions API. The REST endpoint doesn't
 * send CORS headers, so Flutter web can't call it directly from the browser
 * (blocked by CORS policy) — only server-to-server calls work. Mobile calls
 * Google directly (native HTTP, no CORS) and doesn't need this, but any
 * platform can safely use it.
 *
 * Plain HTTPS endpoint rather than a Callable Function — one fewer moving
 * part, and the web client already needed a raw fetch/POST-shaped call.
 */
export const getDrivingRoute = onRequest(
  {region: "asia-south1", cors: true},
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).json({error: "POST required."});
      return;
    }
    const body = (request.body ?? {}) as Record<string, unknown>;
    const origin = String(body.origin ?? "").trim();
    const destination = String(body.destination ?? "").trim();
    if (!origin || !destination) {
      response.status(400).json({error: "origin and destination are required."});
      return;
    }
    const waypointsRaw = body.waypoints;
    const waypoints = Array.isArray(waypointsRaw)
      ? waypointsRaw.map((w) => String(w)).filter((w) => w.length > 0)
      : [];

    const result = await fetchDrivingRoute(origin, destination, waypoints);
    response.status(200).json(result);
  },
);

/**
 * Server-side proxy for Google's Geocoding API (forward search + reverse
 * lookup) — same CORS limitation as Directions. Used by the rides and
 * delivery place pickers' search boxes, and for labeling a dropped pin, on
 * web only (mobile uses the native `geocoding` plugin directly).
 */
export const geocodePlace = onCall(
  {region: "asia-south1"},
  async (request) => {
    const query = String(request.data?.query ?? "").trim();
    const lat = request.data?.lat;
    const lng = request.data?.lng;

    if (!query && !(typeof lat === "number" && typeof lng === "number")) {
      throw new HttpsError("invalid-argument", "query or lat/lng is required.");
    }

    if (mapsApiMocked()) {
      return {
        results: [
          {
            label: query || `Mock location near ${lat},${lng}`,
            lat: typeof lat === "number" ? lat : 6.9271,
            lng: typeof lng === "number" ? lng : 79.8612,
          },
        ],
      };
    }

    const params = new URLSearchParams({
      key: mapsKey(),
      region: "lk",
    });
    if (query) {
      params.set(
        "address",
        query.toLowerCase().includes("sri lanka") ? query : `${query}, Sri Lanka`,
      );
    } else {
      params.set("latlng", `${lat},${lng}`);
    }

    let response: Response;
    try {
      response = await fetch(
        `https://maps.googleapis.com/maps/api/geocode/json?${params.toString()}`,
      );
    } catch (e) {
      logger.error("geocodePlace: network error", e);
      throw new HttpsError("unavailable", "Could not reach Geocoding API.");
    }
    const data = (await response.json()) as Record<string, unknown>;
    const status = String(data.status ?? "");
    if (status !== "OK") {
      return {results: []};
    }
    const results = (data.results as Record<string, unknown>[]) ?? [];
    return {
      results: results.slice(0, 6).map((r) => {
        const geometry = (r.geometry as Record<string, unknown>) ?? {};
        const location = (geometry.location as Record<string, unknown>) ?? {};
        return {
          label: String(r.formatted_address ?? ""),
          lat: Number(location.lat ?? 0),
          lng: Number(location.lng ?? 0),
        };
      }),
    };
  },
);
