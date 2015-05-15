# Shell script to setup necessary environment variables and run a management command

{% include 'project/django/venv_setup.sh' %}

cd {{ directory }}
{{ virtualenv_root }}/bin/python {{ directory }}/manage.py $@
