// Adapted from thunder-authentication's App.example.tsx pattern. The routing
// STRUCTURE is prescribed there and kept verbatim: NoAccess sits ABOVE the
// shell route and replaces it; Forbidden sits INSIDE the shell; every gated
// route is wrapped in <RequireOperation>, fed from src/authz/screens.ts;
// /callback is routed outside the provider. This project's wireframes.dsl
// declares no public (role-less) screen, so there is no PUBLIC_SCREENS block
// here — every screen in both flows carries `role "Member"`.
//
// BrowserRouter itself lives in main.tsx, alongside OxygenUIThemeProvider
// (oxygen-ui-design-system's Setup) — this file owns only the route table.

import { useEffect, type ReactElement } from "react";
import { Navigate, Route, Routes, useNavigate } from "react-router-dom";
import {
  AuthzProvider,
  Forbidden,
  NoAccess,
  RequireOperation,
  useAuthz,
  useScopes,
} from "./authz/gates";
import { reachableScreens, hasScopedReach, SCREEN_ROUTES } from "./authz/screens";
import { setForbiddenNavigator } from "./authz/client";
import { signIn } from "./authz/session";
import { APP_NAME } from "./appName";
import { AppShell } from "./shell/AppShell";
import { CallbackPage } from "./pages/Callback";
import { RoomListPage } from "./pages/RoomList";
import { RoomSearchPage } from "./pages/RoomSearch";
import { BookRoomPage } from "./pages/BookRoom";
import { MyBookingsPage } from "./pages/MyBookings";

const PAGE_BY_KEY: Record<string, ReactElement> = {
  roomlist: <RoomListPage />,
  roomsearch: <RoomSearchPage />,
  bookroom: <BookRoomPage />,
  mybookings: <MyBookingsPage />,
};

export function App(): ReactElement {
  return (
    <>
      <ForbiddenWiring />
      <Routes>
        <Route path="/callback" element={<CallbackPage />} />
        <Route
          path="*"
          element={
            <AuthzProvider fallback={<Splash />}>
              <SignedIn />
            </AuthzProvider>
          }
        />
      </Routes>
    </>
  );
}

/** Hands src/authz/client.ts the route a refusal goes to — wired once. */
function ForbiddenWiring(): null {
  const navigate = useNavigate();
  useEffect(() => {
    setForbiddenNavigator(() => navigate("/forbidden", { replace: true }));
  }, [navigate]);
  return null;
}

function Splash(): ReactElement {
  return (
    <main>
      <p>Checking your session…</p>
    </main>
  );
}

function SignedIn(): ReactElement {
  const { signedIn } = useAuthz();
  const scopes = useScopes();

  // Load-time guard: only a MISSING session starts a sign-in redirect.
  // currentUser() already tried a silent renew for an expired one, so signing
  // in here on every visit would turn that renew into a full-screen redirect.
  useEffect(() => {
    if (!signedIn) void signIn();
  }, [signedIn]);

  if (!signedIn) return <Splash />;

  const reachable = reachableScreens(scopes, signedIn);

  if (!hasScopedReach(scopes, signedIn)) return <NoAccess appName={APP_NAME} />;

  const landing = (reachable.find((s) => !s.public && s.loads !== null) ?? reachable[0]).path;

  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route index element={<Navigate to={landing} replace />} />
        {SCREEN_ROUTES.map((screen) => {
          const page = PAGE_BY_KEY[screen.key];
          if (screen.loads === null) {
            return <Route key={screen.key} path={screen.path} element={page} />;
          }
          return (
            <Route
              key={screen.key}
              element={<RequireOperation op={screen.loads} screen={screen.label} />}
            >
              <Route path={screen.path} element={page} />
            </Route>
          );
        })}
        <Route path="/forbidden" element={<Forbidden />} />
        <Route path="*" element={<Navigate to={landing} replace />} />
      </Route>
    </Routes>
  );
}
