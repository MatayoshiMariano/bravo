require 'bravo'
require 'pp'

# Set up Bravo defaults/config.
Bravo.pkey              = 'pkey'
Bravo.cert              = 'cert.crt'
Bravo.cuit              = '30714602272'
Bravo.sale_point        = '0002'
Bravo.default_concepto  = 'Productos'
Bravo.default_moneda    = :peso
Bravo.own_iva_cond      = :responsable_inscripto
Bravo.openssl_bin       = '/usr/bin/openssl'
Bravo::AuthData.environment         = :test

# Let's issue a Factura for 1200 ARS to a Responsable Inscripto
bill_a = Bravo::BillItemized.new(iva_condition: :responsable_inscripto, net: 1200, invoice_type: :invoice)
bill_a.document_number      = '30710151543'
bill_a.document_type        = 'CUIT'
bill_a.authorize
