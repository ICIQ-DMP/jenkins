<a id="readme-top"></a>

<!-- PROJECT SHIELDS -->
[![GPLv3 License][license-shield]][license-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <h3 align="center">ICIQ DMP Jenkins</h3>

  <p align="center">
    Shared Jenkins + nginx reverse-proxy stack used to trigger and run ICIQ DMP automations
    <br />
    <a href="https://github.com/ICIQ-DMP/jenkins/issues">Report Bug</a>
    &middot;
    <a href="https://github.com/ICIQ-DMP/jenkins/issues">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#architecture">Architecture</a></li>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#configuration">Configuration</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project

This repository provisions the Jenkins instance that ICIQ DMP automations run and trigger their jobs on.

It used to live inside the `auto-justifications` ("Justicier") project as a single Jenkins container coupled to
that one automation. As more automations started depending on the same Jenkins, it was extracted into its own
repository so the infrastructure (Jenkins + reverse proxy) can be versioned, deployed, and reasoned about
independently of any single automation's job code, which now lives in each automation's own repository.

### Architecture

The stack is two containers, wired together with Docker Compose:

* **`jenkins`** — `jenkins/jenkins:lts`, holding all job definitions and running builds. Not published directly;
  only reachable from `nginx` over the internal Compose network.
* **`nginx`** — reverse proxy and the only container with a published port. It deliberately exposes a narrow
  allowlist instead of the whole Jenkins UI:
  * `GET /crumbIssuer/api/json` — CSRF crumb issuance, needed before triggering a build.
  * `POST /job/<any-job>/buildWithParameters` — trigger any job by name. This is what automations call remotely.
  * `/` (the full Jenkins UI) — restricted to an admin IP allowlist (`NGINX_ADMIN_IP`), everything else denied.
  * `/healthz` — used by the container healthcheck.

nginx's config is not committed as a static file: `service/nginx/conf/nginx.conf` and `proxy_params` are
templates containing `${PLACEHOLDER}` variables (server name, admin IP, listen port, Jenkins upstream). At
container start, nginx's own `docker-entrypoint.d/20-envsubst-on-templates.sh` renders them into the running
config using the values Compose reads from `.env`. See [Configuration](#configuration).

### Built With

* [Jenkins](https://www.jenkins.io/) (`jenkins/jenkins:lts`)
* [nginx](https://nginx.org/) (`nginx:stable`)
* [Docker Compose](https://docs.docker.com/compose/)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

* Docker and the Docker Compose plugin
* A Unix host user/group to own `service/jenkins_home` (the Jenkins container runs as this `HOST_UID:HOST_GID`, not root)

### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/ICIQ-DMP/jenkins.git
   cd jenkins
   ```
2. Copy the environment template and adjust it for your deployment
   ```sh
   cp .env.example .env
   ```
3. Bring the stack up
   ```sh
   docker compose up -d
   ```
   `service/jenkins_home` and `service/nginx_logs` are created automatically on first run (bind mounts) and are
   gitignored, since they're runtime state, not configuration.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE EXAMPLES -->
## Usage

Automations trigger their Jenkins job remotely through nginx: fetch a CSRF crumb, then POST to
`buildWithParameters` with the job's build token and parameters. `scripts/run_workflow.sh` is a runnable example
of that flow:

```sh
./scripts/run_workflow.sh <job-name> [param=value ...]

# e.g.
./scripts/run_workflow.sh run-justicier ID=33 cause=automated+workflow
```

It reads `NGINX_SERVER_NAME` and `JENKINS_API_USER` from `.env`, and the actual credentials from `secrets/`
(gitignored, one value per file): `JENKINS_API_TOKEN`, `JENKINS_BUILD_TOKEN`. Only real credentials live under
`secrets/` — everything else belongs in `.env`, so the token files stay easy to swap for a Vault- or
Docker-secrets-backed mount later without touching the rest of the configuration.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONFIGURATION -->
## Configuration

All configuration is environment-driven via `.env` (see `.env.example`):

| Variable                 | Purpose                                                              |
|---------------------------|-----------------------------------------------------------------------|
| `JENKINS_PORT_EXTERNAL`  | Host port Jenkins is published on (not routed through nginx)         |
| `JENKINS_PORT_INTERNAL`  | Port Jenkins listens on inside its container                         |
| `FIREWALL_PORT_EXTERNAL` | Host port nginx is published on — the actual public entrypoint       |
| `FIREWALL_PORT_INTERNAL` | Port nginx listens on inside its container                           |
| `HOST_UID` / `HOST_GID`   | Host user/group that owns `service/jenkins_home`                     |
| `NGINX_SERVER_NAME`      | `server_name` nginx serves and validates; also the host `scripts/run_workflow.sh` targets |
| `NGINX_ADMIN_IP`         | Single IP allowed to reach the full Jenkins UI through nginx         |
| `JENKINS_API_USER`       | Jenkins username `scripts/run_workflow.sh` authenticates as (not sensitive by itself) |

Actual credentials (`JENKINS_API_TOKEN`, `JENKINS_BUILD_TOKEN`) are kept out of `.env` and read from `secrets/`
instead — one value per file — so they can't leak through something that dumps `.env` or `docker compose config`
wholesale, and so they map directly onto a Vault- or Docker-secrets-style file mount if one is introduced later.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ROADMAP -->
## Roadmap

- [ ] Restore CI/build-agent capability (a previous SSH `agent` container was removed during the extraction from
      `auto-justifications` and has not been replaced yet)
- [ ] Document the process for onboarding a new automation's job onto this shared Jenkins

See the [open issues](https://github.com/ICIQ-DMP/jenkins/issues) for the full list.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- LICENSE -->
## License

Distributed under the GPLv3 License. See `LICENSE` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

ICIQ DMP — digitalitzacio@iciq.es

Project Link: [https://github.com/ICIQ-DMP/jenkins](https://github.com/ICIQ-DMP/jenkins)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
[license-shield]: https://img.shields.io/badge/license-GPLv3-blue.svg
[license-url]: https://github.com/ICIQ-DMP/jenkins/blob/master/LICENSE
