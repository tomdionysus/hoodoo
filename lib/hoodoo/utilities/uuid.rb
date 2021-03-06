require "uuidtools"

module Hoodoo

  # Class that handles generation and validation of UUIDs. Whenever you
  # want to associate an identifier with something, you should use this
  # class rather than (e.g.) relying on identifiers generated by a
  # database. This allows you to cluster your database later on, should
  # your application become big enough, without having to worry about
  # ID synchronisation across instances.
  #
  class UUID

    # A regexp which, as its name suggests, only matches a string that
    # contains 16 pairs of hex digits (with upper or lower case A-F).
    #
    # http://stackoverflow.com/questions/287684/regular-expression-to-validate-hex-string
    #
    MATCH_16_PAIRS_OF_HEX_DIGITS = /^([[:xdigit:]]{2}){16}$/

    # Generate a unique identifier. Returns a 32 character string.
    #
    def self.generate
      UUIDTools::UUID.random_create().hexdigest()
    end

    # Checks if a UUID string is valid. Returns +true+ if so, else +false+.
    #
    # +uuid+:: UUID string to validate. Must be a String, 32 characters
    #          long (as 16 hex digit pairs) and parse to a valid result
    #          internally, according to internal UUID generation rules.
    #
    # Note that the validity of a UUID says nothing about where, if anywhere,
    # it might have been used. So, just because a UUID is valid, doesn't mean
    # you have (say) stored something with that UUID as the primary key in a
    # row in a database.
    #
    def self.valid?( uuid )
      uuid.is_a?( ::String )                           &&
      ( uuid =~ MATCH_16_PAIRS_OF_HEX_DIGITS ) != nil  &&
      UUIDTools::UUID.parse_hexdigest( uuid ).valid?()
    end
  end
end
