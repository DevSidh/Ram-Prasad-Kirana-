import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

async function main(): Promise<void> {
  const temporaryStorage = await mkdtemp(
    path.join(os.tmpdir(), 'freshharvest-image-storage-'),
  );
  const previousDirectory = process.env.UPLOADS_DIRECTORY;
  process.env.UPLOADS_DIRECTORY = temporaryStorage;

  try {
    const { getImageMimeType, getUploadsDirectory, saveUploadedImage } = await import(
      '../src/services/image-upload.js'
    );
    const pngHeader = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
    assert.equal(getImageMimeType(pngHeader), 'image/png');
    const url = await saveUploadedImage(pngHeader);

    assert.ok(url?.startsWith('/uploads/'));
    assert.equal(getUploadsDirectory(), temporaryStorage);
    assert.deepEqual(
      await readFile(path.join(temporaryStorage, path.basename(url))),
      pngHeader,
    );
    assert.equal(await saveUploadedImage(Buffer.from('not an image')), null);
    assert.equal(getImageMimeType(Buffer.from('not an image')), null);
    console.log('Image upload persistence-path tests passed.');
  } finally {
    if (previousDirectory === undefined) {
      delete process.env.UPLOADS_DIRECTORY;
    } else {
      process.env.UPLOADS_DIRECTORY = previousDirectory;
    }
    await rm(temporaryStorage, { recursive: true, force: true });
  }
}

void main();
