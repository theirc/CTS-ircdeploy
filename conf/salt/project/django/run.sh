# Shell script to setup necessary environment variables and run a shell command
# E.g.
#    path/to/run.sh ls -l
#
. {{ virtualenv_root }}/bin/activate
{% include 'project/django/venv_setup.sh' %}
"$@"
