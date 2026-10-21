import { Router, type RequestHandler } from 'express';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';

const autocompleteInput = z.object({
  input: z.string().trim().min(3).max(200),
  sessionToken: z.string().uuid().optional(),
  locationBias: z.object({
    latitude: z.number().finite().min(-90).max(90),
    longitude: z.number().finite().min(-180).max(180),
  }).strict().optional(),
}).strict();

const detailsInput = z.object({
  placeId: z.string().trim().min(1).max(300),
  sessionToken: z.string().uuid().optional(),
}).strict();

interface GooglePlaceComponent {
  longText?: string;
  shortText?: string;
  types?: string[];
}

interface GooglePlaceDetails {
  formattedAddress?: string;
  location?: { latitude?: number; longitude?: number };
  addressComponents?: GooglePlaceComponent[];
  displayName?: { text?: string };
}

type FetchGoogle = typeof fetch;

function fieldValue(
  components: GooglePlaceComponent[],
  ...types: string[]
): string {
  for (const type of types) {
    const value = components.find((component) => component.types?.includes(type))
      ?.longText;
    if (value?.trim()) return value.trim();
  }
  return '';
}

export function createPlacesRouter(
  apiKey: string | undefined = process.env.GOOGLE_MAPS_PLACES_API_KEY,
  authenticateToken?: RequestHandler,
  fetchGoogle: FetchGoogle = fetch,
): Router {
  const router = Router();
  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 60,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many place searches. Please wait and try again.' },
  });
  if (authenticateToken) router.use(authenticateToken);
  router.use(limiter);

  router.post('/autocomplete', async (req, res) => {
    const parsed = autocompleteInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter at least three characters to search.' });
    }
    if (!apiKey?.trim()) {
      return res.status(503).json({ error: 'Place search is not configured on the server.' });
    }

    try {
      const response = await fetchGoogle(
        'https://places.googleapis.com/v1/places:autocomplete',
        {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: JSON.stringify({
            input: parsed.data.input,
            languageCode: 'en',
            includedRegionCodes: ['np'],
            locationBias: {
              circle: {
                center: parsed.data.locationBias ?? {
                  latitude: 26.728,
                  longitude: 85.925,
                },
                radius: 50_000,
              },
            },
            ...(parsed.data.sessionToken
              ? { sessionToken: parsed.data.sessionToken }
              : {}),
          }),
          signal: AbortSignal.timeout(8_000),
        },
      );
      if (!response.ok) {
        console.error('Google Places autocomplete returned HTTP', response.status);
        return res.status(502).json({ error: 'Place search is temporarily unavailable.' });
      }

      const body = await response.json() as {
        suggestions?: Array<{
          placePrediction?: {
            placeId?: string;
            text?: { text?: string };
            structuredFormat?: {
              mainText?: { text?: string };
              secondaryText?: { text?: string };
            };
          };
        }>;
      };
      const suggestions = (body.suggestions ?? [])
        .flatMap((suggestion) => {
          const prediction = suggestion.placePrediction;
          const placeId = prediction?.placeId?.trim();
          const label = prediction?.text?.text?.trim();
          if (!placeId || !label) return [];
          return [{
            placeId,
            label,
            primaryText: prediction?.structuredFormat?.mainText?.text?.trim() || label,
            secondaryText:
              prediction?.structuredFormat?.secondaryText?.text?.trim() || '',
          }];
        })
        .slice(0, 5);
      return res.json({ suggestions });
    } catch (error) {
      console.error('Google Places autocomplete request failed:', error);
      return res.status(502).json({ error: 'Place search is temporarily unavailable.' });
    }
  });

  router.post('/details', async (req, res) => {
    const parsed = detailsInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Choose a valid place from the search results.' });
    }
    if (!apiKey?.trim()) {
      return res.status(503).json({ error: 'Place search is not configured on the server.' });
    }

    try {
      const url = new URL(
        `https://places.googleapis.com/v1/places/${encodeURIComponent(parsed.data.placeId)}`,
      );
      url.searchParams.set('languageCode', 'en');
      if (parsed.data.sessionToken) {
        url.searchParams.set('sessionToken', parsed.data.sessionToken);
      }
      const response = await fetchGoogle(url, {
        headers: {
          'x-goog-api-key': apiKey,
          'x-goog-fieldmask':
            'formattedAddress,location,addressComponents,displayName',
        },
        signal: AbortSignal.timeout(8_000),
      });
      if (!response.ok) {
        console.error('Google Places details returned HTTP', response.status);
        return res.status(502).json({ error: 'Place details are temporarily unavailable.' });
      }

      const place = await response.json() as GooglePlaceDetails;
      const latitude = place.location?.latitude;
      const longitude = place.location?.longitude;
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
        return res.status(502).json({ error: 'Google did not return a valid location.' });
      }

      const components = place.addressComponents ?? [];
      return res.json({
        placeId: parsed.data.placeId,
        label: place.formattedAddress ?? place.displayName?.text ?? '',
        street: [
          fieldValue(components, 'street_number'),
          fieldValue(components, 'route', 'premise', 'sublocality', 'neighborhood'),
        ].filter(Boolean).join(' '),
        city: fieldValue(
          components,
          'locality',
          'postal_town',
          'administrative_area_level_2',
        ),
        province: fieldValue(components, 'administrative_area_level_1'),
        latitude,
        longitude,
      });
    } catch (error) {
      console.error('Google Places details request failed:', error);
      return res.status(502).json({ error: 'Place details are temporarily unavailable.' });
    }
  });

  return router;
}
