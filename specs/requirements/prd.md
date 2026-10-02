# Shared Office Room Booking — PRD

## Problem Statement

Teams in a shared office compete for the same handful of meeting rooms. Without
one place to see what is free and to claim it, people double-book, turn up to an
occupied room, or book a room too small for the group they invited. The usual
fallbacks — a wall calendar, a chat message, a spreadsheet — have no way to
refuse a clash, so the clash is discovered in the corridor.

## Solution

A web app for booking the office's meeting rooms. A signed-in member sees the
rooms and their capacity, books one for a time range, and sees their own
bookings. The app refuses a booking that would clash with an existing one, and
refuses a booking for more people than the room holds — so a confirmed booking
is one the member can rely on.

## Actors

- **Member** — anyone in the office who signs in, books rooms, and manages the
bookings they created. A Member sees every room and every room's busy times,
but may only cancel bookings they made themselves. Every person who uses the
app is a Member; there is no administrator and no privileged role.

## User Stories

1. As a Member, I want to sign in securely, so that bookings are attributable to
a real person.
2. As a Member, I want to see the list of meeting rooms with their capacity and
location, so that I can choose one that fits my group.
3. As a Member, I want to search for the rooms that are free for a date and time
range and that hold at least my group size, so that I only consider rooms I
can actually book.
4. As a Member, I want to book a room for a date and a start and end time, giving
the number of attendees, so that the room is reserved for my meeting.
5. As a Member, I want a booking that clashes with an existing booking for the
same room to be refused with a clear reason, so that two meetings never claim
one room.
6. As a Member, I want a booking for more attendees than the room holds to be
refused with a clear reason, so that I do not take a room my group will not
fit in.
7. As a Member, I want my new booking to appear in my list of bookings
immediately after I make it, without reloading the page, so that I can
confirm the reservation was recorded.
8. As a Member, I want to cancel a booking I made, so that the room is released
for someone else.
9. As a Member, I want to be prevented from cancelling a booking somebody else
made, so that my meetings are not released without my knowledge.

## Product Decisions

- Sign-in is via SSO through Thunder, the platform identity provider — every web
app in this organization signs users in this way. (org default)
- **The office's rooms are a fixed set that the app does not manage.** Rooms,
with their name, capacity and location, are seeded when the app is deployed;
no one adds, edits or removes a room through the app.
- **Two bookings for the same room clash when their time ranges overlap at all.**
A booking that starts before an existing one ends, and ends after that existing
one starts, is a clash and is refused. Two bookings that merely touch — one
ending exactly when the next begins — do not clash and are both allowed.
- **A booking is refused when its attendee count is greater than the room's
capacity.** A booking for exactly the room's capacity is allowed.
- **A room is excluded from a search when it is already booked for any part of
the requested range, or when its capacity is less than the requested group
size.** Search and booking apply the same two rules, so a room offered by a
search can always be booked.
- A refused booking is reported to the Member with the reason it was refused, and
nothing is reserved.
- **A booking whose start time is in the past cannot be made.** The app does not
offer a past time as a choice.
- A Member may hold at most two bookings whose start time is still in the future;
a third is refused until one is cancelled or has passed.
- Bookings are for a single day — a booking's start and end are on the same date.
- All times are the office's local time; the app does not handle time zones.
- Room capacity is a whole number of people. Rooms are identified by a name
unique across the office.
- Cancelling a booking removes it; there is no cancellation history or audit
trail.

## Out of Scope

- Adding, editing or removing rooms through the app.
- Administrator or facilities-manager roles, and any privileged action.
- Recurring or repeating bookings.
- Inviting attendees, sending invitations, or any calendar integration.
- Check-in, no-show detection, or automatic release of unused rooms.
- Equipment or catering requests attached to a booking.
- Approval workflows for booking a room.
- Multiple offices, buildings, or floors as separate bookable scopes.
- Time zones and daylight-saving handling.
- Editing a booking in place; a change is a cancellation and a new booking.
- Reporting on room utilisation.

## Open Questions

- None.

