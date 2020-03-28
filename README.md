## Terraform run
### Select proper SSH key for accessing nodes
- terraform apply -var "sshkey_name=$KEY"

## AWS EKS (features)
- EKS created in public network
- autoscaling group for workerk nodes (keeps desired nodes)

## Howto connect nodes
### Enable access node role
- kubectl apply -f aws-auth.yml
