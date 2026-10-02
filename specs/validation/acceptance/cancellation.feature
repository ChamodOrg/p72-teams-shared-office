Feature: Cancelling a booking

  @story-8
  Rule: A member can cancel a booking they made

    Scenario: Olivia cancels her own booking
      Given Olivia has booked "Summit" on "2026-10-24" from "09:00" to "10:00"
      When Olivia cancels that booking
      Then her list of bookings no longer includes "Summit" on "2026-10-24" from "09:00" to "10:00"
      And "Summit" is free again on "2026-10-24" between "09:00" and "10:00"

  @story-9 @negative
  Rule: A member cannot cancel a booking somebody else made

    Scenario: Olivia cannot cancel Dan's booking
      Given Dan has booked "Horizon" on "2026-10-25" from "14:00" to "15:00"
      When Olivia tries to cancel Dan's booking
      Then the cancellation is refused
      And Dan's list of bookings still includes "Horizon" on "2026-10-25" from "14:00" to "15:00"
