// The Postgres client and startup schema/seed. One client, built once, at
// module level — but never `check`ed into a panic: the component contract
// requires this service to start with no required environment variables, so
// an unreachable rooms-db at boot is captured as a value (`dbClient is
// error`), logged, and every store function that needs it fails its own call
// instead of taking the whole service down.

import ballerina/log;
import ballerina/sql;
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;

function defaultedHost() returns string => roomsDbHost == "" ? "localhost" : roomsDbHost;

function defaultedDbName() returns string => roomsDbName == "" ? "rooms_api" : roomsDbName;

function defaultedUser() returns string => roomsDbUser == "" ? "postgres" : roomsDbUser;

function defaultedPort() returns int {
    int|error parsed = int:fromString(roomsDbPort);
    if parsed is int {
        return parsed;
    }
    return 5432;
}

function initDbClient() returns postgresql:Client|sql:Error {
    return new (
        host = defaultedHost(),
        username = defaultedUser(),
        password = roomsDbPassword,
        database = defaultedDbName(),
        port = defaultedPort()
    );
}

final postgresql:Client|sql:Error dbClient = initDbClient();

// The one place every store function reaches the client through — narrows
// the module-level union once per call instead of repeating the check.
function requireDbClient() returns postgresql:Client|error {
    if dbClient is error {
        return dbClient;
    }
    return dbClient;
}

function createSchema(postgresql:Client cl) returns error? {
    _ = check cl->execute(`
        CREATE TABLE IF NOT EXISTS rooms (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            capacity INT NOT NULL,
            location TEXT NOT NULL
        )
    `);
    _ = check cl->execute(`
        CREATE TABLE IF NOT EXISTS bookings (
            id TEXT PRIMARY KEY,
            room_id TEXT NOT NULL REFERENCES rooms(id),
            member_id TEXT NOT NULL,
            booking_date TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            attendee_count INT NOT NULL,
            created_at TIMESTAMPTZ NOT NULL
        )
    `);
}

// The fixed catalog from the wireframes' demo data. Rooms are seeded,
// read-only through this API — upserted idempotently so a restart never
// duplicates or errors on them.
function seedRooms(postgresql:Client cl) returns error? {
    sql:ParameterizedQuery[] seedQueries = [
        `INSERT INTO rooms (id, name, capacity, location) VALUES ('atlas', 'Atlas', 4, '2nd floor') ON CONFLICT (id) DO NOTHING`,
        `INSERT INTO rooms (id, name, capacity, location) VALUES ('summit', 'Summit', 8, '2nd floor') ON CONFLICT (id) DO NOTHING`,
        `INSERT INTO rooms (id, name, capacity, location) VALUES ('horizon', 'Horizon', 12, '3rd floor') ON CONFLICT (id) DO NOTHING`
    ];
    _ = check cl->batchExecute(seedQueries);
}

function initSchemaAndSeed() returns () {
    postgresql:Client|error cl = requireDbClient();
    if cl is error {
        log:printWarn("rooms-api starting without a usable rooms-db connection; DB-backed operations will fail until ROOMS_DB_* resolve to a reachable database", 'error = cl);
        return;
    }
    error? schemaResult = createSchema(cl);
    if schemaResult is error {
        log:printError("failed to create rooms-api schema", 'error = schemaResult);
        return;
    }
    error? seedResult = seedRooms(cl);
    if seedResult is error {
        log:printError("failed to seed the room catalog", 'error = seedResult);
    }
}

final () schemaReady = initSchemaAndSeed();
