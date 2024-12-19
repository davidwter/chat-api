# db/seeds.rb

require 'json'

puts "Starting seed process..."

# Clear existing data
puts "Clearing existing data..."
Connector.destroy_all
Category.destroy_all
ConnectorTrigger.destroy_all
ConnectorAction.destroy_all

# Create categories
puts "Creating categories..."
categories = [
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

categories.each do |category_data|
  Category.create!(category_data)
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
puts "\nCreating connectors from JSON..."
connectors_data = load_connectors_from_json(connectors_file_path)

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

# Create Fieldwire connector
puts "\nCreating Fieldwire connector and its capabilities..."

fieldwire = Connector.create!(
  name: "Fieldwire",
  description: "Construction project management platform for real-time collaboration"
)

# Associate relevant categories
fieldwire.categories << Category.where(name: ['Product/Project Management', 'Collaboration', 'Operations'])

# Create triggers
puts "\nCreating Fieldwire triggers..."
fieldwire.connector_triggers.create!([
                                       {
                                         name: "New event",
                                         description: "Triggers when any of the tracked entities is updated in Fieldwire",
                                         feature_attributes: {
                                           badge: "Real-time",
                                           details: "Supports entity filtering and webhook notifications"
                                         }
                                       }
                                     ])

# Create actions
puts "\nCreating Fieldwire actions..."
fieldwire.connector_actions.create!([
                                      {
                                        name: "Batch actions on files",
                                        description: "Perform add/update/rename/restore/delete actions in batch on files",
                                        feature_attributes: {
                                          supports_pagination: true
                                        }
                                      },
                                      {
                                        name: "Batch actions on plans",
                                        description: "Add files to plans with batch processing support",
                                        feature_attributes: {
                                          supports_pagination: true
                                        }
                                      },
                                      {
                                        name: "Batch actions on folders",
                                        description: "Perform add/rename/restore/delete actions in batch on folders",
                                        feature_attributes: {
                                          supports_pagination: true,
                                          requires_hierarchical_order: true
                                        }
                                      },
                                      {
                                        name: "Batch check files existence",
                                        description: "Check the existence of files in batch",
                                        feature_attributes: {
                                          supports_pagination: true
                                        }
                                      },
                                      {
                                        name: "Batch check folders existence",
                                        description: "Check the existence of folders in batch",
                                        feature_attributes: {
                                          supports_pagination: true
                                        }
                                      },
                                      {
                                        name: "Batch check plans existence",
                                        description: "Check the existence of plans in batch",
                                        feature_attributes: {
                                          supports_pagination: true
                                        }
                                      },
                                      {
                                        name: "Batch delete files & folders",
                                        description: "Delete files and folders in batch",
                                        feature_attributes: {
                                          supports_pagination: true
                                        }
                                      },
                                      {
                                        name: "Upload file",
                                        description: "Upload a file to S3",
                                        feature_attributes: {
                                          supports_binary: true
                                        }
                                      },
                                      {
                                        name: "Supervise automation",
                                        description: "Control automation workflows with multiple sub-actions",
                                        feature_attributes: {
                                          supported_actions: [
                                            "start_recipe",
                                            "init_sync_recipe",
                                            "mark_recipe_on_error",
                                            "mark_connection_on_error"
                                          ]
                                        }
                                      },
                                      {
                                        name: "Expand item",
                                        description: "Expand a Fieldwire entity to fetch pre-defined nested attributes",
                                        feature_attributes: {}
                                      },
                                      {
                                        name: "Verify emails",
                                        description: "Check if emails are invitable to the account or already attached",
                                        feature_attributes: {}
                                      },
                                      {
                                        name: "Invite user to account",
                                        description: "Invite users to the Fieldwire account",
                                        feature_attributes: {}
                                      },
                                      {
                                        name: "Remove users from account",
                                        description: "Remove users from the account and all associated projects",
                                        feature_attributes: {}
                                      }
                                    ])

puts "\nSeeding completed!"
puts "Created #{Category.count} categories"
puts "Created #{Connector.count} connectors"
puts "Created #{ConnectorTrigger.count} triggers"
puts "Created #{ConnectorAction.count} actions"
puts "Created #{CategoriesConnector.count} category-connector associations"