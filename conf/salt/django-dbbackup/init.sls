{% import 'project/_vars.sls' as vars with context %}

include:
  - project.user
  - project.dirs
  - project.venv

django-dbbackup:
  pip.installed:
#    - name: "django-dbbackup>=2.0.9"
    - name: "hg+https://bitbucket.org/scottm_caktus/django-dbbackup#egg=django-dbbackup"
    - bin_env: {{ vars.venv_dir }}
    - upgrade: true
    - require:
      - virtualenv: venv
      
  file.managed:
    - name: /etc/cron.d/dbbackup_{{ pillar['project_name'] }}
    - source: salt://django-dbbackup/cron.d
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - context:
      project_name: "{{ pillar['project_name'] }}"
      environment: "{{ pillar['environment'] }}"
      domain: "{{ pillar['domain'] }}"
      
#{% for instance in salt['pillar.get']('instances') %}
#set_db_privilages_{{instance}}:
#  cmd.run:
#    - name: psql cts_{{ instance }} -c 'GRANT SELECT ON spatial_ref_sys TO cts_{{ instance }};'
#    - user: postgres
#{% endfor %}

python-gnupg:
  pip.installed:     
    - name: "python-gnupg>=0.3.6"
    - bin_env: {{ vars.venv_dir }}
    - upgrade: true
    - require:
      - virtualenv: venv
  pkg:
    - installed
    - names:
      - gnupg
      - gpgv 
      
boto:
  pip.installed:
    - name: "boto>=2.34.0"
    - bin_env: {{ vars.venv_dir }}
    - upgrade: true
    - require:
      - virtualenv: venv
      
setup_gpg_key:
  cmd.run:
    - name: gpg --homedir {{ vars.root_dir }} --import /tmp/gpg.key
    - user: {{ pillar['project_name'] }}
    - require:
      - file: /tmp/gpg.key
      
  file.managed:
    - name: /tmp/gpg.key
    - source: salt://django-dbbackup/gpg.key
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - mode: 755
