variable "input" {
  type = map(object({
    QuotaOffeset = number
    QuotaLimit   = number
    QuotaPeriod  = string
    BurstLimit   = number
    RateLimit    = number
  }))
}
variable "tags" {
  default = {
    "platform" : "terraform"
  }
}
