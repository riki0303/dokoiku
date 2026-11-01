FactoryBot.define do
  factory :place do
    group
    name { "テストの場所" }
    note { "前から気になっていた" }
    distance { :near }
  end
end
