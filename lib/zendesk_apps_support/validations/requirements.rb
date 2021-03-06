module ZendeskAppsSupport
  module Validations
    module Requirements
      MAX_REQUIREMENTS = 5000

      class <<self
        def call(package)
          if package.manifest.requirements_only? && !package.has_requirements?
            return [ValidationError.new(:missing_requirements)]
          elsif package.manifest.marketing_only? && package.has_requirements?
            return [ValidationError.new(:requirements_not_supported)]
          elsif !package.has_requirements?
            return []
          end

          begin
            requirements = package.requirements_json
          rescue ZendeskAppsSupport::Manifest::OverrideError => e
            return [ValidationError.new(:duplicate_requirements, duplicate_keys: e.key, count: 1)]
          end

          [].tap do |errors|
            errors << invalid_requirements_types(requirements)
            errors << excessive_requirements(requirements)
            errors << invalid_channel_integrations(requirements)
            errors << invalid_user_fields(requirements)
            errors << missing_required_fields(requirements)
            errors.flatten!
            errors.compact!
          end
        rescue JSON::ParserError => e
          return [ValidationError.new(:requirements_not_json, errors: e)]
        end

        private

        def missing_required_fields(requirements)
          [].tap do |errors|
            requirements.each do |requirement_type, requirement|
              next if requirement_type == 'channel_integrations'
              requirement.each do |identifier, fields|
                next if fields.include? 'title'
                errors << ValidationError.new(:missing_required_fields, field: 'title', identifier: identifier)
              end
            end
          end
        end

        def excessive_requirements(requirements)
          requirement_count = requirements.values.map(&:values).flatten.size
          if requirement_count > MAX_REQUIREMENTS
            ValidationError.new(:excessive_requirements, max: MAX_REQUIREMENTS, count: requirement_count)
          end
        end

        def invalid_user_fields(requirements)
          user_fields = requirements['user_fields']
          return unless user_fields
          [].tap do |errors|
            user_fields.each do |identifier, fields|
              next if fields.include? 'key'
              errors << ValidationError.new(:missing_required_fields, field: 'key', identifier: identifier)
            end
          end
        end

        def invalid_channel_integrations(requirements)
          channel_integrations = requirements['channel_integrations']
          return unless channel_integrations
          [].tap do |errors|
            if channel_integrations.size > 1
              errors << ValidationError.new(:multiple_channel_integrations, count: channel_integrations.size)
            end
            channel_integrations.each do |identifier, fields|
              unless fields.include? 'manifest_url'
                errors << ValidationError.new(:missing_required_fields, field: 'manifest_url', identifier: identifier)
              end
            end
          end
        end

        def invalid_requirements_types(requirements)
          invalid_types = requirements.keys - ZendeskAppsSupport::AppRequirement::TYPES

          unless invalid_types.empty?
            ValidationError.new(:invalid_requirements_types, invalid_types: invalid_types.join(', '), count: invalid_types.length)
          end
        end
      end
    end
  end
end
