Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up and / so load balancers, uptime monitors, and
  # container orchestrators can verify the app is live.
  get "up" => "health#show", as: :rails_health_check
  root "health#show"

  # Browsers request this automatically on every page load (including the
  # root health check above); respond with a bare 204 instead of letting it
  # fall through to the catch-all below and spam the logs with routing
  # errors on every hit.
  get "favicon.ico", to: proc { [ 204, {}, [] ] }

  namespace :api do
    namespace :v1 do
      get "assignments", to: "assignments#show"
      resources :events, only: [ :create ]
      resources :experiments, only: [ :index ] do
        patch :toggle_status, on: :member
      end
    end
  end

  # Catch-all: route any other unmatched path to a real controller action
  # instead of letting Rails raise an unhandled ActionController::RoutingError,
  # so API clients always get back a consistent JSON 404 body.
  match "*unmatched", to: "errors#not_found", via: :all
end
