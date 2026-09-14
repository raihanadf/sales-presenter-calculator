import { Hono } from "hono";
import { eq } from "drizzle-orm";
import { db } from "../db/client";
import { users } from "../db/schema";
import { verifyPassword, issueToken } from "../lib/auth";
import { loginSchema } from "../validation/schemas";
import { presentUser } from "../serializers";
import type { Env } from "../types";

export const authRoutes = new Hono<Env>();

authRoutes.post("/login", async (c) => {
  const parsed = loginSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const row = await db(c.env.DB).query.users.findFirst({
    where: eq(users.username, parsed.data.username),
  });
  if (!row || !(await verifyPassword(parsed.data.password, row.passwordHash))) {
    return c.json({ error: "invalid credentials" }, 401);
  }

  const user = { id: row.id, username: row.username, role: row.role };
  const token = await issueToken(user, c.env.JWT_SECRET);
  return c.json({ token, user: presentUser(row) });
});
