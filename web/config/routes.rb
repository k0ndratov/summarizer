Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :summaries, only: %i[index new create show]
  root "summaries#new"
end
