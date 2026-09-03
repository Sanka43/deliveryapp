import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  DEFAULT_FARE_TABLE,
  fareLkrForDistance,
  haversineKm,
  multiLegKm,
  parseFareTable,
  payHereCheckoutHash,
  payHereNotifyHash,
} from "./rideFare";

describe("rideFare", () => {
  it("haversine roughly matches Kandy→Badulla ballpark", () => {
    const km = haversineKm(7.335, 80.623, 6.993, 81.055);
    assert.ok(km > 60 && km < 90, `unexpected km ${km}`);
  });

  it("default fare table approximates web-beta prices near 75 km", () => {
    const d = 75.3;
    assert.equal(
      fareLkrForDistance("wheel", d, DEFAULT_FARE_TABLE),
      150 + Math.ceil(d * 40),
    );
    assert.equal(
      fareLkrForDistance("bike", d, DEFAULT_FARE_TABLE),
      100 + Math.ceil(d * 25),
    );
    assert.equal(
      fareLkrForDistance("car", d, DEFAULT_FARE_TABLE),
      200 + Math.ceil(d * 50),
    );
  });

  it("parseFareTable accepts admin config shape", () => {
    const table = parseFareTable({
      bike: {baseLkr: 120, perKmLkr: 30, minLkr: 180},
      wheel: {baseLkr: 160, perKmLkr: 45, minLkr: 260},
      car: {baseLkr: 220, perKmLkr: 55, minLkr: 420},
    });
    assert.ok(table);
    assert.equal(fareLkrForDistance("bike", 10, table!), 120 + 300);
  });

  it("parseFareTable rejects invalid rates", () => {
    assert.equal(parseFareTable({bike: {baseLkr: -1}}), null);
    assert.equal(parseFareTable(undefined), null);
  });

  it("parseFareTable defaults perStopLkr to 0 for older configs", () => {
    const table = parseFareTable({
      bike: {baseLkr: 120, perKmLkr: 30, minLkr: 180},
      wheel: {baseLkr: 160, perKmLkr: 45, minLkr: 260},
      car: {baseLkr: 220, perKmLkr: 55, minLkr: 420},
    });
    assert.ok(table);
    assert.equal(table!.bike.perStopLkr, 0);
  });

  it("multiLegKm sums consecutive legs (pickup → stop → dropoff)", () => {
    const pickup = {lat: 6.9271, lng: 79.8612};
    const stop = {lat: 6.9147, lng: 79.9724};
    const dropoff = {lat: 6.0535, lng: 80.2210};
    const direct = haversineKm(
      pickup.lat,
      pickup.lng,
      dropoff.lat,
      dropoff.lng,
    );
    const viaStop = multiLegKm([pickup, stop, dropoff]);
    // Detouring via a stop is never shorter than the direct route.
    assert.ok(viaStop >= direct);
  });

  it("fareLkrForDistance adds a per-stop surcharge", () => {
    const d = 10;
    const noStops = fareLkrForDistance("bike", d, DEFAULT_FARE_TABLE, 0);
    const twoStops = fareLkrForDistance("bike", d, DEFAULT_FARE_TABLE, 2);
    assert.equal(
      twoStops,
      noStops + 2 * DEFAULT_FARE_TABLE.bike.perStopLkr,
    );
  });

  it("payHere hashes are uppercase md5", () => {
    const h = payHereCheckoutHash(
      "1211149",
      "Order123",
      "1000.00",
      "LKR",
      "secret",
    );
    assert.match(h, /^[A-F0-9]{32}$/);
    const n = payHereNotifyHash(
      "1211149",
      "Order123",
      "1000.00",
      "LKR",
      "2",
      "secret",
    );
    assert.match(n, /^[A-F0-9]{32}$/);
  });
});
