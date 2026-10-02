// specs/design/components/rooms-api/openapi.yaml, implemented exactly: same
// paths, schemas and status codes. The gateway has already checked the
// operation's scope (api-management) before any request reaches here, so no
// resource below holds a scope check of its own — only `requireGatewayCaller`
// to resolve who the caller is, from the verified assertion and nothing the
// client sent.

import ballerina/http;
import ballerina/time;
import ballerina/uuid;

listener http:Listener ep0 = new (9090);

service http:InterceptableService / on ep0 {

    public function createInterceptors() returns AssertionInterceptor => new;

    // Every room, optionally filtered to those free for a date/time range and
    // with at least `minCapacity`.
    resource function get rooms(http:RequestContext ctx, string? date, string? startTime, string? endTime,
            int? minCapacity, int 'limit = 20, int offset = 0)
            returns http:Ok|http:BadRequest|http:Unauthorized|http:InternalServerError {
        GatewayCaller|http:Unauthorized caller = requireGatewayCaller(ctx);
        if caller is http:Unauthorized {
            return caller;
        }

        if minCapacity is int && minCapacity < 1 {
            return badRequest("minCapacity must be at least 1");
        }

        boolean anyRangeField = date is string || startTime is string || endTime is string;
        boolean allRangeFields = date is string && startTime is string && endTime is string;
        if anyRangeField && !allRangeFields {
            return badRequest("date, startTime and endTime must all be provided together");
        }

        string rangeDate = "";
        string rangeStart = "";
        string rangeEnd = "";
        if allRangeFields {
            string dateValue = <string>date;
            string startValue = <string>startTime;
            string endValue = <string>endTime;
            if !validateDate(dateValue) {
                return badRequest("invalid date");
            }
            string? startNorm = normalizeTime(startValue);
            string? endNorm = normalizeTime(endValue);
            if startNorm is () || endNorm is () {
                return badRequest("invalid time");
            }
            string startNormValue = startNorm;
            string endNormValue = endNorm;
            if endNormValue <= startNormValue {
                return badRequest("endTime must be after startTime");
            }
            rangeDate = dateValue;
            rangeStart = startNormValue;
            rangeEnd = endNormValue;
        }

        int effectiveLimit = clampLimit('limit);
        int effectiveOffset = clampOffset(offset);

        Room[]|error allRoomsResult = storeAllRooms(minCapacity);
        if allRoomsResult is error {
            return internalError("unable to read rooms");
        }
        Room[] allRooms = allRoomsResult;

        Room[] filteredRooms = allRooms;
        if allRangeFields {
            RoomBookingRange[]|error rangesResult = storeBookingsOnDate(rangeDate);
            if rangesResult is error {
                return internalError("unable to read bookings");
            }
            RoomBookingRange[] ranges = rangesResult;
            filteredRooms = from Room room in allRooms
                where !hasOverlap(room.id, ranges, rangeStart, rangeEnd)
                select room;
        }

        int totalCount = filteredRooms.length();
        Room[] pageRooms = paginateRooms(filteredRooms, effectiveLimit, effectiveOffset);

        map<string> extraParams = {};
        if minCapacity is int {
            extraParams["minCapacity"] = minCapacity.toString();
        }
        if allRangeFields {
            extraParams["date"] = rangeDate;
            extraParams["startTime"] = rangeStart;
            extraParams["endTime"] = rangeEnd;
        }

        RoomsEnvelope envelope = {
            count: totalCount,
            next: nextPageUri("/rooms", effectiveLimit, effectiveOffset, totalCount, extraParams),
            previous: previousPageUri("/rooms", effectiveLimit, effectiveOffset, extraParams),
            data: pageRooms
        };
        return <http:Ok>{body: envelope};
    }

    // The caller's own bookings, resolved from the gateway assertion.
    resource function get me/bookings(http:RequestContext ctx, int 'limit = 20, int offset = 0)
            returns http:Ok|http:Unauthorized|http:InternalServerError {
        GatewayCaller|http:Unauthorized caller = requireGatewayCaller(ctx);
        if caller is http:Unauthorized {
            return caller;
        }

        int effectiveLimit = clampLimit('limit);
        int effectiveOffset = clampOffset(offset);

        int|error countResult = storeCountMemberBookingsTotal(caller.userId);
        if countResult is error {
            return internalError("unable to read bookings");
        }
        int totalCount = countResult;

        Booking[]|error bookingsResult = storeListMemberBookings(caller.userId, effectiveLimit, effectiveOffset);
        if bookingsResult is error {
            return internalError("unable to read bookings");
        }
        Booking[] bookings = bookingsResult;

        map<string> noExtraParams = {};
        BookingsEnvelope envelope = {
            count: totalCount,
            next: nextPageUri("/me/bookings", effectiveLimit, effectiveOffset, totalCount, noExtraParams),
            previous: previousPageUri("/me/bookings", effectiveLimit, effectiveOffset, noExtraParams),
            data: bookings
        };
        return <http:Ok>{body: envelope};
    }

    // Book a free room for a date and time range.
    resource function post me/bookings(http:RequestContext ctx, NewBooking payload)
            returns http:Created|http:BadRequest|http:Unauthorized|http:Conflict|http:InternalServerError {
        GatewayCaller|http:Unauthorized caller = requireGatewayCaller(ctx);
        if caller is http:Unauthorized {
            return caller;
        }

        if payload.attendeeCount < 1 {
            return badRequest("attendeeCount must be at least 1");
        }
        if !validateDate(payload.date) {
            return badRequest("invalid date");
        }
        string? normalizedStart = normalizeTime(payload.startTime);
        string? normalizedEnd = normalizeTime(payload.endTime);
        if normalizedStart is () || normalizedEnd is () {
            return badRequest("invalid time");
        }
        string startValue = normalizedStart;
        string endValue = normalizedEnd;
        if endValue <= startValue {
            return badRequest("endTime must be after startTime");
        }

        Room?|error roomResult = storeGetRoom(payload.roomId);
        if roomResult is error {
            return internalError("unable to read room");
        }
        if roomResult is () {
            return badRequest("room does not exist");
        }
        Room room = roomResult;

        if isPastStart(payload.date, startValue) {
            return badRequest("start time is in the past");
        }

        if payload.attendeeCount > room.capacity {
            return conflictError("attendeeCount exceeds this room's capacity");
        }

        RoomBookingRange[]|error rangesResult = storeRoomBookingRanges(payload.roomId, payload.date);
        if rangesResult is error {
            return internalError("unable to check for overlapping bookings");
        }
        foreach RoomBookingRange r in rangesResult {
            if rangesOverlap(r.startTime, r.endTime, startValue, endValue) {
                return conflictError("overlaps an existing booking on this room");
            }
        }

        MemberBookingTime[]|error memberTimesResult = storeMemberBookingTimes(caller.userId);
        if memberTimesResult is error {
            return internalError("unable to check existing bookings");
        }
        if countFutureBookings(memberTimesResult) >= 2 {
            return conflictError("already holds two future bookings");
        }

        string bookingId = uuid:createType4AsString();
        time:Utc createdAt = time:utcNow();
        error? insertResult = storeInsertBooking(bookingId, payload.roomId, caller.userId, payload.date,
                startValue, endValue, payload.attendeeCount, createdAt);
        if insertResult is error {
            return internalError("unable to create booking");
        }

        Booking booking = {
            id: bookingId,
            roomId: payload.roomId,
            roomName: room.name,
            date: payload.date,
            startTime: startValue,
            endTime: endValue,
            attendeeCount: payload.attendeeCount,
            createdAt: time:utcToString(createdAt)
        };
        return <http:Created>{body: booking};
    }

    // Cancel a booking the caller made. A booking that does not exist, or
    // belongs to someone else, is 404 either way — never 403, so a caller
    // cannot learn another member's booking exists.
    resource function delete me/bookings/[string bookingId](http:RequestContext ctx)
            returns http:NoContent|http:Unauthorized|http:NotFound|http:InternalServerError {
        GatewayCaller|http:Unauthorized caller = requireGatewayCaller(ctx);
        if caller is http:Unauthorized {
            return caller;
        }

        BookingOwner?|error ownerResult = storeGetBookingOwner(bookingId);
        if ownerResult is error {
            return internalError("unable to read booking");
        }
        if ownerResult is () {
            return notFound();
        }
        BookingOwner owner = ownerResult;
        if owner.memberId != caller.userId {
            return notFound();
        }

        error? deleteResult = storeDeleteBooking(bookingId);
        if deleteResult is error {
            return internalError("unable to cancel booking");
        }
        return http:NO_CONTENT;
    }
}

function badRequest(string message) returns http:BadRequest => {body: <ErrorDetail>{code: 400, message: message}};

function conflictError(string message) returns http:Conflict => {body: <ErrorDetail>{code: 409, message: message}};

function notFound() returns http:NotFound => {body: <ErrorDetail>{code: 404, message: "no such booking"}};

function internalError(string message) returns http:InternalServerError => {body: <ErrorDetail>{code: 500, message: message}};
