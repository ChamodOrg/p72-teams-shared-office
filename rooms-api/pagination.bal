// limit/offset clamping and the next/previous relative-URI envelope fields,
// shared by both collection GETs.

function clampLimit(int requested) returns int {
    if requested < 1 {
        return 20;
    }
    if requested > 100 {
        return 100;
    }
    return requested;
}

function clampOffset(int requested) returns int {
    if requested < 0 {
        return 0;
    }
    return requested;
}

// In-memory paging for the rooms search, which must filter before it can
// page (see storeAllRooms in store.bal).
function paginateRooms(Room[] items, int pageLimit, int pageOffset) returns Room[] {
    int total = items.length();
    if pageOffset >= total {
        return [];
    }
    int endIndex = pageOffset + pageLimit;
    if endIndex > total {
        endIndex = total;
    }
    return items.slice(pageOffset, endIndex);
}

function buildPageUri(string path, int pageLimit, int pageOffset, map<string> extraParams) returns string {
    string query = string `limit=${pageLimit}&offset=${pageOffset}`;
    foreach [string, string] entry in extraParams.entries() {
        query = query + "&" + entry[0] + "=" + entry[1];
    }
    return path + "?" + query;
}

function nextPageUri(string path, int pageLimit, int pageOffset, int totalCount, map<string> extraParams) returns string? {
    int nextOffset = pageOffset + pageLimit;
    if nextOffset >= totalCount {
        return ();
    }
    return buildPageUri(path, pageLimit, nextOffset, extraParams);
}

function previousPageUri(string path, int pageLimit, int pageOffset, map<string> extraParams) returns string? {
    if pageOffset <= 0 {
        return ();
    }
    int previousOffset = pageOffset - pageLimit;
    if previousOffset < 0 {
        previousOffset = 0;
    }
    return buildPageUri(path, pageLimit, previousOffset, extraParams);
}
