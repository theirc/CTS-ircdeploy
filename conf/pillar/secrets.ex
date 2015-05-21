# This file should be renamed to secrets.sls in the relevant environment directory
secrets:
    DB_PASSWORD: XXXXXX
    newrelic_license_key: XXXXXX
# Uncomment if using celery worker configuration
#     BROKER_PASSWORD: XXXXXX

    # Iraq:
    ONA_DOMAIN_IQ: ona-staging.example.com
    ONA_API_ACCESS_TOKEN_IQ: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    ONA_PACKAGE_FORM_ID_IQ: 4
    ONA_DEVICEID_VERIFICATION_FORM_ID_IQ: 5

    # Jordan:
    ONA_DOMAIN_JO: ona-staging.example.com
    ONA_API_ACCESS_TOKEN_JO: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    ONA_PACKAGE_FORM_ID_JO: 4
    ONA_DEVICEID_VERIFICATION_FORM_ID_JO: 5

    # Turkey:
    ONA_DOMAIN_TR: ona-staging.example.com
    ONA_API_ACCESS_TOKEN_TR: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    ONA_PACKAGE_FORM_ID_TR: 4
    ONA_DEVICEID_VERIFICATION_FORM_ID_TR: 5

    DBBACKUP_S3_BUCKET: 'bucket-name'
    DBBACKUP_S3_ACCESS_KEY: 'AWS access-key'
    DBBACKUP_S3_SECRET_KEY: 'AWS secret-key'
    DBBACKUP_GPG_RECIPIENT: 'GPG user id (short hex string)'
    DBBACKUP_GPG_ALWAYS_TRUST: 'True'

instances:
  jordan:
    # If these are defined, allow readonly access to an instance's database
    # by the specified DB user, but only from the specified IP addresses
    #READONLY_DB_USER: XXXXXXXX
    #READONLY_DB_USER_PASSWORD: XXXXXXX
    #  Space-separated IP addresses to allow:
    #READONLY_DB_USER_IP_ADDRESSES: 127.0.1.2 127.0.1.3

# Uncomment and update username/password to enable HTTP basic auth
# http_auth:
#   username: password


github_deploy_key: |
  -----BEGIN RSA PRIVATE KEY-----
  foobar
  -----END RSA PRIVATE KEY-----


# Optional
# If either ssl_certificate or ssl_key are missing, a self-signed certificate
# will be generated.
# ssl_certificate: |
#     -----BEGIN CERTIFICATE-----
#     sample
#     -----END CERTIFICATE-----
#
# ssl_key: |
#     -----BEGIN PRIVATE KEY-----
#     sample
#     -----END PRIVATE KEY-----
