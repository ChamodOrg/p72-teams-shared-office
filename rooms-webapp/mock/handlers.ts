// One handler per rooms-api operation, against the same contract
// src/generated/rooms-api.ts was generated from. State lives in this module's
// scope: a reload re-runs it and restores the seed (react-webapp's
// mock-mode.md) — only in-app navigation carries a change forward, which is
// exactly what proves "no page reload" for the booking/cancel flows.
//
// Seed data is the wireframes.dsl's own row data (wireframes' seed.mjs), so
// the mock walk sees the same rooms and bookings the rendered wireframe draws.
//
// Write NO scope check here: mock/authz/gateway.ts is this mock's gateway
// layer, reading the same contract a real API gateway would enforce against.
// A handler only owes what a real service owes — its path's reach.

import { http, HttpResponse } from "msw";
import type { components } from "../src/generated/rooms-api";

type Room = components["schemas"]["Room"];
type Booking = components["schemas"]["Booking"];
type NewBooking = components["schemas"]["NewBooking"];

// The caller this mock speaks for, shaped like the gateway assertion.
export const mockCaller = {
  userId: "01a0ab00-0000-7000-8000-000000000001",
  username: "test-member",
};

const OTHER_MEMBER = "01a0ab00-0000-7000-8000-000000000002";

const rooms: Room[] = [
  { id: "room-atlas", name: "Atlas", capacity: 4, location: "2nd floor" },
  { id: "room-summit", name: "Summit", capacity: 8, location: "2nd floor" },
  { id: "room-horizon", name: "Horizon", capacity: 12, location: "3rd floor" },
];

interface StoredBooking extends Booking {
  ownerId: string;
}

let bookings: StoredBooking[] = [
  {
    id: "booking-1",
    roomId: "room-summit",
    roomName: "Summit",
    date: "2026-10-05",
    startTime: "10:00",
    endTime: "11:00",
    attendeeCount: 6,
    createdAt: "2026-09-20T09:00:00Z",
    ownerId: mockCaller.userId,
  },
  {
    id: "booking-2",
    roomId: "room-horizon",
    roomName: "Horizon",
    date: "2026-10-06",
    startTime: "14:00",
    endTime: "15:00",
    attendeeCount: 10,
    createdAt: "2026-09-21T09:00:00Z",
    ownerId: mockCaller.userId,
  },
  // Somebody else's booking — proves /me/bookings is the caller's rows only,
  // and that a cancel attempt on it 404s rather than 403 (openapi-conventions).
  {
    id: "booking-3",
    roomId: "room-atlas",
    roomName: "Atlas",
    date: "2026-10-07",
    startTime: "09:00",
    endTime: "10:00",
    attendeeCount: 3,
    createdAt: "2026-09-22T09:00:00Z",
    ownerId: OTHER_MEMBER,
  },
];

let nextId = 4;

function overlaps(aStart: string, aEnd: string, bStart: string, bEnd: string): boolean {
  return aStart < bEnd && aEnd > bStart;
}

function paginate<T>(all: T[], limit: number, offset: number) {
  const data = all.slice(offset, offset + limit);
  const end = offset + data.length;
  return {
    count: all.length,
    data,
    next: end < all.length ? `?limit=${limit}&offset=${end}` : null,
    previous: offset > 0 ? `?limit=${limit}&offset=${Math.max(0, offset - limit)}` : null,
  };
}

