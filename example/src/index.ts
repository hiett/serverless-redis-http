import {Redis} from "@upstash/redis";

const redis = new Redis({
  url: process.env.REDIS_CONNECTION_URL,
  token: "example_token",
  responseEncoding: false,
});

(async () => {
  await redis.set("key", "value");
  const value = await redis.get("key");
  console.log(value); // value
})();