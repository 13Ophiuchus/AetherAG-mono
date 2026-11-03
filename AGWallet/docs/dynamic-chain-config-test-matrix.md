# Dynamic Chain Configuration Test Matrix

- [ ] Add a valid custom chain and retrieve it.
- [ ] Reject a duplicate chain identifier.
- [ ] Update an existing custom chain.
- [ ] Reject updates to an unknown chain.
- [ ] Remove an existing custom chain.
- [ ] Reject removal of an unknown chain.
- [ ] Persist custom chains across service instances.
- [ ] Keep predefined chains immutable/unaffected by custom mutations.
- [ ] Select RPC, indexer, and broadcast endpoints by role.
- [ ] Reject non-HTTPS production endpoints unless explicitly allowed for local development.
- [ ] Switch active network without mutating other network endpoint sets.
