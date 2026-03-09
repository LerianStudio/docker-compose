# Access Manager Plugin

## Quick Start

1. **Clone the Repository:**
```bash
git clone https://github.com/LerianStudio/plugins-docker-compose.git
```

2. **Go to the plugin directory:**
```bash
cd plugins/plugin-access-manager
```
3. **Run the Docker Compose File**
```bash
docker compose --env-file auth.env --env-file identity.env up
```
   
5. **Access the API:**
Visit `http://localhost:4001` to interact with the Identity API.
Visit `http://localhost:4000` to interact with the Auth API.

6. [Visit our Documentation](https://docs.lerian.studio/en/platform/access-manager/access-manager#what-is-access-manager)