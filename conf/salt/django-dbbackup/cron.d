{% for instance in salt['pillar.get']('instances') %}
{% set minute =  loop.index * 12  %}

{{minute}} 0 * * *    {{ project_name }} /var/www/{{ project_name }}/manage.sh dbbackup --encrypt --settings=cts.settings.{{ instance }}

{% endfor %}
