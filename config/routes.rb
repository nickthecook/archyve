Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Sign in and out. No password-reset routes: no SMTP is configured and there
  # is no public signup, so an admin sets passwords — and with Keycloak now
  # owning normal sign-in, local accounts are break-glass anyway.
  resource :session, only: [:new, :create, :destroy]

  # Single sign-on. The initiate is a POST so forgery protection covers it; the
  # callback is the GET Keycloak redirects back to. Both refuse unless SSO is
  # configured. See docs/architecture.md.
  post "sso", to: "sso_sessions#create", as: :sso_sign_in
  get "sso/callback", to: "sso_sessions#callback", as: :sso_callback

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

  resources :collections, only: [:index, :show, :create, :update, :destroy], param: :slug do
    # A user adding/removing a document to/from this collection (manual
    # memberships only; source rows are retracted at the source).
    resources :documents, only: [:create, :destroy], controller: "collection_memberships"
    # Who may use this collection. Managed by whoever administers the
    # collection, not only by a system admin — owning content includes deciding
    # who sees it.
    resources :people, only: [:index, :create, :update, :destroy], controller: "collection_users"
    # Which sources feed this collection. Lives here, not on the source,
    # because it decides what this collection's readers see.
    resources :sources, only: [:create, :destroy], controller: "collection_sources"
  end
  # Downloading is open to any signed-in user; browsing the archive is not.
  # That asymmetry is deliberate — a reader reaches a document through a chat
  # citation or a search result, not by enumerating the shelf.
  # `destroy` is a purge — the document leaves every collection and the archive —
  # so it lives here rather than under a collection, which owns memberships only.
  resources :documents, only: [:index, :show, :create, :destroy] do
    get :download, on: :member
    # POST because it starts work, not a page — same reasoning as a source's
    # "Sync now".
    post :reprocess, on: :member
  end
  # "Unsorted" is a derived view (docs in no collection), not a collection — its
  # own top-level route so it never collides with a collection slug.
  get "unsorted", to: "unsorted#index"
  post "unsorted/assign", to: "unsorted#assign", as: :assign_unsorted
  # The other thing to do with a selection. A POST like `assign` because both are
  # submissions of the same form.
  post "unsorted/purge", to: "unsorted#purge", as: :purge_unsorted
  get "search", to: "search#index"
  # The section is "Chat"; the records are conversations. `path:` keeps the URL
  # reading the way the nav does without naming the model something it isn't.
  # A conversation is private to its author, so there is no index anyone else
  # can reach and no per-conversation sharing to grant.
  resources :conversations, only: [:index, :show, :create, :destroy], path: "chat" do
    # Asking is creating a message; the answer is a job, not a response body.
    resources :messages, only: [:create]
  end
  get "settings", to: "settings#index"
  # The living style guide (docs/design.md renders itself here). Admin-only: it
  # is a maker's tool, but it ships so the deployed app can be checked against
  # its own rules.
  get "styleguide", to: "styleguide#index"
  # Solid Queue's dashboard — queues, running/failed jobs, retry/discard.
  # Admin-only via MissionControlJobsBaseController.
  mount MissionControl::Jobs::Engine, at: "/jobs"
  # Administration. Admin-only, and distinct from /account above.
  namespace :settings do
    resources :users, except: [:show]
    # The system prompt every chat uses. A single page for prompt-related
    # settings, not a CRUD resource — see Setting.
    resource :prompt, only: [:show, :update]
    # Where Archyve sends prompts. Under Settings rather than beside Sources:
    # a source is content, an inference server is system administration, and
    # only an admin has any business repointing the app at a different LLM.
    resources :inference_servers do
      # Both POSTs because they do something rather than show something.
      # "Check" is synchronous — one HTTP call with one outcome — unlike a
      # source sync, which is a job.
      post :check, on: :member
      get :discover, on: :member
      post :import, on: :member
      # A model without a server is meaningless, so it is managed inside one.
      resources :models, only: [:new, :create, :edit, :update, :destroy],
        controller: "inference_models"
    end
    # The servers sources pull from, and the credentials for them. Here rather
    # than beside Sources because it is IT's job: an operator curates what a
    # collection contains, an admin holds the token that reaches the wiki.
    resources :endpoints do
      # A POST because it does something — one call to the server, recorded.
      post :access, on: :member
    end
  end
  # Sources sit with the content they produce, not under Settings — managing
  # them is a content job, and Settings is heading towards admin-only.
  # "Sync now" is a POST because it starts work, not a page.
  resources :sources do
    post :sync, on: :member
    # Who may manage this source. Not who may read its documents — that is
    # decided by the collections it feeds.
    resources :people, only: [:index, :create, :update, :destroy], controller: "source_users"
  end

  # The landing: the archive corridor with search as the way in.
  root "home#index"
end
