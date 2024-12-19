# db/seeds.rb

require 'json'

puts "Starting seed process..."

# Clear existing data
puts "Clearing existing data..."
Connector.destroy_all
Category.destroy_all
ConnectorTrigger.destroy_all
ConnectorAction.destroy_all

# Create default categories if they don't exist
puts "Creating default categories..."
default_categories = [
  { name: 'Sales And Marketing', description: 'Sales and marketing automation tools' },
  { name: 'Product/Project Management', description: 'Customer relationship management systems' },
  { name: 'Customer Service', description: 'Project management and collaboration tools' },
  { name: 'HR', description: 'Human resources and recruiting software' },
  { name: 'Finance And Accounting', description: 'Accounting and financial management software' },
  { name: 'Developer', description: 'Software development and collaboration tools' },
  { name: 'DevOps/IT', description: 'Infrastructure and network management' },
  { name: 'Productivity', description: 'Productivity and task management tools' },
  { name: 'AI/Machine Learning', description: 'Artificial intelligence and machine learning tools' },
  { name: 'Operations', description: 'Operations and supply chain management software' },
  { name: 'Collaboration', description: 'Collaboration and communication tools' },
  { name: 'Recipe Tools', description: 'Recipe management for Workato' },
  { name: 'Other', description: 'Other tools and services' }
]

default_categories.each do |category_data|
  Category.find_or_create_by!(name: category_data[:name]) do |category|
    category.description = category_data[:description]
  end
end

# Load connectors from JSON file
def load_connectors_from_json(file_path)
  # Ensure the file exists
  unless File.exist?(file_path)
    puts "ERROR: Connectors JSON file not found at #{file_path}"
    return []
  end

  # Read and parse the JSON file
  begin
    JSON.parse(File.read(file_path))
  rescue JSON::ParserError => e
    puts "ERROR: Failed to parse JSON file - #{e.message}"
    []
  end
end

# Path to the connectors JSON file
connectors_file_path = Rails.root.join('db', 'connectors.json')

# Load connectors from JSON
connectors_data = load_connectors_from_json(connectors_file_path)

puts "\nCreating connectors from JSON..."

connectors_data.each do |connector_data|
  begin
    # Create the connector
    connector = Connector.create!(
      name: connector_data['name'],
      description: "Connector for #{connector_data['name']}"
    )

    # Add some default categories based on name (you might want to refine this logic)
    default_category_names = ['Collaboration', 'Productivity']
    categories = Category.where(name: default_category_names)
    connector.categories << categories if categories.any?

    # Create triggers
    if connector_data['triggers']
      connector_data['triggers'].each do |trigger_data|
        connector.connector_triggers.create!(
          name: trigger_data['name'],
          description: trigger_data['description'],
          feature_attributes: trigger_data['attributes'] || {}
        )
      end
    end

    # Create actions
    if connector_data['actions']
      connector_data['actions'].each do |action_data|
        connector.connector_actions.create!(
          name: action_data['name'],
          description: action_data['description'],
          feature_attributes: action_data['attributes'] || {}
        )
      end
    end

    puts "Successfully created connector: #{connector.name}"
  rescue => e
    puts "Error creating connector #{connector_data['name']}: #{e.message}"
    puts e.backtrace.join("\n")
  end
end

puts "\nSeeding completed!"
puts "Created #{Category.count} categories"
puts "Created #{Connector.count} connectors"
puts "Created #{ConnectorTrigger.count} triggers"
puts "Created #{ConnectorAction.count} actions"