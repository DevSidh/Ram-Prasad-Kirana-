import { randomUUID } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import multer from 'multer';
import type { RequestHandler } from 'express';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024, files: 1 },
});
const supplierBillUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024, files: 1 },
});
export function getUploadsDirectory(): string {
  const configuredDirectory = process.env.UPLOADS_DIRECTORY?.trim();
  return path.resolve(
    configuredDirectory || path.join(process.cwd(), 'uploads'),
  );
}

export const receiveSingleImage: RequestHandler = (req, res, next) => {
  upload.single('image')(req, res, (error: unknown) => {
    if (error instanceof multer.MulterError) {
      const status = error.code === 'LIMIT_FILE_SIZE' ? 413 : 400;
      return res.status(status).json({
        error: error.code === 'LIMIT_FILE_SIZE'
          ? 'Images must be 5 MB or smaller.'
          : 'Choose one image file to upload.',
      });
    }
    if (error) return next(error);
    return next();
  });
};

export const receiveSingleSupplierBillImage: RequestHandler = (req, res, next) => {
  supplierBillUpload.single('image')(req, res, (error: unknown) => {
    if (error instanceof multer.MulterError) {
      const status = error.code === 'LIMIT_FILE_SIZE' ? 413 : 400;
      return res.status(status).json({
        error: error.code === 'LIMIT_FILE_SIZE'
          ? 'Supplier bill photos must be 5 MB or smaller.'
          : 'Choose one supplier bill photo to upload.',
      });
    }
    if (error) return next(error);
    return next();
  });
};

export function getImageMimeType(buffer: Buffer): string | null {
  if (
    buffer.length >= 8 &&
    buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
  ) {
    return 'image/png';
  }
  if (
    buffer.length >= 3 &&
    buffer[0] === 0xff &&
    buffer[1] === 0xd8 &&
    buffer[2] === 0xff
  ) {
    return 'image/jpeg';
  }
  if (
    buffer.length >= 12 &&
    buffer.toString('ascii', 0, 4) === 'RIFF' &&
    buffer.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return 'image/webp';
  }

  return null;
}

export async function saveUploadedImage(buffer: Buffer): Promise<string | null> {
  const mimeType = getImageMimeType(buffer);
  const extension = mimeType === 'image/png'
    ? '.png'
    : mimeType === 'image/jpeg'
      ? '.jpg'
      : mimeType === 'image/webp'
        ? '.webp'
        : null;
  if (!extension) return null;

  const filename = `${randomUUID()}${extension}`;
  const uploadDirectory = getUploadsDirectory();
  await mkdir(uploadDirectory, { recursive: true });
  await writeFile(path.join(uploadDirectory, filename), buffer, { flag: 'wx' });
  return `/uploads/${filename}`;
}
