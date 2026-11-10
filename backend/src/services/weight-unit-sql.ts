import { Prisma } from '@prisma/client';

/** SQLite equivalent of the inventory numeric kg/g label rule (Product alias p). */
export function weightUnitSql(): Prisma.Sql {
  const whitespace = Prisma.sql`' ' || CHAR(9) || CHAR(10) || CHAR(13) || CHAR(11) || CHAR(12)`;
  const label = Prisma.sql`LOWER(TRIM(p."unitLabel", ${whitespace}))`;
  const number = Prisma.sql`TRIM(SUBSTR(${label}, 1, LENGTH(${label}) - CASE WHEN SUBSTR(${label}, -2) = 'kg' THEN 2 ELSE 1 END), ${whitespace})`;
  return Prisma.sql`(SUBSTR(${label}, -1) = 'g'
    AND ${number} <> ''
    AND ${number} NOT GLOB '*[^0-9.]*'
    AND SUBSTR(${number}, 1, 1) GLOB '[0-9]'
    AND SUBSTR(${number}, -1) GLOB '[0-9]'
    AND LENGTH(${number}) - LENGTH(REPLACE(${number}, '.', '')) <= 1)`;
}
