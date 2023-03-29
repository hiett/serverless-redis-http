import {Redis} from "@upstash/redis";

const redis = new Redis({
  url: "http://127.0.0.1:8080",
  token: "example_token",
  responseEncoding: false,
});

(async () => {
  await redis.set("key", "value");
  const value = await redis.get("key");
  console.log(value); // value
})();