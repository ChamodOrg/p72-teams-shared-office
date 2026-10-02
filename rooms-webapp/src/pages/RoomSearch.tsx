import { useState, type FormEvent, type ReactElement } from "react";
import { useNavigate } from "react-router-dom";
import {
  Alert,
  Box,
  Button,
  Divider,
  Form,
  ListingTable,
  PageTitle,
  Stack,
  TextField,
  Typography,
} from "@wso2/oxygen-ui";
import { roomsApi } from "../api";
import type { components } from "../generated/rooms-api";

type Room = components["schemas"]["Room"];

interface Criteria {
  date: string;
  startTime: string;
  endTime: string;
  attendees: string;
}

const EMPTY: Criteria = { date: "", startTime: "", endTime: "", attendees: "" };

/**
 * RoomSearch — "Find a room free for a time range and group size." Loads
 * GET /rooms, filtered by the search form's date, time range and group size.
 * Each result row leads to BookRoom.
 */
export function RoomSearchPage(): ReactElement {
  const navigate = useNavigate();
  const [criteria, setCriteria] = useState<Criteria>(EMPTY);
  const [rooms, setRooms] = useState<Room[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [searching, setSearching] = useState(false);
  const [searched, setSearched] = useState(false);

  async function onSearch(event: FormEvent): Promise<void> {
    event.preventDefault();
    setSearching(true);
    setError(null);
    try {
      const { data, error: apiError } = await roomsApi.GET("/rooms", {
        params: {
          query: {
            date: criteria.date || undefined,
            startTime: criteria.startTime || undefined,
            endTime: criteria.endTime || undefined,
            minCapacity: criteria.attendees ? Number(criteria.attendees) : undefined,
            limit: 50,
          },
        },
      });
      setSearched(true);
      if (apiError) {
        setError(apiError.message);
        setRooms([]);
        return;
      }
      setRooms(data?.data ?? []);
    } catch {
      setSearched(true);
      setError("Could not search rooms.");
      setRooms([]);
    } finally {
      setSearching(false);
    }
  }

  function bookRoom(room: Room): void {
    const params = new URLSearchParams({
      roomId: room.id,
      roomName: room.name,
      capacity: String(room.capacity),
      location: room.location,
      date: criteria.date,
      startTime: criteria.startTime,
      endTime: criteria.endTime,
      attendees: criteria.attendees,
    });
    navigate(`/book?${params.toString()}`);
  }

  return (
    <Box>
      <PageTitle>
        <PageTitle.Header>Search Rooms</PageTitle.Header>
      </PageTitle>

      <Form.Section>
        <Box component="form" onSubmit={(e) => void onSearch(e)}>
          <Form.Stack direction="row" spacing={2} sx={{ flexWrap: "wrap" }}>
            <TextField
              label="Date"
              type="date"
              value={criteria.date}
              onChange={(e) => setCriteria((c) => ({ ...c, date: e.target.value }))}
              slotProps={{ inputLabel: { shrink: true } }}
              sx={{ minWidth: 180 }}
            />
            <TextField
              label="Start time"
              type="time"
              value={criteria.startTime}
              onChange={(e) => setCriteria((c) => ({ ...c, startTime: e.target.value }))}
              slotProps={{ inputLabel: { shrink: true } }}
              sx={{ minWidth: 160 }}
            />
            <TextField
              label="End time"
              type="time"
              value={criteria.endTime}
              onChange={(e) => setCriteria((c) => ({ ...c, endTime: e.target.value }))}
              slotProps={{ inputLabel: { shrink: true } }}
              sx={{ minWidth: 160 }}
            />
            <TextField
              label="Attendees"
              type="number"
              value={criteria.attendees}
              onChange={(e) => setCriteria((c) => ({ ...c, attendees: e.target.value }))}
              slotProps={{ htmlInput: { min: 1 } }}
              sx={{ minWidth: 140 }}
            />
          </Form.Stack>
          <Stack direction="row" sx={{ mt: 2 }}>
            <Button type="submit" variant="contained" disabled={searching}>
              {searching ? "Searching…" : "Search"}
            </Button>
          </Stack>
        </Box>
      </Form.Section>

      <Divider sx={{ my: 3 }} />

      {error ? (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      ) : null}

      {!searched ? (
        <Typography variant="body2" color="text.secondary">
          Search for a date, time range and group size to see which rooms are free.
        </Typography>
      ) : (
        <ListingTable.Container>
          <ListingTable>
            <ListingTable.Head>
              <ListingTable.Row>
                <ListingTable.Cell>Room</ListingTable.Cell>
                <ListingTable.Cell>Capacity</ListingTable.Cell>
                <ListingTable.Cell>Location</ListingTable.Cell>
              </ListingTable.Row>
            </ListingTable.Head>
            <ListingTable.Body>
              {rooms && rooms.length === 0 ? (
                <ListingTable.Row>
                  <ListingTable.Cell colSpan={3}>
                    <ListingTable.EmptyState
                      title="No rooms free"
                      description="No room fits that time range and group size. Try widening the search."
                    />
                  </ListingTable.Cell>
                </ListingTable.Row>
              ) : (
                (rooms ?? []).map((room) => (
                  <ListingTable.Row
                    key={room.id}
                    clickable
                    onClick={() => bookRoom(room)}
                  >
                    <ListingTable.Cell>{room.name}</ListingTable.Cell>
                    <ListingTable.Cell>{room.capacity}</ListingTable.Cell>
                    <ListingTable.Cell>{room.location}</ListingTable.Cell>
                  </ListingTable.Row>
                ))
              )}
            </ListingTable.Body>
          </ListingTable>
        </ListingTable.Container>
      )}
    </Box>
  );
}
