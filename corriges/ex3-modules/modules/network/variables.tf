variable "name" {
  description = "Préfixe des noms (tag Name)"
  type        = string
}

variable "cidr_block" {
  description = "Plage CIDR (Classless Inter-Domain Routing) du VPC"
  type        = string
}

variable "subnets" {
  description = "Sous-réseaux indexés par une clé stable (jamais une position)"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
}

variable "https_ingress_cidrs" {
  description = "Plages autorisées en HTTPS (port 443) entrant"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
