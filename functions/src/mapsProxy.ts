import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {haversineKm} from "./deliveryFee";

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

/**
 * Server-side proxy for Places API (New) Nearby Search. Used when confirming
 * a dropped map pin: if there's a named business/landmark right where the
 * customer pinned (e.g. "Pizza Hut - Badulla"), showing that beats a generic
 * street address or, worse, a bare Plus Code in areas with sparse address
 * data — same as what Google Maps' own pin label shows. Called from every
 * platform: mobile's `geocoding` plugin only reverse-geocodes, it has no POI
 * search of its own.
 */
export const findNearestPlace = onCall(
  {region: "asia-south1"},
  async (request) => {
    const lat = request.data?.lat;
    const lng = request.data?.lng;
    if (typeof lat !== "number" || typeof lng !== "number") {
      throw new HttpsError("invalid-argument", "lat and lng are required.");
    }

    if (mapsApiMocked()) {
      return {result: null};
    }

    const body = {
      maxResultCount: 1,
      rankPreference: "DISTANCE",
      excludedTypes: ["route"],
      locationRestriction: {
        circle: {
          center: {latitude: lat, longitude: lng},
          radius: 60,
        },
      },
    };

    let response: Response;
    try {
      response = await fetch(
        "https://places.googleapis.com/v1/places:searchNearby",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": mapsKey(),
            "X-Goog-FieldMask":
              "places.displayName,places.formattedAddress,places.location",
          },
          body: JSON.stringify(body),
        },
      );
    } catch (e) {
      logger.error("findNearestPlace: network error", e);
      return {result: null};
    }
    const data = (await response.json()) as Record<string, unknown>;
    if (!response.ok) {
      logger.warn("findNearestPlace: non-OK response", {
        status: response.status,
        error: data,
      });
      return {result: null};
    }
    const places = (data.places as Record<string, unknown>[]) ?? [];
    if (places.length === 0) {
      return {result: null};
    }
    const place = places[0];
    const displayName = (place.displayName as Record<string, unknown>) ?? {};
    const name = String(displayName.text ?? "").trim();
    const formattedAddress = String(place.formattedAddress ?? "").trim();
    const location = (place.location as Record<string, unknown>) ?? {};
    const placeLat = Number(location.latitude ?? NaN);
    const placeLng = Number(location.longitude ?? NaN);
    if (!name || !Number.isFinite(placeLat) || !Number.isFinite(placeLng)) {
      return {result: null};
    }
    return {
      result: {
        name,
        formattedAddress,
        lat: placeLat,
        lng: placeLng,
        distanceMeters: haversineKm(lat, lng, placeLat, placeLng) * 1000,
      },
    };
  },
);

/**
 * Server-side proxy for Places API (New) Autocomplete. `geocodePlace` above
 * only resolves street addresses — typing a shop/landmark name like "Ranjan
 * Lanka" or "Uva Wellassa University" gets nothing useful from it. This lets
 * the rides and delivery place pickers' search boxes match business/POI
 * names the way Google Maps' own search does. Called from every platform
 * (not just web): no Places SDK is wired into the mobile apps, so mobile
 * proxies through here too instead of calling Google directly.
 */
