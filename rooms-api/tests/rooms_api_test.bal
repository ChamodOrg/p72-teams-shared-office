// Verifies the gateway assertion interceptor (ballerina skill's Verify step)
// and, since every operation here requires a scope and none is public,
// 401-vs-200 behaviour per resource instead of a public-resource case.
//
// Run with a throwaway RSA keypair exported BEFORE `bal test`, so nothing
// here talks to a real gateway or IdP:
//
//   export GATEWAY_ASSERTION_CERTIFICATE="$(cat tests/resources/valid-cert.pem)"
//   export GATEWAY_ASSERTION_ISSUER="aep-gateway-test"
//   export GATEWAY_ASSERTION_HEADER="x-jwt-assertion"
//   bal test
//
// Every store* function (store.bal) is mocked here per tests.md's guidance
// for a test run with no live database: the interceptor and the resources'
// wiring are what is under test, not business-rule correctness against a
// real rooms-db.

import ballerina/crypto;
import ballerina/http;
import ballerina/jwt;
import ballerina/lang.array;
import ballerina/test;

final crypto:PrivateKey validPrivateKey = check crypto:decodeRsaPrivateKeyFromKeyFile("tests/resources/valid-key.pem");
final crypto:PrivateKey wrongPrivateKey = check crypto:decodeRsaPrivateKeyFromKeyFile("tests/resources/wrong-key.pem");
final http:Client testClient = check new ("http://localhost:9090");

const string TEST_ISSUER = "aep-gateway-test";
const string TEST_HEADER = "x-jwt-assertion";
const string TEST_MEMBER_ID = "member-1";

@test:Mock {functionName: "storeAllRooms"}
test:MockFunction storeAllRoomsMock = new ();

@test:Mock {functionName: "storeCountMemberBookingsTotal"}
test:MockFunction storeCountMemberBookingsTotalMock = new ();

@test:Mock {functionName: "storeListMemberBookings"}
test:MockFunction storeListMemberBookingsMock = new ();

@test:Mock {functionName: "storeGetRoom"}
test:MockFunction storeGetRoomMock = new ();

@test:Mock {functionName: "storeRoomBookingRanges"}
test:MockFunction storeRoomBookingRangesMock = new ();

@test:Mock {functionName: "storeMemberBookingTimes"}
test:MockFunction storeMemberBookingTimesMock = new ();

@test:Mock {functionName: "storeInsertBooking"}
test:MockFunction storeInsertBookingMock = new ();

@test:Mock {functionName: "storeGetBookingOwner"}
test:MockFunction storeGetBookingOwnerMock = new ();

@test:Mock {functionName: "storeDeleteBooking"}
test:MockFunction storeDeleteBookingMock = new ();

function mintToken(crypto:PrivateKey signingKey, string subject) returns string|error {
    jwt:IssuerConfig issuerConfig = {
        issuer: TEST_ISSUER,
        username: subject,
        expTime: 300,
        customClaims: {"scope": "rooms:read bookings:read bookings:create bookings:cancel"},
        signatureConfig: {
            algorithm: jwt:RS256,
            config: signingKey
        }
    };
    return jwt:issue(issuerConfig);
}

// Edits the payload segment of an already-signed token so its claims differ
// from what was signed, without re-signing — the signature now verifies
// against different bytes, which jwt:validate must reject.
function tamperedToken(string token) returns string|error {
    string[] parts = re `\.`.split(token);
    byte[] payloadBytes = check base64UrlDecode(parts[1]);
    string payloadJson = check string:fromBytes(payloadBytes);
    string editedJson = re `member-1`.replace(payloadJson, "member-9");
    string editedPayload = base64UrlEncode(editedJson.toBytes());
    return parts[0] + "." + editedPayload + "." + parts[2];
}

function base64UrlDecode(string input) returns byte[]|error {
    string padded = input;
    int remainder = padded.length() % 4;
    if remainder == 2 {
        padded = padded + "==";
    } else if remainder == 3 {
        padded = padded + "=";
    }
    string standardB64 = re `-`.replaceAll(padded, "+");
    standardB64 = re `_`.replaceAll(standardB64, "/");
    return array:fromBase64(standardB64);
}

function base64UrlEncode(byte[] data) returns string {
    string standardB64 = array:toBase64(data);
    string noPadding = re `=+$`.replaceAll(standardB64, "");
    string urlSafe = re `\+`.replaceAll(noPadding, "-");
    urlSafe = re `/`.replaceAll(urlSafe, "_");
    return urlSafe;
}

// --- The interceptor itself (ballerina skill's four required cases, minus
// the public-resource one: nothing here is public) --------------------------

@test:Config {}
function testValidAssertionIsAccepted() returns error? {
    string token = check mintToken(validPrivateKey, TEST_MEMBER_ID);
    Room[] seededRooms = [{id: "atlas", name: "Atlas", capacity: 4, location: "2nd floor"}];
    test:when(storeAllRoomsMock).thenReturn(seededRooms);
    http:Response response = check testClient->get("/rooms", headers = {[TEST_HEADER]: token});
    test:assertEquals(response.statusCode, 200);
}

