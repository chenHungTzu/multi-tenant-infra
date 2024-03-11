variable "input" {
  type = map(object({
    QuotaOffeset = number
    QuotaLimit   = number
    QuotaPeriod  = string
    BurstLimit   = number
    RateLimit    = number
  }))
  default = {
    
  }
}
variable "tags" {
  default = {
    "platform" : "terraform"
  }
}
