module Api
  module V1
    # Inherit from the top-level ApplicationController (not
    # ActionController::API directly) so the global rescue_from handlers for
    # RecordNotFound/RecordInvalid/ParameterMissing apply here too.
    class ApplicationController < ::ApplicationController
    end
  end
end
