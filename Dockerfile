FROM elixir:1.14 AS build
ENV MIX_ENV=prod

WORKDIR /source
RUN mix local.hex --force && mix local.rebar --force

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get

# Copy App files
COPY lib lib
COPY config config
COPY priv priv


# Compile and build the app
RUN mix compile
RUN mix release

# Run the app
# -----------

FROM elixir:1.14
ENV MIX_ENV=prod
EXPOSE 4000

WORKDIR /app
COPY --from=build /source/_build/${MIX_ENV}/rel/v7_task_processor .

CMD ["bin/v7_task_processor", "start"]