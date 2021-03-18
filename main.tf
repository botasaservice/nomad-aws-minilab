resource "aws_instance" "nomad-node" {
    count = var.nomad_node_count
    ami = var.nomad_node_ami_id
    instance_type = var.nomad_node_instance_size
    key_name = var.aws_key_name
    subnet_id = aws_subnet.nomad-lab-pub[count.index].id
    vpc_security_group_ids = [aws_security_group.nomad-sg.id]
    associate_public_ip_address = false
    user_data = file("conf/install-nomad.sh")
    private_ip = "10.0.${count.index}.100"

    tags = {
        Terraform = "true"
        ProvisionedBy = "Project Terra"
        Turbonomic = "true"
        Name = "nomad-node-${count.index}"
    }
}
# Sets up policy to allow for ecr reads.
resource "aws_iam_role_policy" "staging-client-docker_ecr_policy" {
    name = "nomad-client-docker_ecr_policy"
    role = "${module.staging_clients.iam_role_id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

