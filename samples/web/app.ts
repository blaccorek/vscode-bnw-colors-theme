/**
 * Sample TypeScript file exercising most syntax token types.
 */
import { readFile } from "node:fs/promises";
import type { Server } from "node:http";

export const VERSION = "1.4.2" as const;
const MAX_RETRIES = 3;
const TIMEOUT_MS = 5_000;
const EMAIL_RE = /^[\w.+-]+@([\w-]+\.)+[a-z]{2,}$/i;

export enum Status {
  Idle = "idle",
  Running = "running",
  Failed = "failed",
}

export interface User {
  readonly id: number;
  name: string;
  email?: string;
  roles: Array<"admin" | "editor" | "viewer">;
}

type Result<T, E = Error> = { ok: true; value: T } | { ok: false; error: E };

export abstract class Repository<T extends { id: number }> {
  protected readonly items = new Map<number, T>();

  constructor(private readonly namespace: string) {}

  abstract validate(item: T): boolean;

  get size(): number {
    return this.items.size;
  }

  async save(item: T): Promise<Result<T>> {
    if (!this.validate(item)) {
      return { ok: false, error: new TypeError(`invalid item in ${this.namespace}`) };
    }
    this.items.set(item.id, item);
    return { ok: true, value: item };
  }
}

export class UserRepository extends Repository<User> {
  static #instances = 0;

  constructor() {
    super("users");
    UserRepository.#instances++;
  }

  validate(user: User): boolean {
    return user.name.length > 0 && (user.email === undefined || EMAIL_RE.test(user.email));
  }
}

function assertNever(value: never): never {
  throw new Error(`Unexpected value: ${String(value)}`);
}

export function describe(status: Status): string {
  switch (status) {
    case Status.Idle:
      return "waiting for work";
    case Status.Running:
      return "processing…";
    case Status.Failed:
      return "needs attention";
    default:
      return assertNever(status);
  }
}

export async function* paginate<T>(pages: T[][], delay = 0): AsyncGenerator<T, void, unknown> {
  for (const page of pages) {
    if (delay > 0) await new Promise((resolve) => setTimeout(resolve, delay));
    yield* page;
  }
}

export const withRetry = async <T>(fn: () => Promise<T>, retries = MAX_RETRIES): Promise<T> => {
  let lastError: unknown;
  for (let attempt = 1; attempt <= retries; attempt += 1) {
    try {
      return await fn();
    } catch (error: unknown) {
      lastError = error;
      console.warn(`attempt ${attempt}/${retries} failed`, { error });
    } finally {
      // always runs
    }
  }
  throw lastError instanceof Error ? lastError : new Error("unknown failure");
};

declare module "custom-logger" {
  export function log(level: "info" | "warn", message: string): void;
}

export default UserRepository;
