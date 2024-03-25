Rails.application.routes.draw do
  authenticate :user, lambda { |u| u.admin? } do
    mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  end

  resources :conversations do
    resources :messages, only: [:create, :destroy]
  end

  resources :conversation_collections, only: [:create]

  resources :collections do
    resources :documents, only: [:create, :destroy, :show, :vectorize]
    post :search, as: :search
  end

  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "collections#index"
end
