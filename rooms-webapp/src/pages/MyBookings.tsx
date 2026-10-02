import { useEffect, useState, type ReactElement } from "react";
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  ListingTable,
  PageTitle,
  Stack,
  Typography,
} from "@wso2/oxygen-ui";
import { roomsApi } from "../api";
import { Can } from "../authz/gates";
import type { components } from "../generated/rooms-api";

type Booking = components["schemas"]["Booking"];

const PAGE_SIZE = 50;

/**
 * MyBookings — "The signed-in member's own upcoming bookings." Loads
 * GET /me/bookings — the caller's rows and nothing else. Cancelling (DELETE
 * /me/bookings/{bookingId}) removes the row from this list immediately, with
 * no reload.
 */
export function MyBookingsPage(): ReactElement {
  const [bookings, setBookings] = useState<Booking[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [next, setNext] = useState<string | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [pendingCancel, setPendingCancel] = useState<Booking | null>(null);
  const [cancelling, setCancelling] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);

  useEffect(() => {
    load();
  }, []);

  function load(): void {
    setBookings(null);
    setError(null);
    roomsApi
      .GET("/me/bookings", { params: { query: { limit: PAGE_SIZE, offset: 0 } } })
      .then(({ data, error: apiError }) => {
        if (apiError) {
          setError(apiError.message);
          setBookings([]);
          return;
        }
        setBookings(data?.data ?? []);
        setNext(data?.next ?? null);
      })
      .catch(() => {
        setError("Could not load your bookings.");
        setBookings([]);
      });
  }

  async function loadMore(): Promise<void> {
    if (!next || loadingMore) return;
    setLoadingMore(true);
    try {
      const offset = bookings?.length ?? 0;
      const { data, error: apiError } = await roomsApi.GET("/me/bookings", {
        params: { query: { limit: PAGE_SIZE, offset } },
      });
      if (apiError) {
        setError(apiError.message);
        return;
      }
      setBookings((prev) => [...(prev ?? []), ...(data?.data ?? [])]);
      setNext(data?.next ?? null);
    } finally {
      setLoadingMore(false);
    }
  }

  async function confirmCancel(): Promise<void> {
    if (!pendingCancel) return;
    setCancelling(true);
    setCancelError(null);
    try {
      const { response } = await roomsApi.DELETE("/me/bookings/{bookingId}", {
        params: { path: { bookingId: pendingCancel.id } },
      });
      if (response.status === 404) {
        setCancelError("That booking is not yours to cancel, or it is already gone.");
        return;
      }
      if (!response.ok) {
        setCancelError("Could not cancel that booking.");
        return;
      }
      // Remove immediately — no reload, no re-fetch needed.
      setBookings((prev) => (prev ?? []).filter((b) => b.id !== pendingCancel.id));
      setPendingCancel(null);
    } catch {
      setCancelError("Could not reach rooms-api. The booking was not cancelled.");
    } finally {
      setCancelling(false);
    }
  }

  return (
    <Box>
      <PageTitle>
        <PageTitle.Header>My Bookings</PageTitle.Header>
      </PageTitle>

      {error ? (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      ) : null}

      <ListingTable.Container>
        <ListingTable>
          <ListingTable.Head>
            <ListingTable.Row>
              <ListingTable.Cell>Room</ListingTable.Cell>
              <ListingTable.Cell>Date</ListingTable.Cell>
              <ListingTable.Cell>Time</ListingTable.Cell>
              <ListingTable.Cell>Attendees</ListingTable.Cell>
              <ListingTable.Cell />
            </ListingTable.Row>
          </ListingTable.Head>
          <ListingTable.Body>
            {bookings === null ? (
              <ListingTable.Row>
                <ListingTable.Cell colSpan={5}>
                  <Stack direction="row" justifyContent="center" sx={{ py: 4 }}>
                    <CircularProgress size={24} />
                  </Stack>
                </ListingTable.Cell>
              </ListingTable.Row>
            ) : bookings.length === 0 ? (
              <ListingTable.Row>
                <ListingTable.Cell colSpan={5}>
                  <ListingTable.EmptyState
                    title="No upcoming bookings"
                    description="Book a room from Rooms or Search Rooms to see it here."
                  />
                </ListingTable.Cell>
              </ListingTable.Row>
            ) : (
              bookings.map((booking) => (
                <ListingTable.Row key={booking.id}>
                  <ListingTable.Cell>{booking.roomName}</ListingTable.Cell>
                  <ListingTable.Cell>{booking.date}</ListingTable.Cell>
                  <ListingTable.Cell>
                    {booking.startTime}-{booking.endTime}
                  </ListingTable.Cell>
                  <ListingTable.Cell>{booking.attendeeCount}</ListingTable.Cell>
                  <ListingTable.Cell>
                    <ListingTable.RowActions>
                      {/* Cancelling calls a DIFFERENT operation (bookings:cancel)
                          than the one this screen loads (bookings:read), so it
                          gets its own gate rather than riding the route guard's. */}
                      <Can op="DELETE /me/bookings/{bookingId}">
                        <Button
                          size="small"
                          variant="outlined"
                          color="error"
                          onClick={() => {
                            setCancelError(null);
                            setPendingCancel(booking);
                          }}
                        >
                          Cancel
                        </Button>
                      </Can>
                    </ListingTable.RowActions>
                  </ListingTable.Cell>
                </ListingTable.Row>
              ))
            )}
          </ListingTable.Body>
        </ListingTable>
      </ListingTable.Container>

      {next ? (
        <Stack direction="row" justifyContent="center" sx={{ mt: 2 }}>
          <Button variant="outlined" onClick={() => void loadMore()} disabled={loadingMore}>
            {loadingMore ? "Loading…" : "Load more"}
          </Button>
        </Stack>
      ) : null}

      <Typography variant="body2" color="text.secondary" sx={{ mt: 3 }}>
        Cancel a booking from this list to release the room immediately.
      </Typography>

      <Dialog open={pendingCancel !== null} onClose={() => setPendingCancel(null)}>
        <DialogTitle>Cancel this booking?</DialogTitle>
        <DialogContent>
          <DialogContentText>
            {pendingCancel
              ? `${pendingCancel.roomName} on ${pendingCancel.date} from ${pendingCancel.startTime} to ${pendingCancel.endTime} will be released immediately.`
              : null}
          </DialogContentText>
          {cancelError ? (
            <Alert severity="error" sx={{ mt: 2 }}>
              {cancelError}
            </Alert>
          ) : null}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPendingCancel(null)} disabled={cancelling}>
            Keep booking
          </Button>
          <Button
            variant="contained"
            color="error"
            onClick={() => void confirmCancel()}
            disabled={cancelling}
          >
            {cancelling ? "Cancelling…" : "Cancel booking"}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
