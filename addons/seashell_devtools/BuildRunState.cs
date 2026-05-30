namespace SeaShellDevTools;

public enum BuildRunState
{
    Idle,
    Validating,
    BuildingSolution,
    Exporting,
    PostChecking,
    Succeeded,
    Failed,
    Canceled,
}

public enum BuildLogSeverity
{
    Info,
    Success,
    Warning,
    Error,
}

public enum BuildProfileBuildMode
{
    Release,
    Debug,
}
