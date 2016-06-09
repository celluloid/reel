require 'openssl'
require 'base64'

module Reel
  module Session
    module Crypto

      def encrypt val
        cipher = OpenSSL::Cipher::AES128.new :CBC
        cipher.encrypt
        # temp key and iv (should be atleast 16 char long)
        cipher.key = "1234567890123456"
        cipher.iv = "1234567890123456"
        Base64.encode64(cipher.update(val) + cipher.final)
      end

      def decrypt val
        begin
          val = Base64.decode64(val)
          cipher = OpenSSL::Cipher::AES128.new :CBC
          cipher.decrypt
          cipher.key = "1234567890123456"
          cipher.iv = "1234567890123456"
          cipher.update(val) + cipher.final
          rescue => e
            warn e.message
            nil
        end
      end

    end
  end
end
