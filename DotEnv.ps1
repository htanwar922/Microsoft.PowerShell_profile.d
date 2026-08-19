function Load-DotEnv(
        $FilePath = ".env",
        $ToEnvScope = $true
    ) {
    $result = @{}
    Get-Content $FilePath | ForEach-Object {
        if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
            $key = $matches[1]
            $value = $matches[2] -replace '^"|"$'  # remove quotes
            if ($ToEnvScope) {
                [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
            }
            else {
		if ($result) {
		    $result[$key] = $value
		}
		Set-Variable $key $value # Only works when directly run, not from function scope
            }
        }
    }
    if (-not $ToEnvScope) {
        return $result
    }
}

