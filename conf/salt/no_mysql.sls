# REMOVE mysql server AND client if present
mysql-packages:
  pkg.removed:
    - pkgs:
        - mysql-client
        - mysql-client-5.5
        - mysql-client-core-5.5
        - libmysqlclient-dev
        - libmysqlclient18
        - mysql-server
        - mysql-server-5.5
        - mysql-server-core-5.5
        - mysql-common
