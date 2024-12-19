You're absolutely right! If we're using Docker for everything, we only need Docker as a prerequisite. Let me revise the setup instructions:

# AI Integration Assistant

An AI-powered chat application evolving into an integration assistant. Built with Rails API backend, React frontend, and Ollama (Mistral model) for AI responses. The system supports multiple conversations, real-time chat, and will help users understand and create Workato integrations.

## Development Roadmap

### Version 1 - Basic Chat Interface
- Simple React chat interface
- Integration with Llama 2 for basic conversation
- Focus on natural language understanding of integration requests
- No specific Workato knowledge required

### Version 2 - Connector Awareness
- Enhanced chat with knowledge of connector names/existence
- Ability to identify which connectors would be needed for an integration
- Can tell user "This would involve QuickBooks and Fieldwire connectors"
- No deep knowledge of connector capabilities yet

### Version 3 - Capability Analysis
- Deep understanding of each connector's capabilities
- Can identify if an integration is technically possible
- Ability to highlight missing capabilities
- Clear feedback on what needs to be added to connectors

### Version 4 - Recipe Generation
- Suggests basic recipe structure
- Includes main steps needed
- Identifies triggers and actions
- Provides a skeleton that can be imported to Workato

## Prerequisites

- Docker Desktop (with at least 4GB of memory allocated)
- Git

## Local Development Setup

### Step 1: Clone and Configure Repository

1. Clone the repository:
```bash
git clone [repository-url]
cd [project-directory]
```

2. Create a `.env` file in the root directory:
```bash
RAILS_MASTER_KEY=[your-master-key]
```

### Step 2: Start the Development Environment

1. Build and start all services:
```bash
docker-compose up --build
```

This will start:
- PostgreSQL database (port 5432)
- Rails API backend (port 3000)
- React frontend (port 5173)
- Ollama service (port 11434)

### Step 3: Set up the Database

1. In a new terminal, run:
```bash
docker-compose exec api rails db:create db:migrate
```

### Step 4: Download Required AI Model

1. In a new terminal, run:
```bash
docker-compose exec ollama ollama pull mistral
```

### Step 5: Verify Installation

1. Verify services are running:
```bash
docker-compose ps
```

2. Check API health endpoint:
```bash
curl http://localhost:3000/api/v1/health/check
```

3. Access the frontend:
- Open `http://localhost:5173` in your browser
- You should see the chat interface

## Troubleshooting Common Issues

1. If the database connection fails:
```bash
docker-compose down -v
docker-compose up --build
```

2. If the frontend can't connect to the API:
- Verify CORS settings in `backend/config/initializers/cors.rb`
- Check that the `VITE_API_URL` environment variable is set correctly

3. If Ollama service fails:
- Verify Docker has enough memory allocated (recommended: 4GB+)
- Check Ollama logs: `docker-compose logs ollama`

4. If hot reload isn't working:
- Verify file watching is enabled in your Docker Desktop settings
- Check that the volumes are properly mounted in `docker-compose.yml`

## Development Workflow

1. Backend changes:
- Changes to Ruby files will auto-reload in development
- Database changes require running migrations: `docker-compose exec api rails db:migrate`

2. Frontend changes:
- Vite provides hot module replacement automatically
- New dependencies require rebuilding: `docker-compose up --build frontend`

3. Accessing logs:
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f [service-name]
```

## Running Tests

1. Backend tests:
```bash
docker-compose exec api rspec
```

2. Frontend tests (when implemented):
```bash
docker-compose exec frontend npm test
```

## QA Testing Checklist

### Basic Functionality Testing
- [ ] Conversation creation
- [ ] Message sending/receiving
- [ ] Conversation switching
- [ ] Error handling for failed messages
- [ ] Loading states and indicators

### UI/UX Testing
- [ ] Responsiveness across different screen sizes
- [ ] Chat input behavior (send on Enter, disable during loading)
- [ ] Message timestamps and status indicators
- [ ] Conversation list scrolling and layout
- [ ] Message formatting and alignment

### API Integration Tests
- [ ] API endpoints for conversations and messages
- [ ] Error handling for network failures
- [ ] Status codes and response formats
- [ ] CORS configuration
- [ ] Timeout handling (180 seconds)

### Database Testing
- [ ] Message persistence
- [ ] Conversation creation and retrieval
- [ ] Relationship between messages and conversations
- [ ] Index performance for larger datasets

### Docker Environment
- [ ] All services start correctly
- [ ] Inter-service communication
- [ ] Environment variables and configuration
- [ ] Volume persistence
- [ ] Hot reload functionality in development

### Edge Cases
- [ ] Very long messages handling
- [ ] Rapid message sending behavior
- [ ] System response under poor network conditions
- [ ] Concurrent conversation handling
- [ ] Failed message states cleanup

## Additional Notes

- The Mistral model download might take several minutes depending on your internet connection
- Initial startup might be slower due to Docker building images
- Make sure ports 3000, 5173, 5432, and 11434 are available on your machine
- All development is done within Docker containers - no local Ruby or Node.js installation required

## Stopping the Application

To stop all services:
```bash
docker-compose down
```

To stop all services and remove volumes (will delete database data):
```bash
docker-compose down -v
```

I've simplified the setup process to rely entirely on Docker, removed unnecessary local installation steps, and updated all commands to run within Docker containers. Is there anything else you'd like me to clarify or modify?
