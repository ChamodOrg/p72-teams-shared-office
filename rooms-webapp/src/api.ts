// The rooms-api client: openapi-fetch, typed against the generated client,
// reaching the sibling same-origin at /api (nginx proxies it to the gateway —
// react-webapp). Authorization is NOT this module's concern: every call goes
// through authz/client.ts's two functions, exactly as thunder-authentication
// prescribes. No bearer handling and no 401 handling of its own.

import createClient, { type Middleware } from "openapi-fetch";
import type { paths } from "./generated/rooms-api";
import { authorizationHeader, classifyResponse, ForbiddenError } from "./authz/client";

const authMiddleware: Middleware = {
  async onRequest({ request }) {
    const header = await authorizationHeader();
    if (header) request.headers.set("Authorization", header);
    return request;
  },
  async onResponse({ response }) {
    if ((await classifyResponse(response.status)) === "forbidden") {
      throw new ForbiddenError(response.status);
    }
    return response;
  },
};

export const roomsApi = createClient<paths>({ baseUrl: "/api" });
roomsApi.use(authMiddleware);
