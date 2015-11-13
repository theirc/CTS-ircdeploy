{% import 'project/_vars.sls' as vars with context %}

include:
  - project.user
  - project.dirs
  - project.venv

# Helper to run a Django management command in the virtual environment
# Must not be world-readable, to protect passwords
manage:
  file.managed:
    - name: {{ vars.path_from_root('manage.sh') }}
    - source: salt://project/django/manage.sh
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - mode: 700
    - template: jinja
    - context:
        settings: "{{ pillar['project_name']}}.settings.{{ pillar['environment'] }}"
        environment: "{{ pillar['environment'] }}"
        virtualenv_root: "{{ vars.venv_dir }}"
        directory: "{{ vars.source_dir }}"
    - require:
      - pip: pip_requirements
      - file: project_path

# Helper to run a shell command in the virtual environment
# Must not be world-readable, to protect passwords
run_file:
  file.managed:
    - name: {{ vars.path_from_root('run.sh') }}
    - source: salt://project/django/run.sh
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - mode: 700
    - template: jinja
    - context:
        settings: "{{ pillar['project_name']}}.settings.{{ pillar['environment'] }}"
        environment: "{{ pillar['environment'] }}"
        virtualenv_root: "{{ vars.venv_dir }}"
        directory: "{{ vars.source_dir }}"
    - require:
      - pip: pip_requirements
      - file: project_path
