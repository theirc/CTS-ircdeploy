{% import 'project/_vars.sls' as vars with context %}

include:
  - supervisor.pip
  - project.dirs
  - project.venv
  - project.django
  - postfix
  - ufw

{% for instance in salt['pillar.get']('instances') %}
log_dir_{{ instance }}:
  file.directory:
    - name: {{ vars.log_dir }}/{{ instance }}
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - mode: 775
    - makedirs: True
    - require:
      - file: log_dir

gunicorn_{{ instance }}_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-{{ instance }}-gunicorn.conf
    - source: salt://project/web/gunicorn.conf
    - user: root
    - group: root
    - mode: 600
    - template: jinja
    - context:
        log_dir: "{{ vars.log_dir }}/{{ instance }}"
        instance: {{ instance }}
        newrelic_config_file: "{{ vars.services_dir }}/newrelic-app.ini"
        settings: "{{ pillar['project_name'] }}.settings.{{ instance }}"
        virtualenv_root: "{{ vars.venv_dir }}"
        directory: "{{ vars.source_dir }}"
        name: {{ pillar['project_name'] }}-{{ instance }}-server
        port: {{ salt['pillar.get']('instances:' + instance + ':port') }}
    - require:
      - pip: supervisor
      - pip: pip_requirements

gunicorn_{{ instance }}_process:
  supervisord.running:
    - name: {{ pillar['project_name'] }}-{{ instance }}-server
    - restart: True
    - require:
      - file: gunicorn_{{ instance }}_conf
      - file: log_dir_{{ instance }}

migrate_{{ instance }}:
  cmd.run:
    - name: "{{ vars.path_from_root('manage.sh') }} migrate --noinput"
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - env:
        DJANGO_SETTINGS_MODULE: "{{ pillar['project_name'] }}.settings.{{ instance }}"

bootstrap_permissions_{{ instance }}:
  cmd.run:
    - name: "{{ vars.path_from_root('manage.sh') }} bootstrap_permissions"
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - require:
      - cmd: migrate_{{ instance }}
    - env:
        DJANGO_SETTINGS_MODULE: "{{ pillar['project_name'] }}.settings.{{ instance }}"
{% endfor %}

# We only need to run collectstatic once, but it needs to be
# told some instance; just use the first one.
{% set instance = salt['pillar.get']('instances').keys()[0] %}
collectstatic:
  cmd.run:
    - name: "{{ vars.path_from_root('manage.sh') }} collectstatic --noinput"
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - env:
        DJANGO_SETTINGS_MODULE: "{{ pillar['project_name'] }}.settings.{{ instance }}"
    - require:
      - file: manage

node_ppa:
  pkgrepo.managed:
    - ppa: chris-lea/node.js
    - require_in:
        pkg: nodejs

nodejs:
  pkg.installed:
    - require:
      - pkgrepo: node_ppa
    - refresh: True

less:
  cmd.run:
    - name: npm install less@1.5.1 -g
    - user: root
    - unless: "which lessc && lessc --version | grep 1.5.1"
    - require:
      - pkg: nodejs
