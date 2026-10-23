export const STORE_LOCATION = {
  latitude: 26.743218,
  longitude: 85.918854,
} as const;

export const DEFAULT_DELIVERY_FEE = 40;
export const DEFAULT_DELIVERY_SERVICE_RADIUS_KM = 10;
const EARTH_RADIUS_METERS = 6_371_000;

export class DeliveryPricingError extends Error {
  constructor(
    message: string,
    readonly statusCode: number,
  ) {
    super(message);
  }
}

export function assertWithinDeliveryServiceArea(
  latitude: number | null,
  longitude: number | null,
): void {
  if (latitude === null || longitude === null) {
    throw new DeliveryPricingError(
      `Add a map pin within ${getDeliveryServiceRadiusKm()} km of the store to place an order.`,
      422,
    );
  }
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
      !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new DeliveryPricingError('The delivery location is invalid.', 422);
  }

  const radiusKm = getDeliveryServiceRadiusKm();
  const toRadians = (degrees: number) => degrees * Math.PI / 180;
  const latitudeDelta = toRadians(latitude - STORE_LOCATION.latitude);
  const longitudeDelta = toRadians(longitude - STORE_LOCATION.longitude);
  const haversine = Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(toRadians(STORE_LOCATION.latitude)) *
      Math.cos(toRadians(latitude)) *
      Math.sin(longitudeDelta / 2) ** 2;
  const distanceMeters = 2 * EARTH_RADIUS_METERS *
    Math.atan2(Math.sqrt(Math.min(1, haversine)), Math.sqrt(Math.max(0, 1 - haversine)));

  if (distanceMeters > radiusKm * 1000) {
    throw new DeliveryPricingError(
      `This address is outside the ${radiusKm} km delivery area.`,
      422,
    );
  }
}

function getDeliveryServiceRadiusKm(): number {
  const configuredRadius = process.env.DELIVERY_SERVICE_RADIUS_KM?.trim();
  if (!configuredRadius) return DEFAULT_DELIVERY_SERVICE_RADIUS_KM;

  const radiusKm = Number(configuredRadius);
  if (!Number.isFinite(radiusKm) || radiusKm <= 0) {
    throw new DeliveryPricingError(
      'The delivery service area is not configured correctly. Contact the store.',
      503,
    );
  }
  return radiusKm;
}

export async function calculateRoadDeliveryQuote(
  latitude: number | null,
  longitude: number | null,
  options: {
    includePolyline?: boolean;
    origin?: { latitude: number; longitude: number };
  } = {},
): Promise<{
  distanceMeters: number;
  deliveryFee: number;
  encodedPolyline?: string;
}> {
  if (latitude === null || longitude === null) {
    throw new DeliveryPricingError(
      'Add a map pin to this delivery address before calculating road distance.',
      422,
    );
  }
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
      !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new DeliveryPricingError('The delivery location is invalid.', 422);
  }

  const apiKey = process.env.GOOGLE_MAPS_ROUTES_API_KEY?.trim();
  if (!apiKey) {
    throw new DeliveryPricingError(
      'Road-distance pricing is not configured. Contact the store.',
      503,
    );
  }

  let response: Response;
  try {
    response = await fetch(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': options.includePolyline
            ? 'routes.distanceMeters,routes.polyline.encodedPolyline'
            : 'routes.distanceMeters',
        },
        body: JSON.stringify({
          origin: {
            location: {
              latLng: {
                latitude: options.origin?.latitude ?? STORE_LOCATION.latitude,
                longitude: options.origin?.longitude ?? STORE_LOCATION.longitude,
              },
            },
          },
          destination: {
            location: { latLng: { latitude, longitude } },
          },
          travelMode: 'DRIVE',
          routingPreference: 'TRAFFIC_UNAWARE',
        }),
        signal: AbortSignal.timeout(8000),
      },
    );
  } catch (error) {
    if (error instanceof Error && error.name === 'TimeoutError') {
      throw new DeliveryPricingError(
        'The road-distance service timed out. Please try again.',
        503,
      );
    }
    throw new DeliveryPricingError(
      'The road-distance service could not be reached. Please try again.',
      503,
    );
  }

  if (!response.ok) {
    throw new DeliveryPricingError(
      'The road-distance service could not calculate this route.',
      502,
    );
  }

  let data: unknown;
  try {
    data = await response.json();
  } catch {
    throw new DeliveryPricingError(
      'The road-distance service returned an invalid response.',
      502,
    );
  }
  if (
    typeof data !== 'object' ||
    data === null ||
    !('routes' in data) ||
    !Array.isArray(data.routes) ||
    data.routes.length === 0
  ) {
    throw new DeliveryPricingError(
      'No drivable route was found for this delivery address.',
      422,
    );
  }

  const distanceMeters = data.routes[0]?.distanceMeters;
  if (
    typeof distanceMeters !== 'number' ||
    !Number.isFinite(distanceMeters) ||
    distanceMeters < 0
  ) {
    throw new DeliveryPricingError(
      'The road-distance service returned an invalid route distance.',
      502,
    );
  }
  let encodedPolyline: string | undefined;
  if (options.includePolyline) {
    const polyline = data.routes[0]?.polyline;
    if (
      typeof polyline !== 'object' ||
      polyline === null ||
      !('encodedPolyline' in polyline) ||
      typeof polyline.encodedPolyline !== 'string' ||
      polyline.encodedPolyline.length === 0
    ) {
      throw new DeliveryPricingError(
        'The road-distance service did not return a route line.',
        502,
      );
    }
    encodedPolyline = polyline.encodedPolyline;
  }

  return {
    distanceMeters,
    deliveryFee: DEFAULT_DELIVERY_FEE,
    ...(encodedPolyline === undefined ? {} : { encodedPolyline }),
  };
}
