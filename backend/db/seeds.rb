# db/seeds.rb

puts "Starting seed process..."

# Clear existing data - Removed ConnectorMention since it's not created yet
puts "Clearing existing data..."
Connector.destroy_all
Category.destroy_all

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
  begin
    Category.create!(category_data)
    print "."
  rescue => e
    puts "\nError creating category #{category_data[:name]}: #{e.message}"
  end
end

puts "\nCreated #{Category.count} categories"

# Create connectors with appropriate categories
puts "\nCreating connectors..."
connectors_data = [
  {
    name: "Salesforce",
    description: "CRM and sales platform",
    categories: ["Sales And Marketing", "Customer Service"]
  },
  {
    name: "Jira",
    description: "Project and issue tracking",
    categories: ["Product/Project Management", "Developer"]
  },
  {
    name: "Zendesk",
    description: "Customer service and support",
    categories: ["Customer Service", "Collaboration"]
  },
  {
    name: "Workday",
    description: "HR management platform",
    categories: ["HR", "Operations"]
  },
  {
    name: "QuickBooks",
    description: "Accounting software",
    categories: ["Finance And Accounting"]
  }
]

# Create connectors and associate with categories
connectors_data.each do |connector_data|
  begin
    puts "\nCreating connector: #{connector_data[:name]}"
    connector = Connector.new(
      name: connector_data[:name],
      description: connector_data[:description]
    )

    # Find categories before saving
    categories = Category.where(name: connector_data[:categories])
    if categories.empty?
      puts "Warning: No categories found for #{connector_data[:name]}: #{connector_data[:categories].join(', ')}"
    else
      puts "Found categories: #{categories.pluck(:name).join(', ')}"
    end

    # Save connector
    if connector.save
      connector.categories << categories
      puts "Successfully created connector #{connector_data[:name]}"
    else
      puts "Failed to save connector #{connector_data[:name]}: #{connector.errors.full_messages.join(', ')}"
    end
  rescue => e
    puts "Error creating connector #{connector_data[:name]}: #{e.message}"
    puts e.backtrace.join("\n")
  end
end

puts "\nSeeding completed!"
puts "Created #{Category.count} categories"
puts "Created #{Connector.count} connectors"
puts "Created #{CategoriesConnector.count} category-connector associations"