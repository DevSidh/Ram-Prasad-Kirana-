import { writeFileSync } from 'node:fs';
import { manifest, stagingSql } from './schema.mjs';

const metadata = manifest();
writeFileSync(new URL('schema-manifest.json', import.meta.url), JSON.stringify(metadata, null, 2) + '\n');
writeFileSync(new URL('staging-schema.sql', import.meta.url),
  '-- LOSSLESS STAGING ONLY. Not compatible with the current application runtime.\n' +
  '-- Foreign keys must be enabled by the importing connection.\n' +
  stagingSql(metadata).join(';\n\n') + ';\n');
console.log(`Generated ${metadata.models.length} models; ${metadata.enums.length} enums. No database contacted.`);
