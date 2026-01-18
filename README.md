# All-in-One Hackazon

A Docker-based containerized environment for [Hackazon](https://github.com/rapid7/hackazon) - a deliberately vulnerable web application for security testing and training.

## What is Hackazon?

Hackazon is a free, vulnerable test site designed by Rapid7 for testing security tools. It simulates a realistic e-commerce application with intentional security vulnerabilities including:

- SQL Injection
- Cross-Site Scripting (XSS)
- Cross-Site Request Forgery (CSRF)
- Remote/Local File Inclusion
- And many more OWASP Top 10 vulnerabilities

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2.0+ (optional, for easier deployment)

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/all-in-one-hackazon.git
cd all-in-one-hackazon

# Build and run
docker compose up -d

# View logs to get credentials
docker compose logs -f
```

### Using Docker directly

```bash
# Build the image
docker build -t hackazon .

# Run the container
docker run -d --name hackazon -p 80:80 hackazon

# View logs to get credentials
docker logs -f hackazon
```

## Accessing Hackazon

Once the container is running, access Hackazon at:

```
http://localhost
```

### Default Credentials

Credentials are randomly generated on each container start. To view them:

```bash
# View startup logs
docker logs hackazon

# Or read the credentials file
docker exec hackazon cat /credentials.txt
```

## Container Architecture

| Component | Description |
|-----------|-------------|
| Ubuntu 22.04 | Base operating system |
| Apache 2.4 | Web server |
| PHP 8.x | Server-side scripting |
| MySQL 8.0 | Database server |
| Supervisor | Process manager |

## Project Structure

```
.
├── Dockerfile              # Container definition
├── docker-compose.yml      # Docker Compose configuration
├── configs/
│   ├── 000-default.conf    # Apache virtual host configuration
│   ├── supervisord.conf    # Supervisor process manager config
│   ├── parameters.php      # Hackazon application parameters
│   ├── rest.php            # REST API configuration
│   └── createdb.sql        # Database schema
├── scripts/
│   ├── start.sh            # Container startup script
│   ├── foreground.sh       # Apache foreground runner
│   └── passwordHash.php    # Password hashing utility
└── README.md
```

## Security Warning

**This application is intentionally vulnerable and should NEVER be:**

- Deployed on a public network
- Used in production environments
- Connected to systems containing real data

Use only in isolated environments for:
- Security training
- Penetration testing practice
- Security tool testing

## Stopping the Container

```bash
# Using Docker Compose
docker compose down

# Using Docker directly
docker stop hackazon && docker rm hackazon
```

## Troubleshooting

### Container won't start

Check the logs for errors:
```bash
docker logs hackazon
```

### Can't access the web interface

1. Ensure the container is running: `docker ps`
2. Check if port 80 is available: `netstat -tlnp | grep :80`
3. Verify the health check: `docker inspect hackazon | grep -A 10 Health`

### MySQL errors

The MySQL data is initialized fresh on each container start. If you encounter database errors, try rebuilding:
```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

## Credits

- Original Hackazon project by [Rapid7](https://github.com/rapid7/hackazon)
- Docker wrapper based on work by [cmutzel](https://github.com/cmutzel/all-in-one-hackazon)
- Maintained and modernized by v0rt3x

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details.
