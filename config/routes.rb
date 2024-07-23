require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  authenticate :user, ->(u) { u.admin? } do
    mount Motor::Admin => '/admin'
    mount RailsAdmin::Engine => "/rails_admin", as: "rails_admin"
    mount Sidekiq::Web => "/sidekiq"
  end

  resources :conversations do
    resources :messages, only: [:create, :destroy]
  end

  resources :conversation_collections, only: [:create]

  resources :collections do
    resources :documents, only: [:create, :destroy, :show] do
      post :vectorize, as: :vectorize
      post :graph, as: :graph

      resources :chunks, only: [:index, :show]
    end

    post :search, as: :search
    post :search, as: :search, on: :collection, to: "collections#global_search"
  end

  # API
  namespace :v1 do
    resources :collections, only: %i[create destroy index show] do
      get "search", on: :member, to: "collections#search"

      resources :documents, only: [:index, :show] do
        resources :chunks, only: [:index, :show]
      end
    end

    resources :settings, only: [:index, :show]
    resources :models, only: [:index, :show]

    get "search", to: "search#search"
    get "chat", to: "chat#chat"
    get "version", to: "version#show"
  end

  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "collections#index"
end
