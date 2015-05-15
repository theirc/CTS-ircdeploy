base:
  "*":
    - project
    - devs
  'environment:local':
    - match: grain
    - local
{% for env in ['staging', 'production', 'vagrant', 'testing'] %}
  'environment:{{ env }}':
    - match: grain
    - {{ env }}.env
    - {{ env }}.secrets
{% endfor %}
