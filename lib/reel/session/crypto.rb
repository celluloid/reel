require 'openssl'
require 'base64'
require 'uri'

module Reel
  module Session
    module Crypto

      # key and iv (should be atleast 16 char long)
      KEY = '%sreel::session::secret_key'.freeze
      IV =  '%sreel::session::base_iv'.freeze

      def encrypt val
        cipher = OpenSSL::Cipher::AES128.new :CBC
        cipher.encrypt
        # getting config depending on call from session/store
        config = Reel::Session.configuration
        cipher.key = KEY % config[:secret_key]
        cipher.iv = IV % config[:session_name]
        # encoding it as encryption is poping out unsafe character
        URI.encode_www_form_component Base64.encode64(cipher.update(val) + cipher.final)
      end


      def decrypt val
        return unless val
        begin
          val = Base64.decode64 URI.decode_www_form_component(val)
          cipher = OpenSSL::Cipher::AES128.new :CBC
          cipher.decrypt
          # getting config depending on call from session/store
          config = Reel::Session.configuration
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
