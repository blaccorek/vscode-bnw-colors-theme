# Variable values for the prod workspace.
region      = "eu-west-3"
environment = "prod"

instance_types = ["t3.medium", "t3.large"]

node_groups = {
  general = {
    min_size     = 3
    max_size     = 9
    desired_size = 4
    labels       = { workload = "general" }
  }
  spot = {
    min_size      = 0
    max_size      = 12
    desired_size  = 3
    capacity_type = "SPOT"
  }
}
