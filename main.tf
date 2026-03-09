data "aws_region" "current" {}

/**
 * A random string of 24 characters so that we can generate truly unique names for the resouces.
 */
resource "random_string" "rand" {
	length  = 24
	special = false
	upper   = false
}

/**
 * a namespace that includes what we've received and concatenates random characters of the random string above up until 24 characters.
 */
locals {
	namespace = substr (join ("-", [ var.namespace, random_string.rand ]), 0, 24)
}

/**
 * An AWS Resource Group to have everything accessible by name.
 */
resource "aws_resource_groups" "resourcegroup" {
	name = "${local.namespace}-rgroup"
	
	resource_query {
		query = <<-JSON
		{
			"ResourceTypeFilters" : [ "AWS::AllSupported" ],
			"TagFilters" : [ { "Key" : "ResourceGroup", "Values" : [ "${local.namespace}" ] } ]
		}
		JSON
	}
}

/**
 * An AWS KMS key to encrypt data at rest on the S3 Bucket.
 */
resource "aws_kms_key" "kms_key" {
	tags = {
		ResourceGroup = local.namespace
	}
}

/**
 * An AWS S3 Bucket with versioning and encryption at rest to store and version the state files.
 */
resource "aws_s3_bucket" "s3_bucket" {
	bucket        = "${local.namespace}-state-bucket"
	force_destroy = var.force_destroy_state
	
	versioning {
		enabled : true
	}
	
	server_side_encryption_configuration {
		rule {
			apply_server_side_encryption_by_default {
				sse_algorithm="aws:kms"
				kms_master_key_id = aws_kms_key.kms_key.arn
			}
		}
	}
	
	tags = {
		ResourceGroup = local.namespace
	}
}

/**
 * This is configured to avoid public access to the bucket:
 *   - BlockPublicAcls: We don't let calling PutBucketAcl or PutObjectAcl if the ACL is public and we don't accept PutObject / PutBucket 
 *                      actions if the request includes a public ACL.
 *   - BlockPublicPolicy: Rejects calls to PutBucketPolicy if the policy allows public access.
 *   - IgnorePublicAcls: We ignore any public ACL on the bucket or any of the objects it contains.
 *   - RestrictPublicBuckets : Restrict access with a public policy to service principals and authorized users of the owner's account.
 */
resource "aws_s3_bucket_public_access_block" "s3_bucket" {
	bucket = aws_s3_bucket.s3_bucket.id
	
	block_public_acls       = true
	block_public_policy     = true
	ignore_public_acls      = true
	restrict_public_buckets = true
}

/**
 * A DynamoDB table to store the locks on the state files.
 * Setting "billing_mode" to "PAY_PER_REQUEST" creates a "serverless" database rather than a provisioned one.
 */
resouce "aws_dynamodb_table" "dynamodb_table" {
	name = "${local.namespace}-state-lock"
	hash_key = "LockID"
	billing_mode = "PAY_PER_REQUEST"
	attribute {
		name = "LockID"
		type = "S"
	}
	tags = {
		ResourceGroup = local.namespace
	}
}