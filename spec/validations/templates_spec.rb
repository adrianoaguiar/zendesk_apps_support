require 'spec_helper'

describe ZendeskAppsSupport::Validations::Templates do

  it 'should have a jslint error when missing semicolon' do
    template = double('AppFile', :relative_path => 'layout.hdbs', :read => "<style>")
    package = double('Package', :template_files => [template])
    errors = ZendeskAppsSupport::Validations::Templates.call(package)

    errors.first().to_s.should eql "<style> tag in layout.hdbs. Use an app.css file instead."
  end

end
