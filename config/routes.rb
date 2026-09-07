Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :collections, only: [:index, :show, :create], param: :slug do
    # A user adding/removing a document to/from this collection (manual
    # memberships only; connector rows are retracted at the connector).
    resources :documents, only: [:create, :destroy], controller: "collection_memberships"
  end
  resources :documents, only: [:index, :show, :create]
  # "Unsorted" is a derived view (docs in no collection), not a collection — its
  # own top-level route so it never collides with a collection slug.
  get "unsorted", to: "unsorted#index"
  post "unsorted/assign", to: "unsorted#assign", as: :assign_unsorted
  get "search", to: "search#index"
  get "chat", to: "chat#index"
  get "settings", to: "settings#index"
  # Connectors are configured here for now; env-var and API configuration come
  # later. "Sync now" is a POST because it starts work, not a page.
  namespace :settings do
    resources :connectors do
      post :sync, on: :member
    end
  end

  # The landing: the archive corridor with search as the way in.
  root "home#index"
end
