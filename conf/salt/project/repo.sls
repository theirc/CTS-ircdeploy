{% import 'project/_vars.sls' as vars with context %}
include:
  - project.dirs
  - project.user
  - version-control
  - sshd.github

{% if 'github_deploy_key' in pillar %}
project_repo_identity:
  file.managed:
    - name: "{{ vars.ssh_dir }}github"
    - contents_pillar: github_deploy_key
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - mode: 600
    - require:
      - user: project_user
      - file: ssh_dir
{% endif %}

project_repo:
  git.latest:
    - name: "{{ pillar['repo']['url'] }}"
    - rev: "{{ pillar['repo'].get('branch', 'master') }}"
    - target: {{ vars.source_dir }}
    - user: {{ pillar['project_name'] }}
    - always_fetch: true
    {% if 'github_deploy_key' in pillar %}
    - identity: "/home/{{ pillar['project_name'] }}/.ssh/github"
    {% endif %}
    - require:
      - file: root_dir
      - pkg: git-core
      {% if 'github_deploy_key' in pillar %}
      - file: project_repo_identity
      {% endif %}
      - ssh_known_hosts: github.com
