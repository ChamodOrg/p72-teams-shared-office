screen RoomList "Every meeting room, with its capacity and location"
  navbar "Rooms | Rooms -> RoomList | My Bookings -> MyBookings"
  row
    heading "Meeting Rooms"
    right
    button "Search available..." primary -> RoomSearch
  table "Room | Capacity | Location"
    row "Atlas | 4 | 2nd floor"
    row "Summit | 8 | 2nd floor"
    row "Horizon | 12 | 3rd floor"

screen RoomSearch "Find a room free for a time range and group size"
  navbar "Rooms | Rooms -> RoomList | My Bookings -> MyBookings"
  heading "Search Rooms"
  row
    input "Date"
    input "Start time"
    input "End time"
    input "Attendees"
  button "Search" primary
  divider
  table "Room | Capacity | Location" -> BookRoom
    row "Summit | 8 | 2nd floor"
    row "Horizon | 12 | 3rd floor"

screen BookRoom "Book a free room for a time range"
  navbar "Rooms | Rooms -> RoomList | My Bookings -> MyBookings"
  heading "Book Summit"
  card "Summit"
    text "Capacity: 8 | 2nd floor"
  row
    input "Date"
    input "Start time"
    input "End time"
    input "Attendees"
  row
    button "Cancel" -> RoomSearch
    right
    button "Confirm booking" primary -> MyBookings
  text "A clash with an existing booking, or too many attendees for the room, is refused here with the reason."

screen MyBookings "The signed-in member's own upcoming bookings"
  navbar "Rooms | Rooms -> RoomList | My Bookings -> MyBookings"
  heading "My Bookings"
  table "Room | Date | Time | Attendees | "
    row "Summit | 2026-10-05 | 10:00-11:00 | 6 | "
    row "Horizon | 2026-10-06 | 14:00-15:00 | 10 | "
  text "Cancel a booking from this list to release the room immediately."

flow "Find and book a room"
  role "Member"
  description "A member searches for a free room that fits their group and books it"
  RoomList
  RoomSearch
  BookRoom
  MyBookings

flow "Manage my bookings"
  role "Member"
  description "A member reviews and cancels their own upcoming bookings"
  MyBookings
  RoomList