export const placeAutocomplete = onCall(
  {region: "asia-south1"},
  async (request) => {
    const query = String(request.data?.query ?? "").trim();
    const sessionToken = String(request.data?.sessionToken ?? "").trim();
    const lat = request.data?.lat;
    const lng = request.data?.lng;

    if (!query) {
      throw new HttpsError("invalid-argument", "query is required.");
    }

    if (mapsApiMocked()) {
      return {
        results: [
          {
            placeId: "mock_place_id",
            primaryText: query,
            secondaryText: "Mock result, Sri Lanka",
          },
        ],
      };
    }

    const body: Record<string, unknown> = {
      input: query,
      includedRegionCodes: ["lk"],
      locationBias: {
        circle: {
          center: {
            latitude: typeof lat === "number" ? lat : 6.9271,
            longitude: typeof lng === "number" ? lng : 79.8612,
          },
          radius: 50000,
        },
      },
    };
    if (sessionToken) {
      body.sessionToken = sessionToken;
    }

    let response: Response;
    try {
      response = await fetch(
        "https://places.googleapis.com/v1/places:autocomplete",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": mapsKey(),
          },
          body: JSON.stringify(body),
        },
      );
    } catch (e) {
      logger.error("placeAutocomplete: network error", e);
      throw new HttpsError("unavailable", "Could not reach Places API.");
    }
    const data = (await response.json()) as Record<string, unknown>;
    if (!response.ok) {
      logger.warn("placeAutocomplete: non-OK response", {
        status: response.status,
        error: data,
      });
      return {results: []};
    }
    const suggestions = (data.suggestions as Record<string, unknown>[]) ?? [];
    const results = suggestions
      .map((s) => {
        const prediction = (s.placePrediction as Record<string, unknown>) ?? {};
        const structured =
          (prediction.structuredFormat as Record<string, unknown>) ?? {};
        const mainText = (structured.mainText as Record<string, unknown>) ?? {};
        const secondaryText =
          (structured.secondaryText as Record<string, unknown>) ?? {};
        return {
          placeId: String(prediction.placeId ?? ""),
          primaryText: String(mainText.text ?? ""),
          secondaryText: String(secondaryText.text ?? ""),
        };
      })
      .filter((r) => r.placeId && r.primaryText)
      .slice(0, 6);
    return {results};
  },
);

/**
 * Server-side proxy for Places API (New) Place Details. Resolves a
 * `placeId` from `placeAutocomplete` into a name, formatted address and
 * coordinates (autocomplete predictions don't carry coordinates), and closes
 * out the billing session `placeAutocomplete` started via `sessionToken` —
 * Google bills a whole autocomplete-keystrokes-then-details sequence as one
 * session when the same token is reused throughout it, instead of billing
 * every keystroke and the details call separately.
 */
export const placeDetails = onCall(
  {region: "asia-south1"},
  async (request) => {
    const placeId = String(request.data?.placeId ?? "").trim();
    const sessionToken = String(request.data?.sessionToken ?? "").trim();
    if (!placeId) {
      throw new HttpsError("invalid-argument", "placeId is required.");
    }

    if (mapsApiMocked()) {
      return {
        placeId,
        name: "Mock place",
        label: "Mock place, Sri Lanka",
        lat: 6.9271,
        lng: 79.8612,
      };
    }

    const params = new URLSearchParams();
    if (sessionToken) {
      params.set("sessionToken", sessionToken);
    }

    let response: Response;
    try {
      response = await fetch(
        `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}?${params.toString()}`,
        {
          headers: {
            "X-Goog-Api-Key": mapsKey(),
            "X-Goog-FieldMask": "id,displayName,formattedAddress,location",
          },
        },
      );
    } catch (e) {
      logger.error("placeDetails: network error", e);
      throw new HttpsError("unavailable", "Could not reach Places API.");
    }
    const data = (await response.json()) as Record<string, unknown>;
    if (!response.ok) {
      logger.warn("placeDetails: non-OK response", {
        status: response.status,
        error: data,
      });
      throw new HttpsError("not-found", "Place not found.");
    }

    const displayName = (data.displayName as Record<string, unknown>) ?? {};
    const name = String(displayName.text ?? "").trim();
    const formattedAddress = String(data.formattedAddress ?? "").trim();
    const location = (data.location as Record<string, unknown>) ?? {};

    // Avoid "Ranjan Lanka, Ranjan Lanka, Peradeniya Rd" when the address
    // already repeats the business name.
    let label = formattedAddress || name;
    if (
      name &&
      formattedAddress &&
      !formattedAddress.toLowerCase().includes(name.toLowerCase())
    ) {
      label = `${name}, ${formattedAddress}`;
    }

    return {
      placeId,
      name,
      label,
      lat: Number(location.latitude ?? 0),
      lng: Number(location.longitude ?? 0),
    };
  },
);
