class ProjectRequest < ApplicationRecord
  class Search < ApplicationService
    include Model
    include Policy

    model ProjectRequest, :collection
    policy ProjectRequestPolicy

    sort_by name: :asc

    private

    def collection_model!
      policy_scope(super)
    end
  end
end
