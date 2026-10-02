// The contract-facing shapes from specs/design/components/rooms-api/openapi.yaml.
// Field names and required-ness mirror the schemas there exactly.

public type Room record {|
    string id;
    string name;
    int capacity;
    string location;
|};

public type NewBooking record {|
    string roomId;
    string date;
    string startTime;
    string endTime;
    int attendeeCount;
|};

public type Booking record {|
    string id;
    string roomId;
    string roomName;
    string date;
    string startTime;
    string endTime;
    int attendeeCount;
    string createdAt;
|};

public type ErrorDetail record {|
    int code;
    string message;
    string description?;
    string moreInfo?;
|};

public type RoomsEnvelope record {|
    int count;
    string? next;
    string? previous;
    Room[] data;
|};

public type BookingsEnvelope record {|
    int count;
    string? next;
    string? previous;
    Booking[] data;
|};
