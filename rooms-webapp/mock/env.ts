// mockEnv carries exactly the keys the platform actually emits for this
// component: the four USER_AUTH_* OIDC keys src/env.ts declares. There is no
// browser key for rooms-api — it is a sibling reached same-origin at /api,
// never window._env_ (react-webapp). The OIDC scopes are `group` and `ou`,
// singular, plus this project's catalog handles — exactly as the platform
// requests them and exactly as security.json declares them.
export const mockEnv = {
  USER_AUTH_CLIENT_ID: "mock-client",
  USER_AUTH_ISSUER: "https://mock-idp.test",
  USER_AUTH_SCOPES:
    "openid profile email group ou rooms:read bookings:read bookings:create bookings:cancel",
  USER_AUTH_RESOURCE: "https://mock-idp.test/resources/mock-project",
};
