// The Product Decisions from the PRD, as pure functions: date/time format
// validation, the overlap rule, and what counts as "future" for the
// max-two-future-bookings rule. No DB and no HTTP here, so each is testable
// in isolation if that is ever wanted — none of that is required for this
// issue, but keeping the rules pure is what makes the 401-vs-200 resource
// tests possible without a database, since storeXxx (store.bal) is all that
// needs mocking.

import ballerina/time;

final string:RegExp DATE_PATTERN = re `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`;
final string:RegExp TIME_PATTERN = re `^[0-9]{2}:[0-9]{2}(:[0-9]{2})?$`;

// Format plus a loose calendar-range check (month 1-12, day 1-31) — not a
// full days-in-month validation, which the PRD's "invalid date or time
// range" language does not ask for.
function validateDate(string date) returns boolean {
    if !DATE_PATTERN.isFullMatch(date) {
        return false;
    }
    string[] parts = re `-`.split(date);
    int|error month = int:fromString(parts[1]);
    int|error day = int:fromString(parts[2]);
    if month is error || day is error {
        return false;
    }
    if month < 1 || month > 12 {
        return false;
    }
    if day < 1 || day > 31 {
        return false;
    }
    return true;
}

// Accepts "HH:MM" or "HH:MM:SS" and normalizes to "HH:MM:SS" so every stored
// and compared value has the same fixed width — the width that makes a plain
// string `<`/`>` comparison equivalent to chronological order.
function normalizeTime(string timeValue) returns string? {
    if !TIME_PATTERN.isFullMatch(timeValue) {
        return ();
    }
    string[] parts = re `:`.split(timeValue);
    int|error hour = int:fromString(parts[0]);
    int|error minute = int:fromString(parts[1]);
    if hour is error || minute is error {
        return ();
    }
    if hour < 0 || hour > 23 || minute < 0 || minute > 59 {
        return ();
    }
    string seconds = "00";
    if parts.length() == 3 {
        int|error sec = int:fromString(parts[2]);
        if sec is error || sec < 0 || sec > 59 {
            return ();
        }
        seconds = parts[2];
    }
    return parts[0] + ":" + parts[1] + ":" + seconds;
}

// Two ranges clash only when they genuinely overlap — touching endpoints
// (one ends exactly when the other begins) are allowed, hence strict `<`/`>`
// rather than `<=`/`>=`.
function rangesOverlap(string existingStart, string existingEnd, string newStart, string newEnd) returns boolean {
    return existingStart < newEnd && existingEnd > newStart;
}

function hasOverlap(string roomId, RoomBookingRange[] ranges, string newStart, string newEnd) returns boolean {
    foreach RoomBookingRange r in ranges {
        if r.roomId == roomId && rangesOverlap(r.startTime, r.endTime, newStart, newEnd) {
            return true;
        }
    }
    return false;
}

// The server's own clock as the "local, no timezone handling" reference —
// there is no zone conversion anywhere in this service, so the wall clock the
// process runs on IS the local clock the PRD means.
function currentDateAndTime() returns [string, string] {
    time:Utc nowUtc = time:utcNow();
    time:Civil nowCivil = time:utcToCivil(nowUtc);
    return [civilDateString(nowCivil), civilTimeString(nowCivil)];
}

function civilDateString(time:Civil c) returns string {
    return padInt(c.year, 4) + "-" + padInt(c.month, 2) + "-" + padInt(c.day, 2);
}

function civilTimeString(time:Civil c) returns string {
    int wholeSeconds = <int>c.second;
    return padInt(c.hour, 2) + ":" + padInt(c.minute, 2) + ":" + padInt(wholeSeconds, 2);
}

function padInt(int n, int width) returns string {
    string s = n.toString();
    while s.length() < width {
        s = "0" + s;
    }
    return s;
}

// Strictly before now — a start time equal to the current second is not yet
// "in the past".
function isPastStart(string date, string startTime) returns boolean {
    [string, string] nowParts = currentDateAndTime();
    string today = nowParts[0];
    string nowTime = nowParts[1];
    if date < today {
        return true;
    }
    return date == today && startTime < nowTime;
}

// Strictly after now, the symmetric counterpart used for the
// max-two-future-bookings count.
function isFutureBooking(string date, string startTime) returns boolean {
    [string, string] nowParts = currentDateAndTime();
    string today = nowParts[0];
    string nowTime = nowParts[1];
    if date > today {
        return true;
    }
    return date == today && startTime > nowTime;
}

function countFutureBookings(MemberBookingTime[] times) returns int {
    int count = 0;
    foreach MemberBookingTime t in times {
        if isFutureBooking(t.date, t.startTime) {
            count += 1;
        }
    }
    return count;
}
