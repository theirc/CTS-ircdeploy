{% import 'project/_vars.sls' as vars with context %}

include:
  - supervisor.pip
  - project.dirs
  - project.venv
  - postfix
  - project.queue
  - project.web.app

{% for instance in salt['pillar.get']('instances') %}
{{ instance }}_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-celery-{{ instance }}.conf
    - source: salt://project/worker/celery.conf
    - user: root
    - group: root
    - mode: 600
    - template: jinja
    - context:
        newrelic_config_file: "{{ vars.services_dir }}/newrelic-app.ini"
        settings: "{{ pillar['project_name'] }}.settings.{{ instance }}"
        virtualenv_root: "{{ vars.venv_dir }}"
        directory: "{{ vars.source_dir }}"
        name: "celery-{{ instance }}"
        command: "worker"
        flags: "--loglevel=INFO -Q queue_{{ instance }} --concurrency=2"
    - require:
      - pip: supervisor
      - pip: pip_requirements
    - watch_in:
      - cmd: supervisor_update

{{ instance }}_process:
  supervisord.running:
    - name: {{ pillar['project_name'] }}-celery-{{ instance }}
    - restart: True
    - require:
      - file: {{ instance }}_conf

{% endfor %}
