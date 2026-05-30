using System.Text.RegularExpressions;

namespace SeaShellDevTools;

public sealed class ExportPresetInfo
{
    public required int Index { get; init; }

    public required string SectionName { get; init; }

    public required string Name { get; init; }

    public required string Platform { get; init; }

    public required string ExportPath { get; init; }

    public required bool Runnable { get; init; }

    public required bool DedicatedServer { get; init; }

    public required IReadOnlyDictionary<string, string> Options { get; init; }

    public bool GetOptionBool(string key, bool defaultValue = false)
    {
        if (!Options.TryGetValue(key, out var rawValue))
        {
            return defaultValue;
        }

        return rawValue.Trim() switch
        {
            "true" => true,
            "1" => true,
            _ => false,
        };
    }
}

public sealed class ExportPresetCatalog
{
    private ExportPresetCatalog(string sourcePath, IReadOnlyList<ExportPresetInfo> presets)
    {
        SourcePath = sourcePath;
        Presets = presets;
    }

    public string SourcePath { get; }

    public IReadOnlyList<ExportPresetInfo> Presets { get; }

    public IReadOnlyList<ExportPresetInfo> WindowsPresets =>
        Presets.Where(static preset => preset.Platform.Equals("Windows Desktop", StringComparison.OrdinalIgnoreCase)).ToArray();

    public ExportPresetInfo? FindByName(string name) =>
        Presets.FirstOrDefault(preset => preset.Name.Equals(name, StringComparison.Ordinal));

    public static ExportPresetCatalog CreateEmpty(string sourcePath)
    {
        return new ExportPresetCatalog(sourcePath, Array.Empty<ExportPresetInfo>());
    }

    public static ExportPresetCatalog Load(string projectRootAbsolute)
    {
        var sourcePath = Path.Combine(projectRootAbsolute, "export_presets.cfg");
        if (!File.Exists(sourcePath))
        {
            return CreateEmpty(sourcePath);
        }

        var sections = new Dictionary<string, Dictionary<string, string>>(StringComparer.Ordinal);
        string? currentSection = null;

        foreach (var rawLine in File.ReadAllLines(sourcePath))
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

            if (currentSection is null)
            {
                continue;
            }

            var separatorIndex = line.IndexOf('=');
            if (separatorIndex <= 0)
            {
                continue;
            }

            var key = line[..separatorIndex].Trim();
            var value = line[(separatorIndex + 1)..].Trim();

            if (!sections.TryGetValue(currentSection, out var values))
            {
                values = new Dictionary<string, string>(StringComparer.Ordinal);
                sections[currentSection] = values;
            }

            values[key] = value;
        }

        var presets = new List<ExportPresetInfo>();
        foreach (var pair in sections.OrderBy(static pair => ParsePresetIndex(pair.Key)))
        {
            if (ParsePresetIndex(pair.Key) is not int index)
            {
                continue;
            }

            var values = pair.Value;
            if (!values.TryGetValue("name", out var nameValue) || !values.TryGetValue("platform", out var platformValue))
            {
                continue;
            }

            presets.Add(new ExportPresetInfo
            {
                Index = index,
                SectionName = pair.Key,
                Name = Unquote(nameValue),
                Platform = Unquote(platformValue),
                ExportPath = Unquote(values.GetValueOrDefault("export_path", "\"\"")),
                Runnable = ParseBool(values.GetValueOrDefault("runnable", "false")),
                DedicatedServer = ParseBool(values.GetValueOrDefault("dedicated_server", "false")),
                Options = sections.GetValueOrDefault($"{pair.Key}.options", new Dictionary<string, string>(StringComparer.Ordinal)),
            });
        }

        return new ExportPresetCatalog(sourcePath, presets);
    }

    private static int? ParsePresetIndex(string sectionName)
    {
        var match = Regex.Match(sectionName, @"^preset\.(\d+)$", RegexOptions.CultureInvariant);
        if (!match.Success)
        {
            return null;
        }

        return int.Parse(match.Groups[1].Value);
    }

    private static string Unquote(string rawValue)
    {
        var trimmed = rawValue.Trim();
        return trimmed.Length >= 2 && trimmed.StartsWith('"') && trimmed.EndsWith('"')
            ? trimmed[1..^1]
            : trimmed;
    }

    private static bool ParseBool(string rawValue)
    {
        return rawValue.Trim() switch
        {
            "true" => true,
            "1" => true,
            _ => false,
        };
    }
}
