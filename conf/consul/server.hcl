data_dir = "/tmp/consul/server"

server           = true
bootstrap_expect = 1
advertise_addr   = "{{ GetInterfaceIP `eth0` }}"
client_addr      = "0.0.0.0"
ui               = true
datacenter       = "dc-aws-1"
retry_join       = ["10.0.10.100", "10.0.11.100", "10.0.12.100"]
retry_max        = 10
retry_interval   = "15s"

acl = {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}
