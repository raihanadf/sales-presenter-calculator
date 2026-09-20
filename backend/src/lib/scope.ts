import { HTTPException } from "hono/http-exception";
import type { AuthUser } from "../types";

// which branch a request is allowed to touch. superadmin may pass ?branchId to
// drill into one branch, or omit it to span every branch (null). everyone else
// is pinned to their own branch and asking for another one is a 403.
export function resolveBranchScope(user: AuthUser, requested?: number): number | null {
  if (user.role === "superadmin") return requested ?? null;
  if (user.branchId === null) {
    throw new HTTPException(403, { message: "account has no branch" });
  }
  if (requested !== undefined && requested !== user.branchId) {
    throw new HTTPException(403, { message: "branch lain tidak bisa diakses" });
  }
  return user.branchId;
}
