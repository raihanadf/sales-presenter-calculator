import { Hono } from "hono";
import { eq } from "drizzle-orm";
import { db } from "../db/client";
import { users, branches } from "../db/schema";
import { hashPassword, verifyPassword } from "../lib/auth";
import { changePasswordSchema } from "../validation/schemas";
import { presentUser } from "../serializers";
import type { Env } from "../types";

export const accountRoutes = new Hono<Env>();

// who am i, with the current branch. the app calls this on launch so a moved
// presenter sees the new branch without logging out.
accountRoutes.get("/", async (c) => {
  const rows = await db(c.env.DB)
    .select({ user: users, branchName: branches.name })
    .from(users)
    .leftJoin(branches, eq(branches.id, users.branchId))
    .where(eq(users.id, c.get("user").id));
  const row = rows[0];
  if (!row) return c.json({ error: "account no longer exists" }, 401);
  return c.json({ user: presentUser(row.user, row.branchName), branchActive: c.get("user").branchActive });
});

// self-service password change. the first password of a branch admin is
// generated and sent over chat, so it has to be replaceable from the app.
accountRoutes.put("/password", async (c) => {
  const parsed = changePasswordSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const me = c.get("user");
  const row = await db(c.env.DB).query.users.findFirst({ where: eq(users.id, me.id) });
  if (!row) return c.json({ error: "account no longer exists" }, 401);
  if (!(await verifyPassword(parsed.data.currentPassword, row.passwordHash))) {
    return c.json({ error: "password lama salah" }, 401);
  }

  await db(c.env.DB)
    .update(users)
    .set({ passwordHash: await hashPassword(parsed.data.newPassword) })
    .where(eq(users.id, me.id));
  return c.json({ ok: true });
});
