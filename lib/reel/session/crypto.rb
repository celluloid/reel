require 'openssl'
require 'base64'

module Reel
  module Session
    module Crypto

      # key and iv (should be atleast 16 char long)
      KEY = 'reel::session::secret_key::%s'
      IV = 'reel::session::base_iv::%s'

      def encrypt val
        cipher = OpenSSL::Cipher::AES128.new :CBC
        cipher.encrypt
        # getting config depending on call from session/store
        config = @config || configuration
        cipher.key = KEY % config[:secret_key]
        cipher.iv = IV % config[:session_name]
        Base64.encode64(cipher.update(val) + cipher.final)
      end

      def decrypt val
        return val unless val
        begin
          val = Base64.decode64(val)
          cipher = OpenSSL::Cipher::AES128.new :CBC
          cipher.decrypt
          # getting config depending on call from session/store
          config = @config || configuration
          cipher.key = KEY % config[:secret_key]
          cipher.iv = IV % config[:session_name]
          cipher.update(val) + cipher.final
          rescue => e
            warn e.message
            nil
        end
      end

    end
  end
end
