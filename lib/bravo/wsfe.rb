class WSFE

  class << self

    def complete_auth_hash(token, sign, cuit)
      @auth_hash = { 'Token' => token, 'Sign' => sign, 'Cuit' => cuit}
    end

  end

end
