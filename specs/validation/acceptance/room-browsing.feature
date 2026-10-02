Feature: Room browsing

  @story-1
  Rule: Only a signed-in member can see the room list

    @negative
    Scenario: A signed-out visitor is sent to sign in
      Given Olivia has not signed in
      When Olivia tries to open the meeting room list
      Then she is sent to sign in and the room list is not shown

  @story-2
  Rule: Every room is listed with its capacity and location

    Scenario: Olivia sees the office's rooms
      Given Olivia has signed in as a member
      When she opens the meeting room list
      Then she sees every room in the office, each with its capacity and location

  @story-3
  Rule: Search only offers rooms free for the requested range and big enough for the group

    Scenario: A free, big-enough room is offered
      Given a room named "Summit" with a capacity of 8 and no booking on "2026-10-20" between "10:00" and "11:00"
      When Olivia searches for a room on "2026-10-20" between "10:00" and "11:00" for 6 attendees
      Then "Summit" is among the rooms offered

    @negative
    Scenario: A room already booked for the range is excluded
      Given a room named "Summit" with a booking on "2026-10-20" between "10:00" and "11:00"
      When Olivia searches for a room on "2026-10-20" between "10:00" and "11:00" for 4 attendees
      Then "Summit" is not among the rooms offered

    @negative
    Scenario: A room too small for the group is excluded
      Given a room named "Atlas" with a capacity of 4
      When Olivia searches for a room on "2026-10-20" between "10:00" and "11:00" for 6 attendees
      Then "Atlas" is not among the rooms offered
