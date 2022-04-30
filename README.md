# SRH: Serverless Redis HTTP
A Redis connection pooler for serverless applications. This allows your serverless functions to talk to Redis via HTTP,
while also not having to worry about the Redis max connection limits.

The idea is you host this alongside your Redis server, so minimise latency. The serverless functions can then talk to 
this via HTTP.

## Features
- Allows you to talk to redis via HTTP
- Pools redis connections
- Automatically kills redis connections after inactivity
- Supports multiple redis instances, and you can configure unique tokens for each
- Fully supports the `@upstash/redis` TypeScript library.

## Client usage
This will not work with regular Redis clients, as it is over HTTP and not the redis protocol.
However, to try and keep the project as "standardised" as possible, you can use the `@upstash/redis` TypeScript library.
You can read about it here: [Upstash Redis GitHub](https://github.com/upstash/upstash-redis)

Soon I will add specific documentation for the endpoints so you can implement clients in other languages.

## Installation
Soon, I will provide a Docker container for this. Right now, you need Elixir 1.13+ installed. Clone down the repo, then run:
`mix deps.get`
then
`iex -S mix`

To configure Redis targets:\
Create a file: `srh-config/tokens.json`
```json
{
    "example_token": {
        "srh_id": "some_unique_identifier",
        "connection_string": "redis://localhost:6379",
        "max_connections": 3
    } 
}
```
Notes: 
- Srh_id can be anything you want, as long as it's a string, and unique.
- `max_connections` is the maximum number of connections for the pool.
  - If there is inactivity, the pool will kill these connections. They will only be open while the pool is alive. The pool will re-create these connections when commands come in.
- You can add more redis instances to connect to by adding more tokens and connection configurations. Based on the header in each request, the correct pool/connection info will be used.