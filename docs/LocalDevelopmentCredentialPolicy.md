# Local Development Credential Policy

Tracked connection strings are permitted only for isolated local development or
ephemeral CI services.

A tracked connection string is allowed only when all conditions are true:

- Its host is `127.0.0.1`, `localhost`, a Docker Compose service name, or an
  ephemeral CI service container.
- It is not valid for production, staging, or any externally reachable system.
- Production and staging credentials are provided only by the deployment
  platform's secret manager or CI secret store.
- It contains no wallet mnemonic, private key, bearer token, API key, signing
  key, certificate, or cloud credential.

Any finding outside these conditions blocks release until removed and rotated.
