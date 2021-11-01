#!/usr/bin/env pwsh

## You interface with the Actions/Workflow system by interacting
## with the environment.  The `GitHubActions` module makes this
## easier and more natural by wrapping up access to the Workflow
## environment in PowerShell-friendly constructions and idioms
if (-not (Get-Module -ListAvailable GitHubActions)) {
    ## Make sure the GH Actions module is installed from the Gallery
    Install-Module GitHubActions -Force
}

## Load up some common functionality for interacting
## with the GitHub Actions/Workflow environment
Import-Module GitHubActions

. $PSScriptRoot/action_helpers.ps1

$inputs = @{

    test_results_path = "coverage/code-coverage.xml"
    report_name = "Code Coverage"
    report_title = "Code Coverage using Jacoco"
    github_token                        = {{secrets.GITHUB_TOKEN}}
    skip_check_run                      = false
    coverage_value                      = "33.33%"
    total_lines                         = 100
    covered_lines                       = 33
    notcovered_lines                    = 67
    $code_coverage_path = coverage/code-coverage.md

    # test_results_path                   = Get-ActionInput code_coverage_path
    # report_name                         = Get-ActionInput report_name
    # report_title                        = Get-ActionInput report_title
    # github_token                        = Get-ActionInput github_token -Required
    # skip_check_run                      = Get-ActionInput skip_check_run
    # coverage_value                      = Get-ActionInput coverage_value
    # total_lines                         = Get-ActionInput total_lines
    # covered_lines                       = Get-ActionInput covered_lines
    # notcovered_lines                    = Get-ActionInput notcovered_lines
}


$tmpDir = [System.IO.Path]::Combine($PWD, '_TMP')
Write-ActionInfo "Resolved tmpDir as [$tmpDir]"
# $test_results_path = $inputs.test_results_path


# New-Item -Name $tmpDir -ItemType Directory -Force -ErrorAction Ignore

function Build-MarkdownReport {
    $script:report_name = $inputs.report_name
    $script:report_title = $inputs.report_title

    if (-not $script:report_name) {
        $script:report_name = "CODE_COVERAGE_$([datetime]::Now.ToString('yyyyMMdd_hhmmss'))"
    }
    if (-not $report_title) {
        $script:report_title = $report_name
    }

}
function Publish-ToCheckRun {
    param(
        [string]$reportData
    )

    Write-ActionInfo "Publishing Report to GH Workflow"

    $ghToken = $inputs.github_token
    $ctx = Get-ActionContext
    $repo = Get-ActionRepo
    $repoFullName = "$($repo.Owner)/$($repo.Repo)"

    Write-ActionInfo "Resolving REF"
    $ref = $ctx.Sha
    if ($ctx.EventName -eq 'pull_request') {
        Write-ActionInfo "Resolving PR REF"
        $ref = $ctx.Payload.pull_request.head.sha
        if (-not $ref) {
            Write-ActionInfo "Resolving PR REF as AFTER"
            $ref = $ctx.Payload.after
        }
    }
    if (-not $ref) {
        Write-ActionError "Failed to resolve REF"
        exit 1
    }
    Write-ActionInfo "Resolved REF as $ref"
    Write-ActionInfo "Resolve Repo Full Name as $repoFullName"

    Write-ActionInfo "Adding Check Run"
    $conclusion = 'neutral'
    

    $url = "https://api.github.com/repos/$repoFullName/check-runs"
    $hdr = @{
        Accept = 'application/vnd.github.antiope-preview+json'
        Authorization = "token $ghToken"
    }
    $bdy = @{
        name       = $report_name
        head_sha   = $ref
        status     = 'completed'
        conclusion = $conclusion
        output     = @{
            title   = $report_title
            summary = "This run completed at ``$([datetime]::Now)``"
            text    = "Hello"
        }
    }
    Invoke-WebRequest -Headers $hdr $url -Method Post -Body ($bdy | ConvertTo-Json)
}

Write-ActionInfo "Generating Markdown Report from TRX file"
Build-MarkdownReport
$reportData = [System.IO.File]::ReadAllText($code_coverage_path)

if ($inputs.skip_check_run -ne $true) {
    Publish-ToCheckRun -ReportData $reportData
}

