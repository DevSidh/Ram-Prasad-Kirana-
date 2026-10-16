import assert from 'node:assert/strict';
import {
  assertWithinDeliveryServiceArea,
  calculateRoadDeliveryQuote,
  DeliveryPricingError,
  STORE_LOCATION,
} from '../src/services/delivery-pricing.js';

async function run(): Promise<void> {
  const originalFetch = globalThis.fetch;
  const previousApiKey = process.env.GOOGLE_MAPS_ROUTES_API_KEY;
  const previousServiceRadius = process.env.DELIVERY_SERVICE_RADIUS_KM;
  const requests: Array<{ url: string; init?: RequestInit }> = [];
  process.env.GOOGLE_MAPS_ROUTES_API_KEY = 'test-routes-key';
  process.env.DELIVERY_SERVICE_RADIUS_KM = '10';
  globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    requests.push({ url: input.toString(), init });
    return new Response(JSON.stringify({
      routes: [{
        distanceMeters: 2400,
        polyline: { encodedPolyline: '_p~iF~ps|U_ulLnnqC' },
      }],
    }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  }) as typeof fetch;

  try {
    const route = await calculateRoadDeliveryQuote(26.75, 85.93, {
      includePolyline: true,
    });
    assert.deepEqual(route, {
      distanceMeters: 2400,
      deliveryFee: 40,
      encodedPolyline: '_p~iF~ps|U_ulLnnqC',
    });
    assert.equal(requests.length, 1);
    assert.equal(
      new Headers(requests[0].init?.headers).get('X-Goog-Api-Key'),
      'test-routes-key',
    );
    assert.equal(
      new Headers(requests[0].init?.headers).get('X-Goog-FieldMask'),
      'routes.distanceMeters,routes.polyline.encodedPolyline',
    );
    assertWithinDeliveryServiceArea(STORE_LOCATION.latitude, STORE_LOCATION.longitude);
    assertWithinDeliveryServiceArea(26.82, STORE_LOCATION.longitude);
    assert.throws(
      () => assertWithinDeliveryServiceArea(26.84, STORE_LOCATION.longitude),
      (error: unknown) =>
        error instanceof DeliveryPricingError &&
        error.statusCode === 422 &&
        error.message.includes('10 km delivery area'),
    );
    assert.throws(
      () => assertWithinDeliveryServiceArea(null, null),
      (error: unknown) =>
        error instanceof DeliveryPricingError &&
        error.statusCode === 422 &&
        error.message.includes('map pin'),
    );
    process.env.DELIVERY_SERVICE_RADIUS_KM = 'invalid';
    assert.throws(
      () => assertWithinDeliveryServiceArea(STORE_LOCATION.latitude, STORE_LOCATION.longitude),
      (error: unknown) =>
        error instanceof DeliveryPricingError &&
        error.statusCode === 503,
    );
    console.log('Route geometry and fixed delivery fee tests passed.');
  } finally {
    globalThis.fetch = originalFetch;
    if (previousApiKey === undefined) {
      delete process.env.GOOGLE_MAPS_ROUTES_API_KEY;
    } else {
      process.env.GOOGLE_MAPS_ROUTES_API_KEY = previousApiKey;
    }
    if (previousServiceRadius === undefined) {
      delete process.env.DELIVERY_SERVICE_RADIUS_KM;
    } else {
      process.env.DELIVERY_SERVICE_RADIUS_KM = previousServiceRadius;
    }
  }
}

run().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
