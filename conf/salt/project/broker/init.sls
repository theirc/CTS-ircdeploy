include:
  - rabbitmq

# Each instance has its own data, so needs its own broker user/queues etc.
{% for instance in salt['pillar.get']('instances') %}
{% set username = pillar['project_name'] + "_" + instance %}
broker-user-{{ username }}:
  rabbitmq_user.present:
    - name: {{ username }}
    - password: {{ pillar.get('secrets', {}).get('BROKER_PASSWORD') }}
    - force: True
    - require:
      - service: rabbitmq-server

broker-vhost-{{ username }}:
  rabbitmq_vhost.present:
    - name: {{ username }}
    - user: {{ username }}
    - require:
      - rabbitmq_user: broker-user-{{ username }}
{% endfor %}
