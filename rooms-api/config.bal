// Every platform-injected environment variable this service reads, in one
// place. Names come from design.json's envBindings for the rooms-db
// platform-resource dependency — never renamed, never invented.
//
// The user-auth (thunder-app) dependency is also wired in workload.yaml, but
// nothing in this service's own code reads its USER_AUTH_* values: they back
// the gateway's signed assertion (verified in gateway_assertion.bal against
// GATEWAY_ASSERTION_CERTIFICATE/_ISSUER/_HEADER, which the platform injects
// separately), never a token this service validates itself.

import ballerina/os;

configurable string roomsDbHost = os:getEnv("ROOMS_DB_HOST");
configurable string roomsDbPort = os:getEnv("ROOMS_DB_PORT");
configurable string roomsDbName = os:getEnv("ROOMS_DB_DBNAME");
configurable string roomsDbUser = os:getEnv("ROOMS_DB_USER");
configurable string roomsDbPassword = os:getEnv("ROOMS_DB_PASSWORD");
