# Retrieve User/Role
data "aws_iam_user" "main" {
  user_name = var.user_name
}
# Retrieve service role
data "aws_iam_role" "main" {
  name = var.role_name
}
# Retrieve k8s role
data "aws_iam_role" "deploy_role" {
  name = "k8srole"
}

# Create EKSAdmin policy
data "aws_iam_policy_document" "eks_admin" {
  statement {
    actions = ["eks:*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_admin" {
  name        = "AmazonEKSAdminPolicy"
  path        = "/"
  description = "EKS Administrator policy"
  policy = data.aws_iam_policy_document.eks_admin.json
}

locals {
  deploy_policies = concat(var.policies, [aws_iam_policy.eks_admin.arn])
}

# IAM role - attach role policies
resource "aws_iam_role_policy_attachment" "service_role" {
  count      = length(local.deploy_policies)
  role       = data.aws_iam_role.main.name
  policy_arn = element(local.deploy_policies, count.index)
}

# IAM role - attach role policies
resource "aws_iam_role_policy_attachment" "deploy_role" {
  count      = length(local.deploy_policies)
  role       = data.aws_iam_role.deploy_role.name
  policy_arn = element(local.deploy_policies, count.index)
}

# Attach IAM User build_policies
resource "aws_iam_user_policy_attachment" "user_attachment" {
  count      = length(local.deploy_policies)
  user       = data.aws_iam_user.main.user_name
  policy_arn = element(local.deploy_policies, count.index)
}

# IAM User - attach public key
resource "aws_iam_user_ssh_key" "main" {
  username   = data.aws_iam_user.main.user_name
  encoding   = "SSH"
  public_key = var.public_key

  provisioner "local-exec" {
    command = "git remote set-url aws ssh://${self.ssh_public_key_id}@${trimprefix(aws_codecommit_repository.main.clone_url_ssh,"ssh://")}"
  }
  depends_on = [aws_codecommit_repository.main]
}