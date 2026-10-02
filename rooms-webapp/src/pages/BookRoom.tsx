import { useState, type FormEvent, type ReactElement } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Form,
  PageTitle,
  Stack,
  TextField,
  Typography,
} from "@wso2/oxygen-ui";
import { roomsApi } from "../api";

/**
 * BookRoom — "Book a free room for a time range." The selected room rides in
 * the query string from RoomSearch's row click (roomId, roomName, capacity,
 * location) along with the criteria the search was made with, prefilling this
 * form. A visitor who lands here with no roomId (a bare /book) has nothing to
 * book and is sent back to search.
 */
export function BookRoomPage(): ReactElement {
  const navigate = useNavigate();
  const [params] = useSearchParams();

  const roomId = params.get("roomId") ?? "";
  const roomName = params.get("roomName") ?? "";
  const capacity = params.get("capacity") ?? "";
  const location = params.get("location") ?? "";

  const [date, setDate] = useState(params.get("date") ?? "");
  const [startTime, setStartTime] = useState(params.get("startTime") ?? "");
  const [endTime, setEndTime] = useState(params.get("endTime") ?? "");
  const [attendees, setAttendees] = useState(params.get("attendees") ?? "");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  if (!roomId) {
    return (
      <Box>
        <PageTitle>
          <PageTitle.Header>Book a Room</PageTitle.Header>
        </PageTitle>
        <Alert severity="info" sx={{ mb: 2 }}>
          No room selected. Search for a free room first.
        </Alert>
        <Button variant="contained" onClick={() => navigate("/rooms/search")}>
          Back to search
        </Button>
      </Box>
    );
  }

  async function onConfirm(event: FormEvent): Promise<void> {
    event.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      const { data, error: apiError } = await roomsApi.POST("/me/bookings", {
        body: {
          roomId,
          date,
          startTime,
          endTime,
          attendeeCount: Number(attendees),
        },
      });
      if (apiError) {
        // The reason rooms-api returned — clash, oversized group, or a past
        // start time — surfaced verbatim. Nothing is reserved on a refusal,
        // and My Bookings is never touched from here.
        setError(apiError.description || apiError.message);
        return;
      }
      if (data) {
        // Booking succeeded — My Bookings re-fetches on mount, so the new
        // booking appears immediately, with no page reload.
        navigate("/bookings");
      }
    } catch {
      setError("Could not reach rooms-api. The booking was not made.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Box>
      <PageTitle>
        <PageTitle.Header>Book {roomName || "Room"}</PageTitle.Header>
      </PageTitle>

      <Card sx={{ mb: 3, maxWidth: 360 }}>
        <CardContent>
          <Typography variant="h6">{roomName}</Typography>
          <Typography variant="body2" color="text.secondary">
            Capacity: {capacity} | {location}
          </Typography>
        </CardContent>
      </Card>

      {error ? (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      ) : null}

      <Form.Section>
        <Box component="form" onSubmit={(e) => void onConfirm(e)}>
          <Form.Stack direction="row" spacing={2} sx={{ flexWrap: "wrap" }}>
            <TextField
              label="Date"
              type="date"
              required
              value={date}
              onChange={(e) => setDate(e.target.value)}
              slotProps={{ inputLabel: { shrink: true } }}
              sx={{ minWidth: 180 }}
            />
            <TextField
              label="Start time"
              type="time"
              required
              value={startTime}
              onChange={(e) => setStartTime(e.target.value)}
              slotProps={{ inputLabel: { shrink: true } }}
              sx={{ minWidth: 160 }}
            />
            <TextField
              label="End time"
              type="time"
              required
              value={endTime}
              onChange={(e) => setEndTime(e.target.value)}
              slotProps={{ inputLabel: { shrink: true } }}
              sx={{ minWidth: 160 }}
            />
            <TextField
              label="Attendees"
              type="number"
              required
              value={attendees}
              onChange={(e) => setAttendees(e.target.value)}
              slotProps={{ htmlInput: { min: 1 } }}
              sx={{ minWidth: 140 }}
            />
          </Form.Stack>

          <Stack direction="row" justifyContent="flex-end" spacing={2} sx={{ mt: 3 }}>
            <Button variant="outlined" onClick={() => navigate("/rooms/search")}>
              Cancel
            </Button>
            <Button type="submit" variant="contained" disabled={submitting}>
              {submitting ? "Booking…" : "Confirm booking"}
            </Button>
          </Stack>
        </Box>
      </Form.Section>

      <Typography variant="body2" color="text.secondary" sx={{ mt: 3 }}>
        A clash with an existing booking, or too many attendees for the room, is
        refused here with the reason.
      </Typography>
    </Box>
  );
}