export const handlers = [
  http.get("/api/rooms", ({ request }) => {
    const url = new URL(request.url);
    const date = url.searchParams.get("date");
    const startTime = url.searchParams.get("startTime");
    const endTime = url.searchParams.get("endTime");
    const minCapacity = url.searchParams.get("minCapacity");
    const limit = Number(url.searchParams.get("limit") ?? 20);
    const offset = Number(url.searchParams.get("offset") ?? 0);

    if ((startTime && !endTime) || (!startTime && endTime)) {
      return HttpResponse.json(
        { code: 400, message: "startTime and endTime must both be given" },
        { status: 400 },
      );
    }
    if (startTime && endTime && startTime >= endTime) {
      return HttpResponse.json(
        { code: 400, message: "startTime must be before endTime" },
        { status: 400 },
      );
    }

    let matching = rooms;
    if (minCapacity) {
      matching = matching.filter((r) => r.capacity >= Number(minCapacity));
    }
    if (date && startTime && endTime) {
      matching = matching.filter(
        (room) =>
          !bookings.some(
            (b) => b.roomId === room.id && b.date === date && overlaps(startTime, endTime, b.startTime, b.endTime),
          ),
      );
    }

    return HttpResponse.json(paginate(matching, limit, offset));
  }),

  http.get("/api/me/bookings", ({ request }) => {
    const url = new URL(request.url);
    const limit = Number(url.searchParams.get("limit") ?? 20);
    const offset = Number(url.searchParams.get("offset") ?? 0);
    const mine = bookings.filter((b) => b.ownerId === mockCaller.userId);
    const { count, data, next, previous } = paginate(mine, limit, offset);
    const stripped: Booking[] = data.map(({ ownerId: _ownerId, ...rest }) => rest);
    return HttpResponse.json({ count, data: stripped, next, previous });
  }),

  http.post("/api/me/bookings", async ({ request }) => {
    const input = (await request.json()) as Partial<NewBooking>;
    const { roomId, date, startTime, endTime, attendeeCount } = input;

    if (!roomId || !date || !startTime || !endTime || !attendeeCount) {
      return HttpResponse.json(
        { code: 400, message: "roomId, date, startTime, endTime and attendeeCount are required" },
        { status: 400 },
      );
    }
    const room = rooms.find((r) => r.id === roomId);
    if (!room) {
      return HttpResponse.json({ code: 400, message: "No such room" }, { status: 400 });
    }
    if (startTime >= endTime) {
      return HttpResponse.json(
        { code: 400, message: "startTime must be before endTime" },
        { status: 400 },
      );
    }
    const startsAt = new Date(`${date}T${startTime}:00`);
    if (Number.isNaN(startsAt.getTime()) || startsAt.getTime() < Date.now()) {
      return HttpResponse.json(
        {
          code: 400,
          message: "Start time is in the past",
          description: "This booking's start time has already passed.",
        },
        { status: 400 },
      );
    }
    if (attendeeCount > room.capacity) {
      return HttpResponse.json(
        {
          code: 409,
          message: "Too many attendees",
          description: `${room.name} seats ${room.capacity}, which is fewer than ${attendeeCount} attendees.`,
        },
        { status: 409 },
      );
    }
    const clash = bookings.some(
      (b) => b.roomId === roomId && b.date === date && overlaps(startTime, endTime, b.startTime, b.endTime),
    );
    if (clash) {
      return HttpResponse.json(
        {
          code: 409,
          message: "Room already booked",
          description: `${room.name} already has a booking on ${date} that overlaps this time range.`,
        },
        { status: 409 },
      );
    }
    const today = new Date().toISOString().slice(0, 10);
    const futureCount = bookings.filter((b) => b.ownerId === mockCaller.userId && b.date >= today).length;
    if (futureCount >= 2) {
      return HttpResponse.json(
        {
          code: 409,
          message: "Too many upcoming bookings",
          description: "You already hold two upcoming bookings; cancel one before making another.",
        },
        { status: 409 },
      );
    }

    const created: StoredBooking = {
      id: `booking-${nextId++}`,
      roomId: room.id,
      roomName: room.name,
      date,
      startTime,
      endTime,
      attendeeCount,
      createdAt: new Date().toISOString(),
      ownerId: mockCaller.userId,
    };
    bookings = [...bookings, created];
    const { ownerId: _ownerId, ...body } = created;
    return HttpResponse.json(body, { status: 201 });
  }),

  http.delete("/api/me/bookings/:bookingId", ({ params }) => {
    const booking = bookings.find((b) => b.id === params.bookingId);
    if (!booking || booking.ownerId !== mockCaller.userId) {
      return HttpResponse.json(
        { code: 404, message: "No such booking for the caller" },
        { status: 404 },
      );
    }
    bookings = bookings.filter((b) => b.id !== booking.id);
    return new HttpResponse(null, { status: 204 });
  }),
];
