import { Hono } from "hono";
import { eq, asc } from "drizzle-orm";
import { db } from "../db/client";
import { branches, users } from "../db/schema";
import { createBranchSchema, updateBranchSchema, entryIdSchema } from "../validation/schemas";
import { presentBranch, presentUser } from "../serializers";
import { createBranch } from "../services/branches";
import { requireSuperadmin } from "../middleware/auth";
import type { Env } from "../types";

export const branchRoutes = new Hono<Env>();

// the branch list drives the superadmin's branch picker; a branch admin only
// ever needs its own, which comes back on login.
branchRoutes.get("/", requireSuperadmin, async (c) => {
  const rows = await db(c.env.DB).select().from(branches).orderBy(asc(branches.name));
  return c.json({ branches: rows.map(presentBranch) });
});

// creates the branch, its settings and its first admin account in one go.
// the generated password is returned once here and never stored in clear text.
branchRoutes.post("/", requireSuperadmin, async (c) => {
  const parsed = createBranchSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const existing = await db(c.env.DB).query.branches.findFirst({
    where: eq(branches.name, parsed.data.name),
  });
  if (existing) return c.json({ error: "nama cabang sudah dipakai" }, 409);

  const result = await createBranch(c.env.DB, parsed.data);
  if ("error" in result) return c.json({ error: result.error }, 409);

  return c.json(
    {
      branch: presentBranch(result.branch),
      admin: { username: parsed.data.admin.username, password: result.password },
    },
    201,
  );
});

// rename, or close/reopen. closed branches keep every entry they recorded;
// their members can still read but no longer write.
branchRoutes.patch("/:id", requireSuperadmin, async (c) => {
  const id = entryIdSchema.safeParse(c.req.param("id"));
  if (!id.success) return c.json({ error: id.error.flatten() }, 422);
  const parsed = updateBranchSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const updated = await db(c.env.DB)
    .update(branches)
    .set(parsed.data)
    .where(eq(branches.id, id.data))
    .returning();
  if (!updated[0]) return c.json({ error: "branch not found" }, 404);
  return c.json({ branch: presentBranch(updated[0]) });
});

// every account attached to one branch, admins included.
branchRoutes.get("/:id/members", requireSuperadmin, async (c) => {
  const id = entryIdSchema.safeParse(c.req.param("id"));
  if (!id.success) return c.json({ error: id.error.flatten() }, 422);

  const rows = await db(c.env.DB)
    .select()
    .from(users)
    .where(eq(users.branchId, id.data))
    .orderBy(asc(users.name));
  return c.json({ members: rows.map((u) => presentUser(u)) });
});
