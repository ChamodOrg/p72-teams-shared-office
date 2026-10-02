// Data access, and nothing else — every function here is a thin wrapper
// around one query. Kept separate from service.bal so each can be replaced
// wholesale with @test:Mock, the pattern the ballerina skill's tests.md calls
// for when a real database is not part of a test run.

import ballerina/sql;
import ballerina/time;
import ballerinax/postgresql;

// A booking's room/time-range, read back for overlap checking. `roomId` is
// included even when the caller already knows it (one room's own bookings)
// so the one row shape serves both call sites below.
type RoomBookingRange record {|
    string roomId;
    string startTime;
    string endTime;
|};

type BookingOwner record {|
    string id;
    string memberId;
|};

// A member's booking, reduced to just what the future-bookings count needs.
type MemberBookingTime record {|
    string date;
    string startTime;
|};

// The DB row shape for a caller's bookings, joined with the room name.
// `createdAt` stays `time:Utc` here — never a string — per the code-rules'
// timestamptz binding rule; `toBooking` renders it to RFC3339 for the API.
type BookingRow record {|
    string id;
    string roomId;
    string roomName;
    string date;
    string startTime;
    string endTime;
    int attendeeCount;
    time:Utc createdAt;
|};

function toBooking(BookingRow row) returns Booking => {
    id: row.id,
    roomId: row.roomId,
    roomName: row.roomName,
    date: row.date,
    startTime: row.startTime,
    endTime: row.endTime,
    attendeeCount: row.attendeeCount,
    createdAt: time:utcToString(row.createdAt)
};

// Every room, optionally narrowed to at-least-this-capacity. Unpaginated —
// the catalog is a handful of rows, and the free/busy exclusion in
// service.bal needs the whole set before it can page the result.
function storeAllRooms(int? minCapacity) returns Room[]|error {
    postgresql:Client cl = check requireDbClient();
    sql:ParameterizedQuery query = minCapacity is int
        ? `SELECT id, name, capacity, location FROM rooms WHERE capacity >= ${minCapacity} ORDER BY id`
        : `SELECT id, name, capacity, location FROM rooms ORDER BY id`;
    stream<Room, sql:Error?> resultStream = cl->query(query);
    Room[] rooms = check from Room room in resultStream select room;
    check resultStream.close();
    return rooms;
}

function storeGetRoom(string roomId) returns Room?|error {
    postgresql:Client cl = check requireDbClient();
    Room|sql:Error result = cl->queryRow(`SELECT id, name, capacity, location FROM rooms WHERE id = ${roomId}`);
    if result is sql:NoRowsError {
        return ();
    }
    if result is sql:Error {
        return result;
    }
    return result;
}

// Every booking on the given date, across every room — for excluding a busy
// room from a `/rooms` range search.
function storeBookingsOnDate(string date) returns RoomBookingRange[]|error {
    postgresql:Client cl = check requireDbClient();
    sql:ParameterizedQuery query = `SELECT room_id AS "roomId", start_time AS "startTime", end_time AS "endTime"
        FROM bookings WHERE booking_date = ${date}`;
    stream<RoomBookingRange, sql:Error?> resultStream = cl->query(query);
    RoomBookingRange[] ranges = check from RoomBookingRange r in resultStream select r;
    check resultStream.close();
    return ranges;
}

// One room's bookings on one date — the overlap check a new booking on that
// room must clear.
function storeRoomBookingRanges(string roomId, string date) returns RoomBookingRange[]|error {
    postgresql:Client cl = check requireDbClient();
    sql:ParameterizedQuery query = `SELECT room_id AS "roomId", start_time AS "startTime", end_time AS "endTime"
        FROM bookings WHERE room_id = ${roomId} AND booking_date = ${date}`;
    stream<RoomBookingRange, sql:Error?> resultStream = cl->query(query);
    RoomBookingRange[] ranges = check from RoomBookingRange r in resultStream select r;
    check resultStream.close();
    return ranges;
}

// Every booking's date/startTime for a member — the max-two-future-bookings
// check filters these in application code, since "future" depends on the
// clock at call time.
function storeMemberBookingTimes(string memberId) returns MemberBookingTime[]|error {
    postgresql:Client cl = check requireDbClient();
    sql:ParameterizedQuery query = `SELECT booking_date AS "date", start_time AS "startTime"
        FROM bookings WHERE member_id = ${memberId}`;
    stream<MemberBookingTime, sql:Error?> resultStream = cl->query(query);
    MemberBookingTime[] times = check from MemberBookingTime t in resultStream select t;
    check resultStream.close();
    return times;
}

function storeCountMemberBookingsTotal(string memberId) returns int|error {
    postgresql:Client cl = check requireDbClient();
    record {| int total; |} result = check cl->queryRow(`SELECT COUNT(*) AS total FROM bookings WHERE member_id = ${memberId}`);
    return result.total;
}

function storeListMemberBookings(string memberId, int pageLimit, int pageOffset) returns Booking[]|error {
    postgresql:Client cl = check requireDbClient();
    sql:ParameterizedQuery query = `
        SELECT b.id AS id, b.room_id AS "roomId", r.name AS "roomName",
               b.booking_date AS "date", b.start_time AS "startTime", b.end_time AS "endTime",
               b.attendee_count AS "attendeeCount", b.created_at AS "createdAt"
        FROM bookings b JOIN rooms r ON r.id = b.room_id
        WHERE b.member_id = ${memberId}
        ORDER BY b.created_at DESC
        LIMIT ${pageLimit} OFFSET ${pageOffset}`;
    stream<BookingRow, sql:Error?> resultStream = cl->query(query);
    BookingRow[] rows = check from BookingRow row in resultStream select row;
    check resultStream.close();
    return from BookingRow row in rows select toBooking(row);
}

function storeInsertBooking(string id, string roomId, string memberId, string date, string startTime,
        string endTime, int attendeeCount, time:Utc createdAt) returns error? {
    postgresql:Client cl = check requireDbClient();
    _ = check cl->execute(`
        INSERT INTO bookings (id, room_id, member_id, booking_date, start_time, end_time, attendee_count, created_at)
        VALUES (${id}, ${roomId}, ${memberId}, ${date}, ${startTime}, ${endTime}, ${attendeeCount}, ${createdAt})
    `);
}

function storeGetBookingOwner(string bookingId) returns BookingOwner?|error {
    postgresql:Client cl = check requireDbClient();
    BookingOwner|sql:Error result = cl->queryRow(`SELECT id, member_id AS "memberId" FROM bookings WHERE id = ${bookingId}`);
    if result is sql:NoRowsError {
        return ();
    }
    if result is sql:Error {
        return result;
    }
    return result;
}

function storeDeleteBooking(string bookingId) returns error? {
    postgresql:Client cl = check requireDbClient();
    _ = check cl->execute(`DELETE FROM bookings WHERE id = ${bookingId}`);
}
