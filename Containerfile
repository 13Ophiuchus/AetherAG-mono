FROM swift:6.2-noble AS builder
WORKDIR /mono
COPY AGWallet ./AGWallet
COPY AetherShared ./AetherShared
COPY solana-swift-concurrency ./solana-swift-concurrency
COPY web3swift-concurrency ./web3swift-concurrency
COPY AetherAG/Package.swift ./AetherAG/Package.swift
COPY AetherAG/Package.resolved ./AetherAG/Package.resolved
WORKDIR /mono/AetherAG
RUN swift package resolve
COPY AetherAG/Sources ./Sources
COPY AetherAG/Resources ./Resources
COPY AetherAG/Tests ./Tests
RUN swift build -c release --product AetherAGMailServerRun
FROM ubuntu:24.04
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libssl3 libz-dev libsqlite3-0 ca-certificates curl && rm -rf /var/lib/apt/lists/*
COPY --from=builder /mono/AetherAG/.build/release/AetherAGMailServerRun ./AetherAGMailServerRun
COPY --from=builder /mono/AetherAG/Public ./Public
COPY --from=builder /mono/AetherAG/Resources ./Resources
EXPOSE 8080
ENTRYPOINT ["./AetherAGMailServerRun", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
