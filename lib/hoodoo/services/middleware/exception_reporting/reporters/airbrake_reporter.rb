########################################################################
# File::    airbrake_reporter.rb
# (C)::     Loyalty New Zealand 2014
#
# Purpose:: Send exception details to Airbrake.
# ----------------------------------------------------------------------
#           08-Dec-2014 (ADH): Created.
########################################################################

module Hoodoo; module Services
  class Middleware

    class ExceptionReporting

      # Hoodoo::Services::Middleware::ExceptionReporting::BaseReporter subclass
      # giving Hoodoo::Services::Middleware::ExceptionReporting access to
      # Airbrake for error reporting. See https://airbrake.io.
      #
      # Your application must include the Airbrake gem 'airbrake' via Gemfile
      # (+gem 'airbrake'+ / +bundle install) or direct installation (+gem
      # install airbrake+).
      #
      # The API key must be set during your application initialization and the
      # class must be added to Hoodoo for use as an error reporter, e.g.
      # through a 'config/initializers' folder, as follows:
      #
      #     require 'airbrake'
      #
      #     Airbrake.configure do | config |
      #       config.api_key = 'YOUR_AIRBRAKE_API_KEY'
      #     end
      #
      #     Hoodoo::Services::Middleware::ExceptionReporting.add(
      #       Hoodoo::Services::Middleware::ExceptionReporting::AirbrakeReporter
      #     ) unless Service.config.env.test? || Service.config.env.development?
      #
      # Services and the Hoodoo middleware do not pass Rails-like params
      # around in forms or query strings, but do beware of search or filter
      # query data containing sensitive material or POST bodies in e.g. JSON
      # encoding containing sensitive data. This comes down to the filtering
      # ability of the Airbrake gem:
      #
      #   https://github.com/airbrake/airbrake/wiki/Customizing-your-airbrake.rb
      #
      class AirbrakeReporter < Hoodoo::Services::Middleware::ExceptionReporting::BaseReporter

        # Report an exception to Airbrake.
        #
        # +e+::   Exception (or subclass) instance to be reported.
        #
        # +env+:: Optional Rack environment hash for the inbound request, for
        #         exception reports made in the context of Rack request
        #         handling. In the case of Airbrake, the call may just hang
        #         unless a Rack environment is provided.
        #
        def report( e, env = nil )
          Airbrake.notify_or_ignore( e, :rack_env => env )
        end
      end

    end

  end
end; end
