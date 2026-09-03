import * as logger from "firebase-functions/logger";

function mapsKey(): string {
  return (process.env.GOOGLE_MAPS_KEY ?? "").trim();
}

/**
 * Real road distance (km) between two points via Google's Directions API —
 * the same figure Google Maps shows, unlike the Haversine straight-line
 * distance. Returns null if the API key is missing or the request fails so
 * callers can fall back to the straight-line estimate.
 */
export async function fetchDrivingDistanceKm(
  originLat: number,
  originLng: number,
  destLat: number,
  destLng: number,
): Promise<number | null> {
  const key = mapsKey();
  if (!key) {
    return null;
  }

  const params = new URLSearchParams({
    origin: `${originLat},${originLng}`,
    destination: `${destLat},${destLng}`,
    mode: "driving",
    alternatives: "false",
    units: "metric",
    region: "lk",
    key,
  });

  let response: Response;
  try {
    response = await fetch(
      `https://maps.googleapis.com/maps/api/directions/json?${params.toString()}`,
    );
  } catch (e) {
    logger.error("fetchDrivingDistanceKm: network error", e);
    return null;
  }

  const data = (await response.json()) as Record<string, unknown>;
  if (String(data.status ?? "") !== "OK") {
    return null;
  }
  const routes = (data.routes as Record<string, unknown>[]) ?? [];
  if (routes.length === 0) {
    return null;
  }
  const legs = (routes[0].legs as Record<string, unknown>[]) ?? [];
  let meters = 0;
  for (const leg of legs) {
    meters += Number((leg.distance as Record<string, unknown>)?.value ?? 0);
  }
  return meters / 1000;
}
