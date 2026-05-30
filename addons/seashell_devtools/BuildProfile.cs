using Godot;

namespace SeaShellDevTools;

[Tool]
[GlobalClass]
public partial class BuildProfile : Resource
{
    [Export]
    public string DisplayName { get; set; } = "Default Windows Build";

    [Export]
    public string ExportPresetName { get; set; } = "Windows Desktop";

    [Export]
    public BuildProfileBuildMode BuildMode { get; set; } = BuildProfileBuildMode.Release;

    [Export(PropertyHint.Dir)]
    public string OutputDirectory { get; set; } = "artifacts/windows";

    [Export]
    public string ExecutableFileName { get; set; } = "SeaShellDevTools.exe";

    [Export]
    public bool PrebuildDotnetSolution { get; set; } = true;

    [Export]
    public bool VerboseGodotLog { get; set; }

    [Export]
    public bool OpenOutputFolderOnSuccess { get; set; }

    public BuildProfile CloneProfile()
    {
        return new BuildProfile
        {
            DisplayName = DisplayName,
            ExportPresetName = ExportPresetName,
            BuildMode = BuildMode,
            OutputDirectory = OutputDirectory,
            ExecutableFileName = ExecutableFileName,
            PrebuildDotnetSolution = PrebuildDotnetSolution,
            VerboseGodotLog = VerboseGodotLog,
            OpenOutputFolderOnSuccess = OpenOutputFolderOnSuccess,
        };
    }

    internal BuildProfileSnapshot ToSnapshot(string resourcePath)
    {
        return new BuildProfileSnapshot(
            resourcePath,
            DisplayName.Trim(),
            ExportPresetName.Trim(),
            BuildMode,
            OutputDirectory.Trim(),
            ExecutableFileName.Trim(),
            PrebuildDotnetSolution,
            VerboseGodotLog,
            OpenOutputFolderOnSuccess);
    }
}

internal sealed record BuildProfileSnapshot(
    string ResourcePath,
    string DisplayName,
    string ExportPresetName,
    BuildProfileBuildMode BuildMode,
    string OutputDirectory,
    string ExecutableFileName,
    bool PrebuildDotnetSolution,
    bool VerboseGodotLog,
    bool OpenOutputFolderOnSuccess);
