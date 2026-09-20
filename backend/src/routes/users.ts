import { Hono } from "hono";
import { eq } from "drizzle-orm";
import { db } from "../db/client";
import { users } from "../db/schema";
import { hashPassword, randomPassword } from "../lib/auth";
import { entryIdSchema } from "../validation/schemas";
import { presentUser } from "../serializers";
import { requireSuperadmin } from "../middleware/auth";
import type { Env } from "../types";

export const userRoutes = new Hono<Env>();

// forgotten password: the superadmin issues a new one for any account. it is
// returned once here, exactly like a new branch admin's first password.
userRoutes.post("/:id/reset-password", requireSuperadmin, async (c) => {
  const id = entryIdSchema.safeParse(c.req.param("id"));
  if (!id.success) return c.json({ error: id.error.flatten() }, 422);

  const row = await db(c.env.DB).query.users.findFirst({ where: eq(users.id, id.data) });
  if (!row) return c.json({ error: "account not found" }, 404);

  const password = randomPassword();
  await db(c.env.DB)
    .update(users)
    .set({ passwordHash: await hashPassword(password) })
    .where(eq(users.id, id.data));

  return c.json({ user: presentUser(row), password });
});
