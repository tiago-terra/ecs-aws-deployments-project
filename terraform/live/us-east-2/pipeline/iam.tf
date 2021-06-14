data "aws_iam_policy_document" "this" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${local.project_name}_cicd_role"
  assume_role_policy = data.aws_iam_policy_document.this.json
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_user_policy_attachment" "this" {
  for_each   = toset(formatlist("arn:aws:iam::aws:policy/%s", local.policies_to_attach))
  user       = data.aws_caller_identity.current.account_id
  policy_arn = each.value
}
