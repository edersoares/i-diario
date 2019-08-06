FactoryGirl.define do
  factory :role do
    association :author, factory: :user

    name { Faker::Lorem.unique.sentence }
    access_level AccessLevel::TEACHER
  end
end
