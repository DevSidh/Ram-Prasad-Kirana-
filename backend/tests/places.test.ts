import assert from 'node:assert/strict';
import express from 'express';
import { createPlacesRouter } from '../src/routes/places.js';

async function run(): Promise<void> {
  const requests: Array<{ url: string; init?: RequestInit }> = [];
  const fakeFetch: typeof fetch = async (input, init) => {
    const url = input instanceof URL ? input.toString() : input.toString();
    requests.push({ url, init });
    if (url.endsWith('/places:autocomplete')) {
      return new Response(JSON.stringify({
        suggestions: [{
          placePrediction: {
            placeId: 'ChIJplace-id',
            text: { text: 'Janakpur, Nepal' },
            structuredFormat: {
              mainText: { text: 'Janakpur' },
              secondaryText: { text: 'Nepal' },
            },
          },
        }],
      }), { status: 200 });
    }
    return new Response(JSON.stringify({
      formattedAddress: 'Janakpur, Nepal',
      location: { latitude: 26.728, longitude: 85.925 },
      addressComponents: [
        { longText: 'Janakpur', types: ['locality'] },
        { longText: 'Madhesh Province', types: ['administrative_area_level_1'] },
      ],
    }), { status: 200 });
  };

  const app = express();
  app.use(express.json());
  app.use('/places', createPlacesRouter('server-secret-key', undefined, fakeFetch));
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/places`;
    const sessionToken = 'f0f8fad5-9fb7-48d9-9e7e-3f1b4a9834c7';

    const autocomplete = await fetch(`${endpoint}/autocomplete`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        input: 'Janakpur',
        sessionToken,
        locationBias: { latitude: 26.728, longitude: 85.925 },
      }),
    });
    assert.equal(autocomplete.status, 200);
    assert.deepEqual(await autocomplete.json(), {
      suggestions: [{
        placeId: 'ChIJplace-id',
        label: 'Janakpur, Nepal',
        primaryText: 'Janakpur',
        secondaryText: 'Nepal',
      }],
    });
    const autocompleteRequest = requests[0];
    assert.equal(autocompleteRequest.init?.method, 'POST');
    assert.equal(
      (autocompleteRequest.init?.headers as Record<string, string>)['x-goog-api-key'],
      'server-secret-key',
    );
    assert.equal(
      JSON.parse(String(autocompleteRequest.init?.body)).sessionToken,
      sessionToken,
    );

    const details = await fetch(`${endpoint}/details`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ placeId: 'ChIJplace-id', sessionToken }),
    });
    assert.equal(details.status, 200);
    assert.deepEqual(await details.json(), {
      placeId: 'ChIJplace-id',
      label: 'Janakpur, Nepal',
      street: '',
      city: 'Janakpur',
      province: 'Madhesh Province',
      latitude: 26.728,
      longitude: 85.925,
    });

    const invalid = await fetch(`${endpoint}/autocomplete`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ input: 'x' }),
    });
    assert.equal(invalid.status, 400);
    console.log('Places autocomplete and details tests passed.');
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

void run().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
