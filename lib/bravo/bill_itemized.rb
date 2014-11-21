require 'pry'
# encoding: utf-8
module Bravo
  # The main class in Bravo. Handles WSFE method interactions.
  # Subsequent implementations will be added here (maybe).
  #
  class BillItemized
    # Returns the Savon::Client instance in charge of the interactions with WSFE API.
    # (built on init)
    #
    attr_reader :client

    attr_accessor :net, :document_number, :iva_condition, :document_type, :concept, :currency, :due_date,
    :aliciva_id, :date_from, :date_to, :body, :response, :invoice_type

    def initialize(attrs = {})
      opts = { wsdl: Bravo::AuthData.mtx_url }.merge! Bravo.logger_options
      @client       ||= Savon.client(opts)
      @body           = { 'authRequest' => Bravo::AuthData.auth_hash('wsmtxca') }
      @iva_condition  = validate_iva_condition(attrs[:iva_condition])
      @net            = attrs[:net]           || 0
      @document_type  = attrs[:document_type] || Bravo.default_documento
      @currency       = attrs[:currency]      || Bravo.default_moneda
      @concept        = attrs[:concept]       || Bravo.default_concepto
      @invoice_type   = validate_invoice_type(attrs[:invoice_type])
    end

    # Searches the corresponding invoice type according to the combination of
    # the seller's IVA condition and the buyer's IVA condition
    # @return [String] the document type string
    #
    def bill_type
      Bravo::BILL_TYPE[Bravo.own_iva_cond][iva_condition][invoice_type]
    end

    # Calculates the total field for the invoice by adding
    # net and iva_sum.
    # @return [Float] the sum of both fields, or 0 if the net is 0.
    #
    def total
      @total = net.zero? ? 0 : net + iva_sum
    end

    # Calculates the corresponding iva sum.
    # This is performed by multiplying the net by the tax value
    # @return [Float] the iva sum
    #
    # TODO: fix this
    #
    def iva_sum
      @iva_sum = net * applicable_iva_multiplier
      @iva_sum.round(2)
    end

    # Files the authorization request to AFIP
    # @return [Boolean] wether the request succeeded or not
    #
    def authorize
      setup_bill
      response = client.call(:autorizar_comprobante) do |soap|
        # soap.namespaces['xmlns'] = 'http://ar.gov.afip.dif.FEV1/'
        soap.message body
      end
      binding.pry
      setup_response(response.to_hash)
      self.authorized?
    end

    # Sets up the request body for the authorisation
    # @return [Hash] returns the request body as a hash
    #
    def setup_bill
      fecaereq = setup_request_structure
      body.merge!(fecaereq)
    end

    # Returns the result of the authorization operation
    # @return [Boolean] the response result
    #
    def authorized?
      !response.nil? && response.header_result == 'A' && response.detail_result == 'A'
    end

    private

    class << self
      # Sets the header hash for the request
      # @return [Hash]
      #
      def header(bill_type)
        # toodo sacado de la factura
        { 'CantReg' => '1', 'CbteTipo' => bill_type, 'PtoVta' => Bravo.sale_point }
      end
    end

    # Response parser. Only works for the authorize method
    # @return [Struct] a struct with key-value pairs with the response values
    #
    # rubocop:disable Metrics/MethodLength
    def setup_response(response)
      # TODO: turn this into an all-purpose Response class
      result          = response[:fecae_solicitar_response][:fecae_solicitar_result]

      response_header = result[:fe_cab_resp]
      response_detail = result[:fe_det_resp][:fecae_det_response]

      request_header  = body['FeCAEReq']['FeCabReq'].underscore_keys.symbolize_keys
      request_detail  = body['FeCAEReq']['FeDetReq']['FECAEDetRequest'].underscore_keys.symbolize_keys

      request_detail.merge!(request_detail.delete(:iva)['AlicIva'].underscore_keys.symbolize_keys)

      response_hash = { header_result: response_header.delete(:resultado),
        authorized_on: response_header.delete(:fch_proceso),

        detail_result: response_detail.delete(:resultado),
        cae_due_date:  response_detail.delete(:cae_fch_vto),
        cae:           response_detail.delete(:cae),

        iva_id:        request_detail.delete(:id),
        iva_importe:   request_detail.delete(:importe),
        moneda:        request_detail.delete(:mon_id),
        cotizacion:    request_detail.delete(:mon_cotiz),
        iva_base_imp:  request_detail.delete(:base_imp),
        doc_num:       request_detail.delete(:doc_nro)
      }.merge!(request_header).merge!(request_detail)

      keys, values = response_hash.to_a.transpose

      self.response = Struct.new('Response', *keys).new(*values)
    end
    # rubocop:enable Metrics/MethodLength

    def applicable_iva
      index = Bravo::APPLICABLE_IVA[Bravo.own_iva_cond][iva_condition]
      Bravo::ALIC_IVA[index]
    end

    def applicable_iva_code
      applicable_iva[0]
    end

    def applicable_iva_multiplier
      applicable_iva[1]
    end

    def validate_iva_condition(iva_cond)
      valid_conditions = Bravo::BILL_TYPE[Bravo.own_iva_cond].keys
      if valid_conditions.include? iva_cond
        iva_cond
      else
        raise(NullOrInvalidAttribute.new,
        "El valor de iva_condition debe estar incluído en #{ valid_conditions }")
      end
    end

    def validate_invoice_type(type)
      if Bravo::BILL_TYPE_A.keys.include? type
        type
      else
        raise(NullOrInvalidAttribute.new, "invoice_type debe estar incluido en \
        #{ Bravo::BILL_TYPE_A.keys }")
      end
    end

    def setup_request_structure
      { 'comprobanteCAERequest' =>
        {
          'codigoTipoComprobante' => bill_type,
          'numeroPuntoVenta' => Bravo.sale_point,
          'numeroComprobante' => Bravo::Reference.mtx_next_bill_number(bill_type),
          'fechaEmision' => today,
          'codigoTipoDocumento' => Bravo::DOCUMENTOS[document_type],
          'numeroDocumento' => document_number,
          'importeGravado' => ,
          'importeNoGravado' => ,
          'importeExento' => ,
          'importeSubtotal' => ,
          'importeOtrosTributos' => ,
          'importeTotal' => ,
          'codigoMoneda' => Bravo::MONEDAS[currency][:codigo],
          'cotizacionMoneda' => 1,
          'observaciones' => 'Observaciones comerciales, libres',
          'codigoConcepto' => Bravo::CONCEPTOS[concept],
          'arrayOtrosTributos' =>
          {
            'otroTributo' =>
            {
              'codigo' => 99,
              'descripcion' => 'Otro atributo',
              'baseImponible' => 100.00,
              'importe' => 1.00
            }
          },
          'arrayItems' =>
          {
            'item' =>
            {
              'unidadesMtx' => '123456',
              'codigoMtx' => '0123456789913',
              'codigo' => 'P0001',
              'descripcion' => 'Descr del prod P0001',
              'cantidad' => 1.00,
              'codigoUnidadMedida' => 7,
              'precioUnitario' => 100.00,
              'importeBonificacion' => 0.00,
              'codigoCondicionIVA' => 5,
              'importeIVA' => 21.00,
              'importeItem' => 121.00
            }
          },
          'arraySubtotalesIVA' =>
          {
            'subtotalIVA' => {
              'codigo' => 5,
              'importe' => 21.00
            }
          },
        }
      }
    end

    def today
      Time.new.strftime('%Y%m%d')
    end

  end
end
