# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

Capybara.register_driver :quiet_webkit do |app|
  Capybara::Webkit::Driver.new(app, stderr: QTBugWorkAroundOutputter.new)
end

class QTBugWorkAroundOutputter
  IGNOREABLE = /CoreText performance/

  def write(message)
    if message =~ IGNOREABLE
      0
    else
      puts(message)
      1
    end
  end
end

RSpec.configure do |config|
  Capybara.javascript_driver = :quiet_webkit

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"
  config.include FeatureHelper, type: :feature
  config.include FactoryGirl::Syntax::Methods

  config.use_transactional_fixtures = true

  config.before(:each, js: true) do
    self.use_transactional_fixtures = false
    ActiveRecord::Base.establish_connection
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  config.after(:each, js: true) do
    DatabaseCleaner.clean
    ActiveRecord::Base.establish_connection
    self.use_transactional_fixtures = true
  end

  config.before(:all) do
    FactoryGirl.reload
  end
end
