terraform {
  backend "s3" {
    bucket = "n8n-app-infrastructure-tf"
    key    = "terraform.tfstate"
    region = "us-west-2"
  }
}