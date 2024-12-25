ARG ELIXIR_VERSION=1.18.0
ARG OTP_VERSION=27.0.1
ARG DEBIAN_VERSION=buster-20240612-slim
ARG RELEASE_VERSION

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

ARG SELF_HOSTED=0

FROM ${BUILDER_IMAGE} AS builder

ARG SELF_HOSTED
ENV SELF_HOSTED=${SELF_HOSTED}
ARG RELEASE_VERSION
ENV RELEASE_VERSION=${RELEASE_VERSION}

RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs

RUN mkdir /app
WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV="prod"
ENV LANG=C.UTF-8
ENV ERL_FLAGS="+JPperf true"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

WORKDIR /app/assets
RUN npm install

WORKDIR /app
RUN mix assets.deploy
RUN mix compile

COPY config/runtime.exs config/
COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE} AS app

ARG SELF_HOSTED
ENV SELF_HOSTED=${SELF_HOSTED}
ARG RELEASE_VERSION
ENV RELEASE_VERSION=${RELEASE_VERSION}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates curl ssh jq telnet netcat htop \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN useradd --create-home app
WORKDIR /home/app
COPY --from=builder --chown=app /app/_build .

COPY .iex.exs .
COPY scripts/start_commands.sh /scripts/start_commands.sh

# Modification pour résoudre l'erreur exec format
RUN echo '#!/bin/sh' > /scripts/start_commands.sh.tmp && \
    cat /scripts/start_commands.sh >> /scripts/start_commands.sh.tmp && \
    mv /scripts/start_commands.sh.tmp /scripts/start_commands.sh && \
    chmod 755 /scripts/start_commands.sh

USER app
EXPOSE 4000

ENTRYPOINT ["sh", "/scripts/start_commands.sh"]
