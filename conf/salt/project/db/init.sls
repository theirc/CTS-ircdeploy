{% import 'project/_vars.sls' as vars with context %}

include:
  - postgresql
  - ufw


{% for instance in salt['pillar.get']('instances') %}
# If these lines change, change cts/settings/staging.py and fabfile.py.
{% set username = pillar['project_name'] + '_' + instance %}
{% set dbname =  pillar['project_name'] + '_' + instance %}

user-{{ instance }}:
  postgres_user.present:
    - name: {{ username }}
    - createdb: False
    - createuser: False
    - superuser: False
    - password: {{ pillar['secrets']['DB_PASSWORD'] }}
    - encrypted: True
    - require:
      - service: postgresql

# If these parameters change, also change the CREATEDB command in
# fabfile.py's db_restore task.
database-{{ dbname }}:
  postgres_database.present:
    - name: {{ dbname }}
    - owner: {{ username }}
    - template: template0
    - encoding: UTF8
    - lc_collate: en_US.UTF-8
    - lc_ctype: en_US.UTF-8
    - require:
      - postgres_user: user-{{ instance }}
      - file: hba_conf
      - file: postgresql_conf

# Does this instance need a readonly user?
{% if salt['pillar.get']('instances:%s:READONLY_DB_USER' % instance, False) %}
{% set readonly_user = salt['pillar.get']('instances:%s:READONLY_DB_USER' % instance) %}
{% set readonly_user_ips = salt['pillar.get']('instances:%s:READONLY_DB_USER_IP_ADDRESSES' % instance) %}
{% set readonly_user_password = salt['pillar.get']('instances:%s:READONLY_DB_USER_PASSWORD' % instance) %}
readonly-user-{{ instance }}:
  postgres_user.present:
    - name: {{ readonly_user }}
    - createdb: False
    - createuser: False
    - superuser: False
    - password: {{ readonly_user_password }}
    - encrypted: True
    - require:
      - service: postgresql
# The postgres_user salt module won't change the password if the user already exists.
# Set it unconditionally in case we've changed it in our settings.
readonly-user-password-{{ instance }}:
  cmd.run:
    - name: psql -c "ALTER USER {{ readonly_user }} WITH PASSWORD '{{ readonly_user_password }}'";
    - user: postgres
    - require:
      - postgres_user: readonly-user-{{ instance }}
# Give privs on the DB to the user
grant-readonly-connect-{{ instance }}:
  cmd.run:
    - name: psql -c "GRANT CONNECT ON DATABASE {{ dbname }} TO {{ readonly_user }};"
    - user: postgres
    - require:
      - postgres_user: readonly-user-{{ instance }}
      - postgres_database: database-{{ dbname }}
grant-readonly-select-{{ instance }}:
  cmd.run:
    - name: psql -c "GRANT SELECT ON ALL TABLES IN SCHEMA PUBLIC TO {{ readonly_user }};" {{ dbname }}
    - user: postgres
    - require:
      - postgres_user: readonly-user-{{ instance }}
      - postgres_database: database-{{ dbname }}
# Open the ufw firewall from the incoming addresses on the postgres port
{% for ip_address in readonly_user_ips.split() %}
db_allow-readonly-db-{{ instance }}-{{ ip_address }}:
  ufw.allow:
    - name: '5432'
    - enabled: true
    - from: {{ ip_address }}
    - require:
      - pkg: ufw
{% endfor %}
{% endif %}
{% endfor %}


hba_conf:
  file.managed:
    - name: /etc/postgresql/9.1/main/pg_hba.conf
    - source: salt://project/db/pg_hba.conf
    - user: postgres
    - group: postgres
    - mode: 0640
    - template: jinja
    - context:
        servers:
          - 127.0.0.1
    - require:
      - pkg: postgresql
      - cmd: /var/lib/postgresql/configure_utf-8.sh
    - watch_in:
      - service: postgresql

postgresql_conf:
  file.managed:
    - name: /etc/postgresql/9.1/main/postgresql.conf
    - source: salt://project/db/postgresql.conf
    - user: postgres
    - group: postgres
    - mode: 0644
    - template: jinja
    - require:
      - pkg: postgresql
      - cmd: /var/lib/postgresql/configure_utf-8.sh
    - watch_in:
      - service: postgresql

{% for host, ifaces in salt['mine.get']('roles:web|worker', 'network.interfaces', expr_form='grain_pcre').items() %}
{% set host_addr = vars.get_primary_ip(ifaces) %}
db_allow-{{ host }}-{{ host_addr }}:
  ufw.allow:
    - name: '5432'
    - enabled: true
    - from: {{ host_addr }}
    - require:
      - pkg: ufw
{% endfor %}


{% if 'postgis' in pillar['postgres_extensions'] %}
ubuntugis:
  pkgrepo.managed:
    - humanname: UbuntuGIS PPA
    - ppa: ubuntugis/ppa
    - require_in:
        - pkg: postgis-packages

postgis-packages:
  pkg:
    - installed
    - names:
      - postgresql-9.1-postgis-2.0
    - require:
      - pkgrepo: ubuntugis
      - pkg: db-packages
    - require_in:
      - virtualenv: venv
{% endif %}

{% for instance in salt['pillar.get']('instances') %}
{% set db_name = pillar['project_name'] + '_' + instance %}
{% for extension in pillar['postgres_extensions'] %}
create-{{ extension }}-extension-{{ instance }}:
  cmd.run:
    - name: psql -U postgres {{ db_name }} -c "CREATE EXTENSION postgis; GRANT ALL ON geometry_columns TO PUBLIC; GRANT ALL ON spatial_ref_sys TO PUBLIC; GRANT ALL ON geography_columns TO PUBLIC;"
    - unless: psql -U postgres {{ db_name }} -c "\dx+" | grep postgis
    - user: postgres
    - require:
      - pkg: postgis-packages
      - postgres_database: database-{{ db_name }}
    - require_in:
      - virtualenv: venv
{% endfor %}

create-hstore-extension-{{ instance }}:
  cmd.run:
    - name: psql -U postgres {{ db_name }} -c "CREATE EXTENSION hstore;"
    - unless: psql -U postgres {{ db_name }} -c "\dx+" | grep hstore
    - user: postgres
    - require:
      - postgres_database: database-{{ db_name }}
    - require_in:
      - virtualenv: venv
{% endfor %}

# For migrating
mysql-packages:
  pkg.installed:
    - pkgs:
        - mysql-client
        - mysql-server
        - libmysqlclient-dev

mysql-service:
  service:
    - running
    - name: mysql
    - require:
      - pkg: mysql-packages
