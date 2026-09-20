FROM swift:6.2-jammy AS build
WORKDIR /build
COPY . .
WORKDIR /build/AetherAG
RUN git config --global http.lowSpeedLimit 0 && \
    git config --global http.lowSpeedTime 999999 && \
    git config --global http.postBuffer 524288000
RUN --mount=type=cache,target=/root/.cache/org.swift.swiftpm \
    --mount=type=cache,target=/build/AetherAG/.build \
    rm -rf /build/AetherAG/.build/checkouts/flow-swift-macos && \
    rm -rf /root/.cache/org.swift.swiftpm/repositories/flow-swift-macos-* && \
    for i in 1 2 3; do \
        swift package resolve && break || { echo "Resolve attempt $i failed, retrying in 10s..."; sleep 10; }; \
    done
RUN --mount=type=cache,target=/root/.cache/org.swift.swiftpm \
    --mount=type=cache,target=/build/AetherAG/.build \
    swift build -c release --product AetherAGMailServerRun && \
    mkdir -p /build/output && \
    cp /build/AetherAG/.build/release/AetherAGMailServerRun /build/output/ && \
    cp -r /build/AetherAG/Public /build/output/Public && \
    mkdir -p /build/output/Resources && \
    if [ -d /build/AetherAG/Resources ]; then \
        cp -a /build/AetherAG/Resources/. /build/output/Resources/; \
    fi

FROM swift:6.2-jammy-slim
WORKDIR /app
COPY --from=build /build/output/AetherAGMailServerRun ./
COPY --from=build /build/output/Public ./Public
COPY --from=build /build/output/Resources ./Resources
EXPOSE 8080
ENTRYPOINT ["./AetherAGMailServerRun"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
