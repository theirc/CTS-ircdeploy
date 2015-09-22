# REMOVE postgres server (not client) if present
postgres-packages:
  pkg.removed:
    - names:
      - postgresql-9.1
      - postgresql-contrib-9.1
      - postgresql-server-dev-9.1
      - postgresql-contrib-9.3
      - postgresql-server-dev-9.3
