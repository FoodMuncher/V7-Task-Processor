# V7TaskProcessor

## Using the App

### Starting up
To start up the app, build and run the docker image with the command: `docker build --tag "v7_task_processor" .; docker run -p 4000:4000 v7_task_processor:latest`

The app will now be running on port `4000`.

### Testing
To run the tests use the command: `mix test`

### Sending in an Event
To handle incoming events a HTTP endpoint has been created.

#### Request

Endpoint:
`POST "/api/event/v1"`

Request Body:
```
{
  "user_id":       integer,
  "priority":      integer,
  "event_data":    any,
  "event_type_id": integer
}
```
Where `priority` is the order in which incoming requests are processed. The lower the number, the higher the priority. Higher priority events will be processed first.

Request Headers:
`Content-Type: application/json`

Example Curl Request:
`curl -d '{"user_id": 123, "priority": 1, "event_data": "data", "event_type_id": 5}'  -H 'Content-Type: application/json' -X POST "localhost:4000/api/event/v1"`

#### Response
* If the event is succesfully added to the queue, it will return a status code of `200`.
* If the event is malformed and can't be parsed, it will return a `400` and the body will be a string explaining the reason why it was rejected.
* If the event is unable to be added to the queue, it will return a `500`

## Implementation

### General Code Flow

The general flow of an incoming request is as follows:
1. An event is sent into the app and picked up by the EventController, where it is parsed into an Event struct.
2. The event is passed into the Queue GenServer.
3. The Queue GenServer, receives the request. From here it can do two things:
  * If all Queue Workers are active (all currently processing events), it will add the request to it's internal state, where it will be processed once a Queue Worker becomes available.
  *  If there is an inactive Queue Worker (not currently processing an events), it will notify the Queue Worker of a new event.
4. The Queue Worker receives the event, it will then process the event.
5. Once the event has been processed, the Queue Worker will notify the Queue that it was processed.
6. The Queue then has two possibilities:
  * The Queue has more events within its internal state, so it notifies the Queue Worker of the next event, and the cycle continues from bullet point 4.
  * The Queue has no more events within its internal state, so the Queue Worker is put on standby until more work is received.

### Event Handling

If an event is failed to be processed within the worker, when the worker asks the queue for more work it will notify the Queue that the previous event was a failure. The Queue will increment the event's retry counter. If the retry count is below the maximum number of retries, the event will be re-queued. If the retry count hits the maximum number of retries, the event will be sent to the dead letter queue, to be investigated further.

If a Worker crashes, the Queue will be notified. The Queue will then restart the worker, and requeue the event that the worker was processing. Unless the event has hit the retry limit, where it will be sent to the Dead Letter Queue.

### Design Choices

#### Priority Queue
I opted to create a custom data type to handle queue priorities. The data type is a two element tuple, where the first element is an `ordset` made up of the `priority` integers and the second is a `map` with keys of `priority` integers and values of `queue` objects made up of `Event` structs.

When adding an event, the event prioity is added to `ordset`, it doesn't matter if we add the same integer multiple times, it will only be represented once in the `ordset`.
After that the `Event` is added to the relevant `queue` within the `map` for the `Event`'s `priority`.

When fetching from the priority queue, it will get the first `priority` integer from the `ordset`, as the `ordset` is ordered it will return the smallest integer it has. Next, we fetch the relevant `queue` from the `map`, and pop the `Event` at the top of the `queue`.

#### Adding to the Queue
When the `EventController` adds to the `Queue` GenServer it uses a `call`. I opted for a `call` over a `cast` as I wanted to be certain that the event had reached the `Queue` before replied to the HTTP call.
A cast would mean the `EventController` could reply to the HTTP call sooner, but we wouldn't have the certantiy that the event was added.
As the `call` means we have to wait for the `GenServer` to reply before the `EventController` can proceed, there is the possibilty that the `EventController` could timeout. This is one downside to using the `call` approach. To avoid this the timeout duration could be increased or removed altogether.

#### Event Type Queues
I chose not to implement the Event Type Queues, as there is already a lot of code to be reviewed. If I were to implement this feature, I would do the following.

I'd start up a `Registry` for the `Queue`s and then rather than have the `Queue` `GenServer` use the module name as its name, it would use the `Registry` and use the `event_type_id` as the identifier. I would have the `Queue`s using a `DynamicSupervisor`, and I would also start a new `GenServer` called `QueueController`.

When an event comes in and is successfully parsed, I would check the check the `Registry` for the `event_type_id`. If the `Queue` exists, the code flow will continue as normal sending the event to this `Queue`.
If the `Queue` is not present in the `Registry`, it would call the `QueueController` to create a new `Queue` for the `event_type_id` and the `Queue` pid would be returned from this call. The reason for a `GenServer` here is because we need to serialise `Queue` creation, to stop two events with the same `event_type_id` from creating the same `Queue`.

#### Database Interactions
Persistance of the queue was not a requirement for this implementation. If this was a real world example, I would have stored the events in a database. If the app was restarted, it could then read from the database to get any unprocessed events. In addition, if the queue process crashed, it could read from the database to get it's internal queue back to it's original state.
