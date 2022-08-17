# SRH: Serverless Redis HTTP

---

**TLDR: If you want to run a local Upstash-compatible HTTP layer in front of your Redis:**

0) Have a locally running Redis instance - in this example bound to the default port 6379
1) create a json file called tokens.json in a folder called srh-config (`srh-config/tokens.json`)
2) paste this in:
  ```json
  {
    "example_token": {
        "srh_id": "some_unique_identifier",
        "connection_string": "redis://localhost:6379",
        "max_connections": 3
    } 
  }
  ```
3) Run this command:
`docker run -it -d -p 8079:80 --name srh --mount type=bind,source=$(pwd)/srh-config/tokens.json,target=/app/srh-config/tokens.json hiett/serverless-redis-http:latest`
4) Set this as your Upstash configuration
```js
import {Redis} from '@upstash/redis';

export const redis = new Redis({
	url: "http://localhost:8079",
	token: "example_token",
});
```
---

A Redis connection pooler for serverless applications. This allows your serverless functions to talk to Redis via HTTP,
while also not having to worry about the Redis max connection limits.

The idea is you host this alongside your Redis server, to minimise latency. Your serverless functions can then talk to 
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
You have to options to run this:
- Via docker: `docker pull hiett/serverless-redis-http:latest` [Docker Hub link](https://hub.docker.com/r/hiett/serverless-redis-http)
- Via elixir: `(clone this repo)` -> `mix deps.get` -> `iex -S mix`

If you are running via Docker, you will need to mount the configuration file to `/app/srh-config/tokens.json`.\
An example of a run command is the following:

`docker run -it -d -p 8080:80 --name srh --mount type=bind,source=$(pwd)/srh-config/tokens.json,target=/app/srh-config/tokens.json hiett/serverless-redis-http:latest`

*Note that it is running on port 80*

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