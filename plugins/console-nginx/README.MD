# NGINX Dynamic Plugin Manager

## Overview

This project provides an automated solution for managing a suite of microfrontends (referred to as "plugins") using NGINX as a reverse proxy within a Docker Compose environment. The core goal is to dynamically generate NGINX configurations for multiple plugins and register them with a central console application, all with a single command.

This setup is ideal for a microfrontend architecture where frontend plugins need to be seamlessly integrated and exposed through a single, stable entry point (`http://localhost`).

## Core Components

-   `docker-compose.yaml`: Defines the `nginx` service and connects it to the shared `proxy-network` to communicate with other plugin containers.
-   `nginx/`:
    -   `nginx.conf`: The main NGINX configuration. It sets up the server, defines logging, and includes all configuration files from the `nginx/plugins/` directory. It also contains the default proxy rule for the main `console` application.
    -   `plugins/`: This directory is automatically populated with generated `.conf` files for each plugin.
-   `scripts/`:
    -   `add-plugin.sh`: A powerful script that handles the logic for a single plugin. It generates the NGINX config, reloads NGINX, waits for the plugin to become healthy, and registers it with the console's API.
-   `start.sh`: The main entry point for the user. This script launches the NGINX container and then iterates through command-line arguments, calling `add-plugin.sh` for each plugin-port pair provided.

## Usage

The automation is orchestrated by the following steps:

1.  **Prerequisites**: Ensure the [midaz-console](https://github.com/LerianStudio/midaz/tree/main/components/console) application  is running and accessible to Docker on port `8081`.

2.  **Start Plugins**: Launch the individual plugins you want to manage. For example, to start the CRM plugin:
    ```bash
    cd plugins/plugin-crm && docker-compose up -d
    ```

3.  **Run the NGINX Manager**: Execute the `start.sh` script, providing the Docker service name and port for each plugin you want to add.

    *To add a single plugin:*
    ```bash
    ./start.sh plugin-crm-ui 8082
    ```

    *To add multiple plugins at once:*
    ```bash
    ./start.sh plugin-crm-ui 8082 plugin-fees-ui 8084 plugin-smart-templates-ui 8083
    ```
4.  **Automated Configuration**: The `start.sh` script will then:
    -   Ensure the NGINX container is running.
    -   Generate a specific `.conf` file for each plugin.
    -   Reload NGINX to apply the new routing rules.
    -   Wait for each plugin to be healthy.
    -   Register each plugin with the `midaz-console` via an API call.

5.  **Access the Console**: Once the script completes, the new plugins will be available in the main console UI. You can access the entire application suite at **`http://localhost`**.

## Console environment variables

To run the console behind this NGINX reverse proxy, set the console URLs to the NGINX service:

- **NEXTAUTH_URL** → http://localhost
- **NEXT_PUBLIC_MIDAZ_CONSOLE_BASE_URL** → http://localhost
- **MIDAZ_CONSOLE_BASE_PATH** → http://localhost

If you expose NGINX with a different DNS name or base path, use that instead (for example, `http://midaz-nginx` or a custom path).