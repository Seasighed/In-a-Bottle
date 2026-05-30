using System.Text.RegularExpressions;

namespace SeaShellDevTools;

internal sealed class GodotProjectInfo
{
    private GodotProjectInfo(
        string projectRootAbsolute,
        string projectFileAbsolute,
        bool hasTopLevelCsproj,
        IReadOnlyList<string> configFeatures)
    {
        ProjectRootAbsolute = projectRootAbsolute;
        ProjectFileAbsolute = projectFileAbsolute;
        HasTopLevelCsproj = hasTopLevelCsproj;
        ConfigFeatures = configFeatures;
    }

    public string ProjectRootAbsolute { get; }

    public string ProjectFileAbsolute { get; }

    public bool HasTopLevelCsproj { get; }

    public IReadOnlyList<string> ConfigFeatures { get; }

    public bool HasCSharpFeature =>
        ConfigFeatures.Any(feature => feature.Equals("C#", StringComparison.OrdinalIgnoreCase));

    public bool LooksLikeCSharpProject => HasTopLevelCsproj || HasCSharpFeature;

    public static GodotProjectInfo Load(string projectRootAbsolute)
    {
        var root = Path.GetFullPath(projectRootAbsolute);
        var projectFileAbsolute = Path.Combine(root, "project.godot");
        var hasTopLevelCsproj = Directory.Exists(root) &&
            Directory.GetFiles(root, "*.csproj", SearchOption.TopDirectoryOnly).Any();

        var configFeatures = File.Exists(projectFileAbsolute)
            ? ParseConfigFeatures(projectFileAbsolute)
            : Array.Empty<string>();

        return new GodotProjectInfo(root, projectFileAbsolute, hasTopLevelCsproj, configFeatures);
    }

    private static IReadOnlyList<string> ParseConfigFeatures(string projectFileAbsolute)
    {
        string? currentSection = null;
        foreach (var rawLine in File.ReadAllLines(projectFileAbsolute))
        {
            var line = rawLine.Trim();
            if (string.IsNullOrWhiteSpace(line) || line.StartsWith(';') || line.StartsWith('#'))
            {
                continue;
            }

            if (line.StartsWith('[') && line.EndsWith(']'))
            {
                currentSection = line[1..^1];
                continue;
            }

            if (!string.Equals(currentSection, "application", StringComparison.Ordinal))
            {
                continue;
            }

            var separatorIndex = line.IndexOf('=');
            if (separatorIndex <= 0)
            {
                continue;
            }

            var key = line[..separatorIndex].Trim();
            if (!string.Equals(key, "config/features", StringComparison.Ordinal))
            {
                continue;
            }

            var rawValue = line[(separatorIndex + 1)..].Trim();
            return ParsePackedStringArray(rawValue);
        }

        return Array.Empty<string>();
    }

    private static IReadOnlyList<string> ParsePackedStringArray(string rawValue)
    {
        var match = Regex.Match(rawValue, @"^PackedStringArray\((?<items>.*)\)$", RegexOptions.CultureInvariant);
        var items = match.Success ? match.Groups["items"].Value : rawValue;
        return Regex.Matches(items, "\"(?<value>(?:\\\\.|[^\"])*)\"", RegexOptions.CultureInvariant)
            .Select(static item => UnescapeQuotedValue(item.Groups["value"].Value))
            .ToArray();
    }

    private static string UnescapeQuotedValue(string value)
    {
        return value
            .Replace("\\\"", "\"", StringComparison.Ordinal)
            .Replace("\\\\", "\\", StringComparison.Ordinal);
    }
}
