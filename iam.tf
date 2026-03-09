data "aws_caller_identity" "current" {}

/**
 * We either take the ARNs that have been explicitly configured as variables or the identity (i.e. principal) that is currently
 * executing Terraform.
 */
locals {
	principal_arns = var.principal_arns != null? var.principal_arns : [ aws_caller_identity.current.arn ]
}

/**
 * A role that allows the principal we've received or is executing us to assume this role with the policy we define below.
 * The connection is made with a "aws_iam_role_policy_attachment" resource.
 */
resource "aws_iam_role" "iam_role" {
	name = "${local.namespace}-tf-assume-role"
	assume_role_policy = <<-EOF
	{
		"Version" : "2012-10-17",
		"Statement" [
		{
			"Action" : "sts:AssumeRole"
			"Principal" : {
				"AWS" : ${jsonencode (local.principal_arns)}
			},
			"Effect" : "Allow"
		} ]
	}
	EOF
	
	tags = {
		ResourceGroup = local.namespace
	}
}

/**
 * This is the "least-privilege" policy that we're going to attach to the role. It allows:
 *   - To call ListBucket on the S3 Bucket.
 *   - To call GetObject, PutObject and DeleteObject on the S3 Bucket's root or below.
 *   - To call GetItem, PutItem and DeleteItem on the DynamoDB table.
 */
data "aws_iam_policy_document" "policy_doc" {
	statement {
		actions   = [ "s3:ListBucket" ]
		resources = [ aws_s3_bucket.s3_bucket.arn ]
	}
	statement {
		actions   = [ "s3:GetObject", "s3:PutObject", "s3:DeleteObject" ]
		resources = [ aws_s3_bucket.s3_bucket.arn ]
	}
	statement {
		actions   = [ "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem" ]
		resources = [ aws_dynamodb_table.dynamodb_table.arn ]
	}
}

/**
 * This is the policy with that allows the statements created above.
 */
resource "aws_iam_policy" "iam_policy" {
	name   = "${local.namespace}-tf-policy"
	path   = "/"
	policy = data.aws_iam_policy_document.policy_doc.json
}

/**
 * And here we attach the role that we let the principals we receive to "assume" with the "least privileges" policy.
 */
resource "aws_iam_role_policy_attachment" "policy_attach" {
	role       = aws_iam_role.iam_role.name
	policy_arn = aws_iam_policy.iam_policy.arn
}