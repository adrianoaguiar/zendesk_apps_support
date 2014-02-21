require 'spec_helper'

describe ZendeskAppsSupport::Validations::Manifest do

  def default_required_params(overrides = {})
    valid_fields = ZendeskAppsSupport::Validations::Manifest::REQUIRED_MANIFEST_FIELDS.inject({ :frameworkVersion => '1.0' }) do |fields, name|
      fields[name] = name
      fields
    end

    valid_fields.merge(overrides)
  end

  def create_package(parameter_hash)
    params = default_required_params(parameter_hash)
    @manifest.stub(:read => MultiJson.dump(params))
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
    files = [mock('AppFile', :relative_path => 'abc.json')]
    package = mock('Package', :files => files)
    package.should have_error 'Could not find manifest.json'
  end

  before do
    @manifest = mock('AppFile', :relative_path => 'manifest.json', :read => "{}")
    @package = mock('Package', :files => [@manifest],
      :has_location? => true, :has_js? => true, :requirements_only => false, :requirements_only= => nil)
  end

  it 'should have an error when required field is missing' do
    @package.should have_error 'Missing required fields in manifest: author, defaultLocale'
  end

  it 'should have an error when location is missing without requirements' do
    @package.stub(:has_location? => false)
    @package.should have_error 'Missing required field in manifest: location'
  end

  it 'should have an error when location is defined but requirements only is true' do
    @manifest.stub(:read => MultiJson.dump(:requirementsOnly => true, :location => 1))
    @package.should have_error 'Having location defined while requirements only is true'
  end

  it 'should not have an error when location is missing but requirements only is true' do
    @manifest.stub(:read => MultiJson.dump(:requirementsOnly => true))
    @package.stub(:has_location? => false)
    @package.should_not have_error 'Missing required field in manifest: location'
  end

  it 'should have an error when frameworkVersion is missing without requirements' do
    @package.should have_error 'Missing required field in manifest: frameworkVersion'
  end

  it 'should have an error when frameworkVersion is defined but requirements only is true' do
    @manifest.stub(:read => MultiJson.dump(:requirementsOnly => true, :frameworkVersion => 1))
    @package.should have_error 'Having framework version defined while requirements only is true'
  end

  it 'should not have an error when frameworkVersion is missing with requirements' do
    @manifest.stub(:read => MultiJson.dump(:requirementsOnly => true))
    @package.should_not have_error 'Missing required field in manifest: frameworkVersion'
  end

  it 'should have an error when the defaultLocale is invalid' do
    manifest = { 'defaultLocale' => 'pt-BR-1' }
    @manifest.stub(:read => MultiJson.dump(manifest))

    @package.should have_error /default locale/
  end

  it 'should have an error when the translation file is missing for the defaultLocale' do
    manifest = { 'defaultLocale' => 'pt' }
    @manifest.stub(:read => MultiJson.dump(manifest))
    translation_files = mock('AppFile', :relative_path => 'translations/en.json')
    @package.stub(:translation_files => [translation_files])

    @package.should have_error /Missing translation file/
  end

  it 'should have an error when the location is invalid' do
    manifest = { 'location' => ['ticket_sidebar', 'a_invalid_location'] }
    @manifest.stub(:read => MultiJson.dump(manifest))

    @package.should have_error /invalid location/
  end

  it 'should have an error when there are duplicate locations' do
    manifest = { 'location' => ['ticket_sidebar', 'ticket_sidebar'] }
    @manifest.stub(:read => MultiJson.dump(manifest))

    @package.should have_error /duplicate/
  end

  it 'should have an error when the version is not supported' do
    manifest = { 'frameworkVersion' => '0.7' }
    @manifest.stub(:read => MultiJson.dump(manifest))

    @package.should have_error /not a valid framework version/
  end

  it 'should have an error when a hidden parameter is set to required' do
    manifest = {
      'parameters' => [
        'name'     => 'a parameter',
        'type'     => 'hidden',
        'required' => true
      ]
    }

    @manifest.stub(:read => MultiJson.dump(manifest))

    @package.should have_error /set to hidden and cannot be required/
  end

  it 'should have an error when manifest is not a valid json' do
    manifest = mock('AppFile', :relative_path => 'manifest.json', :read => "}")
    @package.stub(:files => [manifest])

    @package.should have_error /^manifest is not proper JSON/
  end

  it "should have an error when required oauth fields are missing" do
    oauth_hash = {
      "oauth" => {}
    }
    create_package(default_required_params.merge(oauth_hash)).should have_error \
      "Missing required oauth fields in manifest: client_id, client_secret, authorize_uri, access_token_uri"
  end

  context 'with invalid parameters' do

    before do
      ZendeskAppsSupport::Validations::Manifest.stub(:default_locale_error)
      ZendeskAppsSupport::Validations::Manifest.stub(:invalid_location_error)
      ZendeskAppsSupport::Validations::Manifest.stub(:invalid_version_error)
    end

    it 'has an error when the app parameters are not an array' do
      parameter_hash = {
          'parameters' => {
              'name' => 'a parameter',
              'type' => 'text'
          }
      }

      create_package(parameter_hash).should have_error 'App parameters must be an array.'
    end

    it 'has an error when there is a parameter called "name"' do
      parameter_hash = {
          'parameters' => [{
              'name' => 'name',
              'type' => 'text'
          }]
      }

      create_package(parameter_hash).should have_error "Can't call a parameter 'name'"
    end

    it "doesn't have an error with an array of app parameters" do
      parameter_hash = {
          'parameters' => [{
              'name' => 'a parameter',
              'type' => 'text'
          }]
      }

      create_package(parameter_hash).should_not have_error
    end

    it 'behaves when the manifest does not have parameters' do
      create_package(default_required_params).should_not have_error
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

      create_package(parameter_hash).should have_error 'Duplicate app parameters defined: ["url"]'
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
      create_package(default_required_params.merge(parameter_hash)).should have_error "integer is an invalid parameter type."
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
      create_package(default_required_params.merge(parameter_hash)).should_not have_error
    end
  end
end
