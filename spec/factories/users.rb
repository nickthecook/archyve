FactoryBot.define do
  factory :user do
    # email_address is uniquely indexed, so it has to vary per record.
    sequence(:email_address) { |n| "user#{n}@example.com" }
    # Lazily resolved, so load order between support files and factories doesn't
    # matter — see spec/support/authentication.rb.
    password { AuthenticationHelpers::PASSWORD }

    # An SSO-provisioned user: no password at all, which is only a valid record
    # because User relaxes has_secure_password's presence check for them.
    trait :sso do
      password { nil }
      sequence(:sso_subject) { |n| "keycloak-uuid-#{n}" }
      sso_issuer { SsoHelpers::ISSUER }
    end

    trait :curator do
      role { :curator }
    end

    trait :admin do
      role { :admin }
    end
  end
end
