class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Ransack 4+ requires an explicit allowlist. Disallow searching through associations by default
  def self.ransackable_associations(_auth_object = nil) # rails_best_practices:disable RemoveUnusedMethodsInModelsCheck
    []
  end
end
