FactoryBot.define do
  factory :user do
    # email_address is uniquely indexed, so it has to vary per record.
    sequence(:email_address) { |n| "user#{n}@example.com" }
    # Lazily resolved, so load order between support files and factories doesn't
    # matter — see spec/support/authentication.rb.
    password { AuthenticationHelpers::PASSWORD }

    trait :operator do
      role { :operator }
    end

    trait :admin do
      role { :admin }
    end
  end
end
