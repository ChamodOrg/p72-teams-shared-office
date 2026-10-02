// Typed read of window._env_, mounted by the platform at request time as
// /env-config.js. Never import.meta.env / process.env — those are build-time
// mechanisms the platform does not use and arrive undefined in production.
//
// Only the browser-visible keys this app actually has: the four USER_AUTH_*
// outputs its auth dependency emits (not JWKS_URL — the browser never
// validates a token, the API gateway does, so no asset reads it). There is no
// browser key for rooms-api: it is a sibling component reached same-origin at
// /api, never window._env_ (react-webapp).

type Env = {
  USER_AUTH_CLIENT_ID: string;
  USER_AUTH_ISSUER: string;
  USER_AUTH_SCOPES: string;
  USER_AUTH_RESOURCE: string;
};

declare global {
  interface Window {
    _env_: Env;
  }
}

if (!window._env_) {
  throw new Error(
    "window._env_ not set — /env-config.js failed to load. " +
      "The platform mounts this file; if you see this locally, host " +
      "/env-config.js from your dev server.",
  );
}

export const env: Env = window._env_;
