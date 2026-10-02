import { useEffect, type ReactElement } from "react";
import { useNavigate } from "react-router-dom";
import { Box, Typography } from "@wso2/oxygen-ui";
import { handleCallback } from "../authz/session";

/**
 * The one registered redirect URI, serving both the redirect leg and the
 * hidden-iframe silent-renew leg (thunder-authentication). `handleCallback()`
 * dispatches on `request_type` and settles with no value either way — this
 * page renders from the promise SETTLING, not from a value.
 */
export function CallbackPage(): ReactElement {
  const navigate = useNavigate();

  useEffect(() => {
    let live = true;
    void handleCallback().finally(() => {
      if (live) navigate("/", { replace: true });
    });
    return () => {
      live = false;
    };
  }, [navigate]);

  return (
    <Box sx={{ display: "flex", alignItems: "center", justifyContent: "center", height: "100vh" }}>
      <Typography variant="body1" color="text.secondary">
        Signing you in…
      </Typography>
    </Box>
  );
}
