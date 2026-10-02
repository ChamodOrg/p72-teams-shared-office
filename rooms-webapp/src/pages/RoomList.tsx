import { useEffect, useState, type ReactElement } from "react";
import { useNavigate } from "react-router-dom";
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  ListingTable,
  PageTitle,
  Stack,
} from "@wso2/oxygen-ui";
import { Search } from "@wso2/oxygen-ui-icons-react";
import { roomsApi } from "../api";
import type { components } from "../generated/rooms-api";

type Room = components["schemas"]["Room"];

const PAGE_SIZE = 50;

/**
 * RoomList — "Every meeting room, with its capacity and location."
 * Loads GET /rooms with no filter: every room in the office.
 */
export function RoomListPage(): ReactElement {
  const navigate = useNavigate();
  const [rooms, setRooms] = useState<Room[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [next, setNext] = useState<string | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);

  useEffect(() => {
    let live = true;
    setRooms(null);
    setError(null);
    roomsApi
      .GET("/rooms", { params: { query: { limit: PAGE_SIZE, offset: 0 } } })
      .then(({ data, error: apiError }) => {
        if (!live) return;
        if (apiError) {
          setError(apiError.message);
          setRooms([]);
          return;
        }
        setRooms(data?.data ?? []);
        setNext(data?.next ?? null);
      })
      .catch(() => {
        if (live) {
          setError("Could not load the room list.");
          setRooms([]);
        }
      });
    return () => {
      live = false;
    };
  }, []);

  async function loadMore(): Promise<void> {
    if (!next || loadingMore) return;
    setLoadingMore(true);
    try {
      const offset = (rooms?.length ?? 0);
      const { data, error: apiError } = await roomsApi.GET("/rooms", {
        params: { query: { limit: PAGE_SIZE, offset } },
      });
      if (apiError) {
        setError(apiError.message);
        return;
      }
      setRooms((prev) => [...(prev ?? []), ...(data?.data ?? [])]);
      setNext(data?.next ?? null);
    } finally {
      setLoadingMore(false);
    }
  }

  return (
    <Box>
      <PageTitle>
        <PageTitle.Header>Meeting Rooms</PageTitle.Header>
        <PageTitle.Actions>
          <Button variant="contained" startIcon={<Search size={18} />} onClick={() => navigate("/rooms/search")}>
            Search available...
          </Button>
        </PageTitle.Actions>
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
              <ListingTable.Cell>Capacity</ListingTable.Cell>
              <ListingTable.Cell>Location</ListingTable.Cell>
            </ListingTable.Row>
          </ListingTable.Head>
          <ListingTable.Body>
            {rooms === null ? (
              <ListingTable.Row>
                <ListingTable.Cell colSpan={3}>
                  <Stack direction="row" justifyContent="center" sx={{ py: 4 }}>
                    <CircularProgress size={24} />
                  </Stack>
                </ListingTable.Cell>
              </ListingTable.Row>
            ) : rooms.length === 0 ? (
              <ListingTable.Row>
                <ListingTable.Cell colSpan={3}>
                  <ListingTable.EmptyState
                    title="No rooms yet"
                    description="The office has no meeting rooms in its catalog."
                  />
                </ListingTable.Cell>
              </ListingTable.Row>
            ) : (
              rooms.map((room) => (
                <ListingTable.Row key={room.id}>
                  <ListingTable.Cell>{room.name}</ListingTable.Cell>
                  <ListingTable.Cell>{room.capacity}</ListingTable.Cell>
                  <ListingTable.Cell>{room.location}</ListingTable.Cell>
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
    </Box>
  );
}
