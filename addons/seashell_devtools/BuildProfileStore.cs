using Godot;

namespace SeaShellDevTools;

public sealed class BuildProfileRecord
{
    public required string ResourcePath { get; init; }

    public required BuildProfile Profile { get; init; }
}

public sealed class BuildProfileStore
{
    public const string ProfilesResPath = "res://devtools/build_profiles";

    private readonly string _projectRootAbsolute;
    private readonly string _profilesAbsolutePath;

    public BuildProfileStore(string projectRootAbsolute)
    {
        _projectRootAbsolute = Path.GetFullPath(projectRootAbsolute);
        _profilesAbsolutePath = ProjectSettings.GlobalizePath(ProfilesResPath);
    }

    public string ProfilesAbsolutePath => _profilesAbsolutePath;

    public IReadOnlyList<BuildProfileRecord> LoadProfiles()
    {
        EnsureProfilesDirectory();

        var files = Directory.Exists(_profilesAbsolutePath)
            ? Directory.GetFiles(_profilesAbsolutePath, "*.tres", SearchOption.TopDirectoryOnly)
            : Array.Empty<string>();

        var records = new List<BuildProfileRecord>();
        foreach (var absolutePath in files.OrderBy(static path => path, StringComparer.OrdinalIgnoreCase))
        {
            var resourcePath = PathHelpers.ToResPath(absolutePath, _projectRootAbsolute);
            var profile = ResourceLoader.Load<BuildProfile>(resourcePath);
            if (profile is null)
            {
                continue;
            }

            records.Add(new BuildProfileRecord
            {
                ResourcePath = resourcePath,
                Profile = profile,
            });
        }

        return records;
    }

    public BuildProfileRecord CreateProfile(string displayName, ExportPresetInfo? exportPreset = null)
    {
        EnsureProfilesDirectory();

        var profile = new BuildProfile
        {
            DisplayName = string.IsNullOrWhiteSpace(displayName) ? "New Build Profile" : displayName.Trim(),
            ExportPresetName = exportPreset?.Name ?? "Windows Desktop",
        };

        ApplyPlatformDefaults(profile, exportPreset);

        var resourcePath = BuildUniqueResourcePath(profile.DisplayName);
        SaveProfile(profile, resourcePath);

        return new BuildProfileRecord
        {
            ResourcePath = resourcePath,
            Profile = profile,
        };
    }

    public BuildProfileRecord DuplicateProfile(BuildProfileRecord source)
    {
        var profile = source.Profile.CloneProfile();
        profile.DisplayName = $"{source.Profile.DisplayName} Copy";

        var resourcePath = BuildUniqueResourcePath(profile.DisplayName);
        SaveProfile(profile, resourcePath);

        return new BuildProfileRecord
        {
            ResourcePath = resourcePath,
            Profile = profile,
        };
    }

    public void SaveProfile(BuildProfile profile, string resourcePath)
    {
        var error = ResourceSaver.Save(profile, resourcePath);
        if (error != Error.Ok)
        {
            throw new InvalidOperationException($"Could not save build profile '{resourcePath}'. Godot returned '{error}'.");
        }
    }

    public void DeleteProfile(string resourcePath)
    {
        var absolutePath = ProjectSettings.GlobalizePath(resourcePath);
        if (!File.Exists(absolutePath))
        {
            return;
        }

        var dir = DirAccess.Open(_profilesAbsolutePath);
        if (dir is null)
        {
            throw new InvalidOperationException("Could not open the build profile folder for deletion.");
        }

        var error = dir.Remove(Path.GetFileName(absolutePath));
        if (error != Error.Ok)
        {
            throw new InvalidOperationException($"Could not delete build profile '{resourcePath}'. Godot returned '{error}'.");
        }
    }

    public void EnsureProfilesDirectory()
    {
        DirAccess.MakeDirRecursiveAbsolute(_profilesAbsolutePath);
    }

    private void ApplyPlatformDefaults(BuildProfile profile, ExportPresetInfo? exportPreset)
    {
        if (!SupportedBuildPlatforms.TryResolveFromPreset(exportPreset, out var platformInfo, out _))
        {
            return;
        }

        profile.OutputDirectory = platformInfo.DefaultOutputDirectory;
        profile.ExecutableFileName = SupportedBuildPlatforms.BuildDefaultOutputFileName(BuildProjectOutputStem(), platformInfo);
        profile.BuildMode = platformInfo.Platform == SupportedBuildPlatform.AndroidApk
            ? BuildProfileBuildMode.Debug
            : BuildProfileBuildMode.Release;
    }

    private string BuildProjectOutputStem()
    {
        var trimmedRoot = _projectRootAbsolute.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var folderName = Path.GetFileName(trimmedRoot);
        if (string.IsNullOrWhiteSpace(folderName))
        {
            return "BuildOutput";
        }

        var compact = folderName.Replace(" ", string.Empty);
        return string.IsNullOrWhiteSpace(compact) ? folderName : compact;
    }

    private string BuildUniqueResourcePath(string displayName)
    {
        var slug = PathHelpers.Slugify(displayName, "build-profile");
        var candidate = $"{ProfilesResPath}/{slug}.tres";
        var suffix = 2;

        while (File.Exists(ProjectSettings.GlobalizePath(candidate)))
        {
            candidate = $"{ProfilesResPath}/{slug}-{suffix}.tres";
            suffix += 1;
        }

        return candidate;
    }
}
