module Bravo

  # This class handles authorization data
  #
  class AuthData

    class << self

      attr_accessor :environment, :todays_data_file_name

      # Fetches WSAA Authorization Data to build the datafile for the day.
      # It requires the private key file and the certificate to exist and
      # to be configured as Bravo.pkey and Bravo.cert
      #
      def fetch(service_type)
        raise "Archivo de llave privada no encontrado en #{ Bravo.pkey }" unless File.exist?(Bravo.pkey)
        raise "Archivo certificado no encontrado en #{ Bravo.cert }" unless File.exist?(Bravo.cert)

        Bravo::Wsaa.login(service_type) unless File.exist?(todays_data_file_name(service_type))

        YAML.load_file(todays_data_file_name(service_type)).each do |k, v|
          Bravo.const_set(k.to_s.upcase, v) unless Bravo.const_defined?(k.to_s.upcase)
        end
      end

      # Returns the authorization hash, containing the Token, Signature and Cuit
      # @return [Hash]
      #
      def auth_hash(service_type)
        unless Bravo.constants.include?(:"TOKEN_#{service_type.upcase}") &&
               Bravo.constants.include?(:"SIGN_#{service_type.upcase}")
          fetch(service_type)
        end

        Bravo.const_get(service_type.upcase)
             .complete_auth_hash(Bravo.const_get(:"TOKEN_#{service_type.upcase}"),
                                 Bravo.const_get(:"SIGN_#{service_type.upcase}"),
                                 Bravo.cuit)
      end

      # Returns the right wsaa url for the specific environment
      # @return [String]
      #
      def wsaa_url
        check_environment!
        Bravo::URLS[environment][:wsaa]
      end

      # Returns the right wsfe url for the specific environment
      # @return [String]
      #
      def wsfe_url
        check_environment!
        Bravo::URLS[environment][:wsfe]
      end

      def mtx_url
        check_environment!
        Bravo::URLS[environment][:mtx]
      end

      # Creates the data file name for a cuit number and the current day
      # @return [String]
      #
      def todays_data_file_name(service_type)
        @todays_data_file ||= "/tmp/bravo_#{ Bravo.cuit }_#{ service_type }_#{ Time.new.strftime('%Y_%m_%d') }.yml"
      end

      def check_environment!
        raise 'Environment not set.' unless Bravo::URLS.keys.include? environment
      end
    end
  end
end
