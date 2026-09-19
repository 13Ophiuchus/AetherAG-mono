FROM swift:6.2-jammy AS build
ARG CACHE_BUST=1
WORKDIR /build
COPY . .
WORKDIR /build/AetherAG
RUN git config --global http.lowSpeedLimit 0 && \
    git config --global http.lowSpeedTime 999999 && \
    git config --global http.postBuffer 524288000
RUN --mount=type=cache,target=/root/.cache/org.swift.swiftpm \
    --mount=type=cache,target=/build/AetherAG/.build \
    echo "cache bust: ${CACHE_BUST}" && \
    for i in 1 2 3; do \
        swift package resolve && break || { echo "Resolve attempt $i failed, retrying in 10s..."; sleep 10; }; \
    done
RUN --mount=type=cache,target=/root/.cache/org.swift.swiftpm \
    --mount=type=cache,target=/build/AetherAG/.build \
    swift build -c release --product AetherAGMailServerRun

FROM swift:6.2-jammy-slim
WORKDIR /app
COPY --from=build /build/AetherAG/.build/release/AetherAGMailServerRun ./
COPY --from=build /build/AetherAG/Public ./Public
COPY --from=build /build/AetherAG/Resources ./Resources
EXPOSE 8080
ENTRYPOINT ["./AetherAGMailServerRun"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
