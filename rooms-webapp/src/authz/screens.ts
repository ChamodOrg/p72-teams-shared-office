// Adapted from thunder-authentication's screens.example.ts pattern — see that
// file's comments for why `loads` (never a handle typed into JSX) is the one
// fact each screen carries. THIS app's screens, in the order
// specs/design/components/rooms-webapp/wireframes.dsl draws them:
// RoomList, RoomSearch, BookRoom, MyBookings.
//
// Every screen here sits in a flow with a `role` line ("Member"), so none are
// `public` — every one is routed behind the sign-in guard. This project's
// security.json has exactly one role, so in practice every Member reaches
// every screen; the gating machinery is still wired exactly as it would be
// with a second role.

import { canCall } from "./core";
import { OPERATIONS, isOperationKey, type OperationKey } from "./operations.gen";

export interface ScreenRoute {
  readonly key: string;
  readonly label: string;
  readonly path: string;
  readonly loads: OperationKey | null;
  readonly public?: boolean;
}

export const SCREEN_ROUTES: readonly ScreenRoute[] = [
  { key: "roomlist", label: "Rooms", path: "/rooms", loads: "GET /rooms" },
  { key: "roomsearch", label: "Search Rooms", path: "/rooms/search", loads: "GET /rooms" },
  // BookRoom only writes — its one operation is the booking it submits.
  { key: "bookroom", label: "Book a Room", path: "/book", loads: "POST /me/bookings" },
  { key: "mybookings", label: "My Bookings", path: "/bookings", loads: "GET /me/bookings" },
];

for (const screen of SCREEN_ROUTES) {
  if (screen.loads !== null && !isOperationKey(screen.loads)) {
    throw new Error(
      `src/authz/screens.ts: screen "${screen.label}" loads "${screen.loads}", which ` +
        `no contract declares. Re-run \`npm run gen\`, or name the operation the ` +
        `way openapi.yaml spells it.`,
    );
  }
}

export function reachableScreens(
  scopes: ReadonlySet<string>,
  signedIn: boolean,
): readonly ScreenRoute[] {
  return SCREEN_ROUTES.filter((screen) => {
    if (screen.public) return true;
    if (screen.loads === null) return signedIn;
    return canCall(OPERATIONS[screen.loads], scopes, signedIn);
  });
}

export function hasScopedReach(scopes: ReadonlySet<string>, signedIn: boolean): boolean {
  return reachableScreens(scopes, signedIn).some((screen) => !screen.public && screen.loads !== null);
}
