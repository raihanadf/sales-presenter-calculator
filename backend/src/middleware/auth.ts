import type { MiddlewareHandler } from "hono";
import { readToken } from "../lib/auth";
import type { Env } from "../types";

// verifies the bearer token and stashes the user on the context.
export const requireAuth: MiddlewareHandler<Env> = async (c, next) => {
  const header = c.req.header("Authorization");
  if (!header?.startsWith("Bearer ")) {
    return c.json({ error: "missing bearer token" }, 401);
  }
  try {
    const user = await readToken(header.slice(7), c.env.JWT_SECRET);
    c.set("user", user);
  } catch {
    return c.json({ error: "invalid or expired token" }, 401);
  }
  return next();
};

// gates admin-only routes. must run after requireAuth.
export const requireAdmin: MiddlewareHandler<Env> = async (c, next) => {
  if (c.get("user").role !== "admin") {
    return c.json({ error: "admin only" }, 403);
  }
  return next();
};
