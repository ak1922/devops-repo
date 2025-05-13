locals {
  project_tags = {
    managed_by = "Terraform"
    gitrepo    = "devops-repo"
    gitbranch  = "flaskapp-autoscaling"
    app        = "keybridge"
  }
}

locals {
  now       = timestamp()
  today     = formatdate("YYYY-MM-DD", local.now)
  downscale = "${local.today}T22:00:00Z"
  upscale   = timeadd(local.downscale, "10h")
}
