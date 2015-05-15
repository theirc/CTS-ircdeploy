###########################################################################################
# common environment setup for running Django in our environment
if [ -z "$DJANGO_SETTINGS_MODULE" ] ; then
  export DJANGO_SETTINGS_MODULE='{{ settings }}'
fi
export ALLOWED_HOST='{{ pillar['domain'] }}'
export ENVIRONMENT='{{ environment }}'
{% for key, value in pillar.get('secrets', {}).items() + pillar.get('env', {}).items() %}
export {{ key }}='{{ value }}'
{% endfor %}
###########################################################################################
