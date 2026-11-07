import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const require = createRequire(import.meta.url);
const { Prisma } = require('@prisma/client');
export const schemaPath = new URL('../prisma/schema.prisma', import.meta.url);
export const schemaText = readFileSync(schemaPath, 'utf8');
export const sha256 = (value) => createHash('sha256').update(value).digest('hex');
export const quote = (identifier) => '"' + identifier.replaceAll('"', '""') + '"';
export const literal = (value) => "'" + String(value).replaceAll("'", "''") + "'";

// Only generated model metadata is used. Regenerate the existing client before
// running this tool; field names are checked against the source schema below.
export function manifest() {
  const models = Prisma.dmmf.datamodel.models.map((model) => {
    const block = new RegExp(`model\\s+${model.name}\\s*\\{([\\s\\S]*?)\\n\\}`).exec(schemaText)?.[1];
    if (!block) throw new Error(`Generated client is stale: ${model.name}`);
    if (/@@map|@map|Unsupported\(/.test(block)) {
      throw new Error(`Explicit migration mapping required for ${model.name}`);
    }
    const declared = [...block.matchAll(/^[ \t]*(\w+)[ \t]+([\w]+[?\[\]]*)/gm)]
      .map((match) => match[1]);
    if (declared.length !== model.fields.length || model.fields.some((f) => !declared.includes(f.name))) {
      throw new Error(`Regenerate Prisma client: schema differs for ${model.name}: ${declared.length}/${model.fields.length}; extra=${declared.filter(n=>!model.fields.some(f=>f.name===n))}; missing=${model.fields.filter(f=>!declared.includes(f.name)).map(f=>f.name)}`);
    }
    const indexes = [...block.matchAll(/@@index\(\[([^\]]+)\]\)/g)].map((match) =>
      match[1].split(',').map((field) => field.trim()));
    const unsupportedIndexes = [...block.matchAll(/@@index\(([^\n]+)\)/g)]
      .filter((match) => !/^\[\w+(?:\s*,\s*\w+)*\]$/.test(match[1]));
    if (unsupportedIndexes.length) throw new Error(`Index mapping required for ${model.name}`);
    return {
      name: model.name,
      fields: model.fields.filter((f) => f.kind !== 'object').map((f) => ({
        name: f.name, type: f.type, kind: f.kind, required: f.isRequired,
        id: f.isId, unique: f.isUnique, default: f.default,
      })),
      primaryKey: model.primaryKey?.fields ?? model.fields.filter((f) => f.isId).map((f) => f.name),
      uniqueFields: model.uniqueFields,
      indexes,
      relations: model.fields.filter((f) => f.relationFromFields?.length).map((f) => ({
        fields: f.relationFromFields, target: f.type, references: f.relationToFields,
        onDelete: f.relationOnDelete ?? (f.isRequired ? 'Restrict' : 'SetNull'),
        onUpdate: f.relationOnUpdate ?? 'Cascade',
      })),
    };
  });
  const declaredModels = [...schemaText.matchAll(/^model\s+(\w+)\s*\{/gm)].length;
  if (models.length !== declaredModels) throw new Error('Generated model count differs; run prisma:generate.');
  return {
    format: 1, purpose: 'lossless-staging-only', sourceSchemaSha256: sha256(schemaText),
    enums: Prisma.dmmf.datamodel.enums.map((e) => ({name: e.name, values: e.values.map((v) => v.name)})),
    models,
  };
}

export function stagingSql(metadata) {
  const types = {String:'TEXT', Int:'INTEGER', BigInt:'INTEGER', Boolean:'INTEGER',
    Float:'REAL', Decimal:'TEXT', DateTime:'TEXT', Bytes:'BLOB', Json:'TEXT'};
  const actions = {Cascade:'CASCADE', Restrict:'RESTRICT', NoAction:'NO ACTION', SetNull:'SET NULL', SetDefault:'SET DEFAULT'};
  const statements = [];
  for (const model of metadata.models) {
    const columns = model.fields.map((field) => {
      const type = field.kind === 'enum' ? 'TEXT' : types[field.type];
      if (!type) throw new Error(`Unsupported field ${model.name}.${field.name}`);
      let sql = `${quote(field.name)} ${type}${field.required ? ' NOT NULL' : ''}`;
      const value = field.default;
      // cuid(), updatedAt and sequences are application responsibilities. This
      // staging schema accepts only complete exported records, never app writes.
      if (value !== undefined && (typeof value !== 'object' || value === null)) {
        sql += ` DEFAULT ${typeof value === 'boolean' ? Number(value) : literal(value)}`;
      }
      if (field.type === 'Boolean') sql += ` CHECK (${quote(field.name)} IN (0, 1))`;
      if (field.kind === 'enum') {
        const values = metadata.enums.find((e) => e.name === field.type)?.values;
        if (!values) throw new Error(`Missing enum ${field.type}`);
        sql += ` CHECK (${quote(field.name)} IN (${values.map(literal).join(', ')}))`;
      }
      if (field.type === 'Json') sql += ` CHECK (json_valid(${quote(field.name)}))`;
      if (field.type === 'Int') sql += ` CHECK (${quote(field.name)} BETWEEN -2147483648 AND 2147483647)`;
      return sql;
    });
    columns.push(`PRIMARY KEY (${model.primaryKey.map(quote).join(', ')})`);
    for (const fields of [...model.uniqueFields, ...model.fields.filter((f) => f.unique).map((f) => [f.name])]) {
      columns.push(`UNIQUE (${fields.map(quote).join(', ')})`);
    }
    for (const relation of model.relations) {
      if (!actions[relation.onDelete] || !actions[relation.onUpdate]) throw new Error('Unsupported FK action');
      columns.push(`FOREIGN KEY (${relation.fields.map(quote).join(', ')}) REFERENCES ${quote(relation.target)} (${relation.references.map(quote).join(', ')}) ON DELETE ${actions[relation.onDelete]} ON UPDATE ${actions[relation.onUpdate]} DEFERRABLE INITIALLY DEFERRED`);
    }
    statements.push(`CREATE TABLE ${quote(model.name)} (\n  ${columns.join(',\n  ')}\n)`);
    for (const fields of model.indexes) {
      statements.push(`CREATE INDEX ${quote(model.name + '_' + fields.join('_') + '_idx')} ON ${quote(model.name)} (${fields.map(quote).join(', ')})`);
    }
  }
  return statements;
}
