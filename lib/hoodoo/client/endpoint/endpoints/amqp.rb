########################################################################
# File::    amqp.rb
# (C)::     Loyalty New Zealand 2015
#
# Purpose:: Resource endpoint definition.
# ----------------------------------------------------------------------
#           05-Mar-2015 (ADH): Created.
########################################################################

module Hoodoo
  class Client     # Just used as a namespace here
    class Endpoint # Just used as a namespace here

      # Talk to a resource that is contacted over AMQP using HTTP emulation
      # via the Alchemy and AMQ Endpoint gems.
      #
      # Calls cannot be made until #alchemy= has been called
      # to set an Alchemy caller instance. The Alchemy +http_request+ method
      # is called on this instance to perform the over-queue HTTP simulation.
      #
      # Configured with a Hoodoo::Services::Discovery::ForAMQP discovery
      # result instance.
      #
      class AMQP < Hoodoo::Client::Endpoint::HTTPBased

        protected

          # See Hoodoo::Client::Endpoint#configure_with.
          #
          # Requires a Hoodoo::Services::Discovery::ForAMQP instance in the
          # +discovery_result+ field of the +options+ Hash.
          #
          def configure_with( resource, version, options )
            unless @discovery_result.is_a?( Hoodoo::Services::Discovery::ForAMQP )
              raise "Hoodoo::Client::Endpoint::AMQP must be configured with a Hoodoo::Services::Discovery::ForAMQP instance - got '#{ @discovery_result.class.name }'"
            end

            # Host and port isn't relevant for Alchemy but *is* needed
            # to keep Rack happy.

            endpoint_uri      = URI.parse( 'http://localhost:80' )
            endpoint_uri.path = @discovery_result.equivalent_path

            @description                  = Hoodoo::Client::Endpoint::HTTPBased::DescriptionOfRequest.new
            @description.discovery_result = @discovery_result
            @description.endpoint_uri     = endpoint_uri
          end

        public

          # Set/get the Alchemy caller instance. Its +http_request+ method is
          # called to perform the over-queue HTTP simulation.
          #
          # Instances of the AMQP endpoint can be created, but cannot be
          # used for resource calls - #list, #show, #create, #update and
          # #delete _cannot_ be called - until an Alchemy instance has been
          # specified. An exception will be raised if you try.
          #
          attr_accessor :alchemy

          # See Hoodoo::Client::Endpoint#list.
          #
          def list( query_hash = nil )
            d            = @description.dup # This does NOT dup the objects to which @description points
            d.action     = :list
            d.query_hash = query_hash

            return do_amqp( d )
          end

          # See Hoodoo::Client::Endpoint#show.
          #
          def show( ident, query_hash = nil )
            d            = @description.dup
            d.action     = :show
            d.ident      = ident
            d.query_hash = query_hash

            return do_amqp( d )
          end

          # See Hoodoo::Client::Endpoint#create.
          #
          def create( body_hash, query_hash = nil )
            d            = @description.dup
            d.action     = :create
            d.body_hash  = body_hash
            d.query_hash = query_hash

            return do_amqp( d )
          end

          # See Hoodoo::Client::Endpoint#update.
          #
          def update( ident, body_hash, query_hash = nil )
            d            = @description.dup
            d.action     = :update
            d.ident      = ident
            d.body_hash  = body_hash
            d.query_hash = query_hash

            return do_amqp( d )
          end

          # See Hoodoo::Client::Endpoint#delete.
          #
          def delete( ident, query_hash = nil )
            d            = @description.dup
            d.action     = :delete
            d.ident      = ident
            d.query_hash = query_hash

            return do_amqp( d )
          end

        private

          # Call Alchemy to make an HTTP simulated request over AMQP to a
          # target resource and return the result as a
          # Hoodoo::Client::AugmentedArray (for 'list' calls) or
          # Hoodoo::Client::AugumentedHash (for all other calls) instance.
          #
          # +description_of_request+:: A Hoodoo::Client::Endpoint::HTTPBased::DescriptionOfRequest
          #                            instance with all the request details
          #                            set inside. The +discovery_data+ field
          #                            must refer to a
          #                            Hoodoo::Services::Discovery::ForAMQP
          #                            instance (not re-checked internally).
          #
          def do_amqp( description_of_request )

            if self.alchemy().nil?
              raise 'Hoodoo::Client::Endpoint::AMQP cannot be used unless an Alchemy instance has been provided'
            end

            action = description_of_request.action
            data   = get_data_for_request( description_of_request )

            # Host and port are just there to keep Rack happy at the
            # receiving end of the over-AMQP synthesised HTTP request.

            alchemy_options = {
              :host    => description_of_request.endpoint_uri.host,
              :port    => description_of_request.endpoint_uri.port,
              :query   => data.query_hash,
              :body    => data.body_string,
              :headers => data.header_hash
            }

            unless self.session_id().nil? # Session comes from Endpoint superclass
              alchemy_options[ :session_id ] = self.session_id()
            end

            http_method = {
              :create => 'POST',
              :update => 'PATCH',
              :delete => 'DELETE'
            }[ action ] || 'GET'

            description_of_response        = DescriptionOfResponse.new
            description_of_response.action = action

            amqp_response = self.alchemy().http_request(
              description_of_request.discovery_result.queue_name,
              http_method,
              data.full_uri.path,
              alchemy_options
            )

            description_of_response.http_status_code = amqp_response.status_code.to_i
            description_of_response.http_headers     = amqp_response.headers || {}
            description_of_response.raw_body_data    = amqp_response.body

            return get_data_for_response( description_of_response )
          end

      end
    end
  end
end
