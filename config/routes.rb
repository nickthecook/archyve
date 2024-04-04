Rails.application.routes.draw do
  authenticate :user, ->(u) { u.admin? } do
    mount RailsAdmin::Engine => "/admin", as: "rails_admin"
  end

  resources :conversations do
    resources :messages, only: [:create, :destroy]
  end

  resources :conversation_collections, only: [:create]

  resources :collections do
    resources :documents, only: [:create, :destroy, :show] do
      post :vectorize, as: :vectorize

      resources :chunks, only: [:index, :show]
    end

    post :search, as: :search
    post :search, as: :search, on: :collection, to: "collections#global_search"
  end

  # API
  namespace :v1 do
    resources :documents, only: [:index, :show]
    resources :collections do
      get "list", on: :collection, to: "collections#list"
      get "get", on: :member, to: "collections#get"
      get "search", on: :member, to: "collections#search"
    end
    resources :chunks do
      get "list", on: :collection, to: "chunks#list"
      get "get", on: :member, to: "chunks#get"
    end

    get "search", to: "search#search"
  end

  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "collections#index"
end
