import type { MiddlewareHandler } from "hono";
import { eq } from "drizzle-orm";
import { db } from "../db/client";
import { users, branches } from "../db/schema";
import { readToken } from "../lib/auth";
import type { Env } from "../types";

// verifies the bearer token, then reloads the account from the db so role and
// branch are always current. writes are refused while the branch is closed.
export const requireAuth: MiddlewareHandler<Env> = async (c, next) => {
  const header = c.req.header("Authorization");
  if (!header?.startsWith("Bearer ")) {
    return c.json({ error: "missing bearer token" }, 401);
  }

  let userId: number;
  try {
    userId = (await readToken(header.slice(7), c.env.JWT_SECRET)).id;
  } catch {
    return c.json({ error: "invalid or expired token" }, 401);
  }

  const rows = await db(c.env.DB)
    .select({ user: users, branchActive: branches.active })
    .from(users)
    .leftJoin(branches, eq(branches.id, users.branchId))
    .where(eq(users.id, userId));
  const row = rows[0];
  if (!row) return c.json({ error: "account no longer exists" }, 401);

  // superadmin has no branch, so it is never blocked by a closed one.
  const branchActive = row.user.role === "superadmin" ? true : row.branchActive === true;
  if (c.req.method !== "GET" && !branchActive) {
    return c.json({ error: "cabang nonaktif, akun hanya bisa melihat data" }, 403);
  }

  c.set("user", {
    id: row.user.id,
    username: row.user.username,
    role: row.user.role,
    branchId: row.user.branchId,
    branchActive,
  });
  return next();
};

// admin of a branch, or the superadmin above them. must run after requireAuth.
export const requireAdmin: MiddlewareHandler<Env> = async (c, next) => {
  const role = c.get("user").role;
  if (role !== "admin" && role !== "superadmin") {
    return c.json({ error: "admin only" }, 403);
  }
  return next();
};

// owner-level routes: branches, money settings, moving presenters.
export const requireSuperadmin: MiddlewareHandler<Env> = async (c, next) => {
  if (c.get("user").role !== "superadmin") {
    return c.json({ error: "superadmin only" }, 403);
  }
  return next();
};
