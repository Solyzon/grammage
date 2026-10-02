<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-white.svg">
    <img src="assets/logo.svg" alt="Grammage" height="64">
  </picture>

  <h1>grammage</h1>

  <p>The CI templates of Grammage, the eco-design audit that weighs the carbon footprint of a website on every pull request and certifies it in production with a signed badge, on GitHub Actions, GitLab CI, Bitbucket Pipelines, Azure DevOps and any other CI.</p>

  <p>
    <img alt="GitHub Actions" src="https://img.shields.io/badge/GitHub_Actions-action-2088FF?style=flat-square&logo=githubactions&logoColor=white">
    <img alt="GitLab CI" src="https://img.shields.io/badge/GitLab_CI-template-FC6D26?style=flat-square&logo=gitlab&logoColor=white">
    <img alt="Bitbucket Pipelines" src="https://img.shields.io/badge/Bitbucket-pipelines-0052CC?style=flat-square&logo=bitbucket&logoColor=white">
    <img alt="Azure DevOps" src="https://img.shields.io/badge/Azure_DevOps-pipelines-0078D7?style=flat-square&logo=azuredevops&logoColor=white">
    <img alt="License" src="https://img.shields.io/badge/license-MIT-green?style=flat-square">
  </p>
</div>

## What the job does

