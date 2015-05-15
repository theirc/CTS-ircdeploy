{% import 'project/_vars.sls' as vars with context %}

docserver-pkgs:
  pkg.installed:
    - pkgs:
      - texlive-latex-extra
      - texlive-fonts-recommended

# After collectstatic has been run, we can build our docs
build-docs:
  cmd.run:
    - name: {{ vars.root_dir }}run.sh docs/build.sh "{{ vars.public_dir }}/static/protected"
    - cwd: {{ vars.source_dir }}
    - user: {{ pillar['project_name'] }}
    - require:
      - cmd: collectstatic
