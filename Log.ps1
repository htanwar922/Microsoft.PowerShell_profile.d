# Log output manipulation functions

function AddTimestamp {
	Process {
		ForEach-Object { "$(Get-Date -Format '[yyyy-MM-dd HH:mm:ss.fff]') $_" }
	}
}
