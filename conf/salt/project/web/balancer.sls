{% import 'project/_vars.sls' as vars with context %}
{% set auth_file=vars.auth_file %}

include:
  - nginx
  - nginx.cert
  - ufw
  - project.dirs

http_firewall:
  ufw.allow:
    - names:
      - '80'
      - '443'
    - enabled: true

public_dir:
  file.directory:
    - name: {{ vars.public_dir }}
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - mode: 775
    - makedirs: True
    - require:
      - file: root_dir

ssl_dir:
  file.directory:
    - name: {{ vars.ssl_dir }}
    - user: root
    - group: www-data
    - mode: 644
    - makedirs: True
    - require:
      - file: root_dir

{% if 'ssl_key' in pillar and 'ssl_cert' in pillar %}
ssl_cert_file:
  file.managed:
    - name: {{ vars.build_path(vars.ssl_dir, pillar['domain'] + ".crt") }}
    - contents_pillar: ssl_cert
    - user: root
    - group: root
    - mode: 600
    - require:
      - file: ssl_dir

ssl_key_file:
  file.managed:
    - name: {{ vars.build_path(vars.ssl_dir, pillar['domain'] + ".key") }}
    - contents_pillar: ssl_key
    - user: root
    - group: root
    - mode: 600
    - require:
      - file: ssl_dir

# The margarita nginx state requires a 'cmd.run' state called 'ssl_cert'.  This is a dummy
# just to make it happy:
ssl_cert:
    cmd.run:
        - name: /bin/true

{% else %}
ssl_cert:
  cmd.run:
    - name: cd {{ vars.ssl_dir }} && /var/lib/nginx/generate-cert.sh {{ pillar['domain'] }}
    - cwd: {{ vars.ssl_dir }}
    - user: root
    - unless: test -e {{ vars.build_path(vars.ssl_dir, pillar['domain'] + ".crt") }}
    - require:
      - file: ssl_dir
      - file: generate_cert
{% endif %}

{% if 'http_auth' in pillar %}
apache2-utils:
  pkg:
    - installed

auth_file:
  cmd.run:
    - names:
{%- for key, value in pillar['http_auth'].items() %}
      - htpasswd {% if loop.first -%}-c{%- endif %} -bd {{ auth_file }} {{ key }} {{ value }}
{% endfor %}
    - require:
      - pkg: apache2-utils
      - file: root_dir

{{ auth_file }}:
  file.managed:
    - user: root
    - group: www-data
    - mode: 640
    - require:
      - file: root_dir
      - cmd: auth_file
{% endif %}

nginx_conf:
  file.managed:
    - name: /etc/nginx/sites-enabled/{{ pillar['project_name'] }}.conf
    - source: salt://project/web/site.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        public_root: "{{ vars.public_dir }}"
        log_dir: "{{ vars.log_dir }}"
        ssl_dir: "{{ vars.ssl_dir }}"
        domain: "{{ pillar['domain'] }}"
        servers:
          - '127.0.0.1'
        {%- if 'http_auth' in pillar %}
        auth_file: "{{ auth_file }}"
        {% endif %}
    - require:
      - pkg: nginx
      - file: log_dir
      - file: ssl_dir
      - cmd: ssl_cert
      {%- if 'http_auth' in pillar %}
      - cmd: auth_file
      {% endif %}
    - watch_in:
      - service: nginx
