data_dir = "/tmp/nomad/server"

server {
  enabled          = true
  bootstrap_expect = 3
  job_gc_threshold = "2m"
  server_join {
    retry_join = ["10.0.10.100", "10.0.11.100", "10.0.12.100"]
    retry_max = 10
    retry_interval = "15s"
  }
}

datacenter = "dc-aws-1"
region = "region-aws-1"

advertise {
  http = "{{ GetInterfaceIP `eth0` }}"
  rpc  = "{{ GetInterfaceIP `eth0` }}"
  serf = "{{ GetInterfaceIP `eth0` }}"
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

client {
  enabled           = true
  network_interface = "eth0"
  servers           = ["10.0.10.100", "10.0.11.100", "10.0.12.100"]
}

acl {
  enabled = false
}

plugin "docker" {
  config {
    auth {
      # Nomad will prepend "docker-credential-" to the helper value and call
      # that script name.
      helper = "ecr-login"
    }
  }
}
