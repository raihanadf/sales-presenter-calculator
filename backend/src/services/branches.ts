import { eq } from "drizzle-orm";
import { db } from "../db/client";
import { branches, settings, users } from "../db/schema";
import { hashPassword, randomPassword } from "../lib/auth";
import type { CreateBranchDto } from "../validation/schemas";

// a branch is only ever created complete: its money settings and its first
// admin account come with it. if the dependents fail the branch row is removed
// again, so there is no half-built branch for anyone to log into.
export async function createBranch(d1: D1Database, input: CreateBranchDto) {
  const d = db(d1);
  const now = Date.now();

  const taken = await d.query.users.findFirst({
    where: eq(users.username, input.admin.username),
  });
  if (taken) return { error: "username already taken" as const };

  const branch = (
    await d.insert(branches).values({ name: input.name, active: true, createdAt: now }).returning()
  )[0];

  const password = randomPassword();
  try {
    await d.batch([
      d.insert(settings).values({ ...input.settings, branchId: branch.id, updatedAt: now }),
      d.insert(users).values({
        name: input.admin.name,
        username: input.admin.username,
        passwordHash: await hashPassword(password),
        role: "admin",
        branchId: branch.id,
        createdAt: now,
      }),
    ]);
  } catch (err) {
    await d.delete(branches).where(eq(branches.id, branch.id));
    throw err;
  }

  return { branch, password };
}
