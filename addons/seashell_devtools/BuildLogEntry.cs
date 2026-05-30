namespace SeaShellDevTools;

public sealed class BuildLogEntry
{
    public BuildLogEntry(DateTime timestampUtc, string step, BuildLogSeverity severity, string message)
    {
        TimestampUtc = timestampUtc;
        Step = step;
        Severity = severity;
        Message = message;
    }

    public DateTime TimestampUtc { get; }

    public string Step { get; }

    public BuildLogSeverity Severity { get; }

    public string Message { get; }
}
