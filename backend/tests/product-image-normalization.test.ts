import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import sharp from 'sharp';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';
import { normalizeProductImage } from '../src/services/product-image.js';

async function main(): Promise<void> {
  const fixtureWidth = 100;
  const fixturePixels = Buffer.alloc(fixtureWidth * fixtureWidth * 4);
  for (let y = 20; y < 50; y++) {
    for (let x = 20; x < 50; x++) {
      const offset = (y * fixtureWidth + x) * 4;
      fixturePixels.set([240, 30, 20, 128], offset);
    }
  }
  for (let y = 50; y < 80; y++) {
    for (let x = 50; x < 80; x++) {
      const offset = (y * fixtureWidth + x) * 4;
      fixturePixels.set([20, 200, 30, 255], offset);
    }
  }
  const transparentPng = await sharp(fixturePixels, {
    raw: { width: fixtureWidth, height: fixtureWidth, channels: 4 },
  }).png().toBuffer();
  const normalizedTransparent = await normalizeProductImage(
    transparentPng,
    'image/png',
  );
  const transparentMetadata = await sharp(normalizedTransparent.data).metadata();
  assert.equal(transparentMetadata.width, 640);
  assert.equal(transparentMetadata.height, 640);
  assert.equal(normalizedTransparent.mimeType, 'image/jpeg');
  const transparentRaw = await sharp(normalizedTransparent.data)
    .raw()
    .toBuffer();
  const pixelAt = (x: number, y: number) =>
    [...transparentRaw.subarray((y * 640 + x) * 3, (y * 640 + x) * 3 + 3)];
  assert.deepEqual(pixelAt(0, 0), [255, 255, 255]);
  const blendedEdge = pixelAt(305, 305);
  assert.ok(blendedEdge[0] > 220);
  assert.ok(blendedEdge[1] > 90 && blendedEdge[1] < 170);
  assert.ok(blendedEdge[2] > 80 && blendedEdge[2] < 170);
  assert.ok(pixelAt(335, 335)[1] > 160, 'opaque pixels retain their color');

  const opaqueJpeg = await sharp({
    create: {
      width: 1200,
      height: 400,
      channels: 3,
      background: { r: 25, g: 150, b: 55 },
    },
  }).jpeg().toBuffer();
  const normalizedOpaque = await normalizeProductImage(opaqueJpeg, 'image/jpeg');
  const opaqueMetadata = await sharp(normalizedOpaque.data).metadata();
  assert.equal(opaqueMetadata.width, 640);
  assert.equal(opaqueMetadata.height, 640);
  const opaqueRaw = await sharp(normalizedOpaque.data).raw().toBuffer();
  const whiteCornerOffset = 3 * (0 * 640 + 0);
  assert.ok(opaqueRaw[whiteCornerOffset]! > 245);
  assert.ok(opaqueRaw[whiteCornerOffset + 1]! > 245);
  assert.ok(opaqueRaw[whiteCornerOffset + 2]! > 245);
  const centerOffset = 3 * (320 * 640 + 320);
  assert.ok(opaqueRaw[centerOffset + 1]! > 100);
  const greenX: number[] = [];
  const greenY: number[] = [];
  for (let y = 0; y < 640; y++) {
    for (let x = 0; x < 640; x++) {
      const offset = 3 * (y * 640 + x);
      const red = opaqueRaw[offset]!;
      const green = opaqueRaw[offset + 1]!;
      const blue = opaqueRaw[offset + 2]!;
      if (green > red * 1.25 && green > blue * 1.1) {
        greenX.push(x);
        greenY.push(y);
      }
    }
  }
  const greenWidth = Math.max(...greenX) - Math.min(...greenX) + 1;
  const greenHeight = Math.max(...greenY) - Math.min(...greenY) + 1;
  assert.ok(
    greenWidth / greenHeight > 2.6 && greenWidth / greenHeight < 3.4,
    'the product aspect ratio is preserved instead of stretched',
  );

  const largeImage = await sharp({
    create: {
      width: 2200,
      height: 1600,
      channels: 3,
      background: { r: 40, g: 90, b: 190 },
    },
  }).jpeg().toBuffer();
  assert.equal(
    (await sharp((await normalizeProductImage(largeImage, 'image/jpeg')).data)
      .metadata()).width,
    640,
  );

  const overLimitHeader = Buffer.from(transparentPng);
  overLimitHeader.writeUInt32BE(7000, 16);
  overLimitHeader.writeUInt32BE(7000, 20);
  await assert.rejects(
    normalizeProductImage(overLimitHeader, 'image/png'),
    /pixel limit|40 megapixels/,
  );
  await assert.rejects(
    normalizeProductImage(Buffer.from('corrupt image'), 'image/png'),
  );
  await assert.rejects(
    normalizeProductImage(opaqueJpeg, 'image/png'),
    /does not match its file type/,
  );

  const originalUpload = Buffer.from(transparentPng);
  let storedImage: Record<string, unknown> | null = null;
  const prisma = {
    storedImage: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        storedImage = data;
        return { id: 'product-image-1' };
      },
    },
  } as unknown as PrismaClient;
  const allow: RequestHandler = (_req, _res, next) => next();
  const app = express();
  app.use('/admin', createAdminRouter(prisma, allow, allow));
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/admin/uploads/product-images`;
    const upload = (bytes: Buffer, filename: string) => {
      const form = new FormData();
      form.append('image', new Blob([bytes]), filename);
      return fetch(endpoint, { method: 'POST', body: form });
    };
    const response = await upload(originalUpload, 'transparent.png');
    assert.equal(response.status, 201);
    assert.deepEqual(storedImage?.imageData, originalUpload);
    assert.equal(storedImage?.mimeType, 'image/png');
    assert.equal(storedImage?.normalizedMimeType, 'image/jpeg');
    assert.ok(storedImage?.normalizedImageData instanceof Buffer);

    const corruptImage = Buffer.concat([
      Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
      Buffer.from('broken image payload'),
    ]);
    const corruptResponse = await upload(corruptImage, 'broken.png');
    assert.equal(corruptResponse.status, 422);
    assert.deepEqual(storedImage?.imageData, originalUpload);

    const oversizedResponse = await upload(
      Buffer.alloc(5 * 1024 * 1024 + 1),
      'oversized.png',
    );
    assert.equal(oversizedResponse.status, 413);
    assert.deepEqual(storedImage?.imageData, originalUpload);
    console.log('Product image normalization and safe-upload tests passed.');
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

void main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
