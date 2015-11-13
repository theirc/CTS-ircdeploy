project_name: cts

python_version: 2.7

postgres_extensions: [postgis]

# Client postgres should match postgres version on the RDS server
postgres_version: 9.4

instances:
  turkey:
    name: Turkey
    prefix: /TR
    currency: TRY
    port: 8001
  iraq:
    name: Iraq
    prefix: /IQ
    currency: IQD
    port: 8002
  jordan:
    name: Jordan
    prefix: /JO
    currency: JOD
    port: 8003
