namespace SeaShellDevTools;

public enum SupportedBuildPlatform
{
    WindowsDesktop,
    AndroidApk,
    Web,
}

public sealed class SupportedBuildPlatformInfo
{
    public required SupportedBuildPlatform Platform { get; init; }

    public required string GodotPlatformName { get; init; }

    public required string FriendlyName { get; init; }

    public required string ArtifactLabel { get; init; }

    public required string OutputFileExtension { get; init; }

    public required string DefaultOutputDirectory { get; init; }

    public string? DefaultOutputFileName { get; init; }

    public required IReadOnlyList<string> DebugTemplateSearchPatterns { get; init; }

    public required IReadOnlyList<string> ReleaseTemplateSearchPatterns { get; init; }
}

public static class SupportedBuildPlatforms
{
    public static readonly SupportedBuildPlatformInfo WindowsDesktop = new()
    {
        Platform = SupportedBuildPlatform.WindowsDesktop,
        GodotPlatformName = "Windows Desktop",
        FriendlyName = "Windows Desktop",
        ArtifactLabel = "Windows EXE",
        OutputFileExtension = ".exe",
        DefaultOutputDirectory = "artifacts/windows",
        DebugTemplateSearchPatterns =
        [
            "windows_debug_*.exe",
        ],
        ReleaseTemplateSearchPatterns =
        [
            "windows_release_*.exe",
        ],
    };

    public static readonly SupportedBuildPlatformInfo AndroidApk = new()
    {
        Platform = SupportedBuildPlatform.AndroidApk,
        GodotPlatformName = "Android",
        FriendlyName = "Android APK",
        ArtifactLabel = "Android APK",
        OutputFileExtension = ".apk",
        DefaultOutputDirectory = "artifacts/android",
        DebugTemplateSearchPatterns =
        [
            "android_debug.apk",
        ],
        ReleaseTemplateSearchPatterns =
        [
            "android_release.apk",
        ],
    };

    public static readonly SupportedBuildPlatformInfo Web = new()
    {
        Platform = SupportedBuildPlatform.Web,
        GodotPlatformName = "Web",
        FriendlyName = "Web",
        ArtifactLabel = "Web HTML",
        OutputFileExtension = ".html",
        DefaultOutputDirectory = "artifacts/web",
        DefaultOutputFileName = "index.html",
        DebugTemplateSearchPatterns =
        [
            "web_debug.zip",
            "web_nothreads_debug.zip",
            "web_dlink_debug.zip",
            "web_dlink_nothreads_debug.zip",
        ],
        ReleaseTemplateSearchPatterns =
        [
            "web_release.zip",
            "web_nothreads_release.zip",
            "web_dlink_release.zip",
            "web_dlink_nothreads_release.zip",
        ],
    };

    public static IReadOnlyList<SupportedBuildPlatformInfo> All { get; } =
    [
        WindowsDesktop,
        AndroidApk,
        Web,
    ];

    public static bool IsEligiblePreset(ExportPresetInfo preset)
    {
        return preset.Platform.Equals("Windows Desktop", StringComparison.OrdinalIgnoreCase) ||
            preset.Platform.Equals("Android", StringComparison.OrdinalIgnoreCase) ||
            preset.Platform.Equals("Web", StringComparison.OrdinalIgnoreCase);
    }

    public static bool TryResolveFromPreset(ExportPresetInfo? preset, out SupportedBuildPlatformInfo platformInfo, out string? errorMessage)
    {
        platformInfo = null!;
        errorMessage = null;

        if (preset is null)
        {
            errorMessage = "No export preset is selected.";
            return false;
        }

        if (preset.Platform.Equals("Windows Desktop", StringComparison.OrdinalIgnoreCase))
        {
            platformInfo = WindowsDesktop;
            return true;
        }

        if (preset.Platform.Equals("Android", StringComparison.OrdinalIgnoreCase))
        {
            var configuredExtension = Path.GetExtension(preset.ExportPath ?? string.Empty);
            if (configuredExtension.Equals(".aab", StringComparison.OrdinalIgnoreCase))
            {
                errorMessage = $"Export preset '{preset.Name}' is configured for AAB output in Godot's export menu. Sea Shell DevTools currently supports Android APK presets first.";
                return false;
            }

            if (!string.IsNullOrWhiteSpace(configuredExtension) && !configuredExtension.Equals(".apk", StringComparison.OrdinalIgnoreCase))
            {
                errorMessage = $"Export preset '{preset.Name}' targets Android, but its configured export path ends with '{configuredExtension}'. Sea Shell DevTools currently expects Android APK presets.";
                return false;
            }

            if (!preset.GetOptionBool("gradle_build/use_gradle_build"))
            {
                errorMessage = $"Export preset '{preset.Name}' targets Android, but Gradle Build is disabled. Sea Shell DevTools currently expects Android APK presets with Gradle Build enabled.";
                return false;
            }

            platformInfo = AndroidApk;
            return true;
        }

        if (preset.Platform.Equals("Web", StringComparison.OrdinalIgnoreCase))
        {
            platformInfo = Web;
            return true;
        }

        errorMessage = $"Export preset '{preset.Name}' targets '{preset.Platform}', which is not supported yet.";
        return false;
    }

    public static string BuildDefaultOutputFileName(string baseName, SupportedBuildPlatformInfo platformInfo)
    {
        if (!string.IsNullOrWhiteSpace(platformInfo.DefaultOutputFileName))
        {
            return platformInfo.DefaultOutputFileName;
        }

        var stem = string.IsNullOrWhiteSpace(baseName) ? "BuildOutput" : baseName.Trim();
        var sanitized = new string(stem.Where(ch => !Path.GetInvalidFileNameChars().Contains(ch)).ToArray()).Trim();
        if (string.IsNullOrWhiteSpace(sanitized))
        {
            sanitized = "BuildOutput";
        }

        return $"{sanitized}{platformInfo.OutputFileExtension}";
    }
}
