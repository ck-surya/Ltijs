# Visual Search Game LTI Tool

A Learning Tools Interoperability (LTI) 1.3 compliant tool featuring a visual search cognitive psychology experiment.

## Features

- LTI 1.3 compliant tool for Moodle/Canvas integration
- Visual search psychology experiment with reaction time measurement
- Automatic grade passback to LMS
- Docker Compose deployment with Traefik reverse proxy
- MongoDB for data persistence
- Comprehensive logging

## Quick Start

1. **Clone and setup**:
   ```bash
   git clone <repository-url>
   cd Ltijs
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Create Docker network**:
   ```bash
   docker network create web
   ```

3. **Deploy**:
   ```bash
   docker compose up -d --build
   ```

4. **Access**:
   - Tool: https://lti.csbasics.in
   - Traefik Dashboard: http://localhost:8080 (development only)

## Configuration

### Environment Variables (.env)

- `NODE_ENV`: production/development
- `COOKIE_KEY`: JWT signing secret
- `MONGO_ROOT_USERNAME/PASSWORD`: MongoDB credentials
- `FRAME_ANCESTORS`: LMS domains that can embed the tool
- `PLATFORMS`: LMS platform registration details

### LMS Integration

Add the tool to your LMS using:
- **Tool URL**: https://lti.csbasics.in/
- **Login URL**: https://lti.csbasics.in/login
- **Keyset URL**: https://lti.csbasics.in/keys

## Architecture

```
├── server/                 # Node.js LTI application
│   ├── app.js             # Main application
│   └── platform-registry.js
├── public/                # Static files (game)
│   ├── index.html         # Visual search game
│   ├── bitmaps.json       # Game assets
│   └── stimuli_output2.json
├── traefik/               # Reverse proxy config
├── logs/                  # Application logs
└── data/                  # Persistent data
```

## Logs

- Application logs: `logs/app/`
- Traefik logs: `logs/traefik/`
- MongoDB logs: `logs/mongo/`

## Security

- HTTPS termination via Traefik
- Let's Encrypt automatic SSL certificates
- Rate limiting and security headers
- MongoDB authentication
- Docker container isolation

## Development

```bash
# Development mode (without Traefik)
NODE_ENV=development npm run dev

# View logs
docker compose logs -f app
```

## Production

- Remove Traefik dashboard access (port 8080)
- Use dedicated MongoDB user (not root)
- Configure firewall rules
- Monitor logs regularly
