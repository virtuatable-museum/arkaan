FactoryBot.define do
  factory :empty_group, class: Core::Models::Permissions::Group do
    factory :group do
      slug { 'test_group' }

      factory :users do
        slug { 'users' }
        is_superuser { false }
      end

      factory :administrators do
        slug { 'administrators' }
        is_superuser { true }
      end

      factory :group_with_members do
        after :create do |group, evaluator|
          create_list(:account, 1, groups: [group])
        end
      end

      factory :group_with_rights do
        after :create do |group, evaluator|
          create_list(:right, 1, groups: [group])
        end
      end
    end
  end
end