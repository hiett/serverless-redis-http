# syntax=docker/dockerfile:1

###
FROM elixir:1.13.4-alpine AS builder

#
ARG MIX_ENV=prod
ENV MIX_ENV=${MIX_ENV}

ARG PORT

WORKDIR /app

COPY mix.exs .
COPY mix.lock .
COPY .formatter.exs .

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get

COPY lib/ ./lib/
COPY config/ ./config/

RUN mix release

###
FROM elixir:1.13.4-alpine

#
ARG MIX_ENV=prod
ENV MIX_ENV=${MIX_ENV}

WORKDIR /app

COPY --from=builder /app/_build/${MIX_ENV}/rel/prod/ ./_build/${MIX_ENV}/rel/prod/

CMD ["sh", "-c", "_build/${MIX_ENV}/rel/prod/bin/prod start"]
