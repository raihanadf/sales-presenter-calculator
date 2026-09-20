// bindings + per-request context shared across routes.
export type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  MIN_APP_VERSION: string;
};

export type Role = "superadmin" | "admin" | "presenter";

// branchId is null only for superadmin. always read from the db, never from
// the token, so moving a presenter takes effect on the next request.
export type AuthUser = {
  id: number;
  username: string;
  role: Role;
  branchId: number | null;
  branchActive: boolean;
};

export type Env = {
  Bindings: Bindings;
  Variables: {
    user: AuthUser;
  };
};