[Grammage](https://getgrammage.com) loads your pages in a real headless Chromium, records every
byte, request and DOM node, and turns them into a grade from A to F, an estimate in grams of CO₂ per
visit and a list of fixes ranked by the points they bring back. Its best-practice checks come from
the 115 web eco-design best practices of Green IT and from the French RGESN, and each finding names
the rule it refers to.

This repository holds the templates only. Each platform gets the same three jobs.

| Job     | When                        | What it does                                                                                                                          |
| ------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| audit   | on each pull request        | audits the preview, or the site started by the pipeline, then shows the grade, the findings on the files and the metrics of each page |
| source  | on each pull request        | reads the repository without a browser and points, file and line, to what will make the pages heavier, such as a 200 KB image         |
| certify | after the production deploy | measures the public site and sends the report to Grammage, which remeasures it and keeps the badge of the domain valid                |

A threshold, a grade or a carbon budget, can fail the pipeline, so a pull request that makes the
site heavier is caught before it ships.

| Platform            | Where the results show                                                                                     |
| ------------------- | ---------------------------------------------------------------------------------------------------------- |
| GitHub Actions      | job summary, annotations on the changed files, one pull request comment updated on each run, code scanning |
| GitLab CI           | Tests tab, Code Quality and Metrics widgets of the merge request                                           |
| Bitbucket Pipelines | Tests tab and Code Insights report of the pull request, with its annotations                               |
| Azure DevOps        | Tests tab, Grammage tab of the build summary, Scans tab                                                    |
| Any other CI        | a JUnit report, a Markdown summary and the exit code                                                       |

## Install

The Grammage image needs a license, which you get on [getgrammage.com](https://getgrammage.com/#tarifs).
It comes with a registry username. Keep both as secrets of your project or organization:
`GRAMMAGE_LICENSE` for the license token and `GRAMMAGE_REGISTRY_USERNAME` for the username.

### GitHub Actions

```yaml
on: pull_request

permissions:
    contents: read
    pull-requests: write

jobs:
    grammage:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v7
            - uses: Solyzon/grammage@v1
              with:
                  url: https://preview.example.com/
                  fail-under: C
                  license: ${{ secrets.GRAMMAGE_LICENSE }}
                  registry-username: ${{ secrets.GRAMMAGE_REGISTRY_USERNAME }}
```

To audit the site built by the workflow itself, start it in a step before the action and give its
address to `serve-url`. Grammage puts a proxy in front of it that compresses the responses like a
production server, so the weight matches what visitors download.

```yaml
- run: npm ci && npm run build
- run: npm run preview -- --port 4321 &
- uses: Solyzon/grammage@v1
  with:
      serve-url: http://127.0.0.1:4321
      site: '1'
      license: ${{ secrets.GRAMMAGE_LICENSE }}
      registry-username: ${{ secrets.GRAMMAGE_REGISTRY_USERNAME }}
```

- The comment needs `pull-requests: write`.
- A pull request opened from a fork gets neither your secrets nor a write token, so the image
  cannot even be pulled. Skip the job for forks with
  `if: github.event.pull_request.head.repo.full_name == github.repository`.
- `sarif: true` also sends the findings to code scanning, with `security-events: write`. Code
  scanning is free on public repositories and needs GitHub Advanced Security on private ones.
- The action fails with the exit code of Grammage. To warn without blocking, add
  `continue-on-error: true` to the step, and read the `exit-code` output if you need it.
- `command: source` reads the repository, and `command: certify` certifies the production site after
  a deploy, with the same inputs.
- The runner needs Docker and the `gh` command, which GitHub's hosted Ubuntu runners have.

### GitLab CI

Add two masked CI/CD variables to your project or group, `GRAMMAGE_LICENSE` and
`DOCKER_AUTH_CONFIG`, so the runner can pull the image:

```json
{ "auths": { "registry.solyzon.net": { "auth": "<base64 of username:license>" } } }
```

Then include the template in your `.gitlab-ci.yml` and extend the jobs you need.

```yaml
include:
    - remote: https://raw.githubusercontent.com/Solyzon/grammage/main/grammage.gitlab-ci.yml

grammage:
    extends: .grammage
    variables:
        GRAMMAGE_URL: https://preview.example.com/
        GRAMMAGE_CATEGORY: showcase
        GRAMMAGE_FAIL_UNDER: C

grammage:certify:
    extends: .grammage-certify
    rules:
        - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    variables:
        GRAMMAGE_URL: https://example.com/
        GRAMMAGE_SITE: '1'
```

The image is pulled with `pull_policy: always`, so `latest` follows each new version your license
covers. A self-hosted runner must therefore list `always` in its `allowed_pull_policies`.

### Bitbucket Pipelines

Bitbucket does not include remote files, so copy the step of
[`grammage.bitbucket-pipelines.yml`](grammage.bitbucket-pipelines.yml) into your
`bitbucket-pipelines.yml`. Add `GRAMMAGE_LICENSE` and `GRAMMAGE_REGISTRY_USERNAME` as secured
repository variables, and `GRAMMAGE_URL` with the page to audit. The step writes its JUnit report
in `test-results/`, which Bitbucket reads by itself, and sends the Code Insights report through the
proxy of the pipeline, without any token. A missed threshold only warns. To make it block, replace
the last line of the script with `exit "$code"`.

### Azure DevOps

Copy the job of [`grammage.azure-pipelines.yml`](grammage.azure-pipelines.yml) into your
`azure-pipelines.yml`. Add `GRAMMAGE_LICENSE` and `GRAMMAGE_REGISTRY_USERNAME` as secret variables
of the pipeline, and `GRAMMAGE_URL` as a plain one. The Scans tab reads the SARIF file once the
SARIF SAST Scans Tab extension is installed in the organization. A missed threshold only warns. To
make it block, replace the script of the last step with `exit "$(grammageExitCode)"`.

### Other CI

Any CI that runs Docker can run the image directly.

```bash
echo "$GRAMMAGE_LICENSE" | docker login registry.solyzon.net --username "$GRAMMAGE_REGISTRY_USERNAME" --password-stdin
docker run --rm --user "$(id -u):$(id -g)" --env HOME=/tmp --volume "$PWD:/work" --env GRAMMAGE_LICENSE \
  registry.solyzon.net/solyzon/products/grammage/grammage:latest \
  audit https://example.com/ --format junit,markdown --out grammage
```

The command exits with 0 when everything passes, 1 when a threshold is missed, 2 when a page could
not be measured and 3 when the repository holds no website. Jenkins reads the report with
`junit 'grammage/grammage-junit.xml'`, and CircleCI with `store_test_results: path: grammage`.

## Main variables

On GitHub, each variable is an input of the action, named in the second column.

| Variable              | GitHub input | Default                 | Role                                                                  |
| --------------------- | ------------ | ----------------------- | --------------------------------------------------------------------- |
| `GRAMMAGE_URL`        | `url`        | `PREVIEW_URL`           | the page to audit, or the start of the crawl with `GRAMMAGE_SITE`     |
| `GRAMMAGE_SITE`       | `site`       |                         | any value audits the whole site, found by its sitemap or its links    |
| `GRAMMAGE_SERVE`      |              |                         | GitLab only, a command that builds and starts the site inside the job |
| `GRAMMAGE_SERVE_URL`  | `serve-url`  | `http://127.0.0.1:4321` | where the started site answers                                        |
| `GRAMMAGE_CATEGORY`   | `category`   | `showcase`              | the grading category, or `auto` to infer it for each page             |
| `GRAMMAGE_DEVICE`     | `device`     | `mobile`                | `mobile` or `desktop`                                                 |
| `GRAMMAGE_MODE`       | `mode`       | `normal`                | `fast`, `normal` or `full`, that is one, two or three runs per page   |
| `GRAMMAGE_FAIL_UNDER` | `fail-under` |                         | the lowest grade, from A to F, or the lowest score that passes        |
| `GRAMMAGE_BUDGET`     | `budget`     |                         | a `budget.json` file of the repository with your own limits           |
| `GRAMMAGE_HTTP_AUTH`  | `http-auth`  |                         | `user:password` of a password protected preview, as a secret          |
| `GRAMMAGE_VERSION`    | `version`    | `latest`                | the image tag, `latest` or a fixed version                            |

On GitHub, `serve-url` has no default: without it, the action audits `url`.

The full list, the reports of each platform and the protected pages are described in the
[CI/CD documentation](https://getgrammage.com/en/ci-cd-integration/).

## En français

Ce dépôt contient les modèles de CI de Grammage, l'audit d'éco-conception de Solyzon qui mesure
vraiment l'empreinte carbone d'un site web à chaque pull request, puis le fait vérifier en
production pour que son badge reste valide. Il marche avec GitHub Actions, où l'action
`Solyzon/grammage@v1` s'ajoute en quelques lignes, avec GitLab CI, où le modèle s'inclut dans le
`.gitlab-ci.yml`, et aussi avec Bitbucket Pipelines et Azure DevOps, dont on recopie l'extrait, ou
avec n'importe quelle autre CI qui sait lancer Docker. Chaque plateforme affiche ensuite les
résultats là où elle sait le faire, que ce soit dans un commentaire de la pull request, dans un
widget de la demande de fusion ou dans l'onglet des tests, avec une note de A à F, une estimation en
grammes de CO₂ par visite et des conseils rangés par les points qu'ils font gagner. Les bonnes
pratiques vérifiées viennent des 115 bonnes pratiques d'écoconception web de Green IT et du RGESN,
c'est-à-dire le référentiel général d'écoconception de services numériques. L'image demande une
licence, qu'on prend sur [getgrammage.com](https://getgrammage.com/#tarifs), et la documentation
complète se trouve sur la page [intégration CI/CD](https://getgrammage.com/integration-ci-cd/).

## Authors

Designed and developed by **[Armand OCTEAU](https://github.com/Pomme978)** and
**[Sarah LÉVY](https://github.com/Saaaraaah14)** at [Solyzon](https://solyzon.com).

## License

The templates of this repository are released under the [MIT license](LICENSE). The Grammage image
they run is distributed under a separate commercial license.

<div align="center">
  <br>
  <a href="https://solyzon.com">
    <img src="assets/solyzon.svg" alt="Solyzon" height="48">
  </a>
  <p><sub>Designed and developed by Solyzon.</sub></p>
  <p><sub>© 2026 Solyzon. All rights reserved.</sub></p>
</div>
