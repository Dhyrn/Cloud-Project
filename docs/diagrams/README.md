# Diagrams

Mermaid source files that render directly on GitHub and on the mermaid
live editor.

| File | What it shows |
|---|---|
| [`aws-infra.mmd`](aws-infra.mmd) | All deployed AWS resources, networking, and SG-to-SG flow |
| [`deploy-pipeline.mmd`](deploy-pipeline.mmd) | End-to-end deploy on `git push` (sequence diagram) |

## Rendering

**Easiest** — paste the file contents into https://mermaid.live and screenshot.

**Local** — `npm install -g @mermaid-js/mermaid-cli`, then:

```bash
cd docs/diagrams
mmdc -i aws-infra.mmd -o aws-infra.png -t dark -b transparent
mmdc -i deploy-pipeline.mmd -o deploy-pipeline.png -t dark -b transparent
```

**GitHub** — view the `.mmd` file in the GitHub UI; modern GitHub now
renders Mermaid blocks natively, but the `.mmd` filetype needs the file
contents wrapped in a fenced block to render in the file view.

A simpler-but-equivalent text version of the architecture diagram is in
the project [README.md](../../README.md) and in
[../architecture.md](../architecture.md).
