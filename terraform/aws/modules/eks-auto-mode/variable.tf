variable "project" {
  type = string
}

variable "iam_user" {
  type = string
}

variable "vpc" {
  type = object({
    id         = string
    subnet_ids = list(string)
  })
}
