# EVM Production Plan

## Send-path acceptance
- [ ] Native and ERC-20 sends resolve a pending nonce before signing.
- [ ] Fee data and estimated gas are populated before signing.
- [ ] Display amounts convert safely into integer base units.
- [ ] RPC, signing, and broadcast errors have deterministic tests.

## History acceptance
- [ ] EVM history uses an indexer endpoint when configured.
- [ ] Missing indexer configuration returns documented behavior.
- [ ] Indexer response mapping handles malformed, pending, and paginated results.
- [ ] Indexer API keys are never logged or returned in errors.
