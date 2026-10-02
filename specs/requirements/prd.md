# Shared Office Room Booking — PRD

## Problem Statement

Teams in a shared office compete for the same handful of meeting rooms. Without
one place to see what is free and to claim it, people double-book, turn up to
an occupied room, or book a room too small for the group they invited. The
usual fallbacks — a wall calendar, a chat message, a spreadsheet — have no way
to refuse a clash, so the clash is discovered in the corridor.

## Solution

A shared room-booking system that shows, in one place, which meeting rooms
exist, their capacity, and when each is free — and lets anyone claim a free
room for a time range with the system itself refusing any booking that would
clash with an existing one or that would not fit the group.

## Actors

- **Employee** — any staff member in the shared office. Can see room
availability, search by time and group size, book a free room, view their
own upcoming bookings, and cancel their own bookings.
- **Office Admin** — maintains the catalog of meeting rooms (name, capacity,
location) and can view and cancel any booking to resolve disputes or free a
room when needed.

## User Stories

1. As an Employee, I want to see which meeting rooms are free right now and
 for the rest of the day, so that I can quickly find a place to meet.
2. As an Employee, I want to search rooms by a time range and minimum group
 size, so that I only see rooms that actually fit my meeting.
3. As an Employee, I want to book a free room for a specific time range, so
 that it is reserved for my team.
4. As an Employee, I want the system to refuse a booking that overlaps an
 existing booking on the same room, so that clashes never happen.
5. As an Employee, I want the system to refuse a booking where my group is
 larger than the room's capacity, so that I never end up in a room too
 small for the people I invited.
6. As an Employee, I want to see my upcoming bookings, so that I can keep
 track of where and when I'm meeting.
7. As an Employee, I want to cancel a booking I made, so that I free the room
 for others when my meeting changes or is no longer needed.
8. As an Employee, I want the system to suggest the smallest free room that
 fits my group size and time, so that I don't have to compare rooms by hand.
9. As an Office Admin, I want to add, edit and remove meeting rooms (name,
 capacity, location), so that the room list reflects what's actually
 available in the office.
10. As an Office Admin, I want to view and cancel any booking, so that I can
 resolve disputes or free a room when a team no-shows or a plan changes.

## Product Decisions

- **Actors**: Employee (self-service booking) and Office Admin (manages the
room catalog, can override any booking). *assumed*
- **Scope of offices**: a single shared office — rooms are not grouped by
building or site. *assumed*
- **Booking shape**: one-off bookings only, each a single date/time range; no
recurring series in this version. *assumed*
- **Capacity enforcement**: hard rule — a room whose capacity is below the
stated group size is excluded from search results and cannot be booked for
that group, rather than merely flagged as a warning. *assumed*
- **Room suggestion**: an agent suggests the smallest free room that fits a
requested group size and time window, ranking options so the employee isn't
comparing a room list by hand. *assumed*
- **Sign-in**: every user signs in via SSO through Thunder, the platform IDP.
- **Notifications**: booking confirmation and clash refusals are shown in-app
only; no email/SMS notifications in this version. *assumed*
- **Self-service enrolment**: not applicable — accounts are provisioned via
the organization's existing directory through Thunder SSO, not self sign-up.

## Out of Scope

- Multiple office locations or buildings.
- Recurring/series bookings.
- Syncing with external calendars (Outlook, Google Calendar).
- Equipment, catering, or other resource requests attached to a booking.
- Email/SMS/chat notifications.
- Mobile-native apps (web only).

## Open Questions

&lt;none at this time&gt;

## Further Notes

&lt;none&gt;