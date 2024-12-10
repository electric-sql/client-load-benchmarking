ARG ELIXIR_VERSION=1.17.2
ARG OTP_VERSION=27.0.1
ARG DEBIAN_VERSION=bookworm-20240722-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

###############################################################
FROM ${BUILDER_IMAGE} AS builder
LABEL maintainer="info@electric-sql.com"

RUN apt-get update -y && \
    apt-get install -y build-essential git curl && \
    apt-get clean && \
    rm -f /var/lib/apt/lists/*_*

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

WORKDIR /app

COPY mix.* /app/
RUN mix deps.get
RUN mix deps.compile

# These are ordered by change frequency, with the least frequently changing dir first.
COPY rel /app/rel
COPY lib /app/lib/

COPY config/*runtime.exs /app/config/

ARG ELECTRIC_VERSION

RUN mix compile
RUN mix release

###############################################################
FROM ${RUNNER_IMAGE} AS runner_setup

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates curl && \
    apt-get clean && \
    rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

###############################################################
FROM runner_setup AS runner

ARG S6_OVERLAY_VERSION=3.2.0.2
ARG RELEASE_NAME=client_load
ARG VARNISH_BACKENDS

# ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
# RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
#
# ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
# RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz


## Vaxine configuration via environment variables
COPY --from=builder /app/_build/prod/rel/${RELEASE_NAME} ./
COPY script/entrypoint /app/entrypoint-wrapped
COPY script/rewrite-varnish-conf.sh /usr/local/bin/rewrite-varnish-conf.sh
# RUN mkdir -p /etc/varnish && /usr/local/bin/rewrite-varnish-conf.sh > /etc/varnish/default.vcl && rm -f /usr/local/bin/rewrite-varnish-conf.sh
RUN mv /app/bin/${RELEASE_NAME} /app/bin/entrypoint

# can't set ulimits directly, but can configure a user to have specific limits
# thanks: https://community.fly.io/t/how-to-set-ulimit-previous-solutions-not-working-anymore/19418

RUN useradd --no-create-home electric --shell /bin/bash && mkdir -p /home/electric && chown electric /home/electric
COPY --chmod=644 script/electric.conf /etc/security/limits.d/electric.conf

ENV CLIENT_COUNT="50000"

CMD ["su" , "-c", "/app/entrypoint-wrapped", "electric"]
