import {Redis} from "@upstash/redis";

const redis = new Redis({
  // The URL of the SRH instance
  url: "http://127.0.0.1:8080",

  // The token you defined in tokens.json
  token: "example_token",
});

(async () => {
  await redis.set("foo", "bar");
  const value = await redis.get("foo");
  console.log(value);

  // Run a pipeline operation
  const pipelineResponse = await redis.pipeline()
    .set("amazing-key", "bar")
    .get("amazing-key")
    .del("amazing-other-key")
    .del("random-key-that-doesnt-exist")
    .srandmember("random-key-that-doesnt-exist")
    .sadd("amazing-set", "item1", "item2", "item3", "bar", "foo", "example")
    .smembers("amazing-set")
    .get("foo")
    .exec();

  console.log(pipelineResponse);

  const multiExecResponse = await redis.multi()
    .set("example", "value")
    .get("example")
    .exec();

  console.log(multiExecResponse);
})();