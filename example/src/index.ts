import {Redis} from "@upstash/redis";

const redis = new Redis({
  url: "http://127.0.0.1:8080",
  token: "example_token",
  // responseEncoding: true,
});

(async () => {
  // await redis.set("key", "value");
  const value = await redis.get("foo");
  console.log(value); // value

  // Run a pipeline operation
  const pipelineResponse = await redis.pipeline()
    .set("amazing-key", "bar")
    .get("amazing-key")
    .del("amazing-other-key")
    .del("random-key-that-doesnt-exist")
    .srandmember("random-key-that-doesnt-exist")
    .sadd("amazing-set", "item1", "item2", "item3", "bar", "foo", "example")
    .smembers("amazing-set")
    // .evalsha("aijsojiasd", [], [])
    .get("foo")
    .exec();

  console.log(pipelineResponse);
})();