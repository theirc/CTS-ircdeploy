{% import 'project/_vars.sls' as vars with context %}

include:
  - supervisor.pip
  - project.dirs
  - project.venv

{% for instance in salt['pillar.get']('instances') %}
beat_{{ instance }}_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-celery-beat-{{ instance }}.conf
    - source: salt://project/worker/celery.conf
    - user: root
    - group: root
    - mode: 600
    - template: jinja
    - context:
        settings: "{{ pillar['project_name'] }}.settings.{{ instance }}"
        virtualenv_root: "{{ vars.venv_dir }}"
        newrelic_config_file: "{{ vars.services_dir }}/newrelic-app.ini"
        directory: "{{ vars.source_dir }}"
        name: "celery-beat-{{ instance }}"
        command: "beat"
        flags: "--schedule={{ vars.path_from_root('celerybeat-' + instance + '-schedule.db') }} --pidfile={{ vars.path_from_root('celerybeat-' + instance + '.pid') }} --loglevel=INFO"
    - require:
      - pip: supervisor
      - pip: pip_requirements
    - watch_in:
      - cmd: supervisor_update

beat_{{ instance }}_process:
  supervisord.running:
    - name: {{ pillar['project_name'] }}-celery-beat-{{ instance }}
    - restart: True
    - require:
      - file: beat_{{ instance }}_conf
{% endfor %}
