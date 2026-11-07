FactoryBot.define do
  factory :visit do
    place
    visited_on { Date.current }
    want_again { false }
  end
end
