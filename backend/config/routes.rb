Rails.application.routes.draw do
  # Health check for load balancers/uptime monitors.
  get "up" => "health#show", as: :rails_health_check
  root "health#show"

  # Avoid spamming logs with 404s for the browser's automatic favicon request.
  get "favicon.ico", to: proc { [ 204, {}, [] ] }

  namespace :api do
    namespace :v1 do
      get "assignments", to: "assignments#show"
      resources :events, only: [ :create ]
      resources :experiments, only: [ :index, :create, :destroy ] do
        patch :toggle_status, on: :member
      end
      resources :experiment_drafts, only: [ :create ]
      resources :variants, only: [] do
        patch :generate_content, on: :member
      end
    end
  end

  # Catch-all so unmatched paths get a consistent JSON 404 instead of a raw RoutingError.
  match "*unmatched", to: "errors#not_found", via: :all
end
