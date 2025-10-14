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
      uses: cloudmatos/matos-iac-github-actions@master
      with:
        # scanning two directories: ./terraform/ ./cfn-templates/ plus a single file
        scan_dir: 'terraform,cfn-templates,my-other-sub-folder/Dockerfile'
        api_key: ${{ secrets.MATOS_API_KEY }}
        server_url: 'https://app-api-cnapp.cloudmatos.ai'
    # Display the results in json format
    - name: display matos iac scan results
      run: |
        cat ./results.json
```
