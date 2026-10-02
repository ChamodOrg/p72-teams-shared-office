import type { ReactElement } from "react";
import { Link as RouterLink, Outlet, useLocation } from "react-router-dom";
import {
  AppShell as OxygenAppShell,
  ColorSchemeToggle,
  Footer,
  Header,
  Sidebar,
  UserMenu,
  version as OXYGEN_UI_VERSION,
} from "@wso2/oxygen-ui";
import { Building2, CalendarCheck, LogOut } from "@wso2/oxygen-ui-icons-react";
import { APP_NAME } from "../appName";
import { Can, useAuthz } from "../authz/gates";
import { signOut } from "../authz/session";

/**
 * The app's ONE shell, per the sample's AppLayout. Every screen renders inside
 * it. The wireframes.dsl draws every screen's navbar as
 * "Rooms | Rooms -> RoomList | My Bookings -> MyBookings" — the first segment
 * is the brand, the rest are navigation. Oxygen's own mapping keeps navigation
 * in the sidebar even when a wireframe put the link text in the navbar.
 *
 * ONE rail, each item wrapped in <Can>, reproduces the picture for a Member
 * (today's only role) and also covers a caller holding more than one role.
 */
export function AppShell(): ReactElement {
  const { username } = useAuthz();
  const location = useLocation();
  const activeItem = location.pathname.startsWith("/bookings")
    ? "mybookings"
    : "roomlist";

  return (
    <OxygenAppShell>
      <OxygenAppShell.Navbar>
        <Header>
          <Header.Toggle />
          <Header.Brand>
            <Header.BrandTitle>{APP_NAME}</Header.BrandTitle>
          </Header.Brand>
          <Header.Spacer />
          <Header.Actions>
            <ColorSchemeToggle />
            <UserMenu>
              <UserMenu.Trigger name={username || "Member"} />
              <UserMenu.Header name={username || "Member"} email={username || ""} />
              <UserMenu.Divider />
              <UserMenu.Logout icon={<LogOut />} onClick={() => void signOut()} />
            </UserMenu>
          </Header.Actions>
        </Header>
      </OxygenAppShell.Navbar>

      <OxygenAppShell.Sidebar>
        <Sidebar activeItem={activeItem}>
          <Sidebar.Nav>
            <Sidebar.Category>
              <Can op="GET /rooms">
                <Sidebar.Item id="roomlist" link={<RouterLink to="/rooms" />}>
                  <Sidebar.ItemIcon>
                    <Building2 />
                  </Sidebar.ItemIcon>
                  <Sidebar.ItemLabel>Rooms</Sidebar.ItemLabel>
                </Sidebar.Item>
              </Can>
              <Can op="GET /me/bookings">
                <Sidebar.Item id="mybookings" link={<RouterLink to="/bookings" />}>
                  <Sidebar.ItemIcon>
                    <CalendarCheck />
                  </Sidebar.ItemIcon>
                  <Sidebar.ItemLabel>My Bookings</Sidebar.ItemLabel>
                </Sidebar.Item>
              </Can>
            </Sidebar.Category>
          </Sidebar.Nav>
        </Sidebar>
      </OxygenAppShell.Sidebar>

      <OxygenAppShell.Main>
        <Outlet />
      </OxygenAppShell.Main>

      <OxygenAppShell.Footer>
        <Footer>
          <Footer.Copyright>© {new Date().getFullYear()} WSO2 LLC.</Footer.Copyright>
          <Footer.Divider />
          <Footer.Version>oxygen-ui-v{OXYGEN_UI_VERSION}</Footer.Version>
        </Footer>
      </OxygenAppShell.Footer>
    </OxygenAppShell>
  );
}
