locals {
  environments = merge(
    var.configure_development_environment ? { dev = {} } : {},
    var.configure_nonproduction_environment ? { qa = {} } : {},
    var.configure_production_environment ? { prod = {} } : {}
  )
}
