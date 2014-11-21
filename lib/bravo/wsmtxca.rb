class WSMTXCA

  class << self

    def complete_auth_hash(token, sign, cuit)
      @auth_hash = { 'token' => token, 'sign' => sign, 'cuitRepresentada' => cuit}
    end

  end

end
