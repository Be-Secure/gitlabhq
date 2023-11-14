# frozen_string_literal: true

module Mutations
  module Organizations
    class Create < BaseMutation
      graphql_name 'OrganizationCreate'

      authorize :create_organization

      field :organization,
        ::Types::Organizations::OrganizationType,
        null: true,
        description: 'Organization created.'

      argument :name, GraphQL::Types::String,
        required: true,
        description: 'Name for the organization.'

      argument :path, GraphQL::Types::String,
        required: true,
        description: 'Path for the organization.'

      def resolve(args)
        authorize!(:global)

        result = ::Organizations::CreateService.new(
          current_user: current_user,
          params: args
        ).execute

        { organization: result.payload, errors: result.errors }
      end
    end
  end
end
