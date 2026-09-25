# Build context: the repository root (the server depends on shared/).
#
#   docker build -f server/Dockerfile -t brewly-api .

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
FROM swift:6.2-noble AS build

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libjemalloc-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Resolve dependencies first so they are cached between builds.
COPY shared ./shared
COPY server/Package.* ./server/
RUN swift package --package-path server resolve

COPY server ./server
RUN swift build --package-path server -c release \
        --product BrewlyServer \
        --static-swift-stdlib \
        -Xlinker -ljemalloc

WORKDIR /staging
RUN cp "$(swift build --package-path /build/server -c release --show-bin-path)/BrewlyServer" ./ \
    && cp "/usr/libexec/swift/linux/swift-backtrace-static" ./ \
    && find -L "$(swift build --package-path /build/server -c release --show-bin-path)/" \
        -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
FROM ubuntu:noble

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y libjemalloc2 ca-certificates tzdata \
    && rm -r /var/lib/apt/lists/*

RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app brewly
WORKDIR /app
COPY --from=build --chown=brewly:brewly /staging /app

ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

USER brewly:brewly
EXPOSE 8080
ENTRYPOINT ["./BrewlyServer"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
