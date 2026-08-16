Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up and / so load balancers, uptime monitors, and
  # container orchestrators can verify the app is live.
  get "up" => "health#show", as: :rails_health_check
  root "health#show"

  namespace :api do
    namespace :v1 do
    end
  end
end