@test:Config {}
function testAssertionSignedByAnotherKeyIs401() returns error? {
    string token = check mintToken(wrongPrivateKey, TEST_MEMBER_ID);
    http:Response response = check testClient->get("/rooms", headers = {[TEST_HEADER]: token});
    test:assertEquals(response.statusCode, 401);
}

@test:Config {}
function testTamperedPayloadAssertionIs401() returns error? {
    string original = check mintToken(validPrivateKey, TEST_MEMBER_ID);
    string tampered = check tamperedToken(original);
    http:Response response = check testClient->get("/rooms", headers = {[TEST_HEADER]: tampered});
    test:assertEquals(response.statusCode, 401);
}

// --- 401 vs 200 per resource -------------------------------------------

@test:Config {}
function testListRoomsWithoutAssertionIs401() returns error? {
    http:Response response = check testClient->get("/rooms");
    test:assertEquals(response.statusCode, 401);
}

@test:Config {}
function testListRoomsWithValidAssertionIs200() returns error? {
    Room[] seededRooms = [{id: "summit", name: "Summit", capacity: 8, location: "2nd floor"}];
    test:when(storeAllRoomsMock).thenReturn(seededRooms);
    string token = check mintToken(validPrivateKey, TEST_MEMBER_ID);
    http:Response response = check testClient->get("/rooms", headers = {[TEST_HEADER]: token});
    test:assertEquals(response.statusCode, 200);
}

@test:Config {}
function testListMyBookingsWithoutAssertionIs401() returns error? {
    http:Response response = check testClient->get("/me/bookings");
    test:assertEquals(response.statusCode, 401);
}

@test:Config {}
function testListMyBookingsWithValidAssertionIs200() returns error? {
    test:when(storeCountMemberBookingsTotalMock).thenReturn(0);
    test:when(storeListMemberBookingsMock).thenReturn(<Booking[]>[]);
    string token = check mintToken(validPrivateKey, TEST_MEMBER_ID);
    http:Response response = check testClient->get("/me/bookings", headers = {[TEST_HEADER]: token});
    test:assertEquals(response.statusCode, 200);
}

@test:Config {}
function testCreateMyBookingWithoutAssertionIs401() returns error? {
    NewBooking payload = {roomId: "atlas", date: "2999-01-01", startTime: "10:00", endTime: "11:00", attendeeCount: 1};
    http:Response response = check testClient->post("/me/bookings", payload);
    test:assertEquals(response.statusCode, 401);
}

@test:Config {}
function testCreateMyBookingWithValidAssertionIs201() returns error? {
    Room atlas = {id: "atlas", name: "Atlas", capacity: 4, location: "2nd floor"};
    test:when(storeGetRoomMock).thenReturn(atlas);
    test:when(storeRoomBookingRangesMock).thenReturn(<RoomBookingRange[]>[]);
    test:when(storeMemberBookingTimesMock).thenReturn(<MemberBookingTime[]>[]);
    test:when(storeInsertBookingMock).doNothing();
    NewBooking payload = {roomId: "atlas", date: "2999-01-01", startTime: "10:00", endTime: "11:00", attendeeCount: 1};
    string token = check mintToken(validPrivateKey, TEST_MEMBER_ID);
    http:Response response = check testClient->post("/me/bookings", payload, headers = {[TEST_HEADER]: token});
    test:assertEquals(response.statusCode, 201);
}

@test:Config {}
function testCancelMyBookingWithoutAssertionIs401() returns error? {
    http:Response response = check testClient->delete("/me/bookings/booking-1");
    test:assertEquals(response.statusCode, 401);
}

@test:Config {}
function testCancelMyBookingWithValidAssertionIs204() returns error? {
    BookingOwner owner = {id: "booking-1", memberId: TEST_MEMBER_ID};
    test:when(storeGetBookingOwnerMock).thenReturn(owner);
    test:when(storeDeleteBookingMock).doNothing();
    string token = check mintToken(validPrivateKey, TEST_MEMBER_ID);
    http:Response response = check testClient->delete("/me/bookings/booking-1", headers = {[TEST_HEADER]: token});
    test:assertEquals(response.statusCode, 204);
}

// A booking that exists but belongs to someone else must read exactly like
// one that does not exist at all — 404, never 403 — so a caller cannot learn
// another member's booking exists.
@test:Config {}
function testCancelSomeoneElsesBookingIs404NotForbidden() returns error? {
    BookingOwner owner = {id: "booking-2", memberId: "someone-else"};
    test:when(storeGetBookingOwnerMock).thenReturn(owner);
    string token = check mintToken(validPrivateKey, TEST_MEMBER_ID);
    http:Response response = check testClient->delete("/me/bookings/booking-2", headers = {[TEST_HEADER]: token});
    test:assertEquals(response.statusCode, 404);
}
