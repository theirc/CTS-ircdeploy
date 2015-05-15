base:
  '*':
    - base
    - sudo
    - sshd
    - sshd.github
    - locale.utf8
    - project.devs
    - salt.minion
    - newrelic_sysmon
    - project.broker
    - project.web.app
    - project.newrelic_webmon
    - project.worker.default
    - project.worker.beat
    - project.web.balancer
    - project.nginx
    - project.docserver
    - project.db
    - project.queue
    - project.cache
    - project.swap
    - django-dbbackup
  'precise32':
    - vagrant.user
