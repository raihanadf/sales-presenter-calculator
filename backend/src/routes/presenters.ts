import { Hono } from "hono";
import { eq, asc } from "drizzle-orm";
import { db } from "../db/client";
import { users } from "../db/schema";
import { hashPassword } from "../lib/auth";
import { createPresenterSchema } from "../validation/schemas";
import { presentUser } from "../serializers";
import { requireAdmin } from "../middleware/auth";
import type { Env } from "../types";

// all presenter management is admin-only.
export const presenterRoutes = new Hono<Env>();
presenterRoutes.use("*", requireAdmin);

presenterRoutes.get("/", async (c) => {
  const rows = await db(c.env.DB)
    .select()
    .from(users)
    .where(eq(users.role, "presenter"))
    .orderBy(asc(users.name));
  return c.json({ presenters: rows.map(presentUser) });
});

presenterRoutes.post("/", async (c) => {
  const parsed = createPresenterSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const existing = await db(c.env.DB).query.users.findFirst({
    where: eq(users.username, parsed.data.username),
  });
  if (existing) return c.json({ error: "username already taken" }, 409);

  const inserted = await db(c.env.DB)
    .insert(users)
    .values({
      name: parsed.data.name,
      username: parsed.data.username,
      passwordHash: await hashPassword(parsed.data.password),
      role: "presenter",
      createdAt: Date.now(),
    })
    .returning();
  return c.json({ presenter: presentUser(inserted[0]) }, 201);
});
