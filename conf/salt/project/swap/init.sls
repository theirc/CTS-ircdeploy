# Add swap on EC2 instance if we have the appropriate disk attached

{% set DEVICE = '/dev/xvdb' %}

# Don't mount it
dont_mount_swap:
  file.replace:
    - name: /etc/fstab
    - pattern: "^({{ DEVICE }}.*)$"
    - repl: "# \\1"

# Use EC2 device as swap
swap_service:
  file.managed:
    - name: /etc/init.d/ec2_swap
    - source: salt://project/swap/initfile.j2
    - mode: 0555
    - template: jinja
    - context:
        DEVICE: '/dev/xvdb'
link_ec2_swap_init_file:
  cmd.run:
    - name: /usr/sbin/update-rc.d ec2_swap defaults
    - requires:
        - file: swap_service
run_ec2_swap_init_file:
  cmd.run:
    - name: /usr/sbin/invoke-rc.d ec2_swap start
    - requires:
        - cmd: link_ec2_swap_init_file
