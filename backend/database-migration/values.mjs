const minimumInteger = -(2n ** 63n);
const maximumInteger = 2n ** 63n - 1n;

export function decimalText(value) {
  // Canonical exact base-10 representation; never parse currency as Number.
  const match = /^([+-]?)(\d+)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$/.exec(String(value));
  if (!match) throw new Error('Invalid decimal value');
  const exponent = Number(match[4] ?? 0);
  if (!Number.isSafeInteger(exponent) || Math.abs(exponent) > 10000) throw new Error('Decimal exponent out of range');
  let digits = match[2] + (match[3] ?? '');
  const decimalPosition = match[2].length + exponent;
  let text = decimalPosition <= 0 ? '0.' + '0'.repeat(-decimalPosition) + digits
    : decimalPosition >= digits.length ? digits + '0'.repeat(decimalPosition - digits.length)
    : digits.slice(0, decimalPosition) + '.' + digits.slice(decimalPosition);
  text = text.replace(/^0+(?=\d)/, '').replace(/(\.\d*?)0+$/, '$1').replace(/\.$/, '');
  if (/^0(?:\.0*)?$/.test(text)) return '0';
  return (match[1] === '-' ? '-' : '') + text;
}

export function timestampText(value) {
  let text = String(value).replace(' ', 'T');
  text = text.replace(/\+00(?::00)?$/, 'Z');
  // CockroachDB's timestamp-without-time-zone text is rendered without an
  // offset. The exporter sets its transaction time zone to UTC, so attaching Z
  // preserves that exact UTC wall-clock value rather than using this machine's
  // local time zone.
  if (/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?$/.test(text)) text += 'Z';
  if (!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?Z$/.test(text) || !Number.isFinite(Date.parse(text))) {
    throw new Error('Timestamp must be a UTC instant, with at most microsecond precision');
  }
  return text;
}

export function encodeValue(field, value) {
  if (value === null) {
    if (field.required) throw new Error('Required value is null');
    return null;
  }
  if (typeof value !== 'string') throw new Error('Export fields must be lossless text or null');
  switch (field.type) {
    case 'Boolean':
      if (!['true','false','t','f'].includes(value)) throw new Error('Invalid boolean');
      return ['true','t'].includes(value) ? 1n : 0n;
    case 'BigInt': case 'Int': {
      if (!/^-?\d+$/.test(value)) throw new Error('Invalid integer');
      const integer = BigInt(value);
      if (integer < minimumInteger || integer > maximumInteger) throw new Error('Integer exceeds SQLite signed 64-bit range');
      if (field.type === 'Int' && (integer < -2147483648n || integer > 2147483647n)) throw new Error('Integer exceeds API 32-bit range');
      return integer;
    }
    case 'Float': {
      const number = Number(value);
      if (!value.trim() || !Number.isFinite(number)) throw new Error('Invalid floating-point value');
      return number;
    }
    case 'Decimal': return decimalText(value);
    case 'DateTime': return timestampText(value);
    case 'Json': JSON.parse(value); return value;
    case 'Bytes':
      if (Buffer.from(value,'base64').toString('base64') !== value) throw new Error('Invalid base64');
      return Buffer.from(value, 'base64');
    default: return value;
  }
}
