require 'openssl'
require 'base64'
require 'uri'

module Reel
  module Session
    module Crypto

      # key and iv (should be atleast 16 char long)
      KEY = 'reel::session::secret_key::%s'
      IV = 'reel::session::base_iv::%s'

      # Encryption => although working well but creating bugs due special character like '/n' , '='
      # creating problem while setting key in headeers as well as while retrieving key from headers
      # TODO verify this : although worked

      def encrypt val
        cipher = OpenSSL::Cipher::AES128.new :CBC
        cipher.encrypt
        # getting config depending on call from session/store
        config = @config || configuration
        cipher.key = KEY % config[:secret_key]
        cipher.iv = IV % config[:session_name]
        URI.encode_www_form_component Base64.encode64(cipher.update(val) + cipher.final)
      end

      # Same as above encryption TODO verify this encoding : although worked
      def decrypt val
        return val unless val
        begin
          val = Base64.decode64 URI.decode_www_form_component(val)
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
