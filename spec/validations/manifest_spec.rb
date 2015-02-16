require 'spec_helper'

describe ZendeskAppsSupport::Validations::Manifest do
  def default_required_params(overrides = {})
    valid_fields = ZendeskAppsSupport::Validations::Manifest::REQUIRED_MANIFEST_FIELDS.inject(frameworkVersion: '1.0') do |fields, name|
      fields[name] = name
      fields
    end

    valid_fields.merge(overrides)
  end

  def create_package(parameter_hash)
    params = default_required_params(parameter_hash)
    allow(@manifest).to receive_messages(read: MultiJson.dump(params))
    @package
  end

  RSpec::Matchers.define :have_error do |error|
    match do |package|
      errors = ZendeskAppsSupport::Validations::Manifest.call(package)
      errors.map!(&:to_s) unless error.is_a? Symbol

      error ||= /.+?/

      if error.is_a? Symbol
        errors.find { |e| e.key == error }
      elsif error.is_a? String
        errors.include? error
      elsif error.is_a? Regexp
        errors.find { |e| e =~ error }
      end
    end
  end

  it 'should have an error when manifest.json is missing' do
    files = [double('AppFile', relative_path: 'abc.json')]
    package = double('Package', files: files)
    expect(package).to have_error 'Could not find manifest.json'
  end

  before do
    @manifest = double('AppFile', relative_path: 'manifest.json', read: '{}')
    @package = double('Package', :files => [@manifest],
                                 :has_location? => true, :has_js? => true, :requirements_only => false, :requirements_only= => nil)
  end

  it 'should have an error when required field is missing' do
    expect(@package).to have_error 'Missing required fields in manifest: author, defaultLocale'
  end

  it 'should have an error when location is missing without requirements' do
    allow(@package).to receive_messages(:has_location? => false)
    expect(@package).to have_error 'Missing required field in manifest: location'
  end

  it 'should have an error when location is defined but requirements only is true' do
    allow(@manifest).to receive_messages(read: MultiJson.dump(requirementsOnly: true, location: 1))
    expect(@package).to have_error :no_location_required
  end

  it 'should not have an error when location is missing but requirements only is true' do
    allow(@manifest).to receive_messages(read: MultiJson.dump(requirementsOnly: true))
    allow(@package).to receive_messages(:has_location? => false)
    expect(@package).not_to have_error 'Missing required field in manifest: location'
  end

  it 'should have an error when frameworkVersion is missing without requirements' do
    expect(@package).to have_error 'Missing required field in manifest: frameworkVersion'
  end

  it 'should have an error when frameworkVersion is defined but requirements only is true' do
    allow(@manifest).to receive_messages(read: MultiJson.dump(requirementsOnly: true, frameworkVersion: 1))
    expect(@package).to have_error :no_framework_version_required
  end

  it 'should not have an error when frameworkVersion is missing with requirements' do
    allow(@manifest).to receive_messages(read: MultiJson.dump(requirementsOnly: true))
    expect(@package).not_to have_error 'Missing required field in manifest: frameworkVersion'
  end

  it 'should have an error when the defaultLocale is invalid' do
    manifest = { 'defaultLocale' => 'pt-BR-1' }
    allow(@manifest).to receive_messages(read: MultiJson.dump(manifest))

    expect(@package).to have_error(/default locale/)
  end

  it 'should have an error when the translation file is missing for the defaultLocale' do
    manifest = { 'defaultLocale' => 'pt' }
    allow(@manifest).to receive_messages(read: MultiJson.dump(manifest))
    translation_files = double('AppFile', relative_path: 'translations/en.json')
    allow(@package).to receive_messages(translation_files: [translation_files])

    expect(@package).to have_error(/Missing translation file/)
  end

  it 'should have an error when the location is invalid' do
    manifest = { 'location' => %w(ticket_sidebar a_invalid_location) }
    allow(@manifest).to receive_messages(read: MultiJson.dump(manifest))

    expect(@package).to have_error(/invalid location/)
  end

  it 'should have an error when there are duplicate locations' do
    manifest = { 'location' => %w(ticket_sidebar ticket_sidebar) }
    allow(@manifest).to receive_messages(read: MultiJson.dump(manifest))

    expect(@package).to have_error(/duplicate/)
  end

  it 'should have an error when the version is not supported' do
    manifest = { 'frameworkVersion' => '0.7' }
    allow(@manifest).to receive_messages(read: MultiJson.dump(manifest))

    expect(@package).to have_error(/not a valid framework version/)
  end

  it 'should have an error when a hidden parameter is set to required' do
    manifest = {
      'parameters' => [
        'name'     => 'a parameter',
        'type'     => 'hidden',
        'required' => true
      ]
    }

    allow(@manifest).to receive_messages(read: MultiJson.dump(manifest))

    expect(@package).to have_error(/set to hidden and cannot be required/)
  end

  it 'should have an error when manifest is not a valid json' do
    manifest = double('AppFile', relative_path: 'manifest.json', read: '}')
    allow(@package).to receive_messages(files: [manifest])

    expect(@package).to have_error(/^manifest is not proper JSON/)
  end

  it 'should have an error when required oauth fields are missing' do
    oauth_hash = {
      'oauth' => {}
    }
    expect(create_package(default_required_params.merge(oauth_hash))).to have_error \
      'Missing required oauth fields in manifest: client_id, client_secret, authorize_uri, access_token_uri'
  end

  context 'with invalid parameters' do
    before do
      allow(ZendeskAppsSupport::Validations::Manifest).to receive(:default_locale_error)
      allow(ZendeskAppsSupport::Validations::Manifest).to receive(:invalid_location_error)
      allow(ZendeskAppsSupport::Validations::Manifest).to receive(:invalid_version_error)
    end

    it 'has an error when the app parameters are not an array' do
      parameter_hash = {
        'parameters' => {
          'name' => 'a parameter',
          'type' => 'text'
        }
      }

      expect(create_package(parameter_hash)).to have_error 'App parameters must be an array.'
    end

    it 'has an error when there is a parameter called "name"' do
      parameter_hash = {
        'parameters' => [{
          'name' => 'name',
          'type' => 'text'
        }]
      }

      expect(create_package(parameter_hash)).to have_error "Can't call a parameter 'name'"
    end

    it "doesn't have an error with an array of app parameters" do
      parameter_hash = {
        'parameters' => [{
          'name' => 'a parameter',
          'type' => 'text'
        }]
      }

      expect(create_package(parameter_hash)).not_to have_error
    end

    it 'behaves when the manifest does not have parameters' do
      expect(create_package(default_required_params)).not_to have_error
    end

    it 'shows error when duplicate parameters are defined' do
      parameter_hash = {
        'parameters' => [
          {
            'name' => 'url',
            'type' => 'text'
          },
          {
            'name' => 'url',
            'type' => 'text'
          }
        ]
      }

      expect(create_package(parameter_hash)).to have_error 'Duplicate app parameters defined: ["url"]'
    end

    it 'has an error when the parameter type is not valid' do
      parameter_hash = {
        'parameters' =>
        [
          {
            'name' => 'should be number',
            'type' => 'integer'
          }
        ]
      }
      expect(create_package(default_required_params.merge(parameter_hash))).to have_error 'integer is an invalid parameter type.'
    end

    it "doesn't have an error with a correct parameter type" do
      parameter_hash = {
        'parameters' =>
        [
          {
            'name' => 'valid type',
            'type' => 'number'
          }
        ]
      }
      expect(create_package(default_required_params.merge(parameter_hash))).not_to have_error
    end
  end
end
