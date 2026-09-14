// bindings + per-request context shared across routes.
export type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
};

export type AuthUser = {
  id: number;
  username: string;
  role: "admin" | "presenter";
};

export type Env = {
  Bindings: Bindings;
  Variables: {
    user: AuthUser;
  };
};
