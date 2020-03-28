# Terraform run
- provide -var "sshkey_name=$KEY"

# AWS EKS (features)
- EKS created in public network
- autoscaling group for workerk nodes (keeps desired nodes)

# Howto connect nodes
- kubectl apply -f aws-auth.yml
