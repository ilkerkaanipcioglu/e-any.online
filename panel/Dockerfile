# ---- Build stage ----
FROM elixir:1.18 AS build
WORKDIR /app

RUN apt-get update -y && apt-get install -y build-essential git curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod
ENV PHX_SERVER=true

COPY mix.exs mix.lock ./
RUN mix local.hex --force && mix local.rebar --force && mix deps.get --only prod

COPY . .
RUN mix deps.compile \
    && mix compile \
    && cd assets && npm install && cd .. \
    && mix assets.deploy \
    && mix release e_any_panel

# ---- Runtime stage ----
FROM elixir:1.18-slim AS app
WORKDIR /app

RUN apt-get update -y && apt-get install -y libstdc++6 openssl ca-certificates curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/_build/prod/rel/e_any_panel /app

ENV HOME=/app
EXPOSE 4000

CMD ["/app/bin/e_any_panel", "start"]
