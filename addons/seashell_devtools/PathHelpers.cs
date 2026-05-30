using System.Text;
using System.Text.RegularExpressions;

namespace SeaShellDevTools;

internal static class PathHelpers
{
    public static string ResolveDirectory(string rawPath, string projectRootAbsolute)
    {
        var trimmed = rawPath.Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
        {
            throw new InvalidOperationException("Output directory cannot be blank.");
        }

        if (trimmed.StartsWith("user://", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("The v1 build tool supports relative paths, absolute paths, or res:// paths, but not user:// paths.");
        }

        if (trimmed.StartsWith("res://", StringComparison.OrdinalIgnoreCase))
        {
            var relative = trimmed["res://".Length..].Replace('/', Path.DirectorySeparatorChar);
            return Path.GetFullPath(Path.Combine(projectRootAbsolute, relative));
        }

        if (Path.IsPathRooted(trimmed))
        {
            return Path.GetFullPath(trimmed);
        }

        return Path.GetFullPath(Path.Combine(projectRootAbsolute, trimmed.Replace('/', Path.DirectorySeparatorChar)));
    }

    public static string ToResPath(string absolutePath, string projectRootAbsolute)
    {
        var fullPath = Path.GetFullPath(absolutePath);
        var fullRoot = Path.GetFullPath(projectRootAbsolute);
        if (!fullPath.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"Path '{fullPath}' is outside this Godot project.");
        }

        var relative = Path.GetRelativePath(fullRoot, fullPath).Replace('\\', '/');
        return $"res://{relative}";
    }

    public static string Slugify(string value, string fallback = "build-profile")
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return fallback;
        }

        var lowered = value.Trim().ToLowerInvariant();
        var builder = new StringBuilder(lowered.Length);

        foreach (var ch in lowered)
        {
            builder.Append(char.IsLetterOrDigit(ch) ? ch : '-');
        }

        var collapsed = Regex.Replace(builder.ToString(), "-{2,}", "-").Trim('-');
        return string.IsNullOrWhiteSpace(collapsed) ? fallback : collapsed;
    }

    public static string EnsureOutputFileName(string rawName, string requiredExtension, string artifactLabel)
    {
        var fileName = rawName.Trim();
        if (string.IsNullOrWhiteSpace(fileName))
        {
            throw new InvalidOperationException("Output file name cannot be blank.");
        }

        foreach (var invalidChar in Path.GetInvalidFileNameChars())
        {
            if (fileName.Contains(invalidChar))
            {
                throw new InvalidOperationException($"Output file name '{fileName}' contains an invalid character.");
            }
        }

        if (!fileName.EndsWith(requiredExtension, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"Output file name must end with {requiredExtension} for {artifactLabel} exports.");
        }

        return fileName;
    }
}
