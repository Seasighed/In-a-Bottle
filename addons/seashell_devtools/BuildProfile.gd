@tool
extends Resource

const BUILD_MODE_RELEASE := 0
const BUILD_MODE_DEBUG := 1

@export var DisplayName := "Default Windows Build"
@export var TargetPlatform := "windows_desktop"
@export var ExportPresetName := "Windows Desktop"
@export var BuildMode := BUILD_MODE_RELEASE
@export_dir var OutputDirectory := "artifacts/windows"
@export var ExecutableFileName := "SeaShellDevTools.exe"
@export var PrebuildDotnetSolution := true
@export var VerboseGodotLog := false
@export var OpenOutputFolderOnSuccess := false

func clone_profile() -> Resource:
	var profile: Resource = get_script().new()
	profile.DisplayName = DisplayName
	profile.TargetPlatform = TargetPlatform
	profile.ExportPresetName = ExportPresetName
	profile.BuildMode = BuildMode
	profile.OutputDirectory = OutputDirectory
	profile.ExecutableFileName = ExecutableFileName
	profile.PrebuildDotnetSolution = PrebuildDotnetSolution
	profile.VerboseGodotLog = VerboseGodotLog
	profile.OpenOutputFolderOnSuccess = OpenOutputFolderOnSuccess
	return profile

func to_snapshot(resource_path: String) -> Dictionary:
	return {
		"ResourcePath": resource_path,
		"DisplayName": DisplayName.strip_edges(),
		"TargetPlatform": TargetPlatform.strip_edges(),
		"ExportPresetName": ExportPresetName.strip_edges(),
		"BuildMode": BuildMode,
		"OutputDirectory": OutputDirectory.strip_edges(),
		"ExecutableFileName": ExecutableFileName.strip_edges(),
		"PrebuildDotnetSolution": PrebuildDotnetSolution,
		"VerboseGodotLog": VerboseGodotLog,
		"OpenOutputFolderOnSuccess": OpenOutputFolderOnSuccess,
	}
