import type { MiddlewareHandler } from "hono";
import type { Env } from "../types";

// "1.2.0" -> [1, 2, 0]. a missing or malformed part counts as 0, so an app
// that reports garbage is treated as old rather than as up to date.
function parts(version: string): number[] {
  return version.split(".").map((p) => Number.parseInt(p, 10) || 0);
}

function isOlder(version: string, minimum: string): boolean {
  const a = parts(version);
  const b = parts(minimum);
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const left = a[i] ?? 0;
    const right = b[i] ?? 0;
    if (left !== right) return left < right;
  }
  return false;
}

// blocks writes from an app build older than MIN_APP_VERSION. reads stay open
// so someone can still look at their history while the update downloads.
// no header at all means an old build that predates the header, so it is
// blocked too -- otherwise the gate could be skipped by sending nothing.
export const requireAppVersion: MiddlewareHandler<Env> = async (c, next) => {
  if (c.req.method === "GET") return next();

  const version = c.req.header("X-App-Version");
  if (!version || isOlder(version, c.env.MIN_APP_VERSION)) {
    return c.json(
      {
        error: "versi aplikasi sudah lama, update dulu sebelum mencatat data",
        minVersion: c.env.MIN_APP_VERSION,
      },
      426,
    );
  }
  return next();
};
