# Trigger and Wait for Workflow Action

This composite action triggers a GitHub workflow via `workflow_dispatch` and waits for it to complete.

## Features

- Triggers a workflow in any repository (with appropriate permissions)
- Uses a correlation ID to reliably identify the triggered workflow run
- Polls the workflow status until completion
- Configurable polling interval and timeout
- Returns workflow run details as outputs

## Inputs

| Input             | Description                                              | Required | Default    |
|-------------------|----------------------------------------------------------|----------|------------|
| `github-token`    | GitHub token with workflow permissions                   | Yes      | -          |
| `owner`           | Repository owner                                         | No       | `apicurio` |
| `repo`            | Repository name                                          | Yes      | -          |
| `workflow-id`     | Workflow ID or filename (e.g., `provision-cluster.yaml`) | Yes      | -          |
| `ref`             | Git ref to run the workflow on                           | Yes      | -          |
| `workflow-inputs` | JSON string of workflow inputs                           | No       | `{}`       |
| `poll-interval`   | Polling interval in seconds                              | No       | `30`       |
| `max-wait-time`   | Maximum time to wait for workflow to start (in seconds)  | No       | `180`      |

## Outputs

| Output       | Description                                                 |
|--------------|-------------------------------------------------------------|
| `run-id`     | The ID of the triggered workflow run                        |
| `run-url`    | The URL of the triggered workflow run                       |
| `conclusion` | The conclusion of the workflow run (success, failure, etc.) |

## Usage Example

```yaml
- name: Trigger provision workflow
  uses: ./.github/actions/trigger-and-wait-workflow
  with:
    github-token: ${{ secrets.ACCESS_TOKEN }}
    owner: apicurio
    repo: apicurio-testing
    workflow-id: provision-cluster.yaml
    ref: ${{ github.ref_name }}
    workflow-inputs: |
      {
        "cluster-name": "my-cluster",
        "cluster-version": "4.19",
        "compute-nodes": "2",
        "force": "true"
      }
```

## How It Works

1. **Generates Correlation ID**: Creates a unique identifier to track the specific workflow run
2. **Triggers Workflow**: Calls the GitHub API to trigger the workflow with the specified inputs (plus the correlation ID)
3. **Finds Workflow Run**: Searches for the workflow run that matches the correlation ID. Title must be used since retrieving the parameter list is not supported.
4. **Polls Status**: Continuously polls the workflow run status until it completes
5. **Reports Results**: Returns the run ID, URL, and conclusion, and fails if the workflow didn't succeed

## Notes

- The triggered workflow must accept a `correlation-id` input parameter (optional, string type)
- The action will fail if the triggered workflow fails
- Long-running workflows are supported (the action will poll until completion)
- The correlation ID is embedded in the workflow's display title using `run-name` for tracking

