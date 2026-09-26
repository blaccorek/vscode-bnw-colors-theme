"use strict";

// Sample JavaScript: modules, classes, async, destructuring, regex.
const DEFAULTS = Object.freeze({
  baseUrl: "https://api.example.com/v1",
  retries: 2,
  headers: { "Content-Type": "application/json" },
});

const SLUG_RE = /[^a-z0-9]+/g;

export const slugify = (value) =>
  String(value)
    .toLowerCase()
    .trim()
    .replace(SLUG_RE, "-")
    .replace(/^-|-$/g, "");

export class HttpError extends Error {
  constructor(status, body) {
    super(`HTTP ${status}`);
    this.name = "HttpError";
    this.status = status;
    this.body = body;
  }

  get retryable() {
    return this.status >= 500 || this.status === 429;
  }
}

export default class ApiClient {
  #token = null;

  constructor({ baseUrl, retries, headers } = DEFAULTS) {
    this.baseUrl = baseUrl ?? DEFAULTS.baseUrl;
    this.retries = retries ?? DEFAULTS.retries;
    this.headers = { ...DEFAULTS.headers, ...headers };
  }

  set token(value) {
    this.#token = value;
  }

  async request(path, { method = "GET", body, ...rest } = {}) {
    const url = new URL(path, this.baseUrl);
    const headers = this.#token
      ? { ...this.headers, Authorization: `Bearer ${this.#token}` }
      : this.headers;

    const response = await fetch(url, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
      ...rest,
    });

    if (!response.ok) {
      throw new HttpError(response.status, await response.text());
    }
    return response.json();
  }

  *chunks(items, size = 10) {
    for (let i = 0; i < items.length; i += size) {
      yield items.slice(i, i + size);
    }
  }
}

const numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const [first, second, ...tail] = numbers;
const total = numbers.reduce((sum, n) => sum + n, 0);
const evens = numbers.filter((n) => n % 2 === 0);

console.table({ first, second, tail: tail.length, total, evens });
console.log(`slug: ${slugify("  Hello, World! 42 ")}`, typeof globalThis, 0b1010, 0o17, 0xff, 1e3, 9007199254740993n);
