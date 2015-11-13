{% import 'project/_vars.sls' as vars with context %}

include:
  - project.user
  - project.dirs
  - project.venv

#
# Don't need dbbackup anymore
# Can remove this whole state once it's been removed from staging
# and production, but need this until then.
#
django-dbbackup:
  pip.removed:
#    - name: "django-dbbackup>=2.0.9"
    - name: "hg+https://bitbucket.org/scottm_caktus/django-dbbackup#egg=django-dbbackup"
    - bin_env: {{ vars.venv_dir }}
    - upgrade: true
    - require:
      - virtualenv: venv
      
  file.absent:
    - name: /etc/cron.d/dbbackup_{{ pillar['project_name'] }}
python-gnupg:
  pip.removed:
    - name: "python-gnupg>=0.3.6"
    - bin_env: {{ vars.venv_dir }}
    - upgrade: true
    - require:
      - virtualenv: venv

boto:
  pip.removed:
    - name: "boto>=2.34.0"
    - bin_env: {{ vars.venv_dir }}
    - upgrade: true
    - require:
      - virtualenv: venv

  file.absent:
    - name: /tmp/gpg.key
