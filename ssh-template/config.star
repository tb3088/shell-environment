#host *		implied by caller
  # since AWS hosts auto-scale/relaunch, 'no' is permissible
  # though use of HostKeyAlias is strongly suggested
  StrictHostKeyChecking ask
  HashKnownHosts yes
  #  CheckHostIP no

  ForwardAgent no
  GatewayPorts no

  ServerAliveInterval 90
  ServerAliveCountMax 5

  User ec2-user
  ProxyCommand ${SSH:-ssh} ${SSH_CONFIG:+ -F "$SSH_CONFIG"} ${SSH_KNOWN_HOSTS:+ -o UserKnownHostsFile="$SSH_KNOWN_HOSTS"} -W %h:%p relay${REGION:+.$REGION}.direct
