# matos-iac-github-actions
MatosSphere GitHub Action

## Simple usage example

```yaml
    # Steps represent a sequence of tasks that will be executed as part of the job
    steps:
    # Checks-out your repository under $GITHUB_WORKSPACE, so your job can access it
    - uses: actions/checkout@v3
    # Scan IaC with matos
    - name: run matos iac scan
      uses: cloudmatos/matos-iac-github-actions@v0.2.0
      with:
        # scanning two directories: ./terraform/ ./cfn-templates/ plus a single file
        path: 'terraform,cfn-templates,my-other-sub-folder/Dockerfile'
        output_path: matos-result/
    # Display the results in json format
    - name: display matos iac scan results
      run: |
        cat matos-result/results.json
```
