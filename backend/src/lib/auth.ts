import { sign, verify } from "hono/jwt";
import type { AuthUser } from "../types";

// password hashing with pbkdf2 via web crypto (no native bcrypt on workers).
// stored format: pbkdf2$<iterations>$<saltB64>$<hashB64>
const ITERATIONS = 100_000;

async function pbkdf2(password: string, salt: Uint8Array): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations: ITERATIONS, hash: "SHA-256" },
    key,
    256,
  );
  return new Uint8Array(bits);
}

function b64(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes));
}

function unb64(s: string): Uint8Array {
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
}

export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await pbkdf2(password, salt);
  return `pbkdf2$${ITERATIONS}$${b64(salt)}$${b64(hash)}`;
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [scheme, , saltB64, hashB64] = stored.split("$");
  if (scheme !== "pbkdf2") return false;
  const computed = await pbkdf2(password, unb64(saltB64));
  const expected = unb64(hashB64);
  if (computed.length !== expected.length) return false;
  // constant-time compare
  let diff = 0;
  for (let i = 0; i < computed.length; i++) diff |= computed[i] ^ expected[i];
  return diff === 0;
}

export async function issueToken(user: AuthUser, secret: string): Promise<string> {
  const payload = {
    sub: user.id,
    username: user.username,
    role: user.role,
    exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30, // 30 days
  };
  return sign(payload, secret, "HS256");
}

export async function readToken(token: string, secret: string): Promise<AuthUser> {
  const payload = await verify(token, secret, "HS256");
  return {
    id: payload.sub as number,
    username: payload.username as string,
    role: payload.role as "admin" | "presenter",
  };
}
