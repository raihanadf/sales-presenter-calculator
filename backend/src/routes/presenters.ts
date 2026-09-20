import { Hono } from "hono";
import { eq, and, asc } from "drizzle-orm";
import { db } from "../db/client";
import { users, branches } from "../db/schema";
import { hashPassword } from "../lib/auth";
import {
  createPresenterSchema,
  movePresenterSchema,
  branchQuerySchema,
  entryIdSchema,
} from "../validation/schemas";
import { presentUser } from "../serializers";
import { requireAdmin, requireSuperadmin } from "../middleware/auth";
import { resolveBranchScope } from "../lib/scope";
import type { Env } from "../types";

// all presenter management is admin-only, and scoped to the admin's branch.
export const presenterRoutes = new Hono<Env>();
presenterRoutes.use("*", requireAdmin);

presenterRoutes.get("/", async (c) => {
  const parsed = branchQuerySchema.safeParse(c.req.query());
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const scope = resolveBranchScope(c.get("user"), parsed.data.branchId);
  const filters = [eq(users.role, "presenter")];
  if (scope !== null) filters.push(eq(users.branchId, scope));

  const rows = await db(c.env.DB)
    .select({ user: users, branchName: branches.name })
    .from(users)
    .leftJoin(branches, eq(branches.id, users.branchId))
    .where(and(...filters))
    .orderBy(asc(users.name));
  return c.json({ presenters: rows.map((r) => presentUser(r.user, r.branchName)) });
});

presenterRoutes.post("/", async (c) => {
  const parsed = createPresenterSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  // a branch admin creates inside its own branch; the superadmin must say where.
  const me = c.get("user");
  const branchId = me.role === "superadmin" ? parsed.data.branchId : me.branchId;
  if (!branchId) return c.json({ error: "branchId wajib diisi" }, 422);
  const branch = await db(c.env.DB).query.branches.findFirst({ where: eq(branches.id, branchId) });
  if (!branch) return c.json({ error: "branch not found" }, 404);
  resolveBranchScope(me, branchId);

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
      branchId,
      createdAt: Date.now(),
    })
    .returning();
  return c.json({ presenter: presentUser(inserted[0], branch.name) }, 201);
});

// superadmin only: pull a presenter into another branch. past entries keep the
// branch they were recorded in, so old recaps never shift.
presenterRoutes.patch("/:id/branch", requireSuperadmin, async (c) => {
  const id = entryIdSchema.safeParse(c.req.param("id"));
  if (!id.success) return c.json({ error: id.error.flatten() }, 422);
  const parsed = movePresenterSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const branch = await db(c.env.DB).query.branches.findFirst({
    where: eq(branches.id, parsed.data.branchId),
  });
  if (!branch) return c.json({ error: "branch not found" }, 404);
  if (!branch.active) return c.json({ error: "cabang tujuan nonaktif" }, 409);

  const updated = await db(c.env.DB)
    .update(users)
    .set({ branchId: parsed.data.branchId })
    .where(and(eq(users.id, id.data), eq(users.role, "presenter")))
    .returning();
  if (!updated[0]) return c.json({ error: "presenter not found" }, 404);
  return c.json({ presenter: presentUser(updated[0], branch.name) });
});
