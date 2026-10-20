import sharp from 'sharp';
import type { PrismaClient } from '@prisma/client';
import { getImageMimeType } from './image-upload.js';

const MAX_INPUT_PIXELS = 40_000_000;
const OUTPUT_SIZE = 640;
const PRODUCT_SIZE = 512;
const processingImages = new Map<
  string,
  Promise<StoredProductImage | null>
>();

export interface NormalizedProductImage {
  data: Buffer;
  mimeType: 'image/jpeg';
}

export async function normalizeProductImage(
  input: Buffer,
  declaredMimeType: string,
): Promise<NormalizedProductImage> {
  const detectedMimeType = getImageMimeType(input);
  if (!detectedMimeType || detectedMimeType !== declaredMimeType) {
    throw new Error('The uploaded image data does not match its file type.');
  }

  const source = sharp(input, {
    failOn: 'error',
    limitInputPixels: MAX_INPUT_PIXELS,
  });
  const metadata = await source.metadata();
  if (!metadata.width || !metadata.height ||
      !['jpeg', 'png', 'webp'].includes(metadata.format ?? '')) {
    throw new Error('Choose a supported JPEG, PNG, or WebP product image.');
  }
  if (metadata.width * metadata.height > MAX_INPUT_PIXELS) {
    throw new Error('Product images must contain 40 megapixels or fewer.');
  }

  const product = await sharp(input, {
    failOn: 'error',
    limitInputPixels: MAX_INPUT_PIXELS,
  })
    .rotate()
    .resize({
      width: PRODUCT_SIZE,
      height: PRODUCT_SIZE,
      fit: 'inside',
      withoutEnlargement: true,
    })
    .ensureAlpha()
    .png()
    .toBuffer();
  const data = await sharp({
    create: {
      width: OUTPUT_SIZE,
      height: OUTPUT_SIZE,
      channels: 3,
      background: '#ffffff',
    },
  })
    .composite([{ input: product, gravity: 'centre' }])
    .jpeg({ quality: 88, mozjpeg: true })
    .toBuffer();

  return { data, mimeType: 'image/jpeg' };
}

type StoredProductImage = {
  data: Buffer;
  mimeType: string;
};

type ProductImageRecord = {
  imageData: Uint8Array | null;
  imageMimeType: string | null;
  normalizedImageData: Uint8Array | null;
  normalizedMimeType: string | null;
};

async function normalizeStoredImage(
  key: string,
  loadSource: () => Promise<ProductImageRecord | null>,
  saveNormalized: (normalized: NormalizedProductImage) => Promise<boolean>,
  loadNormalized: () => Promise<{
    normalizedImageData: Uint8Array | null;
    normalizedMimeType: string | null;
  } | null>,
): Promise<StoredProductImage | null> {
  const existing = processingImages.get(key);
  if (existing) return existing;

  const processing = (async () => {
    const image = await loadSource();
    if (!image?.imageData || !image.imageMimeType) return null;
    if (image.normalizedImageData && image.normalizedMimeType) {
      return {
        data: Buffer.from(image.normalizedImageData),
        mimeType: image.normalizedMimeType,
      };
    }

    const normalized = await normalizeProductImage(
      Buffer.from(image.imageData),
      image.imageMimeType,
    );
    if (await saveNormalized(normalized)) return normalized;

    const latest = await loadNormalized();
    if (!latest?.normalizedImageData || !latest.normalizedMimeType) {
      throw new Error(`Normalized image ${key} was not saved.`);
    }
    return {
      data: Buffer.from(latest.normalizedImageData),
      mimeType: latest.normalizedMimeType,
    };
  })();

  processingImages.set(key, processing);
  try {
    return await processing;
  } finally {
    processingImages.delete(key);
  }
}

export function getNormalizedProductImage(
  prisma: PrismaClient,
  id: string,
): Promise<StoredProductImage | null> {
  return normalizeStoredImage(
    `product:${id}`,
    () => prisma.product.findUnique({
      where: { id },
      select: {
        imageData: true,
        imageMimeType: true,
        normalizedImageData: true,
        normalizedMimeType: true,
      },
    }),
    async (normalized) => {
      const saved = await prisma.product.updateMany({
        where: { id, normalizedImageData: null },
        data: {
          normalizedImageData: normalized.data,
          normalizedMimeType: normalized.mimeType,
        },
      });
      return saved.count > 0;
    },
    () => prisma.product.findUnique({
      where: { id },
      select: { normalizedImageData: true, normalizedMimeType: true },
    }),
  );
}

export function getNormalizedWholesaleImage(
  prisma: PrismaClient,
  id: string,
): Promise<StoredProductImage | null> {
  return normalizeStoredImage(
    `wholesaleItem:${id}`,
    () => prisma.wholesaleItem.findUnique({
      where: { id },
      select: {
        imageData: true,
        imageMimeType: true,
        normalizedImageData: true,
        normalizedMimeType: true,
      },
    }),
    async (normalized) => {
      const saved = await prisma.wholesaleItem.updateMany({
        where: { id, normalizedImageData: null },
        data: {
          normalizedImageData: normalized.data,
          normalizedMimeType: normalized.mimeType,
        },
      });
      return saved.count > 0;
    },
    () => prisma.wholesaleItem.findUnique({
      where: { id },
      select: { normalizedImageData: true, normalizedMimeType: true },
    }),
  );
}
