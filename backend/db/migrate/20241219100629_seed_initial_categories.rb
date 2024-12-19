class SeedInitialCategories < ActiveRecord::Migration[7.0]
  def up
    initial_categories = [
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
      { name: 'Other', description: 'Other tools and services' },
    ]

    initial_categories.each do |category|
      execute <<-SQL
        INSERT INTO categories (name, description, created_at, updated_at)
        VALUES ('#{category[:name]}', '#{category[:description]}', NOW(), NOW())
      SQL
    end
  end

  def down
    execute "TRUNCATE categories CASCADE"
  end
end