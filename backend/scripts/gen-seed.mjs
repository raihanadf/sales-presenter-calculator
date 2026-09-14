// generates a production seed sql (settings + one admin) to stdout.
// the admin password is hashed with the same pbkdf2 scheme as src/lib/auth.ts.
//
// usage:
//   ADMIN_PASSWORD='strong-pass' node scripts/gen-seed.mjs > seed.prod.sql
//   wrangler d1 execute sales_presenter --remote --file=seed.prod.sql
//
// optional env: ADMIN_USERNAME (default "admin"), ADMIN_NAME (default "Administrator").

const ITERATIONS = 100_000;
const username = process.env.ADMIN_USERNAME ?? "admin";
const name = process.env.ADMIN_NAME ?? "Administrator";
const password = process.env.ADMIN_PASSWORD;

if (!password || password.length < 8) {
  console.error("set ADMIN_PASSWORD (min 8 chars)");
  process.exit(1);
}

const salt = crypto.getRandomValues(new Uint8Array(16));
const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", salt, iterations: ITERATIONS, hash: "SHA-256" }, key, 256);
const b64 = (b) => Buffer.from(b).toString("base64");
const hash = `pbkdf2$${ITERATIONS}$${b64(salt)}$${b64(new Uint8Array(bits))}`;
const now = Date.now();

// escape single quotes for sql string literals.
const esc = (s) => s.replace(/'/g, "''");

process.stdout.write(`-- fixed calculation values
INSERT OR IGNORE INTO settings (id, closing_price, bop_percent, souvenir_unit_price, souvenir_percent, harian_default, updated_at)
VALUES (1, 81000, 60, 6000, 60, 100000, ${now});

-- admin account
INSERT OR IGNORE INTO users (id, name, username, password_hash, role, created_at)
VALUES (1, '${esc(name)}', '${esc(username)}', '${hash}', 'admin', ${now});
`);
