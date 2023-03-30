## Building the Docker image

To build both an amd64 image and an arm64 image, on an M1 Mac:

```
docker buildx build --platform linux/amd64,linux/arm64 --push -t hiett/serverless-redis-http:0.0.5-alpha
```