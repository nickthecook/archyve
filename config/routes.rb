Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Sign in and out. No password-reset routes: no SMTP is configured and there
  # is no public signup, so an admin sets passwords. Revisit if Keycloak lands
  # and local accounts become break-glass only.
  resource :session, only: [:new, :create, :destroy]

  # Your own account: the only place a non-admin changes their own password.
  # Reached from the account menu in the top bar, not from Settings — Settings
  # is administration, which most people can't see.
  resource :account, only: [:show, :update]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :collections, only: [:index, :show, :create], param: :slug do
    # A user adding/removing a document to/from this collection (manual
    # memberships only; source rows are retracted at the source).
    resources :documents, only: [:create, :destroy], controller: "collection_memberships"
  end
  # Downloading is open to any signed-in user; browsing the archive is not.
  # That asymmetry is deliberate — a reader reaches a document through a chat
  # citation or a search result, not by enumerating the shelf.
  resources :documents, only: [:index, :show, :create] do
    get :download, on: :member
  end
  # "Unsorted" is a derived view (docs in no collection), not a collection — its
  # own top-level route so it never collides with a collection slug.
  get "unsorted", to: "unsorted#index"
  post "unsorted/assign", to: "unsorted#assign", as: :assign_unsorted
  get "search", to: "search#index"
  get "chat", to: "chat#index"
  get "settings", to: "settings#index"
  # Administration. Admin-only, and distinct from /account above.
  namespace :settings do
    resources :users, except: [:show]
  end
  # Sources sit with the content they produce, not under Settings — managing
  # them is a content job, and Settings is heading towards admin-only.
  # "Sync now" is a POST because it starts work, not a page.
  resources :sources do
    post :sync, on: :member
  end

  # The landing: the archive corridor with search as the way in.
  root "home#index"
end
