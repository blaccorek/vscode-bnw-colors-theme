# Theme samples

Files used to eyeball the theme's syntax highlighting across languages. Each one
deliberately packs in as many token types as possible: comments, strings,
numbers, keywords, types, functions, operators, decorators/annotations, regex
literals and error/edge constructs.

## Web

| File                                   | Language                    |
| :------------------------------------- | :-------------------------- |
| [web/app.ts](web/app.ts)               | TypeScript                  |
| [web/component.tsx](web/component.tsx) | TSX / React                 |
| [web/main.js](web/main.js)             | JavaScript                  |
| [web/index.html](web/index.html)       | HTML (with inline CSS + JS) |
| [web/styles.css](web/styles.css)       | CSS                         |
| [web/theme.scss](web/theme.scss)       | SCSS                        |

## Backend

| File                                                     | Language |
| :------------------------------------------------------- | :------- |
| [backend/service.py](backend/service.py)                 | Python   |
| [backend/server.go](backend/server.go)                   | Go       |
| [backend/lib.rs](backend/lib.rs)                         | Rust     |
| [backend/Service.cs](backend/Service.cs)                 | C#       |
| [backend/engine.cpp](backend/engine.cpp)                 | C++      |
| [backend/Application.kt](backend/Application.kt)         | Kotlin   |
| [backend/Service.swift](backend/Service.swift)           | Swift    |
| [backend/UserController.php](backend/UserController.php) | PHP      |
| [backend/user_service.rb](backend/user_service.rb)       | Ruby     |
| [backend/UserService.java](java/UserService.java)        | Java     |

## Infrastructure

| File                                                 | Language                    |
| :--------------------------------------------------- | :-------------------------- |
| [infra/main.tf](infra/main.tf)                       | Terraform / HCL             |
| [infra/terraform.tfvars](infra/terraform.tfvars)     | Terraform variables         |
| [infra/deployment.yaml](infra/deployment.yaml)       | YAML — Kubernetes manifests |
| [infra/ci.yml](infra/ci.yml)                         | YAML — GitHub Actions       |
| [infra/docker-compose.yml](infra/docker-compose.yml) | YAML — Docker Compose       |
| [infra/playbook.yml](infra/playbook.yml)             | YAML — Ansible              |
| [infra/Dockerfile](infra/Dockerfile)                 | Dockerfile                  |
| [infra/Makefile](infra/Makefile)                     | Makefile                    |
| [infra/nginx.conf](infra/nginx.conf)                 | nginx configuration         |
| [infra/config.toml](infra/config.toml)               | TOML                        |
| [infra/app.ini](infra/app.ini)                       | INI                         |
| [infra/env.sample](infra/env.sample)                 | dotenv                      |

## Data and markup

| File                                                 | Language                     |
| :--------------------------------------------------- | :--------------------------- |
| [data/schema.sql](data/schema.sql)                   | SQL (PostgreSQL)             |
| [data/package.sample.json](data/package.sample.json) | JSON                         |
| [data/README.sample.md](data/README.sample.md)       | Markdown (with front matter) |
| [data/config.xml](data/config.xml)                   | XML                          |
| [data/schema.graphql](data/schema.graphql)           | GraphQL SDL                  |
| [data/user.proto](data/user.proto)                   | Protocol Buffers             |

## Shell

| File                                   | Language   |
| :------------------------------------- | :--------- |
| [script/hello.sh](script/hello.sh)     | Bash       |
| [script/hello.fish](script/hello.fish) | fish       |
| [script/deploy.ps1](script/deploy.ps1) | PowerShell |

None of these files are packaged into the extension — see
[.vscodeignore](../.vscodeignore).
