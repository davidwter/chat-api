# config/initializers/httparty.rb
HTTParty::Basement.default_options.merge!(
  timeout: 120,
  verify: false  # Skip SSL verification if needed
)