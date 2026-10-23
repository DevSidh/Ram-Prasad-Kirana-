import assert from 'node:assert/strict';
import express from 'express';
import type { RequestHandler } from 'express';
import { createPlacesRouter } from '../src/routes/places.js';

let googlePayload: unknown = {};
let lastGoogleRequest: { url: string; init?: RequestInit } | undefined;
const googleFetch: typeof fetch = async (input, init) => {
  lastGoogleRequest = { url: input.toString(), init };
  return new Response(JSON.stringify(googlePayload), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
};
const authenticate: RequestHandler = (_req, _res, next) => next();
const app = express();
app.use('/places', createPlacesRouter(
  authenticate,
  () => 'test-places-key',
  googleFetch,
));

async function run(): Promise<void> {
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const baseUrl = `http://127.0.0.1:${address.port}/places`;

    googlePayload = {
      suggestions: [
        {
          placePrediction: {
            placeId: 'place-123',
            text: { text: 'Main Road, Janakpur' },
          },
        },
        { queryPrediction: { text: { text: 'ignored result' } } },
      ],
    };
    const suggestionsResponse = await fetch(
      `${baseUrl}/autocomplete?input=M&languageCode=ne`,
    );
    assert.equal(suggestionsResponse.status, 200);
    assert.deepEqual(await suggestionsResponse.json(), {
      suggestions: [{
        placeId: 'place-123',
        description: 'Main Road, Janakpur',
      }],
    });
    assert.equal(
      lastGoogleRequest?.url,
      'https://places.googleapis.com/v1/places:autocomplete',
    );
    assert.equal(
      new Headers(lastGoogleRequest?.init?.headers).get('X-Goog-Api-Key'),
      'test-places-key',
    );
    const autocompleteBody = JSON.parse(
      lastGoogleRequest?.init?.body?.toString() ?? '{}',
    ) as Record<string, unknown>;
    assert.equal(autocompleteBody.languageCode, 'ne');
    assert.equal(autocompleteBody.input, 'M');
    assert.equal('locationBias' in autocompleteBody, false);
    assert.equal('includedRegionCodes' in autocompleteBody, false);

    googlePayload = {
      location: { latitude: 26.728, longitude: 85.925 },
      formattedAddress: 'Main Road, Janakpur, Nepal',
      displayName: { text: 'Main Road' },
    };
    const detailsResponse = await fetch(`${baseUrl}/place-123`);
    assert.equal(detailsResponse.status, 200);
    assert.deepEqual(await detailsResponse.json(), {
      place: {
        latitude: 26.728,
        longitude: 85.925,
        label: 'Main Road, Janakpur, Nepal',
      },
    });
    assert.equal(
      new Headers(lastGoogleRequest?.init?.headers).get('X-Goog-FieldMask'),
      'location,formattedAddress,displayName',
    );

    const invalidResponse = await fetch(`${baseUrl}/autocomplete?input=`);
    assert.equal(invalidResponse.status, 400);
    console.log('Places API route tests passed.');
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