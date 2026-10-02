Feature: Booking a room

  @story-4
  Rule: A member can book a free room for a date and time range, giving the attendee count

    Scenario: Olivia books a free room
      Given a room named "Summit" with a capacity of 8 and no booking on "2026-10-21" between "09:00" and "10:00"
      When Olivia books "Summit" on "2026-10-21" from "09:00" to "10:00" for 5 attendees
      Then the booking is created for "Summit" on "2026-10-21" from "09:00" to "10:00"

  @story-5 @negative
  Rule: A booking that overlaps an existing booking on the same room is refused

    Scenario: A fully overlapping request is refused
      Given a room named "Summit" with a booking on "2026-10-21" between "09:00" and "10:00"
      When Olivia tries to book "Summit" on "2026-10-21" from "09:30" to "09:45"
      Then the booking is refused as a clash
      And "Summit" still has exactly one booking on "2026-10-21"

    Scenario: A booking that only touches an existing one is allowed
      Given a room named "Summit" with a booking on "2026-10-21" between "09:00" and "10:00"
      When Olivia books "Summit" on "2026-10-21" from "10:00" to "11:00" for 3 attendees
      Then the booking is created for "Summit" on "2026-10-21" from "10:00" to "11:00"

  @story-6 @negative
  Rule: A booking for more attendees than the room's capacity is refused

    Scenario: An oversized group is refused
      Given a room named "Atlas" with a capacity of 4 and no booking on "2026-10-22" between "13:00" and "14:00"
      When Olivia tries to book "Atlas" on "2026-10-22" from "13:00" to "14:00" for 6 attendees
      Then the booking is refused for exceeding the room's capacity
      And "Atlas" still has no booking on "2026-10-22" between "13:00" and "14:00"

    Scenario: A group exactly at capacity is allowed
      Given a room named "Atlas" with a capacity of 4 and no booking on "2026-10-22" between "15:00" and "16:00"
      When Olivia books "Atlas" on "2026-10-22" from "15:00" to "16:00" for 4 attendees
      Then the booking is created for "Atlas" on "2026-10-22" from "15:00" to "16:00"

  @story-7
  Rule: A new booking appears in the member's own bookings immediately

    Scenario: Olivia sees her booking right after making it
      Given a room named "Horizon" with a capacity of 10 and no booking on "2026-10-23" between "11:00" and "12:00"
      When Olivia books "Horizon" on "2026-10-23" from "11:00" to "12:00" for 7 attendees
      Then her list of bookings includes "Horizon" on "2026-10-23" from "11:00" to "12:00" without reloading the page

  @story-4 @negative
  Rule: A booking whose start time is in the past cannot be made

    Scenario: A past start time is rejected
      Given the current time is "2026-10-20 12:00" and a room named "Summit"
      When Olivia tries to book "Summit" on "2026-10-20" from "09:00" to "10:00"
      Then the booking is refused for being in the past
