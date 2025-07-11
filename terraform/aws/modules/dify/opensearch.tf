resource "aws_opensearchserverless_vpc_endpoint" "dify" {
  name       = "${var.project}-dify"
  subnet_ids = var.vpc.private_subnet_ids
  vpc_id     = var.vpc.id
}

resource "aws_opensearchserverless_security_policy" "dify_encryption" {
  name        = "${var.project}-dify-encryption"
  type        = "encryption"
  description = "encryption security policy for ${var.project}-dify"
  policy = jsonencode({
    "Rules" = [
      {
        "Resource" = [
          "collection/${var.project}-dify"
        ],
        "ResourceType" = "collection"
      }
    ],
    "AWSOwnedKey" = true
  })
}

resource "aws_opensearchserverless_security_policy" "dify_network" {
  name        = "${var.project}-dify-network"
  type        = "network"
  description = "VPC access"
  policy = jsonencode([
    {
      Description = "VPC access to collection and Dashboards endpoint for ${var.project}-dify collection",
      Rules = [
        {
          ResourceType = "collection",
          Resource = [
            "collection/${var.project}-dify"
          ]
        },
        {
          ResourceType = "dashboard"
          Resource = [
            "collection/${var.project}-dify"
          ]
        }
      ],
      AllowFromPublic = false,
      SourceVPCEs = [
        aws_opensearchserverless_vpc_endpoint.dify.id
      ]
    }
  ])
}

resource "aws_opensearchserverless_access_policy" "dify" {
  name        = "${var.project}-dify"
  description = "access policy for ${var.project}-dify collection"
  type        = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index",
          Resource = [
            "index/${var.project}-dify/*"
          ],
          Permission = [
            "aoss:*"
          ]
        }
      ],
      Principal = [
        aws_iam_role.ecs_app.arn,
        aws_iam_role.ecs_web.arn
      ]
    }
  ])
}

resource "aws_opensearchserverless_collection" "dify" {
  name = "${var.project}-dify"

  depends_on = [aws_opensearchserverless_security_policy.dify_encryption]
}
