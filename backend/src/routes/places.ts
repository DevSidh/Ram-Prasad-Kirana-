import { Router, type RequestHandler } from 'express';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';

const autocompleteQuery = z.object({
  input: z.string().trim().min(3).max(200),
  latitude: z.coerce.number().finite().min(-90).max(90).optional(),
  longitude: z.coerce.number().finite().min(-180).max(180).optional(),
  languageCode: z.enum(['en', 'ne']).default('en'),
}).strict().refine(
  ({ latitude, longitude }) =>
    (latitude === undefined) === (longitude === undefined),
  { message: 'Latitude and longitude must be provided together.' },
);

type GoogleFetch = typeof fetch;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function apiKey(): string | undefined {
  return process.env.GOOGLE_MAPS_PLACES_API_KEY?.trim();
}

function googleHeaders(key: string, fieldMask?: string): HeadersInit {
  return {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': key,
    ...(fieldMask ? { 'X-Goog-FieldMask': fieldMask } : {}),
  };
}

export function createPlacesRouter(
  authenticateToken: RequestHandler,
  getApiKey: () => string | undefined = apiKey,
  googleFetch: GoogleFetch = fetch,
): Router {
  const router = Router();
  router.use(rateLimit({
    windowMs: 60_000,
    limit: 30,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many place searches. Please wait and try again.' },
  }));
  router.use(authenticateToken);

  router.get('/autocomplete', async (req, res) => {
    const parsed = autocompleteQuery.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter a valid place search.' });
    }
    const key = getApiKey();
    if (!key) {
      return res.status(503).json({ error: 'Place search is not configured.' });
    }

    const { input, latitude, longitude, languageCode } = parsed.data;
    try {
      const response = await googleFetch(
        'https://places.googleapis.com/v1/places:autocomplete',
        {
          method: 'POST',
          headers: googleHeaders(key),
          body: JSON.stringify({
            input,
            languageCode,
            includedRegionCodes: ['np'],
            ...(latitude !== undefined && longitude !== undefined
              ? {
                  locationBias: {
                    circle: {
                      center: { latitude, longitude },
                      radius: 10_000,
                    },
                  },
                }
              : {}),
          }),
          signal: AbortSignal.timeout(8000),
        },
      );
      if (!response.ok) {
        console.error('Google Places autocomplete failed with status:', response.status);
        return res.status(502).json({
          error: 'Place search is temporarily unavailable.',
        });
      }

      const payload: unknown = await response.json();
      const suggestions = isRecord(payload) && Array.isArray(payload.suggestions)
        ? payload.suggestions.flatMap((entry) => {
            if (!isRecord(entry) || !isRecord(entry.placePrediction)) return [];
            const prediction = entry.placePrediction;
            const text = isRecord(prediction.text) ? prediction.text.text : null;
            const placeId = prediction.placeId;
            return typeof text === 'string' && typeof placeId === 'string'
              ? [{ placeId, description: text }]
              : [];
          })
        : [];
      return res.json({ suggestions });
    } catch (error) {
      console.error('Google Places autocomplete request failed:', error);
      return res.status(502).json({
        error: 'Place search is temporarily unavailable.',
      });
    }
  });

  router.get('/:placeId', async (req, res) => {
    const placeId = z.string().trim().min(1).max(512).safeParse(req.params.placeId);
    if (!placeId.success) {
      return res.status(400).json({ error: 'Enter a valid place.' });
    }
    const key = getApiKey();
    if (!key) {
      return res.status(503).json({ error: 'Place search is not configured.' });
    }

    try {
      const response = await googleFetch(
        `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId.data)}`,
        {
          headers: googleHeaders(
            key,
            'location,formattedAddress,displayName',
          ),
          signal: AbortSignal.timeout(8000),
        },
      );
      if (!response.ok) {
        console.error('Google Place details failed with status:', response.status);
        return res.status(502).json({
          error: 'Place details are temporarily unavailable.',
        });
      }

      const payload: unknown = await response.json();
      const location = isRecord(payload) && isRecord(payload.location)
        ? payload.location
        : null;
      const latitude = location?.latitude;
      const longitude = location?.longitude;
      if (
        typeof latitude !== 'number' ||
        !Number.isFinite(latitude) ||
        typeof longitude !== 'number' ||
        !Number.isFinite(longitude)
      ) {
        return res.status(502).json({
          error: 'The selected place has no usable map location.',
        });
      }
      const formattedAddress = isRecord(payload) &&
          typeof payload.formattedAddress === 'string'
        ? payload.formattedAddress
        : '';
      const displayName = isRecord(payload) && isRecord(payload.displayName) &&
          typeof payload.displayName.text === 'string'
        ? payload.displayName.text
        : '';
      return res.json({
        place: {
          latitude,
          longitude,
          label: formattedAddress || displayName,
        },
      });
    } catch (error) {
      console.error('Google Place details request failed:', error);
      return res.status(502).json({
        error: 'Place details are temporarily unavailable.',
      });
    }
  });

  return router;
}